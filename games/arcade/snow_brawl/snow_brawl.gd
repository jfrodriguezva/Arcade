extends Control
## Guerra de Nieve, al estilo de Snow Bros (Toaplan, 1990). Eres Nick, un
## muñeco de nieve: disparas nieve a los monstruos y cada golpe los cubre
## un poco más (4 capas) hasta encerrarlos en una bola. Si caminas contra
## la bola la empujas; si disparas pegado a ella la pateas: rueda, rebota
## en las paredes, cae por los huecos entre pisos y arrolla a todos los
## monstruos que toca (cada uno vale el doble) hasta reventar abajo. Si una
## sola bola acaba con todos, llueven premios. Los monstruos que no
## terminas de cubrir se van descongelando.
##
## Como el original: 4 pociones (roja = velocidad, azul = nieve más
## potente, amarilla = más alcance, verde = te inflas, flotas y eres
## invencible), jefes en los niveles 5 y 10 (solo les hacen daño las bolas
## rodando), fantasma de "¡Apúrate!" si tardas, y 3 tipos de monstruo.
##
## Control táctil sin botones: arrastra a los lados para caminar, toca para
## disparar nieve y desliza hacia arriba para saltar. Teclado: flechas,
## Z / espacio = nieve, X / ↑ = saltar.

const GAME_ID := "snow_brawl"
const PLAY_W := 640.0
const PLAY_H := 880.0
const GRAVITY := 1650.0
const JUMP_VELOCITY := -770.0
const MOVE_SPEED := 210.0
const SPEED_POTION := 290.0
const PLAYER_SIZE := Vector2(34, 42)
const ENEMY_SIZE := Vector2(34, 34)
const SNOW_SPEED := 430.0
const SNOW_GRAVITY := 520.0
const SNOW_RANGE := 250.0
const SNOW_RANGE_POTION := 410.0
const SNOW_COOLDOWN := 0.22
const COVER_MAX := 4
const MELT_DELAY := 2.4
const MELT_STEP := 1.5
const BALL_ROLL_SPEED := 520.0
const PUSH_SPEED := 120.0
const CHAIN_POINTS := [500, 1000, 2000, 4000, 8000, 16000]
const GREEN_TIME := 8.0
const HURRY_TIME := 40.0
const MAX_LEVEL := 10
const BOSS_LEVELS := [5, 10]
const BOSS_SIZE := Vector2(110, 120)
const ITEM_KINDS := ["sushi", "roja", "azul", "amarilla", "verde"]
const ITEM_WEIGHTS := [44, 14, 16, 14, 8]
const ITEM_INFO := {
	"sushi": {"icon": "🍣", "color": Color(1.0, 0.6, 0.45)},
	"roja": {"icon": "🧪", "color": Color(0.95, 0.2, 0.2)},
	"azul": {"icon": "🧪", "color": Color(0.25, 0.45, 1.0)},
	"amarilla": {"icon": "🧪", "color": Color(1.0, 0.85, 0.15)},
	"verde": {"icon": "🧪", "color": Color(0.25, 0.85, 0.35)},
	"bolsa": {"icon": "💰", "color": Color(0.95, 0.75, 0.2)},
}
## Distribuciones de pisos (piso de abajo siempre completo). Los huecos
## entre plataformas dejan caer a las bolas rodando, como el original.
const LAYOUTS := [
	[[0, 690, 250, 22], [390, 690, 250, 22], [120, 530, 400, 22], [0, 370, 220, 22], [420, 370, 220, 22], [130, 210, 380, 22]],
	[[60, 700, 520, 22], [0, 540, 260, 22], [380, 540, 260, 22], [60, 380, 520, 22], [0, 220, 260, 22], [380, 220, 260, 22]],
	[[0, 700, 180, 22], [230, 700, 180, 22], [460, 700, 180, 22], [100, 540, 440, 22], [0, 380, 180, 22], [230, 380, 180, 22], [460, 380, 180, 22], [100, 220, 440, 22]],
	[[0, 690, 300, 22], [380, 610, 260, 22], [0, 520, 260, 22], [340, 440, 300, 22], [0, 350, 300, 22], [380, 270, 260, 22], [120, 190, 300, 22]],
	[[140, 700, 360, 22], [0, 560, 200, 22], [440, 560, 200, 22], [140, 420, 360, 22], [0, 280, 200, 22], [440, 280, 200, 22], [200, 170, 240, 22]],
]
const THEMES := [
	{"sky": [Color(0.08, 0.1, 0.3), Color(0.2, 0.3, 0.6)], "brick": Color(0.85, 0.45, 0.35)},
	{"sky": [Color(0.25, 0.05, 0.3), Color(0.6, 0.25, 0.5)], "brick": Color(0.45, 0.6, 0.9)},
	{"sky": [Color(0.05, 0.2, 0.2), Color(0.15, 0.5, 0.45)], "brick": Color(0.95, 0.75, 0.3)},
	{"sky": [Color(0.3, 0.12, 0.05), Color(0.75, 0.4, 0.2)], "brick": Color(0.55, 0.8, 0.5)},
	{"sky": [Color(0.05, 0.05, 0.12), Color(0.2, 0.2, 0.35)], "brick": Color(0.8, 0.55, 0.85)},
]

const HELP_TEXT := "Eres Nick, un muñeco de nieve. Se juega tocando el juego, sin botones:
- Arrastra el dedo a los lados para caminar.
- Toca para lanzar nieve.
- Desliza hacia arriba para saltar (también mientras caminas).
(Teclado: flechas, Z o espacio = nieve, X o ↑ = saltar.)

Cada bolazo de nieve cubre más al monstruo; a los 4 queda encerrado en una bola. Si no terminas, se descongela poco a poco.

Camina contra la bola para empujarla; dispárale estando pegado para PATEARLA: rueda, rebota en las paredes, cae por los huecos y arrolla a todos los monstruos que toca (500, 1000, 2000...). Si una sola bola acaba con todos, ¡llueven premios!

Pociones: 🔴 roja = velocidad · 🔵 azul = nieve más potente · 🟡 amarilla = más alcance · 🟢 verde = te inflas, flotas y eres invencible. Se pierden al perder una vida.

Monstruos: demonio rojo, rana saltarina y dragón que escupe fuego. En los niveles 5 y 10 hay jefe: solo le hacen daño las bolas rodando. Si tardas mucho, aparece un fantasma que no se puede congelar: ¡apúrate!"

var platforms: Array = []
var player_pos: Vector2 = Vector2.ZERO
var player_vel: Vector2 = Vector2.ZERO
var on_ground: bool = false
var facing: int = 1
var walk_dir: int = 0
var shoot_cd: float = 0.0
var anim_t: float = 0.0
var invuln: float = 0.0
var speed_potion: bool = false
var power_potion: bool = false
var range_potion: bool = false
var green_t: float = 0.0
var jumped_this_touch: bool = false

var enemies: Array = []    # {"kind","pos","vel","dir","cover","melt_t","ground","jump_cd","fire_cd","state"}
var balls: Array = []      # bolas sueltas o rodando: {"pos","vel","rolling","bounces","chain","enemy_kind","life"}
var shots: Array = []
var fires: Array = []
var items: Array = []
var effects: Array = []
var boss: Dictionary = {}
var ghost: Dictionary = {}
var level_time: float = 0.0
var pending_rain: bool = false

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var pad: GesturePad
var score_label: Label
var lives_label: Label
var status_label: Label


func _ready() -> void:
	AudioManager.play_music("aventura")
	_build_ui()
	_new_game()
	TouchHint.show_once(self, GAME_ID, [["↔", "Arrastra a los lados: camina."], ["👆", "Toca: lanza nieve. Pegado a una bola de nieve, la patea."], ["⬆", "Desliza hacia arriba: salta."]])


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

	var stat_panel := PanelContainer.new()
	stat_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 10, 1))
	vbox.add_child(stat_panel)
	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 26)
	stat_panel.add_child(hud)
	score_label = UIKit.title_label("", 15, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("", 15, UIKit.COLOR_ACCENT)
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

	pad = GesturePad.attach(play_area)
	pad.pressed.connect(func(_p: Vector2) -> void: jumped_this_touch = false)
	pad.tapped.connect(func(_p: Vector2) -> void: _shoot())
	pad.dragged.connect(func(_p: Vector2, from_start: Vector2, _s: Vector2) -> void:
		if from_start.y < -48.0 and absf(from_start.y) > absf(from_start.x) * 0.7 and not jumped_this_touch:
			jumped_this_touch = true
			_jump())
	pad.released.connect(func(_p: Vector2) -> void: walk_dir = 0)

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


# --------------------------------------------------------------- partida --
func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	_lose_potions()
	_setup_level()


func _lose_potions() -> void:
	speed_potion = false
	power_potion = false
	range_potion = false
	green_t = 0.0


func _setup_level() -> void:
	state = "playing"
	platforms = [Rect2(0, PLAY_H - 30.0, PLAY_W, 30.0)]
	for p: Array in LAYOUTS[(level - 1) % LAYOUTS.size()]:
		platforms.append(Rect2(p[0], p[1], p[2], p[3]))
	enemies.clear()
	balls.clear()
	shots.clear()
	fires.clear()
	items.clear()
	effects.clear()
	boss = {}
	ghost = {}
	level_time = 0.0
	pending_rain = false
	_respawn_player()
	var is_boss: bool = level in BOSS_LEVELS
	var count: int = 2 if is_boss else mini(3 + level / 2, 8)
	var upper: Array = platforms.slice(1)
	for i in range(count):
		var plat: Rect2 = upper[i % upper.size()]
		var kind := "demonio"
		var r: float = randf()
		if level >= 4 and r < 0.25:
			kind = "dragon"
		elif level >= 2 and r < 0.55:
			kind = "rana"
		_spawn_enemy(kind, Vector2(plat.position.x + randf() * (plat.size.x - ENEMY_SIZE.x), plat.position.y - ENEMY_SIZE.y))
	if is_boss:
		boss = {"pos": Vector2(PLAY_W - BOSS_SIZE.x - 30.0, PLAY_H - 30.0 - BOSS_SIZE.y), "vy": 0.0, "dir": -1,
			"hp": 6 if level == 5 else 10, "max_hp": 6 if level == 5 else 10, "spawn_t": 3.0, "hop_t": 2.5, "hurt": 0.0}
	status_label.text = "Nivel %d / %d%s" % [level, MAX_LEVEL, "  ·  ¡JEFE!" if is_boss else ""]
	status_label.remove_theme_color_override("font_color")
	_update_hud()


func _spawn_enemy(kind: String, pos: Vector2) -> Dictionary:
	var speed: float = 55.0 + level * 6.0
	var e := {"kind": kind, "pos": pos, "vel": Vector2.ZERO, "dir": [-1, 1].pick_random(), "speed": speed,
		"cover": 0, "melt_t": 0.0, "ground": false, "jump_cd": randf_range(1.0, 3.0), "fire_cd": 2.0, "alive": true}
	enemies.append(e)
	return e


func _respawn_player() -> void:
	player_pos = Vector2(PLAY_W / 2.0 - PLAYER_SIZE.x / 2.0, PLAY_H - 30.0 - PLAYER_SIZE.y)
	player_vel = Vector2.ZERO
	invuln = 2.0


func _update_hud() -> void:
	score_label.text = "★ %d" % score
	var pots := ""
	if speed_potion: pots += " 🔴"
	if power_potion: pots += " 🔵"
	if range_potion: pots += " 🟡"
	if green_t > 0.0: pots += " 🟢"
	lives_label.text = "♥ %d%s" % [lives, pots]


# ---------------------------------------------------------------- control --
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Z, KEY_SPACE: _shoot()
		KEY_X, KEY_UP: _jump()


func _jump() -> void:
	if state == "playing" and on_ground:
		AudioManager.play_jump()
		player_vel.y = JUMP_VELOCITY
		on_ground = false


func _shoot() -> void:
	if state != "playing" or shoot_cd > 0.0 or green_t > 0.0:
		return
	shoot_cd = SNOW_COOLDOWN
	var front := Rect2(player_pos + Vector2(PLAYER_SIZE.x if facing > 0 else -14.0, 4), Vector2(14, PLAYER_SIZE.y - 8))
	# Disparar pegado a una bola de nieve la PATEA (sale rodando).
	for b: Dictionary in balls:
		if not b["rolling"] and front.intersects(_ball_rect(b)):
			b["rolling"] = true
			b["vel"] = Vector2(BALL_ROLL_SPEED * facing, 0)
			b["chain"] = 0
			AudioManager.play_kick()
			return
	var start: Vector2 = player_pos + Vector2(PLAYER_SIZE.x / 2.0 + facing * 14.0, 14.0)
	shots.append({"pos": start, "start": start, "vel": Vector2(SNOW_SPEED * facing, -90.0)})
	AudioManager.play_pop()


# ------------------------------------------------------------------ bucle --
func _process(delta: float) -> void:
	anim_t += delta
	_update_effects(delta)
	play_area.queue_redraw()
	if state != "playing":
		return
	level_time += delta
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	if green_t > 0.0:
		green_t -= delta
		if green_t <= 0.0:
			_update_hud()
	_update_player(delta)
	_update_shots(delta)
	_update_enemies(delta)
	_update_balls(delta)
	_update_fires(delta)
	_update_items(delta)
	_update_boss(delta)
	_update_ghost(delta)
	if state == "playing" and _level_cleared():
		_level_clear()


func _land(pos: Vector2, size: Vector2, vy: float, prev_bottom: float) -> float:
	## Devuelve la Y donde aterriza (o -1 si no aterriza). Las plataformas
	## se atraviesan desde abajo, como en el original.
	if vy < 0.0:
		return -1.0
	var new_bottom: float = pos.y + size.y
	for p: Rect2 in platforms:
		if pos.x + size.x > p.position.x + 2.0 and pos.x < p.end.x - 2.0 and prev_bottom <= p.position.y + 6.0 and new_bottom >= p.position.y:
			return p.position.y - size.y
	return -1.0


func _update_player(delta: float) -> void:
	walk_dir = 0
	if pad.is_holding():
		var dx: float = pad.current_pos.x - pad.start_pos.x
		if absf(dx) > 18.0:
			walk_dir = 1 if dx > 0.0 else -1
	if Input.is_key_pressed(KEY_LEFT):
		walk_dir = -1
	elif Input.is_key_pressed(KEY_RIGHT):
		walk_dir = 1
	if walk_dir != 0:
		facing = walk_dir
	var spd: float = SPEED_POTION if speed_potion else MOVE_SPEED
	player_vel.x = walk_dir * spd
	var grav: float = GRAVITY * (0.25 if green_t > 0.0 else 1.0)
	player_vel.y = minf(player_vel.y + grav * delta, 900.0)
	if green_t > 0.0 and pad.is_holding():
		player_vel.y = minf(player_vel.y, -60.0 if pad.current_pos.y < player_pos.y else player_vel.y)
	var prev_bottom: float = player_pos.y + PLAYER_SIZE.y
	var np: Vector2 = player_pos + player_vel * delta
	np.x = clampf(np.x, 0.0, PLAY_W - PLAYER_SIZE.x)
	# Empujar una bola: caminar contra ella la mueve despacio (y Nick no
	# la atraviesa).
	for b: Dictionary in balls:
		if b["rolling"] or b.get("dead", false):
			continue
		var br: Rect2 = _ball_rect(b)
		if not Rect2(np, PLAYER_SIZE).intersects(br) or absf((np.y + PLAYER_SIZE.y) - br.end.y) > 20.0:
			continue
		if walk_dir != 0 and signf(br.get_center().x - (np.x + PLAYER_SIZE.x / 2.0)) == walk_dir:
			b["pos"].x = clampf(b["pos"].x + walk_dir * PUSH_SPEED * delta, 19.0, PLAY_W - 19.0)
			br = _ball_rect(b)
		if np.x + PLAYER_SIZE.x / 2.0 < br.get_center().x:
			np.x = minf(np.x, br.position.x - PLAYER_SIZE.x)
		else:
			np.x = maxf(np.x, br.end.x)
	player_pos = np
	on_ground = false
	var land: float = _land(player_pos, PLAYER_SIZE, player_vel.y, prev_bottom)
	if land >= 0.0:
		player_pos.y = land
		player_vel.y = 0.0
		on_ground = true
	if green_t > 0.0:
		player_pos.y = clampf(player_pos.y, 40.0, PLAY_H - 30.0 - PLAYER_SIZE.y)


func _update_shots(delta: float) -> void:
	var rng: float = SNOW_RANGE_POTION if range_potion else SNOW_RANGE
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		s["vel"].y += SNOW_GRAVITY * delta
		s["pos"] += s["vel"] * delta
		var done: bool = s["pos"].distance_to(s["start"]) > rng or s["pos"].x < 0.0 or s["pos"].x > PLAY_W
		for p: Rect2 in platforms:
			if p.has_point(s["pos"]):
				done = true
		if not done:
			for e: Dictionary in enemies:
				if e["alive"] and Rect2(e["pos"], ENEMY_SIZE).grow(4.0).has_point(s["pos"]):
					_cover_enemy(e)
					done = true
					break
		if not done and not boss.is_empty() and Rect2(boss["pos"], BOSS_SIZE).has_point(s["pos"]):
			done = true  # al jefe la nieve no le hace nada
		if done:
			effects.append({"kind": "puff", "pos": s["pos"], "t": 0.0})
			shots.remove_at(i)


## Cada bolazo cubre una capa más (dos con la poción azul); a las 4 el
## monstruo queda hecho bola.
func _cover_enemy(e: Dictionary) -> void:
	e["cover"] = mini(e["cover"] + (2 if power_potion else 1), COVER_MAX)
	e["melt_t"] = MELT_DELAY
	score += 10
	if e["cover"] >= COVER_MAX:
		e["alive"] = false
		balls.append({"pos": e["pos"] + ENEMY_SIZE / 2.0 + Vector2(0, -2), "vel": Vector2.ZERO, "rolling": false,
			"bounces": 0, "chain": 0, "kind": e["kind"], "life": 7.0, "pushed": false})
		AudioManager.play_place()
	_update_hud()


func _update_enemies(delta: float) -> void:
	for e: Dictionary in enemies:
		if not e["alive"]:
			continue
		# Se descongelan poco a poco si no los sigues cubriendo.
		if e["cover"] > 0:
			e["melt_t"] -= delta
			if e["melt_t"] <= 0.0:
				e["cover"] -= 1
				e["melt_t"] = MELT_STEP
		var speed_mult: float = [1.0, 0.45, 0.0, 0.0, 0.0][e["cover"]]
		e["vel"].y = minf(e["vel"].y + GRAVITY * delta, 900.0)
		if speed_mult > 0.0:
			_enemy_ai(e, delta)
			e["vel"].x = e["dir"] * e["speed"] * speed_mult * (1.6 if e["kind"] == "rana" and not e["ground"] else 1.0)
		else:
			e["vel"].x = 0.0
		var prev_bottom: float = e["pos"].y + ENEMY_SIZE.y
		e["pos"] += e["vel"] * delta
		if e["pos"].x < 0.0 or e["pos"].x > PLAY_W - ENEMY_SIZE.x:
			e["dir"] *= -1
			e["pos"].x = clampf(e["pos"].x, 0.0, PLAY_W - ENEMY_SIZE.x)
		var land: float = _land(e["pos"], ENEMY_SIZE, e["vel"].y, prev_bottom)
		e["ground"] = land >= 0.0
		if e["ground"]:
			e["pos"].y = land
			e["vel"].y = 0.0
		# Tocar a un monstruo que todavía se mueve (cubierto 0-1) mata.
		if e["cover"] <= 1 and Rect2(player_pos, PLAYER_SIZE).grow(-4.0).intersects(Rect2(e["pos"], ENEMY_SIZE).grow(-4.0)):
			if green_t > 0.0:
				_kill_enemy(e, e["pos"], 500)
			elif invuln <= 0.0:
				_lose_life()
				return


func _enemy_ai(e: Dictionary, delta: float) -> void:
	if not e["ground"]:
		return
	e["jump_cd"] -= delta
	var to_player: Vector2 = (player_pos + PLAYER_SIZE / 2.0) - (e["pos"] + ENEMY_SIZE / 2.0)
	var same_floor: bool = absf(to_player.y) < 30.0
	if same_floor and absf(to_player.x) < 200.0:
		e["dir"] = 1 if to_player.x > 0.0 else -1
	# Orilla: a veces se deja caer, si no se voltea.
	var ahead := Vector2(e["pos"].x + (ENEMY_SIZE.x + 4.0 if e["dir"] > 0 else -4.0), e["pos"].y + ENEMY_SIZE.y + 6.0)
	var floor_ahead := false
	for p: Rect2 in platforms:
		if p.has_point(ahead):
			floor_ahead = true
			break
	if not floor_ahead and randf() < 0.93:
		e["dir"] *= -1
	match e["kind"]:
		"rana":
			# Va a saltitos.
			if e["jump_cd"] <= 0.0:
				e["vel"].y = -520.0
				e["jump_cd"] = randf_range(0.6, 1.4)
		"dragon":
			e["fire_cd"] -= delta
			if same_floor and absf(to_player.x) < 280.0 and e["fire_cd"] <= 0.0:
				e["fire_cd"] = 2.6
				e["dir"] = 1 if to_player.x > 0.0 else -1
				fires.append({"pos": e["pos"] + Vector2(ENEMY_SIZE.x / 2.0 + e["dir"] * 18.0, 14.0), "vx": 250.0 * e["dir"], "life": 1.6})
		_:
			# Salta a la plataforma de arriba si estás más alto.
			if to_player.y < -60.0 and e["jump_cd"] <= 0.0:
				e["vel"].y = -760.0
				e["jump_cd"] = randf_range(1.5, 3.0)


func _ball_rect(b: Dictionary) -> Rect2:
	return Rect2(b["pos"] - Vector2(19, 19), Vector2(38, 38))


func _update_balls(delta: float) -> void:
	for b: Dictionary in balls:
		if b.get("dead", false):
			continue
		var prev_bottom: float = b["pos"].y + 19.0
		b["vel"].y = minf(b["vel"].y + GRAVITY * delta, 900.0)
		b["pos"] += b["vel"] * delta
		var land: float = _land(b["pos"] - Vector2(19, 19), Vector2(38, 38), b["vel"].y, prev_bottom)
		if land >= 0.0:
			b["pos"].y = land + 19.0
			b["vel"].y = 0.0
		if not b["rolling"]:
			# Si nadie la patea, el monstruo se libera (y sale medio cubierto).
			b["life"] -= delta
			if b["life"] <= 0.0:
				var e: Dictionary = _spawn_enemy(b["kind"], b["pos"] - ENEMY_SIZE / 2.0)
				e["cover"] = 2
				e["melt_t"] = MELT_STEP
				b["dead"] = true
			continue
		# Rodando: rebota en las paredes; en el piso de abajo revienta al
		# chocar con una pared.
		var on_bottom: bool = b["pos"].y > PLAY_H - 30.0 - 25.0
		if b["pos"].x < 19.0 or b["pos"].x > PLAY_W - 19.0:
			b["pos"].x = clampf(b["pos"].x, 19.0, PLAY_W - 19.0)
			b["vel"].x = -b["vel"].x
			b["bounces"] += 1
			AudioManager.play_click()
			if on_bottom or b["bounces"] >= 6:
				_shatter(b)
				continue
		var br: Rect2 = _ball_rect(b)
		for e: Dictionary in enemies:
			if e["alive"] and br.intersects(Rect2(e["pos"], ENEMY_SIZE)):
				_kill_enemy(e, e["pos"], CHAIN_POINTS[mini(b["chain"], CHAIN_POINTS.size() - 1)])
				b["chain"] += 1
		for o: Dictionary in balls:
			if not is_same(o, b) and not o.get("dead", false) and not o["rolling"] and br.intersects(_ball_rect(o)):
				_kill_enemy({"alive": true, "kind": o["kind"]}, o["pos"] - ENEMY_SIZE / 2.0, CHAIN_POINTS[mini(b["chain"], CHAIN_POINTS.size() - 1)])
				b["chain"] += 1
				o["dead"] = true
		if not boss.is_empty() and br.intersects(Rect2(boss["pos"], BOSS_SIZE)):
			_hit_boss()
			_shatter(b)
	balls = balls.filter(func(x: Dictionary) -> bool: return not x.get("dead", false))
	if _enemies_left() == 0 and pending_rain:
		pending_rain = false
		status_label.text = "¡Lluvia de premios!"
		for k in range(8):
			items.append({"kind": "bolsa", "pos": Vector2(60.0 + k * 75.0, -20.0 - k * 30.0), "vy": 0.0, "life": 8.0})


func _shatter(b: Dictionary) -> void:
	b["dead"] = true
	effects.append({"kind": "shatter", "pos": b["pos"], "t": 0.0})
	AudioManager.play_place()
	# Si esta bola tumbó a 2+ y ya no queda nadie: ¡lluvia de premios!
	if b["chain"] >= 2 and boss.is_empty():
		pending_rain = true


func _kill_enemy(e: Dictionary, pos: Vector2, points: int) -> void:
	AudioManager.vibrate(30)
	e["alive"] = false
	score += points
	effects.append({"kind": "pts", "pos": pos, "t": 0.0, "text": "%d" % points})
	effects.append({"kind": "shatter", "pos": pos + ENEMY_SIZE / 2.0, "t": 0.0})
	AudioManager.play_hit()
	if randf() < 0.5:
		var r: int = randi() % 100
		var acc := 0
		var kind: String = "sushi"
		for k in range(ITEM_KINDS.size()):
			acc += ITEM_WEIGHTS[k]
			if r < acc:
				kind = ITEM_KINDS[k]
				break
		items.append({"kind": kind, "pos": pos + ENEMY_SIZE / 2.0, "vy": -200.0, "life": 7.0})
	_update_hud()


func _update_fires(delta: float) -> void:
	var pr := Rect2(player_pos, PLAYER_SIZE).grow(-5.0)
	for i in range(fires.size() - 1, -1, -1):
		var f: Dictionary = fires[i]
		f["pos"].x += f["vx"] * delta
		f["life"] -= delta
		if pr.has_point(f["pos"]) and invuln <= 0.0 and green_t <= 0.0:
			fires.remove_at(i)
			_lose_life()
			return
		if f["life"] <= 0.0:
			fires.remove_at(i)


func _update_items(delta: float) -> void:
	var pr := Rect2(player_pos, PLAYER_SIZE).grow(6.0)
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		var prev_bottom: float = it["pos"].y + 12.0
		it["vy"] = minf(it["vy"] + GRAVITY * 0.7 * delta, 600.0)
		it["pos"].y += it["vy"] * delta
		var land: float = _land(it["pos"] - Vector2(12, 12), Vector2(24, 24), it["vy"], prev_bottom)
		if land >= 0.0:
			it["pos"].y = land + 12.0
			it["vy"] = 0.0
			it["life"] -= delta
		if pr.has_point(it["pos"]):
			_apply_item(it["kind"])
			items.remove_at(i)
		elif it["life"] <= 0.0:
			items.remove_at(i)


func _apply_item(kind: String) -> void:
	AudioManager.play_power()
	match kind:
		"sushi": score += 300
		"bolsa": score += 1000
		"roja": speed_potion = true
		"azul": power_potion = true
		"amarilla": range_potion = true
		"verde": green_t = GREEN_TIME
	_update_hud()


func _update_boss(delta: float) -> void:
	if boss.is_empty():
		return
	boss["hurt"] = maxf(boss["hurt"] - delta, 0.0)
	var ground_y: float = PLAY_H - 30.0 - BOSS_SIZE.y
	boss["pos"].x += boss["dir"] * (70.0 + level * 4.0) * delta
	if boss["pos"].x < 10.0 or boss["pos"].x > PLAY_W - BOSS_SIZE.x - 10.0:
		boss["dir"] *= -1
		boss["pos"].x = clampf(boss["pos"].x, 10.0, PLAY_W - BOSS_SIZE.x - 10.0)
	boss["hop_t"] -= delta
	if boss["hop_t"] <= 0.0 and boss["pos"].y >= ground_y - 1.0:
		boss["vy"] = -600.0
		boss["hop_t"] = randf_range(2.0, 3.5)
	boss["vy"] += GRAVITY * delta
	boss["pos"].y = minf(boss["pos"].y + boss["vy"] * delta, ground_y)
	if boss["pos"].y >= ground_y:
		boss["vy"] = 0.0
	boss["spawn_t"] -= delta
	if boss["spawn_t"] <= 0.0:
		boss["spawn_t"] = 3.5
		if _enemies_left() < 3:
			var m: Dictionary = _spawn_enemy("demonio", boss["pos"] + Vector2(BOSS_SIZE.x / 2.0, 0))
			m["vel"].y = -600.0
	if invuln <= 0.0 and green_t <= 0.0 and Rect2(player_pos, PLAYER_SIZE).grow(-6.0).intersects(Rect2(boss["pos"], BOSS_SIZE).grow(-12.0)):
		_lose_life()


func _hit_boss() -> void:
	boss["hp"] -= 1
	boss["hurt"] = 0.4
	AudioManager.play_alert()
	if boss["hp"] <= 0:
		score += 10000 if level == 10 else 5000
		effects.append({"kind": "shatter", "pos": boss["pos"] + BOSS_SIZE / 2.0, "t": 0.0})
		boss = {}
		for e: Dictionary in enemies:
			if e["alive"]:
				_kill_enemy(e, e["pos"], 200)
		_update_hud()


func _update_ghost(delta: float) -> void:
	if ghost.is_empty():
		if level_time >= HURRY_TIME and boss.is_empty():
			ghost = {"pos": Vector2(PLAY_W / 2.0, -40.0)}
			status_label.text = "¡APÚRATE!"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			AudioManager.play_alert()
		return
	ghost["pos"] = ghost["pos"].move_toward(player_pos + PLAYER_SIZE / 2.0, (75.0 + level * 4.0) * delta)
	if invuln <= 0.0 and green_t <= 0.0 and ghost["pos"].distance_to(player_pos + PLAYER_SIZE / 2.0) < 30.0:
		_lose_life()


func _enemies_left() -> int:
	var n := 0
	for e: Dictionary in enemies:
		if e["alive"]:
			n += 1
	return n + balls.size()


func _level_cleared() -> bool:
	return boss.is_empty() and _enemies_left() == 0


func _level_clear() -> void:
	state = "clear"
	status_label.text = "¡Piso superado!"
	AudioManager.play_win()
	await get_tree().create_timer(2.0).timeout
	if state != "clear":
		return
	if level >= MAX_LEVEL:
		state = "won"
		status_label.text = "¡Rescataste a las princesas! Puntos: %d" % score
		_record_result(true)
		return
	level += 1
	_setup_level()


func _lose_life() -> void:
	AudioManager.vibrate(200)
	lives -= 1
	_lose_potions()
	_update_hud()
	effects.append({"kind": "shatter", "pos": player_pos + PLAYER_SIZE / 2.0, "t": 0.0})
	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over. Puntos: %d" % score
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result(false)
		return
	AudioManager.play_error()
	_respawn_player()


func _record_result(won: bool) -> void:
	AudioManager.play_win() if won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)


func _update_effects(delta: float) -> void:
	for f: Dictionary in effects:
		f["t"] += delta
	effects = effects.filter(func(f: Dictionary) -> bool: return f["t"] < 0.6)


# ----------------------------------------------------------------- dibujo --
func _draw_play() -> void:
	var ca: Control = play_area
	var theme: Dictionary = THEMES[(level - 1) % THEMES.size()]
	for i in range(24):
		var t: float = i / 23.0
		var y0: float = floorf(i * PLAY_H / 24.0)
		ca.draw_rect(Rect2(0, y0, PLAY_W, floorf((i + 1) * PLAY_H / 24.0) - y0 + 1.0), theme["sky"][0].lerp(theme["sky"][1], t), true, -1.0, false)
	for k in range(30):
		var sx: float = fmod(k * 137.0, PLAY_W)
		var sy: float = fmod(k * 89.0 + anim_t * (8.0 + k % 5), PLAY_H)
		ca.draw_circle(Vector2(sx, sy), 1.5 + (k % 3) * 0.6, Color(1, 1, 1, 0.35))
	for p: Rect2 in platforms:
		_draw_bricks(p, theme["brick"])

	for it: Dictionary in items:
		if it["life"] < 2.0 and int(it["life"] * 8.0) % 2 == 0:
			continue
		var info: Dictionary = ITEM_INFO[it["kind"]]
		ca.draw_circle(it["pos"], 14.0, info["color"].darkened(0.3))
		ca.draw_circle(it["pos"], 11.0, info["color"])
		var f: Font = get_theme_default_font()
		var s: Vector2 = f.get_string_size(info["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		ca.draw_string(f, it["pos"] + Vector2(-s.x / 2.0, 6), info["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

	for e: Dictionary in enemies:
		if e["alive"]:
			_draw_enemy(e["kind"], e["pos"], ENEMY_SIZE, e["dir"], e["cover"])
	for b: Dictionary in balls:
		_draw_ball(b)
	if not boss.is_empty():
		_draw_enemy("jefe", boss["pos"], BOSS_SIZE, boss["dir"], 0, boss["hurt"] > 0.0)
		ca.draw_rect(Rect2(PLAY_W / 2.0 - 120.0, 10, 240, 12), Color(0.3, 0.05, 0.05))
		ca.draw_rect(Rect2(PLAY_W / 2.0 - 120.0, 10, 240.0 * boss["hp"] / boss["max_hp"], 12), UIKit.COLOR_DANGER)
	for s: Dictionary in shots:
		ca.draw_circle(s["pos"], 9.0 if power_potion else 7.0, Color(0.85, 0.93, 1.0))
		ca.draw_circle(s["pos"] - Vector2(2, 2), 3.0, Color(1, 1, 1))
	for f2: Dictionary in fires:
		ca.draw_circle(f2["pos"], 9.0, Color(1.0, 0.45, 0.1))
		ca.draw_circle(f2["pos"], 5.0, Color(1.0, 0.9, 0.3))
	if state in ["playing", "clear"] and (invuln <= 0.0 or int(invuln * 10.0) % 2 == 0):
		_draw_nick()
	if not ghost.is_empty():
		var g: Vector2 = ghost["pos"]
		ca.draw_circle(g, 20.0, Color(1.0, 0.55, 0.1))
		ca.draw_colored_polygon(PackedVector2Array([g + Vector2(-9, -4), g + Vector2(-3, -4), g + Vector2(-6, -10)]), Color(0.1, 0.05, 0))
		ca.draw_colored_polygon(PackedVector2Array([g + Vector2(3, -4), g + Vector2(9, -4), g + Vector2(6, -10)]), Color(0.1, 0.05, 0))
		ca.draw_rect(Rect2(g + Vector2(-10, 4), Vector2(20, 5)), Color(0.1, 0.05, 0))
		ca.draw_rect(Rect2(g + Vector2(-3, -26), Vector2(6, 8)), Color(0.3, 0.6, 0.2))
	var font: Font = get_theme_default_font()
	for fx: Dictionary in effects:
		var k: float = fx["t"] / 0.6
		match fx["kind"]:
			"puff":
				ca.draw_circle(fx["pos"], 6.0 + k * 10.0, Color(1, 1, 1, 0.6 * (1.0 - k)))
			"shatter":
				for a in range(8):
					var ang: float = a * TAU / 8.0
					ca.draw_circle(fx["pos"] + Vector2(cos(ang), sin(ang)) * k * 50.0, 5.0 * (1.0 - k), Color(0.9, 0.95, 1.0, 1.0 - k))
			"pts":
				ca.draw_string(font, fx["pos"] + Vector2(0, -k * 40.0), fx["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 0.6, 1.0 - k))


func _draw_bricks(p: Rect2, col: Color) -> void:
	var ca: Control = play_area
	ca.draw_rect(p, col.darkened(0.35))
	var row_h: float = 11.0
	var y: float = p.position.y
	var row := 0
	while y < p.end.y:
		var h: float = minf(row_h, p.end.y - y)
		var x: float = p.position.x - (12.0 if row % 2 == 1 else 0.0)
		while x < p.end.x:
			var bx: float = maxf(x, p.position.x)
			var bw: float = minf(x + 24.0, p.end.x) - bx
			if bw > 0.0:
				ca.draw_rect(Rect2(bx + 1, y + 1, bw - 2, h - 2), col)
				ca.draw_rect(Rect2(bx + 1, y + 1, bw - 2, 2), col.lightened(0.3))
			x += 24.0
		y += row_h
		row += 1


func _draw_nick() -> void:
	var ca: Control = play_area
	var c: Vector2 = player_pos + PLAYER_SIZE / 2.0
	var bob: float = sin(anim_t * 14.0) * 1.5 if walk_dir != 0 and on_ground else 0.0
	if green_t > 0.0:
		# Inflado como globo (poción verde).
		ca.draw_circle(c, 30.0, Color(0.6, 0.95, 0.6))
		ca.draw_circle(c - Vector2(9, 9), 8.0, Color(1, 1, 1, 0.6))
	# Cuerpo (dos bolas de nieve), gorro azul, bufanda roja y ojos.
	ca.draw_circle(c + Vector2(0, 9 + bob), 15.0, Color(0.95, 0.97, 1.0))
	ca.draw_circle(c + Vector2(0, -8 + bob), 11.0, Color(0.97, 0.98, 1.0))
	ca.draw_rect(Rect2(c + Vector2(-11, -21 + bob), Vector2(22, 7)), Color(0.15, 0.35, 0.95))
	ca.draw_circle(c + Vector2(facing * 6, -24 + bob), 4.0, Color(0.15, 0.35, 0.95))
	ca.draw_rect(Rect2(c + Vector2(-11, 1 + bob), Vector2(22, 4)), Color(0.9, 0.15, 0.2))
	ca.draw_circle(c + Vector2(facing * 4 - 3, -9 + bob), 2.2, Color(0.05, 0.05, 0.1))
	ca.draw_circle(c + Vector2(facing * 4 + 4, -9 + bob), 2.2, Color(0.05, 0.05, 0.1))
	ca.draw_colored_polygon(PackedVector2Array([c + Vector2(facing * 8, -6 + bob), c + Vector2(facing * 16, -4 + bob), c + Vector2(facing * 8, -3 + bob)]), Color(1.0, 0.5, 0.1))
	# Pies.
	var step: float = sin(anim_t * 14.0) * 4.0 if walk_dir != 0 and on_ground else 0.0
	ca.draw_rect(Rect2(c + Vector2(-11 + step, 20), Vector2(9, 5)), Color(0.15, 0.35, 0.95))
	ca.draw_rect(Rect2(c + Vector2(3 - step, 20), Vector2(9, 5)), Color(0.15, 0.35, 0.95))


func _draw_enemy(kind: String, pos: Vector2, size: Vector2, dir: int, cover: int, hurt: bool = false) -> void:
	var ca: Control = play_area
	var c: Vector2 = pos + size / 2.0
	var r: float = size.x * 0.48
	var body: Color = {"demonio": Color(0.9, 0.2, 0.2), "rana": Color(0.3, 0.75, 0.3), "dragon": Color(1.0, 0.55, 0.15), "jefe": Color(0.55, 0.12, 0.35)}[kind]
	if hurt:
		body = Color(1, 0.7, 0.7)
	var step: float = sin(anim_t * 12.0 + pos.x) * r * 0.15
	ca.draw_rect(Rect2(c + Vector2(-r * 0.7 + step, r * 0.7), Vector2(r * 0.5, r * 0.3)), body.darkened(0.4))
	ca.draw_rect(Rect2(c + Vector2(r * 0.2 - step, r * 0.7), Vector2(r * 0.5, r * 0.3)), body.darkened(0.4))
	ca.draw_circle(c, r, body)
	ca.draw_circle(c - Vector2(r * 0.3, r * 0.35), r * 0.25, body.lightened(0.3))
	match kind:
		"demonio", "jefe":
			for sx in [-1.0, 1.0]:
				ca.draw_colored_polygon(PackedVector2Array([c + Vector2(sx * r * 0.35, -r * 0.75), c + Vector2(sx * r * 0.75, -r * 1.25), c + Vector2(sx * r * 0.7, -r * 0.55)]), Color(1.0, 0.9, 0.6))
		"rana":
			for sx in [-1.0, 1.0]:
				ca.draw_circle(c + Vector2(sx * r * 0.45, -r * 0.8), r * 0.3, body)
		"dragon":
			ca.draw_rect(Rect2(c + Vector2(dir * r * 0.6 - r * 0.25, -r * 0.1), Vector2(r * 0.5, r * 0.4)), body.darkened(0.15))
	var eye_y: float = -r * (0.75 if kind == "rana" else 0.2)
	for sx in [-0.35, 0.35]:
		var e: Vector2 = c + Vector2(sx * r + dir * r * 0.15, eye_y)
		ca.draw_circle(e, r * 0.2, Color(1, 1, 1))
		ca.draw_circle(e + Vector2(dir * r * 0.07, 0), r * 0.1, Color(0, 0, 0))
	ca.draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.25), Vector2(r * 0.6, r * 0.12)), Color(0.2, 0, 0))
	# Capas de nieve: lo cubren de abajo hacia arriba.
	if cover > 0:
		var top: float = c.y + r - (2.0 * r) * (cover / float(COVER_MAX))
		var pts := PackedVector2Array()
		for i in range(13):
			var x: float = c.x - r * 1.05 + i * (2.1 * r / 12.0)
			pts.append(Vector2(x, top + sin(i * 1.7) * 4.0))
		pts.append(Vector2(c.x + r * 1.05, c.y + r + 2))
		pts.append(Vector2(c.x - r * 1.05, c.y + r + 2))
		ca.draw_colored_polygon(pts, Color(0.93, 0.96, 1.0))


func _draw_ball(b: Dictionary) -> void:
	var ca: Control = play_area
	var c: Vector2 = b["pos"]
	ca.draw_circle(c + Vector2(2, 3), 20.0, Color(0, 0, 0, 0.2))
	ca.draw_circle(c, 20.0, Color(0.88, 0.93, 1.0))
	ca.draw_circle(c - Vector2(6, 6), 7.0, Color(1, 1, 1))
	if b["rolling"]:
		var ang: float = c.x / 20.0
		for k in range(3):
			var a: float = ang + k * TAU / 3.0
			ca.draw_line(c + Vector2(cos(a), sin(a)) * 6.0, c + Vector2(cos(a), sin(a)) * 17.0, Color(0.6, 0.7, 0.85), 2.0)
	else:
		# Se asoman los cuernos/ojos del monstruo atrapado; tiembla antes de
		# liberarse.
		var shake: float = sin(anim_t * 40.0) * 2.0 if b["life"] < 2.0 else 0.0
		ca.draw_circle(c + Vector2(-6 + shake, -4), 3.0, Color(0.2, 0.2, 0.3))
		ca.draw_circle(c + Vector2(6 + shake, -4), 3.0, Color(0.2, 0.2, 0.3))
