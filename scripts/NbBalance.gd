class_name NbBalance
extends RefCounted

## Every tunable number of MWM Neon Bricks (GDD section 7). Distances are
## logic px on the 1080 x 1920 design frame; 1 px = 0.01 m on the play plane.
## Lett/Vanlig pairs are picked with the helpers at the bottom.

# --- Layout (GDD 4.1) ---
const FIELD_LEFT: float = 40.0
const FIELD_RIGHT: float = 1040.0
const FIELD_TOP: float = 280.0
const GRID_COLS: int = 10
const GRID_ROWS: int = 12
const CELL_W: float = 100.0
const CELL_H: float = 52.0
const GRID_X: float = 40.0
const GRID_Y: float = 340.0
const BRICK_W: float = 92.0
const BRICK_H: float = 44.0
const PADDLE_Y: float = 1420.0
const PADDLE_H: float = 36.0
const PADDLE_W_LETT: float = 400.0
const PADDLE_W_MAX: float = 560.0
const BALL_RADIUS: float = 22.0
const NET_Y: float = 1540.0
const LOSS_Y: float = 1700.0
const DESIGN_W: float = 1080.0
const DESIGN_H: float = 1920.0

# --- Zones (GDD 3.1) ---
const HOME_SQUARE: float = 232.0
const DRAG_TOP: float = 960.0
const WRIST_STRIP: float = 256.0

# --- Paddle (GDD 4.3) ---
const EDGE_GRACE_LETT: float = 22.0
const EDGE_GRACE_VANLIG: float = 13.0
const DRAG_GAIN: float = 1.25
const PADDLE_MAX_SPEED: float = 6000.0
const MAX_BOUNCE_DEG_LETT: float = 55.0
const MAX_BOUNCE_DEG_VANLIG: float = 60.0
const ENGLISH_LETT: float = 0.05
const ENGLISH_VANLIG: float = 0.10
const PADDLE_CONTACT_ABOVE: float = 4.0
const PADDLE_CONTACT_BELOW: float = 24.0

# --- Ball (GDD 4.2) ---
const BALL_SPEED_MIN: float = 300.0
const BALL_SPEED_MAX: float = 1000.0
const RAMP_STEP: float = 0.02
const RAMP_EVERY_S: float = 15.0
const RAMP_CAP: float = 0.15
const SUBSTEP_MAX_PX: float = 8.0

# --- Anti-stuck (GDD 4.4) ---
const MIN_SIDE_DEG: float = 6.0
const MIN_FLAT_DEG: float = 20.0
const CHROME_JITTER_DEG: float = 3.0
const LOOP_REPEATS: int = 3
const LOOP_WINDOW_S: float = 10.0
const LOOP_CELL_PX: float = 20.0
const DRY_SPELL_S: float = 10.0
const DRY_REPEAT_S: float = 5.0
const NUDGE_DEG: float = 9.0
const ASSIST_S_LETT: float = 15.0
const ASSIST_S_VANLIG: float = 30.0
const ASSIST_GLOW_S: float = 1.0
const RESPAWN_OUTSIDE_PX: float = 100.0

# --- Launch (GDD 4.5) ---
const AUTO_LAUNCH_S: float = 3.0
const LAUNCH_DEG_MIN: float = 10.0
const LAUNCH_DEG_MAX: float = 20.0

# --- Net and gentle restart (GDD 4.6) ---
const NET_CHARGES: int = 3
const RESTART_DIM_S: float = 0.6
const RESTART_REWIND_S: float = 0.8
const RESTART_LIFT_S: float = 0.4
const RESTART_DIM_LEVEL: float = 0.6

# --- Capsules and Komet (GDD 5.2) ---
const CAPSULE_W: float = 112.0
const CAPSULE_H: float = 56.0
const CAPSULE_FALL_LETT: float = 180.0
const CAPSULE_FALL_VANLIG: float = 240.0
const CAPSULE_MAGNET_Y: float = 1100.0
const CAPSULE_MAGNET_SPEED: float = 400.0
const CAPSULE_CATCH_GROW: float = 20.0
const CAPSULE_FADE_Y: float = 1600.0
const CAPSULE_MAX: int = 3
const KOMET_BRICKS_LETT: int = 10
const KOMET_BRICKS_VANLIG: int = 8
const KOMET_S_LETT: float = 8.0
const KOMET_S_VANLIG: float = 6.0

# --- Feel (GDD 9) ---
const MAX_FLASHES_PER_S: int = 3
const HOLDOVER_MS: int = 300
const NOTE_STEPS_MAX: int = 8
const SLOWMO_SCALE: float = 0.25
const SLOWMO_S: float = 0.6
const SLOWMO_RETURN_S: float = 0.3
const WIN_CARD_DELAY_S: float = 1.2
const WIN_CARD_FADE_S: float = 0.25
const PUSH_IN: float = 0.08
const SHAKE_LAST_PX: float = 10.0
const SHAKE_LAST_S: float = 0.25
const TOUCH_GLOW_S: float = 0.08
const TOUCH_GLOW_GAIN: float = 0.4
const PADDLE_SQUASH: float = 0.9
const PADDLE_SQUASH_S: float = 0.1
const BRICK_SQUASH: float = 0.9
const BRICK_SQUASH_S: float = 0.08
const BRICK_FADE_S: float = 0.15
const WALL_GLOW_S: float = 0.12
const NET_RIPPLE_S: float = 0.4
const INTRO_SWEEP_S: float = 1.0
const INTRO_SWEEP_DEG: float = 14.0
const DRIFT_DEG: float = 1.5
const DRIFT_PERIOD_S: float = 12.0
const HAND_LOOP_S: float = 1.6
const HAND_FIRST_S: float = 1.0
const IDLE_HINT_S: float = 7.0
const SHARDS: int = 24
const SHARD_LIFE_S: float = 0.5
const PARTICLE_POOL: int = 8
const PUFF_S: float = 0.2

# --- Home guard (GDD 3.2, copies the MWM Play shell) ---
const HOME_GUARD_S: float = 2.0
const HOME_GUARD_MIN_S: float = 0.3

# --- Free part (GDD 6.1) ---
const FREE_LEVELS: int = 3

# --- Rendering (DESIGN 6a) ---
const PX_TO_M: float = 0.01
const CAM_DIST: float = 13.5
const EYE_HEIGHT: float = 6.2
const CAM_NEAR: float = 0.5


static func paddle_w(easy: bool, level_paddle: float) -> float:
	return PADDLE_W_LETT if easy else level_paddle


static func edge_grace(easy: bool) -> float:
	return EDGE_GRACE_LETT if easy else EDGE_GRACE_VANLIG


static func max_bounce_deg(easy: bool) -> float:
	return MAX_BOUNCE_DEG_LETT if easy else MAX_BOUNCE_DEG_VANLIG


static func english(easy: bool) -> float:
	return ENGLISH_LETT if easy else ENGLISH_VANLIG


static func assist_s(easy: bool) -> float:
	return ASSIST_S_LETT if easy else ASSIST_S_VANLIG


static func capsule_fall(easy: bool) -> float:
	return CAPSULE_FALL_LETT if easy else CAPSULE_FALL_VANLIG


static func komet_bricks(easy: bool) -> int:
	return KOMET_BRICKS_LETT if easy else KOMET_BRICKS_VANLIG


static func komet_s(easy: bool) -> float:
	return KOMET_S_LETT if easy else KOMET_S_VANLIG
