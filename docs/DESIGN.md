# MWM Neon Bricks: visual design spec

Owner: graphic-designer. Version 2, 2026-10-07 (worlds 2-6, new elements and QA look fixes added as sections 11-13; section 2c is superseded by 11). Version 1, 2026-10-05. The builder reads this before touching any colour, material, light, camera or UI node. Every token carries its rule and its reason. Game rules and numbers live in `docs/GDD.md`; child rules (rule N) are in `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. Numbers tagged (my calc) are my own arithmetic on rendered pixels, WCAG 2.x formula.

Mockups (all rebuilt by the scripts in `docs/mockups/src/`):

| File | What it shows |
|---|---|
| `docs/mockups/world1_mock.png` | World 1 Neonstranda, level 4 "Krompilarer" mid-play, 1080x1920, stand-alone home disc |
| `docs/mockups/world1_zones.png` | Same frame with zones: home square (white), drag zone (green), wrist strip (red), playfield (yellow line) |
| `docs/mockups/wincard_mock.png` | Win card over the dimmed scene |
| `docs/mockups/elements.png` | Brick colours, the slice brick types, both paddles, ball, Komet ball, capsule, three net states |
| `docs/mockups/world1_fix_mock.png` | World 1 with the section 13 fixes (neon sun through the glass window, lit paddle, continuous top rail) |
| `docs/mockups/world2_mock.png` ... `world6_mock.png` | One gameplay frame per world 2-6 (section 11) with that world's new elements |
| `docs/mockups/worlds_overview.png` | All six worlds side by side (the "different at a glance" check) |
| `docs/mockups/elements_w26.png` | New bricks, switch, ghosts A/B solid and phased, portals, capsules, bosses L20/L25/L30, paddle v1 vs v2 |
| `docs/mockups/src/*.py` | Blender 4.5 scripts (`blender -b -P world1_mock.py -- out.png`, `elements.py -- raw.png labels.json assets/models`) and Pillow overlays (`overlay.py`, `label_sheet.py`) |

---

## 1. Visual theme

**A glossy neon arcade frame standing on a synthwave beach at sunset: candy-bright bricks, one white-hot ball and a cyan paddle in front of a dimmed sun, grid sea and palm silhouettes.**

References:
- **Far Cry 3: Blood Dragon / classic "Outrun" synthwave key art**: take the sliced setting sun, the magenta perspective grid and the palm silhouettes. Leave behind the busy chrome text and scanline noise.
- **Holedown (Grapefrukt)**: take the readability of a dark field with a few saturated objects and almost no UI. Leave behind the flat 2D style; ours is bevelled 3D with real highlights.

The world sits **behind** a dark tinted glass field, so the vista sets the mood while the bricks, ball and paddle are the only bright, saturated things in play. Far from Krypton Egg: no teal floor, no wood, no tiled walls, no top-down board; nothing from `projects/krypton-egg/assets/` is used.

## 2. Palette

Split about 60 / 30 / 10: 60% dark vista and tinted field (night navy, plum), 30% warm bricks and the sun, 10% cyan for what the player controls (paddle, net, ball halo). Magenta and violet are play content here (games are exempt from the no-purple rule, owner's decision). The UI chrome (win card, home disc, settings) is warm white and ink, never purple.

### 2a. Shared brick colours (all worlds)

Brick colour is decoration only. The brick **type** is always told by shape (section 7), so colour is never the only cue (rule 36).

| Token | Hex | Godot | Role |
|---|---|---|---|
| sun | #FFC93C | Color(1.000, 0.788, 0.235) | Brick ramp step 1, Komet tail, sparks |
| tangerine | #FF8A3D | Color(1.000, 0.541, 0.239) | Ramp step 2, shards, win card "next" disc |
| coral | #FF5A5F | Color(1.000, 0.353, 0.373) | Ramp step 3 |
| hotpink | #FF2E88 | Color(1.000, 0.180, 0.533) | Ramp step 4, wall neon tubes |
| magenta | #D63AF9 | Color(0.839, 0.227, 0.976) | Ramp step 5, world 1 sea grid |
| violet | #8A5CFF | Color(0.541, 0.361, 1.000) | Ramp step 6 (worlds 5-6) |
| cyan | #2EE6FF | Color(0.180, 0.902, 1.000) | **Player colour**: paddle light strip, net, ball halo, capsule rim. Not used for bricks in worlds 1-4. |
| mint | #4DFF9A | Color(0.302, 1.000, 0.604) | Ramp colour in world 5 only. v2: was #3DFFB0, moved greener so it never reads as the player cyan |

### 2b. Fixed element colours

| Token | Hex | Godot | Use |
|---|---|---|---|
| chrome | #C9CED8 | Color(0.788, 0.808, 0.847) | Chrome brick base, metallic 1.0, roughness 0.22 |
| chrome_stripe | #9AA1B0 | Color(0.604, 0.631, 0.690) | Diagonal stripes (static, low contrast, rule 38) |
| bolt | #5E6472 | Color(0.369, 0.392, 0.447) | Chrome corner bolts |
| dot | #FFF4D6 | Color(1.000, 0.957, 0.839) | Double/Triple dots, emissive 3 |
| star_inlay | #FFE7A0 | Color(1.000, 0.906, 0.627) | Carrier star, emissive 4 |
| paddle_body | #1C1A33 | Color(0.110, 0.102, 0.200) | Paddle shell, metallic 0.7, roughness 0.25, clear coat |
| ball | #FFFFFF | Color(1.000, 1.000, 1.000) | Ball core, unshaded |
| wall_rail | #15122B | Color(0.082, 0.071, 0.169) | Frame rails, metallic 0.6, roughness 0.45 |
| field_tint | #000000 at 72% alpha | Color(0, 0, 0, 0.72) | Glass behind the playfield, unshaded |

### 2c. World accents (one environment per world)

**Superseded 2026-10-07 by section 11** (exact palettes, props and shader values). Kept for history.

Each world keeps the same bricks, paddle, ball and frame; only the vista, the wall-tube colour and the brick row ramp change.

| World | Sky top / mid / low | Vista accent | Wall tubes | Brick ramp (top row first) | Vista contents |
|---|---|---|---|---|---|
| 1 Neonstranda | #0B0630 / #3A0E5C / #C2186B, horizon #FF7A3D | sea grid magenta #D63AF9, ridges #FF2E88 | hotpink | sun, tangerine, coral, hotpink, magenta | Sliced sunset sun, grid sea, wireframe ridges, 3 palm silhouettes (#12061F) |
| 2 Rutenettbyen | #050B24 / #0E1E4A / #24407A | windows #2EE6FF, signs #FF2E88 | cyan-white #BFF6FF | hotpink, coral, tangerine, sun | Skyline silhouette cards with lit window atlas, 2 neon signs (shapes, no words) |
| 3 Arkadehallen | #10061E / #2A0B3D / #5A1450 | cabinet screens #FFE14D, #FF3D6E | sun | sun, coral, hotpink, violet | Giant cabinet silhouettes, pixel-star sky, checker floor (dark plum, never teal) |
| 4 Nattveien | #06040F / #1A0A26 / #4A1030 | tail lights #FF3B30, lamps #FFB23D | coral | coral, tangerine, sun, hotpink | Road to the horizon, lamp posts as a MultiMesh, light streaks scrolling (UV, not geometry) |
| 5 Krystallgrotta | #040A14 / #0B1E33 / #18324F | crystals #3DFFB0 + #8A5CFF, mist #1B2A4A | mint | mint, violet, magenta, hotpink | Crystal clusters (low-poly, emissive edges), mist cards |
| 6 Stjerneporten | #03020A / #150A2E / #2B0B4F | ring #FFF0C2, nebula #8A5CFF | violet | violet, magenta, hotpink, sun | Nebula sky texture, a ring gate behind the field, slow star parallax |

Rule for every world: the vista behind the tinted field must leave the white ball at **4.5:1 or more** against the brightest spot it can cross (see contrast table). If a vista element is brighter, dim its emission, do not brighten the ball.

### 2d. UI chrome (win card, home disc, map discs, settings)

| Token | Hex | Godot | Use |
|---|---|---|---|
| card | #FFF8EE | Color(1.000, 0.973, 0.933) | Win card, settings panel |
| disc | #FFFFFF | Color(1, 1, 1) | Icon discs, home disc |
| ink | #24211D | Color(0.141, 0.129, 0.114) | All icons, disc rings (5-6 px), star outline |
| card_edge | #8F8371 | Color(0.561, 0.514, 0.443) | 4 px card outline |
| next | #FF8A3D (tangerine) | Color(1.000, 0.541, 0.239) | The "next" disc only: the one most visible action |
| reward | #FFC93C (sun) | Color(1.000, 0.788, 0.235) | Win star fill, cleared-level star on the map |

### 2e. Contrast (my calc, sampled from the rendered `world1_mock.png` and `wincard_mock.png`)

| Pair | Ratio | Need |
|---|---|---|
| Ball #FFFFFF vs dark field #302337 | 14.8:1 | 3.0 (object) |
| Ball vs dimmed sun behind the tint #A95C2E (brightest spot it crosses) | 4.8-4.9:1 | 4.5 (my bar for the one thing a child must track) |
| Paddle strip #8BFDFE vs grid sea under it #501D48 | 10.9:1 | 3.0 |
| Sun brick #FFFF5F vs field | 13.9:1 | 3.0 |
| Tangerine brick #FFCE8A vs field | 10.2:1 | 3.0 |
| Hotpink brick #FF7CF7 vs field | 6.7:1 | 3.0 |
| Chrome brick #8F91A9 vs field | 4.8:1 | 3.0 |
| Home disc white vs sky #210D32 | 18.0:1 | 3.0 |
| Ink icons on white disc | 16.0:1 | 3.0 (rule 35) |
| Ink icon on tangerine "next" disc | 6.8:1 | 3.0 |
| Ink outline vs sun-yellow star | 10.4:1 | 3.0 |
| Card #FFF8EE vs dimmed scene #230E26 | 17.1:1 | 3.0 |
| Ink on card (any text, if ever added) | 15.2:1 | 4.5 (rule 34) |

## 3. Typography

The child never reads in this game: no text in gameplay, map, win card or HUD (GDD 8.2). Numbers are never shown (counts are shapes: dots, pips, orbiting sparks, wing feathers).

- **Stand-alone settings panel and credits (adult-facing):** Fredoka (SIL OFL 1.1, already in `projects/mwm-play/assets/fonts/Fredoka.ttf` + `Fredoka-OFL.txt`; copy both). Body 40 px, labels 44 px, headings 56 px, ink on card.
- **Logo / store art only:** Audiowide (SIL OFL 1.1, Google Fonts). Not bundled yet; graphic-designer adds it with its licence when store art is made. Never used in game UI.

## 4. Components

| Component | Size (px at 1080 wide) | Look | Pressed state |
|---|---|---|---|
| Home disc (stand-alone only; hidden when `mwm_play_shell` meta is set) | dia 136, centre (104, 104), hit area 0,0 to 216,216 | Same as the shell disc: white, 5 px ink ring, ink house 68 px. Guard state copies the shell (dia 164, halo 208, ring fills over 2.0 s) | Scale 0.92, 100 ms |
| Win card | 880 x 910, x 100-980, y 540-1450, radius 56 | card fill, 4 px card_edge outline, a flat dark offset shadow (10 px down, no blur) | none |
| Win star | outer radius 180, ink outline 16 px | reward fill; lands with a 0.25 s scale 0.6 -> 1.08 -> 1.0 | none |
| Icon discs on the card | replay dia 200 at x 270, map dia 200 at x 540, next dia 240 at x 810, all at y 1300 | white (next: tangerine), 6 px ink ring, ink icon 100-110 px. Icons: circular arrow, three dots on a road (the map), play triangle | Scale 0.92 + fill green_soft #E3F0EA for 100 ms, act on release |
| Resume disc (after app pause) | dia 240, screen centre | white disc, ink ring, ink play triangle, scene dimmed 50% | same |
| Map level disc | dia 200, hit 240 | Dark glass disc (#1C1A33) with a 6 px cyan ring and the level's brick picture as a tiny 3D thumbnail; cleared = sun-yellow star with ink outline at the disc's top-right. Suggested level: ring pulses 1 Hz between 60% and 100% brightness (never a flash) | Scale 0.92 |
| Map world arrows | dia 200 at (160, 1560) and (920, 1560) | white disc, ink ring, ink chevron | Scale 0.92 |
| Gear (stand-alone map only) | dia 160, centre (960, 104), hit 216x216 to the corner | white disc, ink ring, ink gear | Scale 0.92 |
| Hand hint | 180 px hand icon | white hand with ink outline, slides left-right in the drag zone at y 1520 over 1.6 s | n/a |

Every target is at least 200 px and none sits at y >= 1664 or inside the 232 x 232 top-left square (except the home disc itself, which is the reason that square exists).

## 5. Layout

All zones exactly as GDD 3.1; `world1_zones.png` proves the mock matches. Mapping: 1 logic px = 0.01 m on the play plane.

| Band (y px) | Content |
|---|---|
| 0-232 | Sky band with stars. Home disc top-left. Nothing else drawn here. |
| 240-280 | Top rail with the neon tube on its lower edge (inner wall at y 280). |
| 280-1700 | Playfield behind 72% black tint. Bricks from y 340, paddle centre 1420, net 1540. |
| 960-1664 | Drag zone (invisible). |
| 1664-1920 | Wrist strip: bare grid sea, cyan end-cap lamps at the rail feet; no target, no HUD. |

Taller screens (20:9): the arena keeps its size and anchors to the bottom (GDD 3.1); the extra height shows more sky and stars, never stretched art. Tablets: side margins show more sea and palms; the vista is built 30% wider than 1080 to cover this.

## 6. Depth and motion

### 6a. Camera
- At rest: Camera3D perpendicular to the play plane (looking down -Z at the plane, which faces +Z), perspective, vertical FOV 70.8 deg (equals a 45 mm lens on 36 mm width: the 10.8 m plane fills 1080 px at 13.5 m distance).
- Horizon at screen y 1310 by **lens shift, not tilt**: eye height 6.2 m above the sea, `projection = PROJECTION_FRUSTUM` (size and offset are measured at the near plane: `frustum_offset.y = 3.4 * near / 13.5`, so the view shifts 3.4 m at the play plane; Blender equivalent: shift_y 0.315). This keeps logic and screen positions identical (bricks never skew) while the sun sits low and the sky gets the space.
- Idle drift: +-1.5 deg yaw on a 12 s sine cycle around the field centre (GDD 9). Gives parallax between frame, palms and sun, which is what sells "3D" at phone distance.
- Level intro: 1.0 s ease-out sweep from 14 deg below to the rest pose. Never more than 15 deg from perpendicular (GDD 4).
- Last brick: 8% push-in toward the brick over the slow-mo window, ease in-out.
- Under "Mindre bevegelse": no drift, no sweep (cut), no push-in.

### 6b. Motion rules
- Flashes: global limiter, at most 3 glow spikes per second (rule 37). A "glow spike" is any emission energy jump above 2x on an area larger than one brick. Extra breaks inside the same 333 ms get shards and sound, no spike.
- No full-screen flash ever. No flicker. Chrome stripes are static. The suggested-level pulse is 1 Hz and smooth.
- Screen shake: last brick 10 px for 250 ms, Nova 6 px for 180 ms, nothing else shakes. Shake moves the camera, never the UI layer. Off under "Mindre bevegelse".
- UI tweens 0.15-0.25 s ease-out; win card fades in 250 ms (instant under "Mindre bevegelse").
- Paddle squash 90% height, 100 ms; brick squash 90%, 80 ms (both off under "Mindre bevegelse").
- Slow-mo on the last brick stays under "Mindre bevegelse" (it is time, not movement).

## 7. Game art

### 7a. Construction
Own Blender models only, built by `docs/mockups/src/nb_parts.py`, exported to `assets/models/` (GLB, Y-up, front faces +Z in Godot, metres, origin at centre). Rounded bevels on everything; no sharp primitive edges.

| File | Size (m, x / depth / y) | Notes |
|---|---|---|
| `brick_glass.glb` | 0.92 x 0.32 x 0.44 | Body (bevel 0.07) + neon rim tube (radius 0.012, inset 0.06) as a second surface |
| `brick_double.glb` | 0.92 x 0.36 x 0.44 | Body + rim + 2 dot domes (r 0.075, at x +-0.17). Builder may split the dots into child nodes to pop one |
| `brick_double_hit.glb` | 0.92 x 0.36 x 0.44 | One dot + a dark crack decal at the popped dot's place |
| `brick_chrome.glb` | 0.92 x 0.32 x 0.44 | Metal body, stripes from the shader, 4 hex bolts (r 0.035) |
| `brick_carrier_glass.glb` | 0.92 x 0.32 x 0.44 | Glass + 5-point star inlay (r 0.12) |
| `paddle_vanlig_280.glb` | 2.80 x 0.41 x 0.36 | Stadium profile shell + cyan light strip loop + 2 white end lamps |
| `paddle_lett_400.glb` | 4.00 x 0.41 x 0.36 | Same, Lett width. For Bredvinge, build the paddle in code as two end caps + a scaled middle; do not scale this mesh in x (the end lamps would stretch) |
| `ball.glb` | 0.44 diameter | Sphere; use an unshaded white material in Godot |
| `capsule_komet.glb` | 1.12 x 0.32 x 0.56 | Dark glass pill, cyan rim, white ball + yellow tail icon on the face |
| `palm_silhouette.glb` | 14.8 x 0.6 x 25.3 | Flat silhouette for the vista; one mesh, MultiMesh or 3 instances |

Brick colours are set per instance (MultiMesh `use_colors`, or per-instance shader parameter), so one brick mesh per type serves every colour.

### 7b. Shape cue per brick type (rule 36: colour is never the only cue)

| Type | Shape cue | Glow |
|---|---|---|
| Glass `G` | Plain smooth candy slab, only the shared rim tube | Rim tube emissive (energy 4-6), body self-emission 0.45 |
| Double `D` | Two raised white dots side by side; hit once = one dot left + a dark crack where the other was | As Glass, dots emissive 3 |
| Chrome `C` | Silver metal, static diagonal stripes, a bolt in each corner, **no rim tube** | None. Chrome is the only brick that never glows: "does not glow" = "does not break" |
| Carrier (lowercase) | 5-point star inlay on the face (centred; between the dots on a Double) | Star emissive 4 |
| Triple `T` (world 2) | Three dots in a triangle, one pops per hit | as Double |
| Nova `N` (world 3) | Four-point star on the face (different point count from the carrier star) | Star emissive 4 |
| Glider `M` (world 4) | Chevrons `< >` on both ends | Rim tube |
| Switch `S` (world 4, level 16) | Round button: ring with a dot (power symbol), slightly domed | Ring emissive |
| Ghost `A` / `B` (world 4, level 16) | A: dashed outline + square corner brackets. B: dashed outline + round corner dots. Dashes and marks sit on a dark keyline (section 12.2). Solid = filled body + outline, phased = outline only at 30% opacity | Outline only |
| Portal `1` / `2` (world 5, level 21) | Pair 1: a single spiral disc. Pair 2: spiral with a star centre | Spiral emissive, rotates 0.25 rev/s (static under "Mindre bevegelse") |

### 7c. Paddle, ball, net, capsule
- **Paddle:** dark gunmetal stadium shell with clear coat, a cyan neon loop around its face and two white end lamps. Cyan is reserved for the player's things, so the paddle is always the most saturated cool object on screen. Touch-down: strip energy +40% for 80 ms.
- **Ball:** unshaded white core (the brightest thing in the scene) + a camera-facing cyan halo quad (additive, radius 1.4x ball) + a short tapered cyan ribbon trail (12 points, 150 px long, additive, fades to 0). Komet: the trail turns sun-yellow and long (1.5 m), 8 yellow sparks orbit at r 0.38 m; one winks out per brick (under "Mindre bevegelse": sparks static).
- **Net:** a cyan tube (r 0.025 m, energy 4) across x 40-1040 at y 1540 with a faint diamond lattice (energy 1.2) below it. Charges (Vanlig): 3 white diamond pips centred on the line; a catch removes one with a single crack. 0 charges: the line becomes a dashed line and the lattice disappears. Count is shape (pips), not colour.
- **Capsule:** dark glass pill, cyan rim, white icon on the face (Komet: ball with a sun-yellow swept tail). Spins 0.5 rev/s around its long axis while falling.
- **Break shards:** 24 small triangles in the brick's colour, unshaded additive, 0.5 s life, flung toward the camera; a 0.2 s local glow puff (one additive quad) where the brick was.

### 7d. Bloom / glow budget (mobile renderer)

| Effect | How | Why |
|---|---|---|
| Neon glow on rims, tubes, ball, paddle | **Real glow**: WorldEnvironment `glow_enabled`, HDR threshold 1.0, intensity 0.8, strength 1.0, bloom 0.0, blend Additive, levels 2, 3 and 4 only (1, 5, 6, 7 off). Emission energy 3-8 on the tubes only | One post pass, cost is fixed per frame regardless of how many neon objects there are |
| Ball halo, capsule glow, glow puff on break | **Shader trick**: additive camera-facing quad with a baked radial gradient (128 px) | Readability must not depend on post glow: if glow is off (Compatibility fallback on the 32-bit tablet), the halo quads still give the neon read |
| Sun, sky, stars | **Shader trick**: one unshaded backdrop shader (gradient + slice mask + star hash) on one quad, no lighting | 1 draw call for the whole sky |
| Sea grid | **Shader trick**: unshaded shader, lines from `fract()` with `fwidth()` anti-aliasing, fades with distance; emission below the glow threshold | Grid must not bloom, or it competes with the field |
| Palms, ridges, skyline | Unshaded flat silhouettes (alpha scissor where needed, never alpha blend) | Cheap, no overdraw sorting |
| Field glass | One unshaded black quad at 72% alpha | The only large transparent surface; keep it single |
| Brick gloss | Standard PBR, roughness 0.18 + clear coat, reflections from the sky radiance (Sky with a 256 px radiance size) | Gives the candy highlight; no ReflectionProbe, no SSR |
| Tonemap | Linear, exposure 1.0 | Keeps neon saturation; emissive cores clip to white like the mock |

Off on mobile: SSAO, SSR, SSIL, SDFGI, volumetric fog, DOF, TAA. One DirectionalLight (key, cool white from above-front, **shadows off**: the field is a vertical glass plane and shadows would not be noticed at camera distance); ambient from the sky. Optional fake contact: a soft dark blob quad behind the ball on the field glass.

### 7e. Phone budgets (design ceilings; the PerfOverlay on the device decides)

| Item | Budget |
|---|---|
| Draw calls | <= 60 in play (bricks: one MultiMesh per type and state, about 6; vista 6-8; frame 4; paddle, ball, halo, trail, net 6; particles up to 6; UI 5) |
| Visible triangles | <= 80k. Measured GLBs: glass 700, chrome 380, double 1420, carrier 736, ball 960, paddle 1404, capsule 1064, palm 840 tris. A full 120-cell grid of doubles is 170k, so for MultiMesh use a 2-segment bevel copy (about 400 tris per brick, 48k worst case) and keep the 4-segment GLBs for the win-card thumbnail and store art |
| Particles | Pool 8 GPUParticles3D, max 6 alive, 24 shards each (144 max). Compatibility fallback: CPUParticles3D with 12 shards |
| Transparency | Field tint, ball halo, trail, glow puffs, ghost bricks only |
| Textures | <= 512 px each except the world vista atlas (1024 x 2048 max); ETC2/ASTC |
| Lights | 1 directional, no shadows; no omni lights (glow is emission) |
| Target | 60 fps on a mid-range phone; on the 32-bit tablet 60 fps with glow on, else glow off and halos carry the look |

### 7f. Four questions (premium 3D rule) for the features the owner asked for

| Feature | Noticed at camera distance? | Phone cost | Cheaper trick | Fits spec? | Verdict |
|---|---|---|---|---|---|
| Glossy PBR bricks | Yes: the specular streak on the top bevel is what makes them read as 3D | Low (MultiMesh, one material) | Matcap would do, but PBR with sky radiance is already cheap | Yes | Keep |
| Glow/bloom | Yes, it is the genre | One fixed post pass | Halo quads (also kept, as fallback) | Yes | Keep, 3 levels |
| GPU particles on break | Yes, it is the reward | Small (144 quads max) | None needed | Yes | Keep, pooled |
| Screen shake | Yes | Free | n/a | Only 2 events | Keep, off under Mindre bevegelse |
| Slow-mo last brick | Yes | Free | n/a | Yes | Keep |
| Moving camera | Yes, via parallax | Free | n/a | +-1.5 deg only | Keep |
| Real-time shadows | No (vertical glass field, glow lighting) | 1 shadow pass | Blob quad behind the ball | No | Cut |
| Reflections of the sun on the sea | Barely (under the tint) | SSR cost | Bake a soft orange streak into the sea shader | Yes | Shader streak only |

## 8. Do and don't

- Do: keep the ball the brightest white thing on screen and cyan only on the player's things (paddle, net, ball halo, capsule rim).
- Do: keep chrome non-glowing; the lack of glow is its "unbreakable" cue alongside stripes and bolts.
- Do: dim a vista element before it ever drops the ball below 4.5:1.
- Do: count things with shapes (dots, pips, sparks, feathers), never digits.
- Don't: put cyan on bricks in worlds 1-4, or any vista glow inside the field above the glow threshold.
- Don't: flash, strobe or flicker anything; respect the 3-per-second limiter.
- Don't: use text in gameplay, map or win card; don't draw anything in the 232 x 232 square except the home disc.
- Don't: use teal floors, wood, or anything from Krypton Egg's assets; don't use purple in the UI chrome (card, discs, settings).
- Don't: share this game's look with other MWM games; it is its own look.

## 9. Store assets (later; not part of the slice)

- **Icon (512x512):** a single glossy hotpink brick cracking open with the white ball bursting through, cyan halo, on the world 1 sky gradient with the sliced sun behind. Must read at 48 px: one brick, one ball, no text.
- **Feature graphic (1024x500):** the world 1 vista wide, a row of candy bricks shattering, the paddle bottom-left, the name in Audiowide on the dark sky band (not on the sun).
- **Screenshots (from game-qa's capture bot, never mock-ups):** level 3 with Komet ploughing through the wall; level 4 with chrome posts and a falling capsule (this mock's moment); the win card after level 5 (Palmesol sun picture).

## 10. Visual tier

**Premium stylized 3D.** The hero scene is world 1 level 4 as in `world1_mock.png`; the owner signs it off from the builder's real Godot screenshot (not this mock) before worlds 2-6 are built.

### Premium stylized 3D rules
Target: a polished commercial mobile game, stylized, never photoreal. No voxel/block look, no bare primitives, no default Godot lighting or default camera.
- **Hero scene first.** Before building levels, make one small scene look final: lighting, materials, camera, UI, particles. The owner signs it off from screenshots, then content copies its setup.
- **Geometry:** strong silhouettes, bevelled/rounded edges, a few good assets over many crude ones.
- **Materials:** varied roughness; flat colour only where the style asks for it (vista silhouettes). Textures at most 2048 px.
- **Lighting:** one directional key light (shadows off here, see 7d), fill from the sky ambient, emissive accents for the focal objects.
- **Camera:** fixed framed shot, eased movement only.
- **Color:** one palette per world from section 2c; the brightest, most saturated colour (cyan + white) marks what the player controls and watches.
- **Performance budget:** section 7e.

### Four questions before any visual feature
1. Will the player notice it at the real camera distance?
2. What does it cost on the phone GPU (draw calls, overdraw, shader cost)?
3. Can a cheaper trick (baked light, texture, vertex color, fake shadow) get the same look?
4. Does it fit this spec?


---

## 11. Worlds 2-6 (art direction, 2026-10-07)

Mocks: `docs/mockups/world2_mock.png` ... `world6_mock.png`, overview `worlds_overview.png`. Every world keeps the world 1 camera, frame, field glass, bricks, paddle, ball and net; only the vista, the floor, the wall tubes, the rail tint, the brick ramp and the win-card rim change. All numbers below come from `docs/mockups/src/nb_worlds.py` (the single source the mocks are rendered from); `nb_sky.py` is a numpy port of the sky shader and is the reference when the GLSL and this text disagree.

### 11.0 The rule that drives every palette: the glass luminance budget

The field glass multiplies everything behind it by 0.28 (linear light). I verified this against the QA screenshot: sun `#FFC93C` x 0.9 through the glass predicts (137, 107, 28), the capture shows (139, 103, 29). The white ball must stay at 4.5:1 or better against any vista area larger than the ball, so a large vista area may show at most relative luminance **0.178** after the glass (my calc). At that luminance a yellow or green is olive or ochre (the "muddy sun"), while red, pink, magenta, violet and blue stay vivid. So:

1. **Behind the glass, large shapes use red, pink, magenta, violet or blue** at displayed luminance 0.178 or lower.
2. **Thin details** (12 px or less in one direction: window dots, lamp heads, neon strips, beads, ridge lines) may reach displayed luminance 0.37 (2.5:1 against the ball); the ball covers them for 2-3 frames at most.
3. **Each world's warm or bright signature lives where there is no glass**: the sky band (y 0-280, minus the 232 x 232 home square), the bricks, the rails and tubes, and the floor strip below y 1700.
4. A motif that needs more light than 0.28 transmission gets a **glass window** (section 13.1) and HDR source colours, never a brighter field-wide glass.

Measured on the vista-only renders (gameplay hidden, my calc, WCAG 2.x, ball #FFFFFF, worst 44 x 44 px area inside the field y 280-1540 / worst single pixel):

| World | Worst area L | Ball ratio | Worst thin detail L | Ratio | Brightest thing |
|---|---|---|---|---|---|
| 1 | 0.183 | 4.51:1 | 0.365 | 2.5:1 | Sun lower slices at the window edge (at the limit; do not brighten) |
| 2 | 0.059 | 9.6:1 | 0.371 | 2.5:1 | Lit window dots |
| 3 | 0.134 | 5.7:1 | 0.341 | 2.7:1 | Cabinet marquee strips |
| 4 | 0.086 | 7.7:1 | 0.369 | 2.5:1 | Lamp heads |
| 5 | 0.161 | 5.0:1 | 0.267 | 3.3:1 | Crystal facets |
| 6 | 0.057 | 9.8:1 | 0.313 | 2.9:1 | Ring-gate beads |

If a level or the Godot capture shows a higher value, dim the emission of that vista element. Never brighten the ball.

### 11.1 One line per world

| # | World | At a glance | Signature where there is no glass | Behind the glass |
|---|---|---|---|---|
| 1 | Neonstranda | Pink-orange sunset | Stars in the sky band | Neon sliced sun (fixed, 13.1), grid sea, ridges, palms |
| 2 | Rutenettbyen | Electric-blue night city | Full moon with two cloud bands, upper middle (x 535-735, y 50-250; moved left of the gear 2026-10-07) | Low skyline, three depth layers with amber window dots, four vertical neon strips (pink/blue) |
| 3 | Arkadehallen | Gold arcade hall | Ceiling truss with a row of 14 gold bulbs (x 250-1080, y 150-215); gold checker floor lines | Square gold pixel stars, a CRT screen at the horizon with pixel hills and a pixel sun, cabinet rows on both sides |
| 4 | Nattveien | Red highway at night | Overpass deck crossing the band with 14 amber lamps (y 130-215) | Road to the horizon with amber lane dashes, red edge lines, red tail-light and warm head-light streaks, lamp posts, red mountain line |
| 5 | Krystallgrotta | Mint-and-violet cave | Rock ceiling with 10 short stalactites, mint tips | Faceted violet crystal heart at the horizon, crystal clusters, floor mist, violet lattice floor |
| 6 | Stjerneporten | Violet space gate with gold | Nebula and a gold-lit planet upper right (x 660-810, y 60-200; moved left of the gear 2026-10-07) | Ring gate (violet segments, 24 gold beads) around the field, gate light glow, nebula, gold grid bridge |

### 11.2 Sky gradient (sky.gdshader uniforms, `source_color`)

| World | sky_top | sky_mid | sky_low | horizon |
|---|---|---|---|---|
| 1 Neonstranda | `#0B0630` Color(0.043, 0.024, 0.188) | `#3A0E5C` Color(0.227, 0.055, 0.361) | `#C2186B` Color(0.761, 0.094, 0.420) | `#FF7A3D` Color(1.000, 0.478, 0.239) |
| 2 Rutenettbyen | `#040A22` Color(0.016, 0.039, 0.133) | `#0B1C48` Color(0.043, 0.110, 0.282) | `#1D3C7A` Color(0.114, 0.235, 0.478) | `#3A6FD0` Color(0.227, 0.435, 0.816) |
| 3 Arkadehallen | `#0E0818` Color(0.055, 0.031, 0.094) | `#1C0E2A` Color(0.110, 0.055, 0.165) | `#3A1838` Color(0.227, 0.094, 0.220) | `#C8501E` Color(0.784, 0.314, 0.118) |
| 4 Nattveien | `#05030C` Color(0.020, 0.012, 0.047) | `#160818` Color(0.086, 0.031, 0.094) | `#3E0C1C` Color(0.243, 0.047, 0.110) | `#C0283A` Color(0.753, 0.157, 0.227) |
| 5 Krystallgrotta | `#02060C` Color(0.008, 0.024, 0.047) | `#061624` Color(0.024, 0.086, 0.141) | `#0E2438` Color(0.055, 0.141, 0.220) | `#1E5A4E` Color(0.118, 0.353, 0.306) |
| 6 Stjerneporten | `#020108` Color(0.008, 0.004, 0.031) | `#120828` Color(0.071, 0.031, 0.157) | `#2A0C4A` Color(0.165, 0.047, 0.290) | `#5A1C8A` Color(0.353, 0.110, 0.541) |

### 11.3 Sky shader v2: motif, stars, ridges, nebula

New uniforms on `shaders/sky.gdshader` (all set per world from a `WORLD_LOOK` table in `NbWorld.gd` that replaces `WORLD_SKY`, `WORLD_SEA` and `WORLD_HORIZON`):

`int motif` (0 none, 1 sliced sun, 2 moon + cloud bands, 3 CRT screen, 5 hex crystal, 6 gate light) · `vec2 motif_c` · `float motif_r` (in t units: t = view direction xy / -z, as the current shader; screen x = 540 + 1350 t.x, screen y = 1310 - 1350 t.y) · `vec3 motif_top, motif_mid, motif_low, motif_rim : source_color` · `float motif_hdr` (2.222 when the motif has a glass window, else 1.0) · `vec3 star_col : source_color`, `float star_gain`, `float star_density` (hash threshold), `float star_square` (0 round, 1 square pixel stars: `max(abs(dx), abs(dy)) < 0.08` instead of the round distance) · `vec3 ridge_col`, `float ridge_gain` (0 = off), `float ridge_height`, `vec3 ridge_solid` · `sampler2D nebula_tex : hint_default_black, filter_linear, repeat_enable` (`assets/textures/nebula_512.png`, import with sRGB **off**: it is data), `vec3 neb_a, neb_b : source_color`, `float neb_gain` · `vec3 haze_col : source_color` (replaces `sun_low` in the haze line; = floor haze colour).

Motif colours are what the player sees **through the glass**; the shader outputs `colour x motif_hdr`, unclamped, and only the non-motif sky keeps `min(c, vec3(0.98))`:

`ALBEDO = mix(min(c, vec3(0.98)), motif_colour * motif_hdr, motif_cover);`

| World | motif | c (t) | r (t) | window | top | mid | low | rim |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 sliced sun | (0.0, 0.012) | 0.222 | on | `#D2402E` Color(0.824, 0.251, 0.180) | `#D4326C` Color(0.831, 0.196, 0.424) | `#A42CC4` Color(0.643, 0.173, 0.769) | `#F27088` Color(0.949, 0.439, 0.533) |
| 2 | 2 moon + cloud bands | (0.07, 0.86) | 0.075 | off | `#E4ECFF` Color(0.894, 0.925, 1.000) | `#B4C6FF` Color(0.706, 0.776, 1.000) | `#8FA6F0` Color(0.561, 0.651, 0.941) | `#FFFFFF` Color(1.000, 1.000, 1.000) |
| 3 | 3 CRT screen | (0.0, 0.1) | 0.075 | on | `#B4400E` Color(0.706, 0.251, 0.055) | `#8A1F66` Color(0.541, 0.122, 0.400) | `#12082A` Color(0.071, 0.031, 0.165) | `#B89A3A` Color(0.722, 0.604, 0.227) |
| 4 | 0 none | - | - | off | - | - | - | - |
| 5 | 5 hex crystal | (0.0, 0.1) | 0.13 | on | `#6A44E0` Color(0.416, 0.267, 0.878) | `#4A2CB0` Color(0.290, 0.173, 0.690) | `#2A1A80` Color(0.165, 0.102, 0.502) | `#20A060` Color(0.125, 0.627, 0.376) |
| 6 | 6 gate light | (0.0, 0.16) | 0.3 | off | `#8A5CFF` Color(0.541, 0.361, 1.000) | `#D63AF9` Color(0.839, 0.227, 0.976) | `#2A0C4A` Color(0.165, 0.047, 0.290) | `#FFD27A` Color(1.000, 0.824, 0.478) |

Motif shapes in `sp = (t - motif_c) / motif_r` (port of `nb_sky.py`; `aa = fwidth(t.x)`):
- **1 sliced sun** (world 1): the current disc, gradient low (sp.y -0.9) -> mid (0) -> top (0.8), slices `gap = clamp((0.35 - sp.y) / 1.35, 0, 1) * 0.6`, plus a rim: `motif_rim` where `r > 1 - 2.5 aa / motif_r` and `sp.y > 0.05`. Glow ring stays `mid * 0.18 * exp(-max(r - 1, 0) * 6)`.
- **2 moon** (world 2): disc, gradient low -> top along `sp.y - 0.3 sp.x` (-0.9 to 0.7), rim on the upper left (`sp.x < 0.2 && sp.y > -0.2`). Two cloud bands painted over it in `sky_mid x 1.2` at 80% cover: band 1 centre sp.y 0.05, half height 0.07, from sp.x -1.6 to 0.7; band 2 centre -0.42, half height 0.05, from -0.4 to 1.7; both with `smoothstep` soft ends 0.3 wide. Halo `low * 0.25 * exp(-max(r - 1, 0) * 2.5)`. Static: clouds do not move.
- **3 CRT screen** (world 3): rounded box screen half size (1.75, 1.0) corner 0.28, bezel to (1.95, 1.2) corner 0.36 in `#1A0C24`, 2 px `motif_rim` line on the bezel edge. Inside: `motif_low` with scanlines (x0.82 / x1.0 alternating, 18 per r unit), pixel hills (quantise sp to 0.1 cells; hill top `-0.17 + 0.22 sin(2.3 qx + 0.6) + 0.12 sin(5.7 qx)`) in `motif_mid`, pixel sun (quantised disc r 0.42 at (0.55, 0.25)) in `motif_top`. Static.
- **5 hex crystal** (world 5): pointy-top hexagon stretched 1.3x in y: `d = max(|x|, 0.5|x| + 0.866|y|) / 0.866` with y = sp.y / 1.3. Six sectors alternate `motif_top` / `motif_mid`, lower half shaded toward `motif_low`, inner hexagon (d < 0.45) in `motif_top`, facet lines (sector borders outside d 0.45, the d = 0.45 ring and the outline) in `motif_rim`, 1.6 aa wide. Static.
- **6 gate light** (world 6): no shape, adds `mid * 0.10 * exp(-1.6 r^2) + top * 0.12 * exp(-0.5 r^2)` behind the 3D ring gate.

| World | stars col | gain | square | density | ridge col / gain / height / solid | nebula a / b / gain |
|---|---|---|---|---|---|---|
| 1 | `#FFEBF2` Color(1.000, 0.922, 0.949) | 0.6 | 0 | 0.975 | `#FF2E88` Color(1.000, 0.180, 0.533) / 1.0 / 1.0 / `#120618` | off (gain 0) |
| 2 | `#DCE6FF` Color(0.863, 0.902, 1.000) | 0.35 | 0 | 0.985 | off (gain 0) | off (gain 0) |
| 3 | `#FFE14D` Color(1.000, 0.882, 0.302) | 0.9 | 1 | 0.982 | off (gain 0) | off (gain 0) |
| 4 | `#FFE6C8` Color(1.000, 0.902, 0.784) | 0.45 | 0 | 0.982 | `#FF3B30` Color(1.000, 0.231, 0.188) / 0.8 / 1.6 / `#0A0510` | off (gain 0) |
| 5 | `#9CFFC8` Color(0.612, 1.000, 0.784) | 0.25 | 0 | 0.99 | off (gain 0) | `#1B2A4A` / `#123A34` / 0.5 |
| 6 | `#FFF0F8` Color(1.000, 0.941, 0.973) | 0.8 | 0 | 0.965 | off (gain 0) | `#5A2CB0` / `#A0249C` / 0.55 |

Nebula (worlds 5-6): `vec2 n = texture(nebula_tex, t * 0.6 + vec2(0.37, 0.11)).rg; c += (neb_a * smoothstep(0.40, 0.80, n.r) + neb_b * smoothstep(0.50, 0.85, n.g)) * neb_gain * smoothstep(-0.02, 0.15, t.y);` world 5 also multiplies by `1 - smoothstep(0.05, 0.45, t.y)` so the mist hugs the floor. One texture fetch per sky pixel; no fbm in the shader.

Ridges: the current code with `ridge_height` multiplying `hill`, `ridge_solid` as the fill colour, and the wireframe term only in world 1 (`wire * 0.35` becomes `wire * 0.35 * wire_on`, wire_on = 1 for world 1 only). World 4 uses height 1.6 and no wire: a solid black mountain line with a red edge.

### 11.4 Floor (sea.gdshader v2)

New uniforms: `int mode` (0 grid, 1 checker, 2 road, 3 lattice), `vec3 base2` (checker), `vec3 dash_col, edge_col` (road). Lines keep the current anti-aliased `fract()` code; `period`, `width`, `gain`, `line_col`, `streak_col`, `haze_col`, `base` per world.

- **grid**: as now.
- **checker** (world 3): `base` and `base2` alternate on `floor(g.x) + floor(g.y)`, lines on top.
- **road** (world 4): inside `|x| < 7.0` m use `#06040A` and no grid; lane dashes at `|x| = 3.5` m (half width 0.12 m), 6 m period, 50% duty, `dash_col` x 0.9; edge lines at `|x| = 7.0` m (half width 0.15 m) `edge_col` x 0.8; both multiplied by the distance fade. Dashes scroll toward the camera at 6 m/s (`wp.z + TIME * 6.0`); under "Mindre bevegelse" they stand still.
- **lattice** (world 5): lines on `(x + z) / period` and `(x - z) / period` (diagonal diamonds).

| World | mode | base (base2) | line | period m | width | gain | streak | haze | road dash / edge |
|---|---|---|---|---|---|---|---|---|---|
| 1 | grid | `#07041A` | `#D63AF9` Color(0.839, 0.227, 0.976) | 3.0 | 0.035 | 0.85 | `#FF7A3D` | `#9E1F4C` | - |
| 2 | grid | `#040814` | `#3D7BFF` Color(0.239, 0.482, 1.000) | 2.0 | 0.03 | 0.8 | `#FFB547` | `#1D3C7A` | - |
| 3 | checker | `#0F0716` (`#22102E`) | `#FFC93C` Color(1.000, 0.788, 0.235) | 2.5 | 0.025 | 0.75 | `#FF3D6E` | `#3A1838` | - |
| 4 | road | `#0A0710` | `#5A1028` Color(0.353, 0.063, 0.157) | 4.0 | 0.03 | 0.6 | `#FF3B30` | `#3E0C1C` | `#FFB23D` / `#FF3B30` |
| 5 | lattice | `#03070C` | `#6A4CFF` Color(0.416, 0.298, 1.000) | 2.5 | 0.03 | 0.45 | `#4DFF9A` | `#1B2A4A` | - |
| 6 | grid | `#05030E` | `#FFD27A` Color(1.000, 0.824, 0.478) | 3.0 | 0.025 | 0.55 | `#8A5CFF` | `#2A0C4A` | - |

### 11.5 Frame, bricks, lights and win-card rim per world

| World | wall tube (albedo x2.2, unshaded) | rail albedo | win-card rim | brick ramp (top row first) | key light | fill (mock only) | ambient | ProceduralSky top / horizon |
|---|---|---|---|---|---|---|---|---|
| 1 | `#FF2E88` Color(1.000, 0.180, 0.533) | `#15122B` Color(0.082, 0.071, 0.169) | `#FF2E88` Color(1.000, 0.180, 0.533) | sun, tangerine, coral, hotpink, magenta | `#D9E6FF` Color(0.851, 0.902, 1.000) x1.1 | `#FF7359` | 0.7 | `#1A0D4D` / `#D94073` |
| 2 | `#3D7BFF` Color(0.239, 0.482, 1.000) | `#0C1430` Color(0.047, 0.078, 0.188) | `#3D7BFF` Color(0.239, 0.482, 1.000) | hotpink, coral, tangerine, sun | `#E0E8FF` Color(0.878, 0.910, 1.000) x1.1 | `#4D7BFF` | 0.6 | `#0B1C48` / `#3A6FD0` |
| 3 | `#FFC93C` Color(1.000, 0.788, 0.235) | `#1E1020` Color(0.118, 0.063, 0.125) | `#FFC93C` Color(1.000, 0.788, 0.235) | sun, coral, hotpink, violet | `#FFF0D9` Color(1.000, 0.941, 0.851) x1.15 | `#FF8A3D` | 0.6 | `#1C0E2A` / `#C8501E` |
| 4 | `#FF3B30` Color(1.000, 0.231, 0.188) | `#1A0A12` Color(0.102, 0.039, 0.071) | `#FF5A3C` Color(1.000, 0.353, 0.235) | coral, tangerine, sun, hotpink | `#FFE6D0` Color(1.000, 0.902, 0.816) x1.05 | `#FF3B30` | 0.55 | `#160818` / `#C0283A` |
| 5 | `#4DFF9A` Color(0.302, 1.000, 0.604) | `#0A1A20` Color(0.039, 0.102, 0.125) | `#3DDC8A` Color(0.239, 0.863, 0.541) | mint, violet, magenta, hotpink | `#D9FFF0` Color(0.851, 1.000, 0.941) x1.05 | `#8A5CFF` | 0.6 | `#061624` / `#1E5A4E` |
| 6 | `#8A5CFF` Color(0.541, 0.361, 1.000) | `#120A24` Color(0.071, 0.039, 0.141) | `#FFD27A` Color(1.000, 0.824, 0.478) | violet, magenta, hotpink, sun | `#F0E6FF` Color(0.941, 0.902, 1.000) x1.1 | `#D63AF9` | 0.6 | `#120828` / `#5A1C8A` |

Tube colour stays the base of `_sync_tubes` (Neonrush still lerps toward `WHITE_HOT`). Cyan stays on the player's things only; no world uses cyan for tubes, bricks or vista (world 2's blue is `#3D7BFF`, hue 222 deg, against cyan's 188 deg). Win-card rim contrast against the dimmed scene (my calc): pink 5.5:1, blue 5.1:1, gold 12.6:1, red-orange 6.3:1, mint 10.9:1, gold 13.6:1. The card rim is UI chrome, so world 6 uses gold, never violet.

### 11.6 Props and placements (Godot coordinates: x right, y up, z toward the camera, play plane z 0)

All props are unshaded or lit opaque meshes, shadows off, no alpha blend. Every list below is one `MultiMeshInstance3D` per mesh (one draw call each). GLBs are in `assets/models/` (sizes and triangle counts in 12.8).

**World 2 Rutenettbyen**
- Skyline `CitySkyline_L0/L1/L2`: `prop_city_tower.glb` instances (14 x 8 x 53.6 m reference, scale x and y per instance), three layers at z -110, -180, -280; from x -150 to +150, width 9-20 m, gap 1-6 m, height ranges 8-30 / 18-50 / 30-78 m multiplied by `0.6 + 0.4 min(1, |x| / 50)` (lower in the middle so the ball zone stays dark). Seed the RNG with 2 so it is the same every run. Body colours `#0C1638`, `#0A1230`, `#081028`.
- Window shader `shaders/windows.gdshader` (new, unshaded): cell 1.6 m wide x 2.0 m tall in object space, window = middle 50% x 40% of the cell, lit when `hash(cell) < density` (0.30 / 0.25 / 0.20 per layer); lit colour `#C08028` x 1.5 (unshaded albedo, may exceed 1). Static: no flicker.
- Neon strips `CitySigns`: 4 vertical unshaded tubes r 0.45 m on the front layer at (x, y bottom, height): (-38, 9, 9) `#FF2E88`, (-12, 14, 7) `#3D7BFF`, (21, 11, 10) `#FF2E88`, (44, 16, 8) `#3D7BFF`, z -105.5, albedo x 2.4. **Never a ring, arrow or chevron**: those are portal and glider cues.
- Moon: in the sky shader (motif 2). No 3D object.

**World 3 Arkadehallen**
- `ArcadeCabinets`: `prop_arcade_cabinet.glb` x 14, scale 2.8, rows at x = +-(7.0 + 0.9 k), z = -10 - 8 k, k 0-6, each turned to face the centre line 55 deg (y rotation = -55 deg on the right, +55 deg on the left). Marquee `#FFE14D` x 1.4, screens alternate `#FF3D6E` / `#3D7BFF` x 1.4. Body `#0B0612`, roughness 0.6.
- `CeilingTruss`: box 30 x 1.0 x 0.8 m at (5.0, 42.6, -30.0), `#1A1020`, metallic 0.6, roughness 0.5. `TrussBulbs`: 14 spheres r 0.38 m at x = -8.6 + 2.1 k, y 41.7, z -29.4, unshaded `#FFE14D` x 3.0. The bulbs breathe 0.5 Hz between 75% and 100% on alternate bulbs (a sine, never on/off; static under "Mindre bevegelse").

**World 4 Nattveien**
- `LampPosts`: `prop_lamp_post.glb` (pole 9 m, arm reaching 2.4 m toward the road), x = +-9.0, z = -20 - 24 k, k 0-15 (32 instances, the right side turned 180 deg). Head `#FFB23D` x 1.6 unshaded. `LampPools`: additive quads 8 x 12 m flat on the road under the first 8 per side, `#FFB23D` at 18%, radial gradient texture (the existing `_halo_tex`).
- `LightStreaks`: 4 unshaded quads 0.12 m wide from z -14 to -434 at y 0.6: x 3.1 and 3.9 `#FF3B30` x 1.6 (tail lights), x -3.1 and -3.9 `#FFE6C8` x 1.6 (head lights). A UV-scrolled dash mask (period 18 m, 70% duty, 20 m/s away from the camera on the right, toward it on the left) makes them "pass"; static under "Mindre bevegelse".
- `Overpass`: box 120 x 3 x 6 m at (0, 55, -45), `#0E0812`, roughness 0.7; `OverpassLamps`: 14 boxes 1.2 x 0.35 x 0.4 m at x = -19.5 + 3 k, y 53.3, z -41.9, unshaded `#FFB23D` x 3.0 (outside the glass, so allowed bright).

**World 5 Krystallgrotta**
- `CrystalClusters`: `prop_crystal_cluster.glb` (3.7 m tall reference) at (x, z, scale): (-12, -16, 0.9) violet, (12.5, -20, 1.0) mint, (-30, -60, 3.3) mint, (34, -70, 3.5) violet, (-70, -150, 6.0) violet, (80, -160, 6.5) mint. Violet material: albedo `#2A1A80`, emission `#4A2CB0` energy 0.9, roughness 0.1, clearcoat 1.0. Mint material: albedo `#0E3A2C`, emission `#1E7A52` energy 0.9, roughness 0.1, clearcoat 1.0. Keep tops below screen y 980 (t.y 0.24).
- `CaveCeiling`: box 90 x 10 x 4 m at (0, 50, -30), albedo `#07101A`, emission `#0B2A26` energy 0.8. `Stalactites`: `prop_stalactite.glb` x 10 at x = -7 + 3 k (+-0.5 jitter), base at y 45.2, z -29, height 1.6-3.0 m (scale y), tips unshaded `#4DFF9A` x 3.0. Tips must stay above screen y 240 and outside the home square.
- `MistCards`: 2 quads 160 x 3.5 m at (0, 1.5, -35) and (0, 3.0, -70), `#1B2A4A` additive at 30%.

**World 6 Stjerneporten**
- `RingGate`: `prop_ring_gate.glb` (R 40 m, 24 segments, 24 beads), facing the camera, at (0, 27.6, -120): its inner opening frames the field (t radius about 0.30). Segments albedo `#2A1A5A`, metallic 0.7, roughness 0.25, emission `#5A2CB0` energy 0.9; beads unshaded `#FFD27A` x 1.6. It rotates 0.02 rev/min around z (barely visible, parallax only; static under "Mindre bevegelse"). The lower part passes through the floor plane; that is intended.
- `Planet`: sphere r 23 m at (60, 367, -400) (was 104: the stand-alone gear at x 870-1040 covered it, QA 2026-10-07), albedo `#3A1C6A`, emission `#120828` 0.5, plus a gold terminator: a second sphere r 23.2 m offset (-5, +3, -6) unshaded `#FFD27A` x 1.6 drawn behind it (reads as a lit crescent). Outside the home square.
- Nebula and gate light: sky shader.

### 11.7 Four questions (worlds 2-6 vista features)

| Feature | Noticed at camera distance? | Phone cost | Cheaper trick used | Fits spec? |
|---|---|---|---|---|
| Sky motif per world | Yes, it is the world's face | 0 extra draws (same sky quad, a few ALU ops) | Shader, not geometry | Yes |
| Glass window behind the motif | Yes (fixes the muddy sun) | 0 extra draws, a few ALU on the glass quad | Instead of brighter glass | Yes |
| City skyline + windows | Yes | 3 draws, about 6k tris, 1 hash per pixel | Window grid in shader, no texture | Yes |
| Arcade cabinets, lamp posts, crystals, stalactites | Yes as silhouettes | 1 draw per MultiMesh, under 10k tris each | MultiMesh | Yes |
| Ring gate | Yes, frames the field | 1 draw, 2.4k tris | Beads are geometry, glow from shader | Yes |
| Nebula | Yes, sky band | 1 texture fetch per sky pixel | Baked 512 px texture instead of fbm | Yes |
| Moving light streaks / road dashes | Yes, sells "highway" | UV scroll only | No geometry motion | Yes, off under Mindre bevegelse |
| Real lights on lamp posts | No (glass dims them) | 1 omni each | Emissive heads + additive pools | Cut |

Budget per world stays within 7e: vista 6-9 draw calls, worst world 4 about 34k vista triangles (32 lamp posts x 324 + road + mountains).

---

## 12. New elements in worlds 2-6 (look specs)

Sheet: `docs/mockups/elements_w26.png`. Every element has a **shape** cue; colour is decoration (rule 36). Flash rule unchanged: at most 3 glow spikes per second through `NbFlashLimiter`, no full-screen flash, no on/off blinking.

### 12.1 Bryter / Switch `S` (`brick_switch.glb`, 1828 tris)
- Body: dark steel `#3A4052` Color(0.227, 0.251, 0.322), metallic 0.8, roughness 0.30, **no rim tube** (like chrome: no glow on the body means "does not break"), no stripes and no bolts (that is chrome's cue).
- Button: domed disc r 0.15 m `#1A1C26`, clearcoat 1.0, with a polished bezel ring r 0.165 m (`#C9CED8`, metallic 1.0, roughness 0.2) and the power symbol (open ring r 0.085 m + bar) in `#FFF4D6` Color(1.000, 0.957, 0.839), emission energy 3.5. Ring vs body 9.4:1 (my calc).
- Set marks: a square (0.09 m) at x -0.33 = set A, a round dot (r 0.05 m) at x +0.33 = set B. The mark of the set that is **solid now** is lit (`#FFF4D6`, energy 3.5), the other is dark `#4A4F60` (no emission). So the switch tells the child which shape is solid, by shape.
- Hit: button presses in 0.03 m over 60 ms and back over 120 ms; the power symbol energy 3.5 -> 7 -> 3.5 over 200 ms, through the limiter (it is one spike). The marks swap at the same moment. Under "Mindre bevegelse": no press motion, marks swap.

### 12.2 Skygge / Ghost `A` / `B` (`brick_ghost_a.glb`, `brick_ghost_b.glb`)
- Solid: the normal candy brick body in the row colour (brick shader, as glass) **without** the rim tube, plus a dashed outline: 12 dashes, 45% duty, tube r 0.011 m, `#FFF4D6` emission 3.0, sitting on a dark keyline `#1A0614` (r 0.020 m, 47% duty) so the dashes read 3:1 or better on any candy fill (white dash on coral alone is 2.8:1, my calc; with the keyline the mark is dark-on-candy at 5:1 or better).
- Set A corner marks: L-brackets 0.13 x 0.11 m, tube r 0.028 m, keyline r 0.040 m. Set B corner marks: round dots r 0.05 m, keyline dots r 0.065 m.
- Phased: body hidden; a faint haze body at 8% alpha in the row colour, outline and marks in `#FFF4D6` at **30% alpha**, no keyline, no emission spike. The ball passes through.
- Render: ghosts are their own two MultiMeshes `GhostsA` and `GhostsB` with one ShaderMaterial (uniform `phase` 0 solid -> 1 phased; alpha mix, depth write on only when solid). Switch toggle: 0.25 s ease-in-out cross-fade, both sets at once (one set goes 0 -> 1 while the other goes 1 -> 0). Not a flash. Under "Mindre bevegelse": instant.

### 12.3 Ormehull / Portal pairs `1` / `2` (`portal_1.glb`, `portal_2.glb`)
- Size: ring r 0.40 m (exactly the 40 px logic radius), tube r 0.03 m, so what the child sees is the trigger area.
- Hole: disc `#05020C` Color(0.020, 0.008, 0.047), clearcoat 1.0, so it reads as a hole.
- Pair 1: ring and one spiral arm (2.6 turns from r 0.05 to 0.35 m) in `#9CFFC8` Color(0.612, 1.000, 0.784); ring emission 4.0, arm 2.5.
- Pair 2: ring and **two** spiral arms (from r 0.15 to 0.35 m) plus a 5-point star r 0.14 m in the centre, all `#FFD27A` Color(1.000, 0.824, 0.478); ring 4.0, arms 2.5, star 4.0. Shape difference: one arm vs two arms + star. Ring vs hole 17.2:1 and 14.5:1 (my calc).
- Motion: spiral arms rotate 0.25 rev/s (ring and star still); static under "Mindre bevegelse".
- Teleport: both portals of the pair scale 1.0 -> 1.15 -> 1.0 over 150 ms (no emission spike); the ball's trail is cut at the entry and restarts at the exit (no streak drawn across the field).

### 12.4 Saktetid (tape slow) capsule and state (`capsule_saktetid.glb`)
- Capsule: the shared capsule (dark glass, cyan rim) with a white cassette icon: rounded window 0.62 x 0.30 m outline, two reels r 0.075 m with three spokes each, a tape line under them.
- While falling: the reels spin 1 rev/s (the capsule body spins as all capsules do); static under "Mindre bevegelse".
- Active state on the ball: the cyan ribbon trail is replaced by a **dotted trail** of 8 dots, every 24 px along the path, radius shrinking from 7.5 to 0.75 px (mesh: 8 small quads, additive, `#FFE6C8` Color(1.000, 0.902, 0.784) at 80%). Dots read "slow motion" without any count or text. Ending: over the 0.5 s wind-up the dots fade and the ribbon fades back in.
- No colour grade, no screen tint (a field-wide change would be a large glow change and costs a pass).

### 12.5 Skjoldnett (shield net) capsule (`capsule_skjoldnett.glb`)
- Icon: a net line with a zigzag under it and a plus sign above, white.
- Catch (Vanlig): a new white diamond pip drops from the paddle to its place on the net over 0.25 s ease-out and lands with a small ring (radius 0 -> 40 px, alpha 0.6 -> 0, 200 ms, additive cyan). At 3 pips (max) the capsule still plays the drop, onto the existing third pip. Lett: carriers drop Bredvinge instead (GDD 5.2), so no Skjoldnett look is needed there.

(Bredvinge `capsule_bredvinge.glb` and Neonpuls `capsule_neonpuls.glb` icons are exported too, replacing the slice placeholders: winged paddle; paddle with three arcs.)

### 12.6 Bosses (3 x 2 cells, hit box 2.92 x 0.96 m)

Shared core (all bosses, all worlds, replaces the placeholder): dark glass disc r 0.30 m `#140F2E` (clearcoat 1.0), core ring r 0.24 m tube 0.035 m `#FFF4D6` emission 4.0, and **health notches built in code**: N = max HP boxes 0.032 x 0.075 x 0.03 m on a circle r 0.355 m around the core centre, starting at 12 o'clock, clockwise, each rotated to point outward. Alive: unshaded boss accent colour x 4.0; dark: `#2A2238`, no emission. One notch goes dark per point of damage (GDD 15.5). With 36 notches they are 6 cm apart at 2.92 m; still separable at 1080 px (6 px gaps). The GLBs contain the body, disc and ring only.

| Boss | GLB (tris) | Silhouette | Materials | Accent (notches) | Core centre in the box |
|---|---|---|---|---|---|
| L20 Lastebilen | `boss_lastebilen.glb` (2980) | A lorry seen from the side: trailer box (1.95 x 0.74 m) left, chrome cab with a slanted dark window right, 4 wheels with chrome hubs, 6 amber marker lamps along the trailer top, 4 white ribs. No face (side view, no headlights). | Trailer `#FF3B30` roughness 0.18, clearcoat 1, emission `#FF3B30` 0.35; cab `#C9CED8` metallic 1, roughness 0.22; window `#140F2E`; tyres `#0C0A12`; lamps `#FFB23D` x 5 | `#FFB23D` amber | (-0.46, +0.06) m: on the trailer side |
| L25 Krystallhjertet | `boss_krystallhjertet.glb` (1416) | An elongated six-sided gem (2.8 x 0.84 m) with mint facet lines and two mint spikes at the upper corners; the core sits inside the gem | Gem `#8A5CFF` roughness 0.08, clearcoat 1, emission `#8A5CFF` 0.7; edges `#4DFF9A` x 5 | `#4DFF9A` mint | (0, 0) |
| L30 Neonnova | `boss_neonnova.glb` (1424) | A cut-corner octagon casing (never a stadium pill: that shape belongs to capsules) with a gold rim tube, a magenta 4-point glow star and a pale-gold 4-point spike star behind the core (the Nova brick's shape, so the child links it to the Nova ring around it) | Casing `#140A2A` metallic 0.4, roughness 0.12, clearcoat 1; rim `#FFD27A` x 5; glow `#D63AF9` x 2; spikes `#FFE7A0` x 5 | `#D63AF9` magenta | (0, 0) |

Neonnova's spike tips overhang the hit box by 4 cm top and bottom; visual only, the hit box stays 292 x 96 px.

Boss events (through the limiter): hit = squash 95% 80 ms + one notch goes dark + a spark at the contact point; phase roar = core ring energy 4 -> 8 -> 4 over 0.6 s (one spike); defeat = core ring scales to 0 over 0.4 s (implode) + 3 shard bursts 0.15 s apart in the accent colour. Krystallhjertet's portal jump (GDD 15.9): scale 1 -> 0 over 0.25 s with a 180 deg z spin at the old spot, 0 -> 1 over 0.25 s with the reverse spin at the new spot; under "Mindre bevegelse" a 0.2 s alpha cross-fade instead.

### 12.7 Bricks shown for the first time in mocks
Triple (`brick_triple.glb`, three dots in a triangle, 1372 tris), Glider (`brick_glider.glb`, chevrons, 780), Nova (`brick_nova.glb`, 4-point star r 0.15 m emission 4, 728). They match section 7b; use them for the win-card thumbnails and the 2-segment MultiMesh copies (7e).

### 12.7b Magnet `O` (builder's look, 2026-10-07; graphic-designer to confirm)
Not specified above, so built in `shaders/brick.gdshader` (kind 8) as a shape cue: the candy brick in the row colour with the shared rim tube, a white ring (r 0.075 m) in the middle and four white chevrons pointing inward at it (left, right, top, bottom). The first hit removes the right and top chevrons and adds a dark crack. Six faint spokes in a pale tint of the row colour turn at 0.25 rev/s around the ring (static under "Mindre bevegelse"); while a ball is inside the 170 px pull radius they brighten a little (steady, no flash). The world-6 accent comes from the row ramp (violet, magenta, hotpink, sun). Carriers move the star to the right end (x 0.30 m), as on Triple and Nova.

### 12.8 GLB list added 2026-10-07 (metres, Y-up, front +Z, origin centre)

| File | Size x / depth / y (m) | Tris | Material names (stable, look them up by name) |
|---|---|---|---|
| brick_switch | 0.92 / 0.38 / 0.44 | 1828 | switch_body, switch_btn, switch_bezel, switch_ring, switch_mark_off |
| brick_ghost_a / _b | 0.92 / 0.34 / 0.44 | 2540 / 3180 (solid look; phased is the same mesh with the ghost shader) | brick_*, ghost_line_100, ghost_key |
| portal_1 / portal_2 | 0.86 / 0.08 / 0.86 | 1896 / 2712 | portal_hole, portal_ring1/2, portal_arm1/2, portal_star |
| capsule_saktetid / skjoldnett / bredvinge / neonpuls | 1.12 / 0.32 / 0.56 | 1350-2300 | capsule_body, capsule_rim, capsule_icon |
| boss_lastebilen / krystallhjertet / neonnova | 2.92 / 0.49-0.53 / 0.89-1.04 | 2980 / 1416 / 1424 | see 12.6 |
| paddle_vanlig_280 / paddle_lett_400 (v2, replace v1) | 2.80 or 4.00 / 0.41 / 0.36 | 1840 | paddle_body, paddle_plate, **paddle_light** (unchanged name), paddle_cap |
| prop_city_tower | 14 / 8 / 53.6 | 176 | tower_body |
| prop_arcade_cabinet | 0.82 / 1.02 / 2.0 | 308 | cab_body, cab_marquee, cab_screen |
| prop_lamp_post | 2.68 / 0.35 / 9.0 | 324 | pole, lamp_head |
| prop_crystal_cluster | 3.7 / 2.2 / 3.9 | 154 | crystal_vio |
| prop_stalactite | 1.46 / 1.43 / 2.56 | 92 | rock, stal_tip |
| prop_ring_gate | 86.4 / 4.5 / 86.4 | 2400 | gate_body, gate_bead |

The v1 paddle GLBs stay available in git history.

---

## 13. QA look fixes (QA_SLICE_2026-10-06 section 5)

All four were prototyped in a scratch copy of the game (not in this repo) and captured with the real Godot Mobile renderer on 2026-10-07; the numbers below are the ones that produced the good capture.

### 13.1 Sun reads muddy ochre -> neon (0 extra draw calls)

Cause: sun `#FFC93C` x `sun_gain` 0.9 through 72% black glass = (137, 107, 28) linear-correct (QA saw (139, 103, 29)). Yellow at that brightness is ochre, and it cannot get brighter without breaking the ball's 4.5:1 (11.0).

Fix, three parts:
1. **New sun colours** (what the player sees through the window): `sun_top #D2402E` Color(0.824, 0.251, 0.180), `sun_mid #D4326C` Color(0.831, 0.196, 0.424), `sun_low #A42CC4` Color(0.643, 0.173, 0.769), `sun_rim #F27088` Color(0.949, 0.439, 0.533) (2.5 px rim on the upper half). Remove `sun_gain`. Add `uniform float sun_hdr = 2.222;` (= 1 / (1 - 0.55)). The haze line uses a new `haze_col` (world 1 `#FF2E88`) instead of `sun_low`.
2. **Unclamped sun**: `ALBEDO = mix(min(c, vec3(0.98)), sc * sun_hdr, sun);` where `sc` already includes the rim. The highest source value is about 1.5, inside the Mobile renderer's 0-2 HDR range.
3. **Glass window**: replace the field `StandardMaterial3D` with `shaders/field_glass.gdshader` (unshaded, `blend_mix`, `depth_draw_never`, `cull_disabled`): `base_alpha 0.72`, `window_alpha 0.55`, window centre/radius = the motif's `motif_c`/`motif_r`, computed from the view direction exactly like the sky (`t = d.xy / max(-d.z, 0.05)`) so it follows the sun under camera drift. `win = (1 - smoothstep(1.03, 1.30, rr)) * smoothstep(0.0, 0.04, t.y)`; `ALPHA = mix(base_alpha, window_alpha, win)`; world 3 uses a box distance `max(|sp.x| / 1.95, |sp.y| / 1.2)`; worlds 2, 4 and 6 set `window_on = 0`.

Result in Godot (my calc on the capture): sun centre (210, 64, 61), previously (139, 103, 29). Ball vs sun 4.6:1. Mock: `world1_fix_mock.png`.

### 13.2 Paddle reads as a thin outline -> lit body (0 extra draw calls)

Use the re-exported `paddle_vanlig_280.glb` / `paddle_lett_400.glb` (already in `assets/models/`; `_set_paddle()` finds `paddle_light` as before). Material values (glTF carries them; if the importer drops clearcoat, set it on `paddle_body` / `paddle_plate` in code):
- `paddle_body`: albedo `#4A5578` Color(0.290, 0.333, 0.471), metallic 0.35, roughness 0.32, clearcoat 1.0 (clearcoat roughness 0.05), emission `#263052` Color(0.149, 0.188, 0.322) energy 1.0.
- `paddle_plate` (new inset face panel inside the light loop, 0.02 m proud): albedo `#6A7AA6` Color(0.416, 0.478, 0.651), metallic 0.3, roughness 0.28, clearcoat 1.0, emission `#2E3C66` Color(0.180, 0.235, 0.400) energy 1.0.
- `paddle_light` unchanged (cyan, energy 7; touch +40%), `paddle_cap` unchanged.
In Godot the face now reads as a solid blue-steel bar inside the cyan loop. The cyan strip stays the brightest cool thing on screen. I tried an additive under-glow quad and cut it: it read as a second, larger pill.

### 13.3 Win card is a flat cream slab -> neon rim (0 extra draw calls, still `_draw()`)

In `NbWinCard._draw()`, replace the dark offset shadow and the 4 px edge with three `StyleBoxFlat`s (all `anti_aliasing = true`):
1. Card: `bg_color CARD`, corner radius 56, `border_color = rim`, border width 6, `shadow_color = Color(rim, 0.55)`, `shadow_size = 28`, `shadow_offset = Vector2.ZERO`, drawn on `CARD_RECT`. The soft shadow is the glow.
2. Hot core line: `draw_center = false`, corner radius 54, border 2 px `Color(1.0, 0.92, 0.95)`, on `CARD_RECT.grow(-2)`.
3. Inner keyline: `draw_center = false`, corner radius 50, border 3 px `CARD_EDGE`, on `CARD_RECT.grow(-6)` (keeps the card edge readable for ink-on-cream).
`rim` = the world's card-rim colour (11.5), passed in through `show_card(..., world_id)`. Remove the `SHADOW` offset slab. The 250 ms fade-in is unchanged. Fill and icons unchanged (light card, ink icons, no purple).

### 13.4 Seam at the frame top (x 0-30, y 235-265)

Cause: the top rail was exactly 10.8 m (screen width) with rounded end caps at the screen edge, and the side rails overlapped it with their own rounded tops.
In `NbWorld._build_frame()`:
- Top rail mesh `Vector3(12.4, 0.4, 0.4)` (0.8 m past each edge, covers the +-1.5 deg drift).
- Side rails stop under it: height `z_top - z_bot`, position y `(z_top + z_bot) * 0.5` (no +0.4 / +0.2).
- Rail material: metallic 0.4, roughness 0.6 (was 0.6 / 0.45) and albedo = the world's rail colour (11.5).
Captured result: the rail runs as one band to the screen edge; the grey corner block is gone.

The plain sky above the field (QA 5, second half) is answered by the sky-band signatures in 11.1: moon, bulb truss, overpass, stalactites, planet. World 1 keeps its stars (owner-approved hero scene).

### 13.5 Build order for these fixes (one session)
1. 13.1 sun + `field_glass.gdshader` (world 1 only first). 2. 13.2 paddle (GLBs already swapped). 3. 13.4 rails. 4. 13.3 card rim. 5. Recapture `01`, `02`, `04` and compare to `world1_fix_mock.png`; the sun centre pixel should read about (210, 64, 61).
