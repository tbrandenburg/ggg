# Contributing

Use Python 3.11+ and the Godot version in `engine.lock.json`. Install uv, then run `uv sync --locked` to create `.venv` and install the locked development tools and editable CLI. No activation is needed. See `AGENTS.md` and `make help` for the full workflow.

For a game, run `uv run ggg new your-game --dimension 2d` or `3d`, then work inside its folder. Keep all required art and sound with the game. Use original work or document asset licenses. Do not modify another game to register yours.

For platform changes, keep the no-dependency Python runtime and independent-project boundary. Add behavioral tests for new failure modes or contracts. Use the engine's smoke checks for scene and physics behavior. Avoid tests that merely repeat the implementation.

Before a pull request:

```sh
uv run ruff check .
uv run ruff format --check .
uv run gdformat --check launcher templates games tools/*.gd
uv run python -m unittest discover -s tests -v
uv run ggg check --smoke
```

Describe what changes for a player or learner, how it was checked, and any operating system that still needs testing. Template changes affect newly created games only. Update an existing sample explicitly when appropriate.
