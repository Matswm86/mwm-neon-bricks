extends Node

## Headless action-pass test (GDD 15.10 acceptance):
##   godot --headless --audio-driver Dummy res://tests/levels_test.tscn
## LEVELS_SEEDS=<n> sets runs per level and setting (default 20);
## LEVELS_ONLY=<id> runs one level; LEVELS_VERBOSE=1 prints every run.
## 1. A bot paddle (tracks at 2500 px/s like tools/action_sim.py, random
##    contact offset) clears every level 1-15 in Lett and Vanlig with the
##    real nets; no run may reach the 300 s cap. Prints median / p90 clear
##    time, breaks per second, longest gap and last-3 time next to the
##    GDD 15.6 sim medians. Checks: Vanlig median within +-35% of 15.6,
##    Vanlig longest-gap median < 10 s, no ball flatter than 20 degrees,
##    no march piece bottom below its floor_y (<= 1000), Lett never restarts.
## 2. Ekko: echo balls falling past a charged net never spend a charge
##    (level 6, Vanlig, forced Ekko).
## 3. Lett: unlimited net on all 15 levels; gameplay shake is off in Lett.
## 4. Flash limiter in the real game (NbMain, autopilot): at most 3 glow
##    spikes in any 1 s window during level 12 (Nova chains) and level 10
##    (boss phase change).
## Exit code 0 = all pass.

const DT: float = 1.0 / 60.0
const CAP_S: float = 300.0
const BOT_SPEED: float = 2500.0
const PARITY: float = 0.35
## GDD 15.6 (tools/action_sim.py --runs 80): median clear [Lett, Vanlig] s.
const SIM_MEDIAN: Dictionary = {
	1: [59, 46],
	2: [72, 59],
	3: [57, 46],
	4: [44, 54],
	5: [34, 32],
	6: [44, 35],
	7: [37, 41],
	8: [69, 69],
	9: [49, 54],
	10: [46, 40],
	11: [36, 36],
	12: [31, 29],
	13: [35, 37],
	14: [23, 25],
	15: [26, 29],
	# GDD 16.5 (tools/action_sim.py --skip-old --runs 40, v3 sim)
	16: [68, 50],
	17: [44, 38],
	18: [80, 54],
	19: [63, 51],
	20: [43, 32],
	21: [41, 41],
	22: [31, 24],
	23: [59, 39],
	24: [34, 38],
	25: [28, 30],
	26: [27, 28],
	27: [24, 22],
	28: [29, 29],
	29: [20, 22],
	30: [22, 30],
}

## Open findings for game-designer, printed as KNOWN instead of failing.
## (Level 10 was here until GDD 16.6 lowered its Vanlig boss HP 20 -> 16.)
const KNOWN_GAP: Dictionary = {}

var fails: int = 0
var finished: int = 0
var seeds: int = 20
var only: int = 0
## LEVELS_FROM=<id> skips the levels below it; LEVELS_QUICK=1 skips the
## game-loop flash test.
var from_id: int = 1
var quick: bool = false
var verbose: bool = false
var _novas: int = 0
var _phases: int = 0
var _warns: int = 0


func _ready() -> void:
	var env: String = OS.get_environment("LEVELS_SEEDS")
	if env.is_valid_int():
		seeds = maxi(1, env.to_int())
	if OS.get_environment("LEVELS_ONLY").is_valid_int():
		only = OS.get_environment("LEVELS_ONLY").to_int()
	if OS.get_environment("LEVELS_FROM").is_valid_int():
		from_id = OS.get_environment("LEVELS_FROM").to_int()
	quick = OS.get_environment("LEVELS_QUICK") == "1"
	verbose = OS.get_environment("LEVELS_VERBOSE") == "1"
	_test_all_levels()
	_test_ekko_never_spends()
	_test_lett_rules()
	_test_endless()
	if quick:
		finished += 1
	else:
		await _test_flash_in_game()
	_check(finished == 5, "all 5 test groups ran to the end (%d)" % finished)
	print("RESULT: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	NbMeshes.clear_cache()
	NbEndless.clear_cache()
	get_tree().quit(0 if fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _median(a: Array[float]) -> float:
	var s: Array[float] = a.duplicate()
	s.sort()
	var n: int = s.size()
	if n == 0:
		return 0.0
	return s[n / 2] if n % 2 == 1 else 0.5 * (s[n / 2 - 1] + s[n / 2])


func _p90(a: Array[float]) -> float:
	var s: Array[float] = a.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(0.9 * s.size()))]


## One bot run. Returns clear time, pacing and the safety logs.
func _run(id: int, easy: bool, seed_i: int) -> Dictionary:
	var sim := NbSim.new()
	sim.rng.seed = 1000 * id + seed_i + (0 if easy else 500)
	sim.setup(NbLevels.get_level(id), easy)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7000 * id + seed_i
	var off: Array[float] = [rnd.randf_range(-0.6, 0.6) * sim.paddle_half]
	sim.paddle_hit.connect(
		func(p: Vector2, _r: float) -> void:
			if p.is_equal_approx(sim.balls[0].pos):
				off[0] = rnd.randf_range(-0.6, 0.6) * sim.paddle_half
	)
	var breaks: Array[float] = []
	var left3: Array[float] = [-1.0]
	sim.brick_broken.connect(
		func(_i: int, _l: bool) -> void:
			breaks.append(sim.time)
			if sim.breakable_left <= 3 and left3[0] < 0.0:
				left3[0] = sim.time
	)
	var caught: Array[int] = [0]
	sim.capsule_caught.connect(func(_k: String, _p: Vector2) -> void: caught[0] += 1)
	# GDD 16.11 logs: a phased ghost is never hit; portal hops <= 3.
	var phased_hits: Array[int] = [0]
	var hop_max: Array[int] = [0]
	var ghost_hit := func(i: int) -> void:
		var b: NbSim.Brick = sim.bricks[i]
		if b.ghost != 0 and not sim.ghosts_locked and (b.ghost == 1) != sim.ghost_a_solid:
			phased_hits[0] += 1
	sim.brick_hit.connect(ghost_hit)
	sim.brick_broken.connect(func(i: int, _l: bool) -> void: ghost_hit.call(i))
	sim.portal_used.connect(
		func(bi: int, _f: Vector2, _t: Vector2) -> void:
			hop_max[0] = maxi(hop_max[0], sim.balls[bi].hops)
	)
	var finale_phased: int = 0
	var block_overlap: int = 0
	var floor_over: float = -INF
	var bx: float = sim.paddle_x
	var flattest: float = 1.0
	var march_low: float = 0.0
	while sim.state != NbSim.State.CLEAR and sim.time < CAP_S:
		var tx: float = NbPlay.bot_target(sim, off[0])
		bx = move_toward(bx, tx, BOT_SPEED * DT)
		sim.set_paddle_target(bx)
		sim.step(DT)
		if sim.state == NbSim.State.PLAY:
			for bl: NbSim.Ball in sim.balls:
				var sp: float = bl.vel.length()
				if sp > 1.0:
					flattest = minf(flattest, absf(bl.vel.y) / sp)
		if sim.march_on:
			for b: NbSim.Brick in sim.bricks:
				if b.alive and b.march:
					march_low = maxf(march_low, b.rect.end.y)
					floor_over = maxf(floor_over, b.rect.end.y - sim.blocks[b.block].floor_y)
			if sim.blocks.size() == 2:
				block_overlap += _blocks_overlap(sim)
		if sim.has_ghosts and sim.breakable_left <= NbBalance.finale_left(easy):
			if sim.start_breakable >= NbBalance.FINALE_MIN_START and sim.breakable_left > 0:
				for b: NbSim.Brick in sim.bricks:
					if b.alive and b.ghost != 0 and not sim.solid(b):
						finale_phased += 1
	sim.disconnect_all()
	var marks: Array[float] = [NbBalance.AUTO_LAUNCH_S]
	marks.append_array(breaks)
	var gap: float = 0.0
	for i: int in range(1, marks.size()):
		gap = maxf(gap, marks[i] - marks[i - 1])
	return {
		"t": sim.time,
		"cleared": sim.state == NbSim.State.CLEAR,
		"bps": float(breaks.size()) / maxf(1.0, sim.time - NbBalance.AUTO_LAUNCH_S),
		"gap": gap,
		"end": sim.time - left3[0] if left3[0] >= 0.0 else 0.0,
		"restarts": sim.restart_count,
		"caps": caught[0],
		"combo": sim.max_combo,
		"flat": flattest,
		"march_low": march_low,
		"floor": sim.march_floor,
		"floor_over": floor_over,
		"bricks": sim.start_breakable,
		"phased_hits": phased_hits[0],
		"finale_phased": finale_phased,
		"hop_max": hop_max[0],
		"pull_max": sim.max_pull_turn_deg,
		"block_overlap": block_overlap,
	}


func _blocks_overlap(sim: NbSim) -> int:
	for a: NbSim.Brick in sim.bricks:
		if not a.alive or a.block != 0:
			continue
		for b: NbSim.Brick in sim.bricks:
			if b.alive and b.block == 1 and a.rect.intersects(b.rect):
				return 1
	return 0


func _test_all_levels() -> void:
	print(
		(
			"-- all %d levels, %d seeds per setting, bot at 2500 px/s, real nets"
			% [NbLevels.count(), seeds]
		)
	)
	var min_flat: float = sin(deg_to_rad(NbBalance.MIN_FLAT_DEG)) - 0.001
	var t0: int = Time.get_ticks_msec()
	for easy: bool in [true, false]:
		var tag_s: String = "Lett  " if easy else "Vanlig"
		for id: int in range(1, NbLevels.count() + 1):
			if (only > 0 and id != only) or id < from_id:
				continue
			var ts: Array[float] = []
			var bps: Array[float] = []
			var gaps: Array[float] = []
			var ends: Array[float] = []
			var combos: Array[float] = []
			var restarts: int = 0
			var all_clear: bool = true
			var worst_t: float = 0.0
			var flattest: float = 1.0
			var march_low: float = 0.0
			var floor_y: float = 0.0
			var bricks: int = 0
			var floor_over: float = -INF
			var phased_hits: int = 0
			var finale_phased: int = 0
			var hop_max: int = 0
			var pull_max: float = 0.0
			var overlaps: int = 0
			for s: int in seeds:
				var r: Dictionary = _run(id, easy, s)
				if verbose:
					print("run   L%d %s seed %d %s" % [id, tag_s, s, r])
				ts.append(float(r["t"]))
				bps.append(float(r["bps"]))
				gaps.append(float(r["gap"]))
				ends.append(float(r["end"]))
				combos.append(float(r["combo"]))
				restarts += int(r["restarts"])
				all_clear = all_clear and bool(r["cleared"])
				worst_t = maxf(worst_t, float(r["t"]))
				flattest = minf(flattest, float(r["flat"]))
				march_low = maxf(march_low, float(r["march_low"]))
				floor_y = float(r["floor"])
				bricks = int(r["bricks"])
				floor_over = maxf(floor_over, float(r["floor_over"]))
				phased_hits += int(r["phased_hits"])
				finale_phased += int(r["finale_phased"])
				hop_max = maxi(hop_max, int(r["hop_max"]))
				pull_max = maxf(pull_max, float(r["pull_max"]))
				overlaps += int(r["block_overlap"])
			var med: float = _median(ts)
			var ref: float = float(SIM_MEDIAN[id][0 if easy else 1])
			print(
				(
					(
						"info  %s L%-2d bricks %2d  median %5.1f s (sim %3.0f)  p90 %5.1f  max %5.1f"
						+ "  breaks/s %.2f  gap %4.1f s  last-3 %4.1f s  max combo %2.0f  restarts %d"
					)
					% [
						tag_s,
						id,
						bricks,
						med,
						ref,
						_p90(ts),
						worst_t,
						_median(bps),
						_median(gaps),
						_median(ends),
						_median(combos),
						restarts
					]
				)
			)
			var tag: String = "%s L%d" % [tag_s.strip_edges(), id]
			_check(
				all_clear and worst_t < CAP_S,
				"%s all %d runs clear, slowest %.0f s (< %.0f)" % [tag, seeds, worst_t, CAP_S]
			)
			_check(flattest >= min_flat, "%s no ball flatter than 20 deg" % tag)
			if march_low > 0.0:
				_check(
					floor_over <= 0.01 and march_low <= NbBalance.MARCH_FLOOR_MAX_Y,
					(
						"%s march bottom max %.0f px, %+.0f px vs its block's floor_y (limit 1000)"
						% [tag, march_low, floor_over]
					)
				)
			var lv: Dictionary = NbLevels.get_level(id)
			if _has_code(lv, "AB"):
				_check(
					phased_hits == 0, "%s no phased ghost was ever hit (%d)" % [tag, phased_hits]
				)
				_check(
					finale_phased == 0,
					(
						"%s no ghost phased at %d bricks left (%d frames)"
						% [tag, NbBalance.finale_left(easy), finale_phased]
					)
				)
			if _has_code(lv, "12"):
				_check(
					hop_max <= NbBalance.PORTAL_MAX_HOPS,
					"%s portal hops max %d (<= 3)" % [tag, hop_max]
				)
			if _has_code(lv, "O"):
				_check(
					pull_max < 120.0,
					"%s magnet turn per pass max %.0f deg (< 120)" % [tag, pull_max]
				)
			if lv.get("march", {}) is Array:
				_check(
					overlaps == 0, "%s the two march blocks never overlap (%d)" % [tag, overlaps]
				)
			if easy:
				_check(restarts == 0, "%s no restart in Lett (%d)" % [tag, restarts])
			else:
				var dev: float = (med - ref) / ref
				_check(
					absf(dev) <= PARITY,
					(
						"%s Vanlig median %.1f s vs sim %.0f s (%+.0f%%, limit 35%%)"
						% [tag, med, ref, dev * 100.0]
					)
				)
				var gap_ok: bool = _median(gaps) < 10.0
				var gap_msg: String = (
					"%s Vanlig longest-gap median %.1f s (< 10)" % [tag, _median(gaps)]
				)
				if not gap_ok and KNOWN_GAP.has(id):
					print("KNOWN %s: %s" % [gap_msg, KNOWN_GAP[id]])
				else:
					_check(gap_ok, gap_msg)
	print("info  level runs took %.1f s wall" % ((Time.get_ticks_msec() - t0) / 1000.0))
	finished += 1


## Endless "Neonveien" v3 (GDD 16.9): deterministic, valid maps for k 1-40
## with everything cleared and with world 1 only; a bot clears a few.
func _test_endless() -> void:
	print("-- endless generator v3: k 1-40, two saves, bot runs")
	var all30: Array = range(1, 31)
	var w1: Array = [1, 2, 3, 4, 5]
	for cleared: Array in [all30, w1]:
		var bad: PackedStringArray = PackedStringArray()
		var mech: Dictionary = {}
		for k: int in range(1, 41):
			var lv: Dictionary = NbEndless.generate(k, cleared)
			var again: Dictionary = NbEndless.generate(k, cleared)
			if lv["rows"] != again["rows"]:
				bad.append("k%d not deterministic" % k)
			var sim := NbSim.new()
			sim.setup(lv, false)
			var n: int = sim.start_breakable
			if n < 20 or n > 48:
				bad.append("k%d breakable %d" % [k, n])
			var unreach: PackedStringArray = NbEndless.lint(lv)
			if not unreach.is_empty():
				bad.append("k%d unreachable %s" % [k, unreach])
			if k % 10 == 0 and sim.boss_index < 0:
				bad.append("k%d has no boss" % k)
			if k % 5 == 0 and not sim.net_unlimited:
				bad.append("k%d is a breather but its Vanlig net is charged" % k)
			var m: Variant = lv.get("march", {})
			var key: String = (
				"two_march" if m is Array else ("march" if not (m as Dictionary).is_empty() else "")
			)
			for code: String in ["S", "1", "O", "M", "C", "T"]:
				for row: String in lv["rows"]:
					if row.to_upper().contains(code):
						mech[code] = int(mech.get(code, 0)) + 1
						break
			if key != "":
				mech[key] = int(mech.get(key, 0)) + 1
			if cleared == w1:
				for row: String in lv["rows"]:
					for code: String in ["S", "A", "1", "O", "M", "C", "T"]:
						if row.to_upper().contains(code):
							bad.append("k%d uses %s before it was cleared" % [k, code])
		var tag: String = "all 30 cleared" if cleared == all30 else "world 1 only"
		print("info  endless (%s) element counts over k 1-40: %s" % [tag, mech])
		_check(bad.is_empty(), "endless (%s): 40 valid maps %s" % [tag, bad])
	# March in endless (GDD 16.9 rule 6, QA 2026-10-07 finding 3): non-boss
	# levels k 1-200 with everything cleared.
	var marches: int = 0
	var twos: int = 0
	var eligible: int = 0
	for k: int in range(1, 201):
		if k % 10 == 0:
			continue
		eligible += 1
		var mv: Variant = NbEndless.generate(k, all30).get("march", {})
		if mv is Array:
			twos += 1
			marches += 1
		elif not (mv as Dictionary).is_empty():
			marches += 1
	var rate: float = float(marches) / float(eligible)
	_check(
		rate >= 0.15 and twos > 0,
		(
			"endless march on %d of %d non-boss levels (%.0f%%, %d with two blocks), k 1-200"
			% [marches, eligible, rate * 100.0, twos]
		)
	)
	# Bot clears (Vanlig, all cleared, real nets), cap 300 s.
	var times: PackedStringArray = PackedStringArray()
	var ok: bool = true
	for k: int in [1, 5, 10, 13, 20, 27, 40]:
		var lv: Dictionary = NbEndless.generate(k, all30)
		var sim := NbSim.new()
		sim.rng.seed = 900 + k
		sim.setup(lv, false)
		var bx: float = sim.paddle_x
		var rnd := RandomNumberGenerator.new()
		rnd.seed = k
		var off: float = 0.0
		while sim.state != NbSim.State.CLEAR and sim.time < CAP_S:
			if sim.balls[0].vel.y < 0.0:
				off = rnd.randf_range(-0.6, 0.6) * sim.paddle_half
			bx = move_toward(bx, NbPlay.bot_target(sim, off), BOT_SPEED * DT)
			sim.set_paddle_target(bx)
			sim.step(DT)
		times.append("k%d %.0f s" % [k, sim.time])
		ok = ok and sim.state == NbSim.State.CLEAR
	_check(ok, "endless bot clears (Vanlig, < 300 s): %s" % ", ".join(times))
	finished += 1


func _has_code(lv: Dictionary, codes: String) -> bool:
	for row: String in lv["rows"]:
		for ch: String in codes:
			if row.to_upper().contains(ch):
				return true
	return false


func _test_ekko_never_spends() -> void:
	print("-- Ekko echoes never spend a net charge (Vanlig, level 6, forced Ekko)")
	var sim := NbSim.new()
	sim.rng.seed = 66
	sim.setup(NbLevels.get_level(6), false)
	_check(not sim.net_unlimited and sim.net_charges == 3, "level 6 Vanlig net has 3 charges")
	var spent_without_echo: Array[int] = [0]
	var spent_with_echo: Array[int] = [0]
	var last: Array[int] = [sim.net_charges]
	sim.net_caught.connect(
		func(_p: Vector2, left: int) -> void:
			if left < last[0]:
				if sim.echo_count() > 0:
					spent_with_echo[0] += 1
				else:
					spent_without_echo[0] += 1
			last[0] = left
	)
	sim.launch()
	sim._apply_powerup("ekko")
	_check(sim.echo_count() == 2, "Ekko split into 2 echoes (%d)" % sim.echo_count())
	var echoes_lost_at_net: int = 0
	var t: float = 0.0
	while t < 12.0 and sim.state == NbSim.State.PLAY:
		# Dodge every ball so all of them fall to the net.
		sim.set_paddle_target(1040.0 if sim.ball_pos.x < 540.0 else 40.0)
		var before: int = sim.echo_count()
		var charges_before: int = sim.net_charges
		sim.step(DT)
		t += DT
		if sim.echo_count() < before:
			echoes_lost_at_net += before - sim.echo_count()
			_check(
				sim.net_charges == charges_before or spent_without_echo[0] > 0,
				"echo gone at %.1f s, charges %d -> %d" % [t, charges_before, sim.net_charges]
			)
	_check(echoes_lost_at_net >= 1, "echoes dissolved at the net (%d)" % echoes_lost_at_net)
	_check(
		spent_with_echo[0] == 0,
		(
			"no charge spent while an echo was in play (spent %d with echo, %d without)"
			% [spent_with_echo[0], spent_without_echo[0]]
		)
	)
	finished += 1


func _test_lett_rules() -> void:
	print("-- Lett: unlimited net on all levels, no gameplay shake")
	var all_unlimited: bool = true
	for id: int in range(1, NbLevels.count() + 1):
		var sim := NbSim.new()
		sim.setup(NbLevels.get_level(id), true)
		all_unlimited = all_unlimited and sim.net_unlimited
	_check(all_unlimited, "Lett net unlimited on all %d levels" % NbLevels.count())
	var st: NbState = get_node("/root/NeonBricks")
	var keep: bool = st.easy
	var play := NbPlay.new()
	st.easy = true
	_check(not play.shake_allowed(), "Lett: combo / Nova shake off")
	st.easy = false
	st.less_motion = true
	_check(not play.shake_allowed(), "Vanlig + Mindre bevegelse: shake off")
	st.less_motion = false
	_check(play.shake_allowed(), "Vanlig: shake on")
	st.easy = keep
	play.free()
	finished += 1


## Runs a level in the real game loop and returns the most glow spikes seen
## in any 1 s window of real time.
func _flash_run(main: NbMain, id: int, until: Callable, max_real_s: float) -> Array[int]:
	main.open_level(id)
	var play: NbPlay = main.play
	play.sim.nova_blasted.connect(func(_p: Vector2) -> void: _novas += 1)
	play.sim.boss_phase_changed.connect(func(_i: int, _ph: int) -> void: _phases += 1)
	play.sim.ghost_warned.connect(func(_a: bool) -> void: _warns += 1)
	play.autopilot = true
	Engine.time_scale = 3.0
	var worst: int = 0
	var start: int = Time.get_ticks_msec()
	var seen: float = -1.0
	var w: NbWorld = main.world
	while Time.get_ticks_msec() - start < int(max_real_s * 1000.0):
		await get_tree().process_frame
		var st: Array[float] = w.spike_times
		for i: int in st.size():
			if st[i] <= seen:
				continue
			var n: int = 0
			for j: int in range(i, -1, -1):
				if st[i] - st[j] < 1.0:
					n += 1
			worst = maxi(worst, n)
		if not st.is_empty():
			seen = st[st.size() - 1]
		if until.call() or play.card_visible():
			break
	Engine.time_scale = 1.0
	return [worst, play._limiter.granted, play._limiter.denied]


func _test_flash_in_game() -> void:
	print("-- flash limiter in the real game loop (levels 12, 10, 18 and 30, Vanlig)")
	var st: NbState = get_node("/root/NeonBricks")
	var keep: bool = st.easy
	st.easy = false
	var main: NbMain = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var r12: Array[int] = await _flash_run(main, 12, func() -> bool: return _novas >= 6, 40.0)
	_check(_novas >= 2, "level 12 Nova blasts seen: %d" % _novas)
	_check(
		r12[0] <= 3,
		"level 12 max glow spikes in 1 s: %d (granted %d, held back %d)" % [r12[0], r12[1], r12[2]]
	)
	var r10: Array[int] = await _flash_run(main, 10, func() -> bool: return _phases >= 2, 60.0)
	_check(_phases >= 1, "level 10 boss phase changes seen: %d" % _phases)
	_check(
		r10[0] <= 3,
		"level 10 max glow spikes in 1 s: %d (granted %d, held back %d)" % [r10[0], r10[1], r10[2]]
	)
	_novas = 0
	var r18: Array[int] = await _flash_run(
		main, 18, func() -> bool: return _warns >= 2 and _novas >= 2, 60.0
	)
	_check(
		_warns >= 1 and _novas >= 1,
		"level 18 auto-flip warnings %d, Nova blasts %d" % [_warns, _novas]
	)
	_check(
		r18[0] <= 3,
		"level 18 max glow spikes in 1 s: %d (granted %d, held back %d)" % [r18[0], r18[1], r18[2]]
	)
	_phases = 0
	var r30: Array[int] = await _flash_run(main, 30, func() -> bool: return _phases >= 2, 90.0)
	_check(_phases >= 2, "level 30 boss reached phase 2 (%d phase changes)" % _phases)
	_check(
		r30[0] <= 3,
		"level 30 max glow spikes in 1 s: %d (granted %d, held back %d)" % [r30[0], r30[1], r30[2]]
	)
	main.queue_free()
	st.easy = keep
	st.cleared = [] as Array[int]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NbState.SAVE_PATH))
	finished += 1
