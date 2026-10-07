extends Node

## Dev-only screenshot bot. Run under Xvfb with a fresh user dir:
##   XDG_DATA_HOME=<tmp> CAPTURE_DIR=<dir> godot --audio-driver Dummy \
##     --display-driver x11 --resolution 1080x1920 res://tests/capture.tscn
## CAPTURE_PHASE:
##   shots (default) - level 1 start (first launch), a real touch drag,
##                     level 4 mid-play, level 1 win card, map, settings,
##                     Vanlig 3-pip net + gentle restart dim, Komet run
##   inset           - fake 120 px camera cutout: home disc and map gear
##   tall            - run with --resolution 1080x2400: field stays bottom-anchored
##   shell           - inside MWM Play: Engine meta set, set_full_unlock(false),
##                     levels 1-3 only, level 3 card has no "next" and emits
##                     free_levels_finished; own home disc and gear hidden
##   action          - action pass (GDD 15): Neonrush combo, Ekko echoes, boss
##                     levels 5 / 10 / 15 mid-fight, world 2 and 3 levels,
##                     the three map pages

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var main: NbMain


func _ready() -> void:
	if out_dir == "":
		out_dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var phase: String = OS.get_environment("CAPTURE_PHASE")
	if phase == "shell":
		Engine.set_meta(&"mwm_play_shell", true)
		NeonBricks.set_full_unlock(false)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	var t0: int = Time.get_ticks_msec()
	match phase:
		"inset":
			await _phase_inset()
		"tall":
			await _phase_tall()
		"shell":
			await _phase_shell()
		"action":
			await _phase_action()
		_:
			await _phase_shots()
	print("CAPTURE DONE in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	Engine.time_scale = 1.0
	get_tree().quit()


func _phase_shots() -> void:
	var play: NbPlay = main.play
	print("first launch opened screen=%s level=%d" % [main.screen, play.level_id])
	await _wait_s(1.6)
	await _shot("01_level1_start")
	# Real touch: press in the drag zone, drag right 200 px, release = launch.
	var x0: float = play.sim.paddle_x
	var p := Vector2(540, 1300)
	_touch(p, true)
	await _frames(3)
	for i: int in 10:
		p += Vector2(20, 0)
		_drag(p, Vector2(20, 0))
		await _frames(1)
	await _frames(3)
	var moved: float = play.sim.paddle_x - x0
	_touch(p, false)
	await _frames(3)
	print(
		(
			"touch drag 200 px moved paddle %.0f px (gain 1.25 -> 250); state after release=%d (1=PLAY)"
			% [moved, play.sim.state]
		)
	)
	# Touch above the drag zone is ignored.
	var xb: float = play.sim.paddle_x
	_touch(Vector2(540, 600), true)
	_drag(Vector2(700, 600), Vector2(160, 0))
	_touch(Vector2(700, 600), false)
	await _frames(3)
	print("touch at y 600 moved paddle %.0f px (expect 0)" % (play.sim.paddle_x - xb))

	# Level 4 mid-play (the hero scene), Vanlig paddle like the mock.
	NeonBricks.easy = false
	main.open_level(4)
	play.autopilot = true
	var total: int = play.sim.breakable_left
	Engine.time_scale = 3.0
	var t: float = 0.0
	var komet_seen: bool = false
	while t < 40.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var broken: int = total - play.sim.breakable_left
		if play.sim.komet_active() and not komet_seen and broken >= 4:
			komet_seen = true
			Engine.time_scale = 1.0
			await _frames(2)
			await _shot("03_level4_komet")
			Engine.time_scale = 3.0
		if (
			broken >= int(total * 0.3)
			and not play.sim.capsules.is_empty()
			and play.sim.capsules[0].pos.y > 800.0
		):
			break
		if broken >= int(total * 0.55):
			break
	Engine.time_scale = 1.0
	await _frames(2)
	await _shot("02_level4_midplay")
	print(
		(
			"level 4: %d of %d broken, capsules falling %d, komet %s"
			% [
				total - play.sim.breakable_left,
				total,
				play.sim.capsules.size(),
				play.sim.komet_active()
			]
		)
	)

	# Level 1 to the win card (Lett).
	NeonBricks.easy = true
	main.open_level(1)
	play.autopilot = true
	Engine.time_scale = 4.0
	t = 0.0
	while play.sim.state != NbSim.State.CLEAR and t < 400.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	print(
		(
			"level 1 cleared=%s after %.0f game-s"
			% [play.sim.state == NbSim.State.CLEAR, play.sim.time]
		)
	)
	Engine.time_scale = 1.0
	await _frames(2)
	while not play.card_visible():
		await get_tree().process_frame
	await _wait_s(0.6)
	await _shot("04_level1_wincard")
	print("cleared after win: %s" % [NeonBricks.cleared])

	# Map page with the cleared star and the suggested pulse on level 2.
	play.win_card.map_pressed.emit()
	await _wait_s(1.2)
	await _shot("05_map")
	main.settings.open()
	await _frames(3)
	await _shot("06_settings")
	main.settings.visible = false

	# Vanlig with the test-only 3-charge net: pips, then the gentle restart.
	NeonBricks.easy = false
	play.force_charged_net = true
	main.open_level(2)
	play.autopilot = false
	play._dragged = true
	await _wait_s(0.5)
	play.sim.launch()
	t = 0.0
	var pip_shot: bool = false
	while play.sim.restart_count == 0 and t < 30.0:
		play.sim.set_paddle_target(1040.0 if play.sim.ball_pos.x < 540.0 else 40.0)
		await get_tree().process_frame
		t += get_process_delta_time()
		if not pip_shot and play.sim.net_charges == 2 and play.sim.ball_pos.y < 1200.0:
			pip_shot = true
			await _shot("07_vanlig_net_2pips")
	await _wait_s(0.9)
	await _shot("08_gentle_restart")
	print(
		(
			"restart: state=%d dim=%.2f float=%.2f charges=%d"
			% [
				play.sim.state,
				play.sim.restart_dim(),
				play.sim.restart_float(),
				play.sim.net_charges
			]
		)
	)
	await _wait_s(1.2)
	print(
		(
			"after restart: state=%d bricks=%d charges=%d"
			% [play.sim.state, play.sim.breakable_left, play.sim.net_charges]
		)
	)
	play.force_charged_net = false
	NeonBricks.easy = true

	# App to the background and back: big play disc, resumes on release.
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _frames(3)
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _frames(3)
	await _shot("09_resume_disc")
	var was_paused: bool = play.paused
	play.resume_disc.press()
	await _frames(2)
	print(
		(
			"pause: paused=%s resume disc shown=%s -> after tap paused=%s"
			% [was_paused, play.resume_disc.visible or was_paused, play.paused]
		)
	)


func _phase_inset() -> void:
	main.fake_safe_top = 120.0
	main.apply_safe_area()
	await _wait_s(1.4)
	await _shot("10_inset_play")
	print("home disc centre %s, hit size %s" % [main.home.disc_center, main.home.size])
	main.open_map()
	await _wait_s(1.2)
	await _shot("11_inset_map")
	main.home.press()


func _phase_tall() -> void:
	await _wait_s(1.4)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	await _shot("12_tall_%dx%d" % [int(vs.x), int(vs.y)])
	print("viewport %s, field frame %s" % [vs, main.field_frame.position])


func _phase_shell() -> void:
	var shown: Array[int] = []
	var free_done: Array[int] = [0]
	NeonBricks.level_card_shown.connect(func(id: int) -> void: shown.append(id))
	NeonBricks.free_levels_finished.connect(func() -> void: free_done[0] += 1)
	main.open_map()
	await _wait_s(0.8)
	await _shot("13_shell_map")
	var ids: Array[int] = []
	for id: int in range(1, 6):
		if main.map.disc_for(id) != null:
			ids.append(id)
	print(
		(
			"shell map levels %s, gear visible=%s, home visible=%s"
			% [ids, main.map.gear.visible, main.home.visible]
		)
	)
	main.open_level(3)
	print("shell play: home visible=%s, sfx enabled=%s" % [main.home.visible, main.sfx.enabled])
	main.play.autopilot = true
	Engine.time_scale = 4.0
	var t: float = 0.0
	while not main.play.card_visible() and t < 400.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	await _wait_s(0.5)
	await _shot("14_shell_level3_card")
	print(
		(
			"shell card: level_card_shown=%s free_levels_finished=%d next shown=%s"
			% [shown, free_done[0], main.play.win_card.has_next()]
		)
	)
	Engine.remove_meta(&"mwm_play_shell")


## Runs a level on autopilot at 3x until `until` is true (or max_s game
## seconds), then takes a shot at normal speed.
func _play_until(
	id: int, easy: bool, until: Callable, max_s: float, shot: String, after_s: float = 0.0
) -> void:
	NeonBricks.easy = easy
	main.open_level(id)
	var play: NbPlay = main.play
	play.autopilot = true
	Engine.time_scale = 3.0
	while not until.call() and play.sim.time < max_s and not play.card_visible():
		await get_tree().process_frame
	Engine.time_scale = 1.0
	if after_s > 0.0:
		await _wait_s(after_s)
	await _frames(2)
	await _shot(shot)
	var s: NbSim = play.sim
	print(
		(
			"%s: L%d t=%.1f combo=%d left=%d/%d balls=%d boss_phase=%d capsules=%d finale=%s"
			% [
				shot,
				id,
				s.time,
				s.combo,
				s.breakable_left,
				s.total_breakable,
				s.balls.size(),
				s.boss_phase,
				s.capsules.size(),
				s.finale_on
			]
		)
	)


func _phase_action() -> void:
	var play: NbPlay = main.play
	await _wait_s(1.0)
	# Combo moment: Vanlig level 12 (Nova chains in a march block).
	await _play_until(12, false, func() -> bool: return play.sim.combo >= 10, 60.0, "20_combo_rush")
	# Ekko: Lett level 4, echo balls in play.
	await _play_until(4, true, func() -> bool: return play.sim.balls.size() >= 3, 90.0, "21_ekko")
	# Boss levels mid-fight.
	await _play_until(
		5,
		true,
		func() -> bool: return play.sim.boss_phase >= 1 and play.sim.combo >= 3,
		90.0,
		"22_boss_l5",
		1.0
	)
	await _play_until(
		10, false, func() -> bool: return play.sim.boss_phase >= 1, 90.0, "23_boss_l10_minions", 1.0
	)
	await _play_until(
		15, false, func() -> bool: return play.sim.boss_phase >= 1, 90.0, "24_boss_l15_march", 1.0
	)
	# Worlds 2 and 3 placeholders.
	await _play_until(
		7,
		false,
		func() -> bool: return play.sim.breakable_left <= play.sim.start_breakable - 8,
		60.0,
		"25_world2_l7_gliders"
	)
	await _play_until(
		13,
		false,
		func() -> bool: return play.sim.pulse_left > 0 or play.sim.time > 25.0,
		60.0,
		"26_world3_l13_neonpuls"
	)
	# Map: all three world pages.
	main.open_map()
	main.map.show_page(1)
	await _wait_s(1.2)
	await _shot("27_map_world1")
	main.map.show_page(2)
	await _wait_s(0.6)
	await _shot("28_map_world2")
	main.map.show_page(3)
	await _wait_s(0.6)
	await _shot("29_map_world3")
	var ids: Array[int] = []
	for id: int in range(1, NbLevels.count() + 1):
		main.map.show_page(NbLevels.world_of(id))
		if main.map.disc_for(id) != null:
			ids.append(id)
	print("map levels reachable over the pages: %s" % [ids])


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _wait_s(s: float) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(s * 1000.0):
		await get_tree().process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir + "/" + name + ".png"
	img.save_png(path)
	print("SHOT ", path)
