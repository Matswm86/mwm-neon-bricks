class_name NbSfx
extends Node

## Small synthesised sound set (GDD 9): no audio files, generated once at
## start as 16-bit mono WAV streams. Pool of players on the "Master" bus
## (MWM Play routes streams without a file path to its Sfx bus).

const RATE: int = 22050
const POOL: int = 8
## Pentatonic steps for brick breaks (one step up per brick since the last
## paddle touch).
const PENTA: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.667, 2.0, 2.25, 2.5, 3.0]

var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	for i: int in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["bop"] = _tone(330.0, 330.0, 0.09, "sine", 0.5)
	_streams["tink"] = _tone(1760.0, 1760.0, 0.12, "bell", 0.35)
	_streams["note"] = _tone(523.25, 523.25, 0.28, "tri", 0.45)
	_streams["ting"] = _tone(1230.0, 1230.0, 0.22, "metal", 0.35)
	_streams["tick"] = _tone(900.0, 700.0, 0.035, "sine", 0.25)
	_streams["bwomm"] = _tone(130.0, 90.0, 0.38, "sine", 0.6)
	_streams["hum"] = _tone(220.0, 330.0, 0.07, "sine", 0.25)
	_streams["zip"] = _tone(600.0, 1400.0, 0.12, "tri", 0.25)
	_streams["whoosh"] = _noise(0.55, 0.35)
	_streams["arp"] = _arp([523.25, 659.25, 783.99, 1046.5], 0.1, 0.4)
	_streams["win"] = _arp(
		[523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5, 1568.0], 0.22, 0.45
	)


func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not enabled or not _streams.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = vol_db
	p.play()


func note(step: int) -> void:
	play("note", PENTA[clampi(step, 0, PENTA.size() - 1)])


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _tone(f0: float, f1: float, dur: float, kind: String, amp: float) -> AudioStreamWAV:
	var n: int = int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var f: float = lerpf(f0, f1, t)
		ph += f / RATE
		var env: float = minf(1.0, t * 40.0) * pow(1.0 - t, 2.0)
		var v: float = 0.0
		match kind:
			"tri":
				v = 1.0 - 4.0 * absf(fposmod(ph, 1.0) - 0.5)
			"bell":
				v = sin(TAU * ph) * 0.7 + sin(TAU * ph * 2.76) * 0.3
			"metal":
				v = sin(TAU * ph) * 0.5 + sin(TAU * ph * 2.58) * 0.3 + sin(TAU * ph * 4.1) * 0.2
			_:
				v = sin(TAU * ph)
		s[i] = v * env * amp
	return _wav(s)


func _noise(dur: float, amp: float) -> AudioStreamWAV:
	var n: int = int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var cut: float = lerpf(0.03, 0.25, sin(t * PI))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * cut
		s[i] = lp * sin(t * PI) * amp * 2.0
	return _wav(s)


func _arp(freqs: Array, step_s: float, amp: float) -> AudioStreamWAV:
	var n: int = int((step_s * freqs.size() + 0.25) * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for k: int in freqs.size():
		var start: int = int(k * step_s * RATE)
		var len_n: int = int(0.3 * RATE)
		var f: float = float(freqs[k])
		for i: int in len_n:
			var j: int = start + i
			if j >= n:
				break
			var t: float = float(i) / float(len_n)
			var v: float = 1.0 - 4.0 * absf(fposmod(f * float(i) / RATE, 1.0) - 0.5)
			s[j] += v * minf(1.0, t * 50.0) * pow(1.0 - t, 2.0) * amp * 0.6
	return _wav(s)
