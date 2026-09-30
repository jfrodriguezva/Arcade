extends Control
## Estilo Pac-Man, con el laberinto clásico del arcade (28x31): túnel
## lateral, casa de los fantasmas con puerta, 240 puntos + 4 bolitas de
## poder y la fruta debajo de la casa. Come todos los puntos para pasar de
## nivel; las bolitas grandes vuelven vulnerables a los fantasmas.
##
## Como en el original: el muncher sigue avanzando solo hasta chocar con
## una pared (no hace falta mantener presionado), y el giro que pidas se
## "guarda" y se toma en cuanto haya un pasillo en esa dirección. Siempre
## son 4 fantasmas con su personalidad; por nivel suben las velocidades y
## baja lo que dura el susto.

const GAME_ID := "maze_muncher"
const CELL := 24.0
const PIECE_SIZE := CELL * 1.25
const MAX_LEVEL := 10
const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]  # orden de desempate del original: arriba, izquierda, abajo, derecha

## '#' pared, '.' punto, 'o' bolita de poder, ' ' pasillo sin punto,
## '-' puerta de la casa (solo la cruzan los fantasmas), 'H' interior de la
## casa. Las zonas "fuera" del laberinto (a los lados de la casa) son '#'.
const MAZE := [
	"############################",
	"#............##............#",
	"#.####.#####.##.#####.####.#",
	"#o####.#####.##.#####.####o#",
	"#.####.#####.##.#####.####.#",
	"#..........................#",
	"#.####.##.########.##.####.#",
	"#.####.##.########.##.####.#",
	"#......##....##....##......#",
	"######.##### ## #####.######",
	"######.##### ## #####.######",
	"######.##          ##.######",
	"######.## ###--### ##.######",
	"######.## #HHHHHH# ##.######",
	"      .   #HHHHHH#   .      ",
	"######.## #HHHHHH# ##.######",
	"######.## ######## ##.######",
	"######.##          ##.######",
	"######.## ######## ##.######",
	"######.## ######## ##.######",
	"#............##............#",
	"#.####.#####.##.#####.####.#",
	"#.####.#####.##.#####.####.#",
	"#o..##.......  .......##..o#",
	"###.##.##.########.##.##.###",
	"###.##.##.########.##.##.###",
	"#......##....##....##......#",
	"#.##########.##.##########.#",
	"#.##########.##.##########.#",
	"#..........................#",
	"############################",
]
const MAZE_W := 28
const MAZE_H := 31
const TUNNEL_ROW := 14
const PLAYER_START := Vector2i(13, 23)
const HOUSE_EXIT := Vector2i(13, 11)   # casilla justo encima de la puerta
const HOUSE_CENTER := Vector2i(13, 14)
const FRUIT_CELL := Vector2i(13, 17)
const WALL_COLOR := Color(0.13, 0.13, 0.87)
const DOOR_COLOR := Color(1.0, 0.72, 0.87)

const GHOST_NAMES := ["blinky", "pinky", "inky", "clyde"]
const GHOST_COLORS := [
	Color(0.937, 0.325, 0.314),  # rojo (Blinky, persigue directo)
	Color(1.0, 0.478, 0.706),    # rosa (Pinky, embosca adelante)
	Color(0.306, 0.804, 0.769),  # cian (Inky, flanquea con Blinky)
	Color(1.0, 0.596, 0.208),    # naranja (Clyde, tímido de cerca)
]
## Blinky empieza afuera; los demás dentro de la casa y salen a su tiempo.
const GHOST_STARTS := [Vector2i(13, 11), Vector2i(13, 14), Vector2i(11, 14), Vector2i(15, 14)]
const GHOST_RELEASE := [0.0, 1.0, 5.0, 9.0]
## Esquinas de dispersión: fuera del laberinto, como en el original (así
## el fantasma da vueltas alrededor del bloque de su esquina).
const SCATTER_TARGETS := [Vector2i(25, -3), Vector2i(2, -3), Vector2i(27, 32), Vector2i(0, 32)]
const GHOST_SCARED_COLOR := Color(0.235, 0.318, 0.831)
const GHOST_SCARED_FLASH := Color(0.94, 0.95, 1.0)
const EATEN_EYE_COLOR := Color(0.2, 0.3, 0.6)

const MODE_SCHEDULE := [
	["scatter", 7.0], ["chase", 20.0],
	["scatter", 7.0], ["chase", 20.0],
	["scatter", 5.0], ["chase", 20.0],
	["scatter", 5.0], ["chase", 999999.0],
]
## Segundos que dura el susto en cada nivel (tabla del arcade: se acorta,
## con algunos niveles "de descanso").
const FRIGHT_TIME := [6.0, 5.0, 4.0, 3.0, 2.0, 5.0, 2.0, 2.0, 1.0, 5.0]
const COMBO_SCORES := [200, 400, 800, 1600]
## Frutas del arcade por nivel: cereza, fresa, naranja x2, manzana x2,
## melón x2, galaxian, campana.
const FRUITS := [
	{"name": "cereza", "points": 100, "color": Color(0.9, 0.1, 0.15)},
	{"name": "fresa", "points": 300, "color": Color(0.95, 0.2, 0.35)},
	{"name": "naranja", "points": 500, "color": Color(1.0, 0.6, 0.1)},
	{"name": "naranja", "points": 500, "color": Color(1.0, 0.6, 0.1)},
	{"name": "manzana", "points": 700, "color": Color(0.85, 0.05, 0.1)},
	{"name": "manzana", "points": 700, "color": Color(0.85, 0.05, 0.1)},
	{"name": "melón", "points": 1000, "color": Color(0.4, 0.8, 0.3)},
	{"name": "melón", "points": 1000, "color": Color(0.4, 0.8, 0.3)},
	{"name": "galaxian", "points": 2000, "color": Color(1.0, 0.85, 0.1)},
	{"name": "campana", "points": 3000, "color": Color(1.0, 0.9, 0.2)},
]
const FRUIT_DURATION := 9.5
const READY_TIME := 1.8
const DEATH_TIME := 1.4

const HELP_TEXT := "Muévete con la cruceta (o las flechas del teclado). No hace falta mantener presionado: el muncher sigue avanzando hasta chocar con una pared, y si pides un giro antes de llegar a la esquina, lo toma en cuanto pueda.

- Es el laberinto del arcade original: 240 puntos, 4 bolitas de poder en las esquinas y un túnel a los lados (sales por un lado y apareces por el otro; los fantasmas van más lentos dentro del túnel).
- Cada fantasma tiene su personalidad: el rojo te persigue directo, el rosa embosca por delante, el cian flanquea combinando tu posición con la del rojo, y el naranja huye si te acercas.
- Los fantasmas alternan entre 'dispersión' (se van a su esquina) y 'persecución', e invierten su dirección en cada cambio. Salen uno por uno de la casa del centro.
- Las bolitas grandes los asustan: cómetelos por 200, 400, 800 y 1600. Sus ojos regresan a la casa y vuelven a salir.
- Dos veces por nivel aparece una fruta debajo de la casa; vale más en cada nivel.

Limpia todos los puntos para pasar de nivel. Hay 10 niveles; en cada uno los fantasmas son más rápidos y el susto dura menos. Pierdes si se acaban tus 3 vidas."

var walls: Array = []
var has_dot: Array = []
var has_power: Array = []

var player_cell: Vector2i = PLAYER_START
var player_prev: Vector2 = Vector2.ZERO
var current_dir: Vector2i = Vector2i(-1, 0)
var desired_dir: Vector2i = Vector2i(-1, 0)
var facing_dir: Vector2i = Vector2i(-1, 0)
var move_timer: float = 0.0
var move_interval: float = 0.11
var vulnerable_timer: float = 0.0
var anim_time: float = 0.0
var level_time: float = 0.0
var pause_timer: float = 0.0  # "¡Listo!" al empezar y la animación de muerte
var dying: bool = false

var ghosts: Array = []
var mode_index: int = 0
var mode_timer: float = 0.0
var global_mode: String = "scatter"
var frightened_combo: int = 0

var dots_total: int = 0
var dots_eaten: int = 0
var fruit_spawn_count: int = 0
var fruit_active: bool = false
var fruit_timer: float = 0.0

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var maze_layer: Control
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
	restart_btn.text = "🔁"
	restart_btn.custom_minimum_size = Vector2(32, 32)
	restart_btn.add_theme_font_size_override("font_size", 16)
	UIKit.style_button(restart_btn, UIKit.COLOR_TEXT_DIM, 9)
	restart_btn.pressed.connect(_new_game)
	stats_row.add_child(restart_btn)

	var maze_center := CenterContainer.new()
	maze_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(maze_center)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0, 0, 0), UIKit.COLOR_ACCENT_3, 10, 2))
	maze_center.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(MAZE_W * CELL, MAZE_H * CELL)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	# Paredes al estilo del arcade: fondo negro y el contorno azul de los
	# bloques, dibujado una sola vez por nivel.
	maze_layer = Control.new()
	maze_layer.size = Vector2(MAZE_W * CELL, MAZE_H * CELL)
	maze_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	maze_layer.draw.connect(_draw_maze)
	play_area.add_child(maze_layer)

	dot_layer = Control.new()
	dot_layer.size = Vector2(MAZE_W * CELL, MAZE_H * CELL)
	dot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_layer.draw.connect(_draw_dots)
	play_area.add_child(dot_layer)

	player_view = EntitySprite.new()
	player_view.size = Vector2(PIECE_SIZE, PIECE_SIZE)
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.pivot_offset = player_view.size / 2.0
	player_view.setup("muncher", Color(1.0, 0.9, 0.1), Color(1.0, 0.95, 0.5))
	play_area.add_child(player_view)

	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 12)
	controls_margin.add_theme_constant_override("margin_right", 12)
	controls_margin.add_theme_constant_override("margin_top", 8)
	controls_margin.add_theme_constant_override("margin_bottom", 12)
	root_vbox.add_child(controls_margin)

	var dpad_center := CenterContainer.new()
	controls_margin.add_child(dpad_center)

	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.add_theme_constant_override("h_separation", 8)
	dpad.add_theme_constant_override("v_separation", 8)
	dpad_center.add_child(dpad)

	dpad.add_child(_make_dpad_spacer())
	dpad.add_child(_make_dir_button("▲", Vector2i(0, -1)))
	dpad.add_child(_make_dpad_spacer())
	dpad.add_child(_make_dir_button("◀", Vector2i(-1, 0)))
	dpad.add_child(_make_dpad_spacer())
	dpad.add_child(_make_dir_button("▶", Vector2i(1, 0)))
	dpad.add_child(_make_dpad_spacer())
	dpad.add_child(_make_dir_button("▼", Vector2i(0, 1)))
	dpad.add_child(_make_dpad_spacer())


func _make_dir_button(label: String, d: Vector2i) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(64, 64)
	btn.add_theme_font_size_override("font_size", 24)
	btn.focus_mode = Control.FOCUS_NONE
	UIKit.style_button(btn, UIKit.COLOR_ACCENT_2, 16)
	btn.button_down.connect(func() -> void:
		desired_dir = d
		_press_scale(btn, true))
	btn.button_up.connect(func() -> void: _press_scale(btn, false))
	return btn


func _make_dpad_spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(64, 64)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _press_scale(btn: Button, pressed_down: bool) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2(0.88, 0.88) if pressed_down else Vector2.ONE, 0.08)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var d := Vector2i.ZERO
	match event.keycode:
		KEY_UP, KEY_W: d = Vector2i(0, -1)
		KEY_DOWN, KEY_S: d = Vector2i(0, 1)
		KEY_LEFT, KEY_A: d = Vector2i(-1, 0)
		KEY_RIGHT, KEY_D: d = Vector2i(1, 0)
		_: return
	desired_dir = d
	get_viewport().set_input_as_handled()


func _piece_pos(p: Vector2) -> Vector2:
	var offset: float = (CELL - PIECE_SIZE) / 2.0
	return Vector2(p.x * CELL + offset, p.y * CELL + offset)


func _dir_to_facing_deg(d: Vector2i) -> float:
	if d == Vector2i.ZERO:
		return player_view.facing_deg
	return rad_to_deg(atan2(float(d.y), float(d.x)))


# ---------------------------------------------------------------- dibujo --
func _draw_maze() -> void:
	var line_w := 3.0
	var inset := CELL * 0.3
	for y in range(MAZE_H):
		for x in range(MAZE_W):
			if not walls[y][x]:
				continue
			# Se dibuja el borde de la pared solo donde toca un pasillo, un
			# poco metido hacia la pared: da el contorno azul del arcade.
			var r := Rect2(x * CELL, y * CELL, CELL, CELL)
			if not _wall_at(x, y - 1):
				maze_layer.draw_line(Vector2(r.position.x, r.position.y + inset), Vector2(r.end.x, r.position.y + inset), WALL_COLOR, line_w)
			if not _wall_at(x, y + 1):
				maze_layer.draw_line(Vector2(r.position.x, r.end.y - inset), Vector2(r.end.x, r.end.y - inset), WALL_COLOR, line_w)
			if not _wall_at(x - 1, y):
				maze_layer.draw_line(Vector2(r.position.x + inset, r.position.y), Vector2(r.position.x + inset, r.end.y), WALL_COLOR, line_w)
			if not _wall_at(x + 1, y):
				maze_layer.draw_line(Vector2(r.end.x - inset, r.position.y), Vector2(r.end.x - inset, r.end.y), WALL_COLOR, line_w)
	for x in [13, 14]:
		maze_layer.draw_rect(Rect2(x * CELL, 12 * CELL + CELL * 0.4, CELL, CELL * 0.2), DOOR_COLOR)


## Para dibujar: fuera del mapa cuenta como pared, salvo la fila del túnel.
func _wall_at(x: int, y: int) -> bool:
	if y < 0 or y >= MAZE_H:
		return true
	if x < 0 or x >= MAZE_W:
		return y != TUNNEL_ROW
	return walls[y][x]


func _draw_dots() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var blink: bool = fmod(t, 0.5) < 0.3
	for y in range(MAZE_H):
		for x in range(MAZE_W):
			var c := Vector2(x * CELL + CELL / 2.0, y * CELL + CELL / 2.0)
			if has_power[y][x]:
				if blink or state != "playing":
					dot_layer.draw_circle(c, CELL * 0.36, Color(1.0, 0.72, 0.6))
			elif has_dot[y][x]:
				dot_layer.draw_rect(Rect2(c - Vector2(2.5, 2.5), Vector2(5, 5)), Color(1.0, 0.72, 0.6))
	if fruit_active:
		_draw_fruit(Vector2(FRUIT_CELL.x * CELL + CELL, FRUIT_CELL.y * CELL + CELL / 2.0))
	if pause_timer > 0.0 and not dying:
		var txt := "¡LISTO!"
		var f: Font = get_theme_default_font()
		var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		dot_layer.draw_string(f, Vector2(MAZE_W * CELL / 2.0 - w / 2.0, 17 * CELL + CELL * 0.8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.95, 0.1))


func _draw_fruit(c: Vector2) -> void:
	var fr: Dictionary = FRUITS[mini(level - 1, FRUITS.size() - 1)]
	var r: float = CELL * 0.32
	var col: Color = fr["color"]
	dot_layer.draw_line(c + Vector2(0, -r), c + Vector2(r * 0.5, -r * 1.7), Color(0.35, 0.6, 0.25), 2.0)
	if fr["name"] == "cereza":
		dot_layer.draw_circle(c + Vector2(-r * 0.55, r * 0.2), r * 0.7, col)
		dot_layer.draw_circle(c + Vector2(r * 0.55, r * 0.4), r * 0.7, col)
	else:
		dot_layer.draw_circle(c, r, col)
	dot_layer.draw_circle(c - Vector2(r * 0.35, r * 0.35), r * 0.25, Color(1, 1, 1, 0.55))


# --------------------------------------------------------------- partida --
func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	state = "playing"
	status_label.remove_theme_color_override("font_color")
	_setup_level()


func _load_maze() -> void:
	walls = []
	has_dot = []
	has_power = []
	dots_total = 0
	for y in range(MAZE_H):
		var row_w: Array = []
		var row_d: Array = []
		var row_p: Array = []
		var line: String = MAZE[y]
		for x in range(MAZE_W):
			var ch: String = line[x]
			row_w.append(ch == "#")
			row_d.append(ch == ".")
			row_p.append(ch == "o")
			if ch == "." or ch == "o":
				dots_total += 1
		walls.append(row_w)
		has_dot.append(row_d)
		has_power.append(row_p)


func _setup_level() -> void:
	_load_maze()
	dots_eaten = 0
	fruit_spawn_count = 0
	fruit_active = false
	maze_layer.queue_redraw()

	for g: Dictionary in ghosts:
		g["view"].queue_free()
	ghosts.clear()
	for i in range(4):
		var view := EntitySprite.new()
		view.size = Vector2(PIECE_SIZE, PIECE_SIZE)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.setup("ghost", GHOST_COLORS[i], GHOST_COLORS[i].lightened(0.35), i)
		play_area.add_child(view)
		ghosts.append({"name": GHOST_NAMES[i], "base_color": GHOST_COLORS[i], "view": view, "index": i,
			"scatter_target": SCATTER_TARGETS[i], "phase_offset": float(i) * 0.27})
	# Velocidades: el muncher un poco más rápido que los fantasmas al
	# principio; por nivel ambos aceleran y los fantasmas lo alcanzan.
	move_interval = maxf(0.085, 0.115 - level * 0.003)
	_reset_positions()
	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_update_hud()


## Posiciones de arranque (inicio de nivel y después de perder una vida).
func _reset_positions() -> void:
	player_cell = PLAYER_START
	player_prev = Vector2(player_cell)
	current_dir = Vector2i(-1, 0)
	desired_dir = Vector2i(-1, 0)
	facing_dir = current_dir
	move_timer = 0.0
	player_view.scale = Vector2.ONE
	player_view.visible = true
	player_view.set_facing(_dir_to_facing_deg(facing_dir))
	player_view.position = _piece_pos(Vector2(player_cell) + Vector2(0.5, 0))
	level_time = 0.0
	mode_index = 0
	mode_timer = 0.0
	global_mode = "scatter"
	frightened_combo = 0
	vulnerable_timer = 0.0
	fruit_active = false
	dying = false
	pause_timer = READY_TIME
	var ghost_interval: float = move_interval * (1.12 - minf(level, 10) * 0.018)
	for g: Dictionary in ghosts:
		var i: int = g["index"]
		g["pos"] = GHOST_STARTS[i]
		g["prev"] = Vector2(g["pos"])
		g["dir"] = Vector2i(-1, 0) if i == 0 else Vector2i(0, -1)
		g["mode"] = "scatter" if i == 0 else "house"
		g["release"] = GHOST_RELEASE[i]
		g["interval"] = ghost_interval
		g["timer"] = 0.0
		_restore_ghost_look(g)
		g["view"].position = _piece_pos(Vector2(g["pos"]) + (Vector2(0.5, 0) if i == 0 else Vector2.ZERO))


func _restore_ghost_look(g: Dictionary) -> void:
	var v: EntitySprite = g["view"]
	v.shape = "ghost"
	v.color = g["base_color"]
	v.color2 = g["base_color"].lightened(0.35)
	v.facing_deg = 0.0
	v.visible = true
	v.queue_redraw()


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "♥".repeat(maxi(lives, 0)) + "♡".repeat(maxi(3 - lives, 0))


## ¿Se puede entrar a la celda? El jugador nunca cruza la puerta ni entra a
## la casa; los fantasmas solo cuando salen de ella o vuelven como ojos.
func _passable(p: Vector2i, for_ghost: bool = false, house_ok: bool = false) -> bool:
	if p.y == TUNNEL_ROW and (p.x < 0 or p.x >= MAZE_W):
		return true
	if p.x < 0 or p.x >= MAZE_W or p.y < 0 or p.y >= MAZE_H:
		return false
	var ch: String = MAZE[p.y][p.x]
	if ch == "#":
		return false
	if ch == "-" or ch == "H":
		return for_ghost and house_ok
	return true


func _wrap(p: Vector2i) -> Vector2i:
	if p.y == TUNNEL_ROW:
		p.x = posmod(p.x, MAZE_W)
	return p


# ------------------------------------------------------------------ bucle --
func _process(delta: float) -> void:
	if state != "playing":
		return
	anim_time += delta
	dot_layer.queue_redraw()

	if pause_timer > 0.0:
		pause_timer -= delta
		if dying:
			# Animación de muerte: el muncher se encoge y desaparece.
			var k: float = clampf(pause_timer / DEATH_TIME, 0.0, 1.0)
			player_view.scale = Vector2(k, k)
			player_view.rotation = (1.0 - k) * TAU
			if pause_timer <= 0.0:
				player_view.rotation = 0.0
				_after_death()
		return

	level_time += delta
	for g: Dictionary in ghosts:
		g["view"].set_phase(anim_time * 0.6 + float(g["phase_offset"]))

	_update_modes(delta)
	_update_fright(delta)

	if fruit_active:
		fruit_timer -= delta
		if fruit_timer <= 0.0:
			fruit_active = false

	move_timer += delta
	var pt: float = clampf(move_timer / move_interval, 0.0, 1.0)
	player_view.set_phase(pt if current_dir != Vector2i.ZERO else 0.0)
	player_view.position = _piece_pos(_lerp_cell(player_prev, Vector2(player_cell), pt))
	if move_timer >= move_interval:
		move_timer = 0.0
		player_prev = Vector2(player_cell)
		_try_move_player()
		if state != "playing":
			return
		_check_ghost_collision()

	for g: Dictionary in ghosts:
		var interval: float = g["interval"]
		match g["mode"]:
			"frightened": interval *= 1.6
			"eaten": interval *= 0.45
			"house": interval *= 1.4
		if g["mode"] != "eaten" and g["pos"].y == TUNNEL_ROW and (g["pos"].x <= 5 or g["pos"].x >= 22):
			interval *= 1.8  # lentos dentro del túnel, como en el original
		g["timer"] += delta
		var gt: float = clampf(g["timer"] / interval, 0.0, 1.0)
		g["view"].position = _piece_pos(_lerp_cell(g["prev"], Vector2(g["pos"]), gt))
		if g["timer"] >= interval:
			g["timer"] = 0.0
			g["prev"] = Vector2(g["pos"])
			_move_ghost(g)
			_check_ghost_collision()
			if state != "playing" or dying:
				return


## Interpola entre celdas para que el movimiento sea continuo; si el paso
## fue por el túnel (de un extremo al otro) no se interpola.
func _lerp_cell(a: Vector2, b: Vector2, t: float) -> Vector2:
	if absf(a.x - b.x) > 1.5:
		return b
	return a.lerp(b, t)


func _update_modes(delta: float) -> void:
	if vulnerable_timer > 0.0:
		return  # el reloj de dispersión/persecución se pausa durante el susto
	if mode_index >= MODE_SCHEDULE.size() - 1:
		return
	mode_timer += delta
	if mode_timer >= float(MODE_SCHEDULE[mode_index][1]):
		mode_timer = 0.0
		mode_index += 1
		global_mode = MODE_SCHEDULE[mode_index][0]
		for g: Dictionary in ghosts:
			if g["mode"] == "scatter" or g["mode"] == "chase":
				g["mode"] = global_mode
				g["dir"] = -g["dir"]


func _update_fright(delta: float) -> void:
	if vulnerable_timer <= 0.0:
		return
	vulnerable_timer -= delta
	var flashing: bool = vulnerable_timer < 1.6 and int(vulnerable_timer * 6.0) % 2 == 0
	for g: Dictionary in ghosts:
		if g["mode"] != "frightened":
			continue
		g["view"].color = GHOST_SCARED_FLASH if flashing else GHOST_SCARED_COLOR
		g["view"].color2 = GHOST_SCARED_COLOR if flashing else GHOST_SCARED_FLASH
		g["view"].queue_redraw()
	if vulnerable_timer <= 0.0:
		for g: Dictionary in ghosts:
			if g["mode"] == "frightened":
				g["mode"] = global_mode
				_restore_ghost_look(g)


func _try_move_player() -> void:
	# Giro "guardado": si el pasillo en la dirección pedida está libre, se
	# toma; si no, se sigue derecho hasta la pared.
	if desired_dir != current_dir and _passable(_wrap(player_cell + desired_dir)):
		current_dir = desired_dir
	var next: Vector2i = _wrap(player_cell + current_dir)
	if not _passable(next):
		player_view.set_phase(0.0)
		return
	facing_dir = current_dir
	player_view.set_facing(_dir_to_facing_deg(facing_dir))
	player_cell = next

	if has_dot[next.y][next.x]:
		has_dot[next.y][next.x] = false
		score += 10
		dots_eaten += 1
		_maybe_spawn_fruit()
		_update_hud()
	if has_power[next.y][next.x]:
		has_power[next.y][next.x] = false
		score += 50
		dots_eaten += 1
		_start_fright()
		_update_hud()
	if fruit_active and (next == FRUIT_CELL or next == FRUIT_CELL + Vector2i(1, 0)):
		fruit_active = false
		score += int(FRUITS[mini(level - 1, FRUITS.size() - 1)]["points"])
		AudioManager.play_power()
		_update_hud()
	if dots_eaten >= dots_total:
		_advance_level()


func _start_fright() -> void:
	vulnerable_timer = FRIGHT_TIME[mini(level - 1, FRIGHT_TIME.size() - 1)]
	frightened_combo = 0
	for g: Dictionary in ghosts:
		if g["mode"] != "scatter" and g["mode"] != "chase":
			continue
		g["mode"] = "frightened"
		g["dir"] = -g["dir"]
		g["view"].color = GHOST_SCARED_COLOR
		g["view"].color2 = GHOST_SCARED_FLASH
		g["view"].queue_redraw()


func _maybe_spawn_fruit() -> void:
	# Como en el arcade: la fruta sale a los 70 y a los 170 puntos comidos.
	if (fruit_spawn_count == 0 and dots_eaten >= 70) or (fruit_spawn_count == 1 and dots_eaten >= 170):
		fruit_spawn_count += 1
		fruit_active = true
		fruit_timer = FRUIT_DURATION


func _ghost_by_name(g_name: String) -> Dictionary:
	for g: Dictionary in ghosts:
		if g["name"] == g_name:
			return g
	return {}


func _chase_target(g: Dictionary) -> Vector2i:
	match g["name"]:
		"blinky":
			return player_cell
		"pinky":
			return player_cell + facing_dir * 4
		"inky":
			var blinky: Dictionary = _ghost_by_name("blinky")
			var pivot: Vector2i = player_cell + facing_dir * 2
			return pivot * 2 - blinky.get("pos", g["pos"])
		"clyde":
			if Vector2(g["pos"]).distance_to(Vector2(player_cell)) > 8.0:
				return player_cell
			return g["scatter_target"]
	return player_cell


func _move_ghost(g: Dictionary) -> void:
	match g["mode"]:
		"house":
			# Sube y baja dentro de la casa hasta que le toca salir.
			if level_time >= g["release"]:
				g["mode"] = "leaving"
			else:
				var ny: int = 13 if g["pos"].y >= 15 else (15 if g["pos"].y <= 13 else g["pos"].y + (1 if g["dir"].y >= 0 else -1))
				g["dir"] = Vector2i(0, signi(ny - g["pos"].y))
				g["pos"] = Vector2i(g["pos"].x, ny)
			return
		"leaving":
			# Primero al centro de la casa, luego derecho hacia arriba por la
			# puerta hasta quedar encima de ella.
			var p: Vector2i = g["pos"]
			if p.x != HOUSE_CENTER.x:
				g["pos"] = Vector2i(p.x + signi(HOUSE_CENTER.x - p.x), p.y)
			elif p.y > HOUSE_EXIT.y:
				g["pos"] = Vector2i(p.x, p.y - 1)
			if g["pos"] == HOUSE_EXIT:
				g["mode"] = global_mode
				g["dir"] = Vector2i(-1, 0)
			return
		"entering":
			# Ojos que ya llegaron a la puerta: bajan al centro y renacen.
			if g["pos"].y < HOUSE_CENTER.y:
				g["pos"] = Vector2i(g["pos"].x, g["pos"].y + 1)
			else:
				_restore_ghost_look(g)
				g["mode"] = "leaving"
			return

	var is_frightened: bool = g["mode"] == "frightened"
	var is_eaten: bool = g["mode"] == "eaten"
	var target: Vector2i
	if is_eaten:
		target = HOUSE_EXIT
	elif g["mode"] == "scatter":
		target = g["scatter_target"]
	else:
		target = _chase_target(g)

	# Nunca invierte su dirección por su cuenta (solo en cambios de modo);
	# en cada cruce elige la salida que lo deja más cerca de su objetivo,
	# desempatando arriba > izquierda > abajo > derecha como el arcade.
	var options: Array = []
	for d: Vector2i in DIRS:
		if d == -g["dir"]:
			continue
		var n: Vector2i = _wrap(g["pos"] + d)
		if _passable(n, true, false):
			options.append({"dir": d, "pos": n})
	if options.is_empty():
		var back: Vector2i = _wrap(g["pos"] - g["dir"])
		if not _passable(back, true, false):
			return
		options.append({"dir": -g["dir"], "pos": back})

	var chosen: Dictionary = options[0]
	if is_frightened:
		chosen = options[randi() % options.size()]
	else:
		var best := INF
		for o: Dictionary in options:
			var dist: float = Vector2(o["pos"]).distance_squared_to(Vector2(target))
			if dist < best:
				best = dist
				chosen = o
	g["dir"] = chosen["dir"]
	g["pos"] = chosen["pos"]
	if is_eaten:
		g["view"].set_facing(_dir_to_facing_deg(chosen["dir"]))
		if g["pos"] == HOUSE_EXIT:
			g["mode"] = "entering"


func _check_ghost_collision() -> void:
	for g: Dictionary in ghosts:
		if g["mode"] in ["house", "leaving", "entering", "eaten"]:
			continue
		if g["pos"] != player_cell:
			continue
		if g["mode"] == "frightened":
			frightened_combo += 1
			score += COMBO_SCORES[mini(frightened_combo - 1, COMBO_SCORES.size() - 1)]
			_update_hud()
			AudioManager.play_click()
			g["mode"] = "eaten"
			g["view"].shape = "eyes"
			g["view"].color = Color(0.97, 0.97, 1)
			g["view"].color2 = EATEN_EYE_COLOR
			g["view"].queue_redraw()
		else:
			_lose_life()
			return


func _lose_life() -> void:
	lives -= 1
	_update_hud()
	AudioManager.play_lose()
	dying = true
	pause_timer = DEATH_TIME
	for g: Dictionary in ghosts:
		g["view"].visible = false


func _after_death() -> void:
	dying = false
	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over. Puntos: %d" % score
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result(false)
		return
	_reset_positions()


func _advance_level() -> void:
	if level >= MAX_LEVEL:
		_win()
		return
	level += 1
	AudioManager.play_win()
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
