class_name NbPlay
extends Node

## One level in play: owns the NbSim, reads touches (relative drag in the
## drag zone, launch on release), feeds sim events to NbWorld, NbSfx and the
## flash limiter, runs slow-mo on the last brick and shows the win card.

signal map_requested

## Test hooks (capture bot / headless tests only).
var autopilot: bool = false
var force_charged_net: bool = false

var sim: NbSim
var world: NbWorld
var sfx: NbSfx
var level_id: int = 1
var active: bool = false
var paused: bool = false

var win_card: NbWinCard
var hand: NbHandHint
var dim_rect: ColorRect
var resume_disc: NbDisc

var _limiter := NbFlashLimiter.new()
var _pointer: int = -1
var _last_x: float = 0.0
var _last_us: int = 0
var _clock_s: float = 0.0
var _level_t: float = 0.0
var _slowmo_t: float = -1.0
var _card_t: float = -1.0
var _card_shown: bool = false
var _holdover_until_ms: int = 0
var _dragged: bool = false
var _idle_t: float = 0.0
var _auto_off: float = 0.0
var _auto_rng := RandomNumberGenerator.new()


func setup(
	w: NbWorld, s: NbSfx, field_frame: Control, center_frame: Control, screen_root: Control
) -> void:
	world = w
	sfx = s
	hand = NbHandHint.new()
	hand.size = Vector2(NbBalance.DESIGN_W, NbBalance.DESIGN_H)
	hand.visible = false
	field_frame.add_child(hand)
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
	sim = NbSim.new()
	sim.rng.randomize()
	sim.setup(NbLevels.get_level(id), NeonBricks.easy, force_charged_net)
	_connect_sim()
	world.show_gameplay(true)
	world.bind_level(sim)
	world.set_less_motion(NeonBricks.less_motion)
	world.start_intro()
	win_card.less_motion = NeonBricks.less_motion
	win_card.hide_card()
	resume_disc.visible = false
	dim_rect.color = Color(0, 0, 0, 0)
	Engine.time_scale = 1.0
	_slowmo_t = -1.0
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
	win_card.hide_card()
	resume_disc.visible = false
	dim_rect.color = Color(0, 0, 0, 0)
	world.reset_camera_fx()


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
	var game_dt: float = real_dt * Engine.time_scale
	if autopilot:
		_dragged = true
		_idle_t = 0.0
		_drive_autopilot()
	if not _card_shown:
		sim.step(game_dt)
	world.sync(sim, real_dt, game_dt)
	world.sync_camera(real_dt)
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
		return
	_slowmo_t += real_dt
	if _slowmo_t < NbBalance.SLOWMO_S:
		Engine.time_scale = NbBalance.SLOWMO_SCALE
	elif _slowmo_t < NbBalance.SLOWMO_S + NbBalance.SLOWMO_RETURN_S:
		var k: float = (_slowmo_t - NbBalance.SLOWMO_S) / NbBalance.SLOWMO_RETURN_S
		Engine.time_scale = lerpf(NbBalance.SLOWMO_SCALE, 1.0, k)
	else:
		Engine.time_scale = 1.0
		_slowmo_t = -1.0


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
	var target: float = sim.ball_pos.x - _auto_off
	# Catch a falling capsule when the ball is high and moving up.
	if not sim.capsules.is_empty() and sim.ball_vel.y < 0.0 and sim.ball_pos.y < 900.0:
		target = sim.capsules[0].pos.x
	sim.set_paddle_target(target)


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
	world.fx_brick_broken(sim, i, spike)
	sfx.note(sim.note_step - 1)


func _on_net(pos: Vector2, _left: int) -> void:
	world.fx_net(pos, not sim.net_unlimited)
	sfx.play("bwomm")


func _on_capsule(_kind: String, _pos: Vector2) -> void:
	if _limiter.allow(_clock_s):
		world.fx_touch()
	sfx.play("arp")


func _on_cleared(pos: Vector2) -> void:
	_slowmo_t = 0.0
	world.fx_last_brick(pos)
	sfx.play("win")
	NeonBricks.mark_cleared(level_id)
	_card_t = 0.0
	hand.visible = false


func _show_card() -> void:
	_card_shown = true
	Engine.time_scale = 1.0
	_slowmo_t = -1.0
	var nxt: int = NeonBricks.next_level_after(level_id)
	win_card.show_card(NbLevels.get_level(level_id)["rows"], nxt != 0)
	NbDisc.block_input(NbBalance.HOLDOVER_MS)
	NeonBricks.level_card_shown.emit(level_id)
	if not NeonBricks.full_unlock and level_id == NbBalance.FREE_LEVELS:
		NeonBricks.free_levels_finished.emit()


func _on_next() -> void:
	var nxt: int = NeonBricks.next_level_after(level_id)
	if nxt != 0:
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
