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
# Tamaños visuales (EntitySprite): más redondeados/grandes que la caja de
# colisión de arriba. El sprite se ancla por los "pies" al fondo de la caja
# de colisión para que el salto/aterrizaje no cambien de sensación.
const PLAYER_VIEW_SIZE := Vector2(46, 46)
const ENEMY_VIEW_SIZE := Vector2(40, 40)
const PROJECTILE_VIEW_SIZE := Vector2(16, 16)
const SNOW_SPEED := 480.0
const SNOW_COOLDOWN := 0.35
const FREEZE_HITS := 3
const SNOWBALL_SPEED := 320.0
const SNOWBALL_MAX_DIST := 460.0
const MAX_LEVEL := 10
const FREEZE_DURATION := 6.0  # si no pateas al enemigo a tiempo, se descongela
const ITEM_DROP_CHANCE := 0.4
const ITEM_LIFETIME := 8.0
const ITEM_VIEW_SIZE := Vector2(26, 26)
const MAX_POWER_LEVEL := 2
const ITEM_WEIGHTS := {"fruit": 62, "power_snow": 30, "extra_life": 8}
const ITEM_ICON := {"fruit": "🍒", "power_snow": "❄", "extra_life": "❤"}
const ITEM_COLOR := {"fruit": UIKit.COLOR_DANGER, "power_snow": UIKit.COLOR_ACCENT_2, "extra_life": UIKit.COLOR_ACCENT}

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

const HELP_TEXT := "Salta entre plataformas con ◀ ▶ y ⬆. Dispara ❄ para congelar enemigos (necesitan varios golpes; se ponen azules cuando están congelados).

Camina hacia un enemigo congelado para empujarlo: se convierte en una bola de nieve que rueda y destruye en cadena a cualquier otro enemigo que toque. ¡Si no lo pateas a tiempo, se descongela solo!

Al destruir enemigos con la bola de nieve, a veces sueltan un ítem: 🍒 puntos extra, ❄ mejora tu nieve (menos golpes para congelar), ❤ vida extra. Recógelos antes de que desaparezcan.

Tocar a un enemigo que camina (no congelado) te quita una vida. Limpia todos los enemigos del nivel para avanzar. Hay 10 niveles, cada uno con más enemigos. Pierdes si se acaban tus 3 vidas."

var player_pos: Vector2 = Vector2.ZERO
var player_vel: Vector2 = Vector2.ZERO
var on_ground: bool = false
var facing: int = 1
var moving_left: bool = false
var moving_right: bool = false
var shoot_cooldown: float = 0.0
var player_phase: float = 0.0

var enemies: Array = []
var projectiles: Array = []
var items: Array = []
var power_level: int = 0

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

	UIKit.build_toolbar(vbox, self, "Guerra de Nieve", HELP_TEXT)

	# Barra de estado delgada: puntos + vidas en una sola línea con panel.
	var stat_panel := PanelContainer.new()
	stat_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 10, 1))
	vbox.add_child(stat_panel)

	var stat_margin := MarginContainer.new()
	stat_margin.add_theme_constant_override("margin_left", 16)
	stat_margin.add_theme_constant_override("margin_right", 16)
	stat_margin.add_theme_constant_override("margin_top", 5)
	stat_margin.add_theme_constant_override("margin_bottom", 5)
	stat_panel.add_child(stat_margin)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 26)
	stat_margin.add_child(hud)
	score_label = UIKit.title_label("Puntos: 0", 14, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("❤ 3", 14, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)

	status_label = UIKit.title_label("Nivel 1", 13, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	# Cielo nevado de fondo: degradado sutil para que la escena no se sienta
	# vacía detrás de las plataformas, sin tocar la física ni el layout.
	var sky := ColorRect.new()
	sky.color = UIKit.COLOR_BG.lightened(0.04)
	sky.size = Vector2(PLAY_W, PLAY_H)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_area.add_child(sky)
	play_area.move_child(sky, 0)

	for p: Rect2 in PLATFORMS:
		var plat_view := Panel.new()
		plat_view.position = p.position
		plat_view.size = p.size
		plat_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plat_view.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_ACCENT_2, Color(0, 0, 0, 0), 4))
		play_area.add_child(plat_view)

	player_view = EntitySprite.new()
	player_view.size = PLAYER_VIEW_SIZE
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.setup("snow_player", UIKit.COLOR_ACCENT_3, UIKit.COLOR_ACCENT)
	play_area.add_child(player_view)

	# Controles agrupados como un juego móvil real: cruz de movimiento a la
	# izquierda (salto arriba, izquierda/derecha abajo) y botón de acción
	# (bola de nieve) grande a la derecha.
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 30)
	vbox.add_child(controls)

	var move_cluster := VBoxContainer.new()
	move_cluster.alignment = BoxContainer.ALIGNMENT_CENTER
	move_cluster.add_theme_constant_override("separation", 8)
	controls.add_child(move_cluster)

	var jump_row := HBoxContainer.new()
	jump_row.alignment = BoxContainer.ALIGNMENT_CENTER
	move_cluster.add_child(jump_row)
	var jump_btn := _make_control_button("⬆", Vector2(84, 60), UIKit.COLOR_ACCENT_2)
	jump_btn.pressed.connect(_on_jump_pressed)
	jump_row.add_child(jump_btn)

	var move_row := HBoxContainer.new()
	move_row.alignment = BoxContainer.ALIGNMENT_CENTER
	move_row.add_theme_constant_override("separation", 10)
	move_cluster.add_child(move_row)

	var left_btn := _make_control_button("◀", Vector2(80, 72), UIKit.COLOR_ACCENT_2)
	left_btn.button_down.connect(func() -> void: moving_left = true)
	left_btn.button_up.connect(func() -> void: moving_left = false)
	move_row.add_child(left_btn)

	var right_btn := _make_control_button("▶", Vector2(80, 72), UIKit.COLOR_ACCENT_2)
	right_btn.button_down.connect(func() -> void: moving_right = true)
	right_btn.button_up.connect(func() -> void: moving_right = false)
	move_row.add_child(right_btn)

	var shoot_btn := _make_control_button("❄", Vector2(96, 96), UIKit.COLOR_ACCENT)
	shoot_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shoot_btn.pressed.connect(_on_shoot_pressed)
	controls.add_child(shoot_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_control_button(label: String, min_size: Vector2 = Vector2(76, 68), accent: Color = UIKit.COLOR_ACCENT_2) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", 26)
	UIKit.style_button(btn, accent)
	return btn


func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	power_level = 0
	state = "playing"
	_setup_level()


func _setup_level() -> void:
	facing = 1
	_respawn_player()

	for p: Dictionary in projectiles:
		p["view"].queue_free()
	projectiles.clear()

	for it: Dictionary in items:
		it["view"].queue_free()
	items.clear()

	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()

	var count: int = min(2 + level, 10)
	var speed: float = 60.0 + level * 6.0
	for i in range(count):
		var plat: Rect2 = PLATFORMS[1 + (randi() % (PLATFORMS.size() - 1))]
		var pos := Vector2(plat.position.x + randf() * max(1.0, plat.size.x - ENEMY_SIZE.x), plat.position.y - ENEMY_SIZE.y)
		var view := EntitySprite.new()
		view.size = ENEMY_VIEW_SIZE
		view.position = _enemy_view_pos(pos)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.setup("snow_enemy", UIKit.COLOR_DANGER)
		play_area.add_child(view)
		enemies.append({
			"pos": pos, "platform": plat, "dir": (1 if randi() % 2 == 0 else -1),
			"speed": speed, "state": "walking", "hits": 0, "vel": Vector2.ZERO,
			"start_x": 0.0, "view": view, "phase": fmod(float(i) * 0.31, 1.0),
		})

	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_update_hud()


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "❤ %d" % lives


func _sync_player_view() -> void:
	# Ancla el sprite (más grande/redondo que la caja de colisión) por los
	# pies al fondo de PLAYER_SIZE, para que el salto/aterrizaje no cambien.
	player_view.position = Vector2(
		player_pos.x + PLAYER_SIZE.x / 2.0 - PLAYER_VIEW_SIZE.x / 2.0,
		player_pos.y + PLAYER_SIZE.y - PLAYER_VIEW_SIZE.y
	)
	player_view.set_facing(0.0, facing < 0)
	player_view.set_phase(player_phase)


func _enemy_view_pos(pos: Vector2) -> Vector2:
	return Vector2(
		pos.x + ENEMY_SIZE.x / 2.0 - ENEMY_VIEW_SIZE.x / 2.0,
		pos.y + ENEMY_SIZE.y - ENEMY_VIEW_SIZE.y
	)


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
	var view := EntitySprite.new()
	view.size = PROJECTILE_VIEW_SIZE
	view.position = pos - Vector2(2.0, 2.0)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("snowball", Color.WHITE)
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
	_update_items(delta)

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

	if player_vel.x != 0.0:
		player_phase = fmod(player_phase + delta * 2.6, 1.0)

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

	_sync_player_view()

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
	e["view"].setup("snowball", Color.WHITE)


func _update_enemies(delta: float) -> void:
	for e: Dictionary in enemies:
		match e["state"]:
			"walking":
				_update_walking_enemy(e, delta)
			"rolling":
				_update_rolling_enemy(e, delta)
			"frozen":
				e["frozen_timer"] -= delta
				if e["frozen_timer"] <= 0.0:
					_thaw_enemy(e)


func _thaw_enemy(e: Dictionary) -> void:
	## Si no lo pateas a tiempo, el enemigo congelado se descongela solo y
	## vuelve a caminar (y a ser peligroso), como en el Snow Bros original.
	e["state"] = "walking"
	e["hits"] = 0
	e["view"].setup("snow_enemy", UIKit.COLOR_DANGER)


func _effective_freeze_hits() -> int:
	return max(1, FREEZE_HITS - power_level)


func _update_walking_enemy(e: Dictionary, delta: float) -> void:
	var plat: Rect2 = e["platform"]
	e["pos"].x += e["dir"] * e["speed"] * delta
	if e["pos"].x < plat.position.x:
		e["pos"].x = plat.position.x
		e["dir"] = 1
	elif e["pos"].x + ENEMY_SIZE.x > plat.position.x + plat.size.x:
		e["pos"].x = plat.position.x + plat.size.x - ENEMY_SIZE.x
		e["dir"] = -1
	e["phase"] = fmod(float(e["phase"]) + delta * 3.0, 1.0)
	e["view"].position = _enemy_view_pos(e["pos"])
	e["view"].set_facing(0.0, e["dir"] < 0)
	e["view"].set_phase(e["phase"])


func _update_rolling_enemy(e: Dictionary, delta: float) -> void:
	e["pos"].x += e["vel"].x * delta
	e["view"].position = _enemy_view_pos(e["pos"])

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
			if randf() < ITEM_DROP_CHANCE:
				_spawn_item(other["pos"] + ENEMY_SIZE / 2.0)


func _remove_enemy(e: Dictionary) -> void:
	e["state"] = "removed"
	e["view"].visible = false


func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p["pos"] += p["vel"] * delta
		p["view"].position = p["pos"] - Vector2(2.0, 2.0)

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
				if e["hits"] >= _effective_freeze_hits():
					e["state"] = "frozen"
					e["frozen_timer"] = FREEZE_DURATION
					e["view"].setup("snow_enemy", UIKit.COLOR_ACCENT_2)
				hit = true
				break
		if hit:
			p["view"].queue_free()
			projectiles.remove_at(i)


func _roll_item_kind() -> String:
	var total := 0
	for w: int in ITEM_WEIGHTS.values():
		total += w
	var r: int = randi() % total
	var acc := 0
	for kind: String in ITEM_WEIGHTS.keys():
		acc += ITEM_WEIGHTS[kind]
		if r < acc:
			return kind
	return "fruit"


func _spawn_item(center: Vector2) -> void:
	var kind: String = _roll_item_kind()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(ITEM_COLOR[kind].darkened(0.55), ITEM_COLOR[kind], 8, 2))
	panel.size = ITEM_VIEW_SIZE
	panel.position = center - ITEM_VIEW_SIZE / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = ITEM_ICON[kind]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	panel.add_child(lbl)
	play_area.add_child(panel)
	items.append({"pos": panel.position, "kind": kind, "view": panel, "life": ITEM_LIFETIME})


func _update_items(delta: float) -> void:
	var player_rect := Rect2(player_pos, PLAYER_SIZE)
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		it["life"] -= delta
		var fading: bool = it["life"] < 2.0
		it["view"].modulate.a = (0.4 + 0.6 * absf(sin(it["life"] * 10.0))) if fading else 1.0
		if it["life"] <= 0.0 or Rect2(it["pos"], ITEM_VIEW_SIZE).intersects(player_rect):
			if it["life"] > 0.0:
				_apply_item(it["kind"])
			it["view"].queue_free()
			items.remove_at(i)


func _apply_item(kind: String) -> void:
	match kind:
		"fruit":
			score += 50
		"power_snow":
			power_level = min(power_level + 1, MAX_POWER_LEVEL)
		"extra_life":
			lives += 1
	AudioManager.play_place()
	_update_hud()


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
	player_phase = 0.0
	_sync_player_view()


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
