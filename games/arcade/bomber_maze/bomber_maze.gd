extends Control
## Estilo Bomberman: cuadrícula clásica con pilares indestructibles
## en patrón de tablero + bloques blandos destructibles al azar.
## Colocas una bomba, explota en cruz tras un fusible, destruye
## bloques blandos y a cualquiera (tú o los enemigos) atrapado en
## la explosión. 10 niveles.

const GAME_ID := "bomber_maze"
const GRID_W := 13
const GRID_H := 13
const CELL := 50.0
const BASE_MOVE_INTERVAL := 0.14
const MIN_MOVE_INTERVAL := 0.08
const BOMB_FUSE := 2.0
const BASE_BLAST_RADIUS := 2
const MAX_BLAST_RADIUS := 5
const MAX_BOMB_CAPACITY := 5
const MAX_LEVEL := 10
const ENEMY_TICK := 0.08
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const POWERUP_CHANCE := 0.35
## Tipos de enemigo al estilo del NES: el globo es lento y deambula; la
## cebolla es más rápida y a veces te persigue; el fantasma es rápido y te
## caza (sale también al acabarse el tiempo o si bombardeas la salida).
const ENEMY_TYPES := {
	"globo": {"shape": "critter", "color": Color(1.0, 0.55, 0.3), "interval": 0.36, "chase": 0.0, "points": 100},
	"cebolla": {"shape": "alien", "color": Color(0.35, 0.55, 1.0), "interval": 0.26, "chase": 0.35, "points": 200},
	"fantasma": {"shape": "ghost", "color": Color(0.75, 0.45, 0.95), "interval": 0.18, "chase": 0.7, "points": 400},
}
const LEVEL_TIME := 180.0
## Donde nacen los enemigos (casillas impares: nunca son pilares, y se
## dejan libres de bloques al generar el mapa).
const ENEMY_SPAWNS := [Vector2i(11, 11), Vector2i(1, 11), Vector2i(11, 1), Vector2i(7, 11), Vector2i(11, 7), Vector2i(7, 7)]
const POWERUP_KINDS := ["bomb_up", "fire_up", "speed_up"]
const POWERUP_ICON := {"bomb_up": "💣", "fire_up": "🔥", "speed_up": "👟"}
const POWERUP_COLOR := {
	"bomb_up": UIKit.COLOR_DANGER, "fire_up": UIKit.COLOR_ACCENT_3, "speed_up": UIKit.COLOR_ACCENT_2,
}

const HELP_TEXT := "Se juega tocando el tablero, sin botones: pon el dedo y arrástralo hacia donde quieras caminar (mientras lo mantengas, sigues caminando); toca para poner una bomba en tu celda. (En teclado: flechas y espacio.)

La bomba explota en cruz tras un par de segundos, destruyendo bloques claros (blandos) y a cualquiera atrapado en la explosión — incluido tú, así que aléjate a tiempo. Los pilares oscuros son indestructibles. Si una explosión alcanza otra bomba ya colocada, la detona también, en cadena.

Algunos bloques blandos esconden un power-up al destruirlos: 💣 más bombas a la vez, 🔥 más alcance de explosión, 👟 más velocidad. Se acumulan durante toda la partida.

Uno de los bloques blandos esconde además la salida del nivel: después de eliminar a todos los enemigos, encuéntrala (destruyendo bloques) y camina sobre ella para pasar al siguiente nivel — si ya no quedan enemigos y no la has hallado, los bloques que podrían esconderla parpadean en dorado.

Enemigos: 🟠 globo (lento, deambula, 100), 🔵 cebolla (más rápida, a veces te sigue, 200) y 🟣 fantasma (rápido, te caza, 400). Las bombas bloquean el paso a todos.

Tienes 3 minutos por nivel: si se acaba el tiempo, salen fantasmas. ¡Y no bombardees la salida ya descubierta, que suelta más enemigos!

Tocar a un enemigo también te quita una vida. Hay 10 niveles, cada uno con más enemigos. Pierdes si se acaban tus 3 vidas."

var cell_type: Array = []
var cell_views: Array = []

var player_cell: Vector2i = Vector2i.ZERO
var current_dir: Vector2i = Vector2i.ZERO
var move_timer: float = 0.0
var enemy_tick_timer: float = 0.0

var bombs: Array = []
var powerups: Array = []

var enemies: Array = []

var bomb_capacity: int = 1
var blast_radius: int = BASE_BLAST_RADIUS
var move_interval: float = BASE_MOVE_INTERVAL

var level_time_left: float = 180.0
var time_up: bool = false
var door_cell: Vector2i = Vector2i(-1, -1)
var door_revealed: bool = false
var door_hint_shown: bool = false

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var player_view: EntitySprite
var score_label: Label
var lives_label: Label
var level_label: Label
var powerup_label: Label
var status_label: Label
var bomb_btn: Button  # ya no hay botón en pantalla (queda en null)
var pad: GesturePad
const JOYSTICK_DEADZONE := 22.0
var anim_time: float = 0.0


func _ready() -> void:
	_build_ui()
	_new_game()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Laberinto de Bombas", HELP_TEXT)

	# --- HUD: barra delgada con icono de puntos, corazones de vida y nivel ---
	var hud_panel := PanelContainer.new()
	hud_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(hud_panel)

	var hud_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		hud_margin.add_theme_constant_override(side, 8)
	hud_panel.add_child(hud_margin)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 26)
	hud_margin.add_child(hud)
	score_label = UIKit.title_label("⭐ 0", 16, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("❤❤❤", 16, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)
	level_label = UIKit.title_label("Nivel 1/%d" % MAX_LEVEL, 16, UIKit.COLOR_ACCENT_2)
	hud.add_child(level_label)
	powerup_label = UIKit.title_label("💣1 🔥2 👟0", 14, UIKit.COLOR_TEXT_DIM)
	hud.add_child(powerup_label)

	status_label = UIKit.title_label("", 15, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	# --- Laberinto: ocupa la mayor parte posible del ancho de pantalla ---
	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 14, 3))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(GRID_W * CELL, GRID_H * CELL)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			var cell := Panel.new()
			cell.position = Vector2(x * CELL, y * CELL)
			cell.size = Vector2(CELL, CELL)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play_area.add_child(cell)
			row.append(cell)
		cell_views.append(row)

	player_view = EntitySprite.new()
	player_view.size = Vector2(CELL * 0.8, CELL * 0.8)
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.setup("bomber", UIKit.COLOR_ACCENT_3, UIKit.COLOR_ACCENT_2)
	play_area.add_child(player_view)

	# --- Control táctil sin botones: el punto donde pones el dedo es el
	# centro de un joystick invisible -- arrastra hacia un lado para
	# caminar en esa dirección (mientras sigas tocando) y toca para poner
	# una bomba.
	pad = GesturePad.attach(play_area)
	pad.dragged.connect(func(_p: Vector2, from_start: Vector2, _s: Vector2) -> void:
		if from_start.length() >= JOYSTICK_DEADZONE:
			_set_dir(GesturePad._dir_of(from_start)))
	pad.released.connect(func(_p: Vector2) -> void: current_dir = Vector2i.ZERO)
	pad.tapped.connect(func(_p: Vector2) -> void: _on_bomb_pressed())

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _cell_pos(cell: Vector2i, node_size: Vector2) -> Vector2:
	## Centra un nodo de tamaño `node_size` dentro de la celda de grilla dada.
	return Vector2(cell.x * CELL + (CELL - node_size.x) / 2.0, cell.y * CELL + (CELL - node_size.y) / 2.0)


func _set_dir(d: Vector2i) -> void:
	current_dir = d


func _clear_dir(d: Vector2i) -> void:
	if current_dir == d:
		current_dir = Vector2i.ZERO


func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	bomb_capacity = 1
	blast_radius = BASE_BLAST_RADIUS
	move_interval = BASE_MOVE_INTERVAL
	state = "playing"
	_setup_level()


func _generate_grid() -> void:
	cell_type = []
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			var is_border: bool = x == 0 or y == 0 or x == GRID_W - 1 or y == GRID_H - 1
			var is_pillar: bool = x % 2 == 0 and y % 2 == 0
			row.append("wall" if (is_border or is_pillar) else "empty")
		cell_type.append(row)

	var soft_cells: Array = []
	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			if cell_type[y][x] != "empty" or _near_spawn(x, y) or ENEMY_SPAWNS.has(Vector2i(x, y)):
				continue
			if randf() < 0.55:
				cell_type[y][x] = "soft"
				soft_cells.append(Vector2i(x, y))

	door_cell = soft_cells[randi() % soft_cells.size()] if not soft_cells.is_empty() else Vector2i(-1, -1)
	door_revealed = false
	door_hint_shown = false


func _near_spawn(x: int, y: int) -> bool:
	var corners: Array = [Vector2i(1, 1), Vector2i(GRID_W - 2, 1), Vector2i(1, GRID_H - 2), Vector2i(GRID_W - 2, GRID_H - 2)]
	for c: Vector2i in corners:
		if abs(x - c.x) <= 1 and abs(y - c.y) <= 1:
			return true
	return false


func _setup_level() -> void:
	_generate_grid()

	player_cell = Vector2i(1, 1)
	current_dir = Vector2i.ZERO
	player_view.position = _cell_pos(player_cell, player_view.size)
	player_view.flipped = false

	for b: Dictionary in bombs:
		b["view"].queue_free()
	bombs.clear()
	for p: Dictionary in powerups:
		p["view"].queue_free()
	powerups.clear()
	if bomb_btn:
		bomb_btn.disabled = false

	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()

	# Mezcla de tipos por nivel, como el NES: al principio casi puros globos
	# lentos; después más cebollas y fantasmas que te persiguen.
	var spawn_corners: Array = ENEMY_SPAWNS
	var count: int = mini(2 + level / 2, 6)
	for i in range(count):
		var kind: String = "globo"
		var r: float = randf()
		if level >= 3 and r < 0.15 + level * 0.04:
			kind = "fantasma"
		elif level >= 2 and r < 0.45 + level * 0.03:
			kind = "cebolla"
		_spawn_enemy(spawn_corners[i % spawn_corners.size()], kind)

	level_time_left = LEVEL_TIME
	time_up = false
	_redraw_grid()
	status_label.text = ""
	status_label.remove_theme_color_override("font_color")
	_update_hud()


func _redraw_grid() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			_style_cell(y, x)


func _style_cell(y: int, x: int) -> void:
	var view: Panel = cell_views[y][x]
	var color: Color
	var border: Color = Color(0, 0, 0, 0)
	var radius: int = 0
	var border_w: int = 0
	match cell_type[y][x]:
		"wall":
			color = UIKit.COLOR_BG.darkened(0.08)
			border = UIKit.COLOR_BG_LIGHT
			radius = 2
			border_w = 2
		"soft":
			color = UIKit.COLOR_ACCENT_2.lerp(UIKit.COLOR_BG, 0.25)
			border = UIKit.COLOR_ACCENT_2.darkened(0.35)
			radius = 6
			border_w = 2
			if door_hint_shown and Vector2i(x, y) == door_cell:
				border = UIKit.COLOR_ACCENT_3
				border_w = 3
		"door":
			color = UIKit.COLOR_ACCENT_3.lerp(UIKit.COLOR_BG_LIGHT, 0.35)
			border = UIKit.COLOR_ACCENT_3
			radius = 8
			border_w = 3
		_:
			# piso a cuadros para que la zona caminable se lea como tablero
			color = UIKit.COLOR_BG_LIGHT if (x + y) % 2 == 0 else UIKit.COLOR_BG_LIGHT.darkened(0.05)
	view.add_theme_stylebox_override("panel", UIKit.stylebox(color, border, radius, border_w))


func _update_hud() -> void:
	score_label.text = "⭐ %d" % score
	var hearts := ""
	for i in range(3):
		hearts += "❤" if i < lives else "♡"
	lives_label.text = hearts
	level_label.text = "Nivel %d/%d  ⏱%d" % [level, MAX_LEVEL, ceili(level_time_left)]
	powerup_label.text = "💣%d 🔥%d 👟%d" % [bomb_capacity, blast_radius, roundi((BASE_MOVE_INTERVAL - move_interval) / 0.02)]


func _is_walkable(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= GRID_W or p.y < 0 or p.y >= GRID_H:
		return false
	return cell_type[p.y][p.x] == "empty" or cell_type[p.y][p.x] == "door"


func _on_bomb_pressed() -> void:
	if state != "playing" or bombs.size() >= bomb_capacity:
		return
	if cell_type[player_cell.y][player_cell.x] != "empty":
		return
	for b: Dictionary in bombs:
		if b["cell"] == player_cell:
			return
	if bombs.size() + 1 >= bomb_capacity and bomb_btn:
		bomb_btn.disabled = true
	var view := EntitySprite.new()
	view.size = Vector2(CELL * 0.72, CELL * 0.72)
	view.position = _cell_pos(player_cell, view.size)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("bomb", UIKit.COLOR_TEXT, UIKit.COLOR_TEXT)
	play_area.add_child(view)
	bombs.append({"cell": player_cell, "timer": BOMB_FUSE, "view": view, "anim_t": 0.0})


func _process(delta: float) -> void:
	if state != "playing":
		return

	anim_time += delta
	player_view.set_phase(anim_time * 0.6)
	for e: Dictionary in enemies:
		if e["state"] == "alive":
			e["view"].set_phase(anim_time * 0.9 + e["phase_offset"])

	# El jugador avanza según `move_interval` (se acorta con el power-up de
	# velocidad); los enemigos usan su propio tick fijo, independiente de
	# las mejoras del jugador, para no acelerarse con ellas por accidente.
	move_timer += delta
	if move_timer >= move_interval:
		move_timer = 0.0
		if current_dir != Vector2i.ZERO:
			_try_move_player()

	enemy_tick_timer += delta
	if enemy_tick_timer >= ENEMY_TICK:
		enemy_tick_timer = 0.0
		for e: Dictionary in enemies:
			if e["state"] == "alive":
				_update_enemy(e, ENEMY_TICK)

	# Reloj del nivel: al llegar a 0 salen fantasmas rápidos (en el NES,
	# los "Pontan"), así que no conviene tardarse.
	var before: int = ceili(level_time_left)
	level_time_left = maxf(level_time_left - delta, 0.0)
	if ceili(level_time_left) != before:
		_update_hud()
	if level_time_left <= 0.0 and not time_up:
		time_up = true
		for c: Vector2i in ENEMY_SPAWNS.slice(0, 4):
			if _is_walkable(c):
				_spawn_enemy(c, "fantasma")
		status_label.text = "¡Se acabó el tiempo! Vienen los fantasmas"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		AudioManager.play_alert()

	_update_bombs(delta)
	_check_enemy_touch()

	if state == "playing" and _all_enemies_cleared():
		if not door_revealed and not door_hint_shown:
			_show_door_hint()
		elif door_revealed and player_cell == door_cell:
			_advance_level()


func _show_door_hint() -> void:
	## Todos los enemigos muertos y la puerta aún no aparece: los bloques
	## blandos restantes (donde podría estar escondida) brillan en dorado,
	## para que encontrarla en móvil no dependa de memorizar el mapa.
	door_hint_shown = true
	for y in range(GRID_H):
		for x in range(GRID_W):
			if cell_type[y][x] == "soft":
				_style_cell(y, x)


func _try_move_player() -> void:
	if current_dir.x != 0:
		player_view.flipped = current_dir.x < 0
	var next: Vector2i = player_cell + current_dir
	if not _is_walkable(next):
		return
	for b: Dictionary in bombs:
		if b["cell"] == next:
			return  # las bombas bloquean el paso (puedes salir de la tuya, no volver a entrar)
	player_cell = next
	player_view.position = _cell_pos(next, player_view.size)
	_try_collect_powerup(next)


func _try_collect_powerup(cell: Vector2i) -> void:
	for i in range(powerups.size() - 1, -1, -1):
		var p: Dictionary = powerups[i]
		if p["cell"] != cell:
			continue
		match p["kind"]:
			"bomb_up":
				bomb_capacity = min(bomb_capacity + 1, MAX_BOMB_CAPACITY)
			"fire_up":
				blast_radius = min(blast_radius + 1, MAX_BLAST_RADIUS)
			"speed_up":
				move_interval = max(MIN_MOVE_INTERVAL, move_interval - 0.02)
		AudioManager.play_place()
		p["view"].queue_free()
		powerups.remove_at(i)
		_update_hud()
		return


func _spawn_enemy(c: Vector2i, kind: String) -> void:
	var info: Dictionary = ENEMY_TYPES[kind]
	var view := EntitySprite.new()
	view.size = Vector2(CELL * 0.82, CELL * 0.82)
	view.position = _cell_pos(c, view.size)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup(info["shape"], info["color"], UIKit.COLOR_TEXT, enemies.size())
	play_area.add_child(view)
	var interval: float = maxf(0.12, float(info["interval"]) - level * 0.01)
	enemies.append({"pos": c, "state": "alive", "timer": 0.0, "interval": interval, "view": view,
		"phase_offset": randf(), "kind": kind, "dir": DIRS[randi() % DIRS.size()]})


## ¿Puede un enemigo entrar ahí? Las bombas bloquean el paso, como en el NES.
func _enemy_can_enter(p: Vector2i) -> bool:
	if not _is_walkable(p):
		return false
	for b: Dictionary in bombs:
		if b["cell"] == p:
			return false
	return true


## Caminan derecho y en los cruces a veces doblan (no tiemblan al azar en
## cada paso). Cebollas y fantasmas además giran hacia ti si estás cerca.
func _update_enemy(e: Dictionary, delta: float) -> void:
	e["timer"] += delta
	if e["timer"] < e["interval"]:
		return
	e["timer"] = 0.0
	var options: Array = []
	for d: Vector2i in DIRS:
		if _enemy_can_enter(e["pos"] + d):
			options.append(d)
	if options.is_empty():
		return
	var dir: Vector2i = e["dir"]
	var chase: float = ENEMY_TYPES[e["kind"]]["chase"]
	var to_player: Vector2i = player_cell - e["pos"]
	var near: bool = absi(to_player.x) + absi(to_player.y) <= 6
	if near and randf() < chase:
		# Elige la salida que más lo acerca al jugador.
		var best_d: Vector2i = options[0]
		var best := INF
		for d: Vector2i in options:
			var dist: float = Vector2(e["pos"] + d).distance_to(Vector2(player_cell))
			if dist < best:
				best = dist
				best_d = d
		dir = best_d
	elif not options.has(dir):
		# Chocó: se da la vuelta o toma otra salida.
		dir = options[randi() % options.size()]
	elif options.size() > 2 and randf() < 0.3:
		dir = options[randi() % options.size()]  # dobla en un cruce
	e["dir"] = dir
	e["pos"] = e["pos"] + dir
	e["view"].position = _cell_pos(e["pos"], e["view"].size)
	if dir.x != 0:
		e["view"].flipped = dir.x < 0


func _update_bombs(delta: float) -> void:
	for i in range(bombs.size() - 1, -1, -1):
		var b: Dictionary = bombs[i]
		b["timer"] -= delta
		# El fusible acelera visualmente el pulso/parpadeo de la bomba a medida
		# que se acerca la detonación (0 = recién colocada, 1 = por explotar).
		var progress: float = clamp(1.0 - (b["timer"] / BOMB_FUSE), 0.0, 1.0)
		var rate: float = lerp(1.2, 4.5, progress)
		b["anim_t"] += delta * rate
		b["view"].set_phase(b["anim_t"])
		if b["timer"] <= 0.0:
			_explode_bomb(b)
			bombs.remove_at(i)
			if bomb_btn:
				bomb_btn.disabled = bombs.size() >= bomb_capacity


func _explode_bomb(b: Dictionary) -> void:
	var affected: Array = _apply_explosion(b["cell"])
	b["view"].queue_free()
	_spawn_blast(affected)


func _spawn_blast(cells: Array) -> void:
	## Efecto visual de la explosión: un EntitySprite "blast" por celda afectada,
	## animado de phase 0 -> 1 con un Tween y luego liberado. Puramente visual;
	## la lógica de daño ya se resolvió en _apply_explosion().
	for p: Vector2i in cells:
		UIKit.pulse(cell_views[p.y][p.x])
		var blast := EntitySprite.new()
		blast.size = Vector2(CELL * 0.98, CELL * 0.98)
		blast.position = _cell_pos(p, blast.size)
		blast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blast.setup("blast", UIKit.COLOR_ACCENT_3, UIKit.COLOR_ACCENT_3)
		play_area.add_child(blast)
		var tween := blast.create_tween()
		tween.tween_method(blast.set_phase, 0.0, 1.0, 0.25)
		tween.tween_callback(blast.queue_free)


func _apply_explosion(cell: Vector2i) -> Array:
	## Calcula las celdas afectadas por la explosión (se detiene en paredes,
	## destruye como máximo un bloque blando por dirección), revela la
	## puerta o suelta un power-up al destruir el bloque que los escondía,
	## detona en cadena cualquier otra bomba alcanzada, y aplica el daño a
	## jugador/enemigos. Separado de _explode_bomb (que además dispara el
	## efecto visual) para poder probar la lógica sin UIKit.pulse.
	var affected: Array = [cell]
	var door_hit := false
	for d: Vector2i in DIRS:
		for r in range(1, blast_radius + 1):
			var p: Vector2i = cell + d * r
			if p.x < 0 or p.x >= GRID_W or p.y < 0 or p.y >= GRID_H:
				break
			if cell_type[p.y][p.x] == "wall":
				break
			affected.append(p)
			if cell_type[p.y][p.x] == "door":
				door_hit = true
			if cell_type[p.y][p.x] == "soft":
				if p == door_cell:
					cell_type[p.y][p.x] = "door"
					door_revealed = true
				else:
					cell_type[p.y][p.x] = "empty"
					if randf() < POWERUP_CHANCE:
						_spawn_powerup(p)
				_style_cell(p.y, p.x)
				break

	for p: Vector2i in affected:
		if p == player_cell:
			_lose_life()
		for e: Dictionary in enemies:
			if e["state"] == "alive" and e["pos"] == p:
				e["state"] = "removed"
				e["view"].visible = false
				score += int(ENEMY_TYPES[e["kind"]]["points"])
				_update_hud()
		for other_b: Dictionary in bombs:
			if other_b["cell"] == p and other_b["timer"] > 0.0:
				other_b["timer"] = 0.0  # reacción en cadena: detona en el próximo tick

	# Como en el NES: bombardear la salida ya descubierta la "enoja" y suelta
	# enemigos rápidos.
	if door_hit:
		for i in range(3):
			_spawn_enemy(door_cell, "fantasma")
		status_label.text = "¡Bombardeaste la salida! Salieron más enemigos"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		AudioManager.play_alert()

	return affected


func _spawn_powerup(cell: Vector2i) -> void:
	var kind: String = POWERUP_KINDS[randi() % POWERUP_KINDS.size()]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(POWERUP_COLOR[kind].darkened(0.55), POWERUP_COLOR[kind], 8, 2))
	panel.size = Vector2(CELL * 0.62, CELL * 0.62)
	panel.position = _cell_pos(cell, panel.size)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = POWERUP_ICON[kind]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	panel.add_child(lbl)
	play_area.add_child(panel)
	powerups.append({"cell": cell, "kind": kind, "view": panel})


func _check_enemy_touch() -> void:
	for e: Dictionary in enemies:
		if e["state"] == "alive" and e["pos"] == player_cell:
			_lose_life()
			return


func _all_enemies_cleared() -> bool:
	for e: Dictionary in enemies:
		if e["state"] != "removed":
			return false
	return true


func _lose_life() -> void:
	lives -= 1
	_update_hud()
	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over. Puntos: %d" % score
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result(false)
		return
	player_cell = Vector2i(1, 1)
	current_dir = Vector2i.ZERO
	player_view.position = _cell_pos(player_cell, player_view.size)


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


func _unhandled_key_input(event: InputEvent) -> void:
	var dirs := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0)}
	if dirs.has(event.keycode):
		if event.pressed:
			_set_dir(dirs[event.keycode])
		else:
			_clear_dir(dirs[event.keycode])
	elif event.keycode == KEY_SPACE and event.pressed and not event.echo:
		_on_bomb_pressed()
