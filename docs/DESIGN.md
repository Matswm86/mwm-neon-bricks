# MWM Neon Bricks: visual design spec

Owner: graphic-designer. Version 1, 2026-10-05. The builder reads this before touching any colour, material, light, camera or UI node. Every token carries its rule and its reason. Game rules and numbers live in `docs/GDD.md`; child rules (rule N) are in `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. Numbers tagged (my calc) are my own arithmetic on rendered pixels, WCAG 2.x formula.

Mockups (all rebuilt by the scripts in `docs/mockups/src/`):

| File | What it shows |
|---|---|
| `docs/mockups/world1_mock.png` | World 1 Neonstranda, level 4 "Krompilarer" mid-play, 1080x1920, stand-alone home disc |
| `docs/mockups/world1_zones.png` | Same frame with zones: home square (white), drag zone (green), wrist strip (red), playfield (yellow line) |
| `docs/mockups/wincard_mock.png` | Win card over the dimmed scene |
| `docs/mockups/elements.png` | Brick colours, the slice brick types, both paddles, ball, Komet ball, capsule, three net states |
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
| mint | #3DFFB0 | Color(0.239, 1.000, 0.690) | Ramp colour in world 5 only |

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
| Switch `S` (world 5) | Round button: ring with a dot (power symbol), slightly domed | Ring emissive |
| Ghost `A` / `B` (world 5) | A: dashed outline + square corner marks. B: dashed outline + round corner dots. Solid = filled body + outline, phased = outline only at 30% opacity | Outline only |
| Portal `1` / `2` (world 6) | Pair 1: a single spiral disc. Pair 2: spiral with a star centre | Spiral emissive, rotates 0.25 rev/s (static under "Mindre bevegelse") |

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
