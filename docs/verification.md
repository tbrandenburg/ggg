# Verification record · v0.1.0

Recorded on 2026-10-30 using Python 3.12 and the SHA-256-verified official Godot 4.7.2 editor in a restricted Linux environment.

| Check | Result |
| --- | --- |
| Actual `setup` download, digest verification, installation, version check | Passed |
| Python behavioral suite | 16 tests passed |
| Ruff lint and formatting | Passed |
| GDScript formatting | Passed |
| Import launcher, both games, both templates | Passed |
| Gallery discovery, filters, empty results, eight slots, pagination | Passed |
| 2D movement, landing, jump, collection, victory, reset | Passed |
| 3D movement, landing, jump, collection, victory, reset, fall recovery | Passed |
| OpenGL rendering of gallery and both games | Captured and visually inspected |
| Source-gallery process integration | Both games launched; double launch blocked; gallery restored after closure |
| Linux x86_64 export generation | Passed |
| Universal macOS export generation | Passed; Intel and ARM64 Mach-O slices confirmed |
| Boot all three exported Linux data packs through the pinned editor | Passed |
| Standalone Linux exported executables | Not verified successfully; see below |
| Native Mac play, app launching, signing/notarization | Not tested; requires a Mac |
| Hosted GitHub Actions | Configured; not run in a remote repository |

The two game screenshots in `docs/images/` are actual engine renders. The branded `cover.svg` is a vector illustration; the previous gallery screenshot was removed during the rebrand to avoid displaying outdated branding. Source process integration uses `tools/verify_launch.gd` with an X11 display. It starts real child games, sends each a termination signal, and verifies that the gallery observes their closure. It does not replace a human playtest.

The standalone Linux export templates reported missing project data in this restricted environment, which also lacks `/proc/self/exe`. Both embedded and separate-pack variants were investigated. The final exporter uses separate packs; those exported packs load successfully in the official editor. A normal Linux desktop must validate standalone executable startup and game switching before distributing a release. No claim of successful standalone native play is made.

The included macOS workflow is intended to supply native checks after hosting. Universal Mac bundles were produced on Linux, which establishes export generation rather than native behavior. Builds remain unsigned.

## GoDot Game Gallery rebrand

After restoring the delivered archive, the project was renamed across the gallery, CLI (`ggg.py`), export names, identifiers, workflows, schema, and documentation. The 16 Python tests and all five Godot import/runtime checks passed again on Linux. Prior native-export limitations above remain open; exports were not rerun for this branding change.
