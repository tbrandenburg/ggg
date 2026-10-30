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

## Two-player Pong

Added Pong as an independent game project. On Linux, the 16 Python tests, Ruff checks, GDScript formatting, and all six project import/runtime checks passed. Pong's runtime test covers all eight physical movement keys, independent and simultaneous controls, movement bounds, pause/resume, both walls, both paddles at maximum ball speed, scoring on both sides, automatic serves, match victory, and restart. Gallery discovery also passes with all three games present. Native Mac play and a human two-player playtest remain unverified; exports were not rerun for this addition.

## Blob Volley 2D and 3D

Both original volleyball games passed Linux checks with the pinned Godot editor. All eight project import/runtime checks, all 16 Python tests, Ruff checks, and GDScript formatting passed. The new runtime checks cover physical key bindings, the normal input-to-physics path, simultaneous movement, jumping/landing, player bounds, pause, head contacts and debounce, fast-ball substeps, net side/tape collisions, scoring, automatic serves, out-of-bounds faults, three-touch limits, deuce, and restart. The 3D version also verifies depth movement and bounds. OpenGL renders of both courts were captured and visually inspected; screenshots are included in `docs/images/`. Human two-player rally testing, native Mac play, and new native exports remain unverified.

## Endless Tower

On Linux with the pinned Godot editor, all nine project import/runtime checks passed. The climber test exercises real movement and jumping, momentum-dependent jump strength, wall reflection, one-way upward passage and descending landings, scoring/combos without repeat farming, pause/journal, camera pressure, falling, and same-route replay. It also checks 15,000 adjacent floor pairs across three seeds, 1,024 distinct generated region identities, and bounded platform streaming at distant heights. Intro reading time does not increase camera difficulty.

The 16 Python tests and code-format checks pass. All 16 biome families plus the first remixed reach were rendered with OpenGL without script errors; representative Glacier Gate, Mosswood, Ember Forge, Aurora Reach, and remixed Glacier renders were visually inspected. The included screenshots are actual engine renders at developer-selected preview heights, rather than evidence of a human completing those climbs. Human difficulty/playtesting, native Mac play, record persistence on a native desktop, and new exports remain unverified.
