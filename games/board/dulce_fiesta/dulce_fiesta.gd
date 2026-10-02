extends Control
## Dulce Fiesta: juego de "combinar 3" con la temática de Candy Crush.
## Desliza un dulce sobre su vecino para intercambiarlos; si se forman 3 o
## más iguales en línea, desaparecen, los de arriba caen y salen nuevos.
##
## Especiales (como en el original):
##   4 en línea        -> dulce RAYADO: al estallar limpia toda su fila o
##                        columna.
##   L o T (5 dulces)  -> dulce ENVUELTO: explota en un área de 3x3.
##   5 en línea        -> BOMBA DE COLOR: intercámbiala con un dulce y
##                        elimina todos los de ese color.
## Combinar dos especiales entre sí produce efectos mayores (rayado+rayado
## = cruz, envuelto+envuelto = 5x5, rayado+envuelto = 3 filas y 3
## columnas, bomba+rayado/envuelto = todos los de ese color se vuelven
## especiales y estallan, bomba+bomba = todo el tablero).
##
## 15 niveles con jugadas limitadas: unos piden un puntaje y otros limpiar
## toda la gelatina del tablero. 1 a 3 estrellas según el puntaje.

const GAME_ID := "dulce_fiesta"
const N := 8
const CELL := 76.0
const BOARD_PX := N * CELL
const FALL_SPEED := 1300.0
const SWAP_SPEED := 700.0
const CLEAR_TIME := 0.2
const HINT_DELAY := 5.0
const COLORS := [
	Color(0.93, 0.18, 0.22),  # rojo: gomita
	Color(1.0, 0.55, 0.12),   # naranja: pastilla
	Color(1.0, 0.85, 0.15),   # amarillo: gota de limón
	Color(0.25, 0.78, 0.3),   # verde: cuadrito de menta
	Color(0.2, 0.5, 1.0),     # azul: chupetín
	Color(0.68, 0.3, 0.92),   # morado: racimo
]
const NAMES := ["rojo", "naranja", "amarillo", "verde", "azul", "morado"]

## Niveles: jugadas, colores, meta ("score" o "jelly"), puntaje objetivo
## (1 estrella; 2 = x1.5, 3 = x2) y máscara de gelatina ('1' una capa, '2'
## doble, '.' sin gelatina).
const LEVELS := [
	{"moves": 20, "colors": 5, "goal": "score", "target": 3000},
	{"moves": 18, "colors": 5, "goal": "score", "target": 5000},
	{"moves": 22, "colors": 5, "goal": "jelly", "target": 4000, "jelly": ["........", "........", "..1111..", "..1111..", "..1111..", "..1111..", "........", "........"]},
	{"moves": 20, "colors": 6, "goal": "score", "target": 6000},
	{"moves": 24, "colors": 5, "goal": "jelly", "target": 6000, "jelly": ["11....11", "11....11", "........", "...11...", "...11...", "........", "11....11", "11....11"]},
	{"moves": 22, "colors": 6, "goal": "score", "target": 9000},
	{"moves": 26, "colors": 6, "goal": "jelly", "target": 8000, "jelly": ["11111111", "1......1", "1......1", "1......1", "1......1", "1......1", "1......1", "11111111"]},
	{"moves": 20, "colors": 6, "goal": "score", "target": 11000},
	{"moves": 28, "colors": 6, "goal": "jelly", "target": 10000, "jelly": ["........", ".222222.", ".2....2.", ".2....2.", ".2....2.", ".2....2.", ".222222.", "........"]},
	{"moves": 22, "colors": 6, "goal": "score", "target": 14000},
	{"moves": 30, "colors": 6, "goal": "jelly", "target": 12000, "jelly": ["11111111", "11111111", "........", "........", "........", "........", "11111111", "11111111"]},
	{"moves": 24, "colors": 6, "goal": "score", "target": 18000},
	{"moves": 30, "colors": 6, "goal": "jelly", "target": 15000, "jelly": ["2......2", ".2....2.", "..2..2..", "...22...", "...22...", "..2..2..", ".2....2.", "2......2"]},
	{"moves": 25, "colors": 6, "goal": "score", "target": 22000},
	{"moves": 35, "colors": 6, "goal": "jelly", "target": 20000, "jelly": ["22222222", "21111112", "21111112", "21111112", "21111112", "21111112", "21111112", "22222222"]},
]

const HELP_TEXT := "Desliza un dulce sobre uno vecino para intercambiarlos (o toca uno y luego el de al lado). Si se forman 3 o más del mismo color en línea, desaparecen.

Especiales:
- 4 en línea: dulce RAYADO, limpia toda su fila o columna al estallar.
- L o T de 5: dulce ENVUELTO, explota a su alrededor.
- 5 en línea: BOMBA DE COLOR, intercámbiala con un dulce para eliminar todos los de ese color.
- ¡Combina dos especiales para efectos enormes!

Cada nivel tiene jugadas limitadas. Unos piden llegar a un puntaje; otros, limpiar toda la gelatina rosa (se limpia haciendo combinaciones encima; la doble necesita dos). Las cascadas multiplican los puntos. 1 a 3 estrellas según tu puntaje. Si te atoras, después de unos segundos un dulce te da una pista."

var grid: Array = []      # grid[y][x] = dulce (Dictionary) o null
var jelly: Array = []     # capas de gelatina por celda
var level_idx: int = 0
var moves_left: int = 0
var score: int = 0
var cascade: int = 0
var phase: String = "idle"  # idle | swap | swap_back | clearing | falling | won | lost
var phase_t: float = 0.0
var swap_a: Vector2i = Vector2i(-1, -1)
var swap_b: Vector2i = Vector2i(-1, -1)
var selected: Vector2i = Vector2i(-1, -1)
var press_cell: Vector2i = Vector2i(-1, -1)
var press_used: bool = false
var idle_t: float = 0.0
var hint: Array = []
var next_id: int = 0
var popups: Array = []    # textos flotantes de puntos
var bursts: Array = []    # destellos de rayados/envueltos
var unlocked: int = 1

var board_area: Control
var pad: GesturePad
var level_label: Label
var moves_label: Label
var goal_label: Label
var score_bar: ProgressBar
var status_label: Label
var next_btn: Button


func _ready() -> void:
	unlocked = int(SaveManager.get_game_data(GAME_ID).get("unlocked", 1))
	level_idx = clampi(unlocked - 1, 0, LEVELS.size() - 1)
	_build_ui()
	_start_level()


func _build_ui() -> void:
	UIKit.apply_background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	UIKit.build_toolbar(vbox, self, "Dulce Fiesta", HELP_TEXT)

	var hud_panel := PanelContainer.new()
	hud_panel.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0.36, 0.16, 0.38), Color(1.0, 0.55, 0.8), 14, 2))
	vbox.add_child(hud_panel)
	var hud_box := VBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 4)
	hud_panel.add_child(hud_box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	hud_box.add_child(row)
	level_label = UIKit.title_label("", 16, Color(1, 0.9, 0.95))
	row.add_child(level_label)
	moves_label = UIKit.title_label("", 16, Color(1.0, 0.85, 0.3))
	row.add_child(moves_label)
	goal_label = UIKit.title_label("", 15, Color(1, 0.8, 0.9))
	hud_box.add_child(goal_label)
	score_bar = ProgressBar.new()
	score_bar.custom_minimum_size = Vector2(0, 16)
	score_bar.show_percentage = false
	score_bar.add_theme_stylebox_override("background", UIKit.stylebox(Color(0.2, 0.08, 0.22), Color(0, 0, 0, 0), 8))
	score_bar.add_theme_stylebox_override("fill", UIKit.stylebox(Color(1.0, 0.45, 0.75), Color(0, 0, 0, 0), 8))
	hud_box.add_child(score_bar)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0.16, 0.1, 0.26), Color(1.0, 0.55, 0.8), 16, 3))
	var center := CenterContainer.new()
	center.add_child(board_panel)
	vbox.add_child(center)
	board_area = Control.new()
	board_area.custom_minimum_size = Vector2(BOARD_PX, BOARD_PX)
	board_area.clip_contents = true
	board_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.draw.connect(_draw_board)
	board_panel.add_child(board_area)

	pad = GesturePad.attach(board_area)
	pad.pressed.connect(_on_press)
	pad.dragged.connect(_on_drag)
	pad.tapped.connect(_on_tap)

	status_label = UIKit.title_label("", 15, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	next_btn = Button.new()
	next_btn.custom_minimum_size = Vector2(240, 52)
	UIKit.style_button(next_btn, Color(1.0, 0.45, 0.75))
	next_btn.pressed.connect(_on_next_pressed)
	next_btn.visible = false
	vbox.add_child(next_btn)


# ---------------------------------------------------------------- niveles --
func _level() -> Dictionary:
	return LEVELS[level_idx]


func _start_level() -> void:
	var lv: Dictionary = _level()
	moves_left = lv["moves"]
	score = 0
	cascade = 0
	selected = Vector2i(-1, -1)
	hint.clear()
	popups.clear()
	bursts.clear()
	jelly = []
	var mask: Array = lv.get("jelly", [])
	for y in range(N):
		var r: Array = []
		for x in range(N):
			r.append(int(mask[y][x]) if mask.size() > 0 and mask[y][x] != "." else 0)
		jelly.append(r)
	_fill_board()
	phase = "falling"  # los dulces entran cayendo desde arriba
	next_btn.visible = false
	status_label.text = "Nivel %d · %s" % [level_idx + 1, "¡Llega al puntaje!" if lv["goal"] == "score" else "¡Limpia toda la gelatina!"]
	_update_hud()


## Llena el tablero sin combinaciones hechas y con al menos una jugada.
func _fill_board() -> void:
	while true:
		grid = []
		for y in range(N):
			var r: Array = []
			for x in range(N):
				var c: int = randi() % _level()["colors"]
				while (x >= 2 and r[x - 1]["color"] == c and r[x - 2]["color"] == c) \
						or (y >= 2 and grid[y - 1][x]["color"] == c and grid[y - 2][x]["color"] == c):
					c = randi() % _level()["colors"]
				r.append(_new_candy(c, Vector2(x, y - N - 1) * CELL))
			grid.append(r)
		if not _find_valid_move().is_empty():
			return


func _new_candy(color: int, pos: Vector2, special: String = "") -> Dictionary:
	next_id += 1
	return {"id": next_id, "color": color, "special": special, "pos": pos, "dying": false, "scale": 1.0}


func _update_hud() -> void:
	var lv: Dictionary = _level()
	level_label.text = "Nivel %d/%d" % [level_idx + 1, LEVELS.size()]
	moves_label.text = "Jugadas: %d" % moves_left
	var stars: int = _stars()
	var star_txt: String = "★".repeat(stars) + "☆".repeat(3 - stars)
	if lv["goal"] == "jelly":
		goal_label.text = "Gelatina: %d   ·   %d pts  %s" % [_jelly_left(), score, star_txt]
	else:
		goal_label.text = "Meta: %d   ·   %d pts  %s" % [lv["target"], score, star_txt]
	score_bar.max_value = lv["target"] * 2
	score_bar.value = score


func _stars() -> int:
	var t: int = _level()["target"]
	if score >= t * 2:
		return 3
	if score >= int(t * 1.5):
		return 2
	if score >= t:
		return 1
	return 0


func _jelly_left() -> int:
	var n := 0
	for r: Array in jelly:
		for v: int in r:
			n += v
	return n


func _goal_met() -> bool:
	if _level()["goal"] == "jelly":
		return _jelly_left() == 0
	return score >= _level()["target"]


# ----------------------------------------------------------------- input --
func _cell_at(pos: Vector2) -> Vector2i:
	var c := Vector2i(int(pos.x / CELL), int(pos.y / CELL))
	if c.x < 0 or c.x >= N or c.y < 0 or c.y >= N:
		return Vector2i(-1, -1)
	return c


func _on_press(pos: Vector2) -> void:
	press_cell = _cell_at(pos)
	press_used = false


func _on_drag(_pos: Vector2, from_start: Vector2, _step: Vector2) -> void:
	if press_used or phase != "idle" or press_cell.x < 0:
		return
	if from_start.length() >= CELL * 0.35:
		press_used = true
		var target: Vector2i = press_cell + GesturePad._dir_of(from_start)
		selected = Vector2i(-1, -1)
		_try_swap(press_cell, target)


func _on_tap(pos: Vector2) -> void:
	if phase != "idle":
		return
	var c: Vector2i = _cell_at(pos)
	if c.x < 0:
		return
	if selected.x >= 0 and (absi(c.x - selected.x) + absi(c.y - selected.y)) == 1:
		var a: Vector2i = selected
		selected = Vector2i(-1, -1)
		_try_swap(a, c)
	elif selected == c:
		selected = Vector2i(-1, -1)
	else:
		selected = c


func _try_swap(a: Vector2i, b: Vector2i) -> void:
	if b.x < 0 or b.x >= N or b.y < 0 or b.y >= N or phase != "idle":
		return
	swap_a = a
	swap_b = b
	_swap_cells(a, b)
	hint.clear()
	idle_t = 0.0
	phase = "swap"
	AudioManager.play_click()


func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var t: Variant = grid[a.y][a.x]
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = t


func _on_next_pressed() -> void:
	if phase == "won" and level_idx < LEVELS.size() - 1:
		level_idx += 1
	_start_level()


# ------------------------------------------------------------------ bucle --
func _process(delta: float) -> void:
	board_area.queue_redraw()
	_update_effects(delta)
	var settled: bool = _animate(delta)
	match phase:
		"idle":
			idle_t += delta
			if idle_t > HINT_DELAY and hint.is_empty():
				hint = _find_valid_move()
		"swap":
			if settled:
				_after_swap()
		"swap_back":
			if settled:
				phase = "idle"
		"clearing":
			phase_t -= delta
			if phase_t <= 0.0:
				_remove_dead_and_fall()
				phase = "falling"
		"falling":
			if settled:
				var matches: Array = _find_matches()
				if not matches.is_empty():
					cascade += 1
					_resolve(matches, Vector2i(-1, -1), Vector2i(-1, -1))
				else:
					_turn_finished()


## Mueve cada dulce hacia su celda. Devuelve true si todos llegaron.
func _animate(delta: float) -> bool:
	var settled := true
	var spd: float = SWAP_SPEED if phase in ["swap", "swap_back"] else FALL_SPEED
	for y in range(N):
		for x in range(N):
			var c: Variant = grid[y][x]
			if c == null:
				continue
			var target := Vector2(x, y) * CELL
			if c["pos"] != target:
				c["pos"] = c["pos"].move_toward(target, spd * delta)
				settled = false
			if c["dying"]:
				c["scale"] = maxf(c["scale"] - delta / CLEAR_TIME, 0.0)
	return settled


func _after_swap() -> void:
	var a: Dictionary = grid[swap_a.y][swap_a.x]
	var b: Dictionary = grid[swap_b.y][swap_b.x]
	# Intercambios de especiales que estallan aunque no formen línea.
	if a["special"] == "bomb" or b["special"] == "bomb" or (a["special"] != "" and b["special"] != ""):
		moves_left -= 1
		cascade = 1
		_special_swap(swap_a, swap_b)
		return
	var matches: Array = _find_matches()
	if matches.is_empty():
		_swap_cells(swap_a, swap_b)  # no formó nada: regresa
		phase = "swap_back"
		AudioManager.play_error()
		return
	moves_left -= 1
	cascade = 1
	_resolve(matches, swap_a, swap_b)


func _turn_finished() -> void:
	cascade = 0
	_update_hud()
	if _goal_met() and (moves_left <= 0 or _level()["goal"] == "jelly" or score >= _level()["target"] * 2):
		_level_won()
		return
	if moves_left <= 0:
		if _goal_met():
			_level_won()
		else:
			_level_lost()
		return
	if _find_valid_move().is_empty():
		status_label.text = "¡Sin jugadas! Revolviendo..."
		_shuffle()
	phase = "idle"
	idle_t = 0.0


func _level_won() -> void:
	phase = "won"
	# Las jugadas que sobran se vuelven puntos (como el "Sugar Crush").
	var bonus: int = moves_left * 300
	score += bonus
	_update_hud()
	var stars: int = maxi(_stars(), 1)
	status_label.text = "¡Nivel superado! %s%s" % ["★".repeat(stars), ("  (+%d por jugadas sobrantes)" % bonus) if bonus > 0 else ""]
	AudioManager.play_win()
	unlocked = maxi(unlocked, mini(level_idx + 2, LEVELS.size()))
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats["unlocked"] = unlocked
	var best: Dictionary = stats.get("stars", {})
	best[str(level_idx + 1)] = maxi(int(best.get(str(level_idx + 1), 0)), stars)
	stats["stars"] = best
	stats["best_score"] = maxi(int(stats.get("best_score", 0)), score)
	SaveManager.set_game_data(GAME_ID, stats)
	next_btn.text = "▶  Siguiente nivel" if level_idx < LEVELS.size() - 1 else "🔁  Jugar de nuevo"
	next_btn.visible = true


func _level_lost() -> void:
	phase = "lost"
	status_label.text = "Se acabaron las jugadas. %s" % ("Te faltó gelatina por limpiar." if _level()["goal"] == "jelly" else "Te faltaron %d puntos." % (_level()["target"] - score))
	AudioManager.play_lose()
	next_btn.text = "🔁  Reintentar nivel"
	next_btn.visible = true


# -------------------------------------------------------------- combinar --
## Corridas de 3+ del mismo color: [{"cells": [...], "dir": "h"|"v"}].
func _find_matches() -> Array:
	var runs: Array = []
	for y in range(N):
		var x := 0
		while x < N:
			var c: Variant = grid[y][x]
			var run_len := 1
			if c != null and c["color"] >= 0:
				while x + run_len < N and grid[y][x + run_len] != null and grid[y][x + run_len]["color"] == c["color"]:
					run_len += 1
				if run_len >= 3:
					var cells: Array = []
					for k in range(run_len):
						cells.append(Vector2i(x + k, y))
					runs.append({"cells": cells, "dir": "h"})
			x += run_len
	for x in range(N):
		var y := 0
		while y < N:
			var c: Variant = grid[y][x]
			var run_len := 1
			if c != null and c["color"] >= 0:
				while y + run_len < N and grid[y + run_len][x] != null and grid[y + run_len][x]["color"] == c["color"]:
					run_len += 1
				if run_len >= 3:
					var cells: Array = []
					for k in range(run_len):
						cells.append(Vector2i(x, y + k))
					runs.append({"cells": cells, "dir": "v"})
			y += run_len
	return runs


## Elimina las corridas, crea especiales y dispara los especiales que
## estallen (en cadena).
func _resolve(runs: Array, a: Vector2i, b: Vector2i) -> void:
	var to_clear: Dictionary = {}
	var creations: Array = []  # [celda, color, especial]
	var used: Dictionary = {}
	# L/T: una corrida horizontal y una vertical que se cruzan -> envuelto.
	for i in range(runs.size()):
		for j in range(i + 1, runs.size()):
			if runs[i]["dir"] == runs[j]["dir"]:
				continue
			for c: Vector2i in runs[i]["cells"]:
				if runs[j]["cells"].has(c) and not used.has(i) and not used.has(j):
					var col: int = grid[c.y][c.x]["color"]
					if runs[i]["cells"].size() < 5 and runs[j]["cells"].size() < 5:
						creations.append([c, col, "wrap"])
						used[i] = true
						used[j] = true
	for i in range(runs.size()):
		var run: Dictionary = runs[i]
		var cells: Array = run["cells"]
		for c: Vector2i in cells:
			to_clear[c] = true
		if used.has(i):
			continue
		var at: Vector2i = cells[cells.size() / 2]
		if cells.has(a):
			at = a
		elif cells.has(b):
			at = b
		var col: int = grid[at.y][at.x]["color"]
		if cells.size() >= 5:
			creations.append([at, -1, "bomb"])
		elif cells.size() == 4:
			# 4 horizontales -> rayado vertical (limpia columna) y viceversa.
			creations.append([at, col, "v" if run["dir"] == "h" else "h"])
	var gained: int = 0
	for c: Vector2i in to_clear.keys():
		gained += 1
	score += gained * 60 * cascade
	_add_popup(Vector2(runs[0]["cells"][0]) * CELL + Vector2(CELL / 2.0, CELL / 2.0), gained * 60 * cascade)
	var created_at: Dictionary = {}
	for cr: Array in creations:
		created_at[cr[0]] = cr
		to_clear.erase(cr[0])
		score += 200
	_explode_cells(to_clear.keys(), created_at)
	for cr: Array in creations:
		var cell: Vector2i = cr[0]
		var old: Dictionary = grid[cell.y][cell.x]
		_clear_jelly(cell)
		grid[cell.y][cell.x] = _new_candy(cr[1], old["pos"], cr[2])
	if cascade >= 3:
		status_label.text = ["", "", "", "¡Dulce!", "¡Delicioso!", "¡Divino!", "¡Increíble!"][mini(cascade, 6)]
	AudioManager.play_place()
	phase = "clearing"
	phase_t = CLEAR_TIME
	_update_hud()


## Marca celdas para eliminar; los especiales que caigan aquí estallan y
## suman más celdas (reacción en cadena).
func _explode_cells(cells: Array, protect: Dictionary = {}) -> void:
	var queue: Array = cells.duplicate()
	var done: Dictionary = {}
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if done.has(c) or protect.has(c):
			continue
		done[c] = true
		var candy: Variant = grid[c.y][c.x]
		if candy == null or candy["dying"]:
			continue
		candy["dying"] = true
		_clear_jelly(c)
		score += 20
		match candy["special"]:
			"h":
				_add_burst(c, "h")
				for x in range(N):
					queue.append(Vector2i(x, c.y))
				score += 300
			"v":
				_add_burst(c, "v")
				for y in range(N):
					queue.append(Vector2i(c.x, y))
				score += 300
			"wrap":
				_add_burst(c, "wrap")
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var n := c + Vector2i(dx, dy)
						if n.x >= 0 and n.x < N and n.y >= 0 and n.y < N:
							queue.append(n)
				score += 400
			"bomb":
				# Una bomba atrapada en una explosión se lleva un color al azar.
				var col: int = randi() % _level()["colors"]
				for y in range(N):
					for x in range(N):
						if grid[y][x] != null and grid[y][x]["color"] == col:
							queue.append(Vector2i(x, y))
				score += 500


func _special_swap(pa: Vector2i, pb: Vector2i) -> void:
	var a: Dictionary = grid[pa.y][pa.x]
	var b: Dictionary = grid[pb.y][pb.x]
	var sa: String = a["special"]
	var sb: String = b["special"]
	var cells: Array = []
	if sa == "bomb" and sb == "bomb":
		for y in range(N):
			for x in range(N):
				cells.append(Vector2i(x, y))
		status_label.text = "¡Explosión total!"
	elif sa == "bomb" or sb == "bomb":
		var bomb_at: Vector2i = pa if sa == "bomb" else pb
		var other: Dictionary = b if sa == "bomb" else a
		var col: int = other["color"]
		var make: String = other["special"]
		grid[bomb_at.y][bomb_at.x]["special"] = ""
		cells.append(bomb_at)
		for y in range(N):
			for x in range(N):
				var c: Variant = grid[y][x]
				if c != null and c["color"] == col:
					if make in ["h", "v"]:
						c["special"] = ["h", "v"][randi() % 2]
					elif make == "wrap":
						c["special"] = "wrap"
					cells.append(Vector2i(x, y))
		status_label.text = "¡Bomba de color!"
	else:
		var kinds: Array = [sa, sb]
		var striped: int = kinds.count("h") + kinds.count("v")
		var center: Vector2i = pb
		a["special"] = ""
		b["special"] = ""
		if striped == 2:
			for k in range(N):
				cells.append(Vector2i(k, center.y))
				cells.append(Vector2i(center.x, k))
			_add_burst(center, "h")
			_add_burst(center, "v")
		elif kinds.count("wrap") == 2:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					cells.append(center + Vector2i(dx, dy))
			_add_burst(center, "wrap")
		else:
			for d in range(-1, 2):
				for k in range(N):
					cells.append(Vector2i(k, center.y + d))
					cells.append(Vector2i(center.x + d, k))
			_add_burst(center, "h")
			_add_burst(center, "v")
		cells.append(pa)
		cells.append(pb)
	var valid: Array = cells.filter(func(c: Vector2i) -> bool: return c.x >= 0 and c.x < N and c.y >= 0 and c.y < N)
	score += valid.size() * 60
	_add_popup(Vector2(pb) * CELL, valid.size() * 60)
	_explode_cells(valid)
	AudioManager.play_power()
	phase = "clearing"
	phase_t = CLEAR_TIME * 1.5
	_update_hud()


func _clear_jelly(c: Vector2i) -> void:
	if jelly[c.y][c.x] > 0:
		jelly[c.y][c.x] -= 1
		score += 100


## Quita los dulces eliminados, deja caer los de arriba y crea nuevos.
func _remove_dead_and_fall() -> void:
	for x in range(N):
		var column: Array = []
		for y in range(N - 1, -1, -1):
			var c: Variant = grid[y][x]
			if c != null and not c["dying"]:
				column.append(c)
		var missing: int = N - column.size()
		for k in range(missing):
			var nc: Dictionary = _new_candy(randi() % _level()["colors"], Vector2(x, -1 - k) * CELL)
			column.append(nc)
		for k in range(N):
			grid[N - 1 - k][x] = column[k]


func _shuffle() -> void:
	var all: Array = []
	for y in range(N):
		for x in range(N):
			all.append(grid[y][x])
	for attempt in range(200):
		all.shuffle()
		for i in range(all.size()):
			grid[i / N][i % N] = all[i]
		if _find_matches().is_empty() and not _find_valid_move().is_empty():
			return
	_fill_board()


## Busca un intercambio que forme combinación (para pistas y para saber si
## hay que revolver). Devuelve [celda_a, celda_b] o [].
func _find_valid_move() -> Array:
	for y in range(N):
		for x in range(N):
			var c: Variant = grid[y][x]
			if c != null and c["special"] == "bomb":
				return [Vector2i(x, y), Vector2i(x + 1 if x < N - 1 else x - 1, y)]
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var o := Vector2i(x, y) + d
				if o.x >= N or o.y >= N:
					continue
				_swap_cells(Vector2i(x, y), o)
				var ok: bool = not _find_matches().is_empty()
				_swap_cells(Vector2i(x, y), o)
				if ok:
					return [Vector2i(x, y), o]
	return []


# --------------------------------------------------------------- efectos --
func _add_popup(pos: Vector2, pts: int) -> void:
	popups.append({"pos": pos, "text": "+%d" % pts, "t": 0.0})


func _add_burst(c: Vector2i, kind: String) -> void:
	bursts.append({"cell": c, "kind": kind, "t": 0.0})


func _update_effects(delta: float) -> void:
	for p: Dictionary in popups:
		p["t"] += delta
	popups = popups.filter(func(p: Dictionary) -> bool: return p["t"] < 0.9)
	for b: Dictionary in bursts:
		b["t"] += delta
	bursts = bursts.filter(func(b: Dictionary) -> bool: return b["t"] < 0.35)


# ----------------------------------------------------------------- dibujo --
func _draw_board() -> void:
	var ca: Control = board_area
	for y in range(N):
		for x in range(N):
			var r := Rect2(Vector2(x, y) * CELL + Vector2(2, 2), Vector2(CELL - 4, CELL - 4))
			ca.draw_rect(r, Color(1, 1, 1, 0.06 if (x + y) % 2 == 0 else 0.1))
			var j: int = jelly[y][x]
			if j > 0:
				var jc := Color(1.0, 0.45, 0.75, 0.35 if j == 1 else 0.6)
				ca.draw_rect(r, jc)
				ca.draw_rect(r, Color(1.0, 0.7, 0.9, 0.8), false, 2.0)
	if selected.x >= 0:
		ca.draw_rect(Rect2(Vector2(selected) * CELL + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), Color(1, 1, 1, 0.9), false, 3.0)
	for y in range(N):
		for x in range(N):
			var c: Variant = grid[y][x]
			if c == null:
				continue
			var s: float = c["scale"]
			if hint.size() == 2 and (hint[0] == Vector2i(x, y) or hint[1] == Vector2i(x, y)):
				s *= 1.0 + 0.08 * sin(Time.get_ticks_msec() / 120.0)
			_draw_candy(c, c["pos"] + Vector2(CELL, CELL) / 2.0, s)
	for b: Dictionary in bursts:
		var k: float = b["t"] / 0.35
		var col := Color(1, 1, 1, 1.0 - k)
		var center: Vector2 = Vector2(b["cell"]) * CELL + Vector2(CELL, CELL) / 2.0
		match b["kind"]:
			"h":
				ca.draw_rect(Rect2(0, center.y - 10, BOARD_PX, 20), col)
			"v":
				ca.draw_rect(Rect2(center.x - 10, 0, 20, BOARD_PX), col)
			"wrap":
				ca.draw_circle(center, CELL * (1.0 + k), Color(1, 0.9, 0.5, 0.6 * (1.0 - k)))
	var f: Font = get_theme_default_font()
	for p: Dictionary in popups:
		var a: float = 1.0 - p["t"] / 0.9
		ca.draw_string_outline(f, p["pos"] + Vector2(-20, -p["t"] * 50.0), p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color(0.3, 0.05, 0.25, a))
		ca.draw_string(f, p["pos"] + Vector2(-20, -p["t"] * 50.0), p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, a))


## Cada color tiene su forma, como los dulces del original.
func _draw_candy(c: Dictionary, center: Vector2, s: float) -> void:
	if s <= 0.01:
		return
	var ca: Control = board_area
	var r: float = CELL * 0.36 * s
	if c["special"] == "bomb":
		ca.draw_circle(center + Vector2(2, 3), r, Color(0, 0, 0, 0.25))
		ca.draw_circle(center, r, Color(0.35, 0.2, 0.12))
		for i in range(10):
			var ang: float = i * 2.39
			var p: Vector2 = center + Vector2(cos(ang), sin(ang)) * r * (0.3 + 0.5 * fmod(i * 0.37, 1.0))
			ca.draw_circle(p, r * 0.13, COLORS[i % COLORS.size()])
		ca.draw_circle(center - Vector2(r * 0.35, r * 0.4), r * 0.2, Color(1, 1, 1, 0.35))
		return
	var col: Color = COLORS[c["color"]]
	var dark: Color = col.darkened(0.35)
	var light: Color = col.lightened(0.45)
	ca.draw_circle(center + Vector2(2, 4), r, Color(0, 0, 0, 0.22))
	match c["color"]:
		0:  # gomita roja (ovalada)
			_draw_ellipse(center, Vector2(r * 1.05, r * 0.85), dark)
			_draw_ellipse(center - Vector2(0, r * 0.05), Vector2(r * 0.95, r * 0.75), col)
		1:  # pastilla naranja (cápsula)
			ca.draw_rect(Rect2(center - Vector2(r * 0.6, r * 0.6), Vector2(r * 1.2, r * 1.2)), dark)
			ca.draw_circle(center - Vector2(r * 0.6, 0), r * 0.6, dark)
			ca.draw_circle(center + Vector2(r * 0.6, 0), r * 0.6, dark)
			ca.draw_rect(Rect2(center - Vector2(r * 0.6, r * 0.5), Vector2(r * 1.2, r * 1.0)), col)
			ca.draw_circle(center - Vector2(r * 0.6, 0), r * 0.5, col)
			ca.draw_circle(center + Vector2(r * 0.6, 0), r * 0.5, col)
		2:  # gota de limón amarilla
			ca.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r * 1.1), center + Vector2(r * 0.75, r * 0.1), center + Vector2(-r * 0.75, r * 0.1)]), dark)
			ca.draw_circle(center + Vector2(0, r * 0.25), r * 0.78, dark)
			ca.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r * 0.95), center + Vector2(r * 0.65, r * 0.1), center + Vector2(-r * 0.65, r * 0.1)]), col)
			ca.draw_circle(center + Vector2(0, r * 0.25), r * 0.68, col)
		3:  # cuadrito de menta verde
			ca.draw_rect(Rect2(center - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), dark)
			ca.draw_rect(Rect2(center - Vector2(r, r) * 0.78, Vector2(r, r) * 1.56), col)
		4:  # chupetín azul (círculo con espiral)
			ca.draw_circle(center, r, dark)
			ca.draw_circle(center, r * 0.88, col)
			ca.draw_arc(center, r * 0.55, 0, TAU * 0.8, 16, light, 3.0 * s)
			ca.draw_arc(center, r * 0.28, PI, PI + TAU * 0.7, 12, light, 3.0 * s)
		5:  # racimo morado (hexágono)
			var pts := PackedVector2Array()
			var pts2 := PackedVector2Array()
			for i in range(6):
				var ang: float = i * TAU / 6.0 + PI / 6.0
				pts.append(center + Vector2(cos(ang), sin(ang)) * r)
				pts2.append(center + Vector2(cos(ang), sin(ang)) * r * 0.85)
			ca.draw_colored_polygon(pts, dark)
			ca.draw_colored_polygon(pts2, col)
	ca.draw_circle(center - Vector2(r * 0.35, r * 0.38), r * 0.22, Color(1, 1, 1, 0.55))
	match c["special"]:
		"h":
			for k in [-0.4, 0.0, 0.4]:
				ca.draw_line(center + Vector2(-r * 0.8, r * k), center + Vector2(r * 0.8, r * k), Color(1, 1, 1, 0.9), 3.0 * s)
		"v":
			for k in [-0.4, 0.0, 0.4]:
				ca.draw_line(center + Vector2(r * k, -r * 0.8), center + Vector2(r * k, r * 0.8), Color(1, 1, 1, 0.9), 3.0 * s)
		"wrap":
			ca.draw_arc(center, r * 1.12, 0, TAU, 24, light, 4.0 * s)
			for side in [-1.0, 1.0]:
				ca.draw_colored_polygon(PackedVector2Array([center + Vector2(side * r * 1.05, 0), center + Vector2(side * r * 1.45, -r * 0.4), center + Vector2(side * r * 1.45, r * 0.4)]), light)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var ang: float = i * TAU / 20.0
		pts.append(center + Vector2(cos(ang) * radii.x, sin(ang) * radii.y))
	board_area.draw_colored_polygon(pts, color)
