extends Control
## Lazo y Burbujas, al estilo de Pang / Buster Bros (Mitchell, 1989): un
## cazador dispara un arpón con cuerda hacia arriba y revienta globos que
## rebotan por la pantalla. Cada globo se parte en dos más chicos (4
## tamaños) hasta desaparecer. 12 escenarios de "viaje por el mundo", con
## plataformas (algunas se rompen con el arpón), poderes y límite de tiempo.
##
## Control táctil sin botones: arrastra el dedo para moverte (el cazador lo
## sigue) y toca para disparar. Teclado: flechas y espacio.

const GAME_ID := "burbujas"
const PLAY_W := 680.0
const PLAY_H := 900.0
const FLOOR_Y := 860.0
const GRAVITY := 900.0
const PLAYER_SIZE := Vector2(36, 52)
const PLAYER_SPEED := 300.0
const WIRE_SPEED := 760.0
const STICKY_TIME := 2.5
const BALL_RADIUS := [46.0, 31.0, 19.0, 11.0]
const BALL_BOUNCE := [440.0, 340.0, 250.0, 165.0]   # altura del rebote en el piso, por tamaño
const BALL_POINTS := [50, 100, 150, 200]
const BALL_SPEED_X := 115.0
const BALL_COLORS := [Color(0.95, 0.2, 0.25), Color(0.25, 0.5, 1.0), Color(0.25, 0.8, 0.35), Color(1.0, 0.7, 0.15)]
const STAGE_TIME := 100.0
const START_LIVES := 3
const ITEM_CHANCE := 0.16
const ITEM_LIFE := 6.0
const ITEMS := {
	"doble": {"icon": "⚡", "color": Color(1.0, 0.85, 0.2)},      # 2 arpones a la vez
	"ancla": {"icon": "⚓", "color": Color(0.7, 0.75, 0.8)},      # el arpón se queda pegado al techo
	"metralla": {"icon": "🔫", "color": Color(0.95, 0.5, 0.2)},  # ráfaga de balas
	"reloj": {"icon": "⏱", "color": Color(0.4, 0.8, 1.0)},       # congela los globos
	"dinamita": {"icon": "💣", "color": Color(0.9, 0.25, 0.2)},  # parte todos al tamaño más chico
	"escudo": {"icon": "🛡", "color": Color(0.5, 0.9, 0.5)},      # aguanta un golpe
	"fruta": {"icon": "🍒", "color": Color(1.0, 0.4, 0.5)},      # puntos
}

## Escenarios: [tamaño, x, dirección] por globo y plataformas
## [x, y, ancho, alto, rompible].
const STAGES := [
	{"name": "Monte Fuji", "scene": "fuji", "balls": [[0, 180, 1]], "platforms": []},
	{"name": "Monte Fuji", "scene": "fuji", "balls": [[0, 150, 1], [1, 520, -1]], "platforms": []},
	{"name": "Guilin", "scene": "karst", "balls": [[0, 200, 1], [0, 480, -1]], "platforms": []},
	{"name": "Guilin", "scene": "karst", "balls": [[1, 120, 1], [1, 340, -1], [1, 560, 1]], "platforms": [[240, 540, 200, 22, true]]},
	{"name": "Templo Esmeralda", "scene": "temple", "balls": [[0, 340, 1]], "platforms": [[60, 500, 180, 22, false], [440, 500, 180, 22, false]]},
	{"name": "Angkor Wat", "scene": "temple", "balls": [[0, 150, 1], [0, 520, -1]], "platforms": [[260, 440, 160, 22, true]]},
	{"name": "Uluru", "scene": "desert", "balls": [[1, 100, 1], [1, 250, 1], [1, 420, -1], [1, 580, -1]], "platforms": []},
	{"name": "Taj Mahal", "scene": "dome", "balls": [[0, 340, 1], [1, 120, -1], [1, 560, 1]], "platforms": [[0, 580, 200, 22, true], [480, 580, 200, 22, true]]},
	{"name": "Kremlin", "scene": "dome", "balls": [[0, 200, 1], [0, 480, -1], [2, 340, 1]], "platforms": []},
	{"name": "París", "scene": "tower", "balls": [[0, 120, 1], [0, 340, -1], [0, 560, 1]], "platforms": [[200, 400, 280, 22, false]]},
	{"name": "Barcelona", "scene": "tower", "balls": [[0, 200, 1], [0, 480, -1], [1, 100, 1], [1, 580, -1]], "platforms": [[60, 520, 140, 22, true], [480, 520, 140, 22, true]]},
	{"name": "Isla de Pascua", "scene": "moai", "balls": [[0, 150, 1], [0, 340, -1], [0, 530, 1], [1, 340, 1]], "platforms": []},
]
const SCENE_PALETTES := {
	"fuji": [Color(0.45, 0.7, 0.95), Color(0.85, 0.92, 1.0), Color(0.35, 0.45, 0.65), Color(0.3, 0.55, 0.3)],
	"karst": [Color(0.55, 0.75, 0.85), Color(0.9, 0.95, 0.9), Color(0.25, 0.5, 0.4), Color(0.35, 0.6, 0.6)],
	"temple": [Color(0.95, 0.65, 0.4), Color(1.0, 0.9, 0.7), Color(0.45, 0.35, 0.3), Color(0.35, 0.5, 0.25)],
	"desert": [Color(0.95, 0.55, 0.3), Color(1.0, 0.85, 0.55), Color(0.75, 0.3, 0.15), Color(0.85, 0.6, 0.35)],
	"dome": [Color(0.5, 0.6, 0.9), Color(0.95, 0.85, 0.9), Color(0.92, 0.9, 0.85), Color(0.5, 0.55, 0.4)],
	"tower": [Color(0.3, 0.35, 0.7), Color(0.95, 0.6, 0.55), Color(0.25, 0.22, 0.3), Color(0.3, 0.35, 0.3)],
	"moai": [Color(0.35, 0.6, 0.95), Color(0.8, 0.95, 1.0), Color(0.45, 0.42, 0.4), Color(0.4, 0.65, 0.35)],
}

const HELP_TEXT := "Revienta todos los globos con tu arpón. Se juega tocando el juego, sin botones:

- Arrastra el dedo: el cazador lo sigue de lado a lado.
- Toca: dispara el arpón hacia arriba. La cuerda revienta cualquier globo que la toque mientras sube.
(En teclado: flechas y espacio.)

Cada globo se parte en dos más chicos; los más chicos valen más. Si un globo te toca, pierdes una vida y se reinicia el escenario. Tienes 100 segundos por escenario.

Algunos globos sueltan poderes: ⚡ doble arpón · ⚓ el arpón se queda pegado al techo · 🔫 metralleta · ⏱ congela los globos · 💣 dinamita (parte todos al tamaño más chico) · 🛡 escudo (aguanta un golpe) · 🍒 puntos.

Las plataformas detienen el arpón; las de color claro se rompen al dispararles. Hay 12 escenarios por el mundo."

var balls: Array = []
var wires: Array = []        # {"x", "tip", "stuck_t"}
var bullets: Array = []      # metralla
var items: Array = []
var platforms: Array = []    # {"rect", "breakable"}
var pops: Array = []         # efectos de reventado
var player_x: float = 0.0
var facing: int = 1
var weapon: String = "arpon"   # arpon | doble | ancla | metralla
var weapon_timer: float = 0.0
var freeze_timer: float = 0.0
var shield: bool = false
var fire_cooldown: float = 0.0
var time_left: float = STAGE_TIME
var stage: int = 0
var score: int = 0
var lives: int = START_LIVES
var state: String = "playing"  # playing | dying | stage_clear | game_over | won
var anim_t: float = 0.0
var hurt_t: float = 0.0

var play_area: Control
var pad: GesturePad
var player_view: EntitySprite
var score_label: Label
var lives_label: Label
var stage_label: Label
var time_label: Label
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

	UIKit.build_toolbar(vbox, self, "Lazo y Burbujas", HELP_TEXT)

	var hud_panel := PanelContainer.new()
	hud_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_2, 10, 2))
	vbox.add_child(hud_panel)
	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 22)
	hud_panel.add_child(hud)
	score_label = UIKit.title_label("★ 0", 15, UIKit.COLOR_ACCENT_3)
	hud.add_child(score_label)
	stage_label = UIKit.title_label("", 15, UIKit.COLOR_TEXT_DIM)
	hud.add_child(stage_label)
	time_label = UIKit.title_label("⏱ 100", 15, UIKit.COLOR_ACCENT_2)
	hud.add_child(time_label)
	lives_label = UIKit.title_label("♥ 3", 15, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)

	status_label = UIKit.title_label("", 13, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(play_panel)
	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_area.draw.connect(_draw_play)
	play_panel.add_child(play_area)

	player_view = EntitySprite.new()
	player_view.size = Vector2(46, 56)
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.setup("cowboy", Color(0.85, 0.6, 0.3), Color(0.35, 0.5, 0.25))
	play_area.add_child(player_view)

	pad = GesturePad.attach(play_area)
	pad.tapped.connect(func(_p: Vector2) -> void: _fire())

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _new_game() -> void:
	score = 0
	lives = START_LIVES
	stage = 0
	_start_stage()


func _start_stage() -> void:
	var st: Dictionary = STAGES[stage]
	balls.clear()
	for b: Array in st["balls"]:
		_spawn_ball(b[0], Vector2(b[1], 160.0 + b[0] * 40.0), BALL_SPEED_X * b[2], 0.0)
	platforms.clear()
	for p: Array in st["platforms"]:
		platforms.append({"rect": Rect2(p[0], p[1], p[2], p[3]), "breakable": p[4]})
	wires.clear()
	bullets.clear()
	items.clear()
	pops.clear()
	player_x = PLAY_W / 2.0 - PLAYER_SIZE.x / 2.0
	weapon = "arpon"
	weapon_timer = 0.0
	freeze_timer = 0.0
	shield = false
	time_left = STAGE_TIME
	hurt_t = 0.0
	state = "playing"
	stage_label.text = "%d/%d %s" % [stage + 1, STAGES.size(), st["name"]]
	status_label.text = "¡Revienta todos los globos!"
	status_label.remove_theme_color_override("font_color")
	_update_hud()


func _spawn_ball(size: int, pos: Vector2, vx: float, vy: float) -> void:
	balls.append({"size": size, "pos": pos, "vel": Vector2(vx, vy)})


func _bounce_speed(size: int) -> float:
	return sqrt(2.0 * GRAVITY * BALL_BOUNCE[size])


func _update_hud() -> void:
	score_label.text = "★ %d" % score
	lives_label.text = "♥ %d%s" % [lives, "  🛡" if shield else ""]
	time_label.text = "⏱ %d" % ceili(maxf(time_left, 0.0))


# ------------------------------------------------------------------ bucle --
func _process(delta: float) -> void:
	anim_t += delta
	_update_pops(delta)
	play_area.queue_redraw()
	if state != "playing":
		_sync_player()
		return

	time_left -= delta
	if int(time_left + delta) != int(time_left):
		_update_hud()
	if time_left <= 0.0:
		_player_hit(true)
		return
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if weapon_timer > 0.0:
		weapon_timer -= delta
		if weapon_timer <= 0.0:
			weapon = "arpon"
	if freeze_timer > 0.0:
		freeze_timer -= delta
	if hurt_t > 0.0:
		hurt_t -= delta

	_move_player(delta)
	if weapon == "metralla" and (pad.is_down or Input.is_key_pressed(KEY_SPACE)):
		_fire()
	_update_balls(delta)
	_update_wires(delta)
	_update_bullets(delta)
	_update_items(delta)
	_check_player_hit()
	if state == "playing" and balls.is_empty():
		_stage_clear()


func _move_player(delta: float) -> void:
	var vx := 0.0
	# Solo se mueve con un arrastre (no con un toque corto, que dispara).
	if pad.is_holding():
		var target: float = pad.current_pos.x - PLAYER_SIZE.x / 2.0
		vx = clampf((target - player_x) / maxf(delta, 0.001), -PLAYER_SPEED, PLAYER_SPEED)
	elif Input.is_key_pressed(KEY_LEFT):
		vx = -PLAYER_SPEED
	elif Input.is_key_pressed(KEY_RIGHT):
		vx = PLAYER_SPEED
	if absf(vx) > 5.0:
		facing = 1 if vx > 0.0 else -1
	player_x = clampf(player_x + vx * delta, 0.0, PLAY_W - PLAYER_SIZE.x)
	_sync_player()


func _sync_player() -> void:
	player_view.position = Vector2(player_x + PLAYER_SIZE.x / 2.0 - player_view.size.x / 2.0, FLOOR_Y - player_view.size.y)
	player_view.set_facing(0.0, facing < 0)
	player_view.set_phase(fmod(anim_t * 2.0, 1.0))
	player_view.modulate.a = 0.4 if hurt_t > 0.0 and int(hurt_t * 10.0) % 2 == 0 else 1.0


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_fire()


func _fire() -> void:
	if state != "playing" or fire_cooldown > 0.0:
		return
	var cx: float = player_x + PLAYER_SIZE.x / 2.0
	if weapon == "metralla":
		fire_cooldown = 0.09
		bullets.append({"pos": Vector2(cx + randf_range(-6.0, 6.0), FLOOR_Y - PLAYER_SIZE.y)})
		return
	var max_wires: int = 2 if weapon == "doble" else 1
	if wires.size() >= max_wires:
		return
	fire_cooldown = 0.12
	wires.append({"x": cx, "tip": FLOOR_Y - PLAYER_SIZE.y * 0.6, "stuck_t": -1.0})
	AudioManager.play_click()


func _update_balls(delta: float) -> void:
	if freeze_timer > 0.0:
		return
	for b: Dictionary in balls:
		var r: float = BALL_RADIUS[b["size"]]
		b["vel"].y += GRAVITY * delta
		b["pos"] += b["vel"] * delta
		if b["pos"].x < r:
			b["pos"].x = r
			b["vel"].x = absf(b["vel"].x)
		elif b["pos"].x > PLAY_W - r:
			b["pos"].x = PLAY_W - r
			b["vel"].x = -absf(b["vel"].x)
		if b["pos"].y < r:
			b["pos"].y = r
			b["vel"].y = absf(b["vel"].y)
		if b["pos"].y > FLOOR_Y - r:
			# Rebote con altura fija por tamaño, como en Pang.
			b["pos"].y = FLOOR_Y - r
			b["vel"].y = -_bounce_speed(b["size"])
		for p: Dictionary in platforms:
			_collide_ball_rect(b, r, p["rect"])


func _collide_ball_rect(b: Dictionary, r: float, rect: Rect2) -> void:
	var c: Vector2 = b["pos"]
	var closest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	var d: Vector2 = c - closest
	if d.length_squared() >= r * r:
		return
	if d == Vector2.ZERO:
		d = Vector2(0, -1)
	var n: Vector2 = d.normalized()
	b["pos"] = closest + n * r
	if absf(n.y) > absf(n.x):
		if n.y < 0.0:
			b["vel"].y = -_bounce_speed(b["size"])  # rebota encima como en el piso
		else:
			b["vel"].y = absf(b["vel"].y)
	else:
		b["vel"].x = absf(b["vel"].x) * signf(n.x)


func _update_wires(delta: float) -> void:
	for i in range(wires.size() - 1, -1, -1):
		var w: Dictionary = wires[i]
		if w["stuck_t"] >= 0.0:
			w["stuck_t"] -= delta
			if w["stuck_t"] < 0.0:
				wires.remove_at(i)
				continue
		else:
			w["tip"] -= WIRE_SPEED * delta
		# Choca con plataformas: se detiene (y rompe las rompibles).
		var stopped := false
		for j in range(platforms.size() - 1, -1, -1):
			var rect: Rect2 = platforms[j]["rect"]
			if w["x"] >= rect.position.x and w["x"] <= rect.end.x and w["tip"] <= rect.end.y and w["tip"] + WIRE_SPEED * delta >= rect.end.y - 1.0:
				if platforms[j]["breakable"]:
					_add_pop(rect.get_center(), Color(0.9, 0.85, 0.7), 40.0)
					platforms.remove_at(j)
					score += 50
				stopped = true
				break
		if not stopped and w["tip"] <= 0.0:
			if weapon == "ancla" and w["stuck_t"] < 0.0:
				w["tip"] = 0.0
				w["stuck_t"] = STICKY_TIME
			elif w["stuck_t"] < 0.0:
				stopped = true
		if stopped:
			wires.remove_at(i)
			continue
		# ¿Algún globo toca la cuerda?
		for k in range(balls.size()):
			var b: Dictionary = balls[k]
			var r: float = BALL_RADIUS[b["size"]]
			if absf(b["pos"].x - w["x"]) <= r and b["pos"].y + r >= w["tip"]:
				_pop_ball(k)
				wires.remove_at(i)
				break


func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		bullets[i]["pos"].y -= 900.0 * delta
		var p: Vector2 = bullets[i]["pos"]
		var hit := p.y < 0.0
		for rect_info: Dictionary in platforms:
			if rect_info["rect"].has_point(p):
				hit = true
		if not hit:
			for k in range(balls.size()):
				if balls[k]["pos"].distance_to(p) <= BALL_RADIUS[balls[k]["size"]]:
					_pop_ball(k)
					hit = true
					break
		if hit:
			bullets.remove_at(i)


func _pop_ball(k: int) -> void:
	var b: Dictionary = balls[k]
	balls.remove_at(k)
	score += BALL_POINTS[b["size"]]
	_add_pop(b["pos"], BALL_COLORS[b["size"]], BALL_RADIUS[b["size"]])
	AudioManager.play_place()
	if b["size"] < BALL_RADIUS.size() - 1:
		var ns: int = b["size"] + 1
		var up: float = -minf(_bounce_speed(ns) * 0.8, 520.0)
		for d in [-1.0, 1.0]:
			_spawn_ball(ns, b["pos"] + Vector2(d * BALL_RADIUS[ns] * 0.5, 0), BALL_SPEED_X * d, up)
	if randf() < ITEM_CHANCE:
		var kinds: Array = ITEMS.keys()
		items.append({"kind": kinds[randi() % kinds.size()], "pos": b["pos"], "vy": 0.0, "life": ITEM_LIFE})
	_update_hud()


func _update_items(delta: float) -> void:
	var pr := Rect2(player_x, FLOOR_Y - PLAYER_SIZE.y, PLAYER_SIZE.x, PLAYER_SIZE.y)
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		it["vy"] = minf(it["vy"] + GRAVITY * 0.6 * delta, 400.0)
		it["pos"].y = minf(it["pos"].y + it["vy"] * delta, FLOOR_Y - 16.0)
		for p: Dictionary in platforms:
			var rect: Rect2 = p["rect"]
			if it["pos"].x > rect.position.x and it["pos"].x < rect.end.x and it["pos"].y + 16.0 >= rect.position.y and it["pos"].y < rect.position.y + 6.0:
				it["pos"].y = rect.position.y - 16.0
		if it["pos"].y >= FLOOR_Y - 16.0:
			it["life"] -= delta
		if pr.grow(6.0).has_point(it["pos"]):
			_apply_item(it["kind"])
			items.remove_at(i)
		elif it["life"] <= 0.0:
			items.remove_at(i)


func _apply_item(kind: String) -> void:
	AudioManager.play_power()
	match kind:
		"doble", "ancla", "metralla":
			weapon = kind
			weapon_timer = 15.0 if kind != "metralla" else 6.0
			wires.clear()
		"reloj":
			freeze_timer = 5.0
		"dinamita":
			# Parte todos los globos hasta el tamaño más chico.
			var changed := true
			while changed:
				changed = false
				for k in range(balls.size()):
					if balls[k]["size"] < BALL_RADIUS.size() - 1:
						var b: Dictionary = balls[k]
						balls.remove_at(k)
						var ns: int = b["size"] + 1
						for d in [-1.0, 1.0]:
							_spawn_ball(ns, b["pos"] + Vector2(d * BALL_RADIUS[ns], 0), BALL_SPEED_X * d, -300.0)
						changed = true
						break
		"escudo":
			shield = true
		"fruta":
			score += 1000
	status_label.text = {"doble": "¡Doble arpón!", "ancla": "¡Arpón ancla!", "metralla": "¡Metralleta!", "reloj": "¡Tiempo congelado!",
		"dinamita": "¡Dinamita!", "escudo": "¡Escudo!", "fruta": "+1000"}[kind]
	_update_hud()


func _check_player_hit() -> void:
	if hurt_t > 0.0:
		return
	var pr := Rect2(player_x + 6.0, FLOOR_Y - PLAYER_SIZE.y + 8.0, PLAYER_SIZE.x - 12.0, PLAYER_SIZE.y - 8.0)
	for b: Dictionary in balls:
		var r: float = BALL_RADIUS[b["size"]] * 0.9
		var c: Vector2 = b["pos"]
		var closest := Vector2(clampf(c.x, pr.position.x, pr.end.x), clampf(c.y, pr.position.y, pr.end.y))
		if c.distance_squared_to(closest) < r * r:
			if shield:
				shield = false
				hurt_t = 1.5
				status_label.text = "¡El escudo te salvó!"
				AudioManager.play_alert()
				_update_hud()
			else:
				_player_hit(false)
			return


func _player_hit(time_out: bool) -> void:
	state = "dying"
	lives -= 1
	_update_hud()
	AudioManager.play_lose() if lives <= 0 else AudioManager.play_error()
	status_label.text = "¡Se acabó el tiempo!" if time_out else "¡Te alcanzó un globo!"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
	await get_tree().create_timer(1.4).timeout
	if state != "dying":
		return
	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over · Puntos: %d" % score
		_record_result(false)
	else:
		_start_stage()


func _stage_clear() -> void:
	state = "stage_clear"
	var bonus: int = int(time_left) * 20
	score += bonus
	_update_hud()
	AudioManager.play_win()
	status_label.text = "¡Escenario superado! Bono de tiempo +%d" % bonus
	await get_tree().create_timer(1.8).timeout
	if state != "stage_clear":
		return
	if stage >= STAGES.size() - 1:
		state = "won"
		status_label.text = "¡Diste la vuelta al mundo! Puntos: %d" % score
		_record_result(true)
		return
	stage += 1
	_start_stage()


func _add_pop(pos: Vector2, color: Color, r: float) -> void:
	pops.append({"pos": pos, "color": color, "r": r, "t": 0.0})


func _update_pops(delta: float) -> void:
	for i in range(pops.size() - 1, -1, -1):
		pops[i]["t"] += delta
		if pops[i]["t"] > 0.3:
			pops.remove_at(i)


func _record_result(won: bool) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)


# ----------------------------------------------------------------- dibujo --
func _draw_play() -> void:
	var ca: Control = play_area
	var st: Dictionary = STAGES[stage]
	var pal: Array = SCENE_PALETTES[st["scene"]]
	# Cielo en degradado (franjas) y paisaje del escenario.
	for i in range(30):
		var t: float = float(i) / 29.0
		ca.draw_rect(Rect2(0, t * FLOOR_Y, PLAY_W, FLOOR_Y / 30.0 + 1.0), pal[0].lerp(pal[1], t))
	_draw_landmark(st["scene"], pal)
	ca.draw_rect(Rect2(0, FLOOR_Y, PLAY_W, PLAY_H - FLOOR_Y), pal[3].darkened(0.2))
	ca.draw_rect(Rect2(0, FLOOR_Y, PLAY_W, 5), pal[3].lightened(0.2))

	for p: Dictionary in platforms:
		var rect: Rect2 = p["rect"]
		var col: Color = Color(0.92, 0.85, 0.65) if p["breakable"] else Color(0.45, 0.45, 0.5)
		ca.draw_rect(rect, col)
		ca.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), col.lightened(0.35))
		ca.draw_rect(Rect2(rect.position.x, rect.end.y - 4, rect.size.x, 4), col.darkened(0.35))
		if p["breakable"]:
			for bx in range(int(rect.position.x) + 30, int(rect.end.x), 30):
				ca.draw_line(Vector2(bx, rect.position.y), Vector2(bx, rect.end.y), col.darkened(0.25), 2.0)

	for w: Dictionary in wires:
		_draw_wire(w)
	for bl: Dictionary in bullets:
		ca.draw_rect(Rect2(bl["pos"] - Vector2(2, 8), Vector2(4, 16)), Color(1, 0.9, 0.4))

	for b: Dictionary in balls:
		var r: float = BALL_RADIUS[b["size"]]
		var col: Color = BALL_COLORS[b["size"]]
		if freeze_timer > 0.0:
			col = col.lerp(Color(0.7, 0.9, 1.0), 0.5)
		ca.draw_circle(b["pos"] + Vector2(3, 4), r, Color(0, 0, 0, 0.18))
		ca.draw_circle(b["pos"], r, col.darkened(0.25))
		ca.draw_circle(b["pos"] - Vector2(r * 0.08, r * 0.08), r * 0.9, col)
		ca.draw_circle(b["pos"] - Vector2(r * 0.35, r * 0.38), r * 0.28, Color(1, 1, 1, 0.75))

	var f: Font = get_theme_default_font()
	for it: Dictionary in items:
		var blink: bool = it["life"] < 2.0 and int(it["life"] * 8.0) % 2 == 0
		if blink:
			continue
		var info: Dictionary = ITEMS[it["kind"]]
		ca.draw_circle(it["pos"], 16, info["color"].darkened(0.3))
		ca.draw_circle(it["pos"], 13, info["color"])
		var s: Vector2 = f.get_string_size(info["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		ca.draw_string(f, it["pos"] + Vector2(-s.x / 2.0, 7), info["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

	for pp: Dictionary in pops:
		var k: float = pp["t"] / 0.3
		ca.draw_arc(pp["pos"], pp["r"] * (1.0 + k * 0.8), 0, TAU, 24, Color(pp["color"].r, pp["color"].g, pp["color"].b, 1.0 - k), 3.0)
		for a in range(6):
			var ang: float = a * TAU / 6.0
			ca.draw_line(pp["pos"] + Vector2(cos(ang), sin(ang)) * pp["r"] * (0.6 + k), pp["pos"] + Vector2(cos(ang), sin(ang)) * pp["r"] * (1.0 + k * 1.2), Color(1, 1, 1, 1.0 - k), 2.0)

	if shield and state == "playing":
		ca.draw_arc(Vector2(player_x + PLAYER_SIZE.x / 2.0, FLOOR_Y - PLAYER_SIZE.y / 2.0), 36, 0, TAU, 32, Color(0.5, 1.0, 0.6, 0.7), 3.0)


## La cuerda del arpón: zigzag (como el cable del Pang) con punta de flecha.
func _draw_wire(w: Dictionary) -> void:
	var ca: Control = play_area
	var x: float = w["x"]
	var pts := PackedVector2Array()
	var y: float = FLOOR_Y - 10.0
	var side := 1.0
	while y > w["tip"]:
		pts.append(Vector2(x + side * 4.0, y))
		side = -side
		y -= 9.0
	pts.append(Vector2(x, w["tip"]))
	var col: Color = Color(0.85, 0.85, 0.9) if weapon != "ancla" else Color(1.0, 0.85, 0.3)
	if pts.size() > 1:
		ca.draw_polyline(pts, col, 2.0, true)
	ca.draw_colored_polygon(PackedVector2Array([Vector2(x, w["tip"] - 12), Vector2(x - 7, w["tip"] + 2), Vector2(x + 7, w["tip"] + 2)]), Color(0.95, 0.95, 1.0))


## Monumento/paisaje del escenario, dibujado con formas simples.
func _draw_landmark(kind: String, pal: Array) -> void:
	var ca: Control = play_area
	var c: Color = pal[2]
	var base: float = FLOOR_Y
	# Colinas de fondo.
	var hills := PackedVector2Array([Vector2(0, base)])
	for i in range(13):
		var x: float = i * PLAY_W / 12.0
		hills.append(Vector2(x, base - 90.0 - 40.0 * sin(i * 1.3 + stage)))
	hills.append(Vector2(PLAY_W, base))
	ca.draw_colored_polygon(hills, pal[3].lerp(pal[1], 0.35))
	match kind:
		"fuji":
			ca.draw_colored_polygon(PackedVector2Array([Vector2(60, base - 60), Vector2(340, base - 520), Vector2(620, base - 60)]), c)
			ca.draw_colored_polygon(PackedVector2Array([Vector2(272, base - 420), Vector2(340, base - 520), Vector2(408, base - 420), Vector2(370, base - 435), Vector2(340, base - 415), Vector2(305, base - 437)]), Color(0.97, 0.98, 1.0))
		"karst":
			for k in range(6):
				var cx: float = 40.0 + k * 120.0
				var h: float = 260.0 + 140.0 * sin(k * 2.1)
				ca.draw_colored_polygon(PackedVector2Array([Vector2(cx - 60, base - 40), Vector2(cx - 35, base - h), Vector2(cx, base - h - 30), Vector2(cx + 35, base - h), Vector2(cx + 60, base - 40)]), c.lerp(pal[1], 0.15 * (k % 2)))
		"temple":
			for step in range(5):
				var w: float = 460.0 - step * 80.0
				ca.draw_rect(Rect2(PLAY_W / 2.0 - w / 2.0, base - 80.0 - step * 60.0, w, 60.0), c.lightened(step * 0.05))
			ca.draw_colored_polygon(PackedVector2Array([Vector2(PLAY_W / 2.0 - 60, base - 380), Vector2(PLAY_W / 2.0, base - 520), Vector2(PLAY_W / 2.0 + 60, base - 380)]), c)
		"desert":
			ca.draw_colored_polygon(PackedVector2Array([Vector2(80, base - 50), Vector2(150, base - 260), Vector2(520, base - 280), Vector2(610, base - 50)]), c)
		"dome":
			ca.draw_rect(Rect2(PLAY_W / 2.0 - 160, base - 300, 320, 240), c)
			ca.draw_circle(Vector2(PLAY_W / 2.0, base - 300), 110, c)
			ca.draw_rect(Rect2(PLAY_W / 2.0 - 4, base - 450, 8, 50), c.darkened(0.2))
			for mx in [PLAY_W / 2.0 - 240, PLAY_W / 2.0 + 220]:
				ca.draw_rect(Rect2(mx, base - 420, 20, 360), c)
		"tower":
			ca.draw_colored_polygon(PackedVector2Array([Vector2(220, base - 60), Vector2(330, base - 620), Vector2(350, base - 620), Vector2(460, base - 60), Vector2(400, base - 60), Vector2(340, base - 300), Vector2(280, base - 60)]), c)
			ca.draw_rect(Rect2(270, base - 330, 140, 14), c)
		"moai":
			for k in range(3):
				var mx: float = 150.0 + k * 190.0
				ca.draw_rect(Rect2(mx, base - 300, 90, 240), c)
				ca.draw_rect(Rect2(mx - 6, base - 310, 102, 30), c.darkened(0.25))
				ca.draw_rect(Rect2(mx + 34, base - 230, 22, 80), c.darkened(0.2))
