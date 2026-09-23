extends Control
## Asteroids: nave con inercia (sin fricción dura, como el original)
## controlada por botones táctiles, dispara y destruye asteroides que
## se dividen en fragmentos más chicos. Envoltura de pantalla (sale
## por un lado, aparece por el otro). 10 niveles con más asteroides
## y más velocidad cada vez.

const GAME_ID := "asteroids"
const PLAY_W := 640.0
const PLAY_H := 880.0
const SHIP_RADIUS := 13.0
const ROT_SPEED := 3.4
const THRUST := 260.0
const FRICTION_PER_SEC := 0.55 # que tan rapido frena al soltar el empuje (0=nada, 1=frena de golpe)
const BULLET_SPEED := 460.0
const BULLET_LIFETIME := 1.0
const FIRE_COOLDOWN := 0.28
const MAX_LEVEL := 10
const BASE_ASTEROID_SPEED := 45.0
const SPEED_PER_LEVEL := 6.0

const TIER_RADIUS := [38.0, 22.0, 12.0]
const TIER_POINTS := [20, 50, 100]

const HELP_TEXT := "Controla tu nave con los botones de abajo:

- ◀ / ▶ giran la nave.
- 🚀 acelera en la dirección a la que apuntas (la nave tiene inercia, sigue moviéndose aunque sueltes el botón).
- 🔥 dispara.

Si sales por un borde de la pantalla, apareces por el lado opuesto. Destruye los asteroides grandes: se dividen en 2 más chicos (y esos en 2 más chicos todavía) hasta desaparecer — entre más chico, más puntos vale.

Chocar con un asteroide te quita una vida. Hay 10 niveles, cada uno con más asteroides y más rápidos. Ganas al limpiar los 10; pierdes si se acaban tus 3 vidas."

var ship_pos: Vector2 = Vector2.ZERO
var ship_vel: Vector2 = Vector2.ZERO
var ship_rot: float = 0.0
var rotating_left: bool = false
var rotating_right: bool = false
var thrusting: bool = false
var fire_cooldown_left: float = 0.0
var invulnerable_time: float = 0.0

var bullets: Array = []
var asteroids: Array = []

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing" # playing | game_over | won

var play_area: Control
var ship_view: Polygon2D
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

	UIKit.build_toolbar(vbox, self, "Asteroids", HELP_TEXT)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 30)
	vbox.add_child(hud)
	score_label = UIKit.title_label("Puntos: 0", 16, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("Vidas: 3", 16, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)

	status_label = UIKit.title_label("Nivel 1", 15, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	ship_view = Polygon2D.new()
	ship_view.polygon = PackedVector2Array([Vector2(0, -16), Vector2(10, 12), Vector2(0, 6), Vector2(-10, 12)])
	ship_view.color = UIKit.COLOR_ACCENT
	play_area.add_child(ship_view)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	vbox.add_child(controls)

	var left_btn := _make_hold_button("◀")
	left_btn.button_down.connect(func() -> void: rotating_left = true)
	left_btn.button_up.connect(func() -> void: rotating_left = false)
	controls.add_child(left_btn)

	var thrust_btn := _make_hold_button("🚀")
	thrust_btn.button_down.connect(func() -> void: thrusting = true)
	thrust_btn.button_up.connect(func() -> void: thrusting = false)
	controls.add_child(thrust_btn)

	var right_btn := _make_hold_button("▶")
	right_btn.button_down.connect(func() -> void: rotating_right = true)
	right_btn.button_up.connect(func() -> void: rotating_right = false)
	controls.add_child(right_btn)

	var fire_btn := _make_hold_button("🔥")
	fire_btn.pressed.connect(_on_fire_pressed)
	controls.add_child(fire_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_hold_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(80, 72)
	btn.add_theme_font_size_override("font_size", 26)
	UIKit.style_button(btn, UIKit.COLOR_ACCENT_2)
	return btn


func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	state = "playing"
	for b: Dictionary in bullets:
		b["view"].queue_free()
	bullets.clear()
	_reset_ship()
	_update_hud()
	_spawn_level()


func _reset_ship() -> void:
	ship_pos = Vector2(PLAY_W / 2.0, PLAY_H / 2.0)
	ship_vel = Vector2.ZERO
	ship_rot = 0.0
	invulnerable_time = 2.0


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "Vidas: %d" % lives


func _spawn_level() -> void:
	for a: Dictionary in asteroids:
		a["view"].queue_free()
	asteroids.clear()

	var count: int = min(2 + level, 9)
	var speed: float = BASE_ASTEROID_SPEED + SPEED_PER_LEVEL * (level - 1)
	for i in range(count):
		var edge_pos: Vector2 = _random_edge_position()
		var dir: Vector2 = (Vector2(PLAY_W / 2.0, PLAY_H / 2.0) - edge_pos).normalized().rotated(randf_range(-0.6, 0.6))
		_spawn_asteroid(edge_pos, dir * speed, 0)

	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]


func _random_edge_position() -> Vector2:
	var side: int = randi() % 4
	match side:
		0: return Vector2(randf() * PLAY_W, 0)
		1: return Vector2(randf() * PLAY_W, PLAY_H)
		2: return Vector2(0, randf() * PLAY_H)
		_: return Vector2(PLAY_W, randf() * PLAY_H)


func _spawn_asteroid(pos: Vector2, vel: Vector2, tier: int) -> void:
	var radius: float = TIER_RADIUS[tier]
	var view := GamePiece.new()
	view.size = Vector2(radius * 2.0, radius * 2.0)
	view.position = pos - Vector2(radius, radius)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Color = UIKit.COLOR_TEXT_DIM if tier == 0 else (UIKit.COLOR_ACCENT_2 if tier == 1 else UIKit.COLOR_ACCENT_3)
	view.set_piece(color)
	play_area.add_child(view)
	asteroids.append({"pos": pos, "vel": vel, "tier": tier, "radius": radius, "view": view})


func _on_fire_pressed() -> void:
	if state != "playing" or fire_cooldown_left > 0.0:
		return
	fire_cooldown_left = FIRE_COOLDOWN
	var dir := Vector2(sin(ship_rot), -cos(ship_rot))
	var bullet_pos: Vector2 = ship_pos + dir * SHIP_RADIUS
	var view := GamePiece.new()
	view.size = Vector2(8, 8)
	view.position = bullet_pos - Vector2(4, 4)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_piece(UIKit.COLOR_ACCENT_3)
	play_area.add_child(view)
	bullets.append({"pos": bullet_pos, "vel": dir * BULLET_SPEED + ship_vel, "life": BULLET_LIFETIME, "view": view})


func _wrap_pos(pos: Vector2) -> Vector2:
	var p: Vector2 = pos
	if p.x < 0.0:
		p.x += PLAY_W
	elif p.x > PLAY_W:
		p.x -= PLAY_W
	if p.y < 0.0:
		p.y += PLAY_H
	elif p.y > PLAY_H:
		p.y -= PLAY_H
	return p


func _process(delta: float) -> void:
	if state != "playing":
		return

	if invulnerable_time > 0.0:
		invulnerable_time -= delta
	if fire_cooldown_left > 0.0:
		fire_cooldown_left -= delta

	if rotating_left:
		ship_rot -= ROT_SPEED * delta
	if rotating_right:
		ship_rot += ROT_SPEED * delta

	var dir := Vector2(sin(ship_rot), -cos(ship_rot))
	if thrusting:
		ship_vel += dir * THRUST * delta
	ship_vel *= pow(1.0 - FRICTION_PER_SEC, delta)
	ship_pos = _wrap_pos(ship_pos + ship_vel * delta)

	ship_view.position = ship_pos
	ship_view.rotation = ship_rot
	ship_view.visible = invulnerable_time <= 0.0 or int(invulnerable_time * 8.0) % 2 == 0

	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["pos"] += b["vel"] * delta
		b["life"] -= delta
		if b["life"] <= 0.0 or b["pos"].x < 0.0 or b["pos"].x > PLAY_W or b["pos"].y < 0.0 or b["pos"].y > PLAY_H:
			b["view"].queue_free()
			bullets.remove_at(i)
			continue
		b["view"].position = b["pos"] - Vector2(4, 4)

	for a: Dictionary in asteroids:
		a["pos"] = _wrap_pos(a["pos"] + a["vel"] * delta)
		a["view"].position = a["pos"] - Vector2(a["radius"], a["radius"])

	_check_bullet_hits()
	_check_ship_collision()

	if asteroids.is_empty() and state == "playing":
		_advance_level()


func _check_bullet_hits() -> void:
	for i in range(bullets.size() - 1, -1, -1):
		if i >= bullets.size():
			continue
		var b: Dictionary = bullets[i]
		for j in range(asteroids.size() - 1, -1, -1):
			var a: Dictionary = asteroids[j]
			if b["pos"].distance_to(a["pos"]) <= a["radius"] + 4.0:
				score += TIER_POINTS[a["tier"]]
				_update_hud()
				_break_asteroid(a, j)
				b["view"].queue_free()
				bullets.remove_at(i)
				break


func _break_asteroid(a: Dictionary, index: int) -> void:
	a["view"].queue_free()
	asteroids.remove_at(index)

	if a["tier"] < 2:
		var speed: float = a["vel"].length() * 1.3 + 20.0
		for k in range(2):
			var new_dir: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			_spawn_asteroid(a["pos"], new_dir * speed, a["tier"] + 1)


func _check_ship_collision() -> void:
	if invulnerable_time > 0.0:
		return
	for a: Dictionary in asteroids:
		if ship_pos.distance_to(a["pos"]) <= a["radius"] + SHIP_RADIUS:
			_lose_life()
			return


func _lose_life() -> void:
	lives -= 1
	_update_hud()
	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over. Puntos: %d" % score
		_record_result(false)
		return
	_reset_ship()


func _advance_level() -> void:
	if level >= MAX_LEVEL:
		_win()
		return
	level += 1
	invulnerable_time = 1.5
	_spawn_level()


func _win() -> void:
	state = "won"
	status_label.text = "¡Completaste los %d niveles! Puntos: %d" % [MAX_LEVEL, score]
	_record_result(true)


func _record_result(won: bool) -> void:
	AudioManager.play_win() if won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)
