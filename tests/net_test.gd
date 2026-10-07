extends Node

## Headless logic test (no rendering):
##   godot --headless --audio-driver Dummy res://tests/net_test.tscn
## 1. 3-charge net + gentle restart on a world 1 level (test-only flag).
## 2. Unlimited world 1 net in Vanlig never restarts.
## 3. A bot paddle clears the 5 world 1 levels in Lett and Vanlig; the ball
##    never travels flatter than 20 degrees; level 4 never goes 15 s without
##    progress. (All 30 levels: tests/levels_test.tscn.)
## 4. Komet capsules are caught and plough through bricks; the flash limiter
##    keeps glow spikes to 3 per second.
## Exit code 0 = all pass.

const DT: float = 1.0 / 60.0

var fails: int = 0
## Tests that ran to their last line; a script error stops one early.
var finished: int = 0


func _ready() -> void:
	_test_charged_net()
	_test_unlimited_net()
	_test_bot_clears()
	_test_flash_limiter()
	_test_save_roundtrip()
	_check(finished == 5, "all 5 test groups ran to the end (%d)" % finished)
	print("RESULT: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	NbMeshes.clear_cache()
	NbEndless.clear_cache()
	get_tree().quit(0 if fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


## Moves the paddle away from the ball so every fall reaches the net.
func _dodge(sim: NbSim) -> void:
	sim.set_paddle_target(1040.0 if sim.ball_pos.x < 540.0 else 40.0)


func _test_charged_net() -> void:
	print("-- charged net + gentle restart (Vanlig, level 1, test flag)")
	var sim := NbSim.new()
	sim.rng.seed = 7
	sim.setup(NbLevels.get_level(1), false, true)
	_check(not sim.net_unlimited and sim.net_charges == 3, "net starts with 3 charges")
	var charges_seen: Array[int] = []
	sim.net_caught.connect(func(_p: Vector2, left: int) -> void: charges_seen.append(left))
	var restarted: Array[float] = []
	var restored: Array[int] = []
	var done_at: Array[float] = []
	sim.restart_started.connect(func() -> void: restarted.append(sim.time))
	sim.bricks_restored.connect(func(idx: PackedInt32Array) -> void: restored.append(idx.size()))
	sim.restart_finished.connect(func() -> void: done_at.append(sim.time))
	sim.launch()
	var broken_before: int = 0
	var t: float = 0.0
	while restarted.is_empty() and t < 300.0:
		_dodge(sim)
		sim.step(DT)
		t += DT
		if restarted.is_empty():
			broken_before = sim.start_breakable - sim.breakable_left
	_check(
		charges_seen == [2, 1, 0], "catches spend pips 3 -> 2 -> 1 -> 0 (seen %s)" % [charges_seen]
	)
	_check(restarted.size() == 1, "4th miss starts the gentle restart (after %.1f s)" % t)
	_check(not sim.ball_visible, "ball hidden while the scene dims")
	var dims: Array[float] = []
	while done_at.is_empty() and t < 310.0:
		sim.step(DT)
		t += DT
		dims.append(sim.restart_dim())
	var took: float = done_at[0] - restarted[0] if not done_at.is_empty() else 99.0
	_check(took < 2.0, "restart finishes in %.2f s (< 2 s)" % took)
	_check(dims.max() >= 0.99 and dims[dims.size() - 1] <= 0.05, "scene dims fully and lifts again")
	_check(
		restored.size() == 1,
		(
			"bricks float back once (%d moved, %d broken before)"
			% [restored[0] if restored.size() > 0 else -1, broken_before]
		)
	)
	_check(
		sim.breakable_left == sim.start_breakable,
		"all %d bricks are back (%d)" % [sim.start_breakable, sim.breakable_left]
	)
	_check(sim.net_charges == 3, "net refilled to 3 pips (%d)" % sim.net_charges)
	_check(sim.state == NbSim.State.REST and sim.ball_visible, "ball rests on the paddle")
	_check(absf(sim.ball_pos.x - sim.paddle_x) < 0.01, "ball sits on paddle centre")
	# A second cycle works the same way.
	sim.launch()
	t = 0.0
	while sim.restart_count < 2 and t < 300.0:
		_dodge(sim)
		sim.step(DT)
		t += DT
	_check(
		sim.restart_count == 2 and charges_seen == [2, 1, 0, 2, 1, 0],
		"second round: 3 catches then restart again"
	)
	sim.disconnect_all()
	finished += 1


func _test_unlimited_net() -> void:
	print("-- unlimited net in world 1 (Vanlig, level 4, no flag)")
	var sim := NbSim.new()
	sim.rng.seed = 3
	sim.setup(NbLevels.get_level(4), false)
	sim.launch()
	for i: int in int(90.0 / DT):
		_dodge(sim)
		sim.step(DT)
	_check(sim.net_unlimited, "world 1 Vanlig net is unlimited")
	_check(sim.restart_count == 0, "no restart in 90 s of misses (catches: %d)" % sim.net_catches)
	_check(sim.net_catches > 3, "net kept catching (%d catches)" % sim.net_catches)
	var lett := NbSim.new()
	lett.setup(NbLevels.get_level(1), true)
	_check(lett.net_unlimited, "Lett net is unlimited")
	finished += 1


func _test_bot_clears() -> void:
	var min_flat: float = sin(deg_to_rad(NbBalance.MIN_FLAT_DEG)) - 0.001
	for easy: bool in [true, false]:
		for id: int in range(1, NbLevels.LEVELS_PER_WORLD + 1):
			var sim := NbSim.new()
			sim.rng.seed = 100 + id
			sim.setup(NbLevels.get_level(id), easy)
			var rnd := RandomNumberGenerator.new()
			rnd.seed = 200 + id
			var off: Array[float] = [rnd.randf_range(-0.6, 0.6) * sim.paddle_half]
			sim.paddle_hit.connect(
				func(_p: Vector2, _r: float) -> void:
					off[0] = rnd.randf_range(-0.6, 0.6) * sim.paddle_half
			)
			var last_progress: Array[float] = [0.0]
			sim.paddle_hit.connect(
				func(_p: Vector2, _r: float) -> void: last_progress[0] = sim.time
			)
			sim.brick_hit.connect(func(_i: int) -> void: last_progress[0] = sim.time)
			sim.brick_broken.connect(func(_i: int, _l: bool) -> void: last_progress[0] = sim.time)
			var caught: Array[int] = [0]
			sim.capsule_caught.connect(func(_k: String, _p: Vector2) -> void: caught[0] += 1)
			var komet_breaks: Array[int] = [0]
			sim.brick_broken.connect(
				func(_i: int, _l: bool) -> void:
					if sim.komet_active() or sim.komet_t > 0.0:
						komet_breaks[0] += 1
			)
			var flattest: float = 1.0
			var worst_gap: float = 0.0
			while sim.state != NbSim.State.CLEAR and sim.time < 900.0:
				sim.set_paddle_target(sim.ball_pos.x - off[0])
				sim.step(DT)
				if sim.state == NbSim.State.PLAY:
					var sp: float = sim.ball_vel.length()
					flattest = minf(flattest, absf(sim.ball_vel.y) / sp)
					if sim.time > NbBalance.AUTO_LAUNCH_S:
						worst_gap = maxf(worst_gap, sim.time - last_progress[0])
			var tag: String = "%s L%d" % ["Lett" if easy else "Vanlig", id]
			_check(
				sim.state == NbSim.State.CLEAR,
				(
					"%s cleared by bot in %.0f s (restarts %d, net catches %d)"
					% [tag, sim.time, sim.restart_count, sim.net_catches]
				)
			)
			_check(
				flattest >= min_flat,
				(
					"%s flattest ball %.1f deg from horizontal (>= 20)"
					% [tag, rad_to_deg(asin(clampf(flattest, 0.0, 1.0)))]
				)
			)
			if id == 4:
				_check(
					worst_gap < 15.0,
					(
						"%s longest time with no paddle touch or brick hit %.1f s (< 15)"
						% [tag, worst_gap]
					)
				)
			if NbLevels.carriers(NbLevels.get_level(id)).has("komet"):
				if easy:
					# Lett has the capsule magnet; Vanlig misses are allowed.
					_check(caught[0] >= 1, "%s Komet capsules caught: %d" % [tag, caught[0]])
				else:
					print(
						"info  %s Komet capsules caught by a ball-only bot: %d" % [tag, caught[0]]
					)
			sim.disconnect_all()
	finished += 1


func _test_flash_limiter() -> void:
	print("-- flash limiter during a Komet run (level 3)")
	var sim := NbSim.new()
	sim.rng.seed = 11
	sim.setup(NbLevels.get_level(3), true)
	var lim := NbFlashLimiter.new()
	var spikes: Array[float] = []
	sim.brick_broken.connect(
		func(_i: int, _l: bool) -> void:
			if lim.allow(sim.time):
				spikes.append(sim.time)
	)
	# Komet from the start so the ball ploughs through the wall.
	sim.launch()
	sim._apply_powerup("komet")
	while sim.state != NbSim.State.CLEAR and sim.time < 600.0:
		sim.set_paddle_target(sim.ball_pos.x)
		if not sim.komet_active() and sim.state == NbSim.State.PLAY:
			sim._apply_powerup("komet")
		sim.step(DT)
	var worst: int = 0
	for i: int in spikes.size():
		var n: int = 0
		for j: int in range(i, spikes.size()):
			if spikes[j] - spikes[i] < 1.0:
				n += 1
		worst = maxi(worst, n)
	_check(
		worst <= 3,
		(
			"max glow spikes in any 1 s window: %d (granted %d, held back %d)"
			% [worst, lim.granted, lim.denied]
		)
	)
	_check(lim.denied > 0, "limiter actually held back bursts during the Komet run")
	sim.disconnect_all()
	finished += 1


func _test_save_roundtrip() -> void:
	print("-- save file")
	var st: NbState = get_node("/root/NeonBricks")
	var keep_easy: bool = st.easy
	st.cleared = [1, 2] as Array[int]
	st.easy = false
	st.save_game()
	st.cleared = [] as Array[int]
	st.easy = true
	st.load_game()
	_check(st.cleared == [1, 2] and not st.easy, "save/load keeps cleared levels and difficulty")
	var txt: String = FileAccess.get_file_as_string(NbState.SAVE_PATH)
	_check(
		txt.contains('"version"') and txt.contains('"settings"'), "save has version + settings keys"
	)
	st.full_unlock = false
	_check(st.visible_levels() == ([1, 2, 3] as Array[int]), "full_unlock false shows levels 1-3")
	_check(st.next_level_after(3) == 0, "no next level after 3 when locked")
	st.full_unlock = true
	_check(
		st.visible_levels().size() == NbLevels.count(),
		"full_unlock true shows all %d levels" % NbLevels.count()
	)
	st.cleared = [] as Array[int]
	st.easy = keep_easy
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NbState.SAVE_PATH))
	finished += 1
