extends Node
## Efectos de sonido generados por síntesis (ondas seno/cuadrada), sin
## archivos de audio externos -- consistente con el resto de la
## plataforma (arte procedural, fichas dibujadas, etc). Respeta el
## volumen guardado en SettingsManager.

const SAMPLE_RATE := 22050
const POOL_SIZE := 6

var _players: Array = []
var _next_player: int = 0
var _cache: Dictionary = {}


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _get_player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	return p


func _make_tone(freq: float, duration: float, wave: String = "sine") -> AudioStreamWAV:
	var key: String = "tone_%s_%s_%s" % [freq, duration, wave]
	if _cache.has(key):
		return _cache[key]

	var sample_count: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = 1.0 - float(i) / float(sample_count)
		var sample: float
		if wave == "square":
			sample = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
		else:
			sample = sin(TAU * freq * t)
		sample *= envelope * 0.5
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	_cache[key] = stream
	return stream


func _make_arpeggio(freqs: Array, note_duration: float) -> AudioStreamWAV:
	var key: String = "arp_%s_%s" % [str(freqs), note_duration]
	if _cache.has(key):
		return _cache[key]

	var samples_per_note: int = int(SAMPLE_RATE * note_duration)
	var data := PackedByteArray()
	data.resize(samples_per_note * freqs.size() * 2)
	var idx := 0
	for freq: float in freqs:
		for i in range(samples_per_note):
			var t: float = float(i) / SAMPLE_RATE
			var envelope: float = 1.0 - float(i) / float(samples_per_note)
			var sample: float = sin(TAU * freq * t) * envelope * 0.5
			data.encode_s16(idx * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))
			idx += 1

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	_cache[key] = stream
	return stream


func _play(stream: AudioStreamWAV, volume_key: String) -> void:
	var vol: float = SettingsManager.get_value(volume_key, 0.8)
	if vol <= 0.0:
		return
	var p: AudioStreamPlayer = _get_player()
	p.stream = stream
	p.volume_db = linear_to_db(clamp(vol, 0.02, 1.0))
	p.play()


func play_click() -> void:
	_play(_make_tone(740.0, 0.05, "square"), "sfx_volume")


func play_place() -> void:
	_play(_make_tone(420.0, 0.08, "sine"), "sfx_volume")


func play_error() -> void:
	_play(_make_tone(180.0, 0.1, "square"), "sfx_volume")


func play_win() -> void:
	_play(_make_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.12), "sfx_volume")


func play_lose() -> void:
	_play(_make_arpeggio([392.0, 329.63, 261.63], 0.18), "sfx_volume")
