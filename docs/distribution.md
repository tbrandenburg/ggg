# Builds and distribution

## Local development versus a playable bundle

Source mode requires Python and the pinned Godot editor. `play` runs the source project directly; no export is needed after each code change.

Export mode produces a launcher and one executable/app per game. The entire output directory is the product. Players do not need Python or Godot. Keep game metadata and thumbnail files beside their exported game. To add or update a game, export the collection again.

Linux uses separate `.pck` data files beside the executables. Keep these files with their matching binaries. The exporter also includes this repository's license and Godot's engine/third-party notices.

## Build

```sh
python3 ggg.py setup --templates
python3 ggg.py check --smoke
python3 ggg.py build --platform linux
python3 ggg.py build --platform macos
```

The official export template archive is approximately 1.3 GB. Install it once. The CLI can cross-export these platforms using the templates, but signing/notarization and native testing need appropriate machines.

Linux builds target **x86_64**; ARM64 development is supported, but an ARM64 native export preset is a future addition. macOS builds use a universal app. Source copies in temporary directories isolate exports from a learner's files. A failed export leaves the previous distribution intact.

## macOS signing

These builds are unsigned and not notarized. They are suitable for local development and evaluation; macOS may ask for confirmation before opening a downloaded unsigned app. Follow Apple's normal Open Anyway flow for your own trusted build. Do not disable system protections globally.

The exporter gives the launcher and each game distinct bundle identifiers. Before public distribution, sign every app with your Developer ID, notarize and staple them, and test on a clean Mac. The repository does not contain signing credentials or claim notarization.

## GitHub workflow

After hosting the repository on GitHub, run **Actions → Build playable bundles → Run workflow**. It builds on native Linux and macOS runners and uploads tar.gz archives, preserving executable permissions and application bundle structure. It does not create a public release automatically.

## Verification limits

See [testing.md](testing.md) for the recorded checks. Cross-exporting a Mac app on Linux does not verify native Mac behavior. Validate window focus, returning from a game, keyboard controls, and unsigned-app behavior on a Mac before treating it as a supported release.
