# Random, progressively smaller, and jumpable

The original generator used sinusoidal horizontal drift, nearly fixed widths, and exactly 88 pixels between floors. That made the route safe but visibly regular. Version 2 replaces it with **seeded constrained sampling**.

## What the research contributes

Lee, Partlan, and Cooper's [Precomputing Player Movement in Platformers for Level Generation with Reachability Constraints](https://ceur-ws.org/Vol-2862/paper13.pdf) shows why platformer generation should account for legal player movement states rather than just connecting map cells. Their paper uses precomputed states and constraint-based generation. This game adopts the movement-constraint principle, with a much smaller, game-specific generate-and-test sampler; it does not implement their metatile/ASP/ML pipeline.

[Godot's character-body guide](https://docs.godotengine.org/en/4.7/tutorials/physics/using_character_body_2d.html) makes gravity and motion the script's responsibility. Consequently, the validator imports the actual movement constants from `player.gd`. [Godot's RNG documentation](https://docs.godotengine.org/en/4.7/classes/class_randomnumbergenerator.html) supports reproducible seeded streams and recommends hashing similar external seeds. The generator hashes the seed, chunk, stream name, and layout version. Reproduction is for the pinned engine/generator version; it is not promised across engine upgrades.

## Widths: random locally, smaller on average

For zero-based biome level \(L\), the target mean width is:

\[
\mu(L)=84+136e^{-L/8}.
\]

That starts at 220 pixels and gradually approaches a safe 84-pixel mean. It never deliberately shrinks landings toward zero. A shuffled, balanced sample spans up to ±28% of the level's mean. Opposite deviations preserve the mean across the 20 platforms while random ordering prevents a monotonically narrowing staircase. The full-width starting floor is an onboarding exception.

Vertical rises use another independent shuffled sample around 84 pixels, spanning approximately 62–106 pixels. Its 20 values sum to one chunk's height. Thus occasional easy and demanding steps coexist while chunk anchors remain directly addressable.

## Reachability: validate the move, not just the gap

The ordinary ballistic descending time for a rise \(h\) is a useful initial rejection test:

\[
t=\frac{v_0+\sqrt{v_0^2-2gh}}{g}.
\]

Using maximum horizontal speed times this duration would ignore acceleration and braking. Instead, `jump_model.gd` simulates at 60 Hz with the player's real acceleration, speed cap, drag, and gravity. A steering controller accelerates toward the destination and brakes based on stopping distance.

Validation starts at the source center from rest and uses the baseline jump, without momentum or biome lift. Still air and both ±25 px/s² wind extremes must succeed. The entire body must fit on the destination with an additional six-pixel inset, and its predicted stopping position must remain inside that inset. Gravity on the first simulated step deliberately makes the model slightly conservative.

This produces a movement witness under stated assumptions, not a promise that every input sequence succeeds or a formal proof for all frame rates and time-varying winds. Representative transfers are independently exercised using the actual `CharacterBody2D`, keyboard actions, one-way colliders, and maximum wind.

## Bounded streaming and chunk connections

Each seeded chunk contains 20 floors and independently determined entry/exit anchors. The sampler reserves enough remaining horizontal movement to reach the next anchor, rejects candidates without a jump witness, and uses a finite conservative bridge fallback rather than retrying forever. Chunk seams are validated too.

Only eight chunk results are cached. Distant access regenerates a small chunk instead of replaying every previous floor. `floor_y()` and `floor_at_y()` connect the variable spacing to camera streaming, altitude, and biome transitions. The previous fixed-spacing arithmetic would be incorrect here.

## Checks and practical limits

Tests inspect 15,000 generated edges across three seeds, chunk seams, replay after cache eviction, width means, width/rise fluctuation, genuine horizontal gaps, and height lookups. Eight sampled transfers cover early floors, seams, and narrow late-game platforms in the real engine. Impossible-height and impossible-distance examples must be rejected.

Human difficulty testing remains necessary: a valid jump can still be demanding. Physics or biome changes must rerun these checks. Route version 2 intentionally changes the old sine-wave routes while retaining local best records.
