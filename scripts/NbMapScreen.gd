class_name NbMapScreen
extends Control

## World map (GDD 8.1): one page per world, five level discs on a neon
## road climbing the screen between y 400 and 1500, over the world's 3D
## scene. Left / right arrow discs (200 px) at y 1560 change the world; three
## dots between them show the page as a shape. No padlocks: every visible
## level can be picked; the lowest uncleared one pulses. With full_unlock
## false only world 1 levels 1-3 exist (no arrows). Stand-alone only: a gear
## disc at the top-right opens the settings.

signal level_chosen(level_id: int)
signal settings_pressed
signal world_changed(world: int)

const ROAD := Color(1.000, 0.180, 0.533)
const ROAD_CORE := Color(1.0, 0.75, 0.88)
## Disc centres for levels 1-5 of a page (bottom to top), clear of the
## 232 px home square, the gear, the wrist strip and the world arrows (the
## bottom disc sat at 330, 1430 before the arrows came; its hit box would
## overlap the left arrow's).
const DISC_POS: Array[Vector2] = [
	Vector2(390, 1320),
	Vector2(740, 1190),
	Vector2(340, 950),
	Vector2(740, 710),
	Vector2(420, 470),
]
const GEAR_HIT: float = 216.0
const TOP_ROW_CLEAR: float = 24.0
const ARROW_Y: float = 1560.0
const ARROW_R: float = 100.0
const DOT := Color(1.0, 1.0, 1.0)

var gear: NbDisc
var page: int = 1
var arrow_left: NbDisc
var arrow_right: NbDisc
var _discs: Array[NbLevelDisc] = []
var _safe_dy: float = 0.0
var _pages: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(NbBalance.DESIGN_W, NbBalance.DESIGN_H)
	gear = NbDisc.new()
	gear.icon = "gear"
	gear.disc_radius = 80.0
	gear.tapped.connect(func() -> void: settings_pressed.emit())
	add_child(gear)
	arrow_left = _arrow("left", 160.0)
	arrow_right = _arrow("right", 920.0)
	arrow_left.tapped.connect(func() -> void: show_page(page - 1))
	arrow_right.tapped.connect(func() -> void: show_page(page + 1))
	set_safe_dy(0.0)


func _arrow(icon_name: String, x: float) -> NbDisc:
	var d := NbDisc.new()
	d.icon = icon_name
	d.disc_radius = ARROW_R
	var hit: float = ARROW_R * 2.0
	d.size = Vector2(hit, hit)
	d.position = Vector2(x, ARROW_Y) - d.size * 0.5
	add_child(d)
	return d


## Opens the world page of `level_id` (0 = the suggested level's world).
func open_for(level_id: int) -> void:
	var st: NbState = NeonBricks
	var id: int = level_id if level_id > 0 else st.suggested_level()
	if id <= 0:
		id = 1
	page = NbLevels.world_of(id)
	refresh()


func show_page(p: int) -> void:
	var np: int = clampi(p, 1, _pages)
	if np == page:
		return
	page = np
	NbDisc.block_input(NbBalance.HOLDOVER_MS)
	refresh()


## Rebuilds the discs from the save and the unlock flag.
func refresh() -> void:
	for d: NbLevelDisc in _discs:
		d.queue_free()
	_discs.clear()
	var st: NbState = NeonBricks
	var suggest: int = st.suggested_level()
	var ids: Array[int] = st.visible_levels()
	_pages = maxi(1, NbLevels.world_of(ids[ids.size() - 1])) if not ids.is_empty() else 1
	page = clampi(page, 1, _pages)
	arrow_left.visible = _pages > 1 and page > 1
	arrow_right.visible = _pages > 1 and page < _pages
	for id: int in ids:
		if NbLevels.world_of(id) != page:
			continue
		var d := NbLevelDisc.new()
		d.level_id = id
		d.rows = NbLevels.get_level(id)["rows"]
		d.world = page
		d.cleared = st.is_cleared(id)
		d.suggested = id == suggest
		d.disc_radius = 100.0
		var hit: float = 240.0
		d.size = Vector2(hit, hit)
		d.position = DISC_POS[(id - 1) % DISC_POS.size()] - d.size * 0.5
		d.tapped.connect(func() -> void: level_chosen.emit(id))
		add_child(d)
		_discs.append(d)
	gear.visible = not st.in_shell()
	world_changed.emit(page)
	queue_redraw()


func disc_for(id: int) -> NbLevelDisc:
	for d: NbLevelDisc in _discs:
		if d.level_id == id:
			return d
	return null


## Gear sits in the top-right screen corner; its touch area runs to the
## corner and grows down by the camera cutout depth (ball-connect 7ad7d50).
## frame_pos = where this design frame sits on the screen.
func set_safe_dy(dy: float, frame_pos: Vector2 = Vector2.ZERO) -> void:
	_safe_dy = dy
	gear.position = Vector2(NbBalance.DESIGN_W - GEAR_HIT + frame_pos.x, -frame_pos.y)
	gear.size = Vector2(GEAR_HIT, GEAR_HIT + dy)
	gear.disc_center = Vector2(GEAR_HIT - 120.0, 104.0 + dy)
	gear.queue_redraw()


func _draw() -> void:
	if _pages > 1:
		for i: int in _pages:
			var c := Vector2(540.0 + (float(i) - float(_pages - 1) * 0.5) * 60.0, ARROW_Y)
			if i + 1 == page:
				draw_circle(c, 16.0, DOT)
			else:
				draw_arc(c, 14.0, 0.0, TAU, 24, DOT, 4.0, true)
	var n: int = _discs.size()
	if n < 2:
		return
	var pts := PackedVector2Array()
	pts.append(DISC_POS[0] + Vector2(0, 160))
	for i: int in n:
		pts.append(DISC_POS[i])
	var curve := PackedVector2Array()
	for i: int in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		for k: int in 12:
			var t: float = float(k) / 12.0
			var e: float = t * t * (3.0 - 2.0 * t)
			curve.append(Vector2(lerpf(a.x, b.x, e), lerpf(a.y, b.y, t)))
	curve.append(pts[pts.size() - 1])
	draw_polyline(curve, Color(ROAD.r, ROAD.g, ROAD.b, 0.22), 46.0, true)
	draw_polyline(curve, Color(ROAD.r, ROAD.g, ROAD.b, 0.85), 14.0, true)
	draw_polyline(curve, ROAD_CORE, 4.0, true)
