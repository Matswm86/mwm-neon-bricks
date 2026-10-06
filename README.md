# MWM Neon Bricks

**[⬇ Download the APK (Android, 161 MB)](https://github.com/Matswm86/mwm-neon-bricks/releases/download/latest/mwm-neon-bricks.apk)**

<p align="center"><img src="docs/screenshots/02_level4_midplay.jpg" alt="Gameplay: the ball breaks glowing bricks over a synthwave sunset beach" width="360"></p>

A neon synthwave brick breaker for Android, made for children (ages 4-7 on "Lett", 8+ on "Vanlig"). Steer a glowing paddle with one thumb and bounce a ball through bright 3D bricks on a sunset beach. A safety net under the paddle means a small child never loses. No ads, no tracking, works offline, no Android permissions.

This is the **vertical slice**: world 1 "Neonstranda" with 5 levels, Glass, Double and Chrome bricks, the Komet power-up, the win card, the level map and the Lett/Vanlig setting. Design: `docs/GDD.md` (rules and numbers) and `docs/DESIGN.md` (look).

| Level 1 start | Level 4 mid-play | Win card |
|---|---|---|
| ![](docs/screenshots/01_level1_start.jpg) | ![](docs/screenshots/02_level4_midplay.jpg) | ![](docs/screenshots/04_level1_wincard.jpg) |

## Install on a phone or tablet

1. On the device, tap [mwm-neon-bricks.apk](https://github.com/Matswm86/mwm-neon-bricks/releases/download/latest/mwm-neon-bricks.apk) (or open the [latest release](https://github.com/Matswm86/mwm-neon-bricks/releases/tag/latest)).
2. Open the file and allow "Install from this source" if Android asks.
3. If an older build will not update (signature mismatch), uninstall it first.

The APK runs on 64-bit phones and 32-bit tablets (arm64-v8a and armeabi-v7a). It is debug-signed, for sideloading only.

## How to play

- Put a thumb anywhere in the lower part of the screen and slide it: the paddle follows the slide (it never jumps to the finger, so the thumb never covers the ball).
- Lift the thumb to launch the ball, or wait 3 seconds and it launches itself.
- A brick with a star drops a capsule; catch it for the Komet: the ball ploughs through bricks for a short time.
- Clear every brick that glows (chrome never breaks) to get the star.
- Three-finger tap shows the performance readout (fps, draw calls, memory).

## For a host app (MWM Play)

The autoload `NeonBricks` holds the hooks: `set_full_unlock(on)` (default `true`, so the stand-alone build has every level open), `set_difficulty(easy)`, `set_shell_inset(inset)`, `set_sfx_on`, `set_music_on`, `set_haptics_on`, `set_less_motion`, `save_game()`, and the signals `level_card_shown(level_id)` and `free_levels_finished()`. With `Engine.set_meta(&"mwm_play_shell", true)` the game hides its own home disc and settings gear and leaves the back button to the host. Save file: `user://neon_bricks_save.json`.

## Development

- Godot 4.6, `mobile` renderer, portrait 1080x1920. APKs are built by GitHub Actions on every push to `main`.
- Logic test (net, gentle restart, bot clears all 5 levels, flash limiter, save): `godot --headless --audio-driver Dummy res://tests/net_test.tscn`
- Screenshot bot: `tests/capture.tscn` (phases `shots`, `inset`, `tall`, `shell`; see the header of `tests/capture.gd`).
- Lint: `gdlint scripts tests` and `gdformat --check scripts tests`.

Credits and licences: `CREDITS.md`. Font: Fredoka (SIL OFL 1.1, `assets/fonts/Fredoka-OFL.txt`).
