extends Control
## Estilo Galaga: formación de nave enemigas que se mecen arriba y de
## vez en cuando una se lanza en picada hacia ti disparando. Mata la
## formación completa (las que se quedan Y las que bajan en picada)
## para pasar de nivel. 10 niveles.

const GAME_ID := "galaga_swarm"
const PLAY_W := 680.0
const PLAY_H := 880.0
const PLAYER_SIZE := Vector2(36, 36)
const PLAYER_SPEED := 260.0
const PLAYER_Y := 818.0
const BULLET_SPEED := 520.0
const SHOOT_COOLDOWN := 0.26
const ENEMY_SIZE := Vector2(26, 22)
const FORMATION_COLS := 7
const FORMATION_TOP := 70.0
const ROW_SPACING := 46.0
const COL_SPACING := 78.0
const SWAY_SPEED := 1.6
const SWAY_AMPLITUDE := 22.0
const DIVE_SPEED := 250.0
const ENEMY_BULLET_SPEED := 280.0
const MAX_LEVEL := 10
const STAR_COUNT := 34
# Cada fila de la formación tiene su propia silueta/color: la fila 0 son
# "sentries" (escolta de élite, escudo giratorio) y el resto son "aliens"
# insectoides con aleteo animado — así la formación se lee con jerarquía
# visual en vez de ser fichas idénticas repetidas.
const ROW_VISUALS := [
	{"shape": "sentry", "color": UIKit.COLOR_DANGER, "color2": UIKit.COLOR_ACCENT_3},
	{"shape": "alien", "color": UIKit.COLOR_ACCENT, "color2": UIKit.COLOR_ACCENT_3},
	{"shape": "alien", "color": UIKit.COLOR_ACCENT_2, "color2": UIKit.COLOR_TEXT},
	{"shape": "alien", "color": UIKit.COLOR_ACCENT_3, "color2": UIKit.COLOR_ACCENT},
	{"shape": "alien", "color": UIKit.COLOR_TEXT_DIM, "color2": UIKit.COLOR_ACCENT_2},
	{"shape": "alien", "color": Color(0.75, 0.30, 0.38), "color2": UIKit.COLOR_TEXT_DIM},
]

const HELP_TEXT := "Muévete con ◀ ▶ y dispara con 🔫 hacia arriba.

La formación de naves se mece de un lado a otro. De vez en cuando una nave se lanza en picada hacia ti y dispara — esquívala o destrúyela (vale más puntos que una que sigue en formación).

Destruye toda la formación (incluyendo las que se lanzan en picada) para pasar de nivel. Hay 10 niveles, cada uno con más filas y picadas más frecuentes. Pierdes si se acaban tus 3 vidas."

var time_acc: float = 0.0
var player_x: float = 0.0
var moving_left: bool = false
var moving_right: bool = false
var shoot_cooldown: float = 0.0

var enemies: Array = []
var bullets: Array = []
var enemy_bullets: Array = []
var dive_timer: float = 0.0
var dive_interval: float = 1.6
var stars: Array = []

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var player_view: EntitySprite
var score_label: Label
var lives_label: Label
var status_label: Label


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
		margin.add_theme_constant_override(side, 12)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Enjambre Estelar", HELP_TEXT)

	# Barra HUD delgada: un panel tipo "tablero de mando" con puntaje,
	# vidas y nivel en una sola franja compacta, para dejarle todo el
	# resto de la pantalla al área de juego.
	var hud_panel := PanelContainer.new()
	hud_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_2, 10, 2))
	vbox.add_child(hud_panel)

	var hud_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		hud_margin.add_theme_constant_override(side, 6)
	hud_panel.add_child(hud_margin)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 22)
	hud_margin.add_child(hud)
	score_label = UIKit.title_label("★ 0", 15, UIKit.COLOR_ACCENT_3)
	hud.add_child(score_label)
	status_label = UIKit.title_label("Nivel 1 / %d" % MAX_LEVEL, 15, UIKit.COLOR_TEXT_DIM)
	hud.add_child(status_label)
	lives_label = UIKit.title_label("♥ 3", 15, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	_build_starfield()

	player_view = EntitySprite.new()
	player_view.size = PLAYER_SIZE
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.setup("ship", UIKit.COLOR_ACCENT_2, UIKit.COLOR_ACCENT_3)
	play_area.add_child(player_view)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	vbox.add_child(controls)

	var left_btn := _make_control_button("◀", UIKit.COLOR_ACCENT_2)
	left_btn.button_down.connect(func() -> void: moving_left = true)
	left_btn.button_up.connect(func() -> void: moving_left = false)
	controls.add_child(left_btn)

	var shoot_btn := _make_control_button("🔫", UIKit.COLOR_ACCENT, Vector2(118, 84))
	shoot_btn.pressed.connect(_on_shoot_pressed)
	controls.add_child(shoot_btn)

	var right_btn := _make_control_button("▶", UIKit.COLOR_ACCENT_2)
	right_btn.button_down.connect(func() -> void: moving_right = true)
	right_btn.button_up.connect(func() -> void: moving_right = false)
	controls.add_child(right_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_control_button(label: String, accent: Color, sz: Vector2 = Vector2(100, 84)) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = sz
	btn.add_theme_font_size_override("font_size", 26)
	UIKit.style_button(btn, accent)
	return btn


func _build_starfield() -> void:
	## Fondo de estrellas dibujado con puntos diminutos que se desplazan
	## lentamente hacia abajo — barato de animar y vende la ambientación
	## espacial mucho mejor que un panel plano.
	var layer := Control.new()
	layer.size = Vector2(PLAY_W, PLAY_H)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_area.add_child(layer)
	for i in STAR_COUNT:
		var star := ColorRect.new()
		var sz: float = 1.0 + randf() * 1.6
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf() * PLAY_W, randf() * PLAY_H)
		var b: float = 0.35 + randf() * 0.5
		star.color = Color(b, b, b + 0.05, 0.5 + randf() * 0.35)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(star)
		stars.append({"view": star, "speed": 26.0 + randf() * 58.0})


func _update_starfield(delta: float) -> void:
	for st: Dictionary in stars:
		var v: ColorRect = st["view"]
		var p: Vector2 = v.position
		p.y += st["speed"] * delta
		if p.y > PLAY_H:
			p.y -= PLAY_H
			p.x = randf() * PLAY_W
		v.position = p


func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	state = "playing"
	_setup_level()


func _setup_level() -> void:
	player_x = PLAY_W / 2.0 - PLAYER_SIZE.x / 2.0
	player_view.position = Vector2(player_x, PLAYER_Y)

	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()
	for b: Dictionary in bullets:
		b["view"].queue_free()
	bullets.clear()
	for b: Dictionary in enemy_bullets:
		b["view"].queue_free()
	enemy_bullets.clear()

	var rows: int = min(2 + level / 2, 6)
	var total_width: float = (FORMATION_COLS - 1) * COL_SPACING
	var start_x: float = (PLAY_W - total_width) / 2.0 - ENEMY_SIZE.x / 2.0

	for r in range(rows):
		var visual: Dictionary = ROW_VISUALS[r % ROW_VISUALS.size()]
		for c in range(FORMATION_COLS):
			var bx: float = start_x + c * COL_SPACING
			var by: float = FORMATION_TOP + r * ROW_SPACING
			var view := EntitySprite.new()
			view.size = ENEMY_SIZE
			view.position = Vector2(bx, by)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.setup(visual["shape"], visual["color"], visual["color2"], r * FORMATION_COLS + c)
			play_area.add_child(view)
			enemies.append({
				"base_x": bx, "base_y": by, "pos": Vector2(bx, by), "state": "formation",
				"dive_vel": Vector2.ZERO, "phase": randf() * TAU, "wing_seed": randf(),
				"has_shot": false, "view": view,
			})

	dive_interval = max(0.5, 1.7 - level * 0.1)
	dive_timer = dive_interval
	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_update_hud()


func _update_hud() -> void:
	score_label.text = "★ %d" % score
	lives_label.text = "♥ %d" % lives


func _on_shoot_pressed() -> void:
	if state != "playing" or shoot_cooldown > 0.0:
		return
	shoot_cooldown = SHOOT_COOLDOWN
	var pos := Vector2(player_x + PLAYER_SIZE.x / 2.0 - 4.0, PLAYER_Y - 10.0)
	var view := EntitySprite.new()
	view.size = Vector2(8, 14)
	view.position = pos
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("bullet", UIKit.COLOR_ACCENT_3, UIKit.COLOR_TEXT)
	view.set_facing(0.0)
	play_area.add_child(view)
	bullets.append({"pos": pos, "vel": Vector2(0, -BULLET_SPEED), "view": view})


func _process(delta: float) -> void:
	_update_starfield(delta)
	if state != "playing":
		return

	time_acc += delta
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta

	_update_player(delta)
	player_view.set_phase(fmod(time_acc * 3.0, 1.0))

	dive_timer -= delta
	if dive_timer <= 0.0:
		dive_timer = dive_interval
		_start_random_dive()

	for e: Dictionary in enemies:
		if e["state"] == "removed":
			continue
		e["view"].set_phase(fmod(time_acc * 1.4 + e["wing_seed"], 1.0))
		if e["state"] == "formation":
			e["pos"].x = e["base_x"] + sin(time_acc * SWAY_SPEED + e["phase"]) * SWAY_AMPLITUDE
			e["pos"].y = e["base_y"]
			e["view"].position = e["pos"]
		elif e["state"] == "diving":
			e["pos"] += e["dive_vel"] * delta
			e["view"].position = e["pos"]
			if e["pos"].y > PLAY_H:
				_remove_enemy(e, false)
			elif not e["has_shot"] and e["pos"].y > PLAYER_Y * 0.35:
				e["has_shot"] = true
				_spawn_enemy_bullet(e)

	_update_bullets(delta)
	_update_enemy_bullets(delta)
	_check_dive_collisions()

	if state == "playing" and _all_enemies_cleared():
		_advance_level()


func _update_player(delta: float) -> void:
	var vx := 0.0
	if moving_left and not moving_right:
		vx = -PLAYER_SPEED
	elif moving_right and not moving_left:
		vx = PLAYER_SPEED
	player_x = clamp(player_x + vx * delta, 0.0, PLAY_W - PLAYER_SIZE.x)
	player_view.position = Vector2(player_x, PLAYER_Y)


func _start_random_dive() -> void:
	var candidates: Array = []
	for e: Dictionary in enemies:
		if e["state"] == "formation":
			candidates.append(e)
	if candidates.is_empty():
		return
	var e: Dictionary = candidates[randi() % candidates.size()]
	e["state"] = "diving"
	e["has_shot"] = false
	var target := Vector2(player_x + PLAYER_SIZE.x / 2.0, PLAY_H)
	e["dive_vel"] = (target - e["pos"]).normalized() * DIVE_SPEED


func _spawn_enemy_bullet(e: Dictionary) -> void:
	var pos: Vector2 = e["pos"] + Vector2(ENEMY_SIZE.x / 2.0 - 4.0, ENEMY_SIZE.y)
	var view := EntitySprite.new()
	view.size = Vector2(8, 12)
	view.position = pos
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("bullet", UIKit.COLOR_DANGER, UIKit.COLOR_ACCENT_3)
	view.set_facing(180.0)
	play_area.add_child(view)
	enemy_bullets.append({"pos": pos, "vel": Vector2(0, ENEMY_BULLET_SPEED), "view": view})


func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["pos"] += b["vel"] * delta
		b["view"].position = b["pos"]
		if b["pos"].y < 0.0:
			b["view"].queue_free()
			bullets.remove_at(i)
			continue

		var bullet_rect := Rect2(b["pos"], Vector2(8, 14))
		var hit := false
		for e: Dictionary in enemies:
			if e["state"] == "removed":
				continue
			if bullet_rect.intersects(Rect2(e["pos"], ENEMY_SIZE)):
				_remove_enemy(e, true)
				hit = true
				break
		if hit:
			b["view"].queue_free()
			bullets.remove_at(i)


func _update_enemy_bullets(delta: float) -> void:
	var player_rect := Rect2(player_x, PLAYER_Y, PLAYER_SIZE.x, PLAYER_SIZE.y)
	for i in range(enemy_bullets.size() - 1, -1, -1):
		var b: Dictionary = enemy_bullets[i]
		b["pos"] += b["vel"] * delta
		b["view"].position = b["pos"]
		if b["pos"].y > PLAY_H:
			b["view"].queue_free()
			enemy_bullets.remove_at(i)
			continue
		if Rect2(b["pos"], Vector2(8, 12)).intersects(player_rect):
			b["view"].queue_free()
			enemy_bullets.remove_at(i)
			_lose_life()


func _check_dive_collisions() -> void:
	var player_rect := Rect2(player_x, PLAYER_Y, PLAYER_SIZE.x, PLAYER_SIZE.y)
	for e: Dictionary in enemies:
		if e["state"] == "diving" and Rect2(e["pos"], ENEMY_SIZE).intersects(player_rect):
			_remove_enemy(e, false)
			_lose_life()
			return


func _remove_enemy(e: Dictionary, by_bullet: bool) -> void:
	if by_bullet:
		score += 150 if e["state"] == "diving" else 50
		_update_hud()
	e["state"] = "removed"
	e["view"].visible = false


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
