class_name NbPlay
extends Node

## One level in play: owns the NbSim, reads touches (relative drag in the
## drag zone, launch on release), feeds sim events to NbWorld, NbSfx and the
## flash limiter (every glow spike goes through it, GDD 15.3.1), runs the
## chain and last-brick slow-mo, the combo meter and shows the win card.

signal map_requested
signal level_started(id: int)
## Level 30's "next": the endless page of the map (GDD 8.3).
signal endless_requested

## Test bot: hold the paddle still this close above it (see bot_target).
const BOT_HOLD_PX: float = 120.0

## Test hooks (capture bot / headless tests only).
var autopilot: bool = false
var force_charged_net: bool = false

var sim: NbSim
var music: NbMusic
var world: NbWorld
var sfx: NbSfx
var level_id: int = 1
var active: bool = false
var paused: bool = false

var win_card: NbWinCard
var hand: NbHandHint
var meter: NbComboMeter
var dim_rect: ColorRect
var resume_disc: NbDisc

var _limiter := NbFlashLimiter.new()
var _pointer: int = -1
var _last_x: float = 0.0
var _last_us: int = 0
var _clock_s: float = 0.0
var _level_t: float = 0.0
var _slowmo_t: float = -1.0
var _chain_t: float = -1.0
## Real-clock times of the last Neonrush shakes (at most 3 per second).
var _shake_times: Array[float] = []
## Delayed sounds: [real clock time, name, pitch, db].
var _pending_sfx: Array = []
## Delayed boss death bursts: [real clock time, pos, colour].
var _pending_bursts: Array = []
var _card_t: float = -1.0
var _card_shown: bool = false
var _holdover_until_ms: int = 0
var _dragged: bool = false
var _idle_t: float = 0.0
var _auto_off: float = 0.0
var _auto_rng := RandomNumberGenerator.new()
## Saktetid pitch (GDD 16.2.2), applied to music and effects.
var _pitch: float = 1.0


func setup(
	w: NbWorld, s: NbSfx, field_frame: Control, center_frame: Control, screen_root: Control
) -> void:
	world = w
	sfx = s
	hand = NbHandHint.new()
	hand.size = Vector2(NbBalance.DESIGN_W, NbBalance.DESIGN_H)
	hand.visible = false
	field_frame.add_child(hand)
	meter = NbComboMeter.new()
	field_frame.add_child(meter)
	dim_rect = ColorRect.new()
	dim_rect.color = Color(0, 0, 0, 0)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(dim_rect)
	screen_root.move_child(dim_rect, 0)
	win_card = NbWinCard.new()
	center_frame.add_child(win_card)
	win_card.replay_pressed.connect(func() -> void: start_level(level_id))
	win_card.map_pressed.connect(func() -> void: map_requested.emit())
	win_card.next_pressed.connect(_on_next)
	resume_disc = NbDisc.new()
	resume_disc.icon = "play"
	resume_disc.disc_radius = 120.0
	resume_disc.size = Vector2(300, 300)
	resume_disc.position = Vector2(540 - 150, 960 - 150)
	resume_disc.visible = false
	resume_disc.tapped.connect(resume)
	center_frame.add_child(resume_disc)
	set_process(false)


func start_level(id: int) -> void:
	level_id = id
	level_started.emit(id)
	if sim:
		sim.disconnect_all()
	if id > NbLevels.ENDLESS_BASE:
		NeonBricks.mark_endless(id - NbLevels.ENDLESS_BASE)
	sim = NbSim.new()
	sim.rng.randomize()
	sim.setup(NbLevels.get_level(id), NeonBricks.easy, force_charged_net)
	_connect_sim()
	world.show_gameplay(true)
	world.set_world(NbLevels.world_of(id))
	world.bind_level(sim)
	world.set_less_motion(NeonBricks.less_motion)
	meter.less_motion = NeonBricks.less_motion
	meter.reset()
	meter.visible = true
	world.start_intro()
	win_card.less_motion = NeonBricks.less_motion
	win_card.hide_card()
	resume_disc.visible = false
	dim_rect.color = Color(0, 0, 0, 0)
	Engine.time_scale = 1.0
	_slowmo_t = -1.0
	_chain_t = -1.0
	_shake_times.clear()
	_pending_sfx.clear()
	_pending_bursts.clear()
	_card_t = -1.0
	_card_shown = false
	_pointer = -1
	_level_t = 0.0
	_idle_t = 0.0
	_dragged = false
	paused = false
	_holdover_until_ms = Time.get_ticks_msec() + NbBalance.HOLDOVER_MS
	NbDisc.block_input(NbBalance.HOLDOVER_MS)
	_last_us = Time.get_ticks_usec()
	active = true
	set_process(true)
	if NeonBricks.first_launch:
		NeonBricks.first_launch = false
		NeonBricks.save_game()


func stop() -> void:
	active = false
	set_process(false)
	Engine.time_scale = 1.0
	hand.visible = false
	meter.visible = false
	win_card.hide_card()
	resume_disc.visible = false
	dim_rect.color = Color(0, 0, 0, 0)
	world.reset_camera_fx()
	_pitch = 1.0
	sfx.pitch_mul = 1.0
	if music:
		music.set_pitch(1.0)


func card_visible() -> bool:
	return _card_shown


func _connect_sim() -> void:
	sim.paddle_hit.connect(_on_paddle_hit)
	sim.wall_hit.connect(_on_wall_hit)
	sim.brick_hit.connect(_on_brick_hit)
	sim.brick_broken.connect(_on_brick_broken)
	sim.chrome_hit.connect(func(_i: int, _p: Vector2) -> void: sfx.play("ting", 1.0, -6.0))
	sim.net_caught.connect(_on_net)
	sim.capsule_caught.connect(_on_capsule)
	sim.nudged.connect(func(_p: Vector2) -> void: sfx.play("zip", 1.0, -8.0))
	sim.assist_armed.connect(func(i: int) -> void: world.fx_assist(i))
	sim.restart_started.connect(func() -> void: sfx.play("whoosh", 1.0, -4.0))
	sim.bricks_restored.connect(func(idx: PackedInt32Array) -> void: world.fx_restored(idx))
	sim.level_cleared.connect(_on_cleared)
	sim.combo_stepped.connect(_on_combo_step)
	sim.combo_dropped.connect(func(_c: int) -> void: meter.drop())
	sim.capsule_spawned.connect(_on_capsule_spawned)
	sim.chain_burst.connect(_on_chain_burst)
	sim.nova_blasted.connect(_on_nova)
	sim.echo_split.connect(_on_echo_split)
	sim.boss_hit.connect(_on_boss_hit)
	sim.boss_phase_changed.connect(_on_boss_phase)
	sim.boss_defeated.connect(_on_boss_defeated)
	sim.march_stepped.connect(_on_march_step)
	sim.finale_started.connect(func() -> void: sfx.play("zip", 0.7, -6.0))
	sim.pulse_fired.connect(_on_pulse)
	sim.ghosts_flipped.connect(_on_ghosts_flipped)
	sim.ghost_warned.connect(_on_ghost_warned)
	sim.switch_hit.connect(func(i: int) -> void: world.fx_switch(i, _limiter.allow(_clock_s)))
	sim.portal_used.connect(_on_portal)
	sim.shield_added.connect(_on_shield)
	sim.boss_jump_started.connect(_on_boss_jump)
	sim.nova_ring_added.connect(_on_nova_ring)


# ---------------------------------------------------------------- loop


func _process(_delta: float) -> void:
	if not active:
		return
	var now: int = Time.get_ticks_usec()
	var real_dt: float = clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now
	if paused:
		return
	_clock_s += real_dt
	_slowmo(real_dt)
	_flush_sfx()
	var game_dt: float = real_dt * Engine.time_scale
	if autopilot:
		_dragged = true
		_idle_t = 0.0
		_drive_autopilot()
	if not _card_shown:
		sim.step(game_dt)
	_sync_pitch(real_dt)
	world.sync(sim, real_dt, game_dt)
	world.sync_camera(real_dt)
	meter.set_combo(sim.combo)
	dim_rect.color = Color(0, 0, 0, sim.restart_dim() * NbBalance.RESTART_DIM_LEVEL)
	_level_t += real_dt
	_idle_t += real_dt
	_update_hand()
	if _card_t >= 0.0 and not _card_shown:
		_card_t += real_dt
		if _card_t >= NbBalance.WIN_CARD_DELAY_S:
			_show_card()


func _slowmo(real_dt: float) -> void:
	if _slowmo_t < 0.0:
		_chain_slowmo(real_dt)
		return
	_chain_t = -1.0
	_slowmo_t += real_dt
	if _slowmo_t < NbBalance.SLOWMO_S:
		Engine.time_scale = NbBalance.SLOWMO_SCALE
	elif _slowmo_t < NbBalance.SLOWMO_S + NbBalance.SLOWMO_RETURN_S:
		var k: float = (_slowmo_t - NbBalance.SLOWMO_S) / NbBalance.SLOWMO_RETURN_S
		Engine.time_scale = lerpf(NbBalance.SLOWMO_SCALE, 1.0, k)
	else:
		Engine.time_scale = 1.0
		_slowmo_t = -1.0


## Chain slow-mo (GDD 15.3.1): 0.5x for 0.25 s real time, back over 0.15 s.
## Kept under "Mindre bevegelse"; the last-brick slow-mo always wins.
func _chain_slowmo(real_dt: float) -> void:
	if _chain_t < 0.0:
		return
	_chain_t += real_dt
	var hold: float = NbBalance.CHAIN_SLOWMO_S
	var back: float = NbBalance.CHAIN_SLOWMO_RETURN_S
	if _chain_t < hold:
		Engine.time_scale = NbBalance.CHAIN_SLOWMO_SCALE
	elif _chain_t < hold + back:
		Engine.time_scale = lerpf(NbBalance.CHAIN_SLOWMO_SCALE, 1.0, (_chain_t - hold) / back)
	else:
		Engine.time_scale = 1.0
		_chain_t = -1.0


## Saktetid: music and effects pitch down over 0.3 s while the tape is slow
## and wind back up over the last 0.5 s (follows the sim's slow factor).
func _sync_pitch(real_dt: float) -> void:
	var low: float = NbBalance.saktetid_pitch(sim.easy)
	var sc: float = NbBalance.saktetid_scale(sim.easy)
	var k: float = (1.0 - sim.slow_factor()) / (1.0 - sc)
	var want: float = lerpf(1.0, low, clampf(k, 0.0, 1.0))
	if want < _pitch:
		_pitch = move_toward(_pitch, want, (1.0 - low) / 0.3 * real_dt)
	else:
		_pitch = want
	sfx.pitch_mul = _pitch
	if music:
		music.set_pitch(_pitch)


func _queue_sfx(delay_s: float, name: String, pitch: float, db: float) -> void:
	_pending_sfx.append([_clock_s + delay_s, name, pitch, db])


func _flush_sfx() -> void:
	var i: int = 0
	while i < _pending_sfx.size():
		var e: Array = _pending_sfx[i]
		if _clock_s >= float(e[0]):
			sfx.play(String(e[1]), float(e[2]), float(e[3]))
			_pending_sfx.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _pending_bursts.size():
		var bu: Array = _pending_bursts[i]
		if _clock_s >= float(bu[0]):
			world.fx_burst(bu[1], bu[2], NbBalance.SHARDS_RUSH, _limiter.allow(_clock_s))
			_pending_bursts.remove_at(i)
		else:
			i += 1


func _update_hand() -> void:
	var playing: bool = sim.state == NbSim.State.PLAY or sim.state == NbSim.State.REST
	var want: bool = false
	if playing and not _card_shown:
		if not _dragged and _level_t >= NbBalance.HAND_FIRST_S:
			want = true
		elif _dragged and _idle_t >= NbBalance.IDLE_HINT_S:
			want = true
	if want and not hand.visible:
		hand.restart()
	hand.visible = want


func _drive_autopilot() -> void:
	sim.set_paddle_target(NbPlay.bot_target(sim, _auto_off))


## Paddle bot shared by the capture bot and the headless tests (same idea as
## tools/action_sim.py): follow a falling main ball with a random contact
## offset, else the lowest falling echo, else the lowest capsule. Like a
## thumb, it holds still for the last BOT_HOLD_PX above the paddle once it
## is in place, so paddle english (GDD 4.3) does not randomise every shot.
static func bot_target(s: NbSim, off: float) -> float:
	var main: NbSim.Ball = s.balls[0]
	if main.vel.y > 0.0 or s.state != NbSim.State.PLAY:
		var want: float = main.pos.x - off
		var above: float = s.paddle_top() - (main.pos.y + NbBalance.BALL_RADIUS)
		if (
			main.vel.y > 0.0
			and above < BOT_HOLD_PX
			and absf(s.paddle_x - want) < s.paddle_half * 0.5
		):
			return s.paddle_x
		return want
	var best_y: float = -INF
	var tx: float = main.pos.x
	for i: int in range(1, s.balls.size()):
		var e: NbSim.Ball = s.balls[i]
		if e.vel.y > 0.0 and e.pos.y > best_y:
			best_y = e.pos.y
			tx = e.pos.x
	if best_y > -INF:
		return tx
	for c: NbSim.Capsule in s.capsules:
		if c.alive and c.pos.y > best_y:
			best_y = c.pos.y
			tx = c.pos.x
	return tx


# ---------------------------------------------------------------- input


func _input(event: InputEvent) -> void:
	if not active or paused or _card_shown:
		return
	var st := event as InputEventScreenTouch
	if st:
		_on_touch(st)
		return
	var dr := event as InputEventScreenDrag
	if dr and dr.index == _pointer:
		var dx: float = dr.position.x - _last_x
		_last_x = dr.position.x
		sim.drag_paddle(dx)
		_dragged = true
		_idle_t = 0.0


func _on_touch(st: InputEventScreenTouch) -> void:
	if st.pressed:
		if Time.get_ticks_msec() < _holdover_until_ms:
			return
		var logic: Vector2 = st.position - world.frame_offset()
		var vh: float = get_viewport().get_visible_rect().size.y
		var in_zone: bool = (
			logic.y >= NbBalance.DRAG_TOP and st.position.y < vh - NbBalance.WRIST_STRIP
		)
		if not in_zone:
			return
		_pointer = st.index
		_last_x = st.position.x
		world.fx_touch()
		sfx.play("hum", 1.0, -12.0)
	elif st.index == _pointer:
		_pointer = -1
		sim.release()


# ---------------------------------------------------------------- sim events


func _on_paddle_hit(_pos: Vector2, rel: float) -> void:
	world.fx_paddle_hit()
	sfx.play("bop", 0.8 + 0.5 * absf(rel))
	_auto_off = _auto_rng.randf_range(-0.6, 0.6) * sim.paddle_half


func _on_wall_hit(side: int, _pos: Vector2) -> void:
	world.fx_wall(side)
	sfx.play("tick", 1.0, -10.0)


func _on_brick_hit(i: int) -> void:
	world.fx_brick_hit(i)
	sfx.play("tink", 1.0, -4.0)


func _on_brick_broken(i: int, _last: bool) -> void:
	var spike: bool = _limiter.allow(_clock_s)
	var tier: int = sim.combo_tier()
	world.fx_brick_broken(sim, i, spike, tier)
	sfx.note(mini(sim.combo - 1, NbBalance.NOTE_STEPS_MAX - 1))
	if tier >= 1:
		sfx.play("bwomm", 0.55, -14.0)
	if tier >= 2:
		_rush_shake()


## Neonrush shake (GDD 15.3.1, owner default Q7): 3 px for 60 ms per break,
## Vanlig only, at most 3 per second, never under "Mindre bevegelse".
func _rush_shake() -> void:
	if not shake_allowed():
		return
	while not _shake_times.is_empty() and _clock_s - _shake_times[0] >= 1.0:
		_shake_times.pop_front()
	if _shake_times.size() >= NbBalance.RUSH_SHAKE_MAX_PER_S:
		return
	_shake_times.append(_clock_s)
	world.fx_shake(NbBalance.RUSH_SHAKE_PX, NbBalance.RUSH_SHAKE_S)


## Gameplay shake (Neonrush, Nova) is Vanlig only and never under "Mindre
## bevegelse" (GDD 15.10: Lett has no shake). The last-brick shake is the
## shipped celebration and keeps its own rule (off under less motion).
func shake_allowed() -> bool:
	return not NeonBricks.easy and not NeonBricks.less_motion


func _on_combo_step(c: int, _pos: Vector2) -> void:
	meter.set_combo(c)


func _on_capsule_spawned(c: NbSim.Capsule) -> void:
	if not c.bonus:
		return
	sfx.play("note", 1.5, -6.0)
	_queue_sfx(0.12, "note", 2.0, -6.0)
	world.fx_ring(c.pos, Color(1.0, 0.9, 0.6), 0.6, _limiter.allow(_clock_s))


func _on_chain_burst() -> void:
	if _slowmo_t < 0.0 and not _card_shown:
		_chain_t = 0.0


func _on_nova(pos: Vector2) -> void:
	sfx.play("bwomm", 0.5, -2.0)
	world.fx_ring(pos, Color(1.0, 0.95, 0.75), 1.6, _limiter.allow(_clock_s))
	if shake_allowed():
		world.fx_shake(NbBalance.NOVA_SHAKE_PX, NbBalance.NOVA_SHAKE_S)


func _on_echo_split(_pos: Vector2) -> void:
	sfx.play("bop", 1.3, -4.0)
	_queue_sfx(0.07, "bop", 1.6, -4.0)
	_queue_sfx(0.14, "bop", 1.9, -4.0)


func _on_boss_hit(i: int, _pos: Vector2) -> void:
	var b: NbSim.Brick = sim.bricks[i]
	var lost: int = b.max_hp - maxi(b.hp, 0)
	sfx.play("bwomm", 0.75 + 0.04 * float(lost), -2.0)
	world.fx_boss_hit(i)


func _on_boss_phase(i: int, _phase: int) -> void:
	sfx.play("whoosh", 0.5, 0.0)
	world.fx_boss_roar(i, _limiter.allow(_clock_s))


func _on_boss_defeated(i: int, _pos: Vector2) -> void:
	sfx.play("bwomm", 0.4, 0.0)
	_queue_sfx(0.3, "arp", 1.0, -4.0)
	var b: NbSim.Brick = sim.bricks[i]
	for k: int in NbBalance.BOSS_DEATH_BURSTS:
		var off := Vector2((float(k) - 1.0) * 90.0, 0.0)
		_pending_bursts.append(
			[_clock_s + NbBalance.BOSS_DEATH_STAGGER_S * k, b.center() + off, b.color]
		)


## Tick-tock; the second block plays it a fifth higher (GDD 16.10).
func _on_march_step(block: int) -> void:
	var up: float = 1.5 if block == 1 else 1.0
	sfx.play("tick", 1.25 * up, -6.0)
	_queue_sfx(0.14, "tick", 0.9 * up, -6.0)


func _on_pulse(lo: float, hi: float) -> void:
	sfx.play("zip", 1.4, -8.0)
	world.fx_pulse(lo, hi, _limiter.allow(_clock_s))


## Two-tone "click-clack" on every flip.
func _on_ghosts_flipped(_a_solid: bool, _auto: bool) -> void:
	sfx.play("tick", 1.6, -4.0)
	_queue_sfx(0.09, "tick", 1.1, -4.0)


func _on_ghost_warned(_a_next: bool) -> void:
	world.fx_ghost_warn(_limiter.allow(_clock_s))
	sfx.play("tick", 2.0, -8.0)
	_queue_sfx(0.5, "tick", 2.0, -8.0)


## Falling "whoop" in, rising "whoop" out.
func _on_portal(ball: int, from: Vector2, to: Vector2) -> void:
	world.fx_portal(sim, ball, from, to)
	sfx.play("zip", 0.6, -6.0)
	_queue_sfx(0.08, "zip", 1.5, -6.0)


func _on_shield(_charges: int) -> void:
	world.fx_shield()
	sfx.play("note", 2.25, -4.0)


func _on_boss_jump(_i: int, from: Vector2, to: Vector2) -> void:
	sfx.play("whoosh", 0.45, -2.0)
	world.fx_boss_jump(from, to, _limiter.allow(_clock_s))


func _on_nova_ring(idx: PackedInt32Array) -> void:
	for k: int in idx.size():
		_queue_sfx(0.06 * k, "note", 1.5 + 0.25 * k, -8.0)


func _on_net(pos: Vector2, _left: int) -> void:
	world.fx_net(pos, not sim.net_unlimited)
	sfx.play("bwomm")


func _on_capsule(kind: String, _pos: Vector2) -> void:
	if _limiter.allow(_clock_s):
		world.fx_touch()
	var pitch: Dictionary = {
		"komet": 1.0,
		"ekko": 1.12,
		"bredvinge": 0.9,
		"neonpuls": 1.25,
		"saktetid": 0.8,
		"skjoldnett": 1.33,
	}
	sfx.play("arp", pitch.get(kind, 1.0))


func _on_cleared(pos: Vector2) -> void:
	_slowmo_t = 0.0
	_chain_t = -1.0
	world.fx_last_brick(pos)
	sfx.play("win")
	if level_id > NbLevels.ENDLESS_BASE:
		NeonBricks.mark_endless(level_id - NbLevels.ENDLESS_BASE + 1)
	else:
		NeonBricks.mark_cleared(level_id)
	_card_t = 0.0
	hand.visible = false


func _show_card() -> void:
	_card_shown = true
	Engine.time_scale = 1.0
	_slowmo_t = -1.0
	var nxt: int = NeonBricks.next_level_after(level_id)
	win_card.show_card(NbLevels.get_level(level_id)["rows"], nxt != 0, NbLevels.world_of(level_id))
	NbDisc.block_input(NbBalance.HOLDOVER_MS)
	NeonBricks.level_card_shown.emit(level_id)
	if not NeonBricks.full_unlock and level_id == NbBalance.FREE_LEVELS:
		NeonBricks.free_levels_finished.emit()


func _on_next() -> void:
	var nxt: int = NeonBricks.next_level_after(level_id)
	if nxt < 0:
		endless_requested.emit()
	elif nxt != 0:
		start_level(nxt)


# ---------------------------------------------------------------- pause


func pause() -> void:
	if not active:
		return
	paused = true
	Engine.time_scale = 1.0
	_pointer = -1


## Back from the background: big play disc, scene dimmed 50%; resumes on
## release.
func show_resume() -> void:
	if not active or not paused:
		return
	if _card_shown:
		paused = false
		return
	resume_disc.visible = true
	dim_rect.color = Color(0, 0, 0, 0.5)


func resume() -> void:
	paused = false
	resume_disc.visible = false
	dim_rect.color = Color(0, 0, 0, 0)
	_last_us = Time.get_ticks_usec()
	_holdover_until_ms = Time.get_ticks_msec() + NbBalance.HOLDOVER_MS
