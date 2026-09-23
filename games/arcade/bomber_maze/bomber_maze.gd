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
const MOVE_INTERVAL := 0.14
const BOMB_FUSE := 2.0
const BLAST_RADIUS := 2
const MAX_LEVEL := 10
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const HELP_TEXT := "Muévete con las flechas. Toca 💣 para colocar una bomba en tu celda.

La bomba explota en cruz tras un par de segundos, destruyendo bloques claros (blandos) y a cualquiera atrapado en la explosión — incluido tú, así que aléjate a tiempo. Los pilares oscuros son indestructibles.

Tocar a un enemigo también te quita una vida. Elimina a todos los enemigos del nivel (con las explosiones) para pasar al siguiente. Hay 10 niveles, cada uno con más enemigos. Pierdes si se acaban tus 3 vidas."

var cell_type: Array = []
var cell_views: Array = []

var player_cell: Vector2i = Vector2i.ZERO
var current_dir: Vector2i = Vector2i.ZERO
var move_timer: float = 0.0

var bombs: Array = []
var bomb_active: bool = false

var enemies: Array = []

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var player_view: EntitySprite
var score_label: Label
var lives_label: Label
var level_label: Label
var status_label: Label
var bomb_btn: Button
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

	# --- Controles: cluster de movimiento (izquierda) + botón de bomba
	# prominente (derecha), pensado para pulgares en modo retrato.
	var controls_row := HBoxContainer.new()
	controls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_row.add_theme_constant_override("separation", 40)
	vbox.add_child(controls_row)

	var dpad_box := VBoxContainer.new()
	dpad_box.alignment = BoxContainer.ALIGNMENT_CENTER
	dpad_box.add_theme_constant_override("separation", 8)
	controls_row.add_child(dpad_box)

	var dpad_row1 := HBoxContainer.new()
	dpad_row1.alignment = BoxContainer.ALIGNMENT_CENTER
	dpad_box.add_child(dpad_row1)
	var up_btn := _make_dir_button("▲")
	up_btn.button_down.connect(func() -> void: _set_dir(Vector2i(0, -1)))
	up_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(0, -1)))
	dpad_row1.add_child(up_btn)

	var dpad_row2 := HBoxContainer.new()
	dpad_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	dpad_row2.add_theme_constant_override("separation", 80)
	dpad_box.add_child(dpad_row2)
	var left_btn := _make_dir_button("◀")
	left_btn.button_down.connect(func() -> void: _set_dir(Vector2i(-1, 0)))
	left_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(-1, 0)))
	dpad_row2.add_child(left_btn)
	var right_btn := _make_dir_button("▶")
	right_btn.button_down.connect(func() -> void: _set_dir(Vector2i(1, 0)))
	right_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(1, 0)))
	dpad_row2.add_child(right_btn)

	var dpad_row3 := HBoxContainer.new()
	dpad_row3.alignment = BoxContainer.ALIGNMENT_CENTER
	dpad_box.add_child(dpad_row3)
	var down_btn := _make_dir_button("▼")
	down_btn.button_down.connect(func() -> void: _set_dir(Vector2i(0, 1)))
	down_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(0, 1)))
	dpad_row3.add_child(down_btn)

	bomb_btn = Button.new()
	bomb_btn.text = "💣"
	bomb_btn.custom_minimum_size = Vector2(100, 100)
	bomb_btn.add_theme_font_size_override("font_size", 36)
	UIKit.style_button(bomb_btn, UIKit.COLOR_DANGER, 50)
	bomb_btn.pressed.connect(_on_bomb_pressed)
	controls_row.add_child(bomb_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_dir_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(74, 64)
	btn.add_theme_font_size_override("font_size", 22)
	UIKit.style_button(btn, UIKit.COLOR_ACCENT_2)
	return btn


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

	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			if cell_type[y][x] != "empty" or _near_spawn(x, y):
				continue
			if randf() < 0.55:
				cell_type[y][x] = "soft"


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
	bomb_active = false
	if bomb_btn:
		bomb_btn.disabled = false

	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()

	var spawn_corners: Array = [Vector2i(GRID_W - 2, GRID_H - 2), Vector2i(1, GRID_H - 2), Vector2i(GRID_W - 2, 1)]
	var count: int = min(1 + level / 2, 3)
	var interval: float = max(0.16, 0.34 - level * 0.016)
	for i in range(count):
		var c: Vector2i = spawn_corners[i % spawn_corners.size()]
		var view := EntitySprite.new()
		view.size = Vector2(CELL * 0.82, CELL * 0.82)
		view.position = _cell_pos(c, view.size)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.setup("critter", UIKit.COLOR_DANGER, UIKit.COLOR_TEXT, i)
		play_area.add_child(view)
		enemies.append({"pos": c, "state": "alive", "timer": 0.0, "interval": interval, "view": view, "phase_offset": randf()})

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
	level_label.text = "Nivel %d/%d" % [level, MAX_LEVEL]


func _is_walkable(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= GRID_W or p.y < 0 or p.y >= GRID_H:
		return false
	return cell_type[p.y][p.x] == "empty"


func _on_bomb_pressed() -> void:
	if state != "playing" or bomb_active:
		return
	if cell_type[player_cell.y][player_cell.x] != "empty":
		return
	bomb_active = true
	if bomb_btn:
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

	move_timer += delta
	if move_timer >= MOVE_INTERVAL:
		move_timer = 0.0
		if current_dir != Vector2i.ZERO:
			_try_move_player()
		for e: Dictionary in enemies:
			if e["state"] == "alive":
				_update_enemy(e, MOVE_INTERVAL)

	_update_bombs(delta)
	_check_enemy_touch()

	if state == "playing" and _all_enemies_cleared():
		_advance_level()


func _try_move_player() -> void:
	if current_dir.x != 0:
		player_view.flipped = current_dir.x < 0
	var next: Vector2i = player_cell + current_dir
	if not _is_walkable(next):
		return
	player_cell = next
	player_view.position = _cell_pos(next, player_view.size)


func _update_enemy(e: Dictionary, delta: float) -> void:
	e["timer"] += delta
	if e["timer"] < e["interval"]:
		return
	e["timer"] = 0.0
	var options: Array = []
	for d: Vector2i in DIRS:
		var n: Vector2i = e["pos"] + d
		if _is_walkable(n):
			options.append(n)
	if not options.is_empty():
		e["pos"] = options[randi() % options.size()]
	e["view"].position = _cell_pos(e["pos"], e["view"].size)


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
			bomb_active = false
			if bomb_btn:
				bomb_btn.disabled = false


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
	## destruye como máximo un bloque blando por dirección) y aplica el
	## daño a jugador/enemigos. Separado de _explode_bomb para poder probar
	## la lógica sin disparar la animación visual (UIKit.pulse).
	var affected: Array = [cell]
	for d: Vector2i in DIRS:
		for r in range(1, BLAST_RADIUS + 1):
			var p: Vector2i = cell + d * r
			if p.x < 0 or p.x >= GRID_W or p.y < 0 or p.y >= GRID_H:
				break
			if cell_type[p.y][p.x] == "wall":
				break
			affected.append(p)
			if cell_type[p.y][p.x] == "soft":
				cell_type[p.y][p.x] = "empty"
				_style_cell(p.y, p.x)
				break

	for p: Vector2i in affected:
		if p == player_cell:
			_lose_life()
		for e: Dictionary in enemies:
			if e["state"] == "alive" and e["pos"] == p:
				e["state"] = "removed"
				e["view"].visible = false
				score += 100
				_update_hud()

	return affected


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
