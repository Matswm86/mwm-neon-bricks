# MWM Neon Bricks: game design doc

Version 1, 2026-10-05, game-designer. Game renamed from "Brick Nova" to **MWM Neon Bricks** on 2026-10-05 (trademark conflict). Use the new name everywhere, including save file, class names and voice lines.

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
- Ramp (Vanlig only): +2% every 15 s since launch, capped at +15%. Resets after a net catch and on restart. Lett has no ramp (rule 16).
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
2. **Chrome jitter:** every bounce off a chrome brick or portal rim rotates the velocity by a random -3 to +3 degrees (still subject to rule 1). Walls have no jitter (feels unfair at the paddle).
3. **Loop detector:** on every wall or unbreakable-brick bounce, record (cell of contact rounded to 20 px, velocity octant). If the same record appears 3 times within 10 s with no breakable-brick hit and no paddle touch, rotate the velocity by 9 degrees toward the side with more remaining bricks, play a soft "zip" and show a short spark trail (no flash).
4. **Dry-spell timer:** if 10 s pass with no paddle touch and no brick hit (ball trapped above in chrome), apply the same 9 degree nudge, then repeat every 5 s.
5. **Helping hand (aim assist):** if `ASSIST_S` seconds pass with no brick broken (Lett 15, Vanlig 30), the next paddle bounce aims at the centre of the nearest SOLID breakable brick (angle clamped to +-MAX_BOUNCE_DEG). If none is solid (only phased ghosts left), aim at the nearest switch. The target brick glows softly for 1.0 s before the bounce (rule 18 idle-hint pattern). This kills the classic "hunting the last brick" frustration.
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

| Code | Name (NO / EN) | Hits | Shape cue | Behaviour | First level |
|---|---|---|---|---|---|
| `G` | Glass / Glass | 1 | Plain smooth slab, no marks | Breaks on hit | 1 |
| `D` | Dobbel / Double | 2 | Two raised dots side by side; first hit pops one dot and adds a crack | Breaks on 2nd hit | 2 |
| `C` | Krom / Chrome | never | Diagonal stripes + a bolt in each corner | Unbreakable, not counted, bounce gets -3..+3 deg jitter. Komet bounces off it. | 4 |
| `T` | Trippel / Triple | 3 | Three dots in a triangle; one pops per hit | Breaks on 3rd hit | 6 |
| `N` | Nova | 1 | Four-point star on the face | On break, 0.15 s later deals 1 hit to its 8 neighbours. A nova set off by a nova waits 0.35 s more, so bursts stay at 3 per second or fewer (rule 37). | 11 |
| `M` | Glider | 1 | Chevrons `< >` on both ends | Slides horizontally at 120 px/s (Lett 80) along its row, reversing at walls, chrome or other bricks. | 16 |
| `S` | Bryter / Switch | never | Ring with a dot in it (power symbol) | Not counted. A hit toggles which ghost set is solid. 0.5 s cooldown. | 21 |
| `A` / `B` | Skygge / Ghost (set A, set B) | 1 when solid | Set A: dashed outline with square corner marks. Set B: dashed outline with round dots. Solid = filled + outline; phased = outline only, 30% opacity. | Set A starts solid, set B phased. Phased ghosts let the ball through. Counted for clear. | 21 |
| `1` / `2` | Ormehull / Portal pair 1, pair 2 | never | Pair 1: single spiral. Pair 2: spiral with a star in the middle | Ball centre entering a portal circle (radius 40) leaves its partner 60 px along its velocity, velocity unchanged; 0.4 s per-ball cooldown. Not counted. | 26 |

Carrier mark: a lowercase letter (`g`, `d`, `t`, `n`, `m`) is the same brick carrying a power-up capsule, drawn with a small 5-point star inlay. The capsule drops when the brick breaks. The level data says which power-up its carriers hold.

### 5.2 Power-ups (own names, own twists)

Capsule: 112 x 56 pill with the power-up icon (shape-coded). Falls at 240 px/s (Lett 180). Lett magnet: below y 1100 the capsule drifts toward the paddle x at up to 400 px/s, so a 4-year-old catches nearly every one. Caught when its rect overlaps the paddle rect grown by 20 px. Missed capsules fade at y 1600; no penalty. Max 3 capsules falling at once (more is not possible with current carrier counts). Same power-up again = timer/count refresh, not stack.

| Name (NO / EN) | Icon | Effect | Twist | First level |
|---|---|---|---|---|
| **Komet / Comet** (VERTICAL SLICE) | Ball with a swept tail | For 8 bricks or 6 s (Lett: 10 bricks or 8 s), whichever ends first, the ball breaks any breakable brick in ONE hit and passes through it without bouncing. Still bounces off walls, chrome, switches, paddle, net. | Remaining bricks shown as small sparks orbiting the ball, one winks out per brick: the count is a shape, not a number. | 3 |
| Bredvinge / Wide Wing | Paddle with two wings | Paddle width x1.5 for 15 s (Lett x1.3 for 20 s), grows over 0.3 s, max 560 px. | Five "feathers" on each wing fold away one by one as time runs out: a countdown with no digits. | 8 |
| Ekko / Echo | Three overlapping circles | Two translucent echo balls split from the main ball at -20 and +20 degrees. | Echoes fade after 10 s and can never be "lost": falling echoes just dissolve. If the main ball falls through an empty net while an echo lives, the oldest echo becomes the main ball. | 13 |
| Saktetid / Tape Slow | Cassette reel | Ball speed x0.65 for 10 s (Lett x0.75). | Music and effects pitch down like a slowed tape, then wind back up over 0.5 s. | 18 |
| Neonpuls / Neon Pulse | Paddle with three arcs above it | 6 waves, 1.0 s apart: each deals 1 hit to the lowest breakable brick in every column the paddle overlaps. No tap needed. | Fires on its own, so it adds no input and no reflex demand. | 23 |
| Skjoldnett / Shield Net | Net with a plus | Vanlig: +1 net charge (max 3). | In Lett (net already unlimited) carriers of this type drop Bredvinge instead. | 28 |

## 6. Progression

### 6.1 Rules

- 6 worlds x 5 levels = 30 hand-made levels, then endless.
- Every world follows one rhythm: **level 1** introduces one new brick type, **level 2** practises it, **level 3** introduces one new power-up, **level 4** combines, **level 5** is a breather (fewer traps, more carriers, a picture shape, Vanlig net unlimited).
- **No sequential lock** (my call, owner said "all levels open" for stand-alone): any unlocked level can be picked from the map. The map pulses the lowest uncleared level (1 Hz glow) as the suggestion. Nothing is ever shown locked (no padlocks, rule 22 counter-consideration 1).
- **Free part (owner):** the game holds one flag, `full_unlock: bool`, default `true`. The MWM Play adapter sets it on `enter()` through a public hook `set_full_unlock(on: bool)` (same style as `set_shell_inset`). The game does not check purchases itself.
  - `full_unlock == false`: the map shows only world 1 levels 1-3. Level nodes 4-5, world arrows and the endless page are not drawn at all. Clearing level 3 shows the normal win card with replay + home only (no "next") and emits `free_levels_finished`; the shell then shows its "Du har spilt alle banene her" card.
  - `full_unlock == true`: all 30 levels and endless.
- The stand-alone build never calls the hook, so it is fully open (owner's own copy).

### 6.2 Worlds

| World | Name (NO / EN) | Setting cue for graphic-designer | New brick (L1) | New power-up (L3) |
|---|---|---|---|---|
| 1 | Neonstranda / Neon Beach | Sunset sun, palm silhouettes, grid sea | Glass, Double (L2), Chrome (L4) | Komet |
| 2 | Rutenettbyen / Grid City | Night skyline, neon signs | Triple | Bredvinge |
| 3 | Arkadehallen / Arcade Hall | Giant cabinets, pixel stars | Nova | Ekko |
| 4 | Nattveien / Night Highway | Endless road, passing lights | Glider | Saktetid |
| 5 | Krystallgrotta / Crystal Cave | Glowing crystals, mist | Switch + Ghost | Neonpuls |
| 6 | Stjerneporten / Star Gate | Space, rings, nebula | Portal | Skjoldnett |

World 1 teaches three things (Double, Komet, Chrome) on top of the basics because those are the vertical-slice elements; each still arrives alone in its own level.

### 6.3 Level table

Speeds are base ball speed in px/s. Paddle = width in px. Net: inf = unlimited, 3 = three charges (Vanlig only; Lett is always inf). Target time = median clear time to aim for. Restart chance = share of Vanlig attempts with at least one gentle restart.

| # | W | Name | New / focus | Breakable | Other | Carriers | Lett speed | Vanlig speed | Vanlig paddle | Vanlig net | Target time Lett / Vanlig | Restart chance Vanlig |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | Første lys | Glass, paddle, ball | 14 | | 0 | 520 | 680 | 280 | inf | 54 / 42 s (my calc) | 0 |
| 2 | 1 | To prikker | Double | 22 | | 0 | 520 | 680 | 280 | inf | 93 / 76 s (my calc) | 0 |
| 3 | 1 | Kometen | Komet | 32 | | 2 Komet | 520 | 680 | 280 | inf | 100 / 82 s (my calc) | 0 |
| 4 | 1 | Krompilarer | Chrome | 22 | 4 C | 2 Komet | 520 | 680 | 280 | inf | 95 / 83 s (my calc) | 0 |
| 5 | 1 | Palmesol | Breather (sun picture) | 28 | | 2 Komet | 520 | 680 | 280 | inf | 79 / 75 s (my calc) | 0 |
| 6 | 2 | Trekant | Triple | 24 | | 1 Komet | 530 | 720 | 280 | 3 | 90 / 80 s | 5% (guess) |
| 7 | 2 | Skyline | Triple + chrome roofs | 30 | 6 C | 2 Komet | 530 | 720 | 280 | 3 | 100 / 90 s | 8% (guess) |
| 8 | 2 | Vingene | Bredvinge | 32 | 4 C | 2 Bredvinge | 530 | 720 | 280 | 3 | 100 / 90 s | 6% (guess) |
| 9 | 2 | Gatelys | Chrome corridors | 30 | 10 C | 1 Komet, 1 Bredvinge | 530 | 720 | 280 | 3 | 110 / 100 s | 10% (guess) |
| 10 | 2 | Taxi | Breather (car picture) | 30 | | 3 mixed | 530 | 720 | 280 | inf | 90 / 80 s | 0 |
| 11 | 3 | Nova | Nova | 30 | | 1 Komet | 540 | 760 | 260 | 3 | 90 / 80 s | 8% (guess) |
| 12 | 3 | Kjedereaksjon | Nova chains | 36 | 4 C | 1 Bredvinge | 540 | 760 | 260 | 3 | 100 / 90 s | 10% (guess) |
| 13 | 3 | Ekko | Ekko | 36 | 4 C | 2 Ekko | 540 | 760 | 260 | 3 | 100 / 90 s | 8% (guess) |
| 14 | 3 | Flipper | Chrome bumpers + novas | 34 | 8 C | 1 Ekko, 1 Komet | 540 | 760 | 260 | 3 | 110 / 100 s | 12% (guess) |
| 15 | 3 | Joystick | Breather (joystick picture) | 32 | | 3 mixed | 540 | 760 | 260 | inf | 90 / 85 s | 0 |
| 16 | 4 | Glidere | Glider | 30 | | 1 Komet | 550 | 800 | 260 | 3 | 100 / 90 s | 10% (guess) |
| 17 | 4 | Rushtid | Two glider lanes | 36 | 4 C | 1 Ekko | 550 | 800 | 260 | 3 | 110 / 100 s | 12% (guess) |
| 18 | 4 | Saktetid | Saktetid | 38 | 4 C | 2 Saktetid | 550 | 800 | 260 | 3 | 110 / 100 s | 10% (guess) |
| 19 | 4 | Filskifte | Gliders + chrome gates | 38 | 10 C | 1 Saktetid, 1 Komet | 550 | 800 | 260 | 3 | 120 / 110 s | 15% (guess) |
| 20 | 4 | Solnedgang | Breather (road into sun) | 34 | | 3 mixed | 550 | 800 | 260 | inf | 95 / 90 s | 0 |
| 21 | 5 | Bryteren | Switch + Ghost | 30 | 2 S | 1 Komet | 560 | 840 | 240 | 3 | 110 / 100 s | 12% (guess) |
| 22 | 5 | Skyggevegg | Ghost walls guarding rows | 38 | 2 S, 4 C | 1 Ekko | 560 | 840 | 240 | 3 | 120 / 110 s | 15% (guess) |
| 23 | 5 | Neonpuls | Neonpuls | 40 | 2 S | 2 Neonpuls | 560 | 840 | 240 | 3 | 110 / 100 s | 12% (guess) |
| 24 | 5 | Labyrint | Switch + chrome + triples | 40 | 2 S, 10 C | 1 Neonpuls, 1 Saktetid | 560 | 840 | 240 | 3 | 130 / 120 s | 18% (guess) |
| 25 | 5 | Krystallhjerte | Breather (heart picture) | 36 | | 3 mixed | 560 | 840 | 240 | inf | 100 / 95 s | 0 |
| 26 | 6 | Ormehull | Portal (1 pair) | 34 | 1 pair | 1 Komet | 570 | 880 | 240 | 3 | 110 / 100 s | 15% (guess) |
| 27 | 6 | Dobbelport | Two portal pairs | 40 | 2 pairs, 4 C | 1 Ekko | 570 | 880 | 240 | 3 | 120 / 110 s | 18% (guess) |
| 28 | 6 | Skjoldnett | Skjoldnett | 42 | 1 pair, 4 C | 2 Skjoldnett | 570 | 880 | 240 | 3 | 120 / 110 s | 12% (guess) |
| 29 | 6 | Alt i ett | Every element | 44 | 1 pair, 2 S, 8 C | 1 Neonpuls, 1 Saktetid | 570 | 880 | 240 | 3 | 140 / 130 s | 20% (guess) |
| 30 | 6 | Neonnova | Finale (big nova picture), generous | 48 | 1 pair | 4 mixed | 570 | 880 | 240 | inf | 130 / 120 s | 0 |

Levels 1-5 times are (my calc): `tools/clear_time_sim.py`, 150 runs per level and setting, with a paddle that never misses and hits at a random offset of up to 60% of its half-width. Real children will be slower; treat these as floors. Levels 6-30 times and all restart chances are design targets (guess) that the builder verifies with the same sim and the owner verifies on the phone. Rule of thumb for later maps: keep Lett median under 2.5 min so one level fits a young child's attention.

### 6.4 World 1 maps (vertical slice, build these exactly)

Format: 10 characters per row = columns c0-c9; rows listed from r0 (top, y 340) down; rows not listed are empty. `.` = empty. Codes from section 5.1. Every map is mirror-symmetric except where noted.

**Level 1: Første lys** (glass only; 14 bricks; no carriers)
```
r0 ..........
r1 ..........
r2 ..........
r3 ..........
r4 .GGGGGGGG.
r5 ..GGGGGG..
```
Low and wide: the first bounce off the paddle almost always hits something.

**Level 2: To prikker** (double; 14 G + 8 D = 22 bricks, 30 hits)
```
r0 ..........
r1 ..........
r2 ..........
r3 .GDDGGDDG.
r4 .GDDGGDDG.
r5 ..GGGGGG..
```
A face: two blocks of doubles are the eyes. The first hit on a double shows the dot popping, which teaches "this one needs two".

**Level 3: Kometen** (Komet; 26 G + 4 D + 2 g = 32 bricks; carriers: Komet)
```
r0 ..........
r1 ..........
r2 GGGGGGGGGG
r3 GGDDGGDDGG
r4 GGGGGGGGGG
r5 ..g....g..
```
The two carriers hang below the wall, so they are almost always the first things hit. The dense wall above makes the comet's ploughing visible.

**Level 4: Krompilarer** (chrome; 18 G + 2 D + 2 d = 22 bricks; 4 chrome; carriers: Komet)
```
r0 ..........
r1 ..........
r2 GGGGGGGGGG
r3 .GGGGGGGG.
r4 ..........
r5 C...CC...C
r6 ..........
r7 ..dD..Dd..
```
Chrome posts in r5 deflect but never enclose anything. Carrier doubles in r7 drop their capsule on the second hit.

**Level 5: Palmesol** (breather; 18 G + 8 D + 2 g = 28 bricks; carriers: Komet)
```
r0 ..........
r1 ..........
r2 ..GGGGGG..
r3 .GGGGGGGG.
r4 ..........
r5 .DDDDDDDD.
r6 ..........
r7 ..GgGGgG..
```
A synthwave sun with horizontal slices. Two comets make the finale of world 1 feel generous.

Level data file format (suggested, builder's call): one JSON or `.tres` per level with `rows` (array of 12 strings), `carrier_powerup`, `lett_speed`, `vanlig_speed`, `vanlig_paddle`, `vanlig_net` (0 = unlimited). Values come from the table in 6.3.

### 6.5 Endless generator ("Neonveien", after the 30 levels)

Shown as the last page of the world map. Available when `full_unlock` is true and world 1 has been cleared (my call). Endless level k = 1, 2, 3 ... is deterministic: same k, same layout.

1. `seed = hash("neon_bricks_endless_" + str(k))`; RNG from that seed. `d = min(1.0, (k - 1) / 30.0)`.
2. Elements allowed: those first introduced in levels the player has cleared (save file). World 1 elements always.
3. Rows used: `4 + round(4 * d)`, starting at r2. Lowest brick row never below r9.
4. Pick one template for the left half (columns 0-4): full block, checker, stripes, diamond, pyramid, frame. Remove 10% of filled cells at random. Mirror to columns 5-9.
5. Per filled cell, roll type: Chrome `0.05 + 0.10d` (never in the lowest used row); Triple `0.10d`; Double `0.20 + 0.15d`; Nova `0.04` (max 3 per level); else Glass. Gliders: if allowed, 30% of levels turn one full row into gliders (that row is not mirrored-locked). Switch + ghosts: if allowed, 30% of levels: switches at the two outer cells of one row, one ghost row of set A, one of set B. Portals: if allowed, 25% of levels: one pair in two empty mirrored cells.
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
| `BALL_SPEED_BASE` | 520-570 by world | 680-880 by world | px/s | Table 6.3 |
| `BALL_SPEED_MIN / MAX` | 300 / 1000 | same | px/s | Hard clamps |
| `SPEED_RAMP_STEP / EVERY / CAP` | off | +2% / 15 s / +15% | | Resets on net catch and restart |
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

## 8. Screens and session shape

### 8.1 World map

One world per page: the world's scene in the background, 5 level discs (diameter 200, hit area 240) on a neon road climbing the screen between y 400 and 1500, never in the top-left 232 square or below y 1664. Cleared level: disc holds a star shape. Suggested next level: soft 1 Hz pulse (well under 3 flashes/s). World change: left and right arrow discs (200 px) at y 1560, x 160 and 920. No swipe, no scroll (rule 20). Stand-alone only: gear disc at top-right opens settings (section 10.2).

### 8.2 First 60 seconds (no text anywhere)

- 0 s: first ever launch skips the map and opens level 1 directly. Camera sweep 1.0 s (cut under "Mindre bevegelse"). Ball rests on the paddle.
- 1.0 s: a hand icon slides left-right in the drag zone (loop 1.6 s) until the first drag. Voice line (if recorded) "Dra fingeren hit og dit" (action word last in spirit, rule 17).
- 3.0 s: ball launches by itself if the child has not tapped.
- First brick break: big satisfying break (section 9). Each following brick before the next paddle touch plays one step higher in the scale.
- Ball misses: net catches it with a soft "bwomm" and ripple, play continues. The child learns the net is friendly.
- About 54 s (Lett, my calc): last brick, slow-mo, win card.
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
| Brick break | GPU shards: 24 particles, 0.5 s life, gravity toward camera; local glow on the brick area only | Pentatonic note, one step up per brick since the last paddle touch (max 8 steps), resets on paddle touch | none | No particles: brick fades out in 150 ms |
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
| Ball speed | 520-570 px/s, no ramp | 680-880 px/s, +2%/15 s up to +15% |
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

## 11. Shell hooks (summary for the builder)

- Read `Engine.get_meta(&"mwm_play_shell")`: hide own home disc, own sound button and own settings gear.
- `set_full_unlock(on: bool)` (default true), `set_difficulty(easy: bool)` (default Lett), `set_shell_inset(Vector2(232, 232))` (no-op here, nothing sits there anyway), plus the shell's four settings (sfx, music, haptics, less motion).
- Signals up: `level_card_shown(level_id: int)`, `free_levels_finished()`.
- Public `save_game()` for the adapter's `exit()`.
- Unique class names (the sync script prefixes later).

## 12. Vertical slice (what godot-android-dev builds first)

In: world 1 map page, levels 1-5 exactly as in 6.4, paddle with relative drag, one ball, Glass + Double + Chrome, Komet capsule and effect, net (unlimited in world 1, but the 3-charge mode and gentle restart are also built and covered by a headless test with a test-only level flag, because Vanlig needs them from level 6), anti-stuck rules 1-6, aim assist, win card with the three icon discs, Lett/Vanlig switch, `full_unlock` flag and both signals, "Mindre bevegelse", save file, flash limiter, auto-launch, idle hand hint, shell home square kept free.

Out: worlds 2-6, other bricks and power-ups, endless, voice lines (blocked on a native Norwegian voice, see MWM Les), store art.

Slice acceptance hints for game-qa: Lett level 1 clears with no instruction (kids walk-through, sound off); no gameplay touch target below y 1664 or inside 232x232; never more than 3 flashes in any 1 s window during a Komet run through level 3; ball never travels flatter than 20 degrees (log check); level 4 never has a ball trapped above chrome for more than 15 s.

## 13. Play together tip (rule 42, draft)

"Bytt på: når en kloss med stjerne faller ned, er det den andres tur å styre." ("Take turns: when a star brick drops a capsule, the other person steers.")

## 14. Open questions for the owner

1. **Difficulty setting placement:** a "Lett / Vanlig" row in the MWM Play parent area (needs a small shell change) as I propose, or a child-facing two-icon choice inside the game?
2. **Net charges:** I read "3 charges, then gently restart" as: the net catches 3 times, the 4th miss restarts the level from full bricks. Correct, or should the 3rd catch already restart?
3. **Endless:** available after world 1 is cleared and only in the paid part (my default)? Or only after all 30 levels?
4. **No level order:** in the full game any level can be picked from the map, nothing ever shown locked. OK, or should worlds open one after another?
