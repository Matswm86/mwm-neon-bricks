class_name NbSettings
extends Control

## Stand-alone settings panel (GDD 10.2), adult-facing, opened from the map
## gear: Lett / Vanlig, sound, music (note icon), "Mindre bevegelse". Fredoka (SIL OFL), ink on
## card. Difficulty takes effect from the next level start.

signal closed

const CARD := Color(1.000, 0.973, 0.933)
const CARD_EDGE := Color(0.561, 0.514, 0.443)
const INK := Color(0.141, 0.129, 0.114)
const ON := Color(1.0, 0.541, 0.239)
const OFF := Color(1.0, 1.0, 1.0)
const DIM := Color(0.0, 0.0, 0.0, 0.55)
const PANEL := Rect2(90, 400, 900, 1120)
const MUSIC_ICON_AT := Vector2(205, 1110)

var _lett: Button
var _vanlig: Button
var _sound: Button
var _music: Button
var _motion: Button


func _ready() -> void:
	size = Vector2(NbBalance.DESIGN_W, NbBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var th := Theme.new()
	th.default_font = load("res://assets/fonts/Fredoka.ttf")
	th.default_font_size = 44
	theme = th
	_heading("Innstillinger", Vector2(150, 450))
	var close := NbDisc.new()
	close.icon = "close"
	close.disc_radius = 60.0
	close.size = Vector2(160, 160)
	close.position = Vector2(PANEL.end.x - 170, PANEL.position.y + 10)
	close.tapped.connect(func() -> void: closed.emit())
	add_child(close)
	_label("Vanskelighet", Vector2(150, 610))
	_lett = _button("Lett", Rect2(150, 680, 360, 140))
	_vanlig = _button("Vanlig", Rect2(570, 680, 360, 140))
	_lett.pressed.connect(func() -> void: _set_easy(true))
	_vanlig.pressed.connect(func() -> void: _set_easy(false))
	_label("Lyd", Vector2(150, 900))
	_sound = _button("", Rect2(570, 870, 360, 140))
	_sound.pressed.connect(
		func() -> void:
			NeonBricks.set_sfx_on(not NeonBricks.sfx_on)
			refresh()
	)
	# Music row: a note icon instead of a word (drawn in _draw).
	_music = _button("", Rect2(570, 1040, 360, 140))
	_music.pressed.connect(
		func() -> void:
			NeonBricks.set_music_on(not NeonBricks.music_on)
			refresh()
	)
	_label("Mindre bevegelse", Vector2(150, 1240))
	_motion = _button("", Rect2(570, 1210, 360, 140))
	_motion.pressed.connect(
		func() -> void:
			NeonBricks.set_less_motion(not NeonBricks.less_motion)
			refresh()
	)
	var note := Label.new()
	note.text = "Vanskelighet gjelder fra neste bane."
	note.add_theme_font_size_override("font_size", 40)
	note.add_theme_color_override("font_color", INK)
	note.position = Vector2(150, 1400)
	add_child(note)
	visible = false


func open() -> void:
	refresh()
	visible = true


func refresh() -> void:
	_style(_lett, NeonBricks.easy)
	_style(_vanlig, not NeonBricks.easy)
	_sound.text = "På" if NeonBricks.sfx_on else "Av"
	_style(_sound, NeonBricks.sfx_on)
	_music.text = "På" if NeonBricks.music_on else "Av"
	_style(_music, NeonBricks.music_on)
	_motion.text = "På" if NeonBricks.less_motion else "Av"
	_style(_motion, NeonBricks.less_motion)


func _set_easy(on: bool) -> void:
	NeonBricks.set_difficulty(on)
	refresh()


func _heading(t: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_color", INK)
	l.position = at
	add_child(l)


func _label(t: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", INK)
	l.position = at
	add_child(l)


func _button(t: String, r: Rect2) -> Button:
	var b := Button.new()
	b.text = t
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b


func _style(b: Button, on: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ON if on else OFF
		sb.border_color = INK
		sb.set_border_width_all(5)
		sb.set_corner_radius_all(70)
		sb.anti_aliasing = true
		b.add_theme_stylebox_override(state, sb)
	for c: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"
	]:
		b.add_theme_color_override(c, INK)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), DIM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = CARD_EDGE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(56)
	sb.anti_aliasing = true
	draw_style_box(sb, PANEL)
	NbDisc.draw_icon(self, "music", MUSIC_ICON_AT, 56.0, INK)
