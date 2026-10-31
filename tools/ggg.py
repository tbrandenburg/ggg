"""Create, validate, run, test, and export independent Godot projects."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
FIELDS = {"schema_version", "id", "title", "description", "dimension", "thumbnail", "controls"}


class ArcadeError(Exception):
    """An actionable user-facing problem."""


def lock(root: Path = ROOT) -> dict:
    return json.loads((root / "engine.lock.json").read_text())


def confined(base: Path, relative: str) -> Path:
    """Reject traversal, absolute paths, and symlinks escaping a game's folder."""
    candidate = (base / relative).resolve()
    if Path(relative).is_absolute() or not candidate.is_relative_to(base.resolve()):
        raise ArcadeError(f"Path must stay inside its game folder: {relative}")
    return candidate


def read_game(folder: Path) -> dict:
    try:
        data = json.loads((folder / "game.json").read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ArcadeError(f"{folder.name}: cannot read game.json: {exc}") from exc
    if not isinstance(data, dict) or set(data) != FIELDS:
        raise ArcadeError(f"{folder.name}: manifest fields must be {sorted(FIELDS)}")
    if type(data["schema_version"]) is not int or data["schema_version"] != 1:
        raise ArcadeError(f"{folder.name}: unsupported schema_version")
    if data["id"] != folder.name or not SLUG.fullmatch(folder.name):
        raise ArcadeError(f"{folder.name}: id must match a lowercase, hyphenated folder name")
    for key, maximum in (("title", 60), ("description", 240), ("controls", 180)):
        value = data[key]
        if not isinstance(value, str) or not value.strip() or len(value) > maximum:
            raise ArcadeError(f"{folder.name}: {key} must contain 1–{maximum} characters")
    if any(ord(char) < 32 for char in data["title"]):
        raise ArcadeError(f"{folder.name}: title must be a single line without control characters")
    if data["dimension"] not in ("2d", "3d"):
        raise ArcadeError(f"{folder.name}: dimension must be 2d or 3d")
    thumbnail = data["thumbnail"]
    if not isinstance(thumbnail, str) or Path(thumbnail).suffix.lower() not in (
        ".svg",
        ".png",
        ".jpg",
    ):
        raise ArcadeError(f"{folder.name}: thumbnail must be an SVG, PNG, or JPG")
    if not confined(folder, thumbnail).is_file():
        raise ArcadeError(f"{folder.name}: missing thumbnail")
    if not (folder / "project.godot").is_file():
        raise ArcadeError(f"{folder.name}: missing project.godot")
    return data


def discover(root: Path = ROOT) -> list[tuple[Path, dict]]:
    games = []
    for folder in sorted((root / "games").iterdir()):
        if folder.is_dir() and not folder.name.startswith("."):
            if folder.is_symlink():
                raise ArcadeError(f"{folder.name}: game folders must not be symlinks")
            if (folder / "game.json").exists():
                games.append((folder, read_game(folder)))
    return games


def engine(root: Path = ROOT) -> str:
    candidates = [os.environ.get("GODOT_BIN")]
    local = root / ".tools" / "godot"
    candidates += [str(local / "Godot.app/Contents/MacOS/Godot")]
    candidates += [str(p) for p in sorted(local.glob("Godot*")) if p.is_file()]
    candidates += [shutil.which("godot"), shutil.which("godot4")]
    if sys.platform == "darwin":
        candidates += ["/Applications/Godot.app/Contents/MacOS/Godot"]
    for candidate in candidates:
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            result = subprocess.run(
                [candidate, "--version"], text=True, capture_output=True, check=True, timeout=15
            )
            version = lock(root)["version"]
            if not result.stdout.strip().startswith(version + "."):
                raise ArcadeError(
                    f"Expected Godot {version}, got {result.stdout.strip()}. Run setup."
                )
            return str(Path(candidate).resolve())
    raise ArcadeError("Godot was not found. Run: uv run ggg setup (or set GODOT_BIN).")


def fetch_verified(asset: dict, destination: Path, root: Path = ROOT) -> None:
    url = f"https://github.com/godotengine/godot/releases/download/{lock(root)['release']}/{asset['file']}"
    print(f"Downloading {asset['file']}…", flush=True)
    request = urllib.request.Request(url, headers={"User-Agent": "GoDotGameGallery/0.1"})
    digest = hashlib.sha256()
    with urllib.request.urlopen(request, timeout=120) as response, destination.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
            output.write(chunk)
    if digest.hexdigest() != asset["sha256"]:
        destination.unlink(missing_ok=True)
        raise ArcadeError("Download checksum mismatch; the archive was discarded.")


def extract_verified(archive: Path, destination: Path) -> None:
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            confined(destination, member.filename)
            if stat.S_ISLNK(member.external_attr >> 16):
                raise ArcadeError("Archive contains an unexpected symlink")
        bundle.extractall(destination)
        for member in bundle.infolist():
            path = destination / member.filename
            mode = (member.external_attr >> 16) & 0o777
            if mode and path.exists():
                path.chmod(mode)


def setup(with_templates: bool = False, root: Path = ROOT) -> None:
    if sys.platform not in ("linux", "darwin"):
        raise ArcadeError("This first version supports macOS and Linux.")
    machine = platform.machine().lower()
    if sys.platform == "darwin":
        key = "macos"
    elif machine in ("x86_64", "amd64"):
        key = "linux-x86_64"
    elif machine in ("aarch64", "arm64"):
        key = "linux-arm64"
    else:
        raise ArcadeError(f"Unsupported Linux architecture: {machine}")
    tools = root / ".tools"
    tools.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=tools) as temporary:
        temp = Path(temporary)
        fetch_verified(lock(root)["assets"][key], temp / "engine.zip", root)
        extract_verified(temp / "engine.zip", temp / "engine")
        target = tools / "godot"
        if target.exists():
            shutil.rmtree(target)
        shutil.move(str(temp / "engine"), target)
        if with_templates:
            fetch_verified(lock(root)["assets"]["templates"], temp / "templates.zip", root)
            extract_verified(temp / "templates.zip", temp / "export")
            base = (
                Path.home() / "Library/Application Support/Godot"
                if sys.platform == "darwin"
                else Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot"
            )
            target = base / "export_templates" / f"{lock(root)['version']}.stable"
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                shutil.rmtree(target)
            shutil.move(str(temp / "export/templates"), target)
    print(f"Ready: {engine(root)}")


def new_game(slug: str, dimension: str, title: str | None = None, root: Path = ROOT) -> Path:
    if not SLUG.fullmatch(slug) or len(slug) > 60:
        raise ArcadeError("Use a short lowercase name such as moon-jumper (maximum 60 characters).")
    destination = root / "games" / slug
    if destination.exists():
        raise ArcadeError(f"{slug} already exists; choose another name.")
    with tempfile.TemporaryDirectory(prefix=".new-", dir=root / "games") as temporary:
        staging = Path(temporary) / slug
        shutil.copytree(
            root / "templates" / dimension,
            staging,
            ignore=shutil.ignore_patterns(".godot", "*.uid"),
        )
        data = json.loads((staging / "game.json").read_text())
        data.update(id=slug, title=title or slug.replace("-", " ").title())
        (staging / "game.json").write_text(json.dumps(data, indent=2) + "\n")
        project = staging / "project.godot"
        project.write_text(
            project.read_text().replace(
                'config/name="Starter Game"',
                "config/name=" + json.dumps(data["title"], ensure_ascii=False),
            )
        )
        read_game(staging)
        staging.rename(destination)
    print(f"Created {destination.relative_to(root)}. Play: uv run ggg play {slug}")
    return destination


def game_path(slug: str, root: Path = ROOT) -> Path:
    if not SLUG.fullmatch(slug):
        raise ArcadeError("Invalid game id")
    path = root / "games" / slug
    if path.is_symlink():
        raise ArcadeError("Game folders must not be symlinks")
    read_game(path)
    return path


def run_checked(command: list[str], *, capture: bool = False) -> None:
    result = subprocess.run(
        command, text=True, capture_output=capture, check=False, timeout=180 if capture else None
    )
    output = (result.stdout or "") + (result.stderr or "")
    if capture:
        print(output, end="")
    # Godot can return zero even when a script failed to parse.
    if result.returncode or (capture and re.search(r"SCRIPT ERROR|Parse Error|ERROR:", output)):
        raise ArcadeError(f"Command failed: {' '.join(command)}")


def check(root: Path = ROOT, smoke: bool = False) -> None:
    games = discover(root)
    print(f"Validated {len(games)} games.")
    if not smoke:
        return
    binary = engine(root)
    projects = [root / "launcher"] + [folder for folder, _ in games]
    # Validate templates too, so the next newly created game is actually usable.
    projects += [root / "templates" / dimension for dimension in ("2d", "3d")]
    for project in projects:
        print(f"Checking {project.relative_to(root)}", flush=True)
        run_checked(
            [binary, "--headless", "--path", str(project), "--editor", "--import"], capture=True
        )
        args = [binary, "--headless", "--path", str(project), "--", "--smoke-test"]
        if project.name == "launcher":
            args += ["--library-root", str(root), "--source", "--godot", binary]
        run_checked(args, capture=True)


def presets(platform_name: str, identifier: str = "org.godotgamegallery.launcher") -> str:
    native = "Linux" if platform_name == "linux" else "macOS"
    architecture = "x86_64" if platform_name == "linux" else "universal"
    return f'''[preset.0]
name="{native}"
platform="{native}"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path=""

[preset.0.options]
binary_format/architecture="{architecture}"
binary_format/embed_pck=false
application/bundle_identifier="{identifier}"
codesign/codesign=0
'''


def build(platform_name: str, root: Path = ROOT) -> None:
    games = discover(root)
    binary = engine(root)
    # Keep a previously working build intact until every export succeeds.
    dist = root / "dist"
    dist.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".build-", dir=dist) as temporary:
        staging = Path(temporary)
        output = staging / platform_name
        output.mkdir()
        projects = [
            (
                root / "launcher",
                output
                / (
                    "GoDotGameGallery.x86_64"
                    if platform_name == "linux"
                    else "GoDotGameGallery.app"
                ),
            )
        ]
        for folder, data in games:
            target = output / "games" / folder.name
            target.mkdir(parents=True)
            (target / "game.json").write_text(json.dumps(data, indent=2) + "\n")
            thumbnail = target / data["thumbnail"]
            thumbnail.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(confined(folder, data["thumbnail"]), thumbnail)
            projects.append(
                (folder, target / ("game.x86_64" if platform_name == "linux" else "Game.app"))
            )
        for index, (project, target) in enumerate(projects):
            # Export a temporary copy; never rewrite a child's export configuration.
            work = staging / f"project-{index}"
            shutil.copytree(project, work, ignore=shutil.ignore_patterns(".godot"))
            identifier = (
                "org.godotgamegallery.launcher"
                if index == 0
                else f"org.godotgamegallery.games.{project.name}"
            )
            (work / "export_presets.cfg").write_text(presets(platform_name, identifier))
            run_checked(
                [binary, "--headless", "--path", str(work), "--editor", "--import"], capture=True
            )
            run_checked(
                [
                    binary,
                    "--headless",
                    "--path",
                    str(work),
                    "--export-release",
                    "Linux" if platform_name == "linux" else "macOS",
                    str(target),
                ],
                capture=True,
            )
        (output / "README.txt").write_text(
            "GoDot Game Gallery — keep the games folder next to the launcher.\nLinux: ./GoDotGameGallery.x86_64\nmacOS: open GoDotGameGallery.app\n"
        )
        shutil.copy2(root / "LICENSE", output / "LICENSE.txt")
        if (root / "docs/licenses").is_dir():
            shutil.copytree(root / "docs/licenses", output / "licenses")
        final = dist / platform_name
        if final.exists():
            shutil.rmtree(final)
        shutil.move(str(output), final)
    print(f"Built {final}. These are unsigned local builds; see docs/distribution.md.")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="GoDot Game Gallery · make something playable")
    commands = parser.add_subparsers(dest="command", required=True)
    install = commands.add_parser(
        "setup", help="download the pinned, checksum-verified Godot engine"
    )
    install.add_argument(
        "--templates", action="store_true", help="also install export templates (~1.3 GB)"
    )
    commands.add_parser("doctor", help="check Python, manifests, and engine version")
    commands.add_parser("list", help="list discovered games")
    commands.add_parser("gallery", help="open the 4×2 gallery")
    create = commands.add_parser("new", help="create a playable game")
    create.add_argument("id")
    create.add_argument("--dimension", choices=("2d", "3d"), default="2d")
    create.add_argument("--title")
    for name in ("play", "edit"):
        action = commands.add_parser(name)
        action.add_argument("id")
    validate = commands.add_parser("check", help="validate all games")
    validate.add_argument(
        "--smoke", action="store_true", help="also import and exercise every Godot project"
    )
    export = commands.add_parser("build", help="export a portable gallery and all games")
    export.add_argument("--platform", choices=("linux", "macos"), required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "setup":
            setup(args.templates)
        elif args.command == "new":
            new_game(args.id, args.dimension, args.title)
        elif args.command == "list":
            for _, data in discover():
                print(f"{data['id']:24} {data['dimension'].upper()}  {data['title']}")
        elif args.command == "check":
            check(smoke=args.smoke)
        elif args.command == "doctor":
            print(f"Python {platform.python_version()} · {sys.platform}/{platform.machine()}")
            check()
            print(f"Godot {lock()['version']} · {engine()}")
        elif args.command == "gallery":
            binary = engine()
            run_checked(
                [
                    binary,
                    "--path",
                    str(ROOT / "launcher"),
                    "--",
                    "--source",
                    "--library-root",
                    str(ROOT),
                    "--godot",
                    binary,
                ]
            )
        elif args.command in ("play", "edit"):
            command = [engine(), "--path", str(game_path(args.id))]
            if args.command == "edit":
                command.append("--editor")
            run_checked(command)
        elif args.command == "build":
            build(args.platform)
        return 0
    except (
        ArcadeError,
        OSError,
        ValueError,
        subprocess.SubprocessError,
        zipfile.BadZipFile,
    ) as exc:
        print(f"GoDot Game Gallery: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
