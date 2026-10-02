extends Control
## Ecos: juegas en equipo contigo mismo. Cada intento dura unos segundos;
## al terminar, vuelve a empezar y tu intento anterior queda como un "eco"
## que repite exactamente lo que hiciste. Ningún nivel se pasa solo: hay
## que coordinarse con tus ecos.
##
## Piezas:
##   botón (a-d)  abre su puerta (A-D) mientras alguien esté encima.
##   puerta       solo la cruzas abierta (no se cierra con alguien dentro).
##   láser        mata a quien lo cruce... salvo que un eco lo bloquee con
##                su cuerpo antes de que llegue a ti.
##   guardia      persigue al cuerpo más cercano; si atrapa a un eco, se
##                queda con él; si te atrapa a ti, el intento falla.
## Si terminas un intento antes de tiempo (tocando), tu eco se queda
## parado donde lo dejaste el resto del ciclo: ideal para sostener botones.
##
## Control táctil: arrastra para moverte (joystick invisible donde pongas
## el dedo) y toca para terminar el intento ahí mismo.

const GAME_ID := "ecos"
const T := 56.0                 # tamaño de cada casilla
const COLS := 11
const BODY := 30.0              # lado del cuerpo (caja de choque)
const SPEED := 220.0
const GUARD_SPEED := 150.0
const TICK := 1.0 / 60.0
## Los láseres parpadean: apagados LASER_OFF s de cada ciclo de LASER_CYCLE.
const LASER_CYCLE := 3.0
const LASER_OFF := 1.1
const ECO_COLORS := [Color(1.0, 0.7, 0.3), Color(0.75, 0.5, 1.0), Color(0.4, 1.0, 0.6), Color(1.0, 0.5, 0.7), Color(0.5, 0.85, 1.0), Color(1.0, 1.0, 0.5)]

## '#' pared · '.' piso · 'S' inicio · 'E' salida · a-d botón · A-D puerta ·
## '>' '<' '^' 'v' láser (dispara en esa dirección) · 'G' guardia.
const LEVELS := [
	{"name": "Primer eco", "loop": 8.0, "max": 1, "hint": "Ve al botón y TOCA la pantalla: terminas el intento y tu eco se queda sosteniendo el botón.", "map": [
		"###########",
		"#.........#",
		"#.S.....a.#",
		"#.........#",
		"#####A#####",
		"#.........#",
		"#....E....#",
		"#.........#",
		"###########"]},
	{"name": "Dos puertas", "loop": 9.0, "max": 2, "hint": "Cada eco puede sostener un botón distinto.", "map": [
		"###########",
		"#a...S...b#",
		"#.........#",
		"#####A#####",
		"#.........#",
		"#####B#####",
		"#....E....#",
		"###########"]},
	{"name": "Muro de luz", "loop": 8.0, "max": 1, "hint": "El láser parpadea, pero el pasillo es muy largo para cruzarlo apagado. Mete un eco al pasillo mientras está apagado: desde ahí bloqueará el rayo.", "map": [
		"###########",
		"#S........#",
		"#.........#",
		"#.###v###.#",
		"#.........#",
		"#####.#####",
		"#####.#####",
		"#####.#####",
		"#####.#####",
		"#####E#####",
		"###########"]},
	{"name": "Relevo", "loop": 10.0, "max": 2, "hint": "", "map": [
		"###########",
		"#S..a.....#",
		"#.........#",
		"#####A#####",
		"#.b.......#",
		"#.........#",
		"#####B#####",
		"#....E....#",
		"###########"]},
	{"name": "Señuelo", "loop": 10.0, "max": 1, "hint": "El guardia persigue al más cercano. Un eco puede distraerlo.", "map": [
		"###########",
		"#S........#",
		"#.#######.#",
		"#.#.....#.#",
		"#.#..G..#.#",
		"#.#.....#.#",
		"#.##...##.#",
		"#.........#",
		"#####E#####",
		"###########"]},
	{"name": "Doble luz", "loop": 10.0, "max": 2, "hint": "", "map": [
		"###########",
		"#S........#",
		"#.........#",
		"#.###v###.#",
		"#.........#",
		"#####.#####",
		"#####.#####",
		"#####....<#",
		"########.##",
		"########E##",
		"###########"]},
	{"name": "Luz y puerta", "loop": 10.0, "max": 2, "hint": "", "map": [
		"###########",
		"#S.......a#",
		"#.........#",
		"#.###v###.#",
		"#.........#",
		"#####.#####",
		"#####.#####",
		"#####A#####",
		"#....E....#",
		"###########"]},
	{"name": "Guardia y botón", "loop": 11.0, "max": 2, "hint": "", "map": [
		"###########",
		"#S.......a#",
		"#.........#",
		"#....G....#",
		"#.........#",
		"#.........#",
		"####A######",
		"#...E.....#",
		"###########"]},
	{"name": "Tres llaves", "loop": 12.0, "max": 3, "hint": "", "map": [
		"###########",
		"#a...S...b#",
		"#....c....#",
		"#####A#####",
		"#.........#",
		"#####B#####",
		"#.........#",
		"#####C#####",
		"#....E....#",
		"###########"]},
	{"name": "Gran final", "loop": 12.0, "max": 3, "hint": "", "map": [
		"###########",
		"#a...S...b#",
		"#.........#",
		"#.###v###.#",
		"#.........#",
		"#####.#####",
		"#####A#####",
		"#####.#####",
		"#####B#####",
		"#....E....#",
		"###########"]},
]

const HELP_TEXT := "Juegas en equipo contigo mismo.

Cada intento dura unos segundos (la barra de arriba). Al terminar, vuelve a empezar y tu intento anterior queda como un ECO que repite exactamente lo que hiciste. Llega a la salida verde con ayuda de tus ecos.

- Arrastra el dedo para moverte (donde lo pongas es el centro de un joystick invisible).
- Toca para terminar el intento ahí mismo: tu eco se quedará parado en ese lugar el resto del ciclo (perfecto para sostener un botón).
(Teclado: flechas para moverte, espacio para terminar el intento.)

Piezas: los botones abren su puerta (misma letra) mientras alguien esté encima · los láseres se detienen en el primer cuerpo que tocan, así que un eco puede bloquearlos · el guardia persigue al más cercano y, si atrapa a un eco, se queda con él.

Si un láser o un guardia te alcanza, el intento se repite. ↶ borra tu último eco y ⟲ reinicia el nivel. Menos ecos = más estrellas."

var level_idx: int = 0
var unlocked: int = 1
var map: Array = []
var rows: int = 0
var start_pos: Vector2
var exit_cell: Vector2i
var plates: Dictionary = {}     # Vector2i -> letra
var doors: Dictionary = {}      # Vector2i -> letra
var lasers: Array = []          # [celda, dirección]
var guard_starts: Array = []

var ecos: Array = []            # grabaciones (PackedVector2Array)
var recording: PackedVector2Array = PackedVector2Array()
var tick: int = 0
var acc: float = 0.0
var player: Vector2
var eco_state: Array = []       # por eco: {"pos", "captured"}
var guards: Array = []          # {"pos", "holding": índice de eco o -1}
var open_doors: Dictionary = {}
var beams: Array = []           # segmentos [desde, hasta] para dibujar
var laser_active: bool = true
var state: String = "playing"   # playing | failed | won | replay
var flash: String = ""
var flash_t: float = 0.0
var replay_rec: PackedVector2Array

var board: Control
var pad: GesturePad
var title_label: Label
var info_label: Label
var hint_label: Label
var timer_bar: ProgressBar
var next_btn: Button


func _ready() -> void:
	unlocked = int(SaveManager.get_game_data(GAME_ID).get("unlocked", 1))
	level_idx = clampi(unlocked - 1, 0, LEVELS.size() - 1)
	_build_ui()
	_load_level()


func _build_ui() -> void:
	UIKit.apply_background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	UIKit.build_toolbar(vbox, self, "Ecos", HELP_TEXT)

	title_label = UIKit.title_label("", 17, UIKit.COLOR_ACCENT_2)
	vbox.add_child(title_label)
	info_label = UIKit.title_label("", 14, UIKit.COLOR_TEXT)
	vbox.add_child(info_label)
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(0, 12)
	timer_bar.show_percentage = false
	timer_bar.add_theme_stylebox_override("background", UIKit.stylebox(UIKit.COLOR_BG, Color(0, 0, 0, 0), 6))
	timer_bar.add_theme_stylebox_override("fill", UIKit.stylebox(UIKit.COLOR_ACCENT_2, Color(0, 0, 0, 0), 6))
	vbox.add_child(timer_bar)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0.05, 0.06, 0.12), UIKit.COLOR_ACCENT_2, 12, 2))
	var center := CenterContainer.new()
	center.add_child(panel)
	vbox.add_child(center)
	board = Control.new()
	board.custom_minimum_size = Vector2(COLS * T, 10 * T)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.draw.connect(_draw_board)
	panel.add_child(board)
	pad = GesturePad.attach(board)
	pad.tapped.connect(func(_p: Vector2) -> void: _end_attempt())

	hint_label = UIKit.title_label("", 13, UIKit.COLOR_TEXT_DIM)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(600, 0)
	vbox.add_child(hint_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	var undo_btn := Button.new()
	undo_btn.text = "↶  Borrar último eco"
	undo_btn.custom_minimum_size = Vector2(200, 46)
	UIKit.style_button(undo_btn, UIKit.COLOR_ACCENT_3)
	undo_btn.pressed.connect(func() -> void:
		if state in ["playing", "failed"] and not ecos.is_empty():
			ecos.pop_back()
			_start_loop())
	row.add_child(undo_btn)
	var reset_btn := Button.new()
	reset_btn.text = "⟲  Reiniciar nivel"
	reset_btn.custom_minimum_size = Vector2(180, 46)
	UIKit.style_button(reset_btn, UIKit.COLOR_TEXT_DIM)
	reset_btn.pressed.connect(_load_level)
	row.add_child(reset_btn)
	next_btn = Button.new()
	next_btn.text = "▶  Siguiente nivel"
	next_btn.custom_minimum_size = Vector2(240, 50)
	UIKit.style_button(next_btn, UIKit.COLOR_ACCENT_2)
	next_btn.visible = false
	next_btn.pressed.connect(func() -> void:
		if level_idx < LEVELS.size() - 1:
			level_idx += 1
		_load_level())
	vbox.add_child(next_btn)


# ---------------------------------------------------------------- niveles --
func _load_level() -> void:
	var lv: Dictionary = LEVELS[level_idx]
	map = lv["map"]
	rows = map.size()
	plates.clear()
	doors.clear()
	lasers.clear()
	guard_starts.clear()
	for y in range(rows):
		for x in range(COLS):
			var ch: String = map[y][x]
			var c := Vector2i(x, y)
			match ch:
				"S": start_pos = _center(c)
				"E": exit_cell = c
				"G": guard_starts.append(_center(c))
				">": lasers.append([c, Vector2i(1, 0)])
				"<": lasers.append([c, Vector2i(-1, 0)])
				"^": lasers.append([c, Vector2i(0, -1)])
				"v": lasers.append([c, Vector2i(0, 1)])
				_:
					if ch >= "a" and ch <= "d":
						plates[c] = ch
					elif ch >= "A" and ch <= "D":
						doors[c] = ch.to_lower()
	board.custom_minimum_size = Vector2(COLS * T, rows * T)
	board.size = board.custom_minimum_size
	ecos.clear()
	next_btn.visible = false
	title_label.text = "Nivel %d/%d · %s" % [level_idx + 1, LEVELS.size(), lv["name"]]
	hint_label.text = lv["hint"]
	_start_loop()


func _center(c: Vector2i) -> Vector2:
	return Vector2(c) * T + Vector2(T, T) / 2.0


func _start_loop() -> void:
	recording = PackedVector2Array()
	tick = 0
	acc = 0.0
	player = start_pos
	eco_state.clear()
	for e in ecos:
		eco_state.append({"pos": e[0] if e.size() > 0 else start_pos, "captured": false})
	guards.clear()
	for g: Vector2 in guard_starts:
		guards.append({"pos": g, "holding": -1})
	open_doors.clear()
	state = "playing"
	_update_info()


func _update_info() -> void:
	var lv: Dictionary = LEVELS[level_idx]
	info_label.text = "Ecos: %d / %d" % [ecos.size(), lv["max"]]
	if ecos.size() >= lv["max"]:
		info_label.text += "   ·   ¡último intento con estos ecos!"


# ------------------------------------------------------------- simulación --
func _process(delta: float) -> void:
	flash_t = maxf(flash_t - delta, 0.0)
	board.queue_redraw()
	if state not in ["playing", "replay"]:
		return
	acc += delta
	while acc >= TICK and state in ["playing", "replay"]:
		acc -= TICK
		_step()
	var loop_ticks: int = int(LEVELS[level_idx]["loop"] / TICK)
	timer_bar.max_value = loop_ticks
	timer_bar.value = loop_ticks - tick


## Solo para pruebas automáticas: si se asigna, reemplaza al dedo/teclado.
var scripted_dir: Variant = null


func _input_dir() -> Vector2:
	if scripted_dir != null:
		return scripted_dir
	var d := Vector2.ZERO
	if pad.is_holding():
		var v: Vector2 = pad.current_pos - pad.start_pos
		if v.length() > 14.0:
			d = v.normalized()
	if Input.is_key_pressed(KEY_LEFT): d.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT): d.x += 1.0
	if Input.is_key_pressed(KEY_UP): d.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN): d.y += 1.0
	return d.limit_length(1.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_end_attempt()


## Un paso fijo de simulación (60 por segundo): así los ecos se repiten
## exactamente igual en cada ciclo.
func _step() -> void:
	var loop_ticks: int = int(LEVELS[level_idx]["loop"] / TICK)
	if state == "replay":
		player = replay_rec[mini(tick, replay_rec.size() - 1)]
	else:
		var d: Vector2 = _input_dir()
		player = _move(player, d * SPEED * TICK)
		recording.append(player)
	for i in range(ecos.size()):
		if not eco_state[i]["captured"]:
			var rec: PackedVector2Array = ecos[i]
			eco_state[i]["pos"] = rec[mini(tick, rec.size() - 1)]
	_update_doors()
	_update_guards()
	_update_lasers()
	if state == "failed":
		return
	if _cell_of(player) == exit_cell:
		if state == "replay":
			return
		_win()
		return
	tick += 1
	if tick >= loop_ticks:
		if state == "replay":
			tick = 0
			_start_replay_loop()
		else:
			_end_attempt()


func _bodies() -> Array:
	## Cuerpos activos: [posición, índice de eco o -1 para el jugador].
	# Los ecos van primero: si un eco y tú están en la misma casilla del
	# láser, el eco lo bloquea antes de que te llegue.
	var out: Array = []
	for i in range(eco_state.size()):
		if not eco_state[i]["captured"]:
			out.append([eco_state[i]["pos"], i])
	out.append([player, -1])
	return out


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / T), int(p.y / T))


func _blocked(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= rows:
		return true
	var ch: String = map[c.y][c.x]
	if ch == "#" or ch in [">", "<", "^", "v"]:
		return true
	if doors.has(c) and not open_doors.get(c, false):
		return true
	return false


## Movimiento con choque contra paredes y puertas cerradas (eje por eje,
## para poder deslizarse por las paredes).
func _move(p: Vector2, delta: Vector2) -> Vector2:
	var np := p
	for axis in [Vector2(delta.x, 0), Vector2(0, delta.y)]:
		var cand: Vector2 = np + axis
		if not _box_hits(cand):
			np = cand
	return np


func _box_hits(p: Vector2) -> bool:
	var h: float = BODY / 2.0
	for corner in [Vector2(-h, -h), Vector2(h - 0.01, -h), Vector2(-h, h - 0.01), Vector2(h - 0.01, h - 0.01)]:
		if _blocked(_cell_of(p + corner)):
			return true
	return false


func _update_doors() -> void:
	var pressed := {}
	var occupied := {}
	for b: Array in _bodies():
		var c: Vector2i = _cell_of(b[0])
		if plates.has(c):
			pressed[plates[c]] = true
		occupied[c] = true
		# Una puerta no se cierra con alguien a medio cruzar.
		for corner in [Vector2(-BODY / 2.0, -BODY / 2.0), Vector2(BODY / 2.0, BODY / 2.0)]:
			occupied[_cell_of(b[0] + corner)] = true
	for c: Vector2i in doors:
		open_doors[c] = pressed.has(doors[c]) or (open_doors.get(c, false) and occupied.has(c))


func _update_guards() -> void:
	for g: Dictionary in guards:
		if g["holding"] >= 0:
			g["pos"] = eco_state[g["holding"]]["pos"]
			continue
		var best: Array = []
		var best_d := INF
		for b: Array in _bodies():
			var dd: float = g["pos"].distance_to(b[0])
			if dd < best_d:
				best_d = dd
				best = b
		if best.is_empty():
			continue
		if best_d < BODY * 0.9:
			if best[1] < 0 and state == "replay":
				continue
			if best[1] < 0:
				_fail("¡Te atrapó el guardia!")
				return
			g["holding"] = best[1]
			eco_state[best[1]]["captured"] = true
			continue
		# Camina por el camino más corto (no en línea recta: así rodea
		# paredes y sale de su cuarto por la puerta).
		var aim: Vector2 = best[0]
		var next_cell: Vector2i = _path_step(_cell_of(g["pos"]), _cell_of(best[0]))
		if next_cell != _cell_of(best[0]):
			aim = _center(next_cell)
		var dir: Vector2 = (aim - g["pos"]).normalized()
		g["pos"] = _move(g["pos"], dir * GUARD_SPEED * TICK)


## Cada láser avanza casilla por casilla hasta una pared o puerta cerrada;
## se detiene en el primer cuerpo que cruce su línea. Si ese cuerpo eres
## tú, el intento falla; si es un eco, el eco lo bloquea.
## Siguiente casilla en el camino más corto (búsqueda en anchura).
func _path_step(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return to
	var prev := {from: from}
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not prev.has(n) and not _blocked(n):
				prev[n] = c
				queue.append(n)
	if not prev.has(to):
		return to
	var step: Vector2i = to
	while prev[step] != from:
		step = prev[step]
	return step


func _laser_on() -> bool:
	return fmod(tick * TICK, LASER_CYCLE) >= LASER_OFF


func _update_lasers() -> void:
	beams.clear()
	laser_active = _laser_on()
	var bodies: Array = _bodies() if laser_active else []
	for l: Array in lasers:
		var d: Vector2i = l[1]
		var from: Vector2 = _center(l[0])
		var to: Vector2 = from
		var c: Vector2i = l[0] + d
		var hit: Array = []
		while not _blocked(c) and hit.is_empty():
			var line_center: Vector2 = _center(c)
			for b: Array in bodies:
				var bp: Vector2 = b[0]
				var across: float = absf(bp.y - line_center.y) if d.y == 0 else absf(bp.x - line_center.x)
				var along: float = absf(bp.x - line_center.x) if d.y == 0 else absf(bp.y - line_center.y)
				if across < BODY / 2.0 + 3.0 and along < T / 2.0:
					hit = b
					break
			to = _center(c) + Vector2(d) * T * 0.5
			c += d
		if not hit.is_empty():
			to = hit[0]
			if hit[1] < 0 and state == "playing" and laser_active:
				beams.append([from, to])
				_fail("¡Te alcanzó el láser!")
				return
		beams.append([from, to])


func _fail(msg: String) -> void:
	if state != "playing":
		return
	state = "failed"
	flash = msg
	flash_t = 1.2
	AudioManager.play_error()
	await get_tree().create_timer(1.1).timeout
	if state == "failed":
		_start_loop()


## Termina el intento: se guarda como eco (si quedan) y empieza otro ciclo.
func _end_attempt() -> void:
	if state != "playing" or recording.size() < 2:
		return
	var lv: Dictionary = LEVELS[level_idx]
	if ecos.size() < lv["max"]:
		ecos.append(recording)
		AudioManager.play_place()
		flash = "Eco %d grabado" % ecos.size()
	else:
		flash = "Ya no quedan ecos: inténtalo otra vez (o borra uno)"
		AudioManager.play_error()
	flash_t = 1.0
	_start_loop()


func _win() -> void:
	state = "won"
	var lv: Dictionary = LEVELS[level_idx]
	var used: int = ecos.size()
	AudioManager.play_win()
	unlocked = maxi(unlocked, mini(level_idx + 2, LEVELS.size()))
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats["unlocked"] = unlocked
	SaveManager.set_game_data(GAME_ID, stats)
	flash = "¡Resuelto con %d eco%s!" % [used, "" if used == 1 else "s"]
	flash_t = 3.0
	hint_label.text = "Mira la repetición: todos tus ecos a la vez."
	next_btn.text = "▶  Siguiente nivel" if level_idx < LEVELS.size() - 1 else "🏁  ¡Terminaste Ecos! Jugar de nuevo"
	next_btn.visible = true
	# Repetición de la solución completa (la gracia de compartirla).
	replay_rec = recording
	_start_replay_loop()


func _start_replay_loop() -> void:
	tick = 0
	acc = 0.0
	player = replay_rec[0]
	eco_state.clear()
	for e in ecos:
		eco_state.append({"pos": e[0], "captured": false})
	guards.clear()
	for g: Vector2 in guard_starts:
		guards.append({"pos": g, "holding": -1})
	open_doors.clear()
	state = "replay"


# ----------------------------------------------------------------- dibujo --
func _draw_board() -> void:
	var ca: Control = board
	var now: float = Time.get_ticks_msec() / 1000.0
	for y in range(rows):
		for x in range(COLS):
			var c := Vector2i(x, y)
			var ch: String = map[y][x]
			var r := Rect2(Vector2(c) * T, Vector2(T, T))
			if ch == "#":
				ca.draw_rect(r, Color(0.16, 0.18, 0.3))
				ca.draw_rect(r.grow(-3), Color(0.22, 0.25, 0.4))
				continue
			ca.draw_rect(r, Color(0.08, 0.09, 0.16) if (x + y) % 2 == 0 else Color(0.1, 0.11, 0.19))
			if c == exit_cell:
				var pulse: float = 0.6 + 0.4 * sin(now * 4.0)
				ca.draw_circle(r.get_center(), T * 0.38, Color(0.2, 0.9, 0.5, 0.3 * pulse))
				ca.draw_arc(r.get_center(), T * 0.32, 0, TAU, 24, Color(0.3, 1.0, 0.6), 3.0)
			if plates.has(c):
				var on: bool = false
				for b: Array in _bodies():
					if _cell_of(b[0]) == c:
						on = true
				ca.draw_rect(r.grow(-8), Color(1.0, 0.8, 0.2) if on else Color(0.5, 0.4, 0.15))
				_letter(plates[c].to_upper(), r.get_center(), Color(0.1, 0.08, 0.02))
			if doors.has(c):
				var open: bool = open_doors.get(c, false)
				if open:
					ca.draw_rect(r.grow(-2), Color(1.0, 0.8, 0.2, 0.15), false, 2.0)
				else:
					ca.draw_rect(r.grow(-2), Color(0.85, 0.65, 0.2))
					for k in range(4):
						ca.draw_line(r.position + Vector2(8 + k * 13, 4), r.position + Vector2(8 + k * 13, T - 4), Color(0.4, 0.28, 0.05), 3.0)
				_letter(doors[c].to_upper(), r.get_center(), Color(1, 1, 1, 0.8))
			if ch in [">", "<", "^", "v"]:
				ca.draw_rect(r.grow(-6), Color(0.5, 0.1, 0.15))
				ca.draw_circle(r.get_center(), 8, Color(1, 0.2, 0.25))
	for bm: Array in beams:
		if laser_active:
			ca.draw_line(bm[0], bm[1], Color(1, 0.15, 0.2, 0.5), 10.0)
			ca.draw_line(bm[0], bm[1], Color(1, 0.6, 0.6), 3.0)
		else:
			# Apagado: solo una guía punteada (y parpadea antes de encender).
			var warn: bool = fmod(tick * TICK, LASER_CYCLE) > LASER_OFF - 0.3
			ca.draw_dashed_line(bm[0], bm[1], Color(1, 0.3, 0.3, 0.6 if warn else 0.25), 2.0, 8.0)
	# Rastro y cuerpo de cada eco.
	for i in range(eco_state.size()):
		var col: Color = ECO_COLORS[i % ECO_COLORS.size()]
		var rec: PackedVector2Array = ecos[i]
		var trail := PackedVector2Array()
		for k in range(0, rec.size(), 6):
			trail.append(rec[k])
		if trail.size() > 1:
			ca.draw_polyline(trail, Color(col.r, col.g, col.b, 0.18), 3.0, true)
		_draw_body(eco_state[i]["pos"], col, 0.75 if not eco_state[i]["captured"] else 0.3, str(i + 1))
	for g: Dictionary in guards:
		var p: Vector2 = g["pos"]
		ca.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -18), p + Vector2(17, 14), p + Vector2(-17, 14)]), Color(0.95, 0.25, 0.3))
		ca.draw_circle(p + Vector2(0, 2), 5, Color(1, 1, 0.6))
	_draw_body(player, Color(0.3, 0.95, 1.0), 1.0, "")
	if flash_t > 0.0:
		var f: Font = get_theme_default_font()
		var s: Vector2 = f.get_string_size(flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		var pos := Vector2(COLS * T / 2.0 - s.x / 2.0, rows * T / 2.0)
		ca.draw_rect(Rect2(pos + Vector2(-12, -28), s + Vector2(24, 18)), Color(0, 0, 0, 0.6 * minf(flash_t * 2.0, 1.0)))
		ca.draw_string(f, pos, flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, minf(flash_t * 2.0, 1.0)))


func _draw_body(p: Vector2, col: Color, alpha: float, label: String) -> void:
	board.draw_circle(p, BODY / 2.0 + 2.0, Color(col.r, col.g, col.b, 0.35 * alpha))
	board.draw_circle(p, BODY / 2.0, Color(col.r, col.g, col.b, alpha))
	board.draw_circle(p + Vector2(-5, -3), 3.5, Color(0.05, 0.05, 0.1, alpha))
	board.draw_circle(p + Vector2(5, -3), 3.5, Color(0.05, 0.05, 0.1, alpha))
	if label != "":
		_letter(label, p + Vector2(0, 9), Color(0.05, 0.05, 0.1, alpha), 12)


func _letter(txt: String, center: Vector2, col: Color, size: int = 18) -> void:
	var f: Font = get_theme_default_font()
	var s: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	board.draw_string(f, center + Vector2(-s.x / 2.0, s.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
