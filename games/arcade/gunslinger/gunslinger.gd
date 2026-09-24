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

const PLAYER_BODY_COLOR := Color(0.27, 0.38, 0.52)    # camisa vaquera azul denim
const PLAYER_HAT_COLOR := Color(0.80, 0.63, 0.36)     # sombrero tostado
const BANDIT_MELEE_COLOR := Color(0.52, 0.17, 0.15)   # forajido cuerpo a cuerpo, rojo polvoriento
const BANDIT_RANGED_COLOR := Color(0.30, 0.40, 0.37)  # forajido a distancia, verde apagado
const BANDIT_COLOR2 := Color(0.16, 0.16, 0.18)
const BOSS_COLOR := Color(0.36, 0.10, 0.42)
const BULLET_COLOR := Color(1.0, 0.86, 0.46)
const HIT_FLASH_DURATION := 0.18

const JUMP_DURATION := 0.55  # mientras salta, esquiva balas rasantes (como en Sunset Riders)
const BOSS_HITS := 6
const WEAPON_DROP_CHANCE := 0.22
const WEAPON_DURATION := 10.0
const SHOTGUN_COOLDOWN := 0.34
const SHOTGUN_SPREAD_DEG := 14.0

const HELP_TEXT := "Muévete con ◀ ▶ (también apuntas hacia donde te mueves) y dispara con 🔫. Usa ⤴ para saltar y esquivar disparos rasantes.

Los bandidos entran por los lados: los que se acercan directo te quitan una vida si te tocan (dispárales antes). Los que se quedan a distancia disparan hacia ti — muévete o salta para esquivar sus balas.

Algunos bandidos sueltan una escopeta al caer: dispara 3 balas en abanico por tiempo limitado.

Al llegar a la cuota de bandidos, aparece el jefe del nivel — aguanta varios disparos y alterna entre embestidas y ráfagas. Derrótalo para pasar al siguiente nivel. Hay 10 niveles, cada uno con más bandidos, más rápidos y jefes más resistentes. Pierdes si se acaban tus 3 vidas."

var player_x: float = 0.0
var facing: int = 1
var moving_left: bool = false
var moving_right: bool = false
var shoot_cooldown: float = 0.0
var player_phase: float = 0.0

var enemies: Array = []
var bullets: Array = []
var enemy_bullets: Array = []
var weapon_drops: Array = []

var kills: int = 0
var kills_needed: int = 8
var spawn_timer: float = 0.0
var spawn_interval: float = 1.2
var enemy_speed: float = 70.0
var ranged_chance: float = 0.2
var boss_spawned: bool = false
var boss: Dictionary = {}

var jump_timer: float = 0.0
var weapon: String = "pistol"  # "pistol" | "shotgun"
var weapon_timer: float = 0.0

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var player_view: EntitySprite
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

	var hud_panel := PanelContainer.new()
	hud_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 10, 2))
	vbox.add_child(hud_panel)

	var hud_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		hud_margin.add_theme_constant_override(side, 10)
	hud_panel.add_child(hud_margin)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 16)
	hud_margin.add_child(hud)
	score_label = UIKit.title_label("🤠 0", 15, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("❤ 3", 15, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)
	status_label = UIKit.title_label("Nivel 1/10", 13, UIKit.COLOR_TEXT_DIM)
	hud.add_child(status_label)
	progress_label = UIKit.title_label("", 13, UIKit.COLOR_ACCENT_2)
	hud.add_child(progress_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0.08, 0.06, 0.10), UIKit.COLOR_ACCENT_3, 12, 3))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	var backdrop := GunslingerBackdrop.new()
	backdrop.size = Vector2(PLAY_W, GROUND_Y)
	backdrop.position = Vector2.ZERO
	play_area.add_child(backdrop)

	var ground := Panel.new()
	ground.position = Vector2(0, GROUND_Y)
	ground.size = Vector2(PLAY_W, PLAY_H - GROUND_Y)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0.42, 0.29, 0.19), Color(0, 0, 0, 0), 0))
	play_area.add_child(ground)

	var ground_edge := Panel.new()
	ground_edge.position = Vector2(0, GROUND_Y)
	ground_edge.size = Vector2(PLAY_W, 4)
	ground_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground_edge.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0.64, 0.47, 0.29), Color(0, 0, 0, 0), 0))
	play_area.add_child(ground_edge)

	player_view = EntitySprite.new()
	player_view.size = PLAYER_SIZE
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.setup("cowboy", PLAYER_BODY_COLOR, PLAYER_HAT_COLOR)
	play_area.add_child(player_view)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 14)
	vbox.add_child(controls)

	var left_btn := _make_control_button("◀")
	left_btn.button_down.connect(func() -> void: moving_left = true)
	left_btn.button_up.connect(func() -> void: moving_left = false)
	controls.add_child(left_btn)

	var shoot_btn := Button.new()
	shoot_btn.text = "🔫"
	shoot_btn.custom_minimum_size = Vector2(104, 76)
	shoot_btn.add_theme_font_size_override("font_size", 28)
	UIKit.style_button(shoot_btn, UIKit.COLOR_DANGER)
	shoot_btn.pressed.connect(_on_shoot_pressed)
	controls.add_child(shoot_btn)

	var right_btn := _make_control_button("▶")
	right_btn.button_down.connect(func() -> void: moving_right = true)
	right_btn.button_up.connect(func() -> void: moving_right = false)
	controls.add_child(right_btn)

	var jump_btn := Button.new()
	jump_btn.text = "⤴"
	jump_btn.custom_minimum_size = Vector2(80, 68)
	jump_btn.add_theme_font_size_override("font_size", 24)
	UIKit.style_button(jump_btn, UIKit.COLOR_ACCENT_3)
	jump_btn.pressed.connect(_on_jump_pressed)
	controls.add_child(jump_btn)

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
	for w: Dictionary in weapon_drops:
		w["view"].queue_free()
	weapon_drops.clear()

	kills = 0
	kills_needed = 7 + level
	spawn_timer = 0.0
	spawn_interval = max(0.55, 1.3 - level * 0.07)
	enemy_speed = 65.0 + level * 6.0
	ranged_chance = min(0.15 + level * 0.045, 0.6)
	boss_spawned = false
	boss = {}
	jump_timer = 0.0
	weapon = "pistol"
	weapon_timer = 0.0

	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_update_hud()


func _update_hud() -> void:
	score_label.text = "🤠 %d" % score
	lives_label.text = "❤ %d" % lives
	progress_label.text = "🎯 %d / %d" % [kills, kills_needed]


func _on_shoot_pressed() -> void:
	var cooldown: float = SHOTGUN_COOLDOWN if weapon == "shotgun" else SHOOT_COOLDOWN
	if state != "playing" or shoot_cooldown > 0.0:
		return
	shoot_cooldown = cooldown
	var pos := Vector2(player_x + (PLAYER_SIZE.x if facing > 0 else 0.0), GROUND_Y - PLAYER_SIZE.y / 2.0 - 6.0)
	if weapon == "shotgun":
		for vy: float in [-130.0, 0.0, 130.0]:
			_fire_bullet(pos, Vector2(facing * BULLET_SPEED, vy))
	else:
		_fire_bullet(pos, Vector2(facing * BULLET_SPEED, 0))
	UIKit.pulse(player_view)


func _fire_bullet(pos: Vector2, vel: Vector2) -> void:
	var view := EntitySprite.new()
	view.size = Vector2(10, 18)
	view.position = pos
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("bullet", BULLET_COLOR, BULLET_COLOR.lightened(0.5))
	view.set_facing(rad_to_deg(atan2(vel.x, -vel.y)))
	play_area.add_child(view)
	bullets.append({"pos": pos, "vel": vel, "view": view})


func _on_jump_pressed() -> void:
	if state != "playing" or jump_timer > 0.0:
		return
	jump_timer = JUMP_DURATION
	AudioManager.play_click()


func _spawn_enemy() -> void:
	var side: int = 1 if randi() % 2 == 0 else -1
	var x: float = (PLAY_W - ENEMY_SIZE.x) if side == 1 else 0.0
	var kind: String = "ranged" if randf() < ranged_chance else "melee"
	var view := EntitySprite.new()
	view.size = ENEMY_SIZE
	view.position = Vector2(x, GROUND_Y - ENEMY_SIZE.y)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("bandit", BANDIT_RANGED_COLOR if kind == "ranged" else BANDIT_MELEE_COLOR, BANDIT_COLOR2, enemies.size())
	view.set_facing(0.0, side > 0)
	play_area.add_child(view)
	enemies.append({
		"x": x, "kind": kind, "state": "alive",
		"shoot_timer": randf_range(0.6, 1.4), "view": view,
		"phase": randf(), "flash_timer": 0.0,
	})


func _process(delta: float) -> void:
	if state != "playing":
		return

	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta
	if jump_timer > 0.0:
		jump_timer -= delta
	if weapon_timer > 0.0:
		weapon_timer -= delta
		if weapon_timer <= 0.0:
			weapon = "pistol"

	_update_player(delta)

	var alive_count := 0
	for e: Dictionary in enemies:
		if e["state"] == "alive":
			alive_count += 1

	if not boss_spawned and kills >= kills_needed and alive_count == 0:
		boss_spawned = true
		_spawn_boss()
	elif not boss_spawned:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and alive_count < MAX_ON_SCREEN and kills + alive_count < kills_needed:
			spawn_timer = spawn_interval
			_spawn_enemy()

	for e: Dictionary in enemies:
		if e["state"] == "alive":
			_update_enemy(e, delta)
	_update_boss(delta)

	_update_bullets(delta)
	_update_enemy_bullets(delta)
	_update_weapon_drops(delta)

	if state == "playing" and boss_spawned and boss.is_empty():
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
	# Arco de salto puramente visual (parábola sobre JUMP_DURATION): la
	# esquiva real ya se resuelve por jump_timer en _update_enemy_bullets.
	var hop: float = 0.0
	if jump_timer > 0.0:
		var jt: float = 1.0 - (jump_timer / JUMP_DURATION)
		hop = sin(jt * PI) * 34.0
	player_view.position = Vector2(player_x, GROUND_Y - PLAYER_SIZE.y - hop)
	player_view.set_facing(0.0, facing < 0)
	var bob_speed: float = 2.4 if (moving_left or moving_right) else 0.7
	player_phase = fmod(player_phase + delta * bob_speed, 1.0)
	player_view.set_phase(player_phase)


func _update_enemy(e: Dictionary, delta: float) -> void:
	var player_center: float = player_x + PLAYER_SIZE.x / 2.0
	var enemy_center: float = e["x"] + ENEMY_SIZE.x / 2.0
	var dx: float = player_center - enemy_center
	var dir: float = sign(dx) if abs(dx) > 4.0 else 0.0

	if dir != 0.0:
		e["view"].set_facing(0.0, dir < 0.0)

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

	# El "phase" de la vista controla el bob de espera y, para los que
	# disparan, el destello del cañón justo cuando se dispara la bala.
	if e["flash_timer"] > 0.0:
		e["flash_timer"] -= delta
		e["view"].set_phase(0.6)
	else:
		var cycle: float = 1.0 if e["kind"] == "ranged" else 0.5
		e["phase"] = fmod(e["phase"] + delta * 0.55, cycle)
		e["view"].set_phase(e["phase"])

	e["view"].position = Vector2(e["x"], GROUND_Y - ENEMY_SIZE.y)


func _spawn_enemy_bullet(e: Dictionary) -> void:
	var player_center: float = player_x + PLAYER_SIZE.x / 2.0
	var enemy_center: float = e["x"] + ENEMY_SIZE.x / 2.0
	var dir: float = sign(player_center - enemy_center)
	if dir == 0.0:
		dir = 1.0
	e["flash_timer"] = HIT_FLASH_DURATION
	var pos := Vector2(enemy_center, GROUND_Y - ENEMY_SIZE.y / 2.0)
	var view := EntitySprite.new()
	view.size = Vector2(9, 16)
	view.position = pos
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("bullet", UIKit.COLOR_DANGER, UIKit.COLOR_DANGER.lightened(0.45))
	view.set_facing(90.0 if dir > 0 else -90.0)
	play_area.add_child(view)
	enemy_bullets.append({"pos": pos, "vel": Vector2(dir * ENEMY_BULLET_SPEED, 0), "view": view})


func _spawn_boss() -> void:
	var side: int = 1 if randi() % 2 == 0 else -1
	var sz: Vector2 = ENEMY_SIZE * 1.4
	var x: float = (PLAY_W - sz.x) if side == 1 else 0.0
	var view := EntitySprite.new()
	view.size = sz
	view.position = Vector2(x, GROUND_Y - sz.y)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("bandit", BOSS_COLOR, BANDIT_COLOR2, 999)
	view.set_facing(0.0, side > 0)
	play_area.add_child(view)
	boss = {
		"x": x, "size": sz, "state": "alive", "hp": BOSS_HITS + level / 2, "mode": "ranged",
		"charge_timer": randf_range(2.2, 3.6), "shoot_timer": randf_range(0.8, 1.4),
		"view": view, "phase": randf(), "flash_timer": 0.0,
	}


func _update_boss(delta: float) -> void:
	if boss.is_empty():
		return
	var player_center: float = player_x + PLAYER_SIZE.x / 2.0
	var boss_center: float = boss["x"] + boss["size"].x / 2.0
	var dx: float = player_center - boss_center
	var dir: float = sign(dx) if abs(dx) > 4.0 else 0.0
	if dir != 0.0:
		boss["view"].set_facing(0.0, dir < 0.0)

	boss["charge_timer"] -= delta
	if boss["mode"] == "ranged" and boss["charge_timer"] <= 0.0:
		boss["mode"] = "charge"
		boss["charge_timer"] = 0.9
	elif boss["mode"] == "charge":
		boss["x"] += dir * enemy_speed * 2.2 * delta
		if abs(dx) < MELEE_RANGE * 1.3:
			_lose_life()
			boss["mode"] = "ranged"
			boss["charge_timer"] = randf_range(2.2, 3.6)
		elif boss["charge_timer"] <= 0.0:
			boss["mode"] = "ranged"
			boss["charge_timer"] = randf_range(2.2, 3.6)

	if boss["mode"] == "ranged":
		if abs(dx) > RANGED_STOP_DIST * 0.8:
			boss["x"] += dir * enemy_speed * delta
		boss["shoot_timer"] -= delta
		if boss["shoot_timer"] <= 0.0:
			boss["shoot_timer"] = randf_range(0.5, 0.9)
			_spawn_boss_bullet()

	boss["x"] = clamp(boss["x"], 0.0, PLAY_W - boss["size"].x)
	if boss["flash_timer"] > 0.0:
		boss["flash_timer"] -= delta
		boss["view"].set_phase(0.6)
	else:
		boss["phase"] = fmod(float(boss["phase"]) + delta * 0.6, 1.0)
		boss["view"].set_phase(boss["phase"])
	boss["view"].position = Vector2(boss["x"], GROUND_Y - boss["size"].y)


func _spawn_boss_bullet() -> void:
	var player_center: float = player_x + PLAYER_SIZE.x / 2.0
	var boss_center: float = boss["x"] + boss["size"].x / 2.0
	var dir: float = sign(player_center - boss_center)
	if dir == 0.0:
		dir = 1.0
	boss["flash_timer"] = HIT_FLASH_DURATION
	var pos := Vector2(boss_center, GROUND_Y - boss["size"].y / 2.0)
	var view := EntitySprite.new()
	view.size = Vector2(10, 18)
	view.position = pos
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("bullet", BOSS_COLOR.lightened(0.3), Color(1, 1, 1))
	view.set_facing(90.0 if dir > 0 else -90.0)
	play_area.add_child(view)
	enemy_bullets.append({"pos": pos, "vel": Vector2(dir * ENEMY_BULLET_SPEED * 1.1, 0), "view": view})


func _spawn_weapon_drop(pos: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_ACCENT_2.darkened(0.5), UIKit.COLOR_ACCENT_2, 8, 2))
	panel.size = Vector2(30, 30)
	panel.position = pos - panel.size / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = "🔫"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	panel.add_child(lbl)
	play_area.add_child(panel)
	weapon_drops.append({"pos": panel.position, "size": panel.size, "view": panel, "life": WEAPON_DURATION})


func _update_weapon_drops(delta: float) -> void:
	var player_rect := Rect2(player_x, GROUND_Y - PLAYER_SIZE.y, PLAYER_SIZE.x, PLAYER_SIZE.y)
	for i in range(weapon_drops.size() - 1, -1, -1):
		var w: Dictionary = weapon_drops[i]
		w["life"] -= delta
		if w["life"] <= 0.0 or Rect2(w["pos"], w["size"]).intersects(player_rect):
			if w["life"] > 0.0:
				weapon = "shotgun"
				weapon_timer = WEAPON_DURATION
				AudioManager.play_place()
			w["view"].queue_free()
			weapon_drops.remove_at(i)


func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["pos"] += b["vel"] * delta
		b["view"].position = b["pos"]
		if b["pos"].x < 0.0 or b["pos"].x > PLAY_W or b["pos"].y < -40.0 or b["pos"].y > PLAY_H:
			b["view"].queue_free()
			bullets.remove_at(i)
			continue

		var bullet_rect := Rect2(b["pos"], Vector2(12, 8))
		var hit := false
		for e: Dictionary in enemies:
			if e["state"] != "alive":
				continue
			if bullet_rect.intersects(Rect2(e["x"], GROUND_Y - ENEMY_SIZE.y, ENEMY_SIZE.x, ENEMY_SIZE.y)):
				_spawn_hit_flash(Vector2(e["x"] + ENEMY_SIZE.x / 2.0, GROUND_Y - ENEMY_SIZE.y / 2.0))
				_remove_enemy(e)
				score += 100
				kills += 1
				_update_hud()
				if randf() < WEAPON_DROP_CHANCE:
					_spawn_weapon_drop(Vector2(e["x"] + ENEMY_SIZE.x / 2.0, GROUND_Y))
				hit = true
				break
		if not hit and not boss.is_empty() and boss["state"] == "alive":
			if bullet_rect.intersects(Rect2(boss["x"], GROUND_Y - boss["size"].y, boss["size"].x, boss["size"].y)):
				_spawn_hit_flash(Vector2(boss["x"] + boss["size"].x / 2.0, GROUND_Y - boss["size"].y / 2.0))
				boss["hp"] -= 1
				boss["flash_timer"] = HIT_FLASH_DURATION
				score += 20
				if boss["hp"] <= 0:
					score += 500
					boss["view"].queue_free()
					boss = {}
				_update_hud()
				hit = true
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

		if jump_timer <= 0.0 and Rect2(b["pos"], Vector2(10, 8)).intersects(player_rect):
			b["view"].queue_free()
			enemy_bullets.remove_at(i)
			_lose_life()


func _spawn_hit_flash(center: Vector2) -> void:
	## Destello breve al derribar a un bandido: refuerza el "impacto" del
	## disparo sin depender de _process (una sola animación con tween).
	var flash := EntitySprite.new()
	var fsize: Vector2 = ENEMY_SIZE * 1.4
	flash.size = fsize
	flash.position = center - fsize / 2.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.setup("blast", UIKit.COLOR_ACCENT_3, Color(1, 1, 1))
	play_area.add_child(flash)
	var tw := create_tween()
	tw.tween_method(flash.set_phase, 0.0, 1.0, 0.28)
	tw.tween_callback(flash.queue_free)


func _remove_enemy(e: Dictionary) -> void:
	e["state"] = "removed"
	e["view"].visible = false


func _lose_life() -> void:
	lives -= 1
	_update_hud()
	UIKit.pulse(player_view)
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
