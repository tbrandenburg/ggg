# Endless Tower

An original 2D momentum climber inspired by Icy Tower's run, jump, and keep-climbing idea. The character, artwork, generator, biome system, and scripts are original; no Icy Tower assets or source code are used.

```sh
python3 ggg.py play endless-tower
```

![Glacier Gate](../../docs/images/endless-tower-glacier.png)

## Controls

| Control | Action |
| --- | --- |
| A/D or left/right arrows | Build horizontal momentum |
| Space, W, or Up | Jump; hold to automatically hop after landing |
| P | Pause/resume |
| B | Open/close the biome journal; gameplay freezes while it is open |
| R | Restart the same seeded route |
| N | Start a new seeded route |
| Esc | Save records and return to the gallery |

Speed gives higher jumps. Walls reflect horizontal momentum. Platforms are one-way: pass through them from below, then land on top. A short jump buffer and coyote window make timing forgiving. The camera begins rising after your first jump and gradually speeds up; fall below the screen to end the run. Time spent reading the intro does not increase difficulty.

Landing on new higher floors scores points. Chain landings within 2.5 seconds to build a multiplier, up to ×8; revisiting old floors cannot farm points. The altitude record measures the highest point you actually reach, while scoring requires a landing.

## A tower of changing worlds

Every **20 floors**, discover another biome. The first tour contains **16 authored families**:

| Family | Atmosphere and gentle movement changes |
| --- | --- |
| Glacier Gate | Crystals, snow, slippery footing |
| Mosswood | Forest silhouettes and falling leaves |
| Dune Sea | Dunes, sand, and a gentle breeze |
| Coral Grotto | Bubbles, reef shapes, and extra lift |
| Ember Forge | Volcanic silhouettes, embers, and extra lift |
| Stormspire | Clouds, rain, wind, and slick footing |
| Mycelium Hollow | Mushrooms, spores, and extra lift |
| Clockwork Loft | Slow-turning gears and sparks |
| Crystal Archive | Crystal silhouettes and slippery footing |
| Cloud Garden | Clouds, petals, a breeze, and extra lift |
| Bamboo Moon | Segmented stalks and drifting leaves |
| Candy Orbit | Pastel planets and extra lift |
| Aurora Reach | Waving ribbons, snow, and a breeze |
| Sunken Ruins | Pillars, bubbles, and extra lift |
| Starfall Observatory | Constellations, stars, and extra lift |
| Void Bloom | Orbiting forms, spores, and a breeze |

After floor 320, the climb continues through **remixed reaches**: new region names, hue-shifted palettes, and increasing reach numbers. There is no final biome or fixed final floor. These are procedural variations of the 16 families, rather than a claim of infinitely many hand-drawn environments. The sidebar previews the next discovery; B opens a journal of the latest reached regions. Your highest floor keeps discoveries available between runs.

![Mosswood](../../docs/images/endless-tower-mosswood.png)
![Aurora Reach](../../docs/images/endless-tower-aurora.png)

## Records, routes, and generation

Best altitude and score are stored locally in this game's `user://tower_save.cfg`; they are saved on game over, retry, Esc, or window close. No account or network access is needed. R repeats the displayed route seed; N changes it. Physics and artwork need no assets outside this game folder.

Layouts are derived directly from the floor number and route seed. Adjacent platform spans overlap and vertical gaps stay below the weakest jump's height. Old platforms are removed and only the area around the camera is generated, keeping live platform counts bounded as the climb continues. Different biomes adjust friction, wind, or lift without reducing the minimum jump height.

## Learn by changing a rule

- `player.gd`: acceleration, friction, gravity, coyote time, wall bounce, and momentum-powered jumps.
- `layout.gd`: deterministic floor placement. Change the route curve, spacing, or widths, then check reachability.
- `biomes.gd`: add a biome family or change its palette, weather, and movement values.
- `main.gd`: camera pressure, platform streaming, combos, records, journal, and code-drawn artwork.
- `smoke.gd`: real movement/landing checks, 15,000 generated floors across three seeds, 1,024 distinct region identities, memory bounds, pause, failure, and replay.

The game is designed as a learning project. Automated checks do not replace a human playtest of the difficulty curve. Native Mac play and native exports have not been verified for this addition.
