# Architecture

## One game, one project, one process

The launcher is a Godot project. Every mini game is another Godot project. The platform owns discovery, project creation, engine selection, validation, and exports. Games own their scenes, assets, scripts, controls, and save data.

| Folder | Responsibility |
| --- | --- |
| `launcher/` | Godot gallery and child-process lifecycle |
| `games/<id>/` | Independent source game and metadata |
| `templates/2d/`, `templates/3d/` | Starter projects copied by `new` |
| `tools/` | Python standard-library development commands |
| `schema/` | Versioned game-manifest editor schema |
| `tests/` | Project creation, validation, and export-boundary tests |
| `dist/` | Generated native collections; ignored by Git |
| `.tools/` | Downloaded editor and optional development tools; ignored by Git |

Python creates projects atomically and validates them before they become visible. Builds use temporary project copies and replace a previous distribution only after all exports succeed. Scripts and images never require network access during play.

## Manifest contract

```json
{
  "schema_version": 1,
  "id": "moon-jumper",
  "title": "Moon Jumper",
  "description": "Collect sunshine on a tiny platform adventure.",
  "dimension": "2d",
  "thumbnail": "tile.svg",
  "controls": "A/D: move. Space: jump. R: restart. Esc: gallery."
}
```

Required fields are exactly those shown. IDs use lowercase letters, digits, and single separating hyphens, and match the folder name. Titles contain up to 60 characters, descriptions 240, and controls 180. Thumbnails are relative SVG/PNG/JPG files inside the game folder. `check` additionally verifies the source project exists and rejects escaping paths and symlinks. The schema provides editor feedback; Python performs filesystem validation.

There are no arbitrary shell commands in manifests. Launch arguments are constructed as argument arrays. The development gallery invokes a selected `project.godot` through the pinned Godot executable. Exported games use fixed filenames: `game.x86_64` on Linux and `Game.app` on macOS.

## Gallery

The gallery scans only immediate game folders, sorts titles, applies dimension and text filters, and slices the results into pages of eight. Blank slots preserve four columns and two rows, including on the final page. A title and image are enough to select a game; descriptions and controls appear as tooltips.

A launched process minimizes the gallery. The gallery polls that process and restores itself after it exits. On macOS, exported app bundles are opened with `/usr/bin/open -W -n`, allowing the launcher to wait for the app to close. Closing the launcher does not forcibly terminate a game.

## Why independent projects?

This preserves each game's settings and keeps experiments understandable. A broken game script does not share the gallery's scene tree. There is some duplicated starter code, deliberately: a child can change their own copy freely. Improvements to templates apply to future games, not existing work.

The alternative is a shared Godot project with discoverable scenes. It makes shared helpers convenient but couples input maps, global classes, and project settings. That remains an option if the collection later becomes a single integrated game.

## Engine upgrades

Change `engine.lock.json` only after checking the official release assets and SHA-256 digests. Update all `project.godot` feature versions if needed, run both operating-system CI jobs, test actual play, and rebuild both bundles. `GODOT_BIN` must match the lock. Avoid automatic engine upgrades during a child's active project.
