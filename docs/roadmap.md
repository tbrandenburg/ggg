# First-version scope

Implemented: independent Godot projects, 2D/3D starters, folder discovery, thumbnails, paginated 4×2 gallery, search/filtering, source launching, child-process tracking, project scaffolding, pinned engine installation, automated checks, and native export commands/workflows.

## Deliberate boundaries

- Creating games uses a terminal command or VS Code task. An in-gallery creation wizard is a future feature.
- Code editing uses an existing editor. There is no embedded IDE or automatic code feedback.
- Games are trusted local programs. Separate processes are not a security sandbox.
- Adding source folders works during development. An exported collection needs exported games.
- First-version controls use a keyboard. Controller navigation and gameplay are future additions.
- No accounts, telemetry, ads, online sharing, multiplayer, or automatic uploads.
- Native Linux exports target x86_64; native Mac behavior needs Mac validation.

## Useful next milestones

1. Complete a short parent-and-child playtest and native Mac validation.
2. Add a gallery New Game button and Open Code/Open Godot actions.
3. Add personal thumbnails from screenshots and gamepad controls.
4. Add save slots, checkpoints, and small reusable learning recipes.
5. Add signed Mac releases and ARM64 Linux exports if needed.

Prioritize changes that help a child make their next game. Add platform abstraction only when two real games need it.
