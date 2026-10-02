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

## Entrada estilo Galaga real: la formación llega en 5 oleadas. Cada oleada
## es un "convoy" que sigue la misma curva con rizo (una detrás de otra,
## separadas CONVOY_GAP s) y al final cada nave se separa hacia su lugar.
const ENTRY_PATH_DURATION := 2.1
const ENTRY_TO_SLOT := 0.55
const CONVOY_GAP := 0.13
const WAVE_GAP := 1.35
const ENTRY_WAVES := 5
## Mientras la formación se arma, se desplaza de lado a lado toda junta;
## ya completa, "respira" (se abre y cierra desde el centro), como el arcade.
const BREATHE_SPEED := 1.7
const BREATHE_AMOUNT := 0.09
const DIVE_DURATION := 1.55
const REJOIN_DURATION := 1.1
## Etapa de desafío (bonus): después de los niveles 2 y 6. 5 oleadas de 8
## naves cruzan la pantalla en rizos SIN disparar; 100 pts por impacto y
## 10 000 si las derribas todas ("PERFECT!"), como en el original.
const CHALLENGE_AFTER_LEVELS := [2, 6]
const CHALLENGE_WAVES := 5
const CHALLENGE_PER_WAVE := 8
const CHALLENGE_PATH_DURATION := 4.6
const CHALLENGE_HIT_POINTS := 100
const CHALLENGE_PERFECT_BONUS := 10000
const CAPTURE_CHANCE := 0.3
const CAPTURE_MIN_LEVEL := 2
const CAPTURE_RETURN_DURATION := 0.8
const CAPTURED_TINT := Color(0.55, 0.58, 0.66)

const HELP_TEXT := "Pon el dedo sobre el juego y arrástralo: la nave lo sigue de lado a lado y dispara sola mientras lo mantengas abajo. (En teclado: flechas y espacio.)

Al iniciar cada nivel, la formación entra en 5 oleadas: convoyes que hacen un rizo y luego suben a su lugar — ya puedes dispararles mientras entran. Mientras se arma, la formación se desliza de lado a lado y, ya completa, se abre y se cierra y de vez en cuando una nave pica hacia ti en una curva envolvente, disparando — esquívala o destrúyela (vale más puntos que una que sigue en formación).

Cuidado con los jefes (arriba, con escudo giratorio): a veces, en vez de disparar, capturan tu nave con un rayo tractor y se la llevan a la formación. Sigues jugando con una nave nueva, pero para rescatar la capturada debes destruir justo a ese jefe — al lograrlo, vuelas con dos naves a la vez (doble disparo) el resto del nivel.

Las naves que bajan en picada y no destruyes reaparecen arriba y vuelven a su lugar.

Después de los niveles 2 y 6 viene una ETAPA DE DESAFÍO: 40 naves cruzan la pantalla en rizos sin disparar. 100 puntos por cada una que derribes y 10 000 de bonus si las derribas todas.

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

var formation_complete: bool = false
var breathe_start: float = 0.0
var in_challenge: bool = false
var challenge_hits: int = 0
var challenge_total: int = 0
var challenge_timer: float = 0.0
var challenges_done: Array = []

var player_captured: bool = false
var pad: GesturePad
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

	# Control táctil sin botones: la nave sigue al dedo a lo ancho y dispara
	# sola mientras mantienes el dedo sobre el juego.
	pad = GesturePad.attach(play_area)

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


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
	challenges_done.clear()
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

	in_challenge = false
	challenge_hits = 0
	formation_complete = false
	var rows: int = min(2 + level / 2, 6)
	var total_width: float = (FORMATION_COLS - 1) * COL_SPACING
	var start_x: float = (PLAY_W - total_width) / 2.0 - ENEMY_SIZE.x / 2.0

	var slots: Array = []
	for r in range(rows):
		for c in range(FORMATION_COLS):
			slots.append(Vector2i(c, r))
	# Reparto en oleadas: se llena de arriba hacia abajo, y dentro de cada
	# oleada del centro hacia afuera -- las primeras naves en llegar ocupan
	# el centro de las filas de arriba, como en el arcade.
	var per_wave: int = ceili(float(slots.size()) / ENTRY_WAVES)
	var mid: float = (FORMATION_COLS - 1) / 2.0
	slots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return absf(a.x - mid) < absf(b.x - mid))

	for i in range(slots.size()):
		var slot: Vector2i = slots[i]
		var r: int = slot.y
		var c: int = slot.x
		var wave: int = i / per_wave
		var in_wave: int = i % per_wave
		var visual: Dictionary = ROW_VISUALS[r % ROW_VISUALS.size()]
		var view := EntitySprite.new()
		view.size = ENEMY_SIZE
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.setup(visual["shape"], visual["color"], visual["color2"], r * FORMATION_COLS + c)
		play_area.add_child(view)
		var path: Array = _entry_path(wave)
		view.position = path[0]
		enemies.append({
			"row": r, "base_x": start_x + c * COL_SPACING, "base_y": FORMATION_TOP + r * ROW_SPACING,
			"pos": path[0], "state": "entering", "path": path,
			"entry_t": -(wave * WAVE_GAP + in_wave * CONVOY_GAP),
			"phase": randf() * TAU, "wing_seed": randf(), "has_shot": false, "view": view,
			"is_boss": r == 0, "carries_capture": false,
		})

	dive_interval = max(0.5, 1.7 - level * 0.1)
	var last_arrival: float = (ENTRY_WAVES - 1) * WAVE_GAP + per_wave * CONVOY_GAP + ENTRY_PATH_DURATION + ENTRY_TO_SLOT
	dive_timer = dive_interval + last_arrival
	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	status_label.remove_theme_color_override("font_color")
	_update_hud()


## Curva de entrada de cada oleada (puntos para Catmull-Rom): alternan
## desde arriba-izquierda, arriba-derecha y los costados, todas con un rizo
## completo antes de subir a la formación.
func _entry_path(wave: int) -> Array:
	var mirror: bool = wave % 2 == 1
	var pts: Array
	match wave % 3:
		0:
			pts = [Vector2(250, -60), Vector2(270, 120), Vector2(230, 330)]
			pts.append_array(_loop_points(Vector2(170, 400), 75.0, -PI / 2.0 + 0.9, true))
			pts.append(Vector2(260, 300))
		1:
			pts = [Vector2(-50, 640), Vector2(120, 600), Vector2(280, 520)]
			pts.append_array(_loop_points(Vector2(330, 430), 80.0, PI / 2.0, false))
			pts.append(Vector2(300, 300))
		_:
			pts = [Vector2(PLAY_W / 2.0 - 10.0, -60), Vector2(PLAY_W / 2.0 - 40.0, 200)]
			pts.append_array(_loop_points(Vector2(PLAY_W / 2.0 - 110.0, 360), 90.0, 0.0, true))
			pts.append(Vector2(PLAY_W / 2.0 - 60.0, 260))
	if mirror:
		for i in range(pts.size()):
			pts[i] = Vector2(PLAY_W - pts[i].x, pts[i].y)
	return pts


func _loop_points(center: Vector2, radius: float, start_angle: float, clockwise: bool) -> Array:
	var out: Array = []
	for k in range(9):
		var a: float = start_angle + (TAU * k / 8.0) * (1.0 if clockwise else -1.0)
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out


## Punto a lo largo de una curva Catmull-Rom que pasa por todos los puntos
## (t de 0 a 1 recorre la curva completa).
func _spline(pts: Array, t: float) -> Vector2:
	var n: int = pts.size() - 1
	var f: float = clampf(t, 0.0, 1.0) * n
	var i: int = mini(int(f), n - 1)
	var u: float = f - i
	var p0: Vector2 = pts[maxi(i - 1, 0)]
	var p1: Vector2 = pts[i]
	var p2: Vector2 = pts[i + 1]
	var p3: Vector2 = pts[mini(i + 2, n)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


## Posición del lugar de la nave en la formación en este instante: toda la
## formación se desliza de lado a lado mientras llegan naves, y ya completa
## "respira" abriéndose y cerrándose desde el centro.
func _formation_pos(e: Dictionary) -> Vector2:
	var bx: float = e["base_x"]
	var by: float = e["base_y"]
	if formation_complete:
		var k: float = 1.0 + BREATHE_AMOUNT * (0.5 + 0.5 * sin((time_acc - breathe_start) * BREATHE_SPEED - PI / 2.0))
		var cx: float = PLAY_W / 2.0 - ENEMY_SIZE.x / 2.0
		return Vector2(cx + (bx - cx) * k, FORMATION_TOP + (by - FORMATION_TOP) * k)
	return Vector2(bx + sin(time_acc * SWAY_SPEED) * SWAY_AMPLITUDE, by)


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

	if in_challenge:
		_process_challenge(delta)
		return

	dive_timer -= delta
	if dive_timer <= 0.0:
		dive_timer = dive_interval
		_start_random_dive()

	if not formation_complete and _all_arrived():
		formation_complete = true
		breathe_start = time_acc

	for e: Dictionary in enemies:
		if e["state"] == "removed":
			continue
		e["view"].set_phase(fmod(time_acc * 1.4 + e["wing_seed"], 1.0))

		match e["state"]:
			"entering":
				e["entry_t"] += delta
				if e["entry_t"] < 0.0:
					e["view"].visible = false
					continue
				e["view"].visible = true
				var prev: Vector2 = e["pos"]
				if e["entry_t"] < ENTRY_PATH_DURATION:
					e["pos"] = _spline(e["path"], e["entry_t"] / ENTRY_PATH_DURATION)
				else:
					# Sale del convoy y sube a su lugar (que se sigue moviendo).
					var t: float = clampf((e["entry_t"] - ENTRY_PATH_DURATION) / ENTRY_TO_SLOT, 0.0, 1.0)
					var from: Vector2 = e["path"][e["path"].size() - 1]
					var to: Vector2 = _formation_pos(e)
					e["pos"] = _bezier2(from, Vector2(lerpf(from.x, to.x, 0.5), to.y + 60.0), to, t)
					if t >= 1.0:
						e["state"] = "formation"
				_face_motion(e, prev)
				e["view"].position = e["pos"]
			"rejoin":
				# Picada que salió por abajo: reaparece arriba y vuelve a su
				# lugar en la formación (en el original no se "pierde").
				e["entry_t"] += delta
				var t4: float = clampf(e["entry_t"] / REJOIN_DURATION, 0.0, 1.0)
				var prev2: Vector2 = e["pos"]
				e["pos"] = _bezier2(e["entry_from"], e["entry_ctrl"], _formation_pos(e), t4)
				_face_motion(e, prev2)
				e["view"].position = e["pos"]
				if t4 >= 1.0:
					e["state"] = "formation"
			"formation":
				e["pos"] = _formation_pos(e)
				e["view"].set_facing(0.0)
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
						_start_rejoin(e)
			"returning":
				e["entry_t"] += delta
				var t3: float = clamp(e["entry_t"] / CAPTURE_RETURN_DURATION, 0.0, 1.0)
				e["pos"] = _bezier2(e["entry_from"], e["entry_ctrl"], _formation_pos(e), t3)
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
		if level in CHALLENGE_AFTER_LEVELS and not challenges_done.has(level):
			challenges_done.append(level)
			_start_challenge()
		else:
			_advance_level()


func _all_arrived() -> bool:
	for e: Dictionary in enemies:
		if e["state"] == "entering":
			return false
	return true


## Orienta la nave hacia donde se mueve (en entradas y regresos), como las
## naves del arcade que "miran" su trayectoria al hacer los rizos.
func _face_motion(e: Dictionary, prev: Vector2) -> void:
	var d: Vector2 = e["pos"] - prev
	if d.length() > 0.5:
		e["view"].set_facing(rad_to_deg(atan2(d.x, -d.y)))


func _start_rejoin(e: Dictionary) -> void:
	e["state"] = "rejoin"
	e["entry_t"] = 0.0
	var from := Vector2(e["base_x"], -40.0)
	e["entry_from"] = from
	e["entry_ctrl"] = Vector2(from.x, e["base_y"] * 0.5)
	e["pos"] = from


# --- Etapa de desafío -----------------------------------------------------
func _start_challenge() -> void:
	in_challenge = true
	challenge_hits = 0
	challenge_total = CHALLENGE_WAVES * CHALLENGE_PER_WAVE
	challenge_timer = 0.0
	for b: Dictionary in enemy_bullets:
		b["view"].queue_free()
	enemy_bullets.clear()
	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()
	for w in range(CHALLENGE_WAVES):
		var path: Array = _challenge_path(w)
		var visual: Dictionary = ROW_VISUALS[(w + 1) % ROW_VISUALS.size()]
		for k in range(CHALLENGE_PER_WAVE):
			var view := EntitySprite.new()
			view.size = ENEMY_SIZE
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.setup(visual["shape"], visual["color"], visual["color2"], w * 10 + k)
			view.visible = false
			play_area.add_child(view)
			enemies.append({
				"row": 5, "state": "flyby", "path": path, "pos": path[0], "view": view,
				"entry_t": -(0.6 + w * 3.4 + k * 0.17), "wing_seed": randf(), "is_boss": false,
				"carries_capture": false,
			})
	status_label.text = "¡ETAPA DE DESAFÍO!"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	AudioManager.play_power()


## Rutas de la etapa de desafío: cruzan la pantalla con rizos y se van por
## el otro lado (no se quedan en formación ni disparan).
func _challenge_path(w: int) -> Array:
	var pts: Array
	match w:
		0:
			pts = [Vector2(PLAY_W / 2.0 - 40.0, -60), Vector2(PLAY_W / 2.0 - 60.0, 180)]
			pts.append_array(_loop_points(Vector2(PLAY_W / 2.0 - 150.0, 340), 100.0, 0.0, true))
			pts.append_array([Vector2(PLAY_W / 2.0 + 60.0, 300), Vector2(PLAY_W + 80.0, 120)])
		1:
			pts = [Vector2(-60, 520), Vector2(160, 470)]
			pts.append_array(_loop_points(Vector2(300, 380), 90.0, PI / 2.0, false))
			pts.append_array([Vector2(480, 330), Vector2(PLAY_W + 80.0, 260)])
		2:
			pts = [Vector2(PLAY_W + 60.0, 520), Vector2(PLAY_W - 160.0, 470)]
			pts.append_array(_loop_points(Vector2(PLAY_W - 300.0, 380), 90.0, PI / 2.0, true))
			pts.append_array([Vector2(PLAY_W - 480.0, 330), Vector2(-80, 260)])
		3:
			pts = [Vector2(120, -60), Vector2(200, 250), Vector2(PLAY_W / 2.0, 470), Vector2(PLAY_W - 200.0, 250), Vector2(PLAY_W - 120.0, -80)]
		_:
			pts = [Vector2(PLAY_W - 120.0, -60)]
			pts.append_array(_loop_points(Vector2(PLAY_W / 2.0, 330), 150.0, -PI / 2.0 + 0.6, false))
			pts.append_array([Vector2(160, 260), Vector2(-80, 80)])
	return pts


func _process_challenge(delta: float) -> void:
	challenge_timer += delta
	var active := false
	for e: Dictionary in enemies:
		if e["state"] == "removed":
			continue
		active = true
		e["entry_t"] += delta
		if e["entry_t"] < 0.0:
			continue
		var t: float = e["entry_t"] / CHALLENGE_PATH_DURATION
		if t >= 1.0:
			# Se escapó: se va sin puntos.
			e["state"] = "removed"
			e["view"].visible = false
			continue
		var prev: Vector2 = e["pos"]
		e["pos"] = _spline(e["path"], t)
		e["view"].visible = true
		_face_motion(e, prev)
		e["view"].position = e["pos"]
		e["view"].set_phase(fmod(time_acc * 1.4 + e["wing_seed"], 1.0))
	_update_bullets(delta)
	_check_dive_collisions()
	_update_dual_fighter()
	if state == "playing" and not active:
		_finish_challenge()


func _finish_challenge() -> void:
	in_challenge = false
	state = "challenge_result"
	var perfect: bool = challenge_hits == challenge_total
	if perfect:
		score += CHALLENGE_PERFECT_BONUS
		AudioManager.play_win()
	_update_hud()
	status_label.text = ("¡PERFECTO! +%d" % CHALLENGE_PERFECT_BONUS) if perfect \
		else "Impactos: %d / %d" % [challenge_hits, challenge_total]
	await get_tree().create_timer(2.2).timeout
	if state != "challenge_result":
		return  # el jugador reinició mientras tanto
	state = "playing"
	_advance_level()


func _update_player(delta: float) -> void:
	if player_captured:
		return
	var vx := 0.0
	if pad.is_down:
		# Sigue al dedo, con velocidad máxima (como un joystick rápido).
		var target: float = pad.current_pos.x - PLAYER_SIZE.x / 2.0
		vx = clampf((target - player_x) / maxf(delta, 0.001), -PLAYER_SPEED * 1.8, PLAYER_SPEED * 1.8)
		_on_shoot_pressed()
	elif moving_left and not moving_right or Input.is_key_pressed(KEY_LEFT):
		vx = -PLAYER_SPEED
	elif moving_right and not moving_left or Input.is_key_pressed(KEY_RIGHT):
		vx = PLAYER_SPEED
	if Input.is_key_pressed(KEY_SPACE):
		_on_shoot_pressed()
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
		if (e["state"] == "diving" or e["state"] == "flyby") and not e.get("capture_dive", false) \
				and Rect2(e["pos"], ENEMY_SIZE).intersects(player_rect):
			_remove_enemy(e, false)
			_lose_life()
			return


func _remove_enemy(e: Dictionary, by_bullet: bool) -> void:
	if by_bullet and in_challenge:
		score += CHALLENGE_HIT_POINTS
		challenge_hits += 1
		_update_hud()
	elif by_bullet:
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
