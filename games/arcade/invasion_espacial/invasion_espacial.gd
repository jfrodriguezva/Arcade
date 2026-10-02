extends Control
## Invasión Espacial: port a Godot del juego original hecho en pygame
## (pyGame/Invasion). Mismas reglas, sprites, sonidos y música:
##
## - Nivel 1: lluvia de asteroides. Desde el 2 aparecen naves enemigas que
##   patrullan arriba disparando; desde el 4, planetas que al dispararles se
##   parten en dos asteroides; desde el 6, ovnis que bajan en zigzag
##   disparando; desde el 8, los asteroides se parten en meteoritos.
## - Lo que se te escapa por abajo te resta la mitad de sus puntos.
## - Cada 500 puntos ganados baja una vida extra (❤) que hay que atrapar, y
##   aparece el jefe del nivel: se despeja la pantalla, dejan de salir
##   enemigos y hay que bajarle la barra de vida. Cada jefe tiene más vida
##   (x1.1) y suma un ataque nuevo por nivel (diagonal, rebote, balas
##   anchas, balas largas, granadas, abanico y láser). Vencerlo sube de
##   nivel; al vencer al jefe del nivel 10 ganas.
## - Si algo te pega pierdes una vida y se limpia la pantalla (el jefe se
##   queda). La granada del jefe quita 2 vidas.
##
## Diferencias con el original, por la plataforma: pantalla vertical
## (680x880 en vez de 800x600, con velocidades escaladas para que los
## tiempos de cruce se sientan igual), controles táctiles ◀ 🔫 ▶ ⏸ además
## del teclado, disparo sostenido (en el original se disparaba una bala por
## tecla), 5 vidas en vez de las 300 de prueba que tenía config.py, y la
## música recomprimida a 96 kbps para no inflar la versión web.

const GAME_ID := "invasion_espacial"
const PLAY_W := 680.0
const PLAY_H := 880.0
const MAX_LEVEL := 10
const START_LIVES := 5
const A := "res://games/arcade/invasion_espacial/assets/"

# --- Escala respecto al original (800x600) ---------------------------------
const SPRITE_SCALE := 0.85  # sprites de 64 px -> 54 px
const BOSS_SIZE := 190.0     # los jefes de 256 px del original
const HX := 0.85 * 1000.0    # px/ms del original -> px/s, eje horizontal
const HY := 1.2 * 1000.0     # eje vertical: la pantalla es más alta

# --- Velocidades (valores de config.py convertidos) -------------------------
const VEL_NAVE := 0.3 * HX
const VEL_BALA := 0.6 * HY
const VEL_BALA_ENEMIGO := 0.4 * HY
const VEL_BALA_OVNI := 0.4 * HY
const VEL_BALA_JEFE := 0.2 * HY
const VEL_BALA_JEFE_H := 0.2 * HX
const VEL_BALA_JEFE_REBOTE := 0.1
const VEL_BALA_JEFE_DIAG := 0.5 * HY
const VEL_GRANADA := 0.15 * HY
const VEL_ENEMIGO := 0.25 * HX
const VEL_OVNI := 0.15
const VEL_JEFE := 0.3
const VEL_ASTEROIDE := 0.2 * HY
const VEL_PLANETA := 0.1 * HY
const VEL_AST_PLANETA_H := 0.2 * HX
const VEL_METEORO_H := 0.3 * HX
const VEL_VIDA := 0.2 * HY

# --- Puntajes (config.py) ---------------------------------------------------
const PUNTAJE_METEORO := 5
const PUNTAJE_ASTEROIDE := 100
const PUNTAJE_OVNI := 30
const PUNTAJE_ENEMIGO := 50
const PUNTAJE_PLANETA := 15
const PUNTAJE_JEFE := 15
const BONUS := 500
const VIDA_JEFE_DEFECTO := 500.0
const DANO_BALA_JEFE := 10.0
const LASER_WIDTH := 10.0
const AUTOFIRE_INTERVAL := 0.2

# --- Temporizadores (ms del original -> s) ----------------------------------
const TIMERS := {
	"spawn_ast": 1.0, "spawn_ene": 4.0, "spawn_ovni": 2.0, "spawn_planeta": 3.0,
	"disparo_ene": 1.2, "disparo_ovni": 1.0,
	"jefe_normal": 1.0, "jefe_rebote": 1.5, "jefe_diag": 2.0, "jefe_grande": 3.0,
	"jefe_ancho": 2.5, "jefe_abanico": 8.0, "jefe_laser": 7.0, "jefe_granada": 5.0,
}

const HELP_TEXT := "Pon el dedo sobre el juego y arrástralo: la nave lo sigue y dispara sola mientras lo mantengas abajo. Doble toque = pausa. (En teclado: flechas o A-D, espacio para disparar y P para pausa.)

- Nivel 1: lluvia de asteroides. Nivel 2: naves enemigas que disparan. Nivel 4: planetas que se parten en asteroides. Nivel 6: ovnis en zigzag. Nivel 8: los asteroides se parten en meteoritos.
- Lo que se escapa por abajo te resta la mitad de sus puntos.
- Cada 500 puntos baja una ❤ vida extra (atrápala) y aparece el JEFE del nivel. Bájale toda la barra de vida para subir de nivel. Cada jefe tiene más vida y un ataque nuevo: diagonales, rebote, balas anchas y largas, granadas (quitan 2 vidas), abanico y láser.
- Si te pegan pierdes una vida y se limpia la pantalla.

Vence al jefe del nivel 10 para ganar. Pierdes si se acaban tus vidas."

var tex: Dictionary = {}
var kof_font: FontFile
var music_player: AudioStreamPlayer
var sfx_players: Array = []
var sfx: Dictionary = {}

var play_area: Control
var score_label: Label
var lives_label: Label
var status_label: Label
var pad: GesturePad

var stars: PackedVector2Array = PackedVector2Array()
var timers: Dictionary = {}

# Estado de partida (mismo modelo que config.py).
var nave_x: float = 0.0
var nave_y: float = 0.0
var vidas: int = START_LIVES
var puntaje: int = 0
var puntaje_vida: int = 0  # puntos ganados (las penalidades no lo bajan)
var proximo_bonus: int = BONUS
var bonus_jefe: int = BONUS
var max_vida_jefe: float = VIDA_JEFE_DEFECTO
var vida_jefe: float = VIDA_JEFE_DEFECTO
var jefe_activo: bool = false
var nivel: int = 1
var state: String = "playing"  # playing / paused / game_over / won

var moving_left: bool = false
var moving_right: bool = false
var firing: bool = false
var fire_cooldown: float = 0.0
var flash_time: float = 0.0

# Cada entidad es un Dictionary {"pos": Vector2, "vel": Vector2, "tex": ...}.
var balas: Array = []
var balas_enemigas: Array = []  # todas las balas que dañan al jugador
var asteroides: Array = []
var enemigos: Array = []
var ovnis: Array = []
var planetas: Array = []
var ast_planeta: Array = []
var meteoros: Array = []
var lasers: Array = []
var vidas_extra: Array = []
var efectos: Array = []
var jefe: Dictionary = {}


func _ready() -> void:
	_load_assets()
	_build_ui()
	_new_game()


func _load_assets() -> void:
	for n: String in ["spaceship", "power", "blast", "heart", "asteroid", "asteroid_meteor", "asteroid_meteors",
			"enemy", "enemy_space", "enemy_spaceship", "alien", "alien_head", "alien_space", "alien_spaceship",
			"planet_earth", "planet_jupiter", "planet_mars", "planet_mercury", "planet_neptune", "planet_uranus",
			"planet_saturn", "planet_venus", "planet_asteroid", "planet_asteroids",
			"ship_bullet", "enemy_bullet", "alient_bullet", "boss_bullet", "boss_bullet_diag", "boss_bullet_reb",
			"boss_bullet_aba", "boss_bullet_grd", "boss_bullet_anc", "boss_granade",
			"boss_spaceship_ufo", "boss_alien", "boss_cthulhu", "boss_hydra", "boss_golem", "boss_gargoyle",
			"boss_dragon", "boss_ghost", "boss_evil", "boss_spaceship"]:
		tex[n] = load(A + "sprites/" + n + ".png")
	tex["fondo"] = load(A + "fondo.jpg")
	kof_font = load(A + "fuente/kof-94.ttf")

	# Volúmenes relativos del original (assets.py), escalados por el volumen
	# de efectos/música de la plataforma.
	for s: Array in [["disparo", 0.1], ["golpe", 0.3], ["impacto", 0.2], ["explosion", 0.5], ["vida", 0.3]]:
		sfx[s[0]] = {"stream": load(A + "sonidos/" + s[0] + ".mp3"), "vol": s[1]}
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	music_player = AudioStreamPlayer.new()
	var music: AudioStreamMP3 = load(A + "sonidos/musica_fondo.mp3")
	music.loop = true
	music_player.stream = music
	add_child(music_player)


func _play_sfx(name: String) -> void:
	var vol: float = float(SettingsManager.get_value("sfx_volume", 0.8)) * float(sfx[name]["vol"]) * 2.0
	if vol <= 0.0:
		return
	var p: AudioStreamPlayer = sfx_players[0]
	for cand: AudioStreamPlayer in sfx_players:
		if not cand.playing:
			p = cand
			break
	p.stream = sfx[name]["stream"]
	p.volume_db = linear_to_db(clampf(vol, 0.01, 1.0))
	p.play()


func _start_music() -> void:
	var vol: float = float(SettingsManager.get_value("music_volume", 0.8)) * 0.25
	if vol <= 0.0:
		music_player.stop()
		return
	music_player.volume_db = linear_to_db(clampf(vol, 0.01, 1.0))
	if not music_player.playing:
		music_player.play()


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

	UIKit.build_toolbar(vbox, self, "Invasión Espacial", HELP_TEXT)

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
	lives_label = UIKit.title_label("♥ %d" % START_LIVES, 15, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(play_panel)

	# Todo el juego se dibuja en un solo _draw (ver _draw_play) en vez de un
	# nodo por bala/enemigo: el jefe llega a llenar la pantalla de balas.
	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_area.draw.connect(_draw_play)
	play_panel.add_child(play_area)

	# Control táctil sin botones: la nave sigue al dedo y dispara sola
	# mientras lo mantienes sobre el juego; doble toque = pausa.
	pad = GesturePad.attach(play_area)
	pad.double_tapped.connect(func(_p: Vector2) -> void: _toggle_pause())

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)

	for i in 120:
		stars.append(Vector2(randf() * PLAY_W, randf() * PLAY_H))


## _input (no _unhandled_input): así la barra espaciadora se atiende antes
## de que la UI la use para "presionar" el botón que tenga el foco (Volver).
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			firing = event.pressed
			if event.pressed:
				fire_cooldown = 0.0
		KEY_P:
			if event.pressed:
				_toggle_pause()
		_:
			return
	get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if state == "playing":
		state = "paused"
		music_player.stream_paused = true
	elif state == "paused":
		state = "playing"
		music_player.stream_paused = false
	play_area.queue_redraw()


# ---------------------------------------------------------------- partida --
func _new_game() -> void:
	vidas = START_LIVES
	puntaje = 0
	puntaje_vida = 0
	proximo_bonus = BONUS
	bonus_jefe = BONUS
	max_vida_jefe = VIDA_JEFE_DEFECTO
	vida_jefe = max_vida_jefe
	nivel = 1
	jefe_activo = false
	jefe = {}
	state = "playing"
	nave_x = PLAY_W / 2.0 - _size("spaceship").x / 2.0
	nave_y = PLAY_H - _size("spaceship").y - 10.0
	for k: String in TIMERS:
		timers[k] = TIMERS[k]
	_reinicio_parcial()
	status_label.remove_theme_color_override("font_color")
	_update_hud()
	music_player.stream_paused = false
	_start_music()


## util.reinicio_parcial: limpia balas, enemigos y vidas que van cayendo
## (el jefe NO se va).
func _reinicio_parcial() -> void:
	for arr: Array in [balas, balas_enemigas, asteroides, enemigos, ovnis, planetas, ast_planeta, meteoros, lasers, vidas_extra]:
		arr.clear()


func _update_hud() -> void:
	score_label.text = "★ %d" % puntaje
	lives_label.text = "♥ %d" % vidas
	if state == "playing" or state == "paused":
		status_label.text = "Nivel %d / %d%s" % [nivel, MAX_LEVEL, "  ·  JEFE" if jefe_activo else ""]


func _size(name: String) -> Vector2:
	if name.begins_with("boss_") and not name.begins_with("boss_bullet") and name != "boss_granade":
		return Vector2(BOSS_SIZE, BOSS_SIZE) if name != "boss_spaceship" else Vector2(64, 64) * SPRITE_SCALE * 1.3
	return tex[name].get_size() * SPRITE_SCALE


func _add(arr: Array, name: String, pos: Vector2, vel: Vector2, extra: Dictionary = {}) -> Dictionary:
	var e := {"tex": name, "pos": pos, "vel": vel, "size": _size(name)}
	e.merge(extra)
	arr.append(e)
	return e


## Hitbox algo más chica que el sprite: los íconos traen margen transparente
## y en el original (rect de la imagen completa) se sentían choques "de
## lejos".
func _hitbox(e: Dictionary, shrink: float = 0.8) -> Rect2:
	var s: Vector2 = e["size"]
	return Rect2(e["pos"] + s * (1.0 - shrink) / 2.0, s * shrink)


func _nave_rect() -> Rect2:
	var s: Vector2 = _size("spaceship")
	return Rect2(Vector2(nave_x, nave_y) + s * 0.18, s * 0.64)


# ------------------------------------------------------------------ bucle --
func _process(delta: float) -> void:
	if flash_time > 0.0:
		flash_time -= delta
	_update_effects(delta)
	if state == "playing":
		_step(delta)
	play_area.queue_redraw()


func _step(delta: float) -> void:
	_mover_jugador(delta)
	_tick_timers(delta)
	_invocar_jefe()
	_mover_todo(delta)
	_colision_balas()
	_colision_jugador()
	_update_hud()


func _mover_jugador(delta: float) -> void:
	var left: bool = moving_left or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var right: bool = moving_right or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	if pad.is_down:
		var target: float = pad.current_pos.x - _size("spaceship").x / 2.0
		nave_x += clampf(target - nave_x, -VEL_NAVE * 1.8 * delta, VEL_NAVE * 1.8 * delta)
	elif left and not right:
		nave_x -= VEL_NAVE * delta
	elif right and not left:
		nave_x += VEL_NAVE * delta
	nave_x = clampf(nave_x, 0.0, PLAY_W - _size("spaceship").x)
	fire_cooldown -= delta
	if (firing or pad.is_down) and fire_cooldown <= 0.0:
		fire_cooldown = AUTOFIRE_INTERVAL
		var bs: Vector2 = _size("ship_bullet")
		_add(balas, "ship_bullet", Vector2(nave_x + _size("spaceship").x / 2.0 - bs.x / 2.0, nave_y - bs.y * 0.5), Vector2(0, -VEL_BALA))
		_play_sfx("disparo")


## Equivalente a los PG.time.set_timer del original: cada evento se dispara
## cada N segundos y hace lo mismo que su rama en manejar_eventos().
func _tick_timers(delta: float) -> void:
	for k: String in timers:
		timers[k] -= delta
		if timers[k] > 0.0:
			continue
		timers[k] += TIMERS[k]
		_on_timer(k)


func _on_timer(k: String) -> void:
	if not jefe_activo:
		match k:
			"spawn_ast":
				var s: Vector2 = _size("asteroid")
				_add(asteroides, "asteroid", Vector2(randf() * (PLAY_W - s.x), -s.y), Vector2(0, VEL_ASTEROIDE))
			"spawn_ene":
				if nivel >= 2:
					var n: String = ["enemy", "enemy_space", "enemy_spaceship"].pick_random()
					var s: Vector2 = _size(n)
					_add(enemigos, n, Vector2(randf() * (PLAY_W - s.x), randf_range(25.0, 130.0)), Vector2([-1.0, 1.0].pick_random() * VEL_ENEMIGO, 0))
			"spawn_planeta":
				if nivel >= 4:
					var n: String = ["planet_earth", "planet_jupiter", "planet_mars", "planet_mercury", "planet_neptune", "planet_uranus", "planet_saturn", "planet_venus"].pick_random()
					var s: Vector2 = _size(n)
					_add(planetas, n, Vector2(randf() * (PLAY_W - s.x), -s.y), Vector2(0, VEL_PLANETA))
			"spawn_ovni":
				if nivel >= 6:
					var n: String = ["alien", "alien_head", "alien_space", "alien_spaceship"].pick_random()
					var s: Vector2 = _size(n)
					_add(ovnis, n, Vector2(randf() * (PLAY_W - s.x), -s.y), Vector2([-1.0, 1.0].pick_random() * VEL_OVNI * HX, VEL_OVNI * 0.7 * HY))
			"disparo_ene":
				for e: Dictionary in enemigos:
					_disparo_enemigo(e, "enemy_bullet", Vector2(0, VEL_BALA_ENEMIGO))
			"disparo_ovni":
				for e: Dictionary in ovnis:
					_disparo_enemigo(e, "alient_bullet", Vector2(0, VEL_BALA_OVNI))
		return

	# Ataques del jefe: cada uno se desbloquea en un nivel, como en el original.
	if jefe.is_empty():
		return
	var jp: Vector2 = jefe["pos"]
	var js: Vector2 = jefe["size"]
	var bottom_c := Vector2(jp.x + js.x / 2.0, jp.y + js.y * 0.85)
	match k:
		"jefe_normal":
			_boss_shot("boss_bullet", bottom_c, Vector2(0, VEL_BALA_JEFE))
		"jefe_diag":
			if nivel >= 2:
				_boss_shot("boss_bullet_diag", Vector2(jp.x + js.x * 0.1, jp.y + js.y * 0.7), Vector2(-VEL_BALA_JEFE_H, VEL_BALA_JEFE_DIAG))
				if nivel >= 3:
					_boss_shot("boss_bullet_diag", Vector2(jp.x + js.x * 0.9, jp.y + js.y * 0.7), Vector2(VEL_BALA_JEFE_H, VEL_BALA_JEFE_DIAG))
		"jefe_rebote":
			if nivel >= 4:
				_boss_shot("boss_bullet_reb", bottom_c, Vector2(VEL_BALA_JEFE_REBOTE * HX, VEL_BALA_JEFE_REBOTE * HY), {"bounce": true})
		"jefe_ancho":
			if nivel >= 5:
				_boss_shot("boss_bullet_anc", bottom_c, Vector2(0, VEL_BALA_JEFE))
		"jefe_grande":
			if nivel >= 6:
				_boss_shot("boss_bullet_grd", bottom_c, Vector2(0, VEL_BALA_JEFE))
		"jefe_granada":
			if nivel >= 7:
				_boss_shot("boss_granade", bottom_c, Vector2([-1.0, 1.0].pick_random() * 0.15 * HX, VEL_GRANADA), {"damage": 2})
		"jefe_abanico":
			if nivel >= 8:
				for dxx in [-2, -1, 0, 1, 2]:
					_boss_shot("boss_bullet_aba", bottom_c, Vector2(dxx * 0.4 * HX, 0.4 * HY))
		"jefe_laser":
			if nivel >= 9:
				lasers.append({"x": bottom_c.x - LASER_WIDTH / 2.0, "y": bottom_c.y})


func _disparo_enemigo(e: Dictionary, name: String, vel: Vector2) -> void:
	var bs: Vector2 = _size(name)
	var s: Vector2 = e["size"]
	_add(balas_enemigas, name, e["pos"] + Vector2(s.x / 2.0 - bs.x / 2.0, s.y * 0.8), vel)


func _boss_shot(name: String, center: Vector2, vel: Vector2, extra: Dictionary = {}) -> void:
	var bs: Vector2 = _size(name)
	_add(balas_enemigas, name, center - Vector2(bs.x / 2.0, 0), vel, extra)


## funciones.invocar_jefe: al juntar suficientes puntos aparece el jefe del
## nivel, se limpia la pantalla y dejan de salir enemigos.
func _invocar_jefe() -> void:
	if jefe_activo or puntaje_vida < bonus_jefe:
		return
	var names := ["boss_spaceship_ufo", "boss_alien", "boss_cthulhu", "boss_hydra", "boss_golem",
		"boss_gargoyle", "boss_dragon", "boss_ghost", "boss_evil", "boss_spaceship"]
	var n: String = names[clampi(nivel - 1, 0, names.size() - 1)]
	var s: Vector2 = _size(n)
	jefe = {"tex": n, "pos": Vector2(PLAY_W / 2.0 - s.x / 2.0, 40.0), "size": s, "dir": Vector2(1, 0), "change": 2.0}
	jefe_activo = true
	_reinicio_parcial()
	bonus_jefe += BONUS
	vida_jefe = max_vida_jefe
	AudioManager.play_alert()


func _mover_todo(delta: float) -> void:
	for arr: Array in [balas, balas_enemigas, asteroides, enemigos, ovnis, planetas, ast_planeta, meteoros, vidas_extra]:
		for e: Dictionary in arr:
			e["pos"] += e["vel"] * delta

	# Rebotes horizontales en los bordes (enemigos, ovnis, fragmentos).
	for arr: Array in [enemigos, ovnis, ast_planeta, meteoros]:
		for e: Dictionary in arr:
			var p: Vector2 = e["pos"]
			var w: float = e["size"].x
			if (p.x <= 0.0 and e["vel"].x < 0.0) or (p.x >= PLAY_W - w and e["vel"].x > 0.0):
				e["vel"].x *= -1.0
	for b: Dictionary in balas_enemigas:
		if b.get("bounce", false) and ((b["pos"].x <= 0.0 and b["vel"].x < 0.0) or (b["pos"].x >= PLAY_W - b["size"].x and b["vel"].x > 0.0)):
			b["vel"].x *= -1.0

	# Lo que se escapa por abajo resta la mitad de sus puntos (y suena golpe).
	_escapes(asteroides, PUNTAJE_ASTEROIDE)
	_escapes(ovnis, PUNTAJE_OVNI)
	_escapes(planetas, PUNTAJE_PLANETA)
	_escapes(ast_planeta, PUNTAJE_ASTEROIDE)
	_escapes(meteoros, PUNTAJE_METEORO)
	_cull(balas, func(e: Dictionary) -> bool: return e["pos"].y < -e["size"].y)
	_cull(balas_enemigas, func(e: Dictionary) -> bool: return e["pos"].y > PLAY_H or e["pos"].x < -40.0 or e["pos"].x > PLAY_W + 40.0)
	_cull(vidas_extra, func(e: Dictionary) -> bool: return e["pos"].y > PLAY_H)

	for l: Dictionary in lasers:
		l["y"] += VEL_BALA_JEFE * delta
	_cull(lasers, func(l: Dictionary) -> bool: return l["y"] > PLAY_H)

	_mover_jefe(delta)


func _escapes(arr: Array, puntos: int) -> void:
	for i in range(arr.size() - 1, -1, -1):
		if arr[i]["pos"].y > PLAY_H:
			arr.remove_at(i)
			_play_sfx("golpe")
			puntaje = maxi(0, int(puntaje - puntos / 2.0))


func _cull(arr: Array, pred: Callable) -> void:
	for i in range(arr.size() - 1, -1, -1):
		if pred.call(arr[i]):
			arr.remove_at(i)


## movimientos.mover_jefe: cambia de dirección al azar cada 1-3 s y rebota
## en los bordes, sin bajar de la mitad de la pantalla.
func _mover_jefe(delta: float) -> void:
	if jefe.is_empty():
		return
	jefe["change"] -= delta
	if jefe["change"] <= 0.0:
		var d := Vector2(randi_range(-1, 1), randi_range(-1, 1))
		if d == Vector2.ZERO:
			d.x = [-1.0, 1.0].pick_random()
		jefe["dir"] = d
		jefe["change"] = randf_range(1.0, 3.0)
	var p: Vector2 = jefe["pos"] + jefe["dir"] * Vector2(VEL_JEFE * HX, VEL_JEFE * HY) * delta
	var s: Vector2 = jefe["size"]
	if p.x <= 0.0 or p.x >= PLAY_W - s.x:
		jefe["dir"].x *= -1.0
		p.x = clampf(p.x, 0.0, PLAY_W - s.x)
	if p.y <= 0.0 or p.y >= PLAY_H / 2.0 - s.y * 0.3:
		jefe["dir"].y *= -1.0
		p.y = clampf(p.y, 0.0, PLAY_H / 2.0 - s.y * 0.3)
	jefe["pos"] = p


# ------------------------------------------------------------- colisiones --
## colisiones.colision_balas: cada bala del jugador pega en lo primero que
## toque, en el mismo orden de prioridad del original.
func _colision_balas() -> void:
	for i in range(balas.size() - 1, -1, -1):
		if i >= balas.size():
			continue  # vencer al jefe limpia todas las balas a media vuelta
		var br := Rect2(balas[i]["pos"] + balas[i]["size"] * Vector2(0.35, 0.1), balas[i]["size"] * Vector2(0.3, 0.8))
		var hit := false
		for grupo_name: String in ["planetas", "ast_planeta", "meteoros", "asteroides", "enemigos", "ovnis"]:
			var grupo: Array = get(grupo_name)
			for j in range(grupo.size()):
				var obj: Dictionary = grupo[j]
				if not br.intersects(_hitbox(obj, 0.85)):
					continue
				_play_sfx("impacto")
				_efecto(obj["pos"] + obj["size"] / 2.0, "blast")
				grupo.remove_at(j)
				_on_destroyed(grupo_name, obj)
				hit = true
				break
			if hit:
				break
		if not hit and not jefe.is_empty() and br.intersects(_hitbox(jefe, 0.7)):
			hit = true
			_play_sfx("impacto")
			_efecto(balas[i]["pos"], "blast", 0.5)
			vida_jefe -= DANO_BALA_JEFE
			if vida_jefe <= 0.0:
				_jefe_derrotado()
		if hit and i < balas.size():
			balas.remove_at(i)


## Se identifica el grupo por NOMBRE: comparar arreglos con == compara su
## contenido, y dos grupos vacíos resultaban "iguales" (un asteroide se
## trataba como planeta y soltaba fragmentos).
func _on_destroyed(grupo: String, obj: Dictionary) -> void:
	var puntos := 0
	var center: Vector2 = obj["pos"] + obj["size"] / 2.0
	if grupo == "planetas":
		puntos = PUNTAJE_PLANETA
		# El planeta se parte en dos asteroides que salen en diagonal.
		var n: String = ["planet_asteroid", "planet_asteroids"].pick_random()
		var s: Vector2 = _size(n)
		for d in [-1.0, 1.0]:
			_add(ast_planeta, n, center - s / 2.0, Vector2(d * VEL_AST_PLANETA_H, VEL_ASTEROIDE))
	elif grupo == "ast_planeta" or grupo == "asteroides":
		puntos = PUNTAJE_ASTEROIDE
	elif grupo == "meteoros":
		puntos = PUNTAJE_METEORO
	elif grupo == "enemigos":
		puntos = PUNTAJE_ENEMIGO
	elif grupo == "ovnis":
		puntos = PUNTAJE_OVNI
	# Desde el nivel 8, los asteroides se parten en meteoritos.
	if nivel >= 8 and (grupo == "asteroides" or grupo == "ast_planeta"):
		var m: String = ["asteroid_meteor", "asteroid_meteors"].pick_random()
		var ms: Vector2 = _size(m)
		for d in [-1.0, 1.0]:
			_add(meteoros, m, center - ms / 2.0, Vector2(d * VEL_METEORO_H, VEL_ASTEROIDE))
	_sumar(puntos)


func _sumar(puntos: int) -> void:
	puntaje += puntos
	puntaje_vida += puntos
	if puntaje_vida >= proximo_bonus:
		var s: Vector2 = _size("heart")
		_add(vidas_extra, "heart", Vector2(randf_range(20.0, PLAY_W - s.x - 20.0), -s.y), Vector2(0, VEL_VIDA))
		proximo_bonus += BONUS


func _jefe_derrotado() -> void:
	_efecto(jefe["pos"] + jefe["size"] / 2.0, "power", 3.0)
	_play_sfx("explosion")
	jefe = {}
	jefe_activo = false
	nivel += 1
	max_vida_jefe *= 1.1
	vida_jefe = max_vida_jefe
	_reinicio_parcial()
	_sumar(PUNTAJE_JEFE)
	if nivel > MAX_LEVEL:
		nivel = MAX_LEVEL
		_end(true)
	else:
		AudioManager.play_power()


func _colision_jugador() -> void:
	var nr: Rect2 = _nave_rect()
	for i in range(balas_enemigas.size() - 1, -1, -1):
		var b: Dictionary = balas_enemigas[i]
		if nr.intersects(_hitbox(b, 0.7)):
			balas_enemigas.remove_at(i)
			_golpe_jugador(int(b.get("damage", 1)))
			return
	for l: Dictionary in lasers:
		if nr.intersects(Rect2(l["x"], l["y"], LASER_WIDTH, PLAY_H - l["y"])):
			_golpe_jugador(1)
			return
	for grupo: Array in [asteroides, planetas, ast_planeta, meteoros, enemigos, ovnis]:
		for j in range(grupo.size()):
			if nr.intersects(_hitbox(grupo[j], 0.75)):
				grupo.remove_at(j)
				_golpe_jugador(1)
				return
	for i in range(vidas_extra.size() - 1, -1, -1):
		if nr.intersects(_hitbox(vidas_extra[i], 0.9)):
			vidas_extra.remove_at(i)
			vidas += 1
			_play_sfx("vida")


func _golpe_jugador(dano: int) -> void:
	_play_sfx("explosion")
	vidas -= dano
	flash_time = 0.25
	_efecto(Vector2(nave_x, nave_y) + _size("spaceship") / 2.0, "blast", 1.5)
	if vidas <= 0:
		vidas = 0
		_end(false)
	else:
		_reinicio_parcial()
	_update_hud()


func _end(won: bool) -> void:
	state = "won" if won else "game_over"
	firing = false
	music_player.stop()
	if won:
		status_label.text = "¡VICTORIA FINAL! Puntos: %d" % puntaje
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	else:
		status_label.text = "GAME OVER · Nivel %d · Puntos: %d" % [nivel, puntaje]
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
	AudioManager.play_win() if won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), puntaje)
	SaveManager.set_game_data(GAME_ID, stats)


func _efecto(center: Vector2, name: String, scale_mult: float = 1.0) -> void:
	efectos.append({"tex": name, "center": center, "t": 0.0, "dur": 0.22, "scale": scale_mult})


func _update_effects(delta: float) -> void:
	for i in range(efectos.size() - 1, -1, -1):
		efectos[i]["t"] += delta
		if efectos[i]["t"] >= efectos[i]["dur"]:
			efectos.remove_at(i)


# ----------------------------------------------------------------- dibujo --
func _draw_play() -> void:
	var ca: Control = play_area
	ca.draw_texture_rect(tex["fondo"], Rect2(Vector2.ZERO, Vector2(PLAY_W, PLAY_H)), false)
	for s: Vector2 in stars:
		ca.draw_rect(Rect2(s, Vector2(1.5, 1.5)), Color(0.78, 0.78, 0.78))

	if not jefe.is_empty():
		ca.draw_texture_rect(tex[jefe["tex"]], Rect2(jefe["pos"], jefe["size"]), false)
	for arr: Array in [asteroides, planetas, ast_planeta, meteoros, enemigos, ovnis, vidas_extra, balas, balas_enemigas]:
		for e: Dictionary in arr:
			ca.draw_texture_rect(tex[e["tex"]], Rect2(e["pos"], e["size"]), false)
	for l: Dictionary in lasers:
		ca.draw_rect(Rect2(l["x"], l["y"], LASER_WIDTH, PLAY_H - l["y"]), Color(0.0, 0.78, 1.0))
		ca.draw_rect(Rect2(l["x"] + LASER_WIDTH * 0.3, l["y"], LASER_WIDTH * 0.4, PLAY_H - l["y"]), Color(0.85, 0.97, 1.0))

	if state != "game_over":
		ca.draw_texture_rect(tex["spaceship"], Rect2(Vector2(nave_x, nave_y), _size("spaceship")), false)

	for fx: Dictionary in efectos:
		var t: Texture2D = tex[fx["tex"]]
		var sz: Vector2 = t.get_size() * fx["scale"] * (1.0 + fx["t"] / fx["dur"] * 0.5)
		ca.draw_texture_rect(t, Rect2(fx["center"] - sz / 2.0, sz), false, Color(1, 1, 1, 1.0 - fx["t"] / fx["dur"]))

	# Barra de vida del jefe (rojo = vida perdida, verde = restante).
	if not jefe.is_empty():
		var bw := 240.0
		var bx: float = PLAY_W / 2.0 - bw / 2.0
		ca.draw_rect(Rect2(bx, 10, bw, 16), Color(1, 0, 0))
		ca.draw_rect(Rect2(bx, 10, bw * clampf(vida_jefe / max_vida_jefe, 0.0, 1.0), 16), Color(0, 1, 0))

	if flash_time > 0.0:
		ca.draw_rect(Rect2(Vector2.ZERO, Vector2(PLAY_W, PLAY_H)), Color(1, 0, 0, 0.45 * flash_time / 0.25))

	match state:
		"paused":
			_center_text("PAUSA", PLAY_H / 2.0, Color(1, 1, 0), 40)
		"game_over":
			ca.draw_rect(Rect2(Vector2.ZERO, Vector2(PLAY_W, PLAY_H)), Color(0.39, 0.39, 0.39, 0.45))
			_center_text("GAME OVER", PLAY_H / 2.0 - 30.0, Color(1, 0, 0), 44)
			_center_text("Nivel: %d - Puntaje: %d" % [nivel, puntaje], PLAY_H / 2.0 + 20.0, Color(1, 1, 0), 22)
		"won":
			ca.draw_rect(Rect2(Vector2.ZERO, Vector2(PLAY_W, PLAY_H)), Color(0.39, 0.39, 0.39, 0.45))
			_center_text("VICTORIA FINAL", PLAY_H / 2.0 - 30.0, Color(1, 1, 1), 40)
			_center_text("Puntaje: %d" % puntaje, PLAY_H / 2.0 + 20.0, Color(1, 1, 0), 22)


func _center_text(text: String, y: float, color: Color, size: int) -> void:
	var w: float = kof_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	play_area.draw_string_outline(kof_font, Vector2(PLAY_W / 2.0 - w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.8))
	play_area.draw_string(kof_font, Vector2(PLAY_W / 2.0 - w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
