# Contributing

Use Python 3.11+ and the Godot version in `engine.lock.json`. Install the pinned development tools in a virtual environment using `requirements-dev.txt`.

For a game, run `python3 ggg.py new your-game --dimension 2d` or `3d`, then work inside its folder. Keep all required art and sound with the game. Use original work or document asset licenses. Do not modify another game to register yours.

For platform changes, keep the no-dependency Python runtime and independent-project boundary. Add behavioral tests for new failure modes or contracts. Use the engine's smoke checks for scene and physics behavior. Avoid tests that merely repeat the implementation.

Before a pull request:

```sh
ruff check .
ruff format --check .
gdformat --check launcher templates games tools/*.gd
python3 -m unittest discover -s tests -v
python3 ggg.py check --smoke
```

Describe what changes for a player or learner, how it was checked, and any operating system that still needs testing. Template changes affect newly created games only. Update an existing sample explicitly when appropriate.
