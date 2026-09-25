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
## Fila 0 son los "jefes" (estilo Boss Galaga): valen más y son los únicos
## capaces de capturar la nave con un rayo tractor. El resto vale menos en
## formación pero más al picar (como en el arcade original).
const ROW_POINTS_FORMATION := [150, 80, 80, 50, 50, 50]
const ROW_POINTS_DIVING := [400, 160, 160, 100, 100, 100]

const ENTRY_DURATION := 1.05
const ENTRY_STAGGER := 0.07
const DIVE_DURATION := 1.55
const CAPTURE_CHANCE := 0.3
const CAPTURE_MIN_LEVEL := 2
const CAPTURE_RETURN_DURATION := 0.8
const CAPTURED_TINT := Color(0.55, 0.58, 0.66)

const HELP_TEXT := "Muévete con ◀ ▶ y dispara con 🔫 hacia arriba.

Al iniciar cada nivel, la formación entra volando en curva desde los bordes — espera a que se acomode. Luego se mece de un lado a otro y de vez en cuando una nave pica hacia ti en una curva envolvente, disparando — esquívala o destrúyela (vale más puntos que una que sigue en formación).

Cuidado con los jefes (arriba, con escudo giratorio): a veces, en vez de disparar, capturan tu nave con un rayo tractor y se la llevan a la formación. Sigues jugando con una nave nueva, pero para rescatar la capturada debes destruir justo a ese jefe — al lograrlo, vuelas con dos naves a la vez (doble disparo) el resto del nivel.

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

var player_captured: bool = false
var captured_fighter: Dictionary = {}

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
	restart_btn.text = "🔁  Nueva partida"
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
	player_view.visible = true
	player_captured = false
	if captured_fighter.get("view") != null:
		captured_fighter["view"].queue_free()
	captured_fighter = {}

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

	var idx: int = 0
	for r in range(rows):
		var visual: Dictionary = ROW_VISUALS[r % ROW_VISUALS.size()]
		for c in range(FORMATION_COLS):
			var bx: float = start_x + c * COL_SPACING
			var by: float = FORMATION_TOP + r * ROW_SPACING
			var view := EntitySprite.new()
			view.size = ENEMY_SIZE
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.setup(visual["shape"], visual["color"], visual["color2"], r * FORMATION_COLS + c)
			play_area.add_child(view)

			# Entrada en curva: llegan desde una esquina fuera de pantalla,
			# escalonadas por columna, en vez de aparecer ya formadas.
			var from_side: float = -60.0 if c < FORMATION_COLS / 2.0 else PLAY_W + 60.0
			var entry_from := Vector2(from_side, -70.0 - r * 14.0)
			var entry_ctrl := Vector2(lerp(from_side, bx, 0.35), by - 220.0 - r * 10.0)
			view.position = entry_from

			enemies.append({
				"row": r, "base_x": bx, "base_y": by, "pos": entry_from, "state": "entering",
				"phase": randf() * TAU, "wing_seed": randf(), "has_shot": false, "view": view,
				"entry_from": entry_from, "entry_ctrl": entry_ctrl,
				"entry_t": -float(idx) * ENTRY_STAGGER, "is_boss": r == 0, "carries_capture": false,
			})
			idx += 1

	dive_interval = max(0.5, 1.7 - level * 0.1)
	dive_timer = dive_interval + rows * FORMATION_COLS * ENTRY_STAGGER + ENTRY_DURATION
	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_update_hud()


func _update_hud() -> void:
	score_label.text = "★ %d" % score
	lives_label.text = "♥ %d" % lives


func _on_shoot_pressed() -> void:
	if state != "playing" or shoot_cooldown > 0.0 or player_captured:
		return
	shoot_cooldown = SHOOT_COOLDOWN
	_fire_bullet_from(player_x + PLAYER_SIZE.x / 2.0 - 4.0)
	if not captured_fighter.is_empty() and captured_fighter.get("active", false):
		var cap_view: EntitySprite = captured_fighter["view"]
		_fire_bullet_from(cap_view.position.x + cap_view.size.x / 2.0 - 4.0)


func _fire_bullet_from(bx: float) -> void:
	var pos := Vector2(bx, PLAYER_Y - 10.0)
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

		match e["state"]:
			"entering":
				e["entry_t"] += delta
				if e["entry_t"] < 0.0:
					continue
				var t: float = clamp(e["entry_t"] / ENTRY_DURATION, 0.0, 1.0)
				e["pos"] = _bezier2(e["entry_from"], e["entry_ctrl"], Vector2(e["base_x"], e["base_y"]), t)
				e["view"].position = e["pos"]
				if t >= 1.0:
					e["state"] = "formation"
			"formation":
				e["pos"].x = e["base_x"] + sin(time_acc * SWAY_SPEED + e["phase"]) * SWAY_AMPLITUDE
				e["pos"].y = e["base_y"]
				e["view"].position = e["pos"]
				if e["carries_capture"]:
					_update_captive_visual(e)
			"diving":
				e["dive_t"] += delta / DIVE_DURATION
				var t2: float = clamp(e["dive_t"], 0.0, 1.0)
				e["pos"] = _bezier3(e["dive_from"], e["dive_ctrl1"], e["dive_ctrl2"], e["dive_to"], t2)
				e["view"].position = e["pos"]
				if e["carries_capture"] and not player_captured:
					_update_captive_visual(e)
				if e.get("capture_dive", false) and not e["has_captured"] and not player_captured and t2 >= 0.46:
					_trigger_capture(e)
				elif not e["capture_dive"] and not e["has_shot"] and t2 >= 0.3:
					e["has_shot"] = true
					_spawn_enemy_bullet(e)
				if t2 >= 1.0:
					if e["has_captured"]:
						_start_capture_return(e)
					else:
						_remove_enemy(e, false)
			"returning":
				e["entry_t"] += delta
				var t3: float = clamp(e["entry_t"] / CAPTURE_RETURN_DURATION, 0.0, 1.0)
				e["pos"] = _bezier2(e["entry_from"], e["entry_ctrl"], Vector2(e["base_x"], e["base_y"]), t3)
				e["view"].position = e["pos"]
				_update_captive_visual(e)
				if t3 >= 1.0:
					e["state"] = "formation"
					player_captured = false
					player_view.visible = true

	_update_bullets(delta)
	_update_enemy_bullets(delta)
	_check_dive_collisions()
	_update_dual_fighter()

	if state == "playing" and _all_enemies_cleared():
		_advance_level()


func _update_player(delta: float) -> void:
	if player_captured:
		return
	var vx := 0.0
	if moving_left and not moving_right:
		vx = -PLAYER_SPEED
	elif moving_right and not moving_left:
		vx = PLAYER_SPEED
	player_x = clamp(player_x + vx * delta, 0.0, PLAY_W - PLAYER_SIZE.x)
	player_view.position = Vector2(player_x, PLAYER_Y)


func _start_random_dive() -> void:
	if player_captured:
		return
	var candidates: Array = []
	var boss_candidates: Array = []
	for e: Dictionary in enemies:
		if e["state"] != "formation":
			continue
		candidates.append(e)
		if e["is_boss"] and not e["carries_capture"]:
			boss_candidates.append(e)
	if candidates.is_empty():
		return

	var capture_dive: bool = (
		level >= CAPTURE_MIN_LEVEL and not boss_candidates.is_empty()
		and captured_fighter.is_empty() and randf() < CAPTURE_CHANCE
	)
	var e: Dictionary = boss_candidates[randi() % boss_candidates.size()] if capture_dive \
		else candidates[randi() % candidates.size()]

	e["state"] = "diving"
	e["has_shot"] = false
	e["has_captured"] = false
	e["capture_dive"] = capture_dive
	e["dive_t"] = 0.0

	var start: Vector2 = e["pos"]
	var side: float = 1.0 if start.x < PLAY_W / 2.0 else -1.0
	var target_x: float = player_x + PLAYER_SIZE.x / 2.0
	e["dive_from"] = start
	e["dive_ctrl1"] = start + Vector2(side * 100.0, 110.0)
	e["dive_ctrl2"] = Vector2(lerp(start.x, target_x, 0.55), PLAY_H * 0.62)
	e["dive_to"] = Vector2(target_x, PLAY_H + 50.0)


func _bezier2(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _bezier3(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var ab: Vector2 = a.lerp(b, t)
	var bc: Vector2 = b.lerp(c, t)
	var cd: Vector2 = c.lerp(d, t)
	return ab.lerp(bc, t).lerp(bc.lerp(cd, t), t)


func _trigger_capture(e: Dictionary) -> void:
	## El jefe atrapa la nave con un rayo tractor: se oculta la nave
	## principal y el jugador pierde el control hasta que el jefe la deje
	## en la formación (o hasta que se rescate destruyendo a ese jefe).
	e["has_captured"] = true
	e["carries_capture"] = true
	player_captured = true
	player_view.visible = false
	captured_fighter = {"view": null, "active": false, "owner": e}


func _start_capture_return(e: Dictionary) -> void:
	e["state"] = "returning"
	e["entry_from"] = e["pos"]
	e["entry_ctrl"] = Vector2(lerp(e["pos"].x, e["base_x"], 0.4), min(e["pos"].y, e["base_y"]) - 120.0)
	e["entry_t"] = 0.0

	var cap_view := EntitySprite.new()
	cap_view.size = PLAYER_SIZE * 0.85
	cap_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_view.setup("ship", CAPTURED_TINT, CAPTURED_TINT.lightened(0.3))
	play_area.add_child(cap_view)
	captured_fighter["view"] = cap_view


func _update_captive_visual(e: Dictionary) -> void:
	if not captured_fighter.is_empty() and captured_fighter.get("view") != null and not captured_fighter.get("active", false):
		var v: EntitySprite = captured_fighter["view"]
		v.position = e["pos"] + Vector2(ENEMY_SIZE.x / 2.0 - v.size.x / 2.0, ENEMY_SIZE.y + 4.0)


func _update_dual_fighter() -> void:
	if captured_fighter.is_empty() or not captured_fighter.get("active", false):
		return
	var v: EntitySprite = captured_fighter["view"]
	v.position = Vector2(player_x + PLAYER_SIZE.x + 10.0, PLAYER_Y)
	v.visible = player_view.visible


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
		if not player_captured and Rect2(b["pos"], Vector2(8, 12)).intersects(player_rect):
			b["view"].queue_free()
			enemy_bullets.remove_at(i)
			_lose_life()


func _check_dive_collisions() -> void:
	if player_captured:
		return
	var player_rect := Rect2(player_x, PLAYER_Y, PLAYER_SIZE.x, PLAYER_SIZE.y)
	for e: Dictionary in enemies:
		if e["state"] == "diving" and not e.get("capture_dive", false) \
				and Rect2(e["pos"], ENEMY_SIZE).intersects(player_rect):
			_remove_enemy(e, false)
			_lose_life()
			return


func _remove_enemy(e: Dictionary, by_bullet: bool) -> void:
	if by_bullet:
		var row: int = e.get("row", ROW_VISUALS.size() - 1)
		var was_diving: bool = e["state"] == "diving" or e["state"] == "returning"
		score += ROW_POINTS_DIVING[row] if was_diving else ROW_POINTS_FORMATION[row]
		_update_hud()
		if e.get("carries_capture", false):
			_rescue_captive()
	elif e.get("carries_capture", false):
		# El jefe que llevaba tu nave capturada murió de otra forma (choque
		# contigo, por ejemplo): la nave capturada se pierde, pero limpiamos
		# su sprite fantasma para no dejarlo huérfano ni bloquear futuras
		# capturas el resto del nivel.
		if captured_fighter.get("view") != null:
			captured_fighter["view"].queue_free()
		captured_fighter = {}
	e["state"] = "removed"
	e["view"].visible = false


func _rescue_captive() -> void:
	## Al destruir al jefe que se llevó tu nave, la recuperas: de aquí en
	## adelante vuelas con dos naves (disparo doble), como en el original.
	if captured_fighter.is_empty():
		return
	captured_fighter["active"] = true
	player_captured = false
	player_view.visible = true


func _all_enemies_cleared() -> bool:
	for e: Dictionary in enemies:
		if e["state"] != "removed":
			return false
	return true


func _lose_life() -> void:
	lives -= 1
	_update_hud()
	if not captured_fighter.is_empty():
		# Perder la nave principal también cuesta la nave doble ganada por
		# rescate, igual que en el arcade original: vuelves a un solo caza.
		if captured_fighter.get("view") != null:
			captured_fighter["view"].queue_free()
		captured_fighter = {}
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
