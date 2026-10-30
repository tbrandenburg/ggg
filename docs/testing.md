# Testing

## Fast checks

```sh
python3 -m unittest discover -s tests -v
python3 ggg.py check
```

Tests cover creating independent 2D/3D projects, discovery without registration, preserving existing work, atomic creation, invalid metadata, traversal and symlink boundaries, archive extraction, engine failures that report zero exit status, and preserving an existing distribution when export fails.

## Engine checks

```sh
python3 ggg.py check --smoke
```

This imports the launcher, all games, and both templates through the pinned Godot editor. It then starts each project headlessly with `--smoke-test`. Captured `SCRIPT ERROR`, `Parse Error`, and `ERROR:` messages fail the command even when Godot exits with status zero. Each captured engine invocation has a three-minute timeout.

- Gallery: discovery, eight slots, dimension filtering, empty search results, and multiple pages.
- 2D: landing, movement input, jumping, coin collection, victory, and restart.
- 3D: landing, movement input, jumping, spark collection, victory, restart, and fall recovery.
- Pong: all eight movement keys, independent/simultaneous input, movement boundaries, pause/resume, top/bottom wall bounces, both paddles at maximum ball speed, scoring on both sides, serve countdown, victory, and restart.

These execute real game scripts: the starters exercise Godot physics, while Pong checks its custom ball/paddle collision logic. They do not establish that every platform is fun or that every jump is reachable. The scripts also run independently when a learner tests a scene in the editor.

## Manual play checklist

- Launch the gallery on Mac and Linux; check every tile has readable text and artwork.
- Create nine games and refresh. Confirm page navigation and filtering stay correct.
- Launch each starter, collect all six items, win, restart, and return with Esc.
- Play Pong with two people: move with WASD and the arrow keys, pause/resume with Space, reach seven points, restart with R, and return with Esc.
- Close a game using the window controls and confirm the gallery restores.
- Try a long title, a missing thumbnail, an invalid manifest, and an empty games folder.
- Move a portable bundle to another directory and play it without Python or Godot installed.

## First-version verification record

The delivery includes a generated `docs/verification.md` recording the checks actually completed in the build environment. GitHub workflows need their first run after the repository is uploaded; their configuration alone is not proof of a passing run. Native macOS gameplay and signing must be checked on a Mac.
