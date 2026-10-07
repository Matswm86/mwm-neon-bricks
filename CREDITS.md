# Credits and licences: MWM Neon Bricks

## Art
| Asset | Source | Licence |
|---|---|---|
| All 3D models in `assets/models/` (bricks, paddles, ball, Komet capsule, palm silhouette) | Made for this game in Blender 4.5 from the scripts in `docs/mockups/src/` | Own work, same licence as this repository |
| Worlds 2-6 models in `assets/models/` (`brick_triple`, `brick_glider`, `brick_nova`, `brick_switch`, `brick_ghost_a`, `brick_ghost_b`, `portal_1`, `portal_2`, `capsule_saktetid`, `capsule_skjoldnett`, `capsule_bredvinge`, `capsule_neonpuls`, `boss_lastebilen`, `boss_krystallhjertet`, `boss_neonnova`, `prop_city_tower`, `prop_arcade_cabinet`, `prop_lamp_post`, `prop_crystal_cluster`, `prop_stalactite`, `prop_ring_gate`) and the v2 paddles (2026-10-07) | Made for this game in Blender 4.5 from `docs/mockups/src/nb_parts_w26.py` and `elements_w26.py` | Own work, same licence as this repository |
| `assets/textures/nebula_512.png` (worlds 5-6 mist and nebula, R/G noise data) | Generated with numpy by `docs/mockups/src/nb_sky.py` (`nebula_texture()`) | Own work |
| Mock renders in `docs/mockups/` | Rendered in Blender 4.5 (EEVEE) from the same scripts; win-card and home-disc overlays drawn with Python Pillow | Own work |

No third-party textures, HDRIs or models are used (checked 2026-10-07, worlds 2-6 included). Planned free sources, to be listed here with the exact file when added: Poly Haven (CC0), ambientCG (CC0), Kenney (CC0).

## Sound
| Asset | Source | Licence |
|---|---|---|
| Sound effects in `assets/sfx/` | Own synthesis (`tools/render_sfx.py`), layered with samples from Kenney Impact Sounds (https://kenney.nl/assets/impact-sounds): `impactGlass_light_000-002`, `impactGlass_medium_000-002`, `impactMetal_light_000-001` | Own work; Kenney samples CC0 |
| Background music `assets/music/neon_bricks_theme.ogg` | Supplied by the game owner | Used with the owner's permission |

## Fonts
| Font | Use | Licence |
|---|---|---|
| Fredoka | Stand-alone settings and credits (adult text only); labels on the dev sheet `docs/mockups/elements.png` | SIL Open Font License 1.1 (bundle `Fredoka-OFL.txt` next to the font file) |
| Audiowide (planned) | Logo and store art only | SIL Open Font License 1.1 (add the licence file with the font) |

## Code ideas
Paddle and ball physics ideas come from our own Krypton Egg remake code. No Krypton Egg art, levels, names or assets are used.
