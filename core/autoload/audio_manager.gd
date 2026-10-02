extends Node
## Sonido de toda la plataforma, 100% sintetizado (sin archivos de audio:
## no pesa en la descarga web ni depende de licencias). Dos partes:
##
## 1. Efectos estilo "sfxr" (como los de los arcades de 8 bits): ondas
##    cuadrada/sierra/triángulo/ruido con barrido de tono, vibrato y
##    envolvente. Se generan una vez y se guardan en caché.
## 2. Música chiptune por estilo (melodía, bajo, arpegio y batería) generada
##    a partir de una progresión de acordes y una semilla fija, así cada
##    estilo suena siempre igual. Se genera por partes a lo largo de varios
##    cuadros para no trabar el juego, y queda en bucle.
##
## Respeta los volúmenes de SettingsManager ("sfx_volume", "music_volume") y
## la vibración ("vibration").

const SAMPLE_RATE := 22050
const POOL_SIZE := 8
const MUSIC_GAIN := 0.32

var _players: Array = []
var _next_player: int = 0
var _cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_cache: Dictionary = {}
var _music_style: String = ""
var _music_request: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # la música sigue en pausas (p. ej. la guía de gestos)
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)


func _get_player() -> AudioStreamPlayer:
	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = _players[(_next_player + i) % POOL_SIZE]
		if not p.playing:
			_next_player = (_next_player + i + 1) % POOL_SIZE
			return p
	var q: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	return q


func _play(stream: AudioStreamWAV, volume_key: String, gain: float = 1.0) -> void:
	var vol: float = float(SettingsManager.get_value(volume_key, 0.8)) * gain
	if vol <= 0.0:
		return
	var p: AudioStreamPlayer = _get_player()
	p.stream = stream
	p.volume_db = linear_to_db(clamp(vol, 0.02, 1.0))
	p.play()


# ---------------------------------------------------------------- síntesis --
static func _osc(wave: String, phase: float, duty: float, rng: RandomNumberGenerator) -> float:
	match wave:
		"square":
			return 1.0 if fposmod(phase, 1.0) < duty else -1.0
		"saw":
			return fposmod(phase, 1.0) * 2.0 - 1.0
		"tri":
			var f: float = fposmod(phase, 1.0)
			return 4.0 * f - 1.0 if f < 0.5 else 3.0 - 4.0 * f
		"noise":
			return rng.randf_range(-1.0, 1.0)
	return sin(phase * TAU)


## Un efecto: lista de capas que suenan juntas. Cada capa:
##   wave, f0 -> f1 (barrido exponencial), dur, attack, vol, duty,
##   vib (Hz), vib_depth (fracción), delay (s), steps (arpegio: lista de
##   multiplicadores de f0 que avanzan en el tiempo).
func _sfx(key: String, layers: Array) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var total := 0.0
	for l: Dictionary in layers:
		total = maxf(total, l.get("delay", 0.0) + l["dur"])
	var n: int = int(total * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for l: Dictionary in layers:
		var start: int = int(l.get("delay", 0.0) * SAMPLE_RATE)
		var count: int = int(l["dur"] * SAMPLE_RATE)
		var f0: float = l["f0"]
		var f1: float = l.get("f1", f0)
		var attack: float = l.get("attack", 0.005)
		var vol: float = l.get("vol", 0.5)
		var duty: float = l.get("duty", 0.5)
		var vib: float = l.get("vib", 0.0)
		var vib_depth: float = l.get("vib_depth", 0.0)
		var steps: Array = l.get("steps", [])
		var phase := 0.0
		var noise_hold := 0.0
		var noise_t := 0.0
		for i in range(count):
			var t: float = float(i) / SAMPLE_RATE
			var k: float = float(i) / float(count)
			var f: float = f0 * pow(f1 / f0, k)
			if not steps.is_empty():
				f = f0 * float(steps[mini(int(k * steps.size()), steps.size() - 1)])
			if vib > 0.0:
				f *= 1.0 + vib_depth * sin(TAU * vib * t)
			phase += f / SAMPLE_RATE
			var s: float
			if l["wave"] == "noise":
				# Ruido "de 8 bits": se sostiene un valor según el tono.
				noise_t += f / SAMPLE_RATE
				if noise_t >= 1.0:
					noise_t -= 1.0
					noise_hold = rng.randf_range(-1.0, 1.0)
				s = noise_hold
			else:
				s = _osc(l["wave"], phase, duty, rng)
			var env: float = minf(t / attack, 1.0) * pow(1.0 - k, l.get("curve", 1.6))
			var idx: int = start + i
			if idx < n:
				buf[idx] += s * env * vol
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	_cache[key] = stream
	return stream


# ---------------------------------------------------------------- efectos --
func play_click() -> void:
	_play(_sfx("click", [{"wave": "square", "f0": 880.0, "f1": 1320.0, "dur": 0.05, "vol": 0.35, "duty": 0.25}]), "sfx_volume")


func play_place() -> void:
	_play(_sfx("place", [{"wave": "tri", "f0": 660.0, "f1": 330.0, "dur": 0.09, "vol": 0.6},
		{"wave": "noise", "f0": 6000.0, "dur": 0.03, "vol": 0.15}]), "sfx_volume")


func play_error() -> void:
	_play(_sfx("error", [{"wave": "saw", "f0": 220.0, "f1": 150.0, "dur": 0.2, "vol": 0.35, "vib": 30.0, "vib_depth": 0.06}]), "sfx_volume")
	vibrate(70)


func play_win() -> void:
	_play(_sfx("win", [{"wave": "square", "f0": 523.25, "dur": 0.6, "vol": 0.3, "duty": 0.25, "curve": 0.6, "steps": [1.0, 1.26, 1.5, 2.0, 2.0, 2.52]},
		{"wave": "tri", "f0": 261.63, "dur": 0.6, "vol": 0.45, "curve": 0.8, "steps": [1.0, 1.0, 1.5, 1.5, 2.0, 2.0]}]), "sfx_volume")
	vibrate(120)


func play_lose() -> void:
	_play(_sfx("lose", [{"wave": "square", "f0": 440.0, "dur": 0.75, "vol": 0.3, "duty": 0.5, "curve": 0.7, "steps": [1.0, 0.94, 0.84, 0.75, 0.63, 0.5]},
		{"wave": "tri", "f0": 220.0, "f1": 90.0, "dur": 0.75, "vol": 0.4}]), "sfx_volume")
	vibrate(300)


func play_power() -> void:
	_play(_sfx("power", [{"wave": "square", "f0": 300.0, "f1": 1400.0, "dur": 0.32, "vol": 0.3, "duty": 0.25, "vib": 18.0, "vib_depth": 0.08, "curve": 0.8}]), "sfx_volume")
	vibrate(50)


func play_alert() -> void:
	_play(_sfx("alert", [{"wave": "square", "f0": 880.0, "dur": 0.48, "vol": 0.3, "curve": 0.3, "steps": [1.0, 0.75, 1.0, 0.75]}]), "sfx_volume")
	vibrate(90)


## Golpe grave de "latido" (Asteroids): dos notas alternadas.
func play_beat(high: bool) -> void:
	_play(_sfx("beat_%s" % high, [{"wave": "square", "f0": 110.0 if high else 98.0, "f1": 70.0, "dur": 0.1, "vol": 0.55}]), "sfx_volume")


func play_laser() -> void:
	_play(_sfx("laser", [{"wave": "square", "f0": 1400.0, "f1": 280.0, "dur": 0.14, "vol": 0.25, "duty": 0.3}]), "sfx_volume", 0.8)


func play_explosion() -> void:
	_play(_sfx("explosion", [{"wave": "noise", "f0": 1800.0, "f1": 200.0, "dur": 0.45, "vol": 0.6, "curve": 1.2},
		{"wave": "sine", "f0": 120.0, "f1": 40.0, "dur": 0.3, "vol": 0.5}]), "sfx_volume")


func play_jump() -> void:
	_play(_sfx("jump", [{"wave": "square", "f0": 320.0, "f1": 760.0, "dur": 0.14, "vol": 0.3, "duty": 0.25}]), "sfx_volume")


func play_coin() -> void:
	_play(_sfx("coin", [{"wave": "square", "f0": 988.0, "dur": 0.22, "vol": 0.28, "duty": 0.5, "curve": 1.0, "steps": [1.0, 1.335, 1.335, 1.335]}]), "sfx_volume")


func play_pop() -> void:
	_play(_sfx("pop", [{"wave": "sine", "f0": 900.0, "f1": 180.0, "dur": 0.09, "vol": 0.55},
		{"wave": "noise", "f0": 8000.0, "dur": 0.04, "vol": 0.2}]), "sfx_volume")


func play_hit() -> void:
	_play(_sfx("hit", [{"wave": "noise", "f0": 3000.0, "f1": 800.0, "dur": 0.1, "vol": 0.45},
		{"wave": "square", "f0": 200.0, "f1": 90.0, "dur": 0.1, "vol": 0.3}]), "sfx_volume")


func play_kick() -> void:
	_play(_sfx("kick", [{"wave": "tri", "f0": 180.0, "f1": 60.0, "dur": 0.16, "vol": 0.7},
		{"wave": "noise", "f0": 5000.0, "f1": 1500.0, "dur": 0.06, "vol": 0.25}]), "sfx_volume")


# ------------------------------------------------------------------ música --
## Estilos: escala (MIDI de la raíz + intervalos), progresión (grados),
## tempo, semilla de la melodía y qué tan "llena" va la batería.
const MUSIC_STYLES := {
	"arcade": {"root": 60, "scale": [0, 2, 4, 5, 7, 9, 11], "prog": [0, 4, 5, 3], "bpm": 140, "seed": 7, "drums": 2, "lead": "square"},
	"espacio": {"root": 57, "scale": [0, 2, 3, 5, 7, 8, 10], "prog": [0, 5, 3, 4], "bpm": 124, "seed": 21, "drums": 1, "lead": "saw"},
	"aventura": {"root": 62, "scale": [0, 2, 3, 5, 7, 9, 10], "prog": [0, 3, 6, 4], "bpm": 132, "seed": 13, "drums": 2, "lead": "square"},
	"dulce": {"root": 65, "scale": [0, 2, 4, 5, 7, 9, 11], "prog": [0, 3, 4, 0], "bpm": 112, "seed": 5, "drums": 1, "lead": "tri"},
	"misterio": {"root": 52, "scale": [0, 2, 3, 5, 7, 8, 11], "prog": [0, 5, 3, 4], "bpm": 96, "seed": 3, "drums": 0, "lead": "tri"},
}


## Empieza (o cambia) la música de fondo. Si el estilo no está generado
## todavía, se genera por partes sin trabar el juego.
func play_music(style: String) -> void:
	if style == _music_style and _music_player.playing:
		return
	_music_style = style
	_music_request += 1
	var req: int = _music_request
	var stream: AudioStreamWAV = _music_cache.get(style)
	if stream == null:
		stream = await _build_song(style)
		if req != _music_request:
			return  # mientras se generaba, se pidió otra música o silencio
		_music_cache[style] = stream
	_update_music_volume()
	if float(SettingsManager.get_value("music_volume", 0.8)) <= 0.0:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_request += 1
	_music_style = ""
	_music_player.stop()


func _update_music_volume() -> void:
	var vol: float = float(SettingsManager.get_value("music_volume", 0.8)) * MUSIC_GAIN
	_music_player.volume_db = linear_to_db(clampf(vol, 0.001, 1.0))
	if vol <= 0.0:
		_music_player.stop()


static func _midi_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _build_song(style: String) -> AudioStreamWAV:
	var st: Dictionary = MUSIC_STYLES[style]
	var step_len: float = 60.0 / st["bpm"] / 4.0  # dieciseisavos
	var steps: int = 64                           # 4 compases
	var n: int = int(steps * step_len * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = st["seed"]
	var scale: Array = st["scale"]
	var root: int = st["root"]
	var events: Array = []  # [paso, duración en pasos, midi, voz]

	# Melodía: frase de 2 compases que se repite con el final variado.
	var phrase: Array = []
	for s in range(32):
		if s % 2 == 1 and rng.randf() < 0.75:
			continue
		if rng.randf() < 0.18:
			continue  # silencio
		var chord: int = st["prog"][s / 16]
		var degree: int = chord + [0, 2, 4][rng.randi() % 3] if rng.randf() < 0.7 else chord + rng.randi_range(0, 6)
		var midi: int = root + 12 + scale[degree % 7] + 12 * (degree / 7)
		phrase.append([s, 2 if rng.randf() < 0.7 else 4, midi])
	for half in range(2):
		for ph: Array in phrase:
			var s2: int = ph[0] + half * 32
			var midi2: int = ph[2]
			if half == 1 and ph[0] >= 24:
				var chord2: int = st["prog"][s2 / 16]
				midi2 = root + 12 + scale[(chord2 + [0, 2, 4][int(ph[0]) % 3]) % 7]
			events.append([s2, ph[1], midi2, "lead"])
	# Bajo y arpegio según el acorde de cada compás.
	for bar in range(4):
		var chord3: int = st["prog"][bar]
		var bass_midi: int = root - 12 + scale[chord3 % 7]
		for q in range(4):
			events.append([bar * 16 + q * 4, 3, bass_midi, "bass"])
			if q % 2 == 1:
				events.append([bar * 16 + q * 4 + 2, 1, bass_midi + 12, "bass"])
		for s3 in range(16):
			if s3 % 2 == 0:
				var deg: int = chord3 + [0, 2, 4, 2][(s3 / 2) % 4]
				events.append([bar * 16 + s3, 1, root + scale[deg % 7] + 12 * (deg / 7), "arp"])
		# Batería.
		for s4 in range(16):
			if s4 % 8 == 0 or (st["drums"] >= 2 and s4 == 10):
				events.append([bar * 16 + s4, 1, 0, "kick"])
			if st["drums"] >= 1 and s4 % 8 == 4:
				events.append([bar * 16 + s4, 1, 0, "snare"])
			if st["drums"] >= 1 and s4 % 2 == 0:
				events.append([bar * 16 + s4, 1, 0, "hat"])

	var noise := RandomNumberGenerator.new()
	noise.seed = 99
	var done := 0
	for ev: Array in events:
		var start: int = int(ev[0] * step_len * SAMPLE_RATE)
		var dur: float = ev[1] * step_len
		var voice: String = ev[3]
		var f: float = _midi_hz(ev[2]) if ev[2] > 0 else 0.0
		var count: int = int(dur * SAMPLE_RATE)
		var phase := 0.0
		for i in range(count):
			var idx: int = (start + i) % n
			var k: float = float(i) / float(count)
			var t: float = float(i) / SAMPLE_RATE
			var s := 0.0
			match voice:
				"lead":
					phase += f * (1.0 + 0.004 * sin(TAU * 5.5 * t)) / SAMPLE_RATE
					s = _osc(st["lead"], phase, 0.25, noise) * 0.16 * minf(t / 0.01, 1.0) * (1.0 - k * 0.6)
				"bass":
					phase += f / SAMPLE_RATE
					s = _osc("tri", phase, 0.5, noise) * 0.3 * (1.0 - k * 0.5)
				"arp":
					phase += f / SAMPLE_RATE
					s = _osc("square", phase, 0.125, noise) * 0.05 * (1.0 - k)
				"kick":
					phase += (150.0 * pow(0.3, k)) / SAMPLE_RATE
					s = sin(phase * TAU) * 0.5 * (1.0 - k)
				"snare":
					s = noise.randf_range(-1.0, 1.0) * 0.18 * pow(1.0 - k, 2.0)
				"hat":
					if i > count / 3:
						break
					s = noise.randf_range(-1.0, 1.0) * 0.05 * (1.0 - k * 3.0)
			buf[idx] += s
		done += 1
		if done % 12 == 0:
			await get_tree().process_frame  # repartir el trabajo entre cuadros
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
		if i % 40000 == 39999:
			await get_tree().process_frame
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	return stream


## Vibración del celular (en la web usa navigator.vibrate: funciona en
## Android; iPhone no lo permite). Se apaga desde el menú (📳).
## Golpes cortos (10-40 ms) para impactos y largos (150-300) para perder.
func vibrate(ms: int) -> void:
	if not bool(SettingsManager.get_value("vibration", true)):
		return
	if OS.has_feature("web") or OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
