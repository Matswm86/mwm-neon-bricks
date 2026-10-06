class_name NbSim
extends RefCounted

## Pure game logic of one level in logic px (GDD sections 4 and 5): paddle,
## one ball, bricks, Komet capsules, net, anti-stuck rules, aim assist and the
## gentle restart. No nodes, no rendering: NbPlay drives it and NbWorld draws
## it, and tests run it headless.

signal launched
signal paddle_hit(pos: Vector2, rel: float)
signal wall_hit(side: int, pos: Vector2)
signal brick_hit(index: int)
signal brick_broken(index: int, last: bool)
signal chrome_hit(index: int, pos: Vector2)
signal net_caught(pos: Vector2, charges_left: int)
signal capsule_spawned(capsule: Capsule)
signal capsule_caught(kind: String, pos: Vector2)
signal capsule_missed(capsule: Capsule)
signal komet_changed(active: bool)
signal nudged(pos: Vector2)
signal assist_armed(index: int)
signal restart_started
signal bricks_restored(indices: PackedInt32Array)
signal restart_finished
signal level_cleared(pos: Vector2)

enum State { REST, PLAY, RESTART, CLEAR }


class Brick:
	var row: int = 0
	var col: int = 0
	var code: String = "G"
	var carrier: bool = false
	var max_hp: int = 1
	var hp: int = 1
	var alive: bool = true
	var rect: Rect2 = Rect2()
	var color: Color = Color(1, 1, 1)

	func breakable() -> bool:
		return max_hp > 0

	func center() -> Vector2:
		return rect.get_center()


class Capsule:
	var pos: Vector2 = Vector2.ZERO
	var kind: String = "komet"
	var age: float = 0.0
	var alive: bool = true


var level: Dictionary = {}
var easy: bool = true
var state: State = State.REST
var time: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var bricks: Array[Brick] = []
var breakable_left: int = 0
var capsules: Array[Capsule] = []

var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var ball_visible: bool = true
var base_speed: float = 520.0

var paddle_x: float = 540.0
var paddle_target: float = 540.0
var paddle_vx: float = 0.0
var paddle_half: float = 200.0

var net_unlimited: bool = true
var net_charges: int = 0
var net_catches: int = 0

var komet_left: int = 0
var komet_t: float = 0.0

## Number of bricks broken since the last paddle touch (pentatonic step).
var note_step: int = 0
var restart_count: int = 0
var assist_on: bool = false
var assist_index: int = -1

var _rest_t: float = 0.0
var _ramp_t: float = 0.0
var _last_break_t: float = 0.0
var _next_dry_t: float = 0.0
var _loop_records: Array = []
var _restart_t: float = 0.0
var _restored: bool = false
var _refilled: bool = false


## Builds the level. force_charged_net is the test-only flag (GDD 12): the
## 3-charge net and gentle restart on a world 1 level.
func setup(lv: Dictionary, is_easy: bool, force_charged_net: bool = false) -> void:
	level = lv
	easy = is_easy
	base_speed = float(lv["lett_speed"]) if easy else float(lv["vanlig_speed"])
	paddle_half = NbBalance.paddle_w(easy, float(lv["vanlig_paddle"])) * 0.5
	var vnet: int = int(lv["vanlig_net"])
	net_unlimited = easy or vnet == 0
	net_charges = 0 if net_unlimited else vnet
	if force_charged_net:
		net_unlimited = false
		net_charges = NbBalance.NET_CHARGES
	_build_bricks()
	paddle_x = 540.0
	paddle_target = 540.0
	time = 0.0
	restart_count = 0
	_to_rest()


func _build_bricks() -> void:
	bricks.clear()
	breakable_left = 0
	var rows: Array = level["rows"]
	var colors: Dictionary = NbLevels.row_colors(rows)
	for r: int in rows.size():
		var s: String = rows[r]
		for c: int in mini(s.length(), NbBalance.GRID_COLS):
			var ch: String = s[c]
			if ch == ".":
				continue
			var b := Brick.new()
			b.row = r
			b.col = c
			b.code = ch.to_upper()
			b.carrier = ch != ch.to_upper()
			match b.code:
				"D":
					b.max_hp = 2
				"C":
					b.max_hp = -1
				_:
					b.max_hp = 1
			b.hp = b.max_hp
			var x0: float = (
				NbBalance.GRID_X
				+ NbBalance.CELL_W * c
				+ (NbBalance.CELL_W - NbBalance.BRICK_W) * 0.5
			)
			var y0: float = (
				NbBalance.GRID_Y
				+ NbBalance.CELL_H * r
				+ (NbBalance.CELL_H - NbBalance.BRICK_H) * 0.5
			)
			b.rect = Rect2(x0, y0, NbBalance.BRICK_W, NbBalance.BRICK_H)
			b.color = NbLevels.cell_color(b.code, colors.get(r, Color(1, 1, 1)))
			bricks.append(b)
			if b.breakable():
				breakable_left += 1


func paddle_top() -> float:
	return NbBalance.PADDLE_Y - NbBalance.PADDLE_H * 0.5


func ramp() -> float:
	if easy:
		return 1.0
	return (
		1.0
		+ minf(NbBalance.RAMP_CAP, NbBalance.RAMP_STEP * floorf(_ramp_t / NbBalance.RAMP_EVERY_S))
	)


func speed() -> float:
	return clampf(base_speed * ramp(), NbBalance.BALL_SPEED_MIN, NbBalance.BALL_SPEED_MAX)


func net_active() -> bool:
	return net_unlimited or net_charges > 0 or state == State.CLEAR


func komet_active() -> bool:
	return komet_left > 0


## Relative drag: the paddle never jumps to the finger (GDD 3.2).
func drag_paddle(dx: float) -> void:
	paddle_target = _clamp_paddle(paddle_target + dx * NbBalance.DRAG_GAIN)


## Absolute target, used by the test bots only.
func set_paddle_target(x: float) -> void:
	paddle_target = _clamp_paddle(x)


func _clamp_paddle(x: float) -> float:
	return clampf(x, NbBalance.FIELD_LEFT + paddle_half, NbBalance.FIELD_RIGHT - paddle_half)


## Finger lifted: launches a resting ball (act on release, rule 15).
func release() -> void:
	if state == State.REST:
		launch()


func launch() -> void:
	var deg: float = rng.randf_range(NbBalance.LAUNCH_DEG_MIN, NbBalance.LAUNCH_DEG_MAX)
	if rng.randf() < 0.5:
		deg = -deg
	var a: float = deg_to_rad(deg)
	ball_vel = Vector2(sin(a), -cos(a)) * speed()
	state = State.PLAY
	_ramp_t = 0.0
	_last_break_t = time
	_next_dry_t = time + NbBalance.DRY_SPELL_S
	_loop_records.clear()
	launched.emit()


func step(delta: float) -> void:
	time += delta
	_move_paddle(delta)
	match state:
		State.REST:
			_rest_t += delta
			ball_pos = Vector2(paddle_x, paddle_top() - NbBalance.BALL_RADIUS)
			if _rest_t >= NbBalance.AUTO_LAUNCH_S:
				launch()
		State.PLAY, State.CLEAR:
			_ramp_t += delta
			_move_ball(delta)
			if state == State.PLAY:
				_anti_stuck()
				_komet_tick(delta)
		State.RESTART:
			_restart_tick(delta)
	if state != State.RESTART:
		_capsules_tick(delta)


func _move_paddle(delta: float) -> void:
	var prev: float = paddle_x
	var max_move: float = NbBalance.PADDLE_MAX_SPEED * delta
	paddle_x = _clamp_paddle(paddle_x + clampf(paddle_target - paddle_x, -max_move, max_move))
	paddle_vx = (paddle_x - prev) / delta if delta > 0.0 else 0.0


# ---------------------------------------------------------------- ball


func _move_ball(delta: float) -> void:
	var sp: float = speed()
	if ball_vel.length() < 0.001:
		ball_vel = Vector2(0.3, -1.0)
	ball_vel = ball_vel.normalized() * sp
	var steps: int = maxi(1, ceili(sp * delta / NbBalance.SUBSTEP_MAX_PX))
	var dt: float = delta / float(steps)
	for i: int in steps:
		_substep(dt)
		if state == State.RESTART:
			return
	_flat_floor()


func _substep(dt: float) -> void:
	var r: float = NbBalance.BALL_RADIUS
	var chrome: bool = false
	# X axis
	ball_pos.x += ball_vel.x * dt
	var hit: int = _hit_bricks()
	if hit & 1:
		ball_pos.x -= ball_vel.x * dt
		ball_vel.x = -ball_vel.x
	chrome = chrome or (hit & 2) != 0
	if ball_pos.x - r < NbBalance.FIELD_LEFT:
		ball_pos.x = NbBalance.FIELD_LEFT + r
		ball_vel.x = absf(ball_vel.x)
		_on_wall(0)
	elif ball_pos.x + r > NbBalance.FIELD_RIGHT:
		ball_pos.x = NbBalance.FIELD_RIGHT - r
		ball_vel.x = -absf(ball_vel.x)
		_on_wall(1)
	# Y axis
	ball_pos.y += ball_vel.y * dt
	hit = _hit_bricks()
	if hit & 1:
		ball_pos.y -= ball_vel.y * dt
		ball_vel.y = -ball_vel.y
	chrome = chrome or (hit & 2) != 0
	if ball_pos.y - r < NbBalance.FIELD_TOP:
		ball_pos.y = NbBalance.FIELD_TOP + r
		ball_vel.y = absf(ball_vel.y)
		_on_wall(2)
	if chrome:
		_rotate(rng.randf_range(-NbBalance.CHROME_JITTER_DEG, NbBalance.CHROME_JITTER_DEG))
		_record_loop()
	_push_out()
	_paddle_contact()
	_net_and_loss()


## Every alive brick the ball overlaps takes one hit. Returns bit 1 when the
## ball must reflect (solid hit) and bit 2 when chrome was involved.
func _hit_bricks() -> int:
	var out: int = 0
	var any_break: bool = false
	for i: int in bricks.size():
		var b: Brick = bricks[i]
		if not b.alive or not _overlaps(b.rect):
			continue
		if not b.breakable():
			out |= 3
			chrome_hit.emit(i, ball_pos)
			continue
		any_break = true
		if komet_active():
			komet_left -= 1
			if komet_left <= 0:
				_end_komet()
			_break(i)
			continue
		out |= 1
		b.hp -= 1
		if b.hp <= 0:
			_break(i)
		else:
			brick_hit.emit(i)
	if any_break:
		_progress()
	return out


func _overlaps(rect: Rect2) -> bool:
	var cx: float = clampf(ball_pos.x, rect.position.x, rect.end.x)
	var cy: float = clampf(ball_pos.y, rect.position.y, rect.end.y)
	var dx: float = ball_pos.x - cx
	var dy: float = ball_pos.y - cy
	return dx * dx + dy * dy < NbBalance.BALL_RADIUS * NbBalance.BALL_RADIUS


func _break(i: int) -> void:
	var b: Brick = bricks[i]
	b.alive = false
	b.hp = 0
	breakable_left -= 1
	_last_break_t = time
	if assist_on:
		assist_on = false
		assist_index = -1
	note_step = mini(note_step + 1, NbBalance.NOTE_STEPS_MAX)
	if b.carrier and level.get("carrier_powerup", "") != "":
		_spawn_capsule(b.center(), String(level["carrier_powerup"]))
	var last: bool = breakable_left <= 0
	brick_broken.emit(i, last)
	if last and state == State.PLAY:
		state = State.CLEAR
		_end_komet()
		level_cleared.emit(b.center())


## Corner case (GDD 4.4): still inside a solid brick after a step: push out
## along the shortest axis and flip that velocity component.
func _push_out() -> void:
	for b: Brick in bricks:
		if not b.alive or not _overlaps(b.rect):
			continue
		if b.breakable() and komet_active():
			continue
		var r: float = NbBalance.BALL_RADIUS
		var left: float = ball_pos.x + r - b.rect.position.x
		var right: float = b.rect.end.x - (ball_pos.x - r)
		var up: float = ball_pos.y + r - b.rect.position.y
		var down: float = b.rect.end.y - (ball_pos.y - r)
		var m: float = minf(minf(left, right), minf(up, down))
		if m == left:
			ball_pos.x -= left
			ball_vel.x = -absf(ball_vel.x)
		elif m == right:
			ball_pos.x += right
			ball_vel.x = absf(ball_vel.x)
		elif m == up:
			ball_pos.y -= up
			ball_vel.y = -absf(ball_vel.y)
		else:
			ball_pos.y += down
			ball_vel.y = absf(ball_vel.y)


func _paddle_contact() -> void:
	if ball_vel.y <= 0.0:
		return
	var bottom: float = ball_pos.y + NbBalance.BALL_RADIUS
	var top: float = paddle_top()
	if (
		bottom < top - NbBalance.PADDLE_CONTACT_ABOVE
		or bottom > top + NbBalance.PADDLE_CONTACT_BELOW
	):
		return
	var reach: float = paddle_half + NbBalance.edge_grace(easy)
	if absf(ball_pos.x - paddle_x) > reach:
		return
	var sp: float = speed()
	var rel: float = clampf((ball_pos.x - paddle_x) / reach, -1.0, 1.0)
	var max_deg: float = NbBalance.max_bounce_deg(easy)
	if assist_on:
		var t: int = _nearest_solid_brick(ball_pos)
		assist_on = false
		assist_index = -1
		_last_break_t = time
		if t >= 0:
			var to: Vector2 = bricks[t].center() - ball_pos
			var a: float = clampf(atan2(to.x, -to.y), -deg_to_rad(max_deg), deg_to_rad(max_deg))
			ball_vel = Vector2(sin(a), -cos(a)) * sp
		else:
			_paddle_angle(rel, max_deg, sp)
	else:
		_paddle_angle(rel, max_deg, sp)
	ball_pos.y = top - NbBalance.PADDLE_CONTACT_ABOVE - NbBalance.BALL_RADIUS
	note_step = 0
	_loop_records.clear()
	_progress()
	paddle_hit.emit(ball_pos, rel)


func _paddle_angle(rel: float, max_deg: float, sp: float) -> void:
	var a: float = deg_to_rad(rel * max_deg)
	ball_vel = Vector2(sin(a), -cos(a)) * sp
	ball_vel.x += paddle_vx * NbBalance.english(easy)
	ball_vel = ball_vel.normalized() * sp
	if ball_vel.y > -0.01 * sp:
		ball_vel.y = -0.01 * sp
	_min_side()


func _net_and_loss() -> void:
	if ball_vel.y > 0.0 and ball_pos.y + NbBalance.BALL_RADIUS >= NbBalance.NET_Y and net_active():
		ball_pos.y = NbBalance.NET_Y - NbBalance.BALL_RADIUS
		ball_vel.y = -absf(ball_vel.y)
		_min_side()
		_ramp_t = 0.0
		net_catches += 1
		if not net_unlimited and state == State.PLAY:
			net_charges -= 1
		net_caught.emit(ball_pos, net_charges)
		return
	if ball_pos.y > NbBalance.LOSS_Y and state == State.PLAY:
		_begin_restart()


## GDD 4.3: |v.x| >= sin(6 deg) * speed after paddle and net bounces; a
## near-centre hit leans toward the side with more bricks left.
func _min_side() -> void:
	var sp: float = ball_vel.length()
	var m: float = sin(deg_to_rad(NbBalance.MIN_SIDE_DEG)) * sp
	if absf(ball_vel.x) >= m:
		return
	var side: int = _more_bricks_side()
	if side == 0:
		side = 1 if rng.randf() < 0.5 else -1
	var vy_sign: float = -1.0 if ball_vel.y < 0.0 else 1.0
	ball_vel = Vector2(m * side, vy_sign * sqrt(sp * sp - m * m))


## Anti-stuck rule 1: no ball travels flatter than 20 degrees.
func _flat_floor() -> void:
	var sp: float = ball_vel.length()
	var m: float = sin(deg_to_rad(NbBalance.MIN_FLAT_DEG)) * sp
	if absf(ball_vel.y) >= m:
		return
	var vy_sign: float = 1.0 if ball_vel.y > 0.0 else -1.0
	var vx_sign: float = -1.0 if ball_vel.x < 0.0 else 1.0
	ball_vel = Vector2(vx_sign * sqrt(sp * sp - m * m), vy_sign * m)


func _rotate(deg: float) -> void:
	ball_vel = ball_vel.rotated(deg_to_rad(deg))


func _more_bricks_side() -> int:
	var left: int = 0
	var right: int = 0
	for b: Brick in bricks:
		if b.alive and b.breakable():
			if b.center().x < ball_pos.x:
				left += 1
			elif b.center().x > ball_pos.x:
				right += 1
	if right > left:
		return 1
	if left > right:
		return -1
	return 0


func _on_wall(side: int) -> void:
	wall_hit.emit(side, ball_pos)
	_record_loop()


## A paddle touch or a breakable brick hit resets the dry-spell clock.
func _progress() -> void:
	_next_dry_t = time + NbBalance.DRY_SPELL_S


# ---------------------------------------------------------------- anti-stuck


func _record_loop() -> void:
	var oct: int = int(floor((ball_vel.angle() + PI) / (PI / 4.0))) % 8
	var key: String = (
		"%d_%d_%d"
		% [
			roundi(ball_pos.x / NbBalance.LOOP_CELL_PX),
			roundi(ball_pos.y / NbBalance.LOOP_CELL_PX),
			oct
		]
	)
	var kept: Array = []
	var same: int = 0
	for rec: Array in _loop_records:
		if time - float(rec[1]) <= NbBalance.LOOP_WINDOW_S:
			kept.append(rec)
			if rec[0] == key:
				same += 1
	kept.append([key, time])
	_loop_records = kept
	if same + 1 >= NbBalance.LOOP_REPEATS:
		_loop_records.clear()
		_nudge()


func _nudge() -> void:
	var side: int = _more_bricks_side()
	if side == 0:
		side = 1 if rng.randf() < 0.5 else -1
	var a: Vector2 = ball_vel.rotated(deg_to_rad(NbBalance.NUDGE_DEG))
	var b: Vector2 = ball_vel.rotated(deg_to_rad(-NbBalance.NUDGE_DEG))
	ball_vel = a if a.x * side >= b.x * side else b
	_flat_floor()
	nudged.emit(ball_pos)


func _anti_stuck() -> void:
	if time >= _next_dry_t:
		_nudge()
		_next_dry_t = time + NbBalance.DRY_REPEAT_S
	if not assist_on and time - _last_break_t >= NbBalance.assist_s(easy):
		var t: int = _nearest_solid_brick(Vector2(paddle_x, paddle_top()))
		if t >= 0:
			assist_on = true
			assist_index = t
			assist_armed.emit(t)
	# Safety respawn (rule 6)
	var bad: bool = is_nan(ball_pos.x) or is_nan(ball_pos.y) or is_nan(ball_vel.x)
	var o: float = NbBalance.RESPAWN_OUTSIDE_PX
	if (
		bad
		or ball_pos.x < NbBalance.FIELD_LEFT - o
		or ball_pos.x > NbBalance.FIELD_RIGHT + o
		or ball_pos.y < NbBalance.FIELD_TOP - o
	):
		_to_rest()


func _nearest_solid_brick(from: Vector2) -> int:
	var best: int = -1
	var best_d: float = INF
	for i: int in bricks.size():
		var b: Brick = bricks[i]
		if not b.alive or not b.breakable():
			continue
		var d: float = from.distance_squared_to(b.center())
		if d < best_d:
			best_d = d
			best = i
	return best


# ---------------------------------------------------------------- capsules


func _spawn_capsule(at: Vector2, kind: String) -> void:
	var alive: int = 0
	for c: Capsule in capsules:
		if c.alive:
			alive += 1
	if alive >= NbBalance.CAPSULE_MAX:
		return
	var c := Capsule.new()
	c.pos = at
	c.kind = kind
	capsules.append(c)
	capsule_spawned.emit(c)


func _capsules_tick(delta: float) -> void:
	if capsules.is_empty():
		return
	var fall: float = NbBalance.capsule_fall(easy)
	var pad := Rect2(
		paddle_x - paddle_half,
		NbBalance.PADDLE_Y - NbBalance.PADDLE_H * 0.5,
		paddle_half * 2.0,
		NbBalance.PADDLE_H
	)
	pad = pad.grow(NbBalance.CAPSULE_CATCH_GROW)
	var keep: Array[Capsule] = []
	for c: Capsule in capsules:
		c.age += delta
		c.pos.y += fall * delta
		if easy and c.pos.y > NbBalance.CAPSULE_MAGNET_Y:
			var mv: float = NbBalance.CAPSULE_MAGNET_SPEED * delta
			c.pos.x += clampf(paddle_x - c.pos.x, -mv, mv)
		var rect := Rect2(
			c.pos - Vector2(NbBalance.CAPSULE_W, NbBalance.CAPSULE_H) * 0.5,
			Vector2(NbBalance.CAPSULE_W, NbBalance.CAPSULE_H)
		)
		if rect.intersects(pad):
			c.alive = false
			_apply_powerup(c.kind)
			capsule_caught.emit(c.kind, c.pos)
		elif c.pos.y >= NbBalance.CAPSULE_FADE_Y:
			c.alive = false
			capsule_missed.emit(c)
		else:
			keep.append(c)
	capsules = keep


func _apply_powerup(kind: String) -> void:
	if kind == "komet":
		komet_left = NbBalance.komet_bricks(easy)
		komet_t = NbBalance.komet_s(easy)
		komet_changed.emit(true)


func _komet_tick(delta: float) -> void:
	if komet_left <= 0:
		return
	komet_t -= delta
	if komet_t <= 0.0:
		_end_komet()


func _end_komet() -> void:
	var was: bool = komet_left > 0 or komet_t > 0.0
	komet_left = 0
	komet_t = 0.0
	if was:
		komet_changed.emit(false)


# ---------------------------------------------------------------- rest / restart


func _to_rest() -> void:
	state = State.REST
	_rest_t = 0.0
	ball_visible = true
	ball_vel = Vector2.ZERO
	ball_pos = Vector2(paddle_x, paddle_top() - NbBalance.BALL_RADIUS)
	note_step = 0
	assist_on = false
	assist_index = -1
	_loop_records.clear()


## GDD 4.6 gentle restart: dim 0.6 s, bricks float back 0.8 s, net refills,
## ball rests on the paddle, dim lifts 0.4 s. No text, no failure sound.
func _begin_restart() -> void:
	state = State.RESTART
	_restart_t = 0.0
	_restored = false
	_refilled = false
	ball_visible = false
	restart_count += 1
	for c: Capsule in capsules:
		c.alive = false
	capsules.clear()
	_end_komet()
	restart_started.emit()


func _restart_tick(delta: float) -> void:
	_restart_t += delta
	if not _restored and _restart_t >= NbBalance.RESTART_DIM_S:
		_restored = true
		var idx := PackedInt32Array()
		breakable_left = 0
		for i: int in bricks.size():
			var b: Brick = bricks[i]
			if not b.alive or b.hp != b.max_hp:
				idx.append(i)
			b.alive = true
			b.hp = b.max_hp
			if b.breakable():
				breakable_left += 1
		bricks_restored.emit(idx)
	if not _refilled and _restart_t >= NbBalance.RESTART_DIM_S + NbBalance.RESTART_REWIND_S:
		_refilled = true
		net_charges = NbBalance.NET_CHARGES
		ball_visible = true
		ball_pos = Vector2(paddle_x, paddle_top() - NbBalance.BALL_RADIUS)
	else:
		ball_pos = Vector2(paddle_x, paddle_top() - NbBalance.BALL_RADIUS)
	if (
		_restart_t
		>= NbBalance.RESTART_DIM_S + NbBalance.RESTART_REWIND_S + NbBalance.RESTART_LIFT_S
	):
		_to_rest()
		restart_finished.emit()


## 0..1 share of the 60% dim during a restart.
func restart_dim() -> float:
	if state != State.RESTART:
		return 0.0
	var d: float = NbBalance.RESTART_DIM_S
	var w: float = NbBalance.RESTART_REWIND_S
	if _restart_t < d:
		return _restart_t / d
	if _restart_t < d + w:
		return 1.0
	return clampf(1.0 - (_restart_t - d - w) / NbBalance.RESTART_LIFT_S, 0.0, 1.0)


## 0..1 progress of the bricks floating back (1 = in place).
func restart_float() -> float:
	if state != State.RESTART or not _restored:
		return 1.0
	return clampf((_restart_t - NbBalance.RESTART_DIM_S) / NbBalance.RESTART_REWIND_S, 0.0, 1.0)


func restart_elapsed() -> float:
	return _restart_t if state == State.RESTART else 0.0
