extends Control
## Estilo Sunset Riders: disparos horizontales tipo "galería de tiro".
## Te mueves por una franja de terreno; bandidos entran por los lados
## — unos se acercan cuerpo a cuerpo, otros se detienen y disparan.
## Limpia la cuota de bandidos de cada nivel para avanzar. 10 niveles.

const GAME_ID := "gunslinger"
const PLAY_W := 640.0
const PLAY_H := 480.0
const GROUND_Y := 400.0
const PLAYER_SIZE := Vector2(30, 50)
const ENEMY_SIZE := Vector2(28, 46)
const PLAYER_SPEED := 220.0
const BULLET_SPEED := 560.0
const ENEMY_BULLET_SPEED := 300.0
const SHOOT_COOLDOWN := 0.22
const MELEE_RANGE := 36.0
const RANGED_STOP_DIST := 220.0
const MAX_ON_SCREEN := 4
const MAX_LEVEL := 10

const HELP_TEXT := "Muévete con ◀ ▶ (también apuntas hacia donde te mueves) y dispara con 🔫.

Los bandidos entran por los lados: los que se acercan directo te quitan una vida si te tocan (dispárales antes). Los que se quedan a distancia disparan hacia ti — muévete para esquivar sus balas.

Limpia la cuota de bandidos del nivel para pasar al siguiente. Hay 10 niveles, cada uno con más bandidos, más rápidos y con más disparadores a distancia. Pierdes si se acaban tus 3 vidas."

var player_x: float = 0.0
var facing: int = 1
var moving_left: bool = false
var moving_right: bool = false
var shoot_cooldown: float = 0.0

var enemies: Array = []
var bullets: Array = []
var enemy_bullets: Array = []

var kills: int = 0
var kills_needed: int = 8
var spawn_timer: float = 0.0
var spawn_interval: float = 1.2
var enemy_speed: float = 70.0
var ranged_chance: float = 0.2

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var player_view: GamePiece
var score_label: Label
var lives_label: Label
var status_label: Label
var progress_label: Label


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
		margin.add_theme_constant_override(side, 20)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Pistoleros del Ocaso", HELP_TEXT)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 24)
	vbox.add_child(hud)
	score_label = UIKit.title_label("Puntos: 0", 15, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("Vidas: 3", 15, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)

	status_label = UIKit.title_label("Nivel 1", 14, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)
	progress_label = UIKit.title_label("", 13, UIKit.COLOR_ACCENT_2)
	vbox.add_child(progress_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	var ground := Panel.new()
	ground.position = Vector2(0, GROUND_Y)
	ground.size = Vector2(PLAY_W, PLAY_H - GROUND_Y)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_ACCENT_2.lerp(UIKit.COLOR_BG, 0.6), Color(0, 0, 0, 0), 0))
	play_area.add_child(ground)

	player_view = GamePiece.new()
	player_view.size = PLAYER_SIZE
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.set_piece(UIKit.COLOR_ACCENT_3)
	play_area.add_child(player_view)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	vbox.add_child(controls)

	var left_btn := _make_control_button("◀")
	left_btn.button_down.connect(func() -> void: moving_left = true)
	left_btn.button_up.connect(func() -> void: moving_left = false)
	controls.add_child(left_btn)

	var shoot_btn := _make_control_button("🔫")
	shoot_btn.pressed.connect(_on_shoot_pressed)
	controls.add_child(shoot_btn)

	var right_btn := _make_control_button("▶")
	right_btn.button_down.connect(func() -> void: moving_right = true)
	right_btn.button_up.connect(func() -> void: moving_right = false)
	controls.add_child(right_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_control_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(90, 68)
	btn.add_theme_font_size_override("font_size", 24)
	UIKit.style_button(btn, UIKit.COLOR_ACCENT_2)
	return btn


func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	state = "playing"
	_setup_level()


func _setup_level() -> void:
	player_x = PLAY_W / 2.0 - PLAYER_SIZE.x / 2.0
	facing = 1
	player_view.position = Vector2(player_x, GROUND_Y - PLAYER_SIZE.y)

	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()
	for b: Dictionary in bullets:
		b["view"].queue_free()
	bullets.clear()
	for b: Dictionary in enemy_bullets:
		b["view"].queue_free()
	enemy_bullets.clear()

	kills = 0
	kills_needed = 7 + level
	spawn_timer = 0.0
	spawn_interval = max(0.55, 1.3 - level * 0.07)
	enemy_speed = 65.0 + level * 6.0
	ranged_chance = min(0.15 + level * 0.045, 0.6)

	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_update_hud()


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "Vidas: %d" % lives
	progress_label.text = "Bandidos: %d / %d" % [kills, kills_needed]


func _on_shoot_pressed() -> void:
	if state != "playing" or shoot_cooldown > 0.0:
		return
	shoot_cooldown = SHOOT_COOLDOWN
	var pos := Vector2(player_x + (PLAYER_SIZE.x if facing > 0 else 0.0), GROUND_Y - PLAYER_SIZE.y / 2.0 - 6.0)
	var view := GamePiece.new()
	view.size = Vector2(12, 8)
	view.position = pos
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_piece(UIKit.COLOR_TEXT)
	play_area.add_child(view)
	bullets.append({"pos": pos, "vel": Vector2(facing * BULLET_SPEED, 0), "view": view})


func _spawn_enemy() -> void:
	var side: int = 1 if randi() % 2 == 0 else -1
	var x: float = (PLAY_W - ENEMY_SIZE.x) if side == 1 else 0.0
	var kind: String = "ranged" if randf() < ranged_chance else "melee"
	var view := GamePiece.new()
	view.size = ENEMY_SIZE
	view.position = Vector2(x, GROUND_Y - ENEMY_SIZE.y)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_piece(UIKit.COLOR_ACCENT_2 if kind == "ranged" else UIKit.COLOR_DANGER)
	play_area.add_child(view)
	enemies.append({
		"x": x, "kind": kind, "state": "alive",
		"shoot_timer": randf_range(0.6, 1.4), "view": view,
	})


func _process(delta: float) -> void:
	if state != "playing":
		return

	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta

	_update_player(delta)

	var alive_count := 0
	for e: Dictionary in enemies:
		if e["state"] == "alive":
			alive_count += 1

	spawn_timer -= delta
	if spawn_timer <= 0.0 and alive_count < MAX_ON_SCREEN and kills + alive_count < kills_needed:
		spawn_timer = spawn_interval
		_spawn_enemy()

	for e: Dictionary in enemies:
		if e["state"] == "alive":
			_update_enemy(e, delta)

	_update_bullets(delta)
	_update_enemy_bullets(delta)

	if state == "playing" and kills >= kills_needed and alive_count == 0:
		_advance_level()


func _update_player(delta: float) -> void:
	var vx := 0.0
	if moving_left and not moving_right:
		vx = -PLAYER_SPEED
		facing = -1
	elif moving_right and not moving_left:
		vx = PLAYER_SPEED
		facing = 1
	player_x = clamp(player_x + vx * delta, 0.0, PLAY_W - PLAYER_SIZE.x)
	player_view.position = Vector2(player_x, GROUND_Y - PLAYER_SIZE.y)


func _update_enemy(e: Dictionary, delta: float) -> void:
	var player_center: float = player_x + PLAYER_SIZE.x / 2.0
	var enemy_center: float = e["x"] + ENEMY_SIZE.x / 2.0
	var dx: float = player_center - enemy_center
	var dir: float = sign(dx) if abs(dx) > 4.0 else 0.0

	if e["kind"] == "melee":
		e["x"] += dir * enemy_speed * delta
		if abs(dx) < MELEE_RANGE:
			_remove_enemy(e)
			_lose_life()
			return
	else:
		if abs(dx) > RANGED_STOP_DIST:
			e["x"] += dir * enemy_speed * delta
		e["shoot_timer"] -= delta
		if e["shoot_timer"] <= 0.0:
			e["shoot_timer"] = randf_range(1.0, 1.8)
			_spawn_enemy_bullet(e)

	e["view"].position = Vector2(e["x"], GROUND_Y - ENEMY_SIZE.y)


func _spawn_enemy_bullet(e: Dictionary) -> void:
	var player_center: float = player_x + PLAYER_SIZE.x / 2.0
	var enemy_center: float = e["x"] + ENEMY_SIZE.x / 2.0
	var dir: float = sign(player_center - enemy_center)
	if dir == 0.0:
		dir = 1.0
	var pos := Vector2(enemy_center, GROUND_Y - ENEMY_SIZE.y / 2.0)
	var view := GamePiece.new()
	view.size = Vector2(10, 8)
	view.position = pos
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_piece(UIKit.COLOR_DANGER)
	play_area.add_child(view)
	enemy_bullets.append({"pos": pos, "vel": Vector2(dir * ENEMY_BULLET_SPEED, 0), "view": view})


func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["pos"] += b["vel"] * delta
		b["view"].position = b["pos"]
		if b["pos"].x < 0.0 or b["pos"].x > PLAY_W:
			b["view"].queue_free()
			bullets.remove_at(i)
			continue

		var bullet_rect := Rect2(b["pos"], Vector2(12, 8))
		var hit := false
		for e: Dictionary in enemies:
			if e["state"] != "alive":
				continue
			if bullet_rect.intersects(Rect2(e["x"], GROUND_Y - ENEMY_SIZE.y, ENEMY_SIZE.x, ENEMY_SIZE.y)):
				_remove_enemy(e)
				score += 100
				kills += 1
				_update_hud()
				hit = true
				break
		if hit:
			b["view"].queue_free()
			bullets.remove_at(i)


func _update_enemy_bullets(delta: float) -> void:
	var player_rect := Rect2(player_x, GROUND_Y - PLAYER_SIZE.y, PLAYER_SIZE.x, PLAYER_SIZE.y)
	for i in range(enemy_bullets.size() - 1, -1, -1):
		var b: Dictionary = enemy_bullets[i]
		b["pos"] += b["vel"] * delta
		b["view"].position = b["pos"]
		if b["pos"].x < 0.0 or b["pos"].x > PLAY_W:
			b["view"].queue_free()
			enemy_bullets.remove_at(i)
			continue

		if Rect2(b["pos"], Vector2(10, 8)).intersects(player_rect):
			b["view"].queue_free()
			enemy_bullets.remove_at(i)
			_lose_life()


func _remove_enemy(e: Dictionary) -> void:
	e["state"] = "removed"
	e["view"].visible = false


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
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)
