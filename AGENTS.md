# Repository guidance

- This is a Godot game workshop, not a website. Preserve the native gallery and independent game projects.
- Runtime Python tooling must remain standard-library-only, compatible with Python 3.11+.
- Respect each learner's game folder. Never regenerate or overwrite an existing game to update a template.
- Use the engine version and verified download digests in `engine.lock.json`.
- Build in temporary copies. Failed exports must preserve the previous distribution.
- Keep manifests compatible with `schema/game.schema.json` and both discovery implementations.
- Run `python3 -m unittest discover -s tests -v` and `python3 ggg.py check --smoke` for behavioral changes. Check Ruff and gdformat when editing code.
- State the native operating systems actually tested; cross-export is not native testing.
- Document provenance and licensing for any added asset. Do not copy unlicensed reference code.
