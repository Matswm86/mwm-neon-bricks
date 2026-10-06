class_name NbMapScreen
extends Control

## World 1 map page (GDD 8.1): five level discs on a neon road climbing the
## screen between y 400 and 1500, over the world's 3D scene. No padlocks:
## every visible level can be picked; the lowest uncleared one pulses.
## Stand-alone only: a gear disc at the top-right opens the settings.

signal level_chosen(level_id: int)
signal settings_pressed

const ROAD := Color(1.000, 0.180, 0.533)
const ROAD_CORE := Color(1.0, 0.75, 0.88)
## Disc centres for levels 1-5 (bottom to top), clear of the 232 px home
## square, the gear and the wrist strip.
const DISC_POS: Array[Vector2] = [
	Vector2(330, 1430),
	Vector2(740, 1190),
	Vector2(340, 950),
	Vector2(740, 710),
	Vector2(420, 470),
]
const GEAR_HIT: float = 216.0
const TOP_ROW_CLEAR: float = 24.0

var gear: NbDisc
var _discs: Array[NbLevelDisc] = []
var _safe_dy: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(NbBalance.DESIGN_W, NbBalance.DESIGN_H)
	gear = NbDisc.new()
	gear.icon = "gear"
	gear.disc_radius = 80.0
	gear.tapped.connect(func() -> void: settings_pressed.emit())
	add_child(gear)
	set_safe_dy(0.0)


## Rebuilds the discs from the save and the unlock flag.
func refresh() -> void:
	for d: NbLevelDisc in _discs:
		d.queue_free()
	_discs.clear()
	var st: NbState = NeonBricks
	var suggest: int = st.suggested_level()
	for id: int in st.visible_levels():
		var d := NbLevelDisc.new()
		d.level_id = id
		d.rows = NbLevels.get_level(id)["rows"]
		d.cleared = st.is_cleared(id)
		d.suggested = id == suggest
		d.disc_radius = 100.0
		var hit: float = 240.0
		d.size = Vector2(hit, hit)
		d.position = DISC_POS[id - 1] - d.size * 0.5
		d.tapped.connect(func() -> void: level_chosen.emit(id))
		add_child(d)
		_discs.append(d)
	gear.visible = not st.in_shell()
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
