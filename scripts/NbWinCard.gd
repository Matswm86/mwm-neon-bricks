class_name NbWinCard
extends Control

## Win card (GDD 8.3, DESIGN 4): 880 x 910 card, one big star landing, the
## level's brick picture, three icon discs (replay, map, next). No text.
## Never auto-advances. Positions are in the 1080 x 1920 design frame; the
## owner places this control at the frame offset.

signal replay_pressed
signal map_pressed
signal next_pressed

const CARD := Color(1.000, 0.973, 0.933)
const CARD_EDGE := Color(0.561, 0.514, 0.443)
const REWARD := Color(1.000, 0.788, 0.235)
const INK := Color(0.141, 0.129, 0.114)
const SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const CARD_RECT := Rect2(100, 540, 880, 910)

var rows: Array = []
var world: int = 1
var less_motion: bool = false
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
	_t = 0.0
	visible = true
	modulate.a = 1.0 if less_motion else 0.0
	set_process(true)
	queue_redraw()


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
	var sb := StyleBoxFlat.new()
	sb.bg_color = SHADOW
	sb.set_corner_radius_all(56)
	draw_style_box(sb, Rect2(CARD_RECT.position + Vector2(0, 10), CARD_RECT.size))
	sb.bg_color = CARD
	sb.border_color = CARD_EDGE
	sb.set_border_width_all(4)
	sb.anti_aliasing = true
	draw_style_box(sb, CARD_RECT)
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
