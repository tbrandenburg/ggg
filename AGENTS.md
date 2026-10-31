# Repository guidance

- This is a Godot game workshop, not a website. Preserve the native gallery and independent game projects.
- Runtime Python tooling must remain standard-library-only, compatible with Python 3.11+.
- Respect each learner's game folder. Never regenerate or overwrite an existing game to update a template.
- Use the engine version and verified download digests in `engine.lock.json`.
- Build in temporary copies. Failed exports must preserve the previous distribution.
- Keep manifests compatible with `schema/game.schema.json` and both discovery implementations.
- Run `uv run python -m unittest discover -s tests -v` and `uv run ggg check --smoke` for behavioral changes. Check Ruff and gdformat when editing code.
- State the native operating systems actually tested; cross-export is not native testing.
- Document provenance and licensing for any added asset. Do not copy unlicensed reference code.

## Setup and use

Install uv, then run commands from the repository root. Python 3.12 is pinned in
`.python-version` for development; the tooling remains compatible with Python 3.11+.
uv creates `.venv`, installs the checkout in editable mode, and manages Python if
needed. Do not activate a virtual environment or install tools with pip.

```sh
uv sync --locked
uv run ggg setup
uv run ggg doctor
uv run ggg gallery
```

`make setup` combines the first two steps. `make help` lists all shortcuts.
Godot is pinned separately in `engine.lock.json`; setup downloads and verifies it
into `.tools/`. An existing matching engine can be selected with `GODOT_BIN`.
macOS and Linux are supported. Playing needs a graphical desktop. After the first
sync and engine download, normal development can run offline. The runtime CLI
requires no third-party Python packages; `uv run --no-dev ggg list` omits dev tools.

| Task | uv command | Make shortcut |
| --- | --- | --- |
| List games | `uv run ggg list` | `make list` |
| Open gallery | `uv run ggg gallery` | `make gallery` |
| Create a 2D game | `uv run ggg new moon-jumper --dimension 2d` | `make new GAME=moon-jumper DIMENSION=2d` |
| Play a game | `uv run ggg play moon-jumper` | `make play GAME=moon-jumper` |
| Edit a game | `uv run ggg edit moon-jumper` | `make edit GAME=moon-jumper` |
| Validate manifests | `uv run ggg check` | `make check` |
| Godot smoke checks | `uv run ggg check --smoke` | `make smoke` |
| Python tests | `uv run python -m unittest discover -s tests -v` | `make test` |
| Install export templates | `uv run ggg setup --templates` | `make setup-templates` |
| Export Linux | `uv run ggg build --platform linux` | `make build PLATFORM=linux` |
| Export macOS | `uv run ggg build --platform macos` | `make build PLATFORM=macos` |

Use `--dimension 3d` for a 3D starter. New games belong in `games/<id>/`, with
`game.json`, `project.godot`, scripts, scenes, and their own assets. Discovery is
automatic; no central registration is needed. Refresh the gallery with F5.
Exports go to `dist/<platform>/`; keep the games folder beside the launcher.
Players of exported bundles need neither uv nor Python. The editable Python
package provides tooling for this checkout; Godot exports are the distributable.

## Development workflow

- `tools/ggg.py` implements the CLI; `ggg.py` remains a direct Python entry point.
- `launcher/` is the native gallery; `templates/2d` and `templates/3d` seed new games.
- `tests/` contains Python behavioral tests. `docs/testing.md` describes engine checks.
- Use `make lint` to run Ruff and check Python/GDScript formatting; `make format`
  applies formatting. Run `make test` and `make check` before submitting changes.
- For behavioral or Godot changes also run `make smoke` after `make setup`.
  Export changes need `make setup-templates` and a build for the affected platform.
- Declare development dependencies in `[dependency-groups].dev` in `pyproject.toml`.
  Use `uv add --dev PACKAGE` or `uv remove --dev PACKAGE`; commit `uv.lock` alongside
  metadata changes. For intentional upgrades use `uv lock --upgrade-package PACKAGE`.
  Do not edit the lockfile by hand or reintroduce a separate requirements file.
- `uv sync --locked` must succeed without changing `uv.lock`; CI uses this check.
  Keep `.venv`, `.tools`, and `dist` out of version control. Do not add runtime deps.
- Make accepts `UV=/path/to/uv`, `GAME`, `DIMENSION`, `PLATFORM`, and extra CLI
  options via `ARGS`, e.g. `make new GAME=moon-jumper ARGS='--title "Moon Jumper"'`.
