# MWM Neon Bricks: game design doc

Version 3, 2026-10-07, game-designer (version 1 2026-10-05; version 2 2026-10-06 = the action pass in section 15 after the owner said world 1 "gets boring fast"; version 3 = worlds 4-6 and the level 10 fix in section 16. Where sections disagree, the higher section number wins). Game renamed from "Brick Nova" to **MWM Neon Bricks** on 2026-10-05 (trademark conflict). Use the new name everywhere, including save file, class names and voice lines.

Target: Android, portrait 1080x1920, Godot 4.6 `mobile` renderer, stand-alone app first, later a game inside MWM Play (ages 4-7 and 8+). Visuals belong to graphic-designer (`docs/DESIGN.md`); this doc only lists game-feel hooks.

Legend: **(owner)** = decided by the owner, do not reopen. **(rule N)** = numbered rule in `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. **(my calc)** = my own simulation or arithmetic, not a source. **(my call)** = a design choice I made; change it freely. Nothing here comes from Krypton Egg except paddle/ball physics ideas from our own `krypton-egg/scripts/main.gd` (per-axis swept collision, paddle-offset angle, min-vertical-speed rule). No levels, names, power-ups, monsters, story or art are reused.

---

## 1. Pitch

Steer a glowing paddle with one thumb and bounce a neon ball through walls of bright 3D bricks, world by world, on a synthwave night; a safety net under the paddle means a small child never "loses".

## 2. Core loop

**Drag** (move paddle) -> **bounce** (ball off paddle) -> **break** (bricks) -> **catch** (falling power-up) -> **clear** (last brick, slow-mo, win card) -> pick the next level or stop.

No score, no lives counter, no timer, no currency. One star per cleared level, always earned by clearing (rule 30). The win card is the natural stopping point (owner).

## 3. Controls

One thumb, portrait, no tilt, no precision gestures (owner, rules 9-11).

### 3.1 Zones (logic px at 1080x1920)

| Zone | Rect | What happens |
|---|---|---|
| Shell home square | x 0-232, y 0-232 | Nothing of the game is drawn or tappable here. Stand-alone build draws its own home disc here (same size and place as the shell's, rule 20); hidden when `Engine.get_meta(&"mwm_play_shell")` is set. |
| Playfield | x 40-1040, y 280-1700 | Not tappable. Touches that start above y 960 are ignored during play. |
| Drag zone | x 0-1080, y 960-1664 | Touch-down here becomes the paddle pointer. |
| Wrist strip | y >= 1664 | Touches that START here are ignored (rule 6). A drag that started in the drag zone keeps steering when the finger slides into the strip. |

Taller screens (20:9, canvas about 1080x2400): the playfield keeps its size and is anchored to the bottom, so paddle y = screen height - 500. Extra height goes on top as sky. The drag zone becomes y (paddle_y - 460) to (screen_h - 256). Tablets about 1200 wide: the 1000 px field stays centred, side margins grow. Safe area: push the home disc below `DisplayServer.get_display_safe_area()` but keep its hit area running to the screen edge (copy the ball-connect fix).

### 3.2 Inputs

| Input | Where | Effect |
|---|---|---|
| Touch down | Drag zone | Becomes the active pointer (latest touch wins, older touches ignored, rule 14). Paddle glow brightens for 80 ms and a quiet "hum-up" plays, same frame (rule 19). |
| Drag | Active pointer, anywhere | **Relative** steering: `paddle_x += drag_dx * DRAG_GAIN`, clamped to the walls. The paddle never jumps to the finger, so the thumb never covers the ball. Lifting and re-placing the thumb does not move the paddle. |
| Release | Active pointer | If a ball is resting on the paddle: launch it (act on release, rule 15). Otherwise nothing. |
| No input | | A resting ball auto-launches after `AUTO_LAUNCH_S` (3.0 s), so a child who does not know to tap still plays. |
| Tap home disc / Android back | Top-left | Stand-alone: copies the shell guard (first tap: ring fills over 2.0 s, game keeps running; second tap between 0.3 s and 2.0 s leaves to the world map). In the shell the shell owns this. |
| App sent to background | | Pause. On return, a big "play" icon (240 px disc, centre of screen) resumes on release. |
| Win card buttons | Card | See section 8. |

Holdover filter: ignore all touches for 300 ms after any screen change (rule 8). No long press, no double tap, no swipe in gameplay or menus.

## 4. Physics (all distances in logic px, 1080 wide)

Gameplay is simulated in a flat 2D logic plane in design px and rendered in 3D (suggested mapping 1 px = 0.01 m on the plane). Camera moves never change the logic. Graphic-designer constraint (my call): the camera may tilt at most 15 degrees from top-down during play so bricks at the top render within about 10% of their logic size.

### 4.1 Layout

- Walls: inner left x 40, inner right x 1040, inner top y 280. Field width 1000.
- Brick grid: 10 columns x 12 rows. Cell 100 x 52. Column c spans x 40 + 100c to 140 + 100c. Row r spans y 340 + 52r to 392 + 52r. Brick hit box 92 x 44 centred in the cell (4 px gap each side, so the ball can never squeeze between two bricks: ball diameter 44 > 8).
- Paddle: centre y 1420, hit box height 36 (top face y 1402). Width per difficulty and world (table 7).
- Ball: radius 22 (diameter 44, about 2.8 mm at 400 dpi; it is not a touch target, only something to watch).
- Net: line at y 1540 across x 40-1040.
- Loss line: ball centre y > 1700 with no net.

### 4.2 Ball motion

- Constant speed per ball. Speed = level base speed x setting multiplier x ramp x power-up factor, clamped to `BALL_SPEED_MIN` 300 and `BALL_SPEED_MAX` 1000 px/s.
- Ramp (Vanlig only): **progress ramp** (section 15.4): speed x (1 + 0.15 x share of the level's breakable bricks broken). It replaces the old time ramp (+2% every 15 s). Lett has no ramp (rule 16).
- Sub-stepping: `steps = ceil(speed * delta / 8)`, so no step moves more than 8 px. Per step, move X then test walls and bricks and reflect X; then move Y, test, reflect Y (the Krypton Egg per-axis method). All bricks overlapped in that axis step take one hit; the ball reflects once.
- Corner case: if after a step the ball still overlaps a solid brick (e.g. a glider moved into it), push it out along the shortest axis and flip that velocity component.

### 4.3 Paddle bounce and angle rules

- Contact when `v.y > 0`, ball bottom between paddle top - 4 and paddle top + 24, and `|ball.x - paddle.x| <= half_w + PADDLE_EDGE_GRACE` (Lett 22 = full ball radius, Vanlig 13 = 0.6 radius).
- `rel = clamp((ball.x - paddle.x) / (half_w + grace), -1, 1)`; `angle = rel * MAX_BOUNCE_DEG` from vertical (Lett 55, Vanlig 60). New velocity points up at that angle.
- Paddle "english": `v.x += paddle_vx * 0.10` (paddle_vx in px/s over the last frame), then renormalise to speed. Lett: 0.05.
- After the bounce, place ball at paddle top - 4 - radius.
- **Minimum side angle after paddle and net bounces:** `|v.x| >= sin(6 deg) * speed`. A dead-centre hit goes up at 6 degrees, away from the side with fewer remaining bricks (tie: random). Stops endless straight up-and-down loops.

### 4.4 Anti-stuck rules (apply in this order every frame)

1. **Floor on vertical speed:** `|v.y| >= sin(20 deg) * speed` (Krypton Egg used 0.25; ours is 0.342). Keep the sign, recompute `v.x` from speed. No ball travels flatter than 20 degrees from horizontal.
2. **Chrome jitter:** every bounce off a chrome brick or a switch (v3: portals have no rim and no bounce, 16.2.3) rotates the velocity by a random -3 to +3 degrees (still subject to rule 1). Walls have no jitter (feels unfair at the paddle).
3. **Loop detector:** on every wall or unbreakable-brick bounce, record (cell of contact rounded to 20 px, velocity octant). If the same record appears 3 times within 10 s with no breakable-brick hit and no paddle touch, rotate the velocity by 9 degrees toward the side with more remaining bricks, play a soft "zip" and show a short spark trail (no flash).
4. **Dry-spell timer:** if 10 s pass with no paddle touch and no brick hit (ball trapped above in chrome), apply the same 9 degree nudge, then repeat every 5 s.
5. **Helping hand (aim assist):** if `ASSIST_S` seconds pass with no brick broken (Lett 15, Vanlig 30), the next paddle bounce aims at the nearest SOLID breakable brick **that the ball can reach** (line-of-sight and bank-shot rule in section 15.3.4; aiming straight into chrome trapped the sim forever on a chrome level) (angle clamped to +-MAX_BOUNCE_DEG). If none is solid (only phased ghosts left), aim at the nearest switch. The target brick glows softly for 1.0 s before the bounce (rule 18 idle-hint pattern). This kills the classic "hunting the last brick" frustration.
6. **Safety respawn:** if the ball position is NaN or more than 100 px outside the field, put it back on the paddle as a resting ball. No net charge spent, no sound.

### 4.5 Launch

Ball rests on the paddle centre (top face - radius). Launch on the first release (section 3.2) or after 3.0 s. Launch angle: random 10-20 degrees left or right of vertical (never 0). Same rule after a net-less restart.

### 4.6 Net (ball-saver) (owner)

- Lett: net always on, unlimited catches, every level.
- Vanlig: net unlimited in world 1 (levels 1-5) and on every 5th level (breathers). Other levels: 3 charges.
- Catch: when the ball bottom reaches y 1540 moving down, it reflects up (`v.y = -|v.y|`), then the 6 degree side-angle rule applies. Speed ramp resets. Soft low "bwomm", net ripples out from the contact point over 400 ms.
- Charges (Vanlig, charged levels): shown as 3 diamond pips on the net (count is shape, not colour). A catch removes one pip with a single crack animation (one flash, not a strobe). At 0 charges the net becomes a dashed outline and no longer catches.
- **Gentle restart** (my reading of the owner's rule: 3 catches, the 4th miss restarts): the ball sinks below y 1700, the scene dims to 60% over 0.6 s, broken bricks float back to their places over 0.8 s, net refills to 3 pips, ball rests on the paddle, dim lifts over 0.4 s. No text, no "game over", no failure sound (a soft rewind whoosh). Total under 2 s.
- Multi-ball (Ekko): a catch spends a charge only when exactly one ball is in play. Echo balls never spend charges and never trigger a restart.

### 4.7 Level clear

The level is clear when no breakable brick is left (chrome, switches and portals do not count; ghost bricks do). The last breaking brick triggers slow-mo (section 9), then the win card.

## 5. Elements

### 5.1 Brick types

Every type has a shape cue so colour is never the only cue (rule 36). Suggested colour roles are hints for graphic-designer.

| Code | Name (NO / EN) | Hits | Shape cue | Behaviour | First level (v2) |
|---|---|---|---|---|---|
| `G` | Glass / Glass | 1 | Plain smooth slab, no marks | Breaks on hit | 1 |
| `D` | Dobbel / Double | 2 | Two raised dots side by side; first hit pops one dot and adds a crack | Breaks on 2nd hit | 2 |
| `C` | Krom / Chrome | never | Diagonal stripes + a bolt in each corner | Unbreakable, not counted, bounce gets -3..+3 deg jitter. Komet bounces off it. | 9 (was 4) |
| `T` | Trippel / Triple | 3 | Three dots in a triangle; one pops per hit | Breaks on 3rd hit | 6 |
| `N` | Nova | 1 | Four-point star on the face | On break, 0.15 s later deals 1 hit to its 8 neighbours. A nova set off by a nova waits 0.35 s more, so bursts stay at 3 per second or fewer (rule 37). Blast area: section 15.3.5. | 3 (was 11) |
| `M` | Glider | 1 | Chevrons `< >` on both ends | Slides horizontally at 120 px/s (Lett 80) along its row, reversing at walls, chrome or other bricks. Start direction: toward the field centre (c0-c4 move right, c5-c9 left). | 7 (was 16) |
| `S` | Bryter / Switch | never | Ring with a dot in it (power symbol) | Not counted. A hit toggles which ghost set is solid. 0.5 s cooldown. Full rules incl. auto flip: 16.2.1. | 16 (was 21) |
| `A` / `B` | Skygge / Ghost (set A, set B) | 1 when solid | Set A: dashed outline with square corner marks. Set B: dashed outline with round dots. Solid = filled + outline; phased = outline only, 30% opacity. | Set A starts solid, set B phased. Phased ghosts let the ball through. Counted for clear. | 16 (was 21) |
| `1` / `2` | Ormehull / Portal pair 1, pair 2 | never | Pair 1: single spiral. Pair 2: spiral with a star in the middle | Ball centre entering a portal circle (radius 40) leaves its partner 60 px along its velocity, velocity unchanged; 0.4 s per-ball cooldown; max 3 hops between paddle or brick touches (16.2.3). Not counted. | 21 (was 26) |
| `O` | Magnet / Magnet | 2 | Ring with four inward chevrons | Bends a ball within 170 px toward itself (16.2.5). | 26 (v3) |
| `K` + `+` | Sjef / Mini-boss | 10-30 (per level) | 3x2 cells, a core ring in the middle, one notch per HP around it | Section 15.3.6. `K` = top-left anchor cell, `+` = the other 5 cells it covers. | 5 |

Carrier mark: a lowercase letter (`g`, `d`, `t`, `n`, `m`) is the same brick carrying a power-up capsule, drawn with a small 5-point star inlay. The capsule drops when the brick breaks. The level data says which power-up its carriers hold: v2 uses a `carriers` list assigned round-robin in reading order (section 15.8).

Level mechanic (not a brick code): **Marsj / March** (first level 11), a whole block of rows moves side to side and steps down like an invader formation (section 15.3.7).

### 5.2 Power-ups (own names, own twists)

Capsule: 112 x 56 pill with the power-up icon (shape-coded). Falls at 240 px/s (Lett 180). Lett magnet: below y 1100 the capsule drifts toward the paddle x at up to 400 px/s, so a 4-year-old catches nearly every one. Caught when its rect overlaps the paddle rect grown by 20 px. Missed capsules fade at y 1600; no penalty. Max 3 capsules falling at once (more is not possible with current carrier counts). Same power-up again = timer/count refresh, not stack.

| Name (NO / EN) | Icon | Effect | Twist | First level |
|---|---|---|---|---|
| **Komet / Comet** (VERTICAL SLICE) | Ball with a swept tail | For 8 bricks or 6 s (Lett: 10 bricks or 8 s), whichever ends first, the ball breaks any breakable brick in ONE hit and passes through it without bouncing. Still bounces off walls, chrome, switches, paddle, net. Against a boss: 2 damage and a bounce (uses one brick of the count). | Remaining bricks shown as small sparks orbiting the ball, one winks out per brick: the count is a shape, not a number. | 1 (was 3) |
| Bredvinge / Wide Wing | Paddle with two wings | Paddle width x1.5 for 15 s (Lett x1.3 for 20 s), grows over 0.3 s, max 560 px. | Five "feathers" on each wing fold away one by one as time runs out: a countdown with no digits. | 8 |
| Ekko / Echo | Three overlapping circles | Two translucent echo balls split from the main ball at -20 and +20 degrees. | Echoes fade after 10 s and can never be "lost": falling echoes just dissolve. If the main ball falls through an empty net while an echo lives, the oldest echo becomes the main ball. Echoes break bricks and hit bosses like the main ball; they never home or aim (section 15.3.4). Max 3 balls. | 4 (was 13) |
| Saktetid / Tape Slow | Cassette reel | Ball speed x0.65 for 10 s (Lett x0.75). | Music and effects pitch down like a slowed tape, then wind back up over 0.5 s. | 18 (later phase) |
| Neonpuls / Neon Pulse | Paddle with three arcs above it | 6 waves, 1.0 s apart: each deals 1 hit to the lowest breakable brick in every column the paddle overlaps. No tap needed. | Fires on its own, so it adds no input and no reflex demand. A boss in that column counts as the lowest brick if it is lowest. | 13 (was 23) |
| Skjoldnett / Shield Net | Net with a plus | Vanlig: +1 net charge (max 3). | In Lett (net already unlimited) carriers of this type drop Bredvinge instead. | 23 (was 28, later phase) |

## 6. Progression

### 6.1 Rules

- 6 worlds x 5 levels = 30 hand-made levels, then endless.
- **v2 rhythm (section 15):** every world brings three new things, one per level, and ends in a boss. **Level 1** new brick, **level 2** new brick or level mechanic, **level 3** new power-up, **level 4** combines, **level 5** mini-boss (Vanlig net unlimited, more capsules, so it keeps the breather's safety while being the world's climax). (v1 rhythm, superseded: one brick, one power-up, breather.)
- **No sequential lock** (my call, owner said "all levels open" for stand-alone): any unlocked level can be picked from the map. The map pulses the lowest uncleared level (1 Hz glow) as the suggestion. Nothing is ever shown locked (no padlocks, rule 22 counter-consideration 1).
- **Free part (owner):** the game holds one flag, `full_unlock: bool`, default `true`. The MWM Play adapter sets it on `enter()` through a public hook `set_full_unlock(on: bool)` (same style as `set_shell_inset`). The game does not check purchases itself.
  - `full_unlock == false`: the map shows only world 1 levels 1-3. Level nodes 4-5, world arrows and the endless page are not drawn at all. Clearing level 3 shows the normal win card with replay + home only (no "next") and emits `free_levels_finished`; the shell then shows its "Du har spilt alle banene her" card.
  - `full_unlock == true`: all 30 levels and endless.
- The stand-alone build never calls the hook, so it is fully open (owner's own copy).

### 6.2 Worlds

| World | Name (NO / EN) | Setting cue for graphic-designer | New brick (L1) | New power-up (L3) |
|---|---|---|---|---|
| 1 | Neonstranda / Neon Beach | Sunset sun, palm silhouettes, grid sea | Glass (L1), Double (L2), Nova (L3) | Komet (L1), Ekko (L4); boss Solkjernen (L5) |
| 2 | Rutenettbyen / Grid City | Night skyline, neon signs | Triple (L6), Glider (L7), Chrome (L9) | Bredvinge (L8); boss Nattaxi (L10) |
| 3 | Arkadehallen / Arcade Hall | Giant cabinets, pixel stars | March block (L11, L12) | Neonpuls (L13); boss Arkadekongen (L15) |
| 4 | Nattveien / Night Highway | Endless road, passing lights | Switch + Ghost (L16) | Saktetid (L18); boss (L20) |
| 5 | Krystallgrotta / Crystal Cave | Glowing crystals, mist | Portal (L21) | Skjoldnett (L23); boss (L25) |
| 6 | Stjerneporten / Star Gate | Space, rings, nebula | Magnet (L26), two march blocks (L27) (v3, 16.1) | Final boss Neonnova (L30) |

v2 (section 15): elements arrive 2-3 times sooner than in v1, so world 1 alone shows Glass, Double, Nova, Komet, Ekko and a boss. Chrome moved to level 9 because a wall that never breaks is the least fun thing to meet early.

### 6.3 Level table

**Superseded 2026-10-06 by section 15.6** (levels 1-15, simulated) and 15.9 (levels 16-30, later phase). The v1 table is in git history (commit `827bbc8` and earlier).

### 6.4 Maps

**Superseded 2026-10-06 by section 15.7** (maps for levels 1-15, revised world 1 included). Level data format additions are in 15.8. The v1 world 1 maps that shipped in the slice are in git history (commit `827bbc8`, `scripts/NbLevels.gd`).

### 6.5 Endless generator ("Neonveien", after the 30 levels)

**Superseded 2026-10-07 by section 16.9** (one spec covering all elements). Kept below for history.

Shown as the last page of the world map. Available when `full_unlock` is true and world 1 has been cleared (my call). Endless level k = 1, 2, 3 ... is deterministic: same k, same layout.

1. `seed = hash("neon_bricks_endless_" + str(k))`; RNG from that seed. `d = min(1.0, (k - 1) / 30.0)`.
2. Elements allowed: those first introduced in levels the player has cleared (save file). World 1 elements always.
3. Rows used: `4 + round(4 * d)`, starting at r2. Lowest brick row never below r9.
4. Pick one template for the left half (columns 0-4): full block, checker, stripes, diamond, pyramid, frame. Remove 10% of filled cells at random. Mirror to columns 5-9.
5. Per filled cell, roll type: Chrome `0.05 + 0.10d` (never in the lowest used row); Triple `0.10d`; Double `0.20 + 0.15d`; Nova `0.08` (max 6 per level, v2); else Glass. v2: if March is allowed, 25% of levels make the formation a march block (only when the formation is at most 8 columns wide); every 10th endless level is a boss level using the L15 boss rules with HP `20 + k/5` (Vanlig) or `12 + k/10` (Lett), max 40. Gliders: if allowed, 30% of levels turn one full row into gliders (that row is not mirrored-locked). Switch + ghosts: if allowed, 30% of levels: switches at the two outer cells of one row, one ghost row of set A, one of set B. Portals: if allowed, 25% of levels: one pair in two empty mirrored cells.
6. Carriers: `2 + floor(2d)` breakable cells in the lower half of the formation, each with a random allowed power-up.
7. Validity: breakable count 20-48; chrome at most 20% of filled cells; no breakable brick whose 4 neighbours are all chrome or wall (if found, turn one chrome neighbour into Double). If invalid, reroll with seed + 1, up to 20 tries, then fall back to the "pyramid" template with Glass only.
8. Speeds: Lett 570; Vanlig `880 + 10 * floor(k / 5)`, max 960. Paddle: Lett 400, Vanlig 240. Net: Vanlig 3 charges; every 5th endless level is a breather (`d` halved, net unlimited).
9. Save the highest endless k reached; the page offers "continue from k" and "start at 1" as two icons.

## 7. Numbers (single balance table)

All tunables live in one const block or data file (studio rule). Keys are suggestions.

| Key | Lett (4-7) | Vanlig (8+) | Unit | Note |
|---|---|---|---|---|
| `FIELD_LEFT / RIGHT / TOP` | 40 / 1040 / 280 | same | px | Inner wall edges |
| `GRID_COLS / ROWS` | 10 / 12 | same | | |
| `CELL_W / CELL_H` | 100 / 52 | same | px | Grid origin (40, 340) |
| `BRICK_W / BRICK_H` | 92 / 44 | same | px | Hit box |
| `PADDLE_Y` | 1420 | same | px | Centre; top face 1402 |
| `PADDLE_H` | 36 | same | px | |
| `PADDLE_W` | 400 | 280 (W1-2), 260 (W3-4), 240 (W5-6, endless) | px | |
| `PADDLE_W_MAX` | 560 | 560 | px | With Bredvinge |
| `PADDLE_EDGE_GRACE` | 22 | 13 | px | Extra catch width each side |
| `DRAG_GAIN` | 1.25 | 1.25 | x | Relative drag, as in Krypton Egg |
| `PADDLE_MAX_SPEED` | 6000 | 6000 | px/s | Only guards against glitchy touch events |
| `BALL_RADIUS` | 22 | 22 | px | |
| `BALL_SPEED_BASE` | 520-570 by world | 720-880 by world (v2) | px/s | Table 15.6 |
| `BALL_SPEED_MIN / MAX` | 300 / 1000 | same | px/s | Hard clamps |
| `RAMP_PROGRESS` (v2) | off | +15% at 100% broken | | Replaces the v1 time ramp; section 15.4 |
| `SUBSTEP_MAX_PX` | 8 | 8 | px | |
| `MAX_BOUNCE_DEG` | 55 | 60 | deg | From vertical at paddle edge |
| `PADDLE_ENGLISH` | 0.05 | 0.10 | x paddle_vx | |
| `MIN_SIDE_DEG` | 6 | 6 | deg | After paddle and net bounces |
| `MIN_FLAT_DEG` | 20 | 20 | deg | Floor from horizontal, always |
| `CHROME_JITTER_DEG` | 3 | 3 | +- deg | |
| `LOOP_REPEATS / WINDOW` | 3 / 10 s | same | | Loop detector |
| `DRY_SPELL_S / REPEAT_S` | 10 / 5 | same | s | |
| `NUDGE_DEG` | 9 | 9 | deg | |
| `ASSIST_S` | 15 | 30 | s | No brick broken -> aim next bounce |
| `AUTO_LAUNCH_S` | 3.0 | 3.0 | s | |
| `LAUNCH_DEG` | 10-20 | 10-20 | deg | Random side |
| `NET_Y` | 1540 | 1540 | px | |
| `NET_CHARGES` | unlimited | unlimited in W1 + breathers, else 3 | | |
| `LOSS_Y` | 1700 | 1700 | px | Ball centre |
| `RESTART_DIM / REWIND / LIFT` | n/a | 0.6 / 0.8 / 0.4 | s | Gentle restart |
| `CAPSULE_SIZE` | 112 x 56 | same | px | |
| `CAPSULE_FALL` | 180 | 240 | px/s | |
| `CAPSULE_MAGNET` | below y 1100, 400 px/s | off | | |
| `CAPSULE_CATCH_GROW` | 20 | 20 | px | |
| `KOMET_BRICKS / SECONDS` | 10 / 8 | 8 / 6 | | Ends at whichever first |
| `BREDVINGE_SCALE / SECONDS` | 1.3 / 20 | 1.5 / 15 | | |
| `EKKO_BALLS / SPLIT_DEG / LIFE` | 2 / 20 / 10 s | same | | |
| `SAKTETID_SCALE / SECONDS` | 0.75 / 10 | 0.65 / 10 | | |
| `NEONPULS_WAVES / INTERVAL` | 6 / 1.0 s | same | | |
| `SKJOLDNETT_CHARGES` | becomes Bredvinge | +1, max 3 | | |
| `GLIDER_SPEED` | 80 | 120 | px/s | |
| `NOVA_DELAY / CHAIN_DELAY` | 0.15 / 0.35 | same | s | Keeps bursts <= 3/s |
| `SWITCH_COOLDOWN` | 0.5 | 0.5 | s | |
| `PORTAL_RADIUS / EXIT_OFFSET / COOLDOWN` | 40 / 60 / 0.4 s | same | | |
| `MAX_FLASHES_PER_S` | 3 | 3 | | Global flash limiter, rule 37 |
| `HOLDOVER_MS` | 300 | 300 | ms | Rule 8 |
| `FREE_LEVELS` | 3 | 3 | | Only used when `full_unlock` is false |

v2 (action pass): combo, finale, boss, march and the other new keys are in the const block in section 15.4.

## 8. Screens and session shape

### 8.1 World map

One world per page: the world's scene in the background, 5 level discs (diameter 200, hit area 240) on a neon road climbing the screen between y 400 and 1500, never in the top-left 232 square or below y 1664. Cleared level: disc holds a star shape. Suggested next level: soft 1 Hz pulse (well under 3 flashes/s). World change: left and right arrow discs (200 px) at y 1560, x 160 and 920. No swipe, no scroll (rule 20). Stand-alone only: gear disc at top-right opens settings (section 10.2).

### 8.2 First 60 seconds (no text anywhere)

- 0 s: first ever launch skips the map and opens level 1 directly. Camera sweep 1.0 s (cut under "Mindre bevegelse"). Ball rests on the paddle.
- 1.0 s: a hand icon slides left-right in the drag zone (loop 1.6 s) until the first drag. Voice line (if recorded) "Dra fingeren hit og dit" (action word last in spirit, rule 17).
- 3.0 s: ball launches by itself if the child has not tapped.
- First brick break: big satisfying break (section 9). Each following brick before the next paddle touch plays one step higher in the scale.
- Ball misses: net catches it with a soft "bwomm" and ripple, play continues. The child learns the net is friendly.
- About 15-25 s: a carrier in the lower row drops the first Komet capsule; the Lett magnet pulls it to the paddle.
- About 59 s (Lett, v2 level 1, my calc): last brick, slow-mo, win card.
- Idle hint: if no drag for 7 s during play, the hand icon returns (rule 18).

### 8.3 Win card (natural stopping point, owner)

- Appears 1.2 s after the last brick. Fades in over 250 ms (instant under "Mindre bevegelse").
- Shows: one big star landing in the middle, a small 3D model of the level's brick picture, and three icon discs at y 1300: replay (x 270, 200 px), map/home (x 540, 200 px), next (x 810, 240 px, the most visible). No text.
- Spoken praise of the action (rule 32), e.g. "Du knuste alle klossene!" ("You smashed every brick!").
- Never auto-advances (rule 26). This is where the shell's play limit may end the session; the game emits `level_card_shown(level_id)`.
- After level 30: "next" opens the endless page. After level 3 with `full_unlock` false: no "next" disc, emit `free_levels_finished`.

### 8.4 Session shape

A level takes about 1-2.5 min. A child plays 3-6 levels per sitting and stops at a card. Pull to come back: the next world's new scene and the one new brick or power-up waiting in it. No streaks, daily rewards, timers or "come back" messages (rule 27).

### 8.5 Save (`user://neon_bricks_save.json`)

```json
{
  "version": 1,
  "cleared": [1, 2, 3],
  "endless_best": 0,
  "difficulty": "lett",
  "settings": {"sfx": true, "music": true, "haptics": false, "less_motion": false}
}
```
Save on level clear, on difficulty or setting change, on leaving and on `NOTIFICATION_APPLICATION_PAUSED`. Mid-level state is not saved: a left level starts fresh next time (quitting costs nothing, rule 28). `settings` are only read in the stand-alone build; inside MWM Play the shell's settings win.

## 9. Feel

"Mindre bevegelse" (less motion, rule 39) column: what replaces the effect.

| Event | Visual | Sound | Haptic (only if on; default off, rule 33) | Mindre bevegelse |
|---|---|---|---|---|
| Touch-down in drag zone | Paddle glow +40% for 80 ms | Quiet hum-up, < 80 ms | none | same |
| Paddle hit | Paddle squash to 90% height and back in 100 ms; small spark ring at contact | Synth "bop", pitch by hit offset (centre low, edges high) | 12 ms tick | No squash; spark ring stays (it is not motion of the screen) |
| Wall hit | Wall segment glows 120 ms | Soft tick | none | same |
| Brick hit, not broken | Brick squash 90% for 80 ms; dot pops off (Double/Triple) | Glassy "tink" | none | No squash; dot pops |
| Brick break | GPU shards: 24 particles (v2: 32 at combo 5+, 40 at combo 10+), 0.5 s life, gravity toward camera; local glow on the brick area only | Pentatonic note, one step up per combo step (v2, section 15.3.1: max 12 steps, resets when the combo drops, NOT on paddle touch) | none | No particles: brick fades out in 150 ms |
| Chrome hit | Spark at contact, no glow | Metallic "ting" | none | same |
| Nova blast | Ring wave over the 3x3 area, 300 ms | Low "whump" | 20 ms | No ring wave, neighbours just break |
| Net catch | Net ripple from contact, 400 ms; pip cracks (Vanlig) | Soft low "bwomm" | 25 ms | No ripple; pip just disappears |
| Capsule falls | Capsule spins slowly (0.5 rev/s) | Gentle shimmer loop | none | No spin |
| Capsule caught | Paddle flashes once in the power-up's icon shape, 200 ms | Rising arpeggio, 400 ms | 15 ms | same (one flash only) |
| Komet active | Ball gets a tail and orbiting sparks | Whoosh loop | none | Tail stays, no orbit motion (count shown as static dots) |
| Loop nudge | Short spark trail | Soft "zip" | none | Trail only |
| Last brick | Time scale 0.25 for 0.6 s real time, then back to 1.0 over 0.3 s; camera pushes in 8% toward the brick; screen shake 10 px for 250 ms | Music drops to a filtered pad, then a 2 s win arpeggio | 40 ms | Slow-mo kept, no push-in, no shake |
| Gentle restart | Dim + bricks float back (section 4.6) | Rewind whoosh | none | Instant dim and reset, no float |
| Level intro | Camera sweep from a low angle to play angle, 1.0 s | Rising synth swell | none | Cut |
| Idle during play | Camera drifts +-1.5 deg yaw on a 12 s cycle | Music 90-100 BPM synthwave, at least 6 dB under effects | | No drift |

Screen shake elsewhere: Nova 6 px for 180 ms. All shake is off under "Mindre bevegelse" (owner).

Flash safety: a global limiter allows at most 3 bright flashes per second (rule 37); any extra break inside the same 333 ms gets particles and sound but no glow spike. No full-screen flashes ever. No high-contrast flickering stripes (rule 38): the chrome stripe pattern is static and low contrast.

Performance hint for the builder: pool 8 particle emitters, at most 6 alive at once; this is a design ceiling, the phone PerfOverlay decides.

## 10. Difficulty settings

### 10.1 Lett (ages 4-7, default) vs Vanlig (ages 8+)

| Aspect | Lett | Vanlig |
|---|---|---|
| Net | Unlimited, every level | Unlimited in world 1 and breathers; 3 charges elsewhere, then gentle restart |
| Ball speed | 520-570 px/s, no ramp | 720-880 px/s (v2), +15% at 100% of bricks broken (progress ramp) |
| Paddle | 400 px | 280 -> 240 px |
| Edge grace | full ball radius | 0.6 ball radius |
| Max bounce angle | 55 deg | 60 deg |
| Aim assist | after 15 s without a break | after 30 s |
| Capsules | slower + magnet | plain |
| Power-ups | longer, softer (table 7) | standard |
| Same 30 maps | yes | yes |

Rule 16 (no reflex demands at the easiest level) holds: in Lett a miss costs nothing, the ball is slow and the paddle covers 40% of the field. Rule 31 (no game over for 4-7) holds in both settings: there is no game over screen at all.

### 10.2 Where the setting lives (needs the owner, see open questions)

My default: inside MWM Play, the parent area gets a row "Neon Bricks: Lett / Vanlig" and the adapter calls `set_difficulty(easy: bool)` on `enter()`. In the stand-alone build, the gear on the world map opens a small panel with Lett/Vanlig, sound, music, vibration and "Mindre bevegelse" (no gate: it is the owner's own copy). Changing difficulty takes effect from the next level start.

Builder note 2026-10-07 (QA 2026-10-06 finding 4): the stand-alone panel has Lett/Vanlig, sound on/off + volume, music on/off + volume and "Mindre bevegelse". It has **no vibration row**: vibration would need the Android `VIBRATE` permission, and the game ships with no permissions. `haptics_on` stays in the save and as the shell hook `set_haptics_on()`, unused until haptics are wanted (then add the permission and the row together). The haptic column in sections 9, 15.5 and 16.10 is therefore not built.

## 11. Shell hooks (summary for the builder)

- Read `Engine.get_meta(&"mwm_play_shell")`: hide own home disc, own sound button and own settings gear.
- `set_full_unlock(on: bool)` (default true), `set_difficulty(easy: bool)` (default Lett), `set_shell_inset(Vector2(232, 232))` (no-op here, nothing sits there anyway), plus the shell's four settings (sfx, music, haptics, less motion).
- Signals up: `level_card_shown(level_id: int)`, `free_levels_finished()`.
- Public `save_game()` for the adapter's `exit()`.
- Unique class names (the sync script prefixes later).

## 12. Vertical slice (what godot-android-dev builds first)

In: world 1 map page, levels 1-5 exactly as in 6.4, paddle with relative drag, one ball, Glass + Double + Chrome, Komet capsule and effect, net (unlimited in world 1, but the 3-charge mode and gentle restart are also built and covered by a headless test with a test-only level flag, because Vanlig needs them from level 6), anti-stuck rules 1-6, aim assist, win card with the three icon discs, Lett/Vanlig switch, `full_unlock` flag and both signals, "Mindre bevegelse", save file, flash limiter, auto-launch, idle hand hint, shell home square kept free.

Out: worlds 2-6, other bricks and power-ups, endless, voice lines (blocked on a native Norwegian voice, see MWM Les), store art.

Status 2026-10-06: the slice shipped (QA `docs/QA_SLICE_2026-10-06.md`). The next build is the action pass, section 15.10.

Slice acceptance hints for game-qa: Lett level 1 clears with no instruction (kids walk-through, sound off); no gameplay touch target below y 1664 or inside 232x232; never more than 3 flashes in any 1 s window during a Komet run through level 3; ball never travels flatter than 20 degrees (log check); level 4 never has a ball trapped above chrome for more than 15 s.

## 13. Play together tip (rule 42, draft)

"Bytt på: når en kloss med stjerne faller ned, er det den andres tur å styre." ("Take turns: when a star brick drops a capsule, the other person steers.")

## 14. Open questions for the owner

1. **Difficulty setting placement:** a "Lett / Vanlig" row in the MWM Play parent area (needs a small shell change) as I propose, or a child-facing two-icon choice inside the game?
2. **Net charges:** I read "3 charges, then gently restart" as: the net catches 3 times, the 4th miss restarts the level from full bricks. Correct, or should the 3rd catch already restart?
3. **Endless:** available after world 1 is cleared and only in the paid part (my default)? Or only after all 30 levels?
4. **No level order:** in the full game any level can be picked from the map, nothing ever shown locked. OK, or should worlds open one after another?

---

## 15. Action pass 2026-10-06 (owner: "boring fast")

Owner, verbatim, after playing the world 1 slice: "Add more levels on Neon Bricks. Also should have more elements and more action. It gets boring fast." This section is the fix. Where it disagrees with an older section, this section wins. Owner rules that stay untouched: the net rules in 4.6 (owner), all levels open, the free part (levels 1-3), the win card as stopping point, no shake under "Mindre bevegelse", and the child rules for Lett (no reflex demands, no game over, at most 3 flashes per second, colour never the only cue, touch targets at least 200 px).

### 15.1 Diagnosis: why world 1 gets boring

Measured with `tools/action_sim.py` (my calc, 80 runs per level and setting, near-perfect paddle bot, so real players are slower and the dead stretches are longer):

| v1 level | Bricks | Median clear Lett / Vanlig | Breaks per second (Vanlig) | Longest gap between breaks, median (Vanlig) | Time spent on the last 3 bricks (Vanlig) | Capsules caught |
|---|---|---|---|---|---|---|
| 1 | 14 | 57 / 48 s | 0.31 | 12.0 s | 14.7 s (30%) | 0 |
| 2 | 22 | 100 / 83 s | 0.28 | 15.0 s | 20.6 s (25%) | 0 |
| 3 | 32 | 104 / 84 s | 0.39 | 16.0 s | 21.4 s (25%) | 1 |
| 4 | 22 | 95 / 79 s | 0.29 | 19.0 s | 22.0 s (28%) | 2 |
| 5 | 28 | 79 / 67 s | 0.44 | 14.6 s | 19.2 s (29%) | 2 |

1. **Too few events.** One brick breaks every 2.3-3.6 s (Vanlig), and every level has a 12-19 s stretch where nothing breaks. Levels 1-2 have no capsule at all; levels 3-5 have 2 carriers each, so a capsule falls about once a minute (my calc).
2. **The end drags.** A quarter to a third of every level is spent hunting the last 3 bricks (19-22 s in Vanlig, up to 29 s in Lett).
3. **New things arrive too late.** v1 gave one new brick and one new power-up per world: a player who stops after world 1 never sees Nova (level 11), Ekko (13) or Glider (16). World 1's only "new" bricks were Double and Chrome, and Chrome is a wall that never breaks.
4. **Nothing escalates inside a level.** The ball is slow (Vanlig 680 px/s crosses the 1080 px from paddle to top row in 1.6 s), the v1 ramp adds at most 15% and resets on every net catch, and nothing moves except the ball. A hit 40 bricks into a chain sounds the same as the first one, except for the pentatonic step, which resets on every paddle touch.

### 15.2 What changes (summary)

| # | Change | Why |
|---|---|---|
| 1 | **Combo meter "Kjede"** with tiers, rising pitch, bigger shards, a capsule every 8 combo (Lett 6), slow-mo on big chains | Turns quick breaks into a visible, audible streak and feeds more capsules |
| 2 | **Denser levels**: 30-54 bricks instead of 14-32, carriers from level 1, and every level has a combo bonus pool | 2-3x more breaks per second |
| 3 | **Elements pulled forward**: Komet L1, Nova L3, Ekko L4, Glider L7, Neonpuls L13 | Something new every level; Nova chains are the cheapest "action" there is |
| 4 | **Mini-boss** at the end of every world (L5, L10, L15) | Each world ends on a climax |
| 5 | **March block** (L11): a formation that slides and steps down | Moving targets; escalation inside the level |
| 6 | **Progress speed ramp** (Vanlig): +15% by the last brick, no reset | The level speeds up as it empties |
| 7 | **Finale helper**: at 3 bricks left (Lett 4) the ball aims and gently homes, with line-of-sight | Kills the last-bricks drag |
| 8 | **Vanlig base speed** up: 720 / 760 / 800 px/s in worlds 1-3 (v1: 680 / 720 / 760). Lett unchanged | Vanlig feels busy; Lett stays calm |

Result (my calc, same sim, section 15.6): the new levels 1-15 break 0.62-1.58 bricks per second in Vanlig (v1: 0.28-0.44), the longest gap is 3.7-9.8 s (v1: 12-19 s), and the last 3 bricks take 7-22% of a non-boss level, 4-8 s (v1: 25-30%, 15-22 s).

### 15.3 New and changed mechanics (exact rules)

#### 15.3.1 Combo meter "Kjede" (all levels, both settings)

- **Combo count:** +1 for every breakable brick broken AND every hit on a boss. If no such event happens for `COMBO_WINDOW_S` (Lett 3.0 s, Vanlig 2.0 s, game time), the combo drops to 0. A paddle touch does **not** reset it (change from v1). Nova chain breaks and Neonpuls hits count.
- **Pitch:** a brick break plays pentatonic step `min(combo - 1, 11)` (12 steps, two and a half octaves). This replaces the v1 "steps since the last paddle touch".
- **Meter:** a strip of 10 segments on the top rail, x 290-1040, y 248-272 (outside the 232 px home square, nothing tappable). Segment n lights when combo >= n. At combo 10+ all segments are lit and get a steady outline glow ("Neonrush"). When the combo drops, the strip drains from right to left over 0.3 s. The count is a shape (segments), not only a colour.
- **Tiers:**

| Tier | Combo | Shards per break | Ball trail | Sound | Screen |
|---|---|---|---|---|---|
| Glød | 1-4 | 24 (v1) | normal | note only | none |
| Varm | 5-9 | 32 | 1.5x long | note + soft sub-bass thump | none |
| Neonrush | 10+ | 40 | 1.5x long, rim colour shifts toward white-hot | note + hi-hat layer joins the music | Steady rim glow on the field frame (no flashing). Vanlig only: 3 px shake for 60 ms per break, at most 3 per second |

- **Combo capsule:** each time the combo reaches a multiple of `COMBO_DROP_EVERY` (Lett 6, Vanlig 8), a capsule spawns at the centre of the brick that made that step (for a boss hit: at the bottom centre of the boss). Its kind is the next entry of the level's `bonus_pool`, round-robin from index 0 at level start. `CAPSULE_MAX` (3 falling at once) still holds; a drop over the cap is skipped and the index does not advance.
- **Chain slow-mo:** when 4 or more bricks break within 0.4 s of game time (Nova chains, Komet ploughs), time scale goes to 0.5 for 0.25 s real time, then back to 1.0 over 0.15 s. Cooldown 3 s. Never during the last-brick slow-mo. Kept under "Mindre bevegelse" (it is not screen motion).
- **Flash safety:** every glow spike from combos, boss hits and phase roars goes through the existing limiter (at most 3 per second). Shards and sound are never limited.

#### 15.3.2 Progress speed ramp (Vanlig only)

`speed = base x (1 + RAMP_PROGRESS x broken / total)`, with `RAMP_PROGRESS` 0.15, `broken` = breakable bricks broken so far (a boss counts as 1 when it dies), `total` = breakable bricks at level start plus boss minions spawned so far. Clamped to `BALL_SPEED_MAX` 1000. No reset on net catch; reset only on gentle restart (bricks come back, so `broken` is 0 again). The v1 time ramp is removed. Lett: no ramp.

#### 15.3.3 Finale helper "Siste tre"

Active while `breakable_left <= FINALE_LEFT` (Lett 4, Vanlig 3) and the level started with at least 10 breakable bricks. A boss counts as one brick.

1. Every main-ball paddle bounce is an aimed bounce at `aim_point` (15.3.4), angle clamped to +-MAX_BOUNCE_DEG.
2. **Homing:** while the main ball moves up (`v.y < 0`), its velocity turns toward the current direct target by at most `FINALE_TURN_DEG_S` (Lett 40, Vanlig 30 deg/s). The target is re-picked every 0.25 s with `aim_point(direct_only = true)`; no direct target means no homing. The 20 degree flat-floor rule is applied after the turn.
3. Remaining bricks pulse their glow at 1 Hz (well under the flash limit); the music adds a rising filter sweep.
4. Echo balls never aim or home.

Sim effect (my calc): the last 3 bricks take 3.5-8.5 s in Vanlig instead of 15-22 s (boss levels excepted: there the boss itself is among the last bricks, and that is the fight).

#### 15.3.4 Aim point with line of sight (used by aim assist 4.4 rule 5 AND the finale)

`aim_point(from, direct_only)`:
1. Sort alive breakable bricks (boss included) by distance from the ball centre.
2. Return the first brick whose centre has a **clear path**: sample the segment from ball centre to brick centre every 10 px; the path is blocked only if the ball circle (radius 22) at a sample overlaps a non-breakable piece (chrome, switch) or comes within 62 px of a portal centre (v3, 16.2.3). Breakable bricks never block, because hitting any of them is progress.
3. If none and not `direct_only`: try a **one-wall bank shot** for each brick in the same order: mirror the brick centre over x = 62 (left wall + radius) or x = 1018 (right wall - radius); the shot is valid if both legs (ball to wall point, wall point to brick) are clear. Aim at the mirrored point.
4. If still none: no aim; the normal bounce and the dry-spell nudges take over.

Why: in v1 the assist aims at the nearest brick even when a chrome post sits in between; the sim then bounced between paddle and chrome for 15 minutes on a chrome level (my calc, level 9 draft, 3 of 6 seeds).

#### 15.3.5 Nova blast area

A Nova blast hits every alive breakable brick or boss whose rect intersects the blast rect: 300 x 156 px centred on the Nova's centre (3 x 3 cells). On the grid that is exactly the 8 neighbours; it also defines hits on moving bricks and bosses. Delays as in 5.1 (0.15 s, chained Nova +0.35 s). A boss takes 1 damage per blast.

#### 15.3.6 Mini-boss `K` (levels 5, 10, 15)

- **Shape:** 3 x 2 cells. Map code `K` in the top-left cell, `+` in the other 5 cells. Hit box 292 x 96 px (same 4 px inset as bricks). Looks (graphic-designer): one big slab with a core ring in the middle and one notch per HP around the ring; a notch goes dark per hit, so health is a shape. No face that scares (my call for 4-year-olds).
- **HP** (Lett / Vanlig): L5 10 / 14, L10 14 / 20, L15 20 / 30.
- **Damage:** ball or echo contact 1 (the ball bounces); Komet 2 per contact, bounces, uses one brick of the Komet count; Nova blast 1; Neonpuls wave 1.
- **Motion:** glides along its rows at `speed` (L5 60 / 90, L10 80 / 120 px/s), starting to the right, reversing at walls and at other bricks, like a Glider. L15's boss sits inside the march block and has no motion of its own.
- **Phases:** phase 1 when HP <= floor(2/3 x max), phase 2 when HP <= floor(1/3 x max). Each phase change, once: a "roar" (low synth swell 0.6 s, the core ring brightens once, through the limiter), own glide speed x1.25, one capsule from the bonus pool at the boss's bottom centre, and if the level has `minions: true`, up to 4 Glass **minions** appear in the empty cells of the grid row just below the boss's bottom edge, columns (boss column - 1) to (boss column + 3), skipping cells that overlap a ball or a capsule. In a march level the minions join the march block (placed on the block's current offset). Minions fade in over 0.3 s, are solid at once and count for the clear. Under "Mindre bevegelse" they appear without the fade.
- **Defeat:** the boss counts as 1 breakable brick. When it dies: 3 shard bursts staggered 0.15 s apart (limiter applies), a deep "whump", and if it is the last brick the normal last-brick slow-mo. Otherwise play continues.
- **Lett:** same rules with lower HP and speed; the net is unlimited, so the boss can never "win".

#### 15.3.7 March block "Marsj" (levels 11, 12, 14, 15)

- Level field `march: {"rows": [first, last], "floor_y": px}`. Every piece in those rows at level start (any brick, chrome, the boss) belongs to the block and moves with it.
- **Sideways:** `MARCH_SPEED` (Lett 40, Vanlig 70 px/s), starting to the right. When the outer edge of the block's leftmost or rightmost **alive** piece reaches x 44 or x 1036, the block reverses. Dead pieces do not count, so a narrowed block travels further.
- **Step down:** at each reversal, if the lowest alive piece's bottom + 26 <= `floor_y`, the whole block moves down 26 px over 0.25 s. At the floor it keeps sliding but stops stepping. `floor_y` <= 1000 keeps at least 400 px between the block and the paddle top (1402), so it is never a reflex demand.
- A piece moving into the ball uses the existing push-out rule (4.4).
- Feel: a soft two-note "tick-tock" on each step down; bricks lean 3 degrees in the move direction (graphic-designer's call).

#### 15.3.8 Mixed carriers and bonus pool

`carriers`: list of power-up kinds, assigned to the level's carrier cells round-robin in reading order (r0 left to right, then r1 ...). `bonus_pool`: kinds used by combo capsules and boss phases. Kinds available in levels 1-15: `komet`, `ekko`, `bredvinge`, `neonpuls`. Same power-up again = refresh, not stack (5.2). Ekko with echoes alive: refresh their life to 10 s, no new balls.

### 15.4 Numbers (paste into NbBalance; Lett / Vanlig)

```
# --- Action pass v2 (GDD 15) ---
const COMBO_WINDOW_S_LETT: float = 3.0
const COMBO_WINDOW_S_VANLIG: float = 2.0
const COMBO_DROP_EVERY_LETT: int = 6
const COMBO_DROP_EVERY_VANLIG: int = 8
const COMBO_TIER_WARM: int = 5
const COMBO_TIER_RUSH: int = 10
const COMBO_SEGMENTS: int = 10
const COMBO_METER_RECT: Rect2 = Rect2(290, 248, 750, 24)
const COMBO_DRAIN_S: float = 0.3
const NOTE_STEPS_MAX: int = 12            # was 8
const SHARDS_WARM: int = 32
const SHARDS_RUSH: int = 40
const TRAIL_WARM_SCALE: float = 1.5
const RUSH_SHAKE_PX: float = 3.0          # Vanlig only, off under less motion
const RUSH_SHAKE_S: float = 0.06
const RUSH_SHAKE_MAX_PER_S: int = 3
const RUSH_RIM_FADE_S: float = 0.5
const CHAIN_SLOWMO_BREAKS: int = 4
const CHAIN_SLOWMO_WINDOW_S: float = 0.4
const CHAIN_SLOWMO_SCALE: float = 0.5
const CHAIN_SLOWMO_S: float = 0.25
const CHAIN_SLOWMO_RETURN_S: float = 0.15
const CHAIN_SLOWMO_COOLDOWN_S: float = 3.0

const RAMP_PROGRESS_LETT: float = 0.0
const RAMP_PROGRESS_VANLIG: float = 0.15  # replaces RAMP_STEP / RAMP_EVERY_S / RAMP_CAP

const FINALE_LEFT_LETT: int = 4
const FINALE_LEFT_VANLIG: int = 3
const FINALE_MIN_START: int = 10
const FINALE_TURN_DEG_S_LETT: float = 40.0
const FINALE_TURN_DEG_S_VANLIG: float = 30.0
const FINALE_RETARGET_S: float = 0.25
const FINALE_PULSE_HZ: float = 1.0
const AIM_LOS_STEP_PX: float = 10.0

const NOVA_BLAST_W: float = 300.0
const NOVA_BLAST_H: float = 156.0
const NOVA_DELAY_S: float = 0.15
const NOVA_CHAIN_DELAY_S: float = 0.35

const GLIDER_SPEED_LETT: float = 80.0
const GLIDER_SPEED_VANLIG: float = 120.0

const MARCH_SPEED_LETT: float = 40.0
const MARCH_SPEED_VANLIG: float = 70.0
const MARCH_STEP_PX: float = 26.0
const MARCH_STEP_S: float = 0.25
const MARCH_WALL_GAP: float = 4.0
const MARCH_FLOOR_MAX_Y: float = 1000.0

const BOSS_W: float = 292.0
const BOSS_H: float = 96.0
const BOSS_PHASE_SPEEDUP: float = 1.25
const BOSS_MINIONS_MAX: int = 4
const BOSS_MINION_FADE_S: float = 0.3
const BOSS_KOMET_DAMAGE: int = 2
const BOSS_ROAR_S: float = 0.6
const BOSS_DEATH_BURSTS: int = 3
const BOSS_DEATH_STAGGER_S: float = 0.15

const EKKO_BALLS: int = 2
const EKKO_SPLIT_DEG: float = 20.0
const EKKO_LIFE_S: float = 10.0
const BALLS_MAX: int = 3
const BREDVINGE_SCALE_LETT: float = 1.3
const BREDVINGE_SCALE_VANLIG: float = 1.5
const BREDVINGE_S_LETT: float = 20.0
const BREDVINGE_S_VANLIG: float = 15.0
const BREDVINGE_GROW_S: float = 0.3
const NEONPULS_WAVES: int = 6
const NEONPULS_INTERVAL_S: float = 1.0
```
Per-level values (speeds, boss HP and speed, march floor) live in the level data (15.8), not here.

### 15.5 Feel additions

| Event | Visual | Sound | Haptic (if on) | Mindre bevegelse |
|---|---|---|---|---|
| Combo step | Meter segment lights (80 ms scale pop 1.0 -> 1.15 -> 1.0) | Pentatonic step (15.3.1) | none | No scale pop |
| Enter Varm (5) | Trail lengthens over 0.2 s | Soft sub thump joins | none | same |
| Enter Neonrush (10) | Meter outline glows, field rim shifts warm over 0.3 s (steady) | Hi-hat layer fades in over 1 bar | 20 ms | same, no shake |
| Combo capsule | Capsule pops out with a small ring (200 ms) | Two-note chime | none | No ring |
| Combo drops | Meter drains right to left, 0.3 s | none (silence is the cue) | none | Instant |
| Chain slow-mo | Time 0.5x for 0.25 s | Music low-pass for the same time | none | Kept |
| Boss hit | Boss squash 95% for 80 ms, one notch goes dark, spark at contact | Heavy "dunk", pitch up per notch lost | 15 ms | No squash |
| Boss phase roar | Core ring brightens once (limiter), minions fade in | Low swell 0.6 s | 30 ms | No fade |
| Boss defeat | 3 shard bursts 0.15 s apart, core ring implodes 0.4 s | Deep whump + rising arpeggio | 40 ms | No implode, bursts kept |
| March step down | Bricks lean 3 deg in move direction | Tick-tock | none | No lean |
| Finale on | Remaining bricks pulse 1 Hz | Filter riser over the music | none | Pulse kept (it is 1 Hz) |
| Echo split | Two translucent balls fan out at +-20 deg | Triple "pip" | 12 ms | same |

### 15.6 Level table, levels 1-15 (replaces 6.3)

Sim columns are (my calc): `tools/action_sim.py --runs 80`, near-perfect paddle bot, unlimited net, chain slow-mo not modelled. Real children are slower; treat them as floors. Restart chance (Vanlig, charged-net levels) is a design target (guess) for the owner's phone test. Boss counts as 1 brick in "Breakable". Net: inf = unlimited (Lett is always inf).

| # | W | Name | New | Breakable | Other | Carriers (in order) | Bonus pool | Lett / Vanlig speed | Vanlig paddle | Vanlig net | Median Lett / Vanlig | p90 Lett / Vanlig | Breaks/s Vanlig | Longest gap Vanlig | Restart chance Vanlig |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | Første lys | Glass + Komet | 32 | | komet x2 | komet | 520 / 720 | 280 | inf | 59 / 46 s | 88 / 67 s | 0.74 | 5.3 s | 0 |
| 2 | 1 | To prikker | Double | 48 | | komet x2 | komet | 520 / 720 | 280 | inf | 72 / 59 s | 123 / 96 s | 0.86 | 7.9 s | 0 |
| 3 | 1 | Supernova | Nova | 52 | | komet x2 | komet | 520 / 720 | 280 | inf | 57 / 46 s | 102 / 79 s | 1.21 | 7.5 s | 0 |
| 4 | 1 | Ekko | Ekko | 42 | | ekko x2 | komet, ekko | 520 / 720 | 280 | inf | 44 / 54 s | 72 / 82 s | 0.82 | 5.6 s | 0 |
| 5 | 1 | Solkjernen | Boss (HP 10 / 14) | 22 + boss | | ekko, komet | komet, ekko | 520 / 720 | 280 | inf | 34 / 32 s | 49 / 48 s | 0.80 | 7.7 s | 0 |
| 6 | 2 | Trekant | Triple | 32 | | komet, ekko | komet, ekko | 530 / 760 | 280 | 3 | 44 / 35 s | 62 / 57 s | 1.01 | 5.6 s | 5% (guess) |
| 7 | 2 | Rushtid | Glider | 36 | | ekko, komet | komet, ekko | 530 / 760 | 280 | 3 | 37 / 41 s | 78 / 75 s | 0.94 | 6.7 s | 8% (guess) |
| 8 | 2 | Vingene | Bredvinge | 42 | | bredvinge x2 | komet, ekko, bredvinge | 530 / 760 | 280 | 3 | 69 / 69 s | 112 / 90 s | 0.64 | 7.2 s | 6% (guess) |
| 9 | 2 | Gatelys | Chrome | 34 | 2 C | bredvinge, komet | komet, ekko, bredvinge | 530 / 760 | 280 | 3 | 49 / 54 s | 102 / 88 s | 0.67 | 9.8 s | 8% (guess) |
| 10 | 2 | Nattaxi | Boss + minions (HP 14 / 20) | 22 + boss (+ up to 8 minions) | | bredvinge, ekko | komet, ekko, bredvinge | 530 / 760 | 280 | inf | 50 / 51 s | 78 / 81 s | 0.62 | 8.8 s | 0 |
| 11 | 3 | Invasjon | March block | 30 | | ekko, komet | komet, ekko, bredvinge | 540 / 800 | 260 | 3 | 36 / 36 s | 62 / 56 s | 0.90 | 5.6 s | 8% (guess) |
| 12 | 3 | Kjedereaksjon | March + Nova chains | 40 | | komet, ekko | komet, ekko, bredvinge | 540 / 800 | 260 | 3 | 31 / 29 s | 45 / 52 s | 1.51 | 3.7 s | 8% (guess) |
| 13 | 3 | Neonpuls | Neonpuls | 54 | | neonpuls x2 | komet, ekko, neonpuls | 540 / 800 | 260 | 3 | 35 / 37 s | 83 / 79 s | 1.57 | 6.0 s | 10% (guess) |
| 14 | 3 | Flipper | March + chrome + glider | 35 | 4 C | ekko, neonpuls | komet, ekko, bredvinge, neonpuls | 540 / 800 | 260 | 3 | 23 / 25 s | 32 / 50 s | 1.58 | 4.2 s | 12% (guess) |
| 15 | 3 | Arkadekongen | Boss inside a march block (HP 20 / 30) | 32 + boss (+ minions) | | neonpuls, ekko | komet, ekko, bredvinge, neonpuls | 540 / 800 | 260 | inf | 26 / 29 s | 38 / 49 s | 1.58 | 4.1 s | 0 |

Per-level boss and march data: L5 boss speed 60 / 90, no minions. L10 boss speed 80 / 120, minions. L11 and L12 march rows r1-r5, floor 1000. L14 march r1-r5, floor 900. L15 march r1-r5 (boss included, no own motion), floor 800, minions.

Level 1 for a 4-year-old: 32 low bricks and two Komet carriers in r5, so the first capsule falls after a median 18.5 s in Lett and 15.6 s in Vanlig (my calc, 60 runs), and the Lett magnet hands it over. Level 14 is short (23-25 s) on purpose: a fast "flipper" level right before the final boss.

### 15.7 Maps, levels 1-15 (build these exactly)

Format as before: 10 characters per row = columns c0-c9, rows from r0 (top, y 340) down, rows not listed are empty. Codes: `G` Glass, `D` Double, `T` Triple, `N` Nova, `M` Glider, `C` Chrome, `K` boss anchor, `+` boss body, lowercase = carrier (kinds from the `carriers` list in reading order). These are the exact strings the sim ran.

**Level 1: Første lys** (carriers: komet in reading order; bonus pool: komet)
```
r0 ..........
r1 ..........
r2 ..........
r3 .GGGGGGGG.
r4 GGGGGGGGGG
r5 .GGgGGgGG.
r6 ..GGGGGG..
```
Low, wide wall. The two carriers in r5 sit where the first bounces land, so a Komet falls after a median 15-19 s (my calc).

**Level 2: To prikker** (carriers: komet in reading order; bonus pool: komet)
```
r0 ..........
r1 ..........
r2 .GGGGGGGG.
r3 GDDGGGGDDG
r4 GDDGGGGDDG
r5 GGGGggGGGG
r6 .GG....GG.
r7 ..GGGGGG..
```
A face: two blocks of Doubles are the eyes, r6-r7 the smile. The carriers sit in the chin row.

**Level 3: Supernova** (carriers: komet in reading order; bonus pool: komet)
```
r0 ..........
r1 ..........
r2 GGGGGGGGGG
r3 GGNGGGGNGG
r4 GGGGGGGGGG
r5 GDGGNNGGDG
r6 GGGGGGGGGG
r7 ..g....g..
```
Four Novas sit inside a solid wall, so any hit near them sets off a 3x3 blast and often a chain. Komet through the Nova row is the big moment.

**Level 4: Ekko** (carriers: ekko in reading order; bonus pool: komet, ekko)
```
r0 ..........
r1 ..........
r2 DDDDDDDDDD
r3 GGNGGGGNGG
r4 GGGGDDGGGG
r5 .GGGGGGGG.
r6 ..........
r7 ..gG..Gg..
```
A Double roof over a Nova-salted wall. Two Ekko carriers hang low; three balls in a dense wall is the action peak of world 1.

**Level 5: Solkjernen** (carriers: ekko, komet in reading order; bonus pool: komet, ekko; boss HP 10 / 14, speed 60 / 90, minions no)
```
r0 ..........
r1 ...K++....
r2 ...+++....
r3 ..........
r4 .GGGGGGGG.
r5 .DDGNNGDD.
r6 ..........
r7 ..gGGGGg..
```
Solkjernen glides in its own lane (r1-r2) above a shield of Glass and Doubles. Novas in r5 open a hole; Komet ploughs up to it.

**Level 6: Trekant** (carriers: komet, ekko in reading order; bonus pool: komet, ekko)
```
r0 ..........
r1 ..........
r2 ....TT....
r3 ...TNNT...
r4 ..TGGGGT..
r5 .TGGNNGGT.
r6 TGGGGGGGGT
r7 ..t....t..
```
A pyramid of Triples with Novas inside: Nova blasts chip the Triples, so the slow 3-hit bricks still fall fast.

**Level 7: Rushtid** (carriers: ekko, komet in reading order; bonus pool: komet, ekko)
```
r0 ..........
r1 GGGGGGGGGG
r2 GNGGTTGGNG
r3 GGGGGGGGGG
r4 ..........
r5 .M...M...m
r6 ..........
r7 m...M...M.
```
Six Gliders (two carry capsules) cross under a Nova wall. Moving targets in the open lower field.

**Level 8: Vingene** (carriers: bredvinge in reading order; bonus pool: komet, ekko, bredvinge)
```
r0 ..........
r1 GGGGGGGGGG
r2 GTGGNNGGTG
r3 GNGGGGGGNG
r4 .GGGDDGGG.
r5 ..........
r6 .M..gg..M.
```
Two Bredvinge carriers between two Gliders in r6; a wide paddle meets a Triple-cornered wall with a Nova pair.

**Level 9: Gatelys** (carriers: bredvinge, komet in reading order; bonus pool: komet, ekko, bredvinge)
```
r0 ..........
r1 GGGGGGGGGG
r2 GNGGTTGGNG
r3 GGGGGGGGGG
r4 ..........
r5 ..C....C..
r6 ..........
r7 .g.M..M.g.
```
Chrome posts (only two, under c2 and c7) deflect but enclose nothing. Two Gliders and two carriers in r7.

**Level 10: Nattaxi** (carriers: bredvinge, ekko in reading order; bonus pool: komet, ekko, bredvinge; boss HP 14 / 20, speed 80 / 120, minions yes)
```
r0 ..........
r1 ...K++....
r2 ...+++....
r3 ..........
r4 ..........
r5 GTGGNNGGTG
r6 .GGGGGGGG.
r7 ..........
r8 .g..GG..g.
```
Nattaxi glides fast in r1-r2. Its first phase change drops 4 Glass minions into the empty r3 under it. A Nova pair in r5 helps punch up.

**Level 11: Invasjon** (carriers: ekko, komet in reading order; bonus pool: komet, ekko, bredvinge; march rows r1-r5, floor_y 1000)
```
r0 ..........
r1 ..GGGGGG..
r2 ..GNGGNG..
r3 ..TGGGGT..
r4 ..GGGGGG..
r5 ..GgGGgG..
```
A 6-wide march block (r1-r5). Carriers in its bottom row fall first as the block comes down.

**Level 12: Kjedereaksjon** (carriers: komet, ekko in reading order; bonus pool: komet, ekko, bredvinge; march rows r1-r5, floor_y 1000)
```
r0 ..........
r1 .GNGGGGNG.
r2 .GGTNNTGG.
r3 .NGGGGGGN.
r4 .GGGTTGGG.
r5 .GGgGGgGG.
```
An 8-wide march block with six Novas: chains run through the whole block. It only travels 200 px sideways, so it steps down often.

**Level 13: Neonpuls** (carriers: neonpuls in reading order; bonus pool: komet, ekko, neonpuls)
```
r0 ..........
r1 TGGGGGGGGT
r2 GGNGTTGNGG
r3 TGGGGGGGGT
r4 GGGGNNGGGG
r5 DDGGGGGGDD
r6 ..........
r7 M...nn...M
```
The densest level (54): a full wall with Novas and Triples, Gliders at both ends of r7, and two Neonpuls carriers that are Novas themselves.

**Level 14: Flipper** (carriers: ekko, neonpuls in reading order; bonus pool: komet, ekko, bredvinge, neonpuls; march rows r1-r5, floor_y 900)
```
r0 ..........
r1 ..TGNNGT..
r2 ..GGGGGG..
r3 ..GNTTNG..
r4 ..GGGGGG..
r5 ..DGGGGD..
r6 C...M....C
r7 ..........
r8 .gC.GG.Cg.
```
A short, fast level: a 6-wide march block, chrome bumpers at the walls in r6 and r8, one Glider.

**Level 15: Arkadekongen** (carriers: neonpuls, ekko in reading order; bonus pool: komet, ekko, bredvinge, neonpuls; boss HP 20 / 30, speed 0 / 0, minions yes; march rows r1-r5, floor_y 800)
```
r0 ..........
r1 ...K++....
r2 .T.+++..T.
r3 .GNGGGGNG.
r4 .GGGTTGGG.
r5 .DGGGGGGD.
r6 ..........
r7 ..gGNNGg..
```
Arkadekongen rides inside a march block (r1-r5) with Triples beside it and a Nova row under it. Phase changes refill holes in r3 with minions. The block stops stepping at y 800.

### 15.8 Level data format additions

Keep `rows`, `lett_speed`, `vanlig_speed`, `vanlig_paddle`, `vanlig_net` (0 = unlimited). New keys:

| Key | Type | Example | Notes |
|---|---|---|---|
| `world` | int | 2 | Drives the map page and the colour ramp |
| `carriers` | Array[String] | `["bredvinge", "komet"]` | Replaces `carrier_powerup` (keep reading it as a fallback: `[carrier_powerup]`) |
| `bonus_pool` | Array[String] | `["komet", "ekko"]` | Combo capsules and boss phases |
| `boss` | Dictionary or absent | `{"hp": [14, 20], "speed": [80, 120], "minions": true}` | Pairs are Lett, Vanlig. Speed 0 = no own motion |
| `march` | Dictionary or absent | `{"rows": [1, 5], "floor_y": 1000}` | Speed and step from NbBalance |

Colour ramps for worlds 2 and 3 belong to graphic-designer (DESIGN.md). Until they exist, use the world 1 ramp rotated by one step per world so levels at least differ (placeholder, my call).

### 15.9 Later phase: levels 16-30 (superseded)

**Superseded 2026-10-07 by section 16** (exact rules, maps, numbers and sim for levels 16-30). The outline below is history; names and maps changed.

Outline only; maps and sim come after the owner has played 1-15 on the phone. Speeds: Lett 550 / 560 / 570, Vanlig 830 / 860 / 880 for worlds 4 / 5 / 6. Vanlig paddle 260 / 240 / 240. Every 5th level is a boss with unlimited net.

| # | W | Name (working) | New / focus |
|---|---|---|---|
| 16 | 4 | Bryteren | Switch + Ghost |
| 17 | 4 | Skyggemarsj | Ghost rows inside a march block |
| 18 | 4 | Saktetid | Saktetid (a help now that Vanlig is fast) |
| 19 | 4 | Filskifte | Gliders + ghosts + chrome gates |
| 20 | 4 | Lastebilen | Boss with a ghost shield that a switch toggles |
| 21 | 5 | Ormehull | Portal pair |
| 22 | 5 | Krystallbuer | Portals + gliders |
| 23 | 5 | Skjoldnett | Skjoldnett |
| 24 | 5 | Labyrint | Portals + switch + march |
| 25 | 5 | Krystallhjertet | Boss that jumps between two portal spots at each phase |
| 26-29 | 6 | Stjerneporten 1-4 | Remixes, two march blocks moving in opposite directions, one new element (open question 8) |
| 30 | 6 | Neonnova | Final boss, 3 phases (march, minions, Nova ring around it) |

### 15.10 Builder scope for one session (godot-android-dev)

Ship in this order; each step leaves a playable build, so if the session runs out the next session starts at the first unfinished step.

1. **Core action systems** on the existing slice: combo meter, tiers, combo capsules, chain slow-mo, progress ramp (remove the time ramp), finale helper, line-of-sight `aim_point` used by both the assist and the finale. `NOTE_STEPS_MAX` 12.
2. **World 1 v2**: replace the 5 world 1 maps with 15.7 levels 1-5; add `carriers` / `bonus_pool`; Nova (blast rect 15.3.5); Ekko (multi-ball: up to 3 balls in NbSim; echoes never spend net charges, never aim or home); boss `K` with phases (no minions yet needed for L5). Raise Vanlig world 1 speed to 720.
3. **World 2**: Triple, Glider, Bredvinge, boss minions; levels 6-10; world 2 map page with the arrow discs from 8.1; charged net on levels 6-9.
4. **World 3**: march block, Neonpuls; levels 11-15; world 3 map page.

Placeholders allowed this session (graphic-designer follows up): boss = scaled brick body with a ring of notch quads; echo ball = ball mesh at 50% alpha; capsule icons per kind as simple shape decals (Komet tail, three circles, winged paddle, paddle with arcs); world 2-3 backgrounds = the world 1 scene with a tint.

Update `tools/action_sim.py` maps if a map changes, rerun it, and paste the new medians into 15.6.

**Acceptance for game-qa** (headless where possible):
- Sim parity: NbSim bot medians for levels 1-15 within +-35% of the 15.6 Vanlig medians (different bot, same rules).
- No level in either setting has a run over 300 s in 20 seeds (catches trap layouts like the draft level 9).
- Longest gap between breaks: Vanlig median under 10 s on every level.
- Flash limiter: at most 3 glow spikes in any 1 s window during a Nova chain in level 12 and a boss phase change in level 10.
- March floor: no march piece bottom ever below y 1000 (log check, levels 11, 12, 14, 15).
- Ekko: an echo ball falling past the net never spends a charge (level 6 with forced Ekko).
- Lett: no game over, no shake, unlimited net on all 15 levels; kids walk-through of level 1 still passes with sound off.
- `full_unlock == false` still shows only levels 1-3 (owner rule).

### 15.11 Open questions (action pass)

5. **Boss levels as the 5th level:** the old 5th level was a calm breather. I made it a boss fight that keeps the breather's safety (unlimited net, more capsules). OK, or keep a calm breather and move the boss to level 4?
6. **Komet in level 1:** a capsule in the very first level gives action early but is one more thing for a 4-year-old. With the Lett magnet it needs no skill. OK?
7. **Combo shake in Vanlig:** 3 px per break at combo 10+, at most 3 per second. Keep, or no shake at all outside the last brick?
8. **World 6 new element (decided 2026-10-07: Magnet, see 16.1; the owner may overrule, 16.12 question 9):** levels 26-30 had no new brick yet. Ideas: a "Splitter" brick that breaks into two small falling Glass bricks the ball can still hit, or a "Magnet" brick that bends the ball's path when it passes. Pick one, or none?

---

## 16. Worlds 4-6, levels 16-30 (2026-10-07)

The owner played levels 1-15 on his phone on 2026-10-07, said they work, and asked for the rest. This section replaces the outline in 15.9 and the endless spec in 6.5. Where it disagrees with an older section, this section wins. Child rules kept: no game over in Lett, unlimited net on every boss level in both settings, at most 3 bright flashes per second (every new glow goes through the existing limiter), colour is never the only cue (every new piece has a shape cue), no new tap targets in play (the game stays drag-only; map discs stay 200 px with a 240 px hit area).

### 16.1 Decisions in this section (my calls unless marked)

1. **World 6 element (open question 8): Magnet** (`O`), a 2-hit brick that bends the ball toward itself. Not Splitter: falling bricks look like capsules and would teach a 4-year-old the wrong thing. World 6 also gets **two march blocks** (L27) as its level mechanic.
2. **Level 10 gap fix:** Vanlig boss HP 20 -> 16 (level data; the map is unchanged). Verified in the real game loop (16.6).
3. **Ghost flip timer:** ghosts also flip by themselves every 7 s, with a 1 s warning. Without it, phased ghosts the ball cannot reach made Lett levels run 110-120 s with 15-30 s gaps (my calc, first draft of 16, 18 and 19).
4. **Finale makes every ghost solid:** at 3 bricks left (Lett 4) the switches go dark and the ghosts left stay solid, so the end of a level is never a ghost hunt.
5. **Portal hop guard:** a ball may use portals at most 3 times between two paddle or brick touches. Two portal pairs plus two walls made an endless loop in the first L28 draft (my calc).
6. **Map rules with a lint** (16.4), enforced by `tools/action_sim.py` for hand maps and by the endless generator.
7. **The sim now models paddle english** (GDD 4.3) and the game bot's hold rule. The v2 sim left them out, which is why it showed 7.7 s for level 10 while the game showed 11-13 s.

### 16.2 New elements (exact rules)

#### 16.2.1 Switch `S` + Ghost `A` / `B` (first level 16)

- **Switch `S`:** one cell, hit box 92 x 44 like a brick. Never breaks, not counted for the clear, bounces every ball like chrome, including the +-3 degree jitter (4.4 rule 2). Blocks line of sight for `aim_point` (15.3.4).
- **Ghost state:** one flag per level, `ghost_a_solid`, `true` at level start and after a gentle restart. Set A is solid when it is true, set B when it is false.
- **Flip:** any ball (main, echo, Komet) touching any switch flips the flag, if at least `SWITCH_COOLDOWN_S` 0.5 s have passed since the last flip of any kind.
- **Auto flip:** if `GHOST_FLIP_S` (7 s, both settings) pass without a flip, the flag flips by itself. If every breakable piece left is a phased ghost, the wait is `GHOST_FLIP_PHASED_S` 3 s instead. The clock starts at level start (launch) and restarts at every flip. **Warning:** during the last `GHOST_WARN_S` 1.0 s before an automatic flip, the switch rings and the outlines of the ghosts about to turn solid pulse twice (2 Hz, soft glow through the limiter) and a two-note "tick-tick" plays.
- **Phased ghost:** no collision with balls; ignored by Nova blasts, Neonpuls waves and Komet; never a target for `aim_point`. It still counts in `breakable_left` (the level needs it broken).
- **Solid ghost:** a 1-hit brick in every way (combo, note, carrier drop, Nova, Neonpuls, Komet).
- **Turning solid on top of a ball:** that ghost breaks at once as a normal break (no push-out, no stuck ball).
- **Finale:** when the finale helper turns on (15.3.3), every ghost left becomes solid for the rest of the level, switches turn dark and behave as chrome (no flip) and the auto-flip clock stops.
- **Movers:** gliders, march blocks and bosses treat ghosts in either state as obstacles (no overlap ever). A ghost inside a march block moves with the block.
- **Aim fallback:** when no solid breakable piece is in reach, the assist aims at the nearest switch it can see (already in 4.4 rule 5).
- **Carriers:** lowercase `a` / `b` are allowed (a ghost carrying a capsule).
- **Look (graphic-designer):** solid = filled body + outline; phased = outline only at 30% opacity (5.1). Set A has square corner marks, set B round dots (shape cue). Flip = 0.2 s crossfade (logic flips at once). Switch: a ring with a dot, lit while it can flip, dark during the finale.

#### 16.2.2 Saktetid / Tape Slow (power-up, first level 18)

- On catch: for `SAKTETID_S` 10 s every ball's speed is multiplied by `SAKTETID_SCALE` (Lett 0.75, Vanlig 0.65), after the progress ramp, then clamped to `BALL_SPEED_MIN` 300. Gliders, march blocks, bosses and capsules keep their speed.
- During the last `SAKTETID_RETURN_S` 0.5 s the factor rises linearly back to 1.0.
- Same power-up again: the timer goes back to 10 s (refresh, no stacking).
- Countdown with no digits: 5 tape notches on the paddle, one goes dark every 2 s.
- Music and effects `pitch_scale` 0.9 (Lett) / 0.85 (Vanlig) during the effect, back to 1.0 over the same 0.5 s.

#### 16.2.3 Portal pair `1` / `2` (first level 21)

- Map codes `1` and `2`; each appears exactly 0 or 2 times in a map. The portal centre is the cell centre. Portals never move and are not counted.
- **Trigger:** a ball whose centre comes within `PORTAL_RADIUS` 40 px of a portal centre, whose own portal cooldown is over and whose `hops < PORTAL_MAX_HOPS` (3), is placed at the partner's centre + unit velocity x `PORTAL_EXIT_PX` 60, clamped inside the walls. Velocity unchanged. That ball's cooldown becomes `PORTAL_COOLDOWN_S` 0.4 s and `hops += 1`.
- **Hop guard:** `hops` goes back to 0 when the ball touches the paddle or any breakable piece. At 3 hops the ball passes over every portal until then.
- **No collision:** a portal is a flat ring on the floor; balls never bounce on it, so there is no "portal rim" jitter (this replaces the portal part of 4.4 rule 2).
- **Line of sight:** for `aim_point`, a circle of radius 40 + 22 around each portal centre blocks the line (the ball would be teleported).
- Echo and Komet balls use portals. Capsules, Nova blasts and Neonpuls ignore them. Movers treat the portal's cell (92 x 44) as an obstacle.
- Shape cue: pair 1 = single spiral, pair 2 = spiral with a star in the middle (5.1).

#### 16.2.4 Skjoldnett / Shield Net (power-up, first level 23)

- The kind is resolved when the capsule spawns: in Lett, or on a level whose Vanlig net is unlimited, a Skjoldnett capsule spawns as Bredvinge (it shows the Bredvinge icon).
- On catch (Vanlig, charged net): if charges < 3, +1 charge (one diamond pip weaves back over 0.4 s; at 0 charges the dashed net becomes solid again). If charges are already 3, it gives Bredvinge instead.
- Gentle restart refills the net to 3 as before.

#### 16.2.5 Magnet `O` (world 6 element, first level 26)

- A breakable brick with 2 hits. Shape cue: a ring with four chevrons pointing inward; the first hit breaks two chevrons and adds a crack.
- **Pull:** every frame, for each ball (main, echo, Komet), take the nearest alive magnet whose centre is less than `PULL_RADIUS` 170 px from the ball centre. Turn the ball's direction toward the magnet centre by at most `PULL_TURN_DEG_S` (Lett 45, Vanlig 70) x delta, keep the speed, then apply the 20 degree flat-floor rule. One magnet per ball per frame.
- Why the ball can never orbit: the tightest turn radius is speed / turn rate = 880 / 1.22 rad/s = 720 px in Vanlig and 570 / 0.79 = 725 px in Lett (my calc), four times the pull radius.
- Map rule: magnets only in rows r0-r8, so the pull never reaches below y 952 (paddle top is 1402).
- Nova, Neonpuls and Komet hit it like any 2-hit brick. In a march block it moves with the block.
- Look: faint field lines rotating at 0.25 rev/s, low contrast, never flashing. "Mindre bevegelse": static field lines.

#### 16.2.6 Two march blocks (level mechanic, first level 27)

- `march` may be one dictionary (as in 15.8) or an array of up to 2 dictionaries, each with `rows`, `floor_y` and an optional `dir` (+1 starts right, -1 starts left; default +1).
- Each block follows 15.3.7 on its own: own direction, own reversal, own step down. Both use `MARCH_SPEED`.
- **Obstacle rule** (the builder already does this in NbSim; now part of the design): a block reverses when its next sideways move would overlap any alive piece outside the block (the other block, a switch, a ghost in either state, a glider, a portal cell), and it skips a step down that would overlap one.
- Map rule: the upper block's `floor_y` must be at or above the lower block's start top edge, so the blocks can never meet when stepping down.

#### 16.2.7 Boss phase actions and the three new bosses

New optional keys in the level's `boss` dictionary:

| Key | Type | Meaning |
|---|---|---|
| `on_phase` | Array[String], 2 entries | What happens at the phase 1 and the phase 2 change (15.3.6). Each entry is one action or several joined by `+`, run in this order: `minions`, `nova_ring`, `shield_up`, `jump`. Empty string = nothing extra. `minions: true` (old levels) still means minions at both changes. |
| `jump` | Array of [row, col] | Anchor cells the boss jumps to, in order, cycling. Each must be free of other pieces in the map. |

- **`nova_ring`:** up to `NOVA_RING_MAX` 6 Nova bricks appear in free cells around the boss's 3 x 2, filled in this order: the row below (columns c-1 to c+3), then the four side cells (c-1 and c+3 in both boss rows), then the row above (c-1 to c+3). "Free" is the minion rule (no piece, ball or capsule in the cell). In a march they join the block at its current offset. 0.3 s fade-in, counted for the clear, and they blast normally (a blast next to the boss deals it 1 damage).
- **Spawn rule (minions and Nova ring):** a cell directly above a chrome, a switch or a portal cell is not free. Minions in such a pocket made the first L20 draft run 130 s with one brick left (my calc).
- **`shield_up`:** sets `ghost_a_solid = true` if it is false and restarts the auto-flip clock. Ignored once the finale is on.
- **`jump`:** the boss fades out over `BOSS_JUMP_FADE_S` 0.3 s (still solid where it is), then moves to the next anchor and fades in over 0.3 s (solid at once). If a ball overlaps the target rect, it waits until the rect is clear, at most `BOSS_JUMP_WAIT_MAX_S` 1.0 s, then moves anyway (the push-out rule in 4.2 handles the ball). A portal swirl plays at both spots. A jumping boss has speed 0.

| Level | Boss | HP Lett / Vanlig | Motion | Phase 1 / phase 2 |
|---|---|---|---|---|
| 20 Lastebilen | The truck: sits mid-field (r4-r5) between a roof of bricks and a ghost tailgate (set A, r6) | 12 / 14 | Glides 70 / 110 px/s | `shield_up` / `shield_up` (the tailgate slams shut) |
| 25 Krystallhjertet | Crystal heart, does not glide | 18 / 24 | Jumps r1 c3 -> r1 c6 -> r1 c1 | `jump` / `jump`, minions at both changes (`minions: true`) |
| 30 Neonnova | Final boss inside a march block, magnets beside it | 26 / 32 | March r1-r5, floor 800 | `minions` / `minions+nova_ring` |

#### 16.2.8 How the new pieces meet the old ones

| Piece | Komet | Nova blast | Neonpuls | Echo ball | aim_point / finale | Movers |
|---|---|---|---|---|---|---|
| Switch | bounces, flips | ignores | ignores | bounces, flips | blocks the line; fallback target | obstacle |
| Ghost, solid | ploughs through | 1 hit | 1 hit (lowest solid) | breaks it | target | obstacle |
| Ghost, phased | passes | ignores | skipped | passes | not a target | obstacle |
| Portal | teleports | ignores | ignores | teleports | blocks the line (r 62) | obstacle (cell) |
| Magnet | pulled, ploughs through | 1 hit | 1 hit | pulled | target | moves in a march |

### 16.3 Numbers (paste into NbBalance; Lett / Vanlig)

```
# --- Worlds 4-6 (GDD 16) ---
const SWITCH_COOLDOWN_S: float = 0.5
const GHOST_FLIP_S: float = 7.0              # both settings
const GHOST_FLIP_PHASED_S: float = 3.0       # every brick left is a phased ghost
const GHOST_WARN_S: float = 1.0
const GHOST_WARN_PULSES: int = 2
const GHOST_FADE_S: float = 0.2
const GHOST_PHASED_ALPHA: float = 0.3

const SAKTETID_S: float = 10.0
const SAKTETID_SCALE_LETT: float = 0.75
const SAKTETID_SCALE_VANLIG: float = 0.65
const SAKTETID_RETURN_S: float = 0.5
const SAKTETID_PITCH_LETT: float = 0.9
const SAKTETID_PITCH_VANLIG: float = 0.85
const SAKTETID_NOTCHES: int = 5

const PORTAL_RADIUS: float = 40.0
const PORTAL_EXIT_PX: float = 60.0
const PORTAL_COOLDOWN_S: float = 0.4
const PORTAL_MAX_HOPS: int = 3
const PORTAL_LOS_RADIUS: float = 62.0        # PORTAL_RADIUS + BALL_RADIUS

const SKJOLDNETT_MAX_CHARGES: int = 3

const PULL_RADIUS: float = 170.0             # Magnet brick (not the Lett capsule magnet)
const PULL_TURN_DEG_S_LETT: float = 45.0
const PULL_TURN_DEG_S_VANLIG: float = 70.0
const PULL_MAX_ROW: int = 8

const MARCH_BLOCKS_MAX: int = 2
const NOVA_RING_MAX: int = 6
const BOSS_JUMP_FADE_S: float = 0.3
const BOSS_JUMP_WAIT_MAX_S: float = 1.0
```

Per level (level data, 16.8): speeds Lett 550 / 560 / 570 and Vanlig 830 / 860 / 880 in worlds 4 / 5 / 6; Vanlig paddle 260 / 240 / 240; Vanlig net 3 charges, unlimited on 20, 25 and 30.

### 16.4 Map rules (hand maps and the endless generator)

1. Every breakable cell can be reached from the paddle line (y 1376) by a straight shot or a one-wall bank shot from at least one of x 140 / 340 / 540 / 740 / 940, within 55 degrees of vertical, using the `aim_point` line test (chrome, switches and portal circles block; breakable pieces, ghosts included, never block). In practice: keep at least one empty row between a switch or chrome and the brick above it, and never put a switch right under a wall-column brick.
2. A portal's 8 neighbour cells hold no chrome, switch or other portal.
3. Each portal code appears 0 or 2 times.
4. No piece below r9; magnets only in r0-r8; march `floor_y` at most 1000.
5. Two march blocks: the upper block's `floor_y` at or above the lower block's start top.
6. Boss `jump` anchors are free cells in the map.

`python3 tools/action_sim.py` prints `map lint: OK` or the broken rule for every level it runs (rules 1-4 are checked).

### 16.5 Level table, levels 16-30

Sim columns are (my calc): `tools/action_sim.py --skip-old --runs 40`, v3 sim (paddle english on, bot hold rule, near-perfect bot, unlimited net, chain slow-mo not modelled). Real children are slower; treat the times as floors. Python matches the game's own bot test within about 1.5 s on the longest gap for 14 of the 15 built levels, but is optimistic when a boss is the last piece (level 10: Python 8.6 s, game 10.6-12.4 s). So boss levels must come in at 7 s or less here; other levels under 10 s. Restart chance is a guess for the owner's test. Boss counts as 1 in "Breakable".

| # | W | Name | New | Breakable | Other | Carriers (in order) | Bonus pool | Lett / Vanlig speed | Vanlig paddle | Vanlig net | Median Lett / Vanlig | p90 Lett / Vanlig | Breaks/s Vanlig | Longest gap Lett / Vanlig | Last 3 bricks Vanlig | Restart chance Vanlig |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | 4 | Bryteren | Switch + Ghost | 44 | 2 S | komet, ekko | komet, ekko, bredvinge | 550 / 830 | 260 | 3 | 68 / 50 s | 115 / 94 s | 0.93 | 8.1 / 8.0 s | 5.6 s | 10% (guess) |
| 17 | 4 | Skyggemarsj | Ghost rows in a march block | 38 | 2 S (in the block) | ekko, komet | komet, ekko, bredvinge | 550 / 830 | 260 | 3 | 44 / 38 s | 93 / 63 s | 1.07 | 7.5 / 5.0 s | 4.3 s | 10% (guess) |
| 18 | 4 | Saktetid | Saktetid | 42 | 2 S | saktetid x2 | komet, ekko, bredvinge | 550 / 830 | 260 | 3 | 80 / 54 s | 110 / 91 s | 0.82 | 11.5 / 7.7 s | 4.0 s | 8% (guess) |
| 19 | 4 | Filskifte | Ghost checker + gliders | 36 | 2 S | saktetid, ekko | komet, ekko, bredvinge, saktetid | 550 / 830 | 260 | 3 | 63 / 51 s | 110 / 70 s | 0.75 | 11.4 / 9.2 s | 5.8 s | 10% (guess) |
| 20 | 4 | Lastebilen | Boss behind a ghost tailgate (HP 12 / 14) | 26 + boss | 2 S | ekko, komet | komet, ekko, saktetid | 550 / 830 | 260 | inf | 43 / 32 s | 68 / 56 s | 0.93 | 7.5 / 6.6 s | 4.1 s | 0 |
| 21 | 5 | Ormehull | Portal pair | 42 | 1 pair | komet, ekko | komet, ekko, saktetid | 560 / 860 | 240 | 3 | 41 / 41 s | 89 / 57 s | 1.12 | 6.5 / 5.4 s | 5.5 s | 10% (guess) |
| 22 | 5 | Krystallbuer | Two portal pairs + gliders | 32 | 2 pairs | ekko, komet | komet, ekko, bredvinge, saktetid | 560 / 860 | 240 | 3 | 31 / 24 s | 45 / 57 s | 1.49 | 4.9 / 3.2 s | 3.6 s | 12% (guess) |
| 23 | 5 | Skjoldnett | Skjoldnett | 38 | 1 pair, 2 S | skjoldnett x2 | komet, ekko, skjoldnett, saktetid | 560 / 860 | 240 | 3 | 59 / 39 s | 92 / 73 s | 1.04 | 9.4 / 5.8 s | 6.6 s | 10% (guess) |
| 24 | 5 | Labyrint | Portals + switches + march | 26 | 1 pair, 2 S | skjoldnett, ekko | komet, ekko, neonpuls, skjoldnett | 560 / 860 | 240 | 3 | 34 / 38 s | 74 / 65 s | 0.75 | 7.0 / 7.8 s | 4.4 s | 12% (guess) |
| 25 | 5 | Krystallhjertet | Boss that jumps (HP 18 / 24) | 22 + boss | 1 pair | ekko, komet | komet, ekko, neonpuls, skjoldnett | 560 / 860 | 240 | inf | 28 / 30 s | 39 / 58 s | 1.14 | 4.8 / 5.1 s | 12.5 s | 0 |
| 26 | 6 | Magneten | Magnet | 50 |  | komet, ekko | komet, ekko, neonpuls, saktetid | 570 / 880 | 240 | 3 | 27 / 28 s | 47 / 72 s | 1.98 | 3.7 / 3.5 s | 3.6 s | 12% (guess) |
| 27 | 6 | Dobbelmarsj | Two march blocks | 34 |  | ekko, neonpuls | komet, ekko, bredvinge, neonpuls | 570 / 880 | 240 | 3 | 24 / 22 s | 33 / 31 s | 1.82 | 3.5 / 2.7 s | 1.8 s | 15% (guess) |
| 28 | 6 | Stjernestorm | Portals + ghosts + magnets | 42 | 2 pairs, 2 S | komet, skjoldnett | komet, ekko, neonpuls, saktetid, skjoldnett | 570 / 880 | 240 | 3 | 29 / 29 s | 44 / 50 s | 1.64 | 4.6 / 3.7 s | 3.4 s | 15% (guess) |
| 29 | 6 | Siste port | Everything in one march | 28 | 1 pair, 2 S | ekko, neonpuls | komet, ekko, bredvinge, neonpuls, saktetid, skjoldnett | 570 / 880 | 240 | 3 | 20 / 22 s | 32 / 43 s | 1.50 | 3.7 / 4.0 s | 3.8 s | 15% (guess) |
| 30 | 6 | Neonnova | Final boss: march, minions, Nova ring (HP 26 / 32) | 28 + boss | 1 pair | neonpuls, ekko | komet, ekko, bredvinge, neonpuls, saktetid | 570 / 880 | 240 | inf | 22 / 30 s | 28 / 56 s | 1.59 | 3.3 / 5.2 s | 14.3 s | 0 |

Pacing checks (my calc, 40 runs per level and setting, output `pacing targets: ALL MET`): every level's Vanlig longest-gap median is under 10 s (worst L19 9.2 s), the boss levels 20, 25 and 30 are at 6.6, 5.1 and 5.2 s, no run of any level 1-30 reaches 300 s (slowest single run 195 s, Lett L2), and the map lint passes on all 15 new maps.

Notes:
- World 4 is the slowest world in Lett (medians 43-80 s): ghosts take time. It is still inside the 1-2.5 minute session target (8.4). Lett has no gap target; its longest gaps are L18 11.5 s and L19 11.4 s, close to shipped level 3 (12.4 s).
- World 6 is short and dense (medians 20-30 s, 1.5-2.0 breaks per second in Vanlig): magnets pull the ball into bricks. That is on purpose for the last world (more action, owner).
- The v3 sim also passes levels 1-15 (Vanlig longest gap 3.4-9.6 s, level 10 with the 16.6 fix 4.9 s).

### 16.6 Level 10 fix (Vanlig gap 12.4 s)

**Cause:** the long gap is the boss fight after every other brick is gone. Nattaxi (HP 20 in Vanlig) glides at 120-187 px/s near the top, and boss hits are not "breaks", so the stretch with no break is the time to land the last 6-10 hits. Paddle english (4.3) widens it from 7.8 s to 11-13 s in the game (builder's note in `tests/levels_test.gd`).

**Fix:** level 10 `boss.hp` from `[14, 20]` to `[14, 16]`. Map, speeds, minions and Lett unchanged. Paddle physics unchanged.

```
"boss": {"hp": [14, 16], "speed": [80.0, 120.0], "minions": true},
```

**Verified in the real game loop** (my calc: `tests/levels_test.tscn` with `LEVELS_ONLY=10`, 60 seeds per setting, on a scratch copy of the project with only the level 10 entry changed):

| Level 10 variant (Vanlig) | Median clear | Longest gap median | Last 3 bricks |
|---|---|---|---|
| As shipped (HP 20) | 52.4 s | 10.6 s (12.4 s at 20 seeds) | 26.1 s |
| Map only: chrome posts at r1-r2 c0 and c9 (narrower boss lane) | 49.2 s | 9.1 s | 22.3 s |
| Chrome posts + HP 16 | 48.2 s | 8.4 s | 21.6 s |
| **HP 16 (chosen)** | **43.4 s** | **7.1 s** | **20.7 s** |

I chose the HP change over the map-only fix because the chrome posts pass by only 0.9 s and add a wall the owner did not ask for. Builder: remove the `KNOWN_GAP` entry for level 10 in `tests/levels_test.gd` and set `SIM_MEDIAN[10]` to `[46, 40]` (v3 sim).

### 16.7 Maps, levels 16-30 (build these exactly)

Format as in 15.7, plus: `S` switch, `A` / `B` ghost set A / B, `O` magnet, `1` / `2` portal pair 1 / 2, lowercase `a` / `b` / `o` = carriers. These are the exact strings the sim ran.

**Level 16: Bryteren** (carriers: komet, ekko in reading order; bonus pool: komet, ekko, bredvinge)
```
r0 ..........
r1 GGGGGGGGGG
r2 ABABABABAB
r3 BABABABABA
r4 GGNGGGGNGG
r5 ..........
r6 ..S....S..
r7 ..........
r8 .g..GG..g.
```
Intro to ghosts: a checker of set A (solid) and set B (phased) behind a Glass roof. Hit a switch (r6) or wait 7 s and the checker turns inside out. Novas in r4 open the wall from below.

**Level 17: Skyggemarsj** (carriers: ekko, komet in reading order; bonus pool: komet, ekko, bredvinge; march rows r1-r5, floor_y 1000)
```
r0 ..........
r1 .GGGGGGGG.
r2 .AAAAAAAA.
r3 .SBBNNBBS.
r4 .AAAAAAAA.
r5 .GgGGGGgG.
```
An 8-wide march block whose ghost rows ride along, with the two switches built into the block itself, so they come down toward the paddle.

**Level 18: Saktetid** (carriers: saktetid in reading order; bonus pool: komet, ekko, bredvinge)
```
r0 ..........
r1 GGGGGGGGGG
r2 GNGABBAGNG
r3 GGGBAABGGG
r4 .GGGNNGGG.
r5 ..........
r6 ...S..S...
r7 ..........
r8 M...gg...M
```
Saktetid arrives from the two carriers in r8, between two Gliders. A ghost diamond sits in the middle of a Nova-salted wall; Vanlig is fast now (830), so the slow tape is a real help.

**Level 19: Filskifte** (carriers: saktetid, ekko in reading order; bonus pool: komet, ekko, bredvinge, saktetid)
```
r0 ..........
r1 GGGGGGGGGG
r2 GNGGDDGGNG
r3 ABABABABAB
r4 ..........
r5 ...S..S...
r6 ..........
r7 .M..gg..M.
r8 ..........
r9 M........M
```
One ghost checker row under a Nova wall, central switches, and two glider lanes (r7, r9) that cross the open field.

**Level 20: Lastebilen** (carriers: ekko, komet in reading order; bonus pool: komet, ekko, saktetid; boss HP 12 / 14, speed 70 / 110, minions no, on_phase ['shield_up', 'shield_up'])
```
r0 ..........
r1 ..GGGGGG..
r2 .NGBBBBGN.
r3 ..........
r4 ...K++....
r5 ...+++....
r6 .AAAAAAAA.
r7 S........S
r8 ..g.GG.g..
```
Lastebilen glides in the middle (r4-r5) under a roof of Glass and B ghosts and over its own ghost tailgate (set A, r6). The switches at the wall ends of r7 drop the tailgate; every phase change slams it shut again (`shield_up`). Top corners are empty on purpose: corner bricks behind a gliding boss made 20-30 s gaps (my calc).

**Level 21: Ormehull** (carriers: komet, ekko in reading order; bonus pool: komet, ekko, saktetid)
```
r0 ........1.
r1 GGGGGGGGGG
r2 GGNGGGGNGG
r3 DGGGDDGGGD
r4 GGGGGGGGGG
r5 ..........
r6 ..........
r7 .1......g.
r8 ..g.......
```
Portal intro: the low portal (r7 c1) sends a rising ball out of the top portal (r0 c8) behind the wall, so it rattles down through the bricks from above.

**Level 22: Krystallbuer** (carriers: ekko, komet in reading order; bonus pool: komet, ekko, bredvinge, saktetid)
```
r0 1........2
r1 .GGGGGGGG.
r2 .GNGTTGNG.
r3 .GGGGGGGG.
r4 ..........
r5 M...MM...M
r6 ..........
r7 ..2....1..
r8 .g.M..M.g.
```
Two pairs that swap sides (left low to right high and back) and six Gliders in r5 and r8.

**Level 23: Skjoldnett** (carriers: skjoldnett in reading order; bonus pool: komet, ekko, skjoldnett, saktetid)
```
r0 .........1
r1 .GGGGGGGG.
r2 GDGGNNGGDG
r3 GGAABBAAGG
r4 .GGGGGGGG.
r5 ..........
r6 1..S..S...
r7 ..........
r8 ..g....g..
```
Skjoldnett from the carriers in r8 (Vanlig: +1 net charge; Lett: Bredvinge). One portal low on the left wall (r6 c0) leads behind the wall at the top right; a small ghost band in r3.

**Level 24: Labyrint** (carriers: skjoldnett, ekko in reading order; bonus pool: komet, ekko, neonpuls, skjoldnett; march rows r1-r4, floor_y 700)
```
r0 ..........
r1 ..GAAAAG..
r2 ..NBBBBN..
r3 ..GAAAAG..
r4 ..TGGGGT..
r5 ..........
r6 ..........
r7 1.S....S.1
r8 ..........
r9 ...g..g...
```
A 6-wide march block of ghosts that stops stepping at y 700, above a portal pair at both walls (r7) that throws the ball across the field.

**Level 25: Krystallhjertet** (carriers: ekko, komet in reading order; bonus pool: komet, ekko, neonpuls, skjoldnett; boss HP 18 / 24, speed 0 / 0, minions yes, on_phase ['jump', 'jump'], jump [[1, 6], [1, 1]])
```
r0 ..........
r1 ...K++....
r2 ...+++....
r3 ..........
r4 GGDGGGGDGG
r5 GNGGTTGGNG
r6 ..........
r7 .1......1.
r8 ..g....g..
```
Krystallhjertet does not glide: at each phase change it jumps (r1 c3 -> r1 c6 -> r1 c1) and drops minions under its new spot. The portal pair in r7 swaps the ball across.

**Level 26: Magneten** (carriers: komet, ekko in reading order; bonus pool: komet, ekko, neonpuls, saktetid)
```
r0 ..........
r1 GGGGGGGGGG
r2 GGGOGGOGGG
r3 GNGGGGGGNG
r4 GGGGOOGGGG
r5 .GGGGGGGG.
r6 ..........
r7 ..g....g..
```
Magnet intro: four magnets inside a 50-brick wall pull the ball into the bricks. About 2 breaks per second, the busiest non-boss level in the game.

**Level 27: Dobbelmarsj** (carriers: ekko, neonpuls in reading order; bonus pool: komet, ekko, bredvinge, neonpuls; march rows r1-r2, floor_y 600, dir 1; march rows r5-r7, floor_y 1000, dir -1)
```
r0 ..........
r1 .GGNGGNGG.
r2 .GOGGGGOG.
r3 ..........
r4 ..........
r5 ..TGGGGT..
r6 ..GNggNG..
r7 ..GGGGGG..
```
Two march blocks moving in opposite directions: the upper one (r1-r2, magnets inside) starts right and stops stepping at y 600, the lower one (r5-r7) starts left and steps to y 1000.

**Level 28: Stjernestorm** (carriers: komet, skjoldnett in reading order; bonus pool: komet, ekko, neonpuls, saktetid, skjoldnett)
```
r0 1........2
r1 GGGGGGGGGG
r2 GAAOGGOBBG
r3 GBBGNNGAAG
r4 .GGGGGGGG.
r5 ..........
r6 ...S..S...
r7 .2......1.
r8 .g.M..M.g.
```
Remix: two portal pairs (each top corner leads to the low cell on the opposite side), ghost pairs and two magnets in the wall, central switches, two Gliders.

**Level 29: Siste port** (carriers: ekko, neonpuls in reading order; bonus pool: komet, ekko, bredvinge, neonpuls, saktetid, skjoldnett; march rows r1-r4, floor_y 760)
```
r0 ..........
r1 ..GAAAAG..
r2 ..NBOOBN..
r3 ..GAAAAG..
r4 ..DGGGGD..
r5 ..........
r6 ..........
r7 ..........
r8 1.S....S.1
r9 .gM....Mg.
```
Everything at once: a march block with ghosts and two magnets, a portal pair and two switches under it, Gliders in r9.

**Level 30: Neonnova** (carriers: neonpuls, ekko in reading order; bonus pool: komet, ekko, bredvinge, neonpuls, saktetid; boss HP 26 / 32, speed 0 / 0, minions no, on_phase ['minions', 'minions+nova_ring']; march rows r1-r5, floor_y 800)
```
r0 ..........
r1 ...K++....
r2 .O.+++..O.
r3 .GNGGGGNG.
r4 .GGTGGTGG.
r5 .DGGGGGGD.
r6 ..........
r7 1..g..g..1
```
Neonnova rides in a march block (r1-r5, floor 800) between two magnets. Phase 1: 4 Glass minions. Phase 2: minions and a ring of up to 6 Novas around it, so the last third of the fight is chain blasts. The wall portals (r7) swap the ball across.

### 16.8 Level data format additions

| Key | Type | Example | Notes |
|---|---|---|---|
| `march` | Dictionary or Array[Dictionary] | `[{"rows": [1, 2], "floor_y": 600, "dir": 1}, {"rows": [5, 7], "floor_y": 1000, "dir": -1}]` | Old single dictionary still valid; `dir` optional (default 1) |
| `boss.on_phase` | Array[String] | `["minions", "minions+nova_ring"]` | 16.2.7 |
| `boss.jump` | Array[Array[int]] | `[[1, 6], [1, 1]]` | Anchor [row, col] cells, cycled |
| `carriers`, `bonus_pool` | Array[String] | | New kinds: `saktetid`, `skjoldnett` |

World names for the map pages: 4 Nattveien, 5 Krystallgrotta, 6 Stjerneporten (6.2). Colour ramps for worlds 4-6 belong to graphic-designer; until they exist, keep rotating the world 1 ramp (15.8).

### 16.9 Endless generator "Neonveien" v3 (replaces 6.5)

Shown as the last page of the world map; available when `full_unlock` is true and world 1 is cleared (open question 3 still stands). Endless level k = 1, 2, 3 ... is deterministic.

1. `seed = hash("neon_bricks_endless_" + str(k))`; one RNG from that seed for every roll below, in this order. `d = min(1.0, (k - 1) / 30.0)`.
2. **Allowed elements:** world 1 elements always; any other element only if the level that introduced it (5.1 and 16.2: Triple 6, Glider 7, Bredvinge 8, Chrome 9, March 11, Neonpuls 13, Switch + Ghost 16, Saktetid 18, Portal 21, Skjoldnett 23, Magnet 26, two march blocks 27) is in the save's `cleared` list.
3. **Rows:** `n = 4 + round(4 * d)` rows from r2 down; the lowest brick row is never below r9.
4. **Template** for the left half (columns 0-4): full block, checker, stripes, diamond, pyramid or frame. Remove 10% of filled cells at random, then mirror to columns 5-9.
5. **Brick type** per filled cell, rolled in this order: Chrome `0.05 + 0.10d` (never in the lowest used row); Magnet `0.04` if allowed (max 4, never in the lowest used row); Triple `0.10d`; Double `0.20 + 0.15d`; Nova `0.08` (max 6); else Glass. Mirrored cells copy the left cell's type.
6. **Level mechanic,** one roll `u` in [0, 1), first match wins:
   - Boss: every 10th k (k % 10 == 0). Uses the L15 setup: boss `K` anchored at r0 c3 (rows r0-r1, the formation starts at r2), boss and formation form one march block, `floor_y` 800; steps 7 and 8 are skipped with HP `20 + k/5` (Vanlig) or `12 + k/10` (Lett), max 40, `on_phase ["minions", "minions"]`; if L30 is cleared and k % 20 == 0, `["minions", "minions+nova_ring"]` instead.
   - Two march blocks: `u < 0.15`, if allowed and the formation is at most 8 columns wide. Upper half of the used rows = block 1 (`dir` +1, `floor_y` = start top of block 2), lower half = block 2 (`dir` -1, `floor_y` 1000).
   - One march block: `u < 0.40`, if allowed and the formation is at most 8 columns wide (`floor_y` 1000).
   - Gliders: `u < 0.60`, if allowed: the lowest used row becomes gliders.
   - Otherwise none.
7. **Switch + ghosts:** if allowed, 30% of levels (separate roll): the 2nd and 3rd used rows become a checker, `A` where (row + col) is even and `B` where it is odd (keeps the mirror). Two switches at (lowest used row + 2, c3) and (lowest used row + 2, c6). Skip if that row is past r11.
8. **Portals:** if allowed, 25% of levels (separate roll): pair 1 at (r0, c1) and (lowest used row + 2, c8). Skip if that row is past r11 or rule 16.4.2 fails.
9. **Carriers:** `2 + floor(2d)` breakable cells in the lower half of the formation, each with a random allowed power-up (`skjoldnett` follows 16.2.4). `bonus_pool` = all allowed power-ups.
10. **Validity:** breakable count 20-48; chrome at most 20% of filled cells; the map rules in 16.4 (1-6) pass. If not, reroll with seed + 1, up to 20 tries, then fall back to the "pyramid" template with Glass only.
11. **Speeds and net:** Lett 570; Vanlig `880 + 10 * floor(k / 5)`, max 960. Paddle Lett 400, Vanlig 240. Vanlig net 3 charges; every 5th k is a breather (`d` halved, net unlimited), so every boss level (k % 10 == 0) also has an unlimited net.
12. Save the highest endless k reached; the page offers "continue from k" and "start at 1" as two icons.

### 16.10 Feel additions

| Event | Visual | Sound | Haptic (if on) | Mindre bevegelse |
|---|---|---|---|---|
| Switch hit (flip) | Switch ring pops 1.0 -> 1.15 -> 1.0 in 120 ms; ghosts crossfade 0.2 s | Two-tone "click-clack" | 15 ms | No pop; crossfade kept |
| Auto-flip warning | Switch rings and the ghosts about to turn solid pulse twice in 1.0 s (limiter) | "tick-tick" | none | Same (2 Hz, slow) |
| Ghost breaks as it turns solid | Normal break | Normal note | none | same |
| Saktetid on | Ball trail turns into a tape ribbon; 5 notches on the paddle | Music and effects pitch down over 0.3 s | 15 ms | No ribbon wobble |
| Saktetid ends | Notches gone | Pitch winds back up over 0.5 s | none | same |
| Portal in / out | 12-particle swirl at both portals, 0.3 s; the trail is cut, no line across the field | Falling "whoop" in, rising "whoop" out | none | No swirl |
| Skjoldnett catch | One pip weaves back on the net, 0.4 s | Rising "zing" | 15 ms | Pip appears at once |
| Magnet pull | Field lines brighten slightly while a ball is inside the radius (steady, no flashing) | Soft hum that rises with nearness | none | Static lines |
| Second march block | Its bricks lean the other way | Tick-tock a fifth higher than block 1 | none | No lean |
| Boss jump | Boss fades out 0.3 s, portal swirl at both spots, fades in 0.3 s | Deep "vwoom" | 20 ms | Cut, no fade |
| Nova ring | Novas fade in around the boss (0.3 s) | Ring of rising pings | 20 ms | No fade |
| Truck tailgate (`shield_up`) | Ghost row slams solid with a 4 px drop-in | Heavy "clank" | 25 ms | No drop-in |

### 16.11 Builder scope (godot-android-dev) and acceptance

Ship in this order; every step leaves a playable build.

1. **Level 10 fix** (16.6) and the test update (remove `KNOWN_GAP[10]`, `SIM_MEDIAN[10] = [46, 40]`).
2. **World 4:** Switch + Ghost (16.2.1, flip timer, warning, finale rule), Saktetid, boss `on_phase` with `shield_up`, levels 16-20, world 4 map page.
3. **World 5:** portals with the hop guard, Skjoldnett, boss `jump`, levels 21-25, world 5 map page.
4. **World 6:** Magnet, two march blocks, `nova_ring` and the spawn rule, levels 26-30, world 6 map page, then the endless page (16.9).

Placeholders allowed until graphic-designer follows up: switch = chrome brick with a ring decal; ghosts = brick mesh with outline shader and alpha; portal = flat torus; magnet = brick with a ring decal; world 4-6 backgrounds = world 1 scene with a tint.

**Acceptance for game-qa** (headless where possible; same bot as `tests/levels_test.gd`):
- Every level 1-30, 20 seeds per setting, real nets: no run reaches 300 s; Vanlig longest-gap median under 10 s.
- Sim parity for 16-30: NbSim bot medians within +-35% of the Vanlig medians in 16.5.
- Ghosts: a phased ghost never stops a ball (log check on L16); at 3 bricks left (Lett 4) no ghost is phased (log check on L16-20, 23, 24, 28, 29).
- Portals: no ball uses portals more than 3 times between two paddle or brick touches (log check on L22 and L28).
- Magnet: no ball circles a magnet (the ball's direction never turns more than 120 degrees inside one magnet's radius; log check on L26).
- March: no march piece bottom ever below its block's `floor_y`, and the two L27 blocks never overlap (log check).
- Flash limiter: at most 3 glow spikes in any 1 s window during an auto-flip warning plus a Nova chain (L18) and the L30 phase 2 change.
- Lett: no game over, unlimited net, no shake on all 30 levels.

### 16.12 Open questions for the owner

9. **World 6 element:** I picked the Magnet (bends the ball toward itself, 2 hits). Keep it, or would you rather have the Splitter or nothing new?
10. **Ghosts flip on their own every 7 s** (with a 1 s warning), so a child is never stuck waiting for a lucky switch hit. OK, or should only the switches flip them?
11. **World 6 is short:** its levels clear in 20-30 s (medians, dense and very busy) against 28-80 s in Lett and 24-54 s in Vanlig in worlds 4-5. Keep it short and loud, or add more bricks?
12. **Level 10 boss** now has 16 HP in Vanlig (was 20). Fine, or do you want the tougher fight and a map change instead?
