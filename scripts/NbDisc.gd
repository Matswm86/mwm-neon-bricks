class_name NbDisc
extends Control

## Round icon button (DESIGN section 4): white disc, ink ring, ink icon drawn
## from shapes (no text, no fonts). Acts on release inside the control; the
## touch area is the whole control rect, the disc can sit anywhere in it.

signal tapped

const INK := Color(0.141, 0.129, 0.114)
const WHITE := Color(1.0, 1.0, 1.0)
const GREEN_SOFT := Color(0.890, 0.941, 0.918)
const NEXT := Color(1.0, 0.541, 0.239)

## Touches are ignored until this tick (holdover after a screen change).
static var block_until_ms: int = 0

@export var icon: String = "play"
@export var disc_radius: float = 100.0
@export var ring_px: float = 6.0
@export var fill: Color = WHITE
## Disc centre inside the control; negative = the middle of the rect.
@export var disc_center: Vector2 = Vector2(-1, -1)

## Idle look rendered once into a texture (one draw call instead of the
## circle, the anti-aliased ring and the icon polygons; QA 2026-10-07
## finding 8). Used only while the disc is idle and its layout unchanged.
var baked: Texture2D
var baked_key: String = ""
var _down: bool = false
var _press_t: float = 99.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


static func block_input(ms: int) -> void:
	block_until_ms = Time.get_ticks_msec() + ms


func center() -> Vector2:
	return size * 0.5 if disc_center.x < 0.0 else disc_center


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if Time.get_ticks_msec() < block_until_ms:
		_down = false
		return
	if mb.pressed:
		_down = true
		_press_t = 0.0
		set_process(true)
		queue_redraw()
		accept_event()
	elif _down:
		_down = false
		queue_redraw()
		accept_event()
		if Rect2(Vector2.ZERO, size).has_point(mb.position):
			_on_tapped()


func _on_tapped() -> void:
	tapped.emit()


## Test hook and Android back: behaves like a release on the disc.
func press() -> void:
	_on_tapped()


func _process(delta: float) -> void:
	_press_t += delta
	queue_redraw()
	if _press_t > 0.12 and not _down:
		set_process(false)


func layout_key() -> String:
	return "%s|%s|%s|%s|%s" % [icon, size, center(), disc_radius, fill]


## Renders the idle look of each disc once in a SubViewport and keeps the
## image. Needs a real renderer (skipped headless).
static func bake(host: Node, discs: Array[NbDisc]) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vps: Array[SubViewport] = []
	for d: NbDisc in discs:
		var vp := SubViewport.new()
		vp.size = Vector2i(ceili(d.size.x), ceili(d.size.y))
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var c := NbDisc.new()
		c.icon = d.icon
		c.disc_radius = d.disc_radius
		c.ring_px = d.ring_px
		c.fill = d.fill
		c.disc_center = d.center()
		c.size = d.size
		vp.add_child(c)
		host.add_child(vp)
		vps.append(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for i: int in discs.size():
		var img: Image = vps[i].get_texture().get_image()
		if img and is_instance_valid(discs[i]):
			discs[i].baked = ImageTexture.create_from_image(img)
			discs[i].baked_key = discs[i].layout_key()
			discs[i].queue_redraw()
		vps[i].queue_free()


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	if not pressed and baked and baked_key == layout_key():
		draw_texture(baked, Vector2.ZERO)
		return
	var k: float = 0.92 if pressed else 1.0
	var c: Vector2 = center()
	var r: float = disc_radius * k
	var f: Color = GREEN_SOFT if pressed and fill == WHITE else fill
	draw_circle(c, r, f)
	draw_arc(c, r - ring_px * 0.5, 0.0, TAU, 64, INK, ring_px, true)
	NbDisc.draw_icon(self, icon, c, r * 0.55, INK)


## Shared icon painter (also used by the map and win card).
static func draw_icon(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color) -> void:
	match name:
		"play", "next":
			var pts := PackedVector2Array(
				[
					c + Vector2(-0.45, -0.6) * s,
					c + Vector2(0.65, 0.0) * s,
					c + Vector2(-0.45, 0.6) * s
				]
			)
			ci.draw_colored_polygon(pts, col)
		"replay":
			# Open "C" with the arrowhead at the top pointing clockwise.
			var a0: float = deg_to_rad(20.0)
			var a1: float = deg_to_rad(285.0)
			ci.draw_arc(c, s * 0.6, a0, a1, 40, col, s * 0.24, true)
			var p: Vector2 = c + Vector2(cos(a1), sin(a1)) * s * 0.6
			var dir := Vector2(-sin(a1), cos(a1))
			var perp := Vector2(-dir.y, dir.x)
			var tri := PackedVector2Array(
				[
					p + dir * s * 0.42,
					p + perp * s * 0.36 - dir * s * 0.05,
					p - perp * s * 0.36 - dir * s * 0.05
				]
			)
			ci.draw_colored_polygon(tri, col)
		"map":
			var p0: Vector2 = c + Vector2(-0.55, 0.5) * s
			var p1: Vector2 = c + Vector2(0.0, 0.0) * s
			var p2: Vector2 = c + Vector2(0.55, -0.5) * s
			ci.draw_line(p0, p2, col, s * 0.14, true)
			for p: Vector2 in [p0, p1, p2]:
				ci.draw_circle(p, s * 0.2, col)
		"home":
			var roof := PackedVector2Array(
				[
					c + Vector2(-0.8, -0.05) * s,
					c + Vector2(0.0, -0.8) * s,
					c + Vector2(0.8, -0.05) * s
				]
			)
			ci.draw_colored_polygon(roof, col)
			ci.draw_rect(Rect2(c + Vector2(-0.55, -0.1) * s, Vector2(1.1, 0.8) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-0.17, 0.25) * s, Vector2(0.34, 0.45) * s), WHITE)
		"gear":
			var pts := PackedVector2Array()
			for i: int in 32:
				var ang: float = TAU * float(i) / 32.0
				var rr: float = 0.78 if (i / 2) % 2 == 0 else 0.58
				pts.append(c + Vector2(cos(ang), sin(ang)) * rr * s)
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c, s * 0.24, WHITE)
		"left", "right":
			var d: float = -1.0 if name == "left" else 1.0
			var pts := PackedVector2Array(
				[
					c + Vector2(-0.25 * d, -0.6) * s,
					c + Vector2(0.35 * d, 0.0) * s,
					c + Vector2(-0.25 * d, 0.6) * s,
				]
			)
			ci.draw_polyline(pts, col, s * 0.22, true)
		"close":
			ci.draw_line(c + Vector2(-0.5, -0.5) * s, c + Vector2(0.5, 0.5) * s, col, s * 0.2, true)
			ci.draw_line(c + Vector2(0.5, -0.5) * s, c + Vector2(-0.5, 0.5) * s, col, s * 0.2, true)
		"music":
			# Two beamed eighth notes.
			var w: float = s * 0.14
			for hx: float in [-0.45, 0.45]:
				var head: Vector2 = c + Vector2(hx, 0.55) * s
				ci.draw_set_transform(head, -0.35, Vector2(1.3, 1.0))
				ci.draw_circle(Vector2.ZERO, s * 0.24, col)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var top: Vector2 = c + Vector2(hx + 0.26, -0.75) * s
				ci.draw_line(head + Vector2(0.26 * s, 0.0), top, col, w, true)
			ci.draw_line(
				c + Vector2(-0.19, -0.75) * s, c + Vector2(0.71, -0.75) * s, col, s * 0.24, true
			)


## Five-point star polygon.
static func star_points(c: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 10:
		var ang: float = -PI * 0.5 + TAU * float(i) / 10.0
		var rr: float = outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	return pts


## Mini picture of a level's bricks (map discs and the win card). The boss
## (K + its body cells) is drawn as one slab with a core ring.
static func draw_level_picture(
	ci: CanvasItem, rows: Array, centre: Vector2, cell: Vector2, world: int = 1
) -> void:
	var colors: Dictionary = NbLevels.row_colors(rows, world)
	var first: int = 99
	var last: int = -1
	for r: int in rows.size():
		if String(rows[r]).replace(".", "") != "":
			first = mini(first, r)
			last = maxi(last, r)
	if last < 0:
		return
	var n_rows: int = last - first + 1
	var origin: Vector2 = centre - Vector2(cell.x * 5.0, cell.y * float(n_rows) * 0.5)
	for r: int in range(first, last + 1):
		var s: String = rows[r]
		for c: int in s.length():
			var ch: String = s[c]
			if ch == "." or ch == "+":
				continue
			if ch == "1" or ch == "2":
				var pc: Vector2 = origin + Vector2(cell.x * (c + 0.5), cell.y * (r - first + 0.5))
				var pcol := Color(0.612, 1.0, 0.784) if ch == "1" else Color(1.0, 0.824, 0.478)
				ci.draw_arc(pc, cell.y * 0.42, 0.0, TAU, 16, pcol, maxf(1.0, cell.x * 0.1))
				continue
			var col: Color = NbLevels.cell_color(ch.to_upper(), colors.get(r, WHITE))
			if ch == "K":
				var br := Rect2(
					origin + Vector2(cell.x * c, cell.y * (r - first)) + cell * 0.08,
					Vector2(cell.x * 3.0, cell.y * 2.0) - cell * 0.16
				)
				ci.draw_rect(br, col)
				ci.draw_rect(br, INK, false, maxf(1.0, cell.x * 0.08))
				ci.draw_arc(br.get_center(), cell.y * 0.55, 0.0, TAU, 24, INK, cell.x * 0.12)
				continue
			var rect := Rect2(
				origin + Vector2(cell.x * c, cell.y * (r - first)) + cell * 0.08, cell * 0.84
			)
			ci.draw_rect(rect, col)
			ci.draw_rect(rect, INK, false, maxf(1.0, cell.x * 0.06))
