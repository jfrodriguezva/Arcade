extends Control
## Estilo Pac-Man: laberinto generado proceduralmente (algoritmo de
## backtracking, siempre 100% conectado — evita bugs de un laberinto
## armado a mano con puntos inalcanzables) con caza de fantasmas.
## Come todos los puntos para pasar de nivel; las bolitas grandes
## vuelven vulnerables a los fantasmas por unos segundos.

const GAME_ID := "maze_muncher"
const ROOMS_W := 9
const ROOMS_H := 11
const MAZE_W := ROOMS_W * 2 + 1
const MAZE_H := ROOMS_H * 2 + 1
const CELL := 36.0
const PIECE_SIZE := CELL * 0.92
const MOVE_INTERVAL := 0.11
const VULNERABLE_DURATION := 6.0
const MAX_LEVEL := 10
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const GHOST_NAMES := ["blinky", "pinky", "inky", "clyde", "pinky"]
const GHOST_COLORS := [
	Color(0.937, 0.325, 0.314),  # rojo (Blinky, persigue directo)
	Color(1.0, 0.478, 0.706),    # rosa (Pinky, embosca adelante)
	Color(0.306, 0.804, 0.769),  # cian (Inky, flanquea con Blinky)
	Color(1.0, 0.596, 0.208),    # naranja (Clyde, tímido de cerca)
	Color(0.678, 0.478, 0.925),  # morado (5to fantasma, niveles altos)
]
const GHOST_SCARED_COLOR := Color(0.235, 0.318, 0.831)
const GHOST_SCARED_FLASH := Color(0.94, 0.95, 1.0)
const EATEN_EYE_COLOR := Color(0.2, 0.3, 0.6)

## Alternancia clásica dispersión/persecución: cada fantasma huye a su
## esquina y luego caza, y se invierte de dirección en cada cambio de modo.
const MODE_SCHEDULE := [
	["scatter", 7.0], ["chase", 20.0],
	["scatter", 7.0], ["chase", 20.0],
	["scatter", 5.0], ["chase", 999999.0],
]
const COMBO_SCORES := [200, 400, 800, 1600]
const FRUIT_SCORES := [100, 300, 500, 700, 1000, 2000, 3000, 5000, 5000, 5000]
const FRUIT_DURATION := 10.0
const FRIGHTENED_SPEED_MULT := 1.5
const EATEN_SPEED_MULT := 0.55

const HELP_TEXT := "Muévete por el laberinto con las flechas y come todos los puntos.

- Cada fantasma tiene su propia personalidad, como en el juego original: el rojo te persigue directo, el rosa embosca varias celdas por delante, el cian flanquea combinando tu posición con la del rojo, y el naranja huye si te acercas demasiado.
- Los fantasmas alternan entre 'dispersión' (huyen a su esquina) y 'persecución' (te cazan) — cuando cambian de modo, invierten su dirección, igual que en el arcade clásico.
- Las bolitas grandes (amarillas) los vuelven vulnerables: tócalos en ese estado para comerlos (los puntos se duplican por cada fantasma seguido: 200, 400, 800, 1600). Sus ojos vuelven corriendo a la casa y se recuperan.
- De vez en cuando aparece una fruta bonus cerca del centro: tómala antes de que desaparezca para puntos extra.
- Si un fantasma te toca cuando NO está vulnerable ni son solo ojos, pierdes una vida.

Limpia todos los puntos del laberinto para pasar de nivel (se genera uno nuevo, con más fantasmas y más rápidos). Hay 10 niveles. Pierdes si se acaban tus 3 vidas."

var walls: Array = []
var has_dot: Array = []
var has_power: Array = []
var cell_views: Array = []

var player_cell: Vector2i = Vector2i.ZERO
var current_dir: Vector2i = Vector2i.ZERO
var facing_dir: Vector2i = Vector2i(1, 0)
var move_timer: float = 0.0
var vulnerable_timer: float = 0.0
var anim_time: float = 0.0
var level_time: float = 0.0

var ghosts: Array = []

## Dispersión/persecución global (sincroniza a todos los fantasmas que no
## estén asustados o regresando como ojos).
var mode_index: int = 0
var mode_timer: float = 0.0
var global_mode: String = "scatter"
var frightened_combo: int = 0

var dots_total: int = 0
var dots_eaten: int = 0
var fruit_spawn_count: int = 0
var fruit_active: bool = false
var fruit_timer: float = 0.0
var fruit_cell: Vector2i = Vector2i.ZERO

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var dot_layer: Control
var player_view: EntitySprite
var score_label: Label
var lives_label: Label
var status_label: Label


func _ready() -> void:
	_build_ui()
	_new_game()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	# --- Barra superior compacta: volver/ayuda + puntos/vidas/nivel/reinicio -
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 12)
	header_margin.add_theme_constant_override("margin_right", 12)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_bottom", 0)
	root_vbox.add_child(header_margin)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 6)
	header_margin.add_child(header_vbox)

	UIKit.build_toolbar(header_vbox, self, "Caza en el Laberinto", HELP_TEXT)

	var stats_bar := PanelContainer.new()
	stats_bar.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 1))
	header_vbox.add_child(stats_bar)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 18)
	stats_bar.add_child(stats_row)

	score_label = UIKit.title_label("Puntos: 0", 13, UIKit.COLOR_TEXT)
	stats_row.add_child(score_label)

	lives_label = UIKit.title_label("♥♥♥", 15, UIKit.COLOR_DANGER)
	stats_row.add_child(lives_label)

	status_label = UIKit.title_label("Nivel 1 / %d" % MAX_LEVEL, 13, UIKit.COLOR_ACCENT_3)
	stats_row.add_child(status_label)

	var restart_btn := Button.new()
	restart_btn.text = "↻"
	restart_btn.custom_minimum_size = Vector2(32, 32)
	restart_btn.add_theme_font_size_override("font_size", 16)
	UIKit.style_button(restart_btn, UIKit.COLOR_TEXT_DIM, 9)
	restart_btn.pressed.connect(_new_game)
	stats_row.add_child(restart_btn)

	# --- Laberinto: ocupa todo el espacio vertical disponible -----------
	var maze_center := CenterContainer.new()
	maze_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(maze_center)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 10, 2))
	maze_center.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(MAZE_W * CELL, MAZE_H * CELL)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	for y in range(MAZE_H):
		var row: Array = []
		for x in range(MAZE_W):
			var cell := Panel.new()
			cell.position = Vector2(x * CELL, y * CELL)
			cell.size = Vector2(CELL, CELL)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play_area.add_child(cell)
			row.append(cell)
		cell_views.append(row)

	# Capa única para dibujar todos los puntos/bolitas grandes: mucho más
	# barato que un EntitySprite por punto (puede haber cientos por nivel).
	dot_layer = Control.new()
	dot_layer.size = Vector2(MAZE_W * CELL, MAZE_H * CELL)
	dot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_layer.draw.connect(_draw_dots)
	play_area.add_child(dot_layer)

	player_view = EntitySprite.new()
	player_view.size = Vector2(PIECE_SIZE, PIECE_SIZE)
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.setup("muncher", UIKit.COLOR_ACCENT_3, UIKit.COLOR_ACCENT_3.lightened(0.5))
	play_area.add_child(player_view)

	# --- Controles: cruceta grande con feedback táctil -------------------
	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 12)
	controls_margin.add_theme_constant_override("margin_right", 12)
	controls_margin.add_theme_constant_override("margin_top", 8)
	controls_margin.add_theme_constant_override("margin_bottom", 12)
	root_vbox.add_child(controls_margin)

	var controls_vbox := VBoxContainer.new()
	controls_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_vbox.add_theme_constant_override("separation", 6)
	controls_margin.add_child(controls_vbox)

	var dpad_center := CenterContainer.new()
	controls_vbox.add_child(dpad_center)

	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.add_theme_constant_override("h_separation", 8)
	dpad.add_theme_constant_override("v_separation", 8)
	dpad_center.add_child(dpad)

	dpad.add_child(_make_dpad_spacer())
	var up_btn := _make_dir_button("▲")
	up_btn.button_down.connect(func() -> void: _set_dir(Vector2i(0, -1)))
	up_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(0, -1)))
	dpad.add_child(up_btn)
	dpad.add_child(_make_dpad_spacer())

	var left_btn := _make_dir_button("◀")
	left_btn.button_down.connect(func() -> void: _set_dir(Vector2i(-1, 0)))
	left_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(-1, 0)))
	dpad.add_child(left_btn)
	dpad.add_child(_make_dpad_spacer())
	var right_btn := _make_dir_button("▶")
	right_btn.button_down.connect(func() -> void: _set_dir(Vector2i(1, 0)))
	right_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(1, 0)))
	dpad.add_child(right_btn)

	dpad.add_child(_make_dpad_spacer())
	var down_btn := _make_dir_button("▼")
	down_btn.button_down.connect(func() -> void: _set_dir(Vector2i(0, 1)))
	down_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(0, 1)))
	dpad.add_child(down_btn)
	dpad.add_child(_make_dpad_spacer())


func _make_dir_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(72, 72)
	btn.add_theme_font_size_override("font_size", 26)
	UIKit.style_button(btn, UIKit.COLOR_ACCENT_2, 16)
	btn.button_down.connect(func() -> void: _press_scale(btn, true))
	btn.button_up.connect(func() -> void: _press_scale(btn, false))
	return btn


func _make_dpad_spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(72, 72)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _press_scale(btn: Button, pressed_down: bool) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2(0.88, 0.88) if pressed_down else Vector2.ONE, 0.08)


func _piece_pos(cell: Vector2i) -> Vector2:
	var offset: float = (CELL - PIECE_SIZE) / 2.0
	return Vector2(cell.x * CELL + offset, cell.y * CELL + offset)


func _dir_to_facing_deg(d: Vector2i) -> float:
	if d == Vector2i.ZERO:
		return player_view.facing_deg
	return rad_to_deg(atan2(float(d.y), float(d.x)))


func _draw_dots() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.85 + 0.15 * sin(t * 4.0)
	for y in range(MAZE_H):
		for x in range(MAZE_W):
			var c: Vector2 = Vector2(x * CELL + CELL / 2.0, y * CELL + CELL / 2.0)
			if has_power[y][x]:
				var r: float = CELL * 0.24 * pulse
				dot_layer.draw_circle(c, r * 1.7, Color(UIKit.COLOR_ACCENT_3.r, UIKit.COLOR_ACCENT_3.g, UIKit.COLOR_ACCENT_3.b, 0.16))
				dot_layer.draw_circle(c, r, UIKit.COLOR_ACCENT_3)
				dot_layer.draw_circle(c - Vector2(r * 0.3, r * 0.3), r * 0.35, Color(1, 1, 1, 0.55))
			elif has_dot[y][x]:
				dot_layer.draw_circle(c, CELL * 0.085, Color(0.95, 0.87, 0.65, 0.9))

	if fruit_active:
		_draw_fruit(Vector2(fruit_cell.x * CELL + CELL / 2.0, fruit_cell.y * CELL + CELL / 2.0), pulse)


func _draw_fruit(c: Vector2, pulse: float) -> void:
	## Fruta bonus: un ícono de cereza simple, sin depender de EntitySprite
	## (aparece una sola vez a la vez, así que el costo es insignificante).
	var r: float = CELL * 0.16 * pulse
	dot_layer.draw_line(c + Vector2(0, -r * 1.6), c + Vector2(r * 0.4, -r * 2.4), Color(0.35, 0.6, 0.25), 2.0)
	dot_layer.draw_circle(c + Vector2(-r * 0.55, r * 0.15), r, UIKit.COLOR_DANGER)
	dot_layer.draw_circle(c + Vector2(r * 0.55, r * 0.35), r, UIKit.COLOR_DANGER)
	dot_layer.draw_circle(c + Vector2(-r * 0.55 - r * 0.3, r * 0.15 - r * 0.3), r * 0.3, Color(1, 1, 1, 0.5))
	dot_layer.draw_circle(c + Vector2(r * 0.55 - r * 0.3, r * 0.35 - r * 0.3), r * 0.3, Color(1, 1, 1, 0.5))


func _set_dir(d: Vector2i) -> void:
	current_dir = d
	facing_dir = d
	player_view.set_facing(_dir_to_facing_deg(d))


func _clear_dir(d: Vector2i) -> void:
	if current_dir == d:
		current_dir = Vector2i.ZERO


func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	state = "playing"
	_setup_level()


func _generate_maze() -> void:
	walls = []
	for y in range(MAZE_H):
		var row: Array = []
		for x in range(MAZE_W):
			row.append(true)
		walls.append(row)

	var visited: Array = []
	for ry in range(ROOMS_H):
		var vrow: Array = []
		for rx in range(ROOMS_W):
			vrow.append(false)
		visited.append(vrow)

	visited[0][0] = true
	walls[1][1] = false
	var stack: Array = [Vector2i(0, 0)]

	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var neighbors: Array = []
		for d: Vector2i in DIRS:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < ROOMS_W and n.y >= 0 and n.y < ROOMS_H and not visited[n.y][n.x]:
				neighbors.append(n)
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = neighbors[randi() % neighbors.size()]
		visited[next.y][next.x] = true
		var wall_x: int = cur.x * 2 + 1 + (next.x - cur.x)
		var wall_y: int = cur.y * 2 + 1 + (next.y - cur.y)
		walls[wall_y][wall_x] = false
		walls[next.y * 2 + 1][next.x * 2 + 1] = false
		stack.append(next)

	for y in range(1, MAZE_H - 1):
		for x in range(1, MAZE_W - 1):
			var is_edge_slot: bool = (x % 2 == 0 and y % 2 == 1) or (x % 2 == 1 and y % 2 == 0)
			if walls[y][x] and is_edge_slot and randf() < 0.07:
				walls[y][x] = false


func _room_to_grid(r: Vector2i) -> Vector2i:
	return Vector2i(r.x * 2 + 1, r.y * 2 + 1)


func _setup_level() -> void:
	_generate_maze()

	has_dot = []
	has_power = []
	for y in range(MAZE_H):
		var dot_row: Array = []
		var power_row: Array = []
		for x in range(MAZE_W):
			dot_row.append(not walls[y][x])
			power_row.append(false)
		has_dot.append(dot_row)
		has_power.append(power_row)

	player_cell = _room_to_grid(Vector2i(0, 0))
	has_dot[player_cell.y][player_cell.x] = false
	current_dir = Vector2i.ZERO
	vulnerable_timer = 0.0
	level_time = 0.0
	mode_index = 0
	mode_timer = 0.0
	global_mode = "scatter"
	frightened_combo = 0
	fruit_spawn_count = 0
	fruit_active = false
	player_view.position = _piece_pos(player_cell)
	player_view.set_facing(_dir_to_facing_deg(facing_dir))
	player_view.set_phase(0.0)

	var power_spots: Array = [
		Vector2i(ROOMS_W - 1, 0), Vector2i(0, ROOMS_H - 1),
		Vector2i(ROOMS_W - 1, ROOMS_H - 1), Vector2i(ROOMS_W / 2, ROOMS_H / 2),
	]
	for spot: Vector2i in power_spots:
		var g: Vector2i = _room_to_grid(spot)
		has_dot[g.y][g.x] = false
		has_power[g.y][g.x] = true

	fruit_cell = _room_to_grid(Vector2i(1, ROOMS_H / 2))
	has_dot[fruit_cell.y][fruit_cell.x] = false

	dots_total = 0
	for y in range(MAZE_H):
		for x in range(MAZE_W):
			if has_dot[y][x]:
				dots_total += 1
	dots_eaten = 0

	for g: Dictionary in ghosts:
		g["view"].queue_free()
	ghosts.clear()

	# Esquinas de dispersión: cada fantasma "vive" en una esquina del
	# laberinto generado, igual que en el juego clásico.
	var scatter_corners: Dictionary = {
		"blinky": _room_to_grid(Vector2i(ROOMS_W - 1, 0)),
		"pinky": _room_to_grid(Vector2i(0, 0)),
		"inky": _room_to_grid(Vector2i(ROOMS_W - 1, ROOMS_H - 1)),
		"clyde": _room_to_grid(Vector2i(0, ROOMS_H - 1)),
	}

	var spawn_rooms: Array = [
		Vector2i(ROOMS_W / 2, ROOMS_H / 2), Vector2i(ROOMS_W - 1, 0), Vector2i(0, ROOMS_H - 1),
		Vector2i(ROOMS_W - 1, ROOMS_H - 1), Vector2i(0, 0),
	]
	var ghost_count: int = min(1 + level / 2, 5)
	var ghost_interval: float = max(0.11, 0.26 - level * 0.014)
	for i in range(ghost_count):
		var spawn: Vector2i = _room_to_grid(spawn_rooms[i % spawn_rooms.size()])
		has_dot[spawn.y][spawn.x] = false
		var base_color: Color = GHOST_COLORS[i % GHOST_COLORS.size()]
		var g_name: String = GHOST_NAMES[i % GHOST_NAMES.size()]
		var view := EntitySprite.new()
		view.size = Vector2(PIECE_SIZE, PIECE_SIZE)
		view.position = _piece_pos(spawn)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.setup("ghost", base_color, base_color.lightened(0.35), i)
		view.visible = i == 0
		play_area.add_child(view)
		ghosts.append({
			"pos": spawn, "spawn": spawn, "dir": Vector2i.ZERO,
			"view": view, "interval": ghost_interval, "timer": 0.0,
			"base_color": base_color, "phase_offset": float(i) * 0.27,
			"name": g_name, "scatter_corner": scatter_corners.get(g_name, spawn),
			"mode": "scatter" if i == 0 else "inactive",
			"release_time": 0.0 if i == 0 else 4.0 * i,
		})

	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_redraw_maze()
	dot_layer.queue_redraw()
	_update_hud()


func _redraw_maze() -> void:
	for y in range(MAZE_H):
		for x in range(MAZE_W):
			_style_cell(y, x)


func _style_cell(y: int, x: int) -> void:
	# El piso ya no cambia de color al comer: los puntos se dibujan aparte
	# en dot_layer, así el suelo del laberinto se ve limpio y estable.
	var view: Panel = cell_views[y][x]
	var color: Color = UIKit.COLOR_BG if walls[y][x] else UIKit.COLOR_BG_LIGHT
	view.add_theme_stylebox_override("panel", UIKit.stylebox(color, Color(0, 0, 0, 0), 3))


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "♥".repeat(max(lives, 0)) + "♡".repeat(max(3 - lives, 0))


func _is_open(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= MAZE_W or p.y < 0 or p.y >= MAZE_H:
		return false
	return not walls[p.y][p.x]


func _process(delta: float) -> void:
	if state != "playing":
		return

	anim_time += delta
	level_time += delta
	for g: Dictionary in ghosts:
		g["view"].set_phase(anim_time * 0.6 + float(g["phase_offset"]))

	# Libera fantasmas dormidos cuando les toca salir de la "casa".
	for g: Dictionary in ghosts:
		if g["mode"] == "inactive" and level_time >= g["release_time"]:
			g["mode"] = global_mode
			g["view"].visible = true

	# Dispersión/persecución alternadas; al cambiar de modo los fantasmas
	# (que no estén asustados o volviendo como ojos) invierten dirección.
	if mode_index < MODE_SCHEDULE.size() - 1:
		mode_timer += delta
		if mode_timer >= float(MODE_SCHEDULE[mode_index][1]):
			mode_timer = 0.0
			mode_index += 1
			global_mode = MODE_SCHEDULE[mode_index][0]
			for g: Dictionary in ghosts:
				if g["mode"] == "scatter" or g["mode"] == "chase":
					g["mode"] = global_mode
					g["dir"] = -g["dir"]

	if fruit_active:
		fruit_timer -= delta
		if fruit_timer <= 0.0:
			fruit_active = false

	if vulnerable_timer > 0.0:
		vulnerable_timer -= delta
		var flashing: bool = vulnerable_timer < 1.5 and int(vulnerable_timer * 6.0) % 2 == 0
		for g: Dictionary in ghosts:
			if g["mode"] != "frightened":
				continue
			if flashing:
				g["view"].color = GHOST_SCARED_FLASH
				g["view"].color2 = GHOST_SCARED_COLOR
			else:
				g["view"].color = GHOST_SCARED_COLOR
				g["view"].color2 = GHOST_SCARED_FLASH
			g["view"].queue_redraw()
		if vulnerable_timer <= 0.0:
			for g: Dictionary in ghosts:
				if g["mode"] != "frightened":
					continue
				g["mode"] = global_mode
				var base_color: Color = g["base_color"]
				g["view"].color = base_color
				g["view"].color2 = base_color.lightened(0.35)
				g["view"].queue_redraw()

	# La boca "mastica" siguiendo el progreso del paso actual: un mordisco
	# rápido por celda mientras se mueve, cerrada cuando está quieto.
	move_timer += delta
	player_view.set_phase(move_timer / MOVE_INTERVAL if current_dir != Vector2i.ZERO else 0.0)
	dot_layer.queue_redraw()

	if move_timer >= MOVE_INTERVAL:
		move_timer = 0.0
		if current_dir != Vector2i.ZERO:
			_try_move_player()
		for g: Dictionary in ghosts:
			var mult: float = 1.0
			if g["mode"] == "frightened":
				mult = FRIGHTENED_SPEED_MULT
			elif g["mode"] == "eaten":
				mult = EATEN_SPEED_MULT
			g["timer"] += delta / mult
		for g: Dictionary in ghosts:
			if g["timer"] >= g["interval"]:
				g["timer"] = 0.0
				_move_ghost(g)
		_check_ghost_collision()


func _try_move_player() -> void:
	var next: Vector2i = player_cell + current_dir
	if not _is_open(next):
		return
	player_cell = next
	player_view.position = _piece_pos(next)

	if has_dot[next.y][next.x]:
		has_dot[next.y][next.x] = false
		score += 10
		dots_eaten += 1
		_maybe_spawn_fruit()
		_update_hud()
	if has_power[next.y][next.x]:
		has_power[next.y][next.x] = false
		score += 50
		vulnerable_timer = VULNERABLE_DURATION
		frightened_combo = 0
		for g: Dictionary in ghosts:
			if g["mode"] != "scatter" and g["mode"] != "chase":
				continue
			g["mode"] = "frightened"
			g["dir"] = -g["dir"]
			g["view"].color = GHOST_SCARED_COLOR
			g["view"].color2 = GHOST_SCARED_FLASH
			g["view"].queue_redraw()
		_update_hud()

	if fruit_active and next == fruit_cell:
		fruit_active = false
		var bonus: int = FRUIT_SCORES[min(level - 1, FRUIT_SCORES.size() - 1)]
		score += bonus
		_update_hud()

	if _all_dots_eaten():
		_advance_level()


func _maybe_spawn_fruit() -> void:
	if dots_total <= 0:
		return
	var ratio: float = float(dots_eaten) / float(dots_total)
	if fruit_spawn_count == 0 and ratio >= 0.3:
		fruit_spawn_count = 1
		fruit_active = true
		fruit_timer = FRUIT_DURATION
	elif fruit_spawn_count == 1 and ratio >= 0.7:
		fruit_spawn_count = 2
		fruit_active = true
		fruit_timer = FRUIT_DURATION


func _ghost_by_name(g_name: String) -> Dictionary:
	for g: Dictionary in ghosts:
		if g["name"] == g_name:
			return g
	return {}


func _chase_target(g: Dictionary) -> Vector2i:
	## Objetivos de persecución clásicos: Blinky va directo, Pinky embosca
	## varias celdas por delante, Inky flanquea usando a Blinky de pivote,
	## y Clyde caza igual que Blinky salvo que esté cerca (ahí huye).
	match g["name"]:
		"blinky":
			return player_cell
		"pinky":
			return player_cell + facing_dir * 4
		"inky":
			var blinky: Dictionary = _ghost_by_name("blinky")
			var blinky_pos: Vector2i = blinky.get("pos", g["pos"])
			var pivot: Vector2i = player_cell + facing_dir * 2
			return pivot * 2 - blinky_pos
		"clyde":
			if Vector2(g["pos"]).distance_to(Vector2(player_cell)) > 8.0:
				return player_cell
			return g["scatter_corner"]
		_:
			return player_cell


func _move_ghost(g: Dictionary) -> void:
	if g["mode"] == "inactive":
		return

	var target: Vector2i
	var is_frightened: bool = g["mode"] == "frightened"
	var is_eaten: bool = g["mode"] == "eaten"
	if is_eaten:
		target = g["spawn"]
	elif is_frightened:
		target = Vector2i.ZERO  # sin usar: en asustado se elige al azar
	elif g["mode"] == "scatter":
		target = g["scatter_corner"]
	else:
		target = _chase_target(g)

	# Regla clásica: nunca invierte su dirección salvo en un cambio de modo
	# o si es un callejón sin salida (ahí no queda más remedio).
	var reverse_dir: Vector2i = -g["dir"]
	var options: Array = []
	for d: Vector2i in DIRS:
		var n: Vector2i = g["pos"] + d
		if _is_open(n) and (is_eaten or d != reverse_dir or g["dir"] == Vector2i.ZERO):
			options.append({"dir": d, "pos": n})
	if options.is_empty():
		for d: Vector2i in DIRS:
			var n: Vector2i = g["pos"] + d
			if _is_open(n):
				options.append({"dir": d, "pos": n})
		if options.is_empty():
			return

	var chosen: Dictionary = options[0]
	if is_frightened:
		chosen = options[randi() % options.size()]
	else:
		var best := INF
		for o: Dictionary in options:
			var dist: float = Vector2(o["pos"]).distance_to(Vector2(target))
			if dist < best:
				best = dist
				chosen = o

	g["dir"] = chosen["dir"]
	g["pos"] = chosen["pos"]
	g["view"].position = _piece_pos(chosen["pos"])
	if is_eaten:
		# Solo los ojos (no el cuerpo del fantasma) giran para "mirar" hacia
		# donde vuelan de regreso a la casa; el cuerpo normal se mantiene
		# siempre en pie, como en el arcade clásico.
		g["view"].set_facing(_dir_to_facing_deg(chosen["dir"]))

	if is_eaten and g["pos"] == g["spawn"]:
		_respawn_ghost(g)


func _respawn_ghost(g: Dictionary) -> void:
	g["mode"] = global_mode
	g["dir"] = Vector2i.ZERO
	g["view"].shape = "ghost"
	g["view"].color = g["base_color"]
	g["view"].color2 = g["base_color"].lightened(0.35)
	g["view"].facing_deg = 0.0
	g["view"].queue_redraw()


func _check_ghost_collision() -> void:
	for g: Dictionary in ghosts:
		if g["mode"] == "inactive" or g["mode"] == "eaten":
			continue
		if g["pos"] == player_cell:
			if g["mode"] == "frightened":
				frightened_combo += 1
				var pts: int = COMBO_SCORES[min(frightened_combo - 1, COMBO_SCORES.size() - 1)]
				score += pts
				_update_hud()
				g["mode"] = "eaten"
				g["dir"] = -g["dir"]
				g["view"].shape = "eyes"
				g["view"].color = Color(0.97, 0.97, 1)
				g["view"].color2 = EATEN_EYE_COLOR
				g["view"].queue_redraw()
			else:
				_lose_life()
			return


func _all_dots_eaten() -> bool:
	for y in range(MAZE_H):
		for x in range(MAZE_W):
			if has_dot[y][x] or has_power[y][x]:
				return false
	return true


func _lose_life() -> void:
	lives -= 1
	_update_hud()
	current_dir = Vector2i.ZERO
	player_cell = _room_to_grid(Vector2i(0, 0))
	player_view.position = _piece_pos(player_cell)
	player_view.set_phase(0.0)

	level_time = 0.0
	mode_index = 0
	mode_timer = 0.0
	global_mode = "scatter"
	frightened_combo = 0
	vulnerable_timer = 0.0
	fruit_active = false

	for i in ghosts.size():
		var g: Dictionary = ghosts[i]
		g["pos"] = g["spawn"]
		g["dir"] = Vector2i.ZERO
		g["mode"] = "scatter" if i == 0 else "inactive"
		g["view"].position = _piece_pos(g["spawn"])
		g["view"].visible = i == 0
		g["view"].shape = "ghost"
		g["view"].color = g["base_color"]
		g["view"].color2 = g["base_color"].lightened(0.35)
		g["view"].facing_deg = 0.0
		g["view"].queue_redraw()

	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over. Puntos: %d" % score
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result(false)


func _advance_level() -> void:
	if level >= MAX_LEVEL:
		_win()
		return
	level += 1
	_setup_level()


func _win() -> void:
	state = "won"
	status_label.text = "¡Completaste los %d niveles! Puntos: %d" % [MAX_LEVEL, score]
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	_record_result(true)


func _record_result(won: bool) -> void:
	AudioManager.play_win() if won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)
