extends CanvasLayer

## Phone performance readout. Register as autoload "PerfOverlay".
## Hidden by default; three fingers held for about 1 s toggle it, so the
## owner can read FPS, draw calls, triangles and memory on the real device
## while a child's palm or a quick three-finger tap does not (QA 2026-10-06
## finding 6).

const HOLD_S: float = 1.0

var _label: Label
var _touches: Dictionary = {}
var _hold_t: float = -1.0


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(24.0, 96.0)
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_label.add_theme_constant_override("outline_size", 8)
	_label.visible = false
	add_child(_label)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = true
			if _touches.size() >= 3 and _hold_t < 0.0:
				_hold_t = 0.0
		else:
			_touches.erase(touch.index)
			if _touches.size() < 3:
				_hold_t = -1.0


func _process(delta: float) -> void:
	if _hold_t >= 0.0:
		_hold_t += delta
		if _hold_t >= HOLD_S:
			_hold_t = -1.0
			_touches.clear()
			_label.visible = not _label.visible
	if not _label.visible:
		return
	var fps := Engine.get_frames_per_second()
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var ram := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	_label.text = (
		"%d fps  %.1f ms\n%d draws  %dk tris\nVRAM %.0f MB  RAM %.0f MB"
		% [fps, frame_ms, int(draws), int(tris / 1000.0), vram, ram]
	)
