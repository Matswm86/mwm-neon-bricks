class_name NbLevelDisc
extends NbDisc

## Map level disc (DESIGN 4): dark glass disc, 6 px cyan ring, the level's
## brick picture inside, a sun-yellow star at the top-right once cleared. The
## suggested level's ring pulses at 1 Hz between 60% and 100% (never a flash).

const GLASS := Color(0.110, 0.102, 0.200)
const CYAN := Color(0.180, 0.902, 1.0)
const REWARD := Color(1.000, 0.788, 0.235)

var level_id: int = 1
var rows: Array = []
var world: int = 1
var cleared: bool = false
var suggested: bool = false
var _pulse_t: float = 0.0


## Only the suggested disc animates (its 1 Hz pulse); the others redraw on
## press only, like a plain NbDisc (QA 2026-10-06 finding 9).
func _ready() -> void:
	super._ready()
	set_process(suggested)


func _process(delta: float) -> void:
	_press_t += delta
	_pulse_t += delta
	queue_redraw()
	if not suggested and _press_t > 0.12 and not _down:
		set_process(false)


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	var k: float = 0.92 if pressed else 1.0
	var c: Vector2 = center()
	var r: float = disc_radius * k
	draw_circle(c, r + 10.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.12))
	draw_circle(c, r, GLASS)
	var a: float = 1.0
	if suggested:
		a = 0.8 + 0.2 * sin(_pulse_t * TAU)
	draw_arc(c, r - 3.0, 0.0, TAU, 64, Color(CYAN.r, CYAN.g, CYAN.b, a), 6.0, true)
	NbDisc.draw_level_picture(self, rows, c, Vector2(14, 10) * k, world)
	if cleared:
		var sc: Vector2 = c + Vector2(r * 0.72, -r * 0.72)
		var pts: PackedVector2Array = NbDisc.star_points(sc, 40.0, 19.0)
		draw_colored_polygon(pts, REWARD)
		pts.append(pts[0])
		draw_polyline(pts, INK, 5.0, true)
