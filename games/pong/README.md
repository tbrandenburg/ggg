# Pong · 2 Players

A local keyboard game for two people. First to **seven** wins.

```sh
uv run ggg play pong
```

| Control | Action |
| --- | --- |
| Player 1: W / A / S / D | Up / left / down / right |
| Player 2: arrow keys | Up / left / down / right |
| Space | Serve the first ball; pause/resume a rally or the between-point countdown |
| R | Reset the match and scores |
| Esc | Close the game and return to the gallery |

Each paddle stays in its own half. Hit near the paddle's center for a straight return or near its edges to aim up/down. The ball speeds up with each return, up to a limit. A missed ball awards the other player a point, followed by a one-second break and a serve toward the player who missed.

All eight movement keys work independently, including simultaneous input. Some keyboards have hardware limits on how many keys they can report at once.

## Learn by changing a rule

- Change `paddle_speed` or `PADDLE_SIZE` to make defending easier or harder.
- Change `WINNING_SCORE` to make a shorter match.
- Change `START_SPEED`, `MAX_SPEED`, or the multiplier in `_bounce()` to tune rallies.
- Change the allowed horizontal range in `_move_paddles()` to create classic fixed-lane Pong.
- Read `_advance_ball()`: it splits motion into small steps so a fast ball cannot skip through a paddle.
- Read `_bounce()`: the impact position controls the ball's return angle.

The game needs no assets or helpers from another game folder. Its smoke test exercises key mappings, independent movement, boundaries, pause, wall and paddle bounces, fast-ball collisions, scoring, serves, victory, and restart. It is included automatically in `uv run ggg check --smoke`.
