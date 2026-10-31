# GoDot Game Gallery

### Small games. Big ideas.

A local-first game workshop for learning to program. Make independent **2D and 3D Godot games**, keep each one in its own folder, and play them from an automatically discovered **4 × 2 paginated gallery**.

![GoDot Game Gallery](docs/images/cover.svg)

**macOS + Linux · Godot 4.7.2 · GDScript · Python 3.11+ · MIT**

## Play in three commands

Install [uv](https://docs.astral.sh/uv/getting-started/installation/), then open a terminal in this repository. uv manages Python and the project environment automatically (Python 3.12 is the development default; 3.11+ is supported):

```sh
uv run ggg setup
uv run ggg doctor
uv run ggg gallery
```

`setup` downloads the official standard Godot editor for your computer and verifies its SHA-256 against `engine.lock.json`. The engine stays inside this repository's ignored `.tools` folder. The first `uv run` installs the project and locked development tools into `.venv`; no environment activation is needed. After the first sync and engine setup, everyday development works offline. Use `uv run --no-dev ggg …` if you only need the runtime tooling.

Linux supports x86_64 and ARM64 development machines. macOS uses the universal Intel/Apple Silicon editor. A graphical desktop and OpenGL-compatible graphics are required for normal play. Source games also open directly in Godot.

Already installed Godot? Set `GODOT_BIN` to its executable; its version must match the lock file. On a Mac the executable is inside `Godot.app/Contents/MacOS/Godot`.

## Make your first game

```sh
uv run ggg new moon-jumper --dimension 2d --title "Moon Jumper"
uv run ggg play moon-jumper
uv run ggg edit moon-jumper
```

Open `games/moon-jumper/player.gd` in your favorite code editor. Change `speed` or `jump_speed`, save, and run the game again. Refresh the gallery with **F5** to see newly created games. Choose `--dimension 3d` for a floating-island starter.

**Your changes belong to your game.** Templates are copied, not linked. Editing a game cannot change the starter template or another game's code.

## Included games

| Game | Explore | First experiments |
| --- | --- | --- |
| **Coin Garden · 2D** | Jump across platforms and collect six sun coins | Change jump height, rearrange coins, add a platform |
| **Sky Steps · 3D** | Hop between floating islands and collect six sky sparks | Move an island, change gravity, add a spark |
| **Pong · 2 Players · 2D** | Rally on one keyboard; first to seven wins | Tune ball speed, change paddle size, experiment with bounce angles |
| **Blob Volley 2D · 2 Players** | Jump and head the ball over the net | Tune gravity, touches, and jump height |
| **Blob Volley 3D · 2 Players** | Move around a full court and aim depth returns | Explore 3D collision, court bounds, and materials |
| **Endless Tower · 2D** | Chain momentum jumps through 16 biome families and endless remixed reaches | Tune jumps, seeded generation, camera pressure, and biome data |

Coin Garden and Sky Steps have movement, jumping, collisions, and a win state. Falling in Sky Steps returns you to the starting island while retaining collected sparks. Pong gives Player 1 **WASD** and Player 2 the **arrow keys**, with **Space** to serve or pause. Blob Volley adds [classic 2D](games/blob-volley-2d/README.md) and [full 3D](games/blob-volley-3d/README.md) courts; use **F** to serve and **P** to pause. In 3D, **Space** and **Enter** jump. [Endless Tower](games/endless-tower/README.md) adds a single-player momentum climb, a biome journal (**B**), and repeatable routes (**R** retries; **N** changes the seed). Every game supports **R** to restart and **Esc** to return to the gallery. See [Pong's controls and learning experiments](games/pong/README.md).

The gallery includes search, 2D/3D filters, keyboard focus, eight slots per page, empty slots for future ideas, and automatic return when a game closes. Games run in separate processes. Invalid manifests are skipped with a visible message; `check` explains the problem.

## Commands

| Command | What it does |
| --- | --- |
| `uv run ggg setup` | Install the pinned Godot editor |
| `uv run ggg setup --templates` | Also install export templates; approximately 1.3 GB extra |
| `uv run ggg doctor` | Check the environment and manifests |
| `uv run ggg list` | List automatically discovered games |
| `uv run ggg gallery` | Open the game gallery |
| `uv run ggg new NAME --dimension 2d` | Copy a playable starter into a new folder |
| `uv run ggg play NAME` | Run a source game immediately |
| `uv run ggg edit NAME` | Open a game's Godot editor |
| `uv run ggg check` | Validate game metadata and files |
| `uv run ggg check --smoke` | Import and exercise the gallery, games, and templates |
| `uv run ggg build --platform linux` | Export a portable Linux x86_64 collection |
| `uv run ggg build --platform macos` | Export a portable universal macOS collection |

## How folders become games

Each immediate folder inside `games/` containing a valid `game.json` is a game. Its folder name matches its manifest ID. A source game contains `project.godot`, scripts, a scene, its own artwork, and its manifest. No central registry needs updating.

The gallery reads metadata and artwork from disk at startup and when refreshed. Source mode launches the pinned Godot engine with the selected project's path. Exported mode launches that game's native executable. **Creating source folders adds development games; adding games to a distributed bundle requires exporting them.**

See [the manifest contract](docs/architecture.md#manifest-contract) and its [editor schema](schema/game.schema.json).

## Build and share

```sh
uv run ggg setup --templates
uv run ggg build --platform linux
uv run ggg build --platform macos
```

Outputs go to `dist/linux/` and `dist/macos/`. Keep the `games` folder beside the launcher. Players need neither Python nor a Godot installation. Exports are **unsigned local builds**; [distribution notes](docs/distribution.md) explain Mac signing and what has been tested.

The manual **Build playable bundles** GitHub Actions workflow produces downloadable archives after this repository is hosted on GitHub. The regular checks workflow validates code on Linux and imports/smoke-tests projects on Linux and macOS. Workflows are provided; a successful remote CI run is not implied by their presence.

## Develop the platform

```sh
uv sync --locked
make lint
make test
make smoke
```

The Python tools use only the standard library at runtime. Development dependencies are declared in `pyproject.toml` and resolved in the committed `uv.lock`. Run `uv add --dev PACKAGE` to add a development tool and commit both files. CI uses `uv sync --locked` to detect stale lockfiles.

Run `make help` for setup, play, edit, validation, formatting, and export shortcuts. For example, `make new GAME=moon-jumper DIMENSION=2d`, `make play GAME=moon-jumper`, and `make build PLATFORM=linux`. See [AGENTS.md](AGENTS.md) for the development workflow. The Python package supplies an editable CLI for this checkout; share games using `uv run ggg build`, which exports the Godot projects. GitHub Actions are pinned to commit SHAs, permissions are read-only, and Dependabot proposes updates.

## Read next

- [Learning trail: small experiments in 2D and 3D](docs/learning.md)
- [Architecture and project boundaries](docs/architecture.md)
- [Testing and verification](docs/testing.md)
- [Builds and distribution](docs/distribution.md)
- [Contributing](CONTRIBUTING.md)
- [Research references and licensing](docs/references.md)
- [First-version boundaries and next milestones](docs/roadmap.md)

All included scripts and artwork are original implementations, released under [MIT](LICENSE). Godot has its own license and third-party notices, included with its official distributions.
