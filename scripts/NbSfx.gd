class_name NbSfx
extends Node

## Sound effects (GDD 9): pre-rendered .ogg files in res://assets/sfx/, made
## by tools/render_sfx.py (own synthesis plus Kenney CC0 layers, see
## CREDITS.md). One fixed pool of players, no allocation per hit. Each play
## picks a random variant and a small random pitch shift so repeated hits do
## not tire the ear. Players stay on the "Master" bus (MWM Play routes streams
## outside a "music" path to its Sfx bus).

## Emitted when the win stinger starts, with its length in seconds, so the
## music can duck under it.
signal stinger_started(seconds: float)

const POOL: int = 12
const DIR := "res://assets/sfx/"
## Pentatonic steps for brick breaks (one step up per brick since the last
## paddle touch).
const PENTA: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.667, 2.0, 2.25, 2.5, 3.0]
## Call-site name -> files (variants) and the random pitch spread (+- share).
const SOUNDS: Dictionary = {
	"bop": [["nb_bop_1", "nb_bop_2", "nb_bop_3"], 0.03],
	"tink": [["nb_tink_1", "nb_tink_2", "nb_tink_3"], 0.04],
	"note": [["nb_chime"], 0.0],
	"shatter": [["nb_shatter_1", "nb_shatter_2", "nb_shatter_3"], 0.08],
	"ting": [["nb_ting_1", "nb_ting_2"], 0.03],
	"tick": [["nb_tick_1", "nb_tick_2", "nb_tick_3"], 0.06],
	"bwomm": [["nb_bwomm"], 0.04],
	"hum": [["nb_hum"], 0.05],
	"zip": [["nb_zip"], 0.06],
	"whoosh": [["nb_whoosh"], 0.0],
	"arp": [["nb_komet"], 0.0],
	"win": [["nb_win"], 0.0],
}
const SHATTER_DB: float = -5.0
const WIN_DUCK_S: float = 3.0
## Level of every effect before the player's slider. The files peak near
## -5 dBFS; with the default slider (0.6) their peaks land around -19 dB,
## a few dB over the music body instead of 20 dB over it.
const BASE_DB: float = -10.0

var enabled: bool = true
## Effects slider, 0..1 (linear), from NeonBricks.sfx_volume.
var volume: float = 1.0
var _streams: Dictionary = {}
var _spread: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i: int in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key: String in SOUNDS:
		var entry: Array = SOUNDS[key]
		var list: Array[AudioStream] = []
		for file: String in entry[0]:
			var s: AudioStream = load(DIR + file + ".ogg") as AudioStream
			if s != null:
				list.append(s)
			else:
				push_warning("NbSfx: missing " + file)
		_streams[key] = list
		_spread[key] = float(entry[1])


func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not enabled or volume <= 0.01 or not _streams.has(name):
		return
	var list: Array[AudioStream] = _streams[name]
	if list.is_empty():
		return
	var spread: float = _spread[name]
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = list[_rng.randi() % list.size()]
	p.pitch_scale = clampf(pitch * (1.0 + _rng.randf_range(-spread, spread)), 0.25, 4.0)
	p.volume_db = vol_db + BASE_DB + linear_to_db(volume)
	p.play()
	if name == "win":
		stinger_started.emit(WIN_DUCK_S)


## Brick break: a glass chime on the rising pentatonic ladder plus a glass
## shatter layer.
func note(step: int) -> void:
	play("note", PENTA[clampi(step, 0, PENTA.size() - 1)])
	play("shatter", 1.0, SHATTER_DB)
