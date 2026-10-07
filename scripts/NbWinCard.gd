class_name NbWinCard
extends Control

## Win card (GDD 8.3, DESIGN 4 and 13.3): 880 x 910 card with a neon rim in
## the world's card-rim colour, one big star landing, the level's brick
## picture, three icon discs (replay, map, next); with no next level the
## two others sit centred. No text.
## Never auto-advances. Positions are in the 1080 x 1920 design frame; the
## owner places this control at the frame offset.

signal replay_pressed
signal map_pressed
signal next_pressed

const CARD := Color(1.000, 0.973, 0.933)
const CARD_EDGE := Color(0.561, 0.514, 0.443)
const REWARD := Color(1.000, 0.788, 0.235)
const INK := Color(0.141, 0.129, 0.114)
const HOT_CORE := Color(1.0, 0.92, 0.95)
const CARD_RECT := Rect2(100, 540, 880, 910)

var rows: Array = []
var world: int = 1
var less_motion: bool = false
var rim: Color = Color(1.000, 0.180, 0.533)
var _card_sb: StyleBoxFlat
var _hot_sb: StyleBoxFlat
var _inner_sb: StyleBoxFlat
var _t: float = 0.0
var _replay: NbDisc
var _map: NbDisc
var _next: NbDisc


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(NbBalance.DESIGN_W, NbBalance.DESIGN_H)
	_replay = _disc("replay", Vector2(270, 1300), 100.0, NbDisc.WHITE)
	_map = _disc("map", Vector2(540, 1300), 100.0, NbDisc.WHITE)
	_next = _disc("next", Vector2(810, 1300), 120.0, NbDisc.NEXT)
	_replay.tapped.connect(func() -> void: replay_pressed.emit())
	_map.tapped.connect(func() -> void: map_pressed.emit())
	_next.tapped.connect(func() -> void: next_pressed.emit())
	visible = false


func _disc(icon_name: String, c: Vector2, r: float, f: Color) -> NbDisc:
	var d := NbDisc.new()
	d.icon = icon_name
	d.disc_radius = r
	d.fill = f
	var hit: float = r * 2.0 + 20.0
	d.position = c - Vector2(hit, hit) * 0.5
	d.size = Vector2(hit, hit)
	add_child(d)
	return d


func show_card(level_rows: Array, has_next: bool, world_id: int = 1) -> void:
	rows = level_rows
	world = world_id
	_next.visible = has_next
	# QA 2026-10-06 finding 5: centre replay and map when there is no next.
	_place(_replay, Vector2(270 if has_next else 360, 1300))
	_place(_map, Vector2(540 if has_next else 720, 1300))
	rim = NbWorldLook.get_look(world_id)["card_rim"]
	_build_styles()
	_t = 0.0
	visible = true
	modulate.a = 1.0 if less_motion else 0.0
	set_process(true)
	queue_redraw()


func _place(d: NbDisc, c: Vector2) -> void:
	d.position = c - d.size * 0.5


## DESIGN 13.3: three StyleBoxFlats, built once per card (not per frame).
func _build_styles() -> void:
	_card_sb = StyleBoxFlat.new()
	_card_sb.bg_color = CARD
	_card_sb.set_corner_radius_all(56)
	_card_sb.border_color = rim
	_card_sb.set_border_width_all(6)
	_card_sb.shadow_color = Color(rim, 0.55)
	_card_sb.shadow_size = 28
	_card_sb.shadow_offset = Vector2.ZERO
	_card_sb.anti_aliasing = true
	_hot_sb = StyleBoxFlat.new()
	_hot_sb.draw_center = false
	_hot_sb.set_corner_radius_all(54)
	_hot_sb.border_color = HOT_CORE
	_hot_sb.set_border_width_all(2)
	_hot_sb.anti_aliasing = true
	_inner_sb = StyleBoxFlat.new()
	_inner_sb.draw_center = false
	_inner_sb.set_corner_radius_all(50)
	_inner_sb.border_color = CARD_EDGE
	_inner_sb.set_border_width_all(3)
	_inner_sb.anti_aliasing = true


func hide_card() -> void:
	visible = false
	set_process(false)


func has_next() -> bool:
	return _next.visible


func _process(delta: float) -> void:
	_t += delta
	if not less_motion:
		modulate.a = clampf(_t / NbBalance.WIN_CARD_FADE_S, 0.0, 1.0)
	queue_redraw()
	if _t > 1.0:
		set_process(false)


func _draw() -> void:
	# Dim the scene behind the card (wincard mock).
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(0.0, 0.0, 0.0, 0.5))
	if _card_sb == null:
		_build_styles()
	draw_style_box(_card_sb, CARD_RECT)
	draw_style_box(_hot_sb, CARD_RECT.grow(-2.0))
	draw_style_box(_inner_sb, CARD_RECT.grow(-6.0))
	# Star lands 0.6 -> 1.08 -> 1.0 over 0.25 s.
	var k: float = clampf(_t / 0.25, 0.0, 1.0)
	var sc: float = 1.0
	if not less_motion:
		sc = lerpf(0.6, 1.08, k / 0.7) if k < 0.7 else lerpf(1.08, 1.0, (k - 0.7) / 0.3)
	var c := Vector2(540, 800)
	var outer: float = 180.0 * sc
	var pts: PackedVector2Array = NbDisc.star_points(c, outer, outer * 0.48)
	draw_colored_polygon(pts, REWARD)
	pts.append(pts[0])
	draw_polyline(pts, INK, 10.0, true)
	NbDisc.draw_level_picture(self, rows, Vector2(540, 1075), Vector2(30, 18), world)
