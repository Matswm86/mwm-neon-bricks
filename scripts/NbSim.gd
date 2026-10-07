class_name NbSim
extends RefCounted

## Pure game logic of one level in logic px (GDD sections 4, 5 and 15):
## paddle, up to 3 balls (main + Ekko echoes), bricks incl. Triple, Nova,
## Glider, mini-boss and the march block, capsules (Komet, Ekko, Bredvinge,
## Neonpuls), the combo meter, net, anti-stuck rules, line-of-sight aim
## (assist + finale) and the gentle restart. No nodes, no rendering: NbPlay
## drives it, NbWorld draws it, and tests run it headless.

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
# Action pass (GDD 15)
signal combo_stepped(combo: int, pos: Vector2)
signal combo_dropped(from_combo: int)
signal chain_burst
signal nova_blasted(pos: Vector2)
signal echo_split(pos: Vector2)
signal boss_hit(index: int, pos: Vector2)
signal boss_phase_changed(index: int, phase: int)
signal boss_defeated(index: int, pos: Vector2)
signal minions_added(indices: PackedInt32Array)
signal march_stepped(dir: int)
signal finale_started
signal pulse_fired(x_lo: float, x_hi: float)
signal wide_changed(active: bool)

enum State { REST, PLAY, RESTART, CLEAR }


class Brick:
	var row: int = 0
	var col: int = 0
	var code: String = "G"
	var carrier: bool = false
	## Power-up this carrier drops ("" = none).
	var carry: String = ""
	var max_hp: int = 1
	var hp: int = 1
	var alive: bool = true
	var rect: Rect2 = Rect2()
	## Start rect; march pieces sit at home + march offset.
	var home: Rect2 = Rect2()
	var vx: float = 0.0
	var home_vx: float = 0.0
	var boss: bool = false
	var march: bool = false
	var minion: bool = false
	var born_t: float = -99.0
	var color: Color = Color(1, 1, 1)

	func breakable() -> bool:
		return max_hp > 0

	func center() -> Vector2:
		return rect.get_center()


class Ball:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var echo: bool = false
	var life: float = 0.0


class Capsule:
	var pos: Vector2 = Vector2.ZERO
	var kind: String = "komet"
	var age: float = 0.0
	var alive: bool = true
	## Spawned by the combo meter or a boss phase (pops out with a ring).
	var bonus: bool = false


var level: Dictionary = {}
var easy: bool = true
var state: State = State.REST
var time: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var bricks: Array[Brick] = []
var breakable_left: int = 0
var start_breakable: int = 0
## Breakable bricks at level start plus minions spawned (progress ramp).
var total_breakable: int = 0
var capsules: Array[Capsule] = []

## balls[0] is always the main ball; the rest are Ekko echoes.
var balls: Array[Ball] = []
## Bumped when an echo takes over as the main ball (the trail restarts).
var main_serial: int = 0
var ball_visible: bool = true
var base_speed: float = 520.0

var paddle_x: float = 540.0
var paddle_target: float = 540.0
var paddle_vx: float = 0.0
var paddle_half: float = 200.0
var paddle_half_base: float = 200.0

var net_unlimited: bool = true
var net_charges: int = 0
var net_catches: int = 0

var komet_left: int = 0
var komet_t: float = 0.0
var wide_t: float = 0.0
var pulse_left: int = 0

var combo: int = 0
var max_combo: int = 0
var finale_on: bool = false
var boss_index: int = -1
var boss_phase: int = 0
var march_on: bool = false
var march_dir: int = 1
var march_off: Vector2 = Vector2.ZERO
var march_floor: float = NbBalance.MARCH_FLOOR_MAX_Y
## Brick the last aim_point() call picked (-1 = none).
var aim_index: int = -1

var restart_count: int = 0
var assist_on: bool = false
var assist_index: int = -1

var ball_pos: Vector2:
	get:
		return balls[0].pos
	set(value):
		balls[0].pos = value

var ball_vel: Vector2:
	get:
		return balls[0].vel
	set(value):
		balls[0].vel = value

var _carriers: Array[String] = []
var _bonus: Array[String] = []
var _bonus_i: int = 0
var _minion_color: Color = Color(1, 1, 1)
var _rest_t: float = 0.0
var _last_break_t: float = 0.0
var _next_dry_t: float = 0.0
var _loop_records: Array = []
var _restart_t: float = 0.0
var _restored: bool = false
var _refilled: bool = false
var _combo_t: float = -99.0
var _break_times: PackedFloat32Array = PackedFloat32Array()
var _chain_ready_t: float = 0.0
## Pending Nova blasts: [due time, centre].
var _novas: Array = []
var _pulse_next_t: float = 0.0
var _home_target: Vector2 = Vector2.INF
var _home_retarget_t: float = 0.0
var _march_drop_left: float = 0.0
var _promote: bool = false


func _init() -> void:
	balls.append(Ball.new())


## Builds the level. force_charged_net is the test-only flag (GDD 12): the
## 3-charge net and gentle restart on a level whose net is unlimited.
func setup(lv: Dictionary, is_easy: bool, force_charged_net: bool = false) -> void:
	level = lv
	easy = is_easy
	base_speed = float(lv["lett_speed"]) if easy else float(lv["vanlig_speed"])
	paddle_half_base = NbBalance.paddle_w(easy, float(lv["vanlig_paddle"])) * 0.5
	paddle_half = paddle_half_base
	var vnet: int = int(lv["vanlig_net"])
	net_unlimited = easy or vnet == 0
	net_charges = 0 if net_unlimited else vnet
	if force_charged_net:
		net_unlimited = false
		net_charges = NbBalance.NET_CHARGES
	_carriers = NbLevels.carriers(lv)
	_bonus = NbLevels.bonus_pool(lv)
	_build_bricks()
	paddle_x = 540.0
	paddle_target = 540.0
	time = 0.0
	restart_count = 0
	_reset_round()
	_to_rest()


func _build_bricks() -> void:
	bricks.clear()
	breakable_left = 0
	boss_index = -1
	var rows: Array = level["rows"]
	var world: int = int(level.get("world", 1))
	var colors: Dictionary = NbLevels.row_colors(rows, world)
	var ramp: Array = NbLevels.RAMPS[clampi(world - 1, 0, NbLevels.RAMPS.size() - 1)]
	_minion_color = ramp[1]
	var march: Dictionary = level.get("march", {})
	march_on = not march.is_empty()
	var m_rows: Array = march.get("rows", [-1, -1])
	march_floor = minf(float(march.get("floor_y", 1000.0)), NbBalance.MARCH_FLOOR_MAX_Y)
	var boss_cfg: Dictionary = level.get("boss", {})
	var pick: int = 0 if easy else 1
	var ci: int = 0
	for r: int in rows.size():
		var s: String = rows[r]
		for c: int in mini(s.length(), NbBalance.GRID_COLS):
			var ch: String = s[c]
			if ch == "." or ch == "+":
				continue
			var b := Brick.new()
			b.row = r
			b.col = c
			b.code = ch.to_upper()
			b.carrier = ch != b.code
			if b.carrier and not _carriers.is_empty():
				b.carry = _carriers[ci % _carriers.size()]
				ci += 1
			var size := Vector2(NbBalance.BRICK_W, NbBalance.BRICK_H)
			match b.code:
				"D":
					b.max_hp = 2
				"T":
					b.max_hp = 3
				"C":
					b.max_hp = -1
				"K":
					b.boss = true
					b.max_hp = int(boss_cfg.get("hp", [10, 14])[pick])
					b.home_vx = float(boss_cfg.get("speed", [60.0, 90.0])[pick])
					size = Vector2(NbBalance.BOSS_W, NbBalance.BOSS_H)
					boss_index = bricks.size()
				"M":
					b.max_hp = 1
					b.home_vx = NbBalance.glider_speed(easy) * (1.0 if c < 5 else -1.0)
				_:
					b.max_hp = 1
			b.hp = b.max_hp
			b.rect = Rect2(_cell_origin(r, c), size)
			b.home = b.rect
			if march_on and r >= int(m_rows[0]) and r <= int(m_rows[1]):
				b.march = true
				b.home_vx = 0.0
			b.vx = b.home_vx
			b.color = NbLevels.cell_color(b.code, colors.get(r, Color(1, 1, 1)))
			bricks.append(b)
			if b.breakable():
				breakable_left += 1
	start_breakable = breakable_left
	total_breakable = breakable_left


func _cell_origin(r: int, c: int) -> Vector2:
	return Vector2(
		NbBalance.GRID_X + NbBalance.CELL_W * c + (NbBalance.CELL_W - NbBalance.BRICK_W) * 0.5,
		NbBalance.GRID_Y + NbBalance.CELL_H * r + (NbBalance.CELL_H - NbBalance.BRICK_H) * 0.5
	)


## Per-round action state; cleared at level start and on a gentle restart.
func _reset_round() -> void:
	combo = 0
	_combo_t = -99.0
	_break_times = PackedFloat32Array()
	_chain_ready_t = 0.0
	_novas.clear()
	pulse_left = 0
	wide_t = 0.0
	paddle_half = paddle_half_base
	finale_on = false
	boss_phase = 0
	_bonus_i = 0
	march_dir = 1
	march_off = Vector2.ZERO
	_march_drop_left = 0.0
	_home_target = Vector2.INF
	_promote = false
	while balls.size() > 1:
		balls.pop_back()
	balls[0].echo = false


func paddle_top() -> float:
	return NbBalance.PADDLE_Y - NbBalance.PADDLE_H * 0.5


## Progress ramp (GDD 15.3.2): +15% by the last brick in Vanlig, no reset
## on net catches; Lett has none.
func ramp() -> float:
	if total_breakable <= 0:
		return 1.0
	var broken: float = float(total_breakable - breakable_left) / float(total_breakable)
	return 1.0 + NbBalance.ramp_progress(easy) * clampf(broken, 0.0, 1.0)


func speed() -> float:
	return clampf(base_speed * ramp(), NbBalance.BALL_SPEED_MIN, NbBalance.BALL_SPEED_MAX)


func net_active() -> bool:
	return net_unlimited or net_charges > 0 or state == State.CLEAR


func komet_active() -> bool:
	return komet_left > 0


func echo_count() -> int:
	return balls.size() - 1


## 0 Glød (1-4), 1 Varm (5-9), 2 Neonrush (10+); -1 = no combo.
func combo_tier() -> int:
	if combo >= NbBalance.COMBO_TIER_RUSH:
		return 2
	if combo >= NbBalance.COMBO_TIER_WARM:
		return 1
	return 0 if combo > 0 else -1


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
	balls[0].vel = Vector2(sin(a), -cos(a)) * speed()
	state = State.PLAY
	_last_break_t = time
	_next_dry_t = time + NbBalance.DRY_SPELL_S
	_loop_records.clear()
	launched.emit()


func step(delta: float) -> void:
	time += delta
	_tick_wide(delta)
	_move_paddle(delta)
	match state:
		State.REST:
			_rest_t += delta
			balls[0].pos = Vector2(paddle_x, paddle_top() - NbBalance.BALL_RADIUS)
			_move_balls(delta, false)
			if _rest_t >= NbBalance.AUTO_LAUNCH_S:
				launch()
		State.PLAY, State.CLEAR:
			_move_movers(delta)
			_move_balls(delta, true)
			if state == State.PLAY:
				_tick_novas()
			if state == State.PLAY:
				_tick_pulse()
			if state == State.PLAY:
				_tick_combo()
				_finale_home(delta)
				_anti_stuck()
				_komet_tick(delta)
		State.RESTART:
			_restart_tick(delta)
	if state != State.RESTART:
		_tick_echoes(delta)
		_capsules_tick(delta)


func _move_paddle(delta: float) -> void:
	var prev: float = paddle_x
	var max_move: float = NbBalance.PADDLE_MAX_SPEED * delta
	paddle_target = _clamp_paddle(paddle_target)
	paddle_x = _clamp_paddle(paddle_x + clampf(paddle_target - paddle_x, -max_move, max_move))
	paddle_vx = (paddle_x - prev) / delta if delta > 0.0 else 0.0


## Bredvinge: the paddle grows to x1.5 (Lett x1.3) over 0.3 s and shrinks
## back the same way when the timer runs out.
func _tick_wide(delta: float) -> void:
	if wide_t > 0.0:
		wide_t -= delta
		if wide_t <= 0.0:
			wide_t = 0.0
			wide_changed.emit(false)
	var sc: float = NbBalance.bredvinge_scale(easy)
	var target: float = paddle_half_base
	if wide_t > 0.0:
		target = minf(paddle_half_base * sc, NbBalance.PADDLE_W_MAX * 0.5)
	var rate: float = paddle_half_base * (sc - 1.0) / NbBalance.BREDVINGE_GROW_S
	paddle_half = move_toward(paddle_half, target, rate * delta)


# ---------------------------------------------------------------- balls


func _move_balls(delta: float, with_main: bool) -> void:
	var sp: float = speed()
	var steps: int = maxi(1, ceili(sp * delta / NbBalance.SUBSTEP_MAX_PX))
	var dt: float = delta / float(steps)
	for bi: int in balls.size():
		if bi == 0 and not with_main:
			continue
		var bl: Ball = balls[bi]
		if bl.vel.length() < 0.001:
			bl.vel = Vector2(0.3, -1.0)
		bl.vel = bl.vel.normalized() * sp
		for i: int in steps:
			_substep(bl, dt)
			if state == State.RESTART:
				return
			if bl.echo and bl.life <= 0.0:
				break
		_flat_floor(bl)
	if _promote:
		_promote = false
		_promote_echo()


func _substep(bl: Ball, dt: float) -> void:
	var r: float = NbBalance.BALL_RADIUS
	var chrome: bool = false
	# X axis
	bl.pos.x += bl.vel.x * dt
	var hit: int = _hit_bricks(bl)
	if hit & 1:
		bl.pos.x -= bl.vel.x * dt
		bl.vel.x = -bl.vel.x
	chrome = chrome or (hit & 2) != 0
	if bl.pos.x - r < NbBalance.FIELD_LEFT:
		bl.pos.x = NbBalance.FIELD_LEFT + r
		bl.vel.x = absf(bl.vel.x)
		_on_wall(bl, 0)
	elif bl.pos.x + r > NbBalance.FIELD_RIGHT:
		bl.pos.x = NbBalance.FIELD_RIGHT - r
		bl.vel.x = -absf(bl.vel.x)
		_on_wall(bl, 1)
	# Y axis
	bl.pos.y += bl.vel.y * dt
	hit = _hit_bricks(bl)
	if hit & 1:
		bl.pos.y -= bl.vel.y * dt
		bl.vel.y = -bl.vel.y
	chrome = chrome or (hit & 2) != 0
	if bl.pos.y - r < NbBalance.FIELD_TOP:
		bl.pos.y = NbBalance.FIELD_TOP + r
		bl.vel.y = absf(bl.vel.y)
		_on_wall(bl, 2)
	if chrome:
		bl.vel = bl.vel.rotated(
			deg_to_rad(rng.randf_range(-NbBalance.CHROME_JITTER_DEG, NbBalance.CHROME_JITTER_DEG))
		)
		if not bl.echo:
			_record_loop()
	_push_out(bl)
	_paddle_contact(bl)
	_net_and_loss(bl)


## Every alive brick the ball overlaps takes one hit. Returns bit 1 when the
## ball must reflect (solid hit) and bit 2 when chrome was involved. Komet
## (main ball only) breaks breakable bricks in one hit and passes through;
## against the boss it deals 2 and bounces (GDD 15.3.6).
func _hit_bricks(bl: Ball) -> int:
	var out: int = 0
	var any: bool = false
	var n: int = bricks.size()
	for i: int in n:
		var b: Brick = bricks[i]
		if not b.alive or not _overlaps(bl.pos, b.rect):
			continue
		if not b.breakable():
			out |= 3
			chrome_hit.emit(i, bl.pos)
			continue
		any = true
		if komet_active() and not bl.echo:
			komet_left -= 1
			if b.boss:
				out |= 1
				_damage(i, NbBalance.BOSS_KOMET_DAMAGE, false)
			else:
				_damage(i, b.hp, false)
			if komet_left <= 0:
				_end_komet()
			continue
		out |= 1
		_damage(i, 1, false)
	if any:
		_progress()
	return out


func _overlaps(p: Vector2, rect: Rect2) -> bool:
	var cx: float = clampf(p.x, rect.position.x, rect.end.x)
	var cy: float = clampf(p.y, rect.position.y, rect.end.y)
	var dx: float = p.x - cx
	var dy: float = p.y - cy
	return dx * dx + dy * dy < NbBalance.BALL_RADIUS * NbBalance.BALL_RADIUS


## One hit of n damage on a breakable brick or the boss, from a ball, a Nova
## blast (chained = true) or a Neonpuls wave. Counts for the combo.
func _damage(i: int, n: int, chained: bool) -> void:
	var b: Brick = bricks[i]
	if not b.alive or not b.breakable():
		return
	b.hp -= n
	var at: Vector2 = b.center()
	if b.boss:
		at = Vector2(b.center().x, b.rect.end.y)
	_combo_event(at)
	if b.boss:
		boss_hit.emit(i, at)
		if b.hp > 0:
			_boss_phase_check(i)
	if b.hp <= 0:
		_break(i, chained)
	elif not b.boss:
		brick_hit.emit(i)


func _break(i: int, chained: bool) -> void:
	var b: Brick = bricks[i]
	if not b.alive:
		return
	b.alive = false
	b.hp = 0
	breakable_left -= 1
	_last_break_t = time
	if assist_on:
		assist_on = false
		assist_index = -1
	_note_break_time()
	if b.carry != "":
		_spawn_capsule(b.center(), b.carry, false)
	if b.code == "N":
		var delay: float = NbBalance.NOVA_DELAY_S
		if chained:
			delay += NbBalance.NOVA_CHAIN_DELAY_S
		_novas.append([time + delay, b.center()])
	if b.boss:
		boss_defeated.emit(i, b.center())
	var last: bool = breakable_left <= 0
	brick_broken.emit(i, last)
	if last and state == State.PLAY:
		state = State.CLEAR
		_end_komet()
		_novas.clear()
		pulse_left = 0
		level_cleared.emit(b.center())
	else:
		_update_finale()


## Corner case (GDD 4.4): still inside a solid brick after a step (a glider,
## boss or march block moved into it): push out along the shortest axis and
## flip that velocity component.
func _push_out(bl: Ball) -> void:
	for b: Brick in bricks:
		if not b.alive or not _overlaps(bl.pos, b.rect):
			continue
		if b.breakable() and not b.boss and komet_active() and not bl.echo:
			continue
		var r: float = NbBalance.BALL_RADIUS
		var left: float = bl.pos.x + r - b.rect.position.x
		var right: float = b.rect.end.x - (bl.pos.x - r)
		var up: float = bl.pos.y + r - b.rect.position.y
		var down: float = b.rect.end.y - (bl.pos.y - r)
		var m: float = minf(minf(left, right), minf(up, down))
		if m == left:
			bl.pos.x -= left
			bl.vel.x = -absf(bl.vel.x)
		elif m == right:
			bl.pos.x += right
			bl.vel.x = absf(bl.vel.x)
		elif m == up:
			bl.pos.y -= up
			bl.vel.y = -absf(bl.vel.y)
		else:
			bl.pos.y += down
			bl.vel.y = absf(bl.vel.y)


func _paddle_contact(bl: Ball) -> void:
	if bl.vel.y <= 0.0:
		return
	var bottom: float = bl.pos.y + NbBalance.BALL_RADIUS
	var top: float = paddle_top()
	if (
		bottom < top - NbBalance.PADDLE_CONTACT_ABOVE
		or bottom > top + NbBalance.PADDLE_CONTACT_BELOW
	):
		return
	var reach: float = paddle_half + NbBalance.edge_grace(easy)
	if absf(bl.pos.x - paddle_x) > reach:
		return
	var sp: float = speed()
	var rel: float = clampf((bl.pos.x - paddle_x) / reach, -1.0, 1.0)
	var max_deg: float = NbBalance.max_bounce_deg(easy)
	var aimed: bool = false
	if not bl.echo and (assist_on or finale_on):
		var tgt: Vector2 = aim_point(bl.pos, false)
		if assist_on:
			assist_on = false
			assist_index = -1
			_last_break_t = time
		if tgt.is_finite():
			var to: Vector2 = tgt - bl.pos
			var lim: float = deg_to_rad(max_deg)
			var a: float = clampf(atan2(to.x, -to.y), -lim, lim)
			bl.vel = Vector2(sin(a), -cos(a)) * sp
			_min_side(bl)
			aimed = true
	if not aimed:
		_paddle_angle(bl, rel, max_deg, sp)
	bl.pos.y = top - NbBalance.PADDLE_CONTACT_ABOVE - NbBalance.BALL_RADIUS
	if not bl.echo:
		_loop_records.clear()
		_progress()
	paddle_hit.emit(bl.pos, rel)


func _paddle_angle(bl: Ball, rel: float, max_deg: float, sp: float) -> void:
	var a: float = deg_to_rad(rel * max_deg)
	bl.vel = Vector2(sin(a), -cos(a)) * sp
	bl.vel.x += paddle_vx * NbBalance.english(easy)
	bl.vel = bl.vel.normalized() * sp
	if bl.vel.y > -0.01 * sp:
		bl.vel.y = -0.01 * sp
	_min_side(bl)


## Net (GDD 4.6). Echo balls never touch the net: they dissolve at it and
## never spend a charge. A main-ball catch spends a charge only when no echo
## is in play. A main ball lost past an empty net hands over to the oldest
## echo; with no echo the gentle restart begins.
func _net_and_loss(bl: Ball) -> void:
	var at_net: bool = bl.vel.y > 0.0 and bl.pos.y + NbBalance.BALL_RADIUS >= NbBalance.NET_Y
	if bl.echo:
		if at_net:
			bl.life = 0.0
		return
	if at_net and net_active():
		bl.pos.y = NbBalance.NET_Y - NbBalance.BALL_RADIUS
		bl.vel.y = -absf(bl.vel.y)
		_min_side(bl)
		net_catches += 1
		if not net_unlimited and state == State.PLAY and echo_count() == 0:
			net_charges -= 1
		net_caught.emit(bl.pos, net_charges)
		return
	if bl.pos.y > NbBalance.LOSS_Y and state == State.PLAY:
		if _alive_echoes() > 0:
			_promote = true
		else:
			_begin_restart()


func _alive_echoes() -> int:
	var n: int = 0
	for i: int in range(1, balls.size()):
		if balls[i].life > 0.0:
			n += 1
	return n


func _promote_echo() -> void:
	var best: int = -1
	for i: int in range(1, balls.size()):
		if balls[i].life > 0.0:
			best = i
			break
	if best < 0:
		_begin_restart()
		return
	var e: Ball = balls[best]
	e.echo = false
	e.life = 0.0
	balls.remove_at(best)
	balls[0] = e
	main_serial += 1
	_loop_records.clear()


## GDD 4.3: |v.x| >= sin(6 deg) * speed after paddle and net bounces; a
## near-centre hit leans toward the side with more bricks left.
func _min_side(bl: Ball) -> void:
	var sp: float = bl.vel.length()
	var m: float = sin(deg_to_rad(NbBalance.MIN_SIDE_DEG)) * sp
	if absf(bl.vel.x) >= m:
		return
	var side: int = _more_bricks_side(bl.pos.x)
	if side == 0:
		side = 1 if rng.randf() < 0.5 else -1
	var vy_sign: float = -1.0 if bl.vel.y < 0.0 else 1.0
	bl.vel = Vector2(m * side, vy_sign * sqrt(sp * sp - m * m))


## Anti-stuck rule 1: no ball travels flatter than 20 degrees.
func _flat_floor(bl: Ball) -> void:
	var sp: float = bl.vel.length()
	var m: float = sin(deg_to_rad(NbBalance.MIN_FLAT_DEG)) * sp
	if absf(bl.vel.y) >= m:
		return
	var vy_sign: float = 1.0 if bl.vel.y > 0.0 else -1.0
	var vx_sign: float = -1.0 if bl.vel.x < 0.0 else 1.0
	bl.vel = Vector2(vx_sign * sqrt(sp * sp - m * m), vy_sign * m)


func _more_bricks_side(x: float) -> int:
	var left: int = 0
	var right: int = 0
	for b: Brick in bricks:
		if b.alive and b.breakable():
			if b.center().x < x:
				left += 1
			elif b.center().x > x:
				right += 1
	if right > left:
		return 1
	if left > right:
		return -1
	return 0


func _on_wall(bl: Ball, side: int) -> void:
	wall_hit.emit(side, bl.pos)
	if not bl.echo:
		_record_loop()


## A paddle touch or a breakable brick hit resets the dry-spell clock.
func _progress() -> void:
	_next_dry_t = time + NbBalance.DRY_SPELL_S


# ---------------------------------------------------------------- combo


## GDD 15.3.1: +1 per break or boss hit inside the window; a capsule from
## the bonus pool every COMBO_DROP_EVERY steps (skipped over the cap).
func _combo_event(at: Vector2) -> void:
	if combo > 0 and time - _combo_t <= NbBalance.combo_window_s(easy):
		combo += 1
	else:
		combo = 1
	_combo_t = time
	max_combo = maxi(max_combo, combo)
	combo_stepped.emit(combo, at)
	if not _bonus.is_empty() and combo % NbBalance.combo_drop_every(easy) == 0:
		if _spawn_capsule(at, _bonus[_bonus_i % _bonus.size()], true) != null:
			_bonus_i += 1


func _tick_combo() -> void:
	if combo > 0 and time - _combo_t > NbBalance.combo_window_s(easy):
		var was: int = combo
		combo = 0
		combo_dropped.emit(was)


## Chain slow-mo trigger: 4 breaks inside 0.4 s of game time, 3 s cooldown,
## never on the last brick (that has its own slow-mo).
func _note_break_time() -> void:
	_break_times.append(time)
	if _break_times.size() > NbBalance.CHAIN_SLOWMO_BREAKS:
		_break_times.remove_at(0)
	if (
		_break_times.size() == NbBalance.CHAIN_SLOWMO_BREAKS
		and time - _break_times[0] <= NbBalance.CHAIN_SLOWMO_WINDOW_S
		and time >= _chain_ready_t
		and breakable_left > 0
	):
		_chain_ready_t = time + NbBalance.CHAIN_SLOWMO_COOLDOWN_S
		chain_burst.emit()


# ---------------------------------------------------------------- nova / pulse


func _tick_novas() -> void:
	var i: int = 0
	while i < _novas.size() and state == State.PLAY:
		var nv: Array = _novas[i]
		if time >= float(nv[0]):
			_novas.remove_at(i)
			_nova_blast(nv[1])
		else:
			i += 1


## GDD 15.3.5: 1 hit to every alive breakable piece (boss included) whose
## rect meets the 300 x 156 blast rect around the Nova.
func _nova_blast(at: Vector2) -> void:
	var blast := Rect2(
		at - Vector2(NbBalance.NOVA_BLAST_W, NbBalance.NOVA_BLAST_H) * 0.5,
		Vector2(NbBalance.NOVA_BLAST_W, NbBalance.NOVA_BLAST_H)
	)
	nova_blasted.emit(at)
	var n: int = bricks.size()
	for j: int in n:
		var b: Brick = bricks[j]
		if b.alive and b.breakable() and b.rect.intersects(blast):
			_damage(j, 1, true)
			if state != State.PLAY:
				return


func _tick_pulse() -> void:
	if pulse_left <= 0 or time < _pulse_next_t:
		return
	pulse_left -= 1
	_pulse_next_t += NbBalance.NEONPULS_INTERVAL_S
	_pulse_wave()


## Neonpuls wave: 1 hit to the lowest breakable piece in every grid column
## the paddle overlaps (each piece at most once per wave).
func _pulse_wave() -> void:
	var lo: float = paddle_x - paddle_half
	var hi: float = paddle_x + paddle_half
	var targets := PackedInt32Array()
	for c: int in NbBalance.GRID_COLS:
		var cx0: float = NbBalance.GRID_X + NbBalance.CELL_W * c
		var cx1: float = cx0 + NbBalance.CELL_W
		if cx1 < lo or cx0 > hi:
			continue
		var best: int = -1
		var best_y: float = -INF
		for j: int in bricks.size():
			var b: Brick = bricks[j]
			if not b.alive or not b.breakable():
				continue
			if b.rect.position.x < cx1 and b.rect.end.x > cx0 and b.rect.end.y > best_y:
				best_y = b.rect.end.y
				best = j
		if best >= 0 and not targets.has(best):
			targets.append(best)
	pulse_fired.emit(lo, hi)
	for j: int in targets:
		_damage(j, 1, false)
		if state != State.PLAY:
			return


# ---------------------------------------------------------------- boss


func _boss_phase_check(i: int) -> void:
	var b: Brick = bricks[i]
	var want: int = 0
	if b.hp <= floori(2.0 * b.max_hp / 3.0):
		want = 1
	if b.hp <= floori(b.max_hp / 3.0):
		want = 2
	while boss_phase < want:
		boss_phase += 1
		b.vx *= NbBalance.BOSS_PHASE_SPEEDUP
		var at := Vector2(b.center().x, b.rect.end.y)
		if not _bonus.is_empty():
			if _spawn_capsule(at, _bonus[_bonus_i % _bonus.size()], true) != null:
				_bonus_i += 1
		if bool(level.get("boss", {}).get("minions", false)):
			_spawn_minions(i)
		boss_phase_changed.emit(i, boss_phase)


## Up to 4 Glass minions in the empty cells of the grid row under the boss,
## columns (boss column - 1) to (boss column + 3); in a march level they join
## the block at its current offset (GDD 15.3.6).
func _spawn_minions(bi: int) -> void:
	var b: Brick = bricks[bi]
	var off: Vector2 = march_off if b.march else Vector2.ZERO
	var row: int = floori((b.rect.end.y - off.y - NbBalance.GRID_Y) / NbBalance.CELL_H) + 1
	if row >= NbBalance.GRID_ROWS:
		return
	var col: int = floori((b.rect.position.x - off.x - NbBalance.GRID_X) / NbBalance.CELL_W)
	var added := PackedInt32Array()
	for c: int in range(maxi(0, col - 1), mini(NbBalance.GRID_COLS, col + 4)):
		if added.size() >= NbBalance.BOSS_MINIONS_MAX:
			break
		var home := Rect2(_cell_origin(row, c), Vector2(NbBalance.BRICK_W, NbBalance.BRICK_H))
		var cell := Rect2(home.position + off, home.size)
		if not _cell_free(cell):
			continue
		var m := Brick.new()
		m.row = row
		m.col = c
		m.code = "G"
		m.max_hp = 1
		m.hp = 1
		m.minion = true
		m.march = b.march
		m.born_t = time
		m.home = home
		m.rect = cell
		m.color = _minion_color
		added.append(bricks.size())
		bricks.append(m)
		breakable_left += 1
		total_breakable += 1
	if not added.is_empty():
		minions_added.emit(added)
		_update_finale()


func _cell_free(cell: Rect2) -> bool:
	for o: Brick in bricks:
		if o.alive and o.rect.intersects(cell):
			return false
	for bl: Ball in balls:
		if _overlaps(bl.pos, cell):
			return false
	for c: Capsule in capsules:
		var cr := Rect2(
			c.pos - Vector2(NbBalance.CAPSULE_W, NbBalance.CAPSULE_H) * 0.5,
			Vector2(NbBalance.CAPSULE_W, NbBalance.CAPSULE_H)
		)
		if c.alive and cr.intersects(cell):
			return false
	return true


# ---------------------------------------------------------------- movers


func _move_movers(delta: float) -> void:
	if march_on:
		_move_march(delta)
	for i: int in bricks.size():
		var b: Brick = bricks[i]
		if not b.alive or b.march or b.vx == 0.0:
			continue
		var dx: float = b.vx * delta
		b.rect.position.x += dx
		if _mover_blocked(i, 1 if b.vx > 0.0 else -1):
			b.rect.position.x -= dx
			b.vx = -b.vx


## Gliders and the gliding boss reverse at the walls and at any piece in
## front of them (only pieces ahead count, so an overlap never jitters).
func _mover_blocked(i: int, dir: int) -> bool:
	var b: Brick = bricks[i]
	var gap: float = NbBalance.MOVER_WALL_GAP
	if b.rect.position.x < NbBalance.FIELD_LEFT + gap:
		return dir < 0
	if b.rect.end.x > NbBalance.FIELD_RIGHT - gap:
		return dir > 0
	var cx: float = b.center().x
	for j: int in bricks.size():
		if j == i:
			continue
		var o: Brick = bricks[j]
		if o.alive and o.rect.intersects(b.rect) and (o.center().x - cx) * dir > 0.0:
			return true
	return false


## GDD 15.3.7: the block slides, reverses when its outermost ALIVE piece
## reaches x 44 / 1036 and then steps down 26 px over 0.25 s unless that
## would pass floor_y. Builder addition: it also reverses at, and never steps
## onto, a piece outside the block (chrome bumpers, gliders, low rows), so
## pieces never overlap.
func _move_march(delta: float) -> void:
	var lo: float = INF
	var hi: float = -INF
	var low: float = -INF
	for b: Brick in bricks:
		if b.alive and b.march:
			lo = minf(lo, b.home.position.x + march_off.x)
			hi = maxf(hi, b.home.end.x + march_off.x)
			low = maxf(low, b.home.end.y + march_off.y)
	if lo == INF:
		return
	var dx: float = float(march_dir) * NbBalance.march_speed(easy) * delta
	var reverse: bool = false
	var gap: float = NbBalance.MARCH_WALL_GAP
	if lo + dx < NbBalance.FIELD_LEFT + gap:
		dx = NbBalance.FIELD_LEFT + gap - lo
		reverse = true
	elif hi + dx > NbBalance.FIELD_RIGHT - gap:
		dx = NbBalance.FIELD_RIGHT - gap - hi
		reverse = true
	elif _march_hits_other(Vector2(dx, 0.0)):
		dx = 0.0
		reverse = true
	march_off.x += dx
	if _march_drop_left > 0.0:
		var dy: float = minf(
			_march_drop_left, NbBalance.MARCH_STEP_PX / NbBalance.MARCH_STEP_S * delta
		)
		march_off.y += dy
		_march_drop_left -= dy
	if reverse:
		march_dir = -march_dir
		if (
			_march_drop_left <= 0.0
			and low + NbBalance.MARCH_STEP_PX <= march_floor
			and not _march_hits_other(Vector2(0.0, NbBalance.MARCH_STEP_PX))
		):
			_march_drop_left = NbBalance.MARCH_STEP_PX
			march_stepped.emit(march_dir)
	for b: Brick in bricks:
		if b.march:
			b.rect.position = b.home.position + march_off


func _march_hits_other(d: Vector2) -> bool:
	for m: Brick in bricks:
		if not m.alive or not m.march:
			continue
		var r := Rect2(m.home.position + march_off + d, m.home.size)
		for o: Brick in bricks:
			if o.alive and not o.march and r.intersects(o.rect):
				return true
	return false


# ---------------------------------------------------------------- aim


## GDD 15.3.4: nearest alive breakable piece whose centre the ball can reach
## in a straight line (only non-breakable pieces block), else a one-wall bank
## shot (aims at the mirrored centre), else INF. Sets aim_index.
func aim_point(from: Vector2, direct_only: bool) -> Vector2:
	aim_index = -1
	var order: Array[Vector2] = []
	var blockers: Array[Rect2] = []
	for i: int in bricks.size():
		var b: Brick = bricks[i]
		if not b.alive:
			continue
		if b.breakable():
			order.append(Vector2(from.distance_squared_to(b.center()), float(i)))
		else:
			blockers.append(b.rect)
	order.sort()
	for o: Vector2 in order:
		var c: Vector2 = bricks[int(o.y)].center()
		if _clear_path(from, c, blockers):
			aim_index = int(o.y)
			return c
	if direct_only:
		return Vector2.INF
	var r: float = NbBalance.BALL_RADIUS
	for o: Vector2 in order:
		var c: Vector2 = bricks[int(o.y)].center()
		for wall: float in [NbBalance.FIELD_LEFT + r, NbBalance.FIELD_RIGHT - r]:
			var mx: float = 2.0 * wall - c.x
			if is_equal_approx(mx, from.x):
				continue
			var k: float = (wall - from.x) / (mx - from.x)
			if k <= 0.0 or k >= 1.0:
				continue
			var wp := Vector2(wall, from.y + (c.y - from.y) * k)
			if _clear_path(from, wp, blockers) and _clear_path(wp, c, blockers):
				aim_index = int(o.y)
				return Vector2(mx, c.y)
	return Vector2.INF


func _clear_path(a: Vector2, b: Vector2, blockers: Array[Rect2]) -> bool:
	if blockers.is_empty():
		return true
	var n: int = maxi(1, int(a.distance_to(b) / NbBalance.AIM_LOS_STEP_PX))
	for k: int in range(1, n + 1):
		var p: Vector2 = a.lerp(b, float(k) / float(n))
		for rect: Rect2 in blockers:
			if _overlaps(p, rect):
				return false
	return true


## GDD 15.3.3 finale helper: on with <= 3 (Lett 4) breakable left, if the
## level started with at least 10.
func _update_finale() -> void:
	var want: bool = (
		start_breakable >= NbBalance.FINALE_MIN_START
		and breakable_left > 0
		and breakable_left <= NbBalance.finale_left(easy)
	)
	if want and not finale_on:
		finale_on = true
		_home_retarget_t = time
		finale_started.emit()
	elif not want:
		finale_on = false


## Finale homing: a rising main ball turns toward the nearest directly
## reachable piece by at most 30 (Lett 40) deg/s; retarget every 0.25 s.
func _finale_home(delta: float) -> void:
	if not finale_on:
		return
	var m: Ball = balls[0]
	if m.vel.y >= 0.0:
		return
	if time >= _home_retarget_t:
		_home_retarget_t = time + NbBalance.FINALE_RETARGET_S
		_home_target = aim_point(m.pos, true)
	if not _home_target.is_finite():
		return
	var want: float = atan2(_home_target.x - m.pos.x, -(_home_target.y - m.pos.y))
	var cur: float = atan2(m.vel.x, -m.vel.y)
	var turn: float = deg_to_rad(NbBalance.finale_turn_deg_s(easy)) * delta
	var a: float = cur + clampf(wrapf(want - cur, -PI, PI), -turn, turn)
	m.vel = Vector2(sin(a), -cos(a)) * m.vel.length()
	_flat_floor(m)


# ---------------------------------------------------------------- anti-stuck


func _record_loop() -> void:
	var v: Vector2 = balls[0].vel
	var p: Vector2 = balls[0].pos
	var oct: int = int(floor((v.angle() + PI) / (PI / 4.0))) % 8
	var key: String = (
		"%d_%d_%d"
		% [roundi(p.x / NbBalance.LOOP_CELL_PX), roundi(p.y / NbBalance.LOOP_CELL_PX), oct]
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
	var m: Ball = balls[0]
	var side: int = _more_bricks_side(m.pos.x)
	if side == 0:
		side = 1 if rng.randf() < 0.5 else -1
	var a: Vector2 = m.vel.rotated(deg_to_rad(NbBalance.NUDGE_DEG))
	var b: Vector2 = m.vel.rotated(deg_to_rad(-NbBalance.NUDGE_DEG))
	m.vel = a if a.x * side >= b.x * side else b
	_flat_floor(m)
	nudged.emit(m.pos)


func _anti_stuck() -> void:
	if time >= _next_dry_t:
		_nudge()
		_next_dry_t = time + NbBalance.DRY_REPEAT_S
	if not assist_on and time - _last_break_t >= NbBalance.assist_s(easy):
		var tgt: Vector2 = aim_point(Vector2(paddle_x, paddle_top()), false)
		if tgt.is_finite():
			assist_on = true
			assist_index = aim_index
			assist_armed.emit(aim_index)
	# Safety respawn (rule 6); a lost echo just goes.
	var o: float = NbBalance.RESPAWN_OUTSIDE_PX
	for i: int in range(balls.size() - 1, -1, -1):
		var bl: Ball = balls[i]
		var bad: bool = (
			is_nan(bl.pos.x)
			or is_nan(bl.pos.y)
			or is_nan(bl.vel.x)
			or bl.pos.x < NbBalance.FIELD_LEFT - o
			or bl.pos.x > NbBalance.FIELD_RIGHT + o
			or bl.pos.y < NbBalance.FIELD_TOP - o
		)
		if not bad:
			continue
		if i > 0:
			balls.remove_at(i)
		else:
			_to_rest()


# ---------------------------------------------------------------- capsules


func _spawn_capsule(at: Vector2, kind: String, bonus: bool) -> Capsule:
	var alive: int = 0
	for c: Capsule in capsules:
		if c.alive:
			alive += 1
	if alive >= NbBalance.CAPSULE_MAX:
		return null
	var c := Capsule.new()
	c.pos = at
	c.kind = kind
	c.bonus = bonus
	capsules.append(c)
	capsule_spawned.emit(c)
	return c


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
	var i: int = 0
	while i < capsules.size():
		var c: Capsule = capsules[i]
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
			capsules.remove_at(i)
			_apply_powerup(c.kind)
			capsule_caught.emit(c.kind, c.pos)
		elif c.pos.y >= NbBalance.CAPSULE_FADE_Y:
			c.alive = false
			capsules.remove_at(i)
			capsule_missed.emit(c)
		else:
			i += 1


## Same power-up again = refresh, not stack (GDD 5.2).
func _apply_powerup(kind: String) -> void:
	match kind:
		"komet":
			komet_left = NbBalance.komet_bricks(easy)
			komet_t = NbBalance.komet_s(easy)
			komet_changed.emit(true)
		"ekko":
			_start_ekko()
		"bredvinge":
			if wide_t <= 0.0:
				wide_changed.emit(true)
			wide_t = NbBalance.bredvinge_s(easy)
		"neonpuls":
			if pulse_left <= 0:
				_pulse_next_t = time
			pulse_left = NbBalance.NEONPULS_WAVES


## Ekko: two echo balls split from the main ball at -20 / +20 degrees and
## live 10 s; with echoes alive their life is refreshed instead.
func _start_ekko() -> void:
	var m: Ball = balls[0]
	if echo_count() > 0:
		for i: int in range(1, balls.size()):
			balls[i].life = NbBalance.EKKO_LIFE_S
		return
	var dir := Vector2(0.0, -1.0)
	if state == State.PLAY and m.vel.length() > 1.0:
		dir = m.vel.normalized()
	for d: float in [-NbBalance.EKKO_SPLIT_DEG, NbBalance.EKKO_SPLIT_DEG]:
		if balls.size() >= NbBalance.BALLS_MAX:
			break
		var v: Vector2 = dir.rotated(deg_to_rad(d))
		if v.y > -NbBalance.EKKO_MIN_UP:
			v = Vector2(v.x, -0.6).normalized()
		var e := Ball.new()
		e.pos = m.pos
		e.vel = v * speed()
		e.echo = true
		e.life = NbBalance.EKKO_LIFE_S
		_flat_floor(e)
		balls.append(e)
	echo_split.emit(m.pos)


func _tick_echoes(delta: float) -> void:
	for i: int in range(balls.size() - 1, 0, -1):
		balls[i].life -= delta
		if balls[i].life <= 0.0:
			balls.remove_at(i)


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
	balls[0].vel = Vector2.ZERO
	balls[0].pos = Vector2(paddle_x, paddle_top() - NbBalance.BALL_RADIUS)
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
	if wide_t > 0.0:
		wide_changed.emit(false)
	_reset_round()
	restart_started.emit()


func _restart_tick(delta: float) -> void:
	_restart_t += delta
	if not _restored and _restart_t >= NbBalance.RESTART_DIM_S:
		_restored = true
		var idx := PackedInt32Array()
		breakable_left = 0
		for i: int in bricks.size():
			var b: NbSim.Brick = bricks[i]
			if b.minion:
				b.alive = false
				continue
			if not b.alive or b.hp != b.max_hp or b.rect != b.home:
				idx.append(i)
			b.alive = true
			b.hp = b.max_hp
			b.rect = b.home
			b.vx = b.home_vx
			if b.breakable():
				breakable_left += 1
		total_breakable = start_breakable
		bricks_restored.emit(idx)
	if not _refilled and _restart_t >= NbBalance.RESTART_DIM_S + NbBalance.RESTART_REWIND_S:
		_refilled = true
		net_charges = NbBalance.NET_CHARGES
		ball_visible = true
	balls[0].pos = Vector2(paddle_x, paddle_top() - NbBalance.BALL_RADIUS)
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
