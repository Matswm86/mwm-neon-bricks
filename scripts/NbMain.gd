class_name NbMain
extends Node

## Root of MWM Neon Bricks: the 3D world, the UI layer, the world 1 map and
## the play controller. First ever launch opens level 1 directly (GDD 8.2);
## later launches open the map. Inside MWM Play (Engine meta
## "mwm_play_shell") the own home disc, gear and back handling are left to
## the shell.

const TOP_ROW_CLEAR: float = 36.0
const HOME_HIT: float = 216.0

## Test hook: a fake top safe-area inset in window px; < 0 = ask the display.
var fake_safe_top: float = -1.0
var screen: String = ""

var world: NbWorld
var sfx: NbSfx
var music: NbMusic
var ui: CanvasLayer
var screen_root: Control
var field_frame: Control
var center_frame: Control
var map: NbMapScreen
var settings: NbSettings
var play: NbPlay
var home: NbHomeDisc


func _ready() -> void:
	world = NbWorld.new()
	add_child(world)
	sfx = NbSfx.new()
	add_child(sfx)
	music = NbMusic.new()
	add_child(music)
	sfx.stinger_started.connect(music.duck)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen_root)
	field_frame = _frame()
	center_frame = _frame()
	map = NbMapScreen.new()
	center_frame.add_child(map)
	map.level_chosen.connect(open_level)
	map.settings_pressed.connect(_open_settings)
	play = NbPlay.new()
	add_child(play)
	play.setup(world, sfx, field_frame, center_frame, screen_root)
	play.map_requested.connect(open_map)
	play.level_started.connect(music.play_level)
	settings = NbSettings.new()
	center_frame.add_child(settings)
	settings.closed.connect(func() -> void: settings.visible = false)
	home = NbHomeDisc.new()
	home.icon = "home"
	home.disc_radius = 68.0
	home.ring_px = 5.0
	home.confirmed.connect(open_map)
	screen_root.add_child(home)
	NeonBricks.settings_changed.connect(_apply_settings)
	get_viewport().size_changed.connect(_layout)
	_apply_settings()
	_layout()
	if NeonBricks.first_launch:
		open_level(1)
	else:
		open_map()


func _frame() -> Control:
	var c := Control.new()
	c.size = Vector2(NbBalance.DESIGN_W, NbBalance.DESIGN_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(c)
	return c


func _apply_settings() -> void:
	sfx.enabled = NeonBricks.sfx_on or NeonBricks.in_shell()
	music.set_enabled(NeonBricks.music_on)
	world.set_less_motion(NeonBricks.less_motion)
	var shell: bool = NeonBricks.in_shell()
	home.visible = screen == "play" and not shell
	if map:
		map.gear.visible = not shell


func _layout() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	field_frame.position = Vector2((vs.x - NbBalance.DESIGN_W) * 0.5, vs.y - NbBalance.DESIGN_H)
	center_frame.position = Vector2(
		(vs.x - NbBalance.DESIGN_W) * 0.5, (vs.y - NbBalance.DESIGN_H) * 0.5
	)
	apply_safe_area()


## Home disc and gear move below a camera cutout; their touch areas still run
## to the screen corner (copied from ball-connect 7ad7d50).
func apply_safe_area() -> void:
	var dy: float = maxf(0.0, safe_top_inset() - TOP_ROW_CLEAR)
	home.position = Vector2.ZERO
	home.size = Vector2(HOME_HIT, HOME_HIT + dy)
	home.disc_center = Vector2(104.0, 104.0 + dy)
	home.queue_redraw()
	map.set_safe_dy(dy, center_frame.position)


## Depth of the top screen cutout in viewport px (0 on desktop and on phones
## without a cutout in the drawn area).
func safe_top_inset() -> float:
	var top_px: float = fake_safe_top
	if top_px < 0.0:
		if not OS.has_feature("mobile"):
			return 0.0
		top_px = float(DisplayServer.get_display_safe_area().position.y)
	var win: Vector2i = DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return maxf(0.0, top_px * get_viewport().get_visible_rect().size.y / float(win.y))


func open_level(id: int) -> void:
	screen = "play"
	settings.visible = false
	map.visible = false
	play.start_level(id)
	_apply_settings()


func open_map() -> void:
	screen = "map"
	play.stop()
	world.show_gameplay(false)
	world.start_intro()
	music.play_map()
	map.refresh()
	map.visible = true
	settings.visible = false
	NbDisc.block_input(NbBalance.HOLDOVER_MS)
	_apply_settings()
	NeonBricks.save_game()
	set_process(true)


func _open_settings() -> void:
	settings.open()


func _process(delta: float) -> void:
	if screen == "map":
		world.sync_camera(delta)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			NeonBricks.save_game()
			if play:
				play.pause()
		NOTIFICATION_APPLICATION_RESUMED:
			if play:
				play.show_resume()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()


func _on_back() -> void:
	if NeonBricks.in_shell():
		return
	if screen == "play":
		if play.card_visible():
			open_map()
		else:
			home.press()
	elif settings.visible:
		settings.visible = false
	else:
		NeonBricks.save_game()
		get_tree().quit()
