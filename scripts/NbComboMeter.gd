class_name NbComboMeter
extends Control

## Combo meter "Kjede" (GDD 15.3.1): 10 segments on the top rail, x 290-1040,
## y 248-272 in the 1080 x 1920 design frame (clear of the 232 px home
## square, nothing tappable). Segment n lights at combo >= n, so the count is
## a shape. At 10+ ("Neonrush") all segments get a steady outline glow, never
## a flash. A dropped combo drains right to left over 0.3 s.

const OFF := Color(1.0, 1.0, 1.0, 0.10)
const EDGE := Color(1.0, 1.0, 1.0, 0.28)
const GLOW := Color(1.000, 0.788, 0.235)
const TIER_COLS: Array[Color] = [
	Color(0.180, 0.902, 1.0),
	Color(1.000, 0.541, 0.239),
	Color(1.000, 0.960, 0.820),
]
const GAP: float = 8.0

var less_motion: bool = false
var _combo: int = 0
## Lit segments shown (drains toward 0 after a drop).
var _shown: float = 0.0
var _pop_seg: int = -1
var _pop_t: float = 99.0
var _rush_t: float = 0.0
## Reused edge buffer (no allocation per redraw once grown).
var _edges := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(NbBalance.DESIGN_W, NbBalance.DESIGN_H)
	set_process(true)


func reset() -> void:
	_combo = 0
	_shown = 0.0
	_pop_t = 99.0
	_rush_t = 0.0
	queue_redraw()


func set_combo(c: int) -> void:
	if c == _combo:
		return
	if c > _combo and c <= NbBalance.COMBO_SEGMENTS:
		_pop_seg = c - 1
		_pop_t = 0.0
	_combo = c
	if c > 0:
		_shown = float(mini(c, NbBalance.COMBO_SEGMENTS))
	queue_redraw()


func drop() -> void:
	_combo = 0
	if less_motion:
		_shown = 0.0
	queue_redraw()


func combo() -> int:
	return _combo


func _process(delta: float) -> void:
	if not visible:
		return
	var dirty: bool = false
	if _combo == 0 and _shown > 0.0:
		_shown = maxf(
			0.0, _shown - float(NbBalance.COMBO_SEGMENTS) * delta / NbBalance.COMBO_DRAIN_S
		)
		dirty = true
	if _pop_t < NbBalance.COMBO_POP_S:
		_pop_t += delta
		dirty = true
	var rush: bool = _combo >= NbBalance.COMBO_TIER_RUSH
	var rt: float = clampf(_rush_t + (delta if rush else -delta) / 0.3, 0.0, 1.0)
	if rt != _rush_t:
		_rush_t = rt
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	var r: Rect2 = NbBalance.COMBO_METER_RECT
	var n: int = NbBalance.COMBO_SEGMENTS
	var w: float = (r.size.x - GAP * float(n - 1)) / float(n)
	var tier: int = 0
	if _combo >= NbBalance.COMBO_TIER_RUSH:
		tier = 2
	elif _combo >= NbBalance.COMBO_TIER_WARM:
		tier = 1
	var lit_col: Color = TIER_COLS[tier]
	# Grouped by primitive so the canvas batches them (QA 2026-10-07 finding
	# 1): all fills, then all lit parts, then every edge in one multiline,
	# then the Neonrush glow in one multiline.
	var segs: Array[Rect2] = []
	for i: int in n:
		var seg := Rect2(r.position + Vector2((w + GAP) * float(i), 0.0), Vector2(w, r.size.y))
		if i == _pop_seg and _pop_t < NbBalance.COMBO_POP_S and not less_motion:
			var k: float = _pop_t / NbBalance.COMBO_POP_S
			var sc: float = lerpf(NbBalance.COMBO_POP_SCALE, 1.0, absf(k * 2.0 - 1.0))
			seg = seg.grow_individual(
				w * (sc - 1.0) * 0.5,
				r.size.y * (sc - 1.0) * 0.5,
				w * (sc - 1.0) * 0.5,
				r.size.y * (sc - 1.0) * 0.5
			)
		segs.append(seg)
		draw_rect(seg, OFF)
	for i: int in n:
		var lit: float = clampf(_shown - float(i), 0.0, 1.0)
		if lit > 0.0:
			draw_rect(
				Rect2(segs[i].position, Vector2(segs[i].size.x * lit, segs[i].size.y)), lit_col
			)
	_edges.clear()
	for seg: Rect2 in segs:
		_add_box(_edges, seg)
	draw_multiline(_edges, EDGE, 2.0)
	if _rush_t > 0.0:
		_edges.clear()
		for seg: Rect2 in segs:
			_add_box(_edges, seg.grow(3.0))
		draw_multiline(_edges, Color(GLOW.r, GLOW.g, GLOW.b, 0.85 * _rush_t), 3.0)


static func _add_box(pts: PackedVector2Array, b: Rect2) -> void:
	var p0: Vector2 = b.position
	var p1 := Vector2(b.end.x, b.position.y)
	var p2: Vector2 = b.end
	var p3 := Vector2(b.position.x, b.end.y)
	pts.append_array(PackedVector2Array([p0, p1, p1, p2, p2, p3, p3, p0]))
