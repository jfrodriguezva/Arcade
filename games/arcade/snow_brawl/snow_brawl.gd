extends Control
## Estilo Snow Bros: saltas entre plataformas, disparas bolas de
## nieve para congelar enemigos (3 golpes) y luego los empujas para
## que rueden y destruyan a los demás. Física real (gravedad +
## colisión con plataformas), consistente con Arkanoid. 10 niveles.

const GAME_ID := "snow_brawl"
const PLAY_W := 640.0
const PLAY_H := 880.0
const GRAVITY := 1400.0
const JUMP_VELOCITY := -620.0
const MOVE_SPEED := 220.0
const PLAYER_SIZE := Vector2(28, 40)
const ENEMY_SIZE := Vector2(26, 32)
const SNOW_SPEED := 480.0
const SNOW_COOLDOWN := 0.35
const FREEZE_HITS := 3
const SNOWBALL_SPEED := 320.0
const SNOWBALL_MAX_DIST := 460.0
const MAX_LEVEL := 10

const PLATFORMS := [
	Rect2(0, 850, 640, 30),
	Rect2(40, 700, 200, 20),
	Rect2(400, 700, 200, 20),
	Rect2(220, 560, 200, 20),
	Rect2(40, 420, 200, 20),
	Rect2(400, 420, 200, 20),
	Rect2(220, 280, 200, 20),
	Rect2(40, 140, 200, 20),
	Rect2(400, 140, 200, 20),
]

const HELP_TEXT := "Salta entre plataformas con ◀ ▶ y ⬆. Dispara ❄ para congelar enemigos (necesitan 3 golpes; se ponen azules cuando están congelados).

Camina hacia un enemigo congelado para empujarlo: se convierte en una bola de nieve que rueda y destruye a cualquier otro enemigo que toque.

Tocar a un enemigo que camina (no congelado) te quita una vida. Limpia todos los enemigos del nivel para avanzar. Hay 10 niveles, cada uno con más enemigos. Pierdes si se acaban tus 3 vidas."

var player_pos: Vector2 = Vector2.ZERO
var player_vel: Vector2 = Vector2.ZERO
var on_ground: bool = false
var facing: int = 1
var moving_left: bool = false
var moving_right: bool = false
var shoot_cooldown: float = 0.0

var enemies: Array = []
var projectiles: Array = []

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var player_view: GamePiece
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
		margin.add_theme_constant_override(side, 20)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Guerra de Nieve", HELP_TEXT)

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

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	for p: Rect2 in PLATFORMS:
		var plat_view := Panel.new()
		plat_view.position = p.position
		plat_view.size = p.size
		plat_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plat_view.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_ACCENT_2, Color(0, 0, 0, 0), 4))
		play_area.add_child(plat_view)

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

	var jump_btn := _make_control_button("⬆")
	jump_btn.pressed.connect(_on_jump_pressed)
	controls.add_child(jump_btn)

	var right_btn := _make_control_button("▶")
	right_btn.button_down.connect(func() -> void: moving_right = true)
	right_btn.button_up.connect(func() -> void: moving_right = false)
	controls.add_child(right_btn)

	var shoot_btn := _make_control_button("❄")
	shoot_btn.pressed.connect(_on_shoot_pressed)
	controls.add_child(shoot_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_control_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(76, 68)
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
	_respawn_player()
	facing = 1

	for p: Dictionary in projectiles:
		p["view"].queue_free()
	projectiles.clear()

	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()

	var count: int = min(2 + level, 10)
	var speed: float = 60.0 + level * 6.0
	for i in range(count):
		var plat: Rect2 = PLATFORMS[1 + (randi() % (PLATFORMS.size() - 1))]
		var pos := Vector2(plat.position.x + randf() * max(1.0, plat.size.x - ENEMY_SIZE.x), plat.position.y - ENEMY_SIZE.y)
		var view := GamePiece.new()
		view.size = ENEMY_SIZE
		view.position = pos
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_piece(UIKit.COLOR_DANGER)
		play_area.add_child(view)
		enemies.append({
			"pos": pos, "platform": plat, "dir": (1 if randi() % 2 == 0 else -1),
			"speed": speed, "state": "walking", "hits": 0, "vel": Vector2.ZERO,
			"start_x": 0.0, "view": view,
		})

	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_update_hud()


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "Vidas: %d" % lives


func _on_jump_pressed() -> void:
	if state != "playing" or not on_ground:
		return
	player_vel.y = JUMP_VELOCITY
	on_ground = false


func _on_shoot_pressed() -> void:
	if state != "playing" or shoot_cooldown > 0.0:
		return
	shoot_cooldown = SNOW_COOLDOWN
	var pos: Vector2 = player_pos + Vector2(PLAYER_SIZE.x / 2.0 - 6.0, PLAYER_SIZE.y / 2.0 - 6.0)
	var view := GamePiece.new()
	view.size = Vector2(12, 12)
	view.position = pos
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_piece(UIKit.COLOR_TEXT)
	play_area.add_child(view)
	projectiles.append({"pos": pos, "vel": Vector2(facing * SNOW_SPEED, 0), "view": view})


func _process(delta: float) -> void:
	if state != "playing":
		return

	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta

	_update_player(delta)
	_update_enemies(delta)
	_update_projectiles(delta)

	if _all_enemies_cleared():
		_advance_level()


func _update_player(delta: float) -> void:
	player_vel.y += GRAVITY * delta
	if moving_left and not moving_right:
		player_vel.x = -MOVE_SPEED
		facing = -1
	elif moving_right and not moving_left:
		player_vel.x = MOVE_SPEED
		facing = 1
	else:
		player_vel.x = 0.0

	var prev_bottom: float = player_pos.y + PLAYER_SIZE.y
	player_pos += player_vel * delta
	player_pos.x = clamp(player_pos.x, 0.0, PLAY_W - PLAYER_SIZE.x)

	on_ground = false
	if player_vel.y >= 0.0:
		var new_bottom: float = player_pos.y + PLAYER_SIZE.y
		for p: Rect2 in PLATFORMS:
			var within_x: bool = player_pos.x + PLAYER_SIZE.x > p.position.x and player_pos.x < p.position.x + p.size.x
			if within_x and prev_bottom <= p.position.y + 6.0 and new_bottom >= p.position.y:
				player_pos.y = p.position.y - PLAYER_SIZE.y
				player_vel.y = 0.0
				on_ground = true
				break

	player_view.position = player_pos

	if player_pos.y > PLAY_H:
		_lose_life()
		return

	var player_rect := Rect2(player_pos, PLAYER_SIZE)
	for e: Dictionary in enemies:
		if e["state"] == "walking" and player_rect.intersects(Rect2(e["pos"], ENEMY_SIZE)):
			_lose_life()
			return
		if e["state"] == "frozen" and player_rect.intersects(Rect2(e["pos"], ENEMY_SIZE)) and player_vel.x != 0.0:
			_kick_snowball(e, sign(player_vel.x))


func _kick_snowball(e: Dictionary, dir: float) -> void:
	e["state"] = "rolling"
	e["vel"] = Vector2(SNOWBALL_SPEED * (1.0 if dir >= 0.0 else -1.0), 0.0)
	e["start_x"] = e["pos"].x
	e["view"].set_piece(UIKit.COLOR_TEXT)


func _update_enemies(delta: float) -> void:
	for e: Dictionary in enemies:
		match e["state"]:
			"walking":
				_update_walking_enemy(e, delta)
			"rolling":
				_update_rolling_enemy(e, delta)


func _update_walking_enemy(e: Dictionary, delta: float) -> void:
	var plat: Rect2 = e["platform"]
	e["pos"].x += e["dir"] * e["speed"] * delta
	if e["pos"].x < plat.position.x:
		e["pos"].x = plat.position.x
		e["dir"] = 1
	elif e["pos"].x + ENEMY_SIZE.x > plat.position.x + plat.size.x:
		e["pos"].x = plat.position.x + plat.size.x - ENEMY_SIZE.x
		e["dir"] = -1
	e["view"].position = e["pos"]


func _update_rolling_enemy(e: Dictionary, delta: float) -> void:
	e["pos"].x += e["vel"].x * delta
	e["view"].position = e["pos"]

	if e["pos"].x < 0.0 or e["pos"].x + ENEMY_SIZE.x > PLAY_W or abs(e["pos"].x - e["start_x"]) > SNOWBALL_MAX_DIST:
		_remove_enemy(e)
		return

	var ball_rect := Rect2(e["pos"], ENEMY_SIZE)
	for other: Dictionary in enemies:
		if other == e or other["state"] == "removed" or other["state"] == "rolling":
			continue
		if ball_rect.intersects(Rect2(other["pos"], ENEMY_SIZE)):
			_remove_enemy(other)
			score += 100
			_update_hud()


func _remove_enemy(e: Dictionary) -> void:
	e["state"] = "removed"
	e["view"].visible = false


func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p["pos"] += p["vel"] * delta
		p["view"].position = p["pos"]

		if p["pos"].x < 0.0 or p["pos"].x > PLAY_W:
			p["view"].queue_free()
			projectiles.remove_at(i)
			continue

		var proj_rect := Rect2(p["pos"], Vector2(12, 12))
		var hit := false
		for e: Dictionary in enemies:
			if e["state"] != "walking":
				continue
			if proj_rect.intersects(Rect2(e["pos"], ENEMY_SIZE)):
				e["hits"] += 1
				if e["hits"] >= FREEZE_HITS:
					e["state"] = "frozen"
					e["view"].set_piece(UIKit.COLOR_ACCENT_2)
				hit = true
				break
		if hit:
			p["view"].queue_free()
			projectiles.remove_at(i)


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
	_respawn_player()


func _respawn_player() -> void:
	player_pos = Vector2(PLAY_W / 2.0 - PLAYER_SIZE.x / 2.0, PLATFORMS[0].position.y - PLAYER_SIZE.y)
	player_vel = Vector2.ZERO
	on_ground = true
	moving_left = false
	moving_right = false
	player_view.position = player_pos


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
