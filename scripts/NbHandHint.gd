class_name NbHandHint
extends Control

## Hand icon that slides left-right in the drag zone (GDD 8.2, DESIGN 4):
## 180 px white hand with ink outline at y 1520, 1.6 s loop. Never takes
## touches.

const INK := Color(0.141, 0.129, 0.114)
const SIZE_PX: float = 180.0

var base: Vector2 = Vector2(540.0, 1520.0)
var swing_px: float = 220.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


func restart() -> void:
	_t = 0.0


func _draw() -> void:
	var k: float = sin(_t * TAU / NbBalance.HAND_LOOP_S)
	var c: Vector2 = base + Vector2(k * swing_px, 0.0)
	var s: float = SIZE_PX / 180.0
	# Pointing hand: palm, index finger up, three folded fingers, thumb.
	var parts: Array = [
		[Rect2(-46, -10, 96, 90), 30.0],
		[Rect2(-12, -92, 34, 100), 17.0],
		[Rect2(22, -36, 30, 56), 15.0],
		[Rect2(50, -26, 28, 50), 14.0],
		[Rect2(-74, 0, 52, 30), 15.0],
	]
	for pass_i: int in 2:
		for p: Array in parts:
			var r: Rect2 = p[0]
			var rad: float = float(p[1])
			var grow: float = 7.0 if pass_i == 0 else 0.0
			var rr := Rect2(
				c + r.position * s - Vector2(grow, grow), r.size * s + Vector2(grow, grow) * 2.0
			)
			_round_rect(rr, (rad + grow) * s, INK if pass_i == 0 else Color(1, 1, 1))


func _round_rect(r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
