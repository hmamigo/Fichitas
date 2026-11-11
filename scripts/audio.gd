class_name GameAudio
extends Node
## Efectos de sonido sintetizados en memoria (sin archivos): giro, acierto, error y final.
## Las notas son cortas y suaves; el volumen general se ajusta en cada reproductor.

const RATE := 22050
const VOICES := 4

var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0

func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -7.0
		add_child(p)
		_players.append(p)

func play(name: String) -> void:
	if not enabled or _players.is_empty():
		return
	if not _streams.has(name):
		_streams[name] = _make(name)
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()

## Cada efecto es una lista de notas [frecuencia, duración, amplitud].
func _make(name: String) -> AudioStreamWAV:
	var notes: Array = []
	match name:
		"flip":
			notes = [[520.0, 0.055, 0.16]]
		"ok":
			notes = [[784.0, 0.085, 0.15], [1174.7, 0.16, 0.14]]
		"err":
			notes = [[233.1, 0.09, 0.16], [174.6, 0.15, 0.15]]
		"win":
			notes = [[523.3, 0.10, 0.14], [659.3, 0.10, 0.14], [784.0, 0.10, 0.14], [1046.5, 0.34, 0.15]]
		_:
			return null
	return _wav(notes)

func _wav(notes: Array) -> AudioStreamWAV:
	var total: int = 0
	for n in notes:
		total += int(float(n[1]) * RATE) + 1
	var data := PackedByteArray()
	data.resize(total * 2)
	var idx: int = 0
	for n in notes:
		var freq: float = n[0]
		var dur: float = n[1]
		var amp: float = n[2]
		var count: int = int(dur * RATE)
		for i in count:
			var t: float = float(i) / float(RATE)
			var env: float = minf(1.0, t / 0.006) * exp(-3.4 * t / dur)
			var ph: float = TAU * freq * t
			var v: float = sin(ph) + 0.22 * sin(ph * 2.0)
			data.encode_s16(idx, int(clampf(v * env * amp, -1.0, 1.0) * 32767.0))
			idx += 2
		idx += 2  # un silencio mínimo entre notas
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
