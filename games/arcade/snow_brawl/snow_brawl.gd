extends Control
## Estilo Snow Bros: saltas entre plataformas, disparas bolas de
## nieve para congelar enemigos (3 golpes) y luego los empujas para
## que rueden y destruyan a los demás. Física real (gravedad +
## colisión con plataformas), consistente con Arkanoid. 10 niveles.

const GAME_ID := "snow_brawl"
const PLAY_W := 640.0
const PLAY_H := 880.0
const GRAVITY := 1400.0
const JUMP_VELOCITY := -740.0
const MOVE_SPEED := 220.0
const PLAYER_SIZE := Vector2(28, 40)
const ENEMY_SIZE := Vector2(26, 32)
# Tamaños visuales (EntitySprite): más redondeados/grandes que la caja de
# colisión de arriba. El sprite se ancla por los "pies" al fondo de la caja
# de colisión para que el salto/aterrizaje no cambien de sensación.
const PLAYER_VIEW_SIZE := Vector2(46, 46)
const ENEMY_VIEW_SIZE := Vector2(40, 40)
const PROJECTILE_VIEW_SIZE := Vector2(16, 16)
const SNOW_SPEED := 380.0
const SNOW_ARC_GRAVITY := 260.0  # el aliento de nieve cae un poco, no es una linea recta
const SNOW_RANGE := 320.0        # se disipa a esta distancia, no cruza toda la pantalla
const SNOW_COOLDOWN := 0.35
const FREEZE_HITS := 2
const SNOWBALL_SPEED := 320.0
const SNOWBALL_MAX_DIST := 460.0
const MAX_LEVEL := 10
const FREEZE_DURATION := 6.0  # si no pateas al enemigo a tiempo, se descongela
const AGGRO_RANGE := 160.0
const AGGRO_SPEED_MULT := 1.7
const MOVE_ACCEL := 1600.0  # aceleracion/frenado horizontal, ya no es un cambio instantaneo de velocidad
const LANDING_SQUASH := 0.22
const ENEMY_COLORS := [
	UIKit.COLOR_DANGER, Color(0.85, 0.47, 0.16), Color(0.56, 0.30, 0.78), Color(0.20, 0.55, 0.80),
]
const ITEM_DROP_CHANCE := 0.45
const ITEM_LIFETIME := 8.0
const ITEM_VIEW_SIZE := Vector2(28, 28)
const MAX_POWER_LEVEL := 2
## Las 4 pociones del Snow Bros original + premios. Duran hasta que pierdes
## una vida (salvo la verde, que es temporal):
##   roja = corres más rápido, azul = nieve más potente (congela con menos
##   golpes), amarilla = la nieve llega más lejos, verde = te inflas y eres
##   invencible unos segundos (aplastas a los enemigos al tocarlos).
const ITEM_WEIGHTS := {"fruit": 40, "potion_red": 14, "potion_blue": 14, "potion_yellow": 14, "potion_green": 9, "extra_life": 5}
const ITEM_ICON := {"fruit": "🍣", "potion_red": "🧪", "potion_blue": "🧪", "potion_yellow": "🧪", "potion_green": "🧪", "extra_life": "❤"}
const ITEM_COLOR := {
	"fruit": Color(0.95, 0.55, 0.35), "potion_red": Color(0.95, 0.2, 0.2), "potion_blue": Color(0.25, 0.45, 1.0),
	"potion_yellow": Color(1.0, 0.85, 0.15), "potion_green": Color(0.25, 0.85, 0.35), "extra_life": UIKit.COLOR_ACCENT,
}
const SPEED_POTION_MULT := 1.35
const RANGE_POTION_MULT := 1.6
const GREEN_DURATION := 8.0
const RESPAWN_INVULNERABLE := 2.5
## Puntos por enemigo derribado con la MISMA bola: se duplican en cadena.
const CHAIN_BASE_POINTS := 200
## Los enemigos saltan a la plataforma de arriba y se dejan caer por las
## orillas, como en el arcade (antes se quedaban en su plataforma).
const ENEMY_JUMP_VELOCITY := -700.0
const ENEMY_DROP_CHANCE := 0.35
const ENEMY_JUMP_COOLDOWN := 2.5
## Jefes en los niveles 5 y 10: no se congelan con nieve; hay que pegarles
## con bolas de nieve rodando, hechas con los enemigos que el jefe suelta.
const BOSS_LEVELS := [5, 10]
const BOSS_SIZE := Vector2(96, 104)
const BOSS_HP := {5: 5, 10: 8}
const BOSS_SPAWN_INTERVAL := 4.0
const BOSS_MAX_MINIONS := 3
const BOSS_POINTS := {5: 5000, 10: 10000}
## "¡Apúrate!": si tardas mucho, aparece un fantasma que no se puede
## congelar y te persigue atravesando plataformas.
const HURRY_TIME := 45.0
const HURRY_GHOST_SPEED := 70.0
const HURRY_GHOST_SIZE := Vector2(40, 40)

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

Derribar varios enemigos con la MISMA bola multiplica los puntos: 200, 400, 800, 1600...

Los enemigos derribados a veces sueltan premios: 🍣 puntos, ❤ vida extra y las pociones 🧪 del original — roja: corres más rápido; azul: tu nieve congela con menos golpes; amarilla: tu nieve llega más lejos; verde: te inflas y eres invencible unos segundos (aplastas a los enemigos al tocarlos). Las pociones se pierden al perder una vida.

Los enemigos saltan entre plataformas y se dejan caer por las orillas. Si tardas demasiado en un nivel, aparece un fantasma que no se puede congelar y te persigue: ¡apúrate!

En los niveles 5 y 10 hay un JEFE: la nieve no lo congela; congela a los enemigos que suelta y lánzaselos rodando para bajarle vida.

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
var speed_potion: bool = false
var range_potion: bool = false
var green_timer: float = 0.0
var invulnerable_timer: float = 0.0
var level_time: float = 0.0
var hurry_ghost: Dictionary = {}
var boss: Dictionary = {}

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
	restart_btn.text = "🔁  Nueva partida"
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
	speed_potion = false
	range_potion = false
	green_timer = 0.0
	invulnerable_timer = 0.0
	player_view.scale = Vector2.ONE
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
	_clear_boss()
	_clear_hurry_ghost()
	level_time = 0.0

	var is_boss_level: bool = level in BOSS_LEVELS
	var count: int = 2 if is_boss_level else min(2 + level, 10)
	for i in range(count):
		var plat: Rect2 = PLATFORMS[1 + (randi() % (PLATFORMS.size() - 1))]
		var pos := Vector2(plat.position.x + randf() * max(1.0, plat.size.x - ENEMY_SIZE.x), plat.position.y - ENEMY_SIZE.y)
		_spawn_enemy(pos, plat, i)
	if is_boss_level:
		_spawn_boss()

	status_label.text = "Nivel %d / %d%s" % [level, MAX_LEVEL, "  ·  ¡JEFE!" if is_boss_level else ""]
	status_label.remove_theme_color_override("font_color")
	_update_hud()


func _enemy_speed() -> float:
	return 60.0 + level * 6.0


func _spawn_enemy(pos: Vector2, plat: Rect2, i: int) -> Dictionary:
	var base_color: Color = ENEMY_COLORS[i % ENEMY_COLORS.size()]
	var view := EntitySprite.new()
	view.size = ENEMY_VIEW_SIZE
	view.position = _enemy_view_pos(pos)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("snow_enemy", base_color)
	play_area.add_child(view)
	var speed: float = _enemy_speed()
	var e := {
		"pos": pos, "platform": plat, "dir": (1 if randi() % 2 == 0 else -1),
		"speed": speed, "base_speed": speed, "state": "walking", "hits": 0, "vel": Vector2.ZERO,
		"start_x": 0.0, "view": view, "phase": fmod(float(i) * 0.31, 1.0), "base_color": base_color,
		"vy": 0.0, "airborne": false, "jump_cd": randf_range(1.0, ENEMY_JUMP_COOLDOWN), "chain": 0,
	}
	enemies.append(e)
	return e


func _spawn_boss() -> void:
	var view := EntitySprite.new()
	view.size = BOSS_SIZE * 1.15
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.pivot_offset = view.size / 2.0
	view.setup("snow_enemy", Color(0.55, 0.12, 0.2), Color(1.0, 0.8, 0.2))
	play_area.add_child(view)
	var hp: int = BOSS_HP.get(level, 6)
	var bar := ProgressBar.new()
	bar.max_value = hp
	bar.value = hp
	bar.show_percentage = false
	bar.size = Vector2(240, 12)
	bar.position = Vector2(PLAY_W / 2.0 - 120.0, 8.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UIKit.stylebox(Color(0.3, 0.05, 0.05), Color(0, 0, 0, 0), 5))
	bar.add_theme_stylebox_override("fill", UIKit.stylebox(UIKit.COLOR_DANGER, Color(0, 0, 0, 0), 5))
	play_area.add_child(bar)
	var pos := Vector2(PLAY_W - BOSS_SIZE.x - 40.0, PLATFORMS[0].position.y - BOSS_SIZE.y)
	boss = {"pos": pos, "vy": 0.0, "dir": -1, "hp": hp, "view": view, "bar": bar,
		"spawn_timer": 2.0, "hop_timer": 3.0, "hurt": 0.0, "phase": 0.0}


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "❤ %d%s" % [lives, _potion_text()]


func _sync_player_view() -> void:
	# Ancla el sprite (más grande/redondo que la caja de colisión) por los
	# pies al fondo de PLAYER_SIZE, para que el salto/aterrizaje no cambien.
	player_view.position = Vector2(
		player_pos.x + PLAYER_SIZE.x / 2.0 - PLAYER_VIEW_SIZE.x / 2.0,
		player_pos.y + PLAYER_SIZE.y - PLAYER_VIEW_SIZE.y
	)
	player_view.set_facing(0.0, facing < 0)
	player_view.set_phase(player_phase)


func _play_landing_squash() -> void:
	## Aplaste breve y no-bloqueante al aterrizar, para que el salto se
	## sienta con más peso/impacto en vez de solo detenerse en seco.
	var base: float = 1.35 if green_timer > 0.0 else 1.0  # inflado por la poción verde
	player_view.pivot_offset = player_view.size * Vector2(0.5, 1.0)
	player_view.scale = Vector2(1.0 + LANDING_SQUASH, 1.0 - LANDING_SQUASH) * base
	var tw := create_tween()
	tw.tween_property(player_view, "scale", Vector2.ONE * base, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	view.pivot_offset = view.size / 2.0
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("snowball", Color.WHITE)
	play_area.add_child(view)
	# Aliento de nieve: sale con un empujoncito hacia arriba y cae un poco
	# (SNOW_ARC_GRAVITY), en vez de viajar en línea recta perfecta — y se
	# disipa a los SNOW_RANGE px en vez de cruzar toda la pantalla.
	projectiles.append({
		"pos": pos, "vel": Vector2(facing * SNOW_SPEED, -70.0), "view": view, "start_pos": pos,
	})


func _process(delta: float) -> void:
	if state != "playing":
		return

	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta
	level_time += delta
	if green_timer > 0.0:
		green_timer -= delta
		if green_timer <= 0.0:
			player_view.scale = Vector2.ONE
			_update_hud()
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
	player_view.modulate.a = 0.45 if invulnerable_timer > 0.0 and int(invulnerable_timer * 10.0) % 2 == 0 else 1.0

	_update_player(delta)
	if state != "playing":
		return
	_update_enemies(delta)
	_update_boss(delta)
	_update_hurry_ghost(delta)
	_update_projectiles(delta)
	_update_items(delta)

	if state == "playing" and _all_enemies_cleared():
		_advance_level()


# --- Jefe -------------------------------------------------------------------
func _clear_boss() -> void:
	if boss.is_empty():
		return
	boss["view"].queue_free()
	boss["bar"].queue_free()
	boss = {}


func _update_boss(delta: float) -> void:
	if boss.is_empty():
		return
	var ground: float = PLATFORMS[0].position.y
	boss["phase"] = fmod(boss["phase"] + delta * 2.0, 1.0)
	boss["pos"].x += boss["dir"] * (70.0 + level * 4.0) * delta
	if boss["pos"].x < 10.0 or boss["pos"].x > PLAY_W - BOSS_SIZE.x - 10.0:
		boss["dir"] *= -1
		boss["pos"].x = clampf(boss["pos"].x, 10.0, PLAY_W - BOSS_SIZE.x - 10.0)
	# Da brincos pesados de vez en cuando.
	boss["hop_timer"] -= delta
	if boss["hop_timer"] <= 0.0 and boss["pos"].y >= ground - BOSS_SIZE.y - 0.5:
		boss["vy"] = -560.0
		boss["hop_timer"] = randf_range(2.5, 4.0)
	boss["vy"] += GRAVITY * delta
	boss["pos"].y = minf(boss["pos"].y + boss["vy"] * delta, ground - BOSS_SIZE.y)
	if boss["pos"].y >= ground - BOSS_SIZE.y:
		boss["vy"] = 0.0
	# Suelta enemigos (la "munición" para hacerle daño).
	boss["spawn_timer"] -= delta
	if boss["spawn_timer"] <= 0.0:
		boss["spawn_timer"] = BOSS_SPAWN_INTERVAL
		var alive := 0
		for e: Dictionary in enemies:
			if e["state"] == "walking" or e["state"] == "frozen":
				alive += 1
		if alive < BOSS_MAX_MINIONS:
			var m: Dictionary = _spawn_enemy(boss["pos"] + Vector2(BOSS_SIZE.x / 2.0 - ENEMY_SIZE.x / 2.0, 0), PLATFORMS[0], randi())
			m["airborne"] = true
			m["vy"] = -520.0
	if boss["hurt"] > 0.0:
		boss["hurt"] -= delta
	var v: EntitySprite = boss["view"]
	v.position = boss["pos"] + BOSS_SIZE / 2.0 - v.size / 2.0 + Vector2(0, -v.size.y * 0.06)
	v.set_facing(0.0, boss["dir"] < 0)
	v.set_phase(boss["phase"])
	v.modulate = Color(1, 0.5, 0.5) if boss["hurt"] > 0.0 else Color.WHITE
	if invulnerable_timer <= 0.0 and Rect2(player_pos, PLAYER_SIZE).intersects(_boss_rect().grow(-8.0)):
		_lose_life()


func _boss_rect() -> Rect2:
	return Rect2(boss["pos"], BOSS_SIZE)


func _hit_boss() -> void:
	boss["hp"] -= 1
	boss["hurt"] = 0.35
	boss["bar"].value = boss["hp"]
	_spawn_impact_burst(boss["pos"] + BOSS_SIZE / 2.0)
	AudioManager.play_alert()
	if boss["hp"] > 0:
		return
	score += BOSS_POINTS.get(level, 5000)
	_update_hud()
	_clear_boss()
	# Al caer el jefe, sus enemigos desaparecen con él.
	for e: Dictionary in enemies:
		if e["state"] != "removed":
			_spawn_impact_burst(e["pos"] + ENEMY_SIZE / 2.0)
			_remove_enemy(e)
	AudioManager.play_power()


# --- Fantasma de "¡Apúrate!" ------------------------------------------------
func _clear_hurry_ghost() -> void:
	if not hurry_ghost.is_empty():
		hurry_ghost["view"].queue_free()
	hurry_ghost = {}


func _update_hurry_ghost(delta: float) -> void:
	if hurry_ghost.is_empty():
		if level_time >= HURRY_TIME and boss.is_empty():
			var view := EntitySprite.new()
			view.size = HURRY_GHOST_SIZE
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.setup("ghost", Color(0.85, 0.85, 0.95), Color(0.5, 0.2, 0.7))
			play_area.add_child(view)
			hurry_ghost = {"pos": Vector2(PLAY_W / 2.0, -HURRY_GHOST_SIZE.y), "view": view, "phase": 0.0}
			status_label.text = "¡APÚRATE!"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			AudioManager.play_alert()
		return
	var target: Vector2 = player_pos + PLAYER_SIZE / 2.0 - HURRY_GHOST_SIZE / 2.0
	hurry_ghost["pos"] = hurry_ghost["pos"].move_toward(target, (HURRY_GHOST_SPEED + level * 4.0) * delta)
	hurry_ghost["phase"] = fmod(hurry_ghost["phase"] + delta, 1.0)
	hurry_ghost["view"].position = hurry_ghost["pos"]
	hurry_ghost["view"].set_phase(hurry_ghost["phase"])
	if invulnerable_timer <= 0.0 and green_timer <= 0.0 \
			and Rect2(player_pos, PLAYER_SIZE).intersects(Rect2(hurry_ghost["pos"], HURRY_GHOST_SIZE).grow(-8.0)):
		_lose_life()


func _update_player(delta: float) -> void:
	player_vel.y += GRAVITY * delta

	# Aceleración/frenado suave en vez de fijar la velocidad de golpe: se
	# siente menos rígido al arrancar y al parar.
	var target_vx := 0.0
	var speed: float = MOVE_SPEED * (SPEED_POTION_MULT if speed_potion else 1.0)
	if moving_left and not moving_right:
		target_vx = -speed
		facing = -1
	elif moving_right and not moving_left:
		target_vx = speed
		facing = 1
	player_vel.x = move_toward(player_vel.x, target_vx, MOVE_ACCEL * delta)

	if absf(player_vel.x) > 4.0:
		player_phase = fmod(player_phase + delta * 2.6, 1.0)

	var was_airborne: bool = not on_ground
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
				if was_airborne:
					_play_landing_squash()
				break

	_sync_player_view()

	if player_pos.y > PLAY_H:
		_lose_life()
		return

	var player_rect := Rect2(player_pos, PLAYER_SIZE)
	for e: Dictionary in enemies:
		if e["state"] == "walking" and player_rect.intersects(Rect2(e["pos"], ENEMY_SIZE)):
			if green_timer > 0.0:
				# Poción verde: inflado e invencible, aplasta al enemigo.
				_spawn_impact_burst(e["pos"] + ENEMY_SIZE / 2.0)
				_remove_enemy(e)
				score += 100
				_update_hud()
				continue
			if invulnerable_timer > 0.0:
				continue
			_lose_life()
			return
		if e["state"] == "frozen" and player_rect.intersects(Rect2(e["pos"], ENEMY_SIZE)) and player_vel.x != 0.0:
			_kick_snowball(e, sign(player_vel.x))


func _kick_snowball(e: Dictionary, dir: float) -> void:
	e["state"] = "rolling"
	e["vel"] = Vector2(SNOWBALL_SPEED * (1.0 if dir >= 0.0 else -1.0), 0.0)
	e["start_x"] = e["pos"].x
	e["chain"] = 0
	e["view"].setup("snowball", Color.WHITE)
	AudioManager.play_click()


func _update_enemies(delta: float) -> void:
	for e: Dictionary in enemies:
		match e["state"]:
			"walking":
				_update_walking_enemy(e, delta)
			"rolling":
				_update_rolling_enemy(e, delta)
			"frozen":
				if e["airborne"]:
					_enemy_air_step(e, delta)
					e["view"].position = _enemy_view_pos(e["pos"])
				e["frozen_timer"] -= delta
				if e["frozen_timer"] <= 0.0:
					_thaw_enemy(e)


func _thaw_enemy(e: Dictionary) -> void:
	## Si no lo pateas a tiempo, el enemigo congelado se descongela solo y
	## vuelve a caminar (y a ser peligroso), como en el Snow Bros original.
	e["state"] = "walking"
	e["hits"] = 0
	e["speed"] = e["base_speed"]
	e["view"].setup("snow_enemy", e["base_color"])


func _effective_freeze_hits() -> int:
	return max(1, FREEZE_HITS - power_level)


## Gravedad de un enemigo en el aire (saltando o cayendo de una orilla):
## aterriza en la primera plataforma que encuentre al bajar, igual que el
## jugador (se puede atravesar una plataforma desde abajo).
func _enemy_air_step(e: Dictionary, delta: float) -> void:
	var prev_bottom: float = e["pos"].y + ENEMY_SIZE.y
	e["vy"] += GRAVITY * delta
	e["pos"].y += e["vy"] * delta
	if e["vy"] < 0.0:
		return
	var new_bottom: float = e["pos"].y + ENEMY_SIZE.y
	for p: Rect2 in PLATFORMS:
		var within_x: bool = e["pos"].x + ENEMY_SIZE.x > p.position.x and e["pos"].x < p.position.x + p.size.x
		if within_x and prev_bottom <= p.position.y + 6.0 and new_bottom >= p.position.y:
			e["pos"].y = p.position.y - ENEMY_SIZE.y
			e["vy"] = 0.0
			e["airborne"] = false
			e["platform"] = p
			return


## Plataforma a la que el enemigo podría saltar desde la suya: justo
## arriba (a alcance de salto) y traslapada en x con su posición.
func _platform_above(e: Dictionary) -> bool:
	var plat: Rect2 = e["platform"]
	var cx: float = e["pos"].x + ENEMY_SIZE.x / 2.0
	for p: Rect2 in PLATFORMS:
		var dy: float = plat.position.y - p.position.y
		if dy > 60.0 and dy < 170.0 and cx > p.position.x + 10.0 and cx < p.position.x + p.size.x - 10.0:
			return true
	return false


func _update_walking_enemy(e: Dictionary, delta: float) -> void:
	if e["airborne"]:
		e["pos"].x = clampf(e["pos"].x + e["dir"] * e["speed"] * delta, 0.0, PLAY_W - ENEMY_SIZE.x)
		_enemy_air_step(e, delta)
		e["view"].position = _enemy_view_pos(e["pos"])
		return
	var plat: Rect2 = e["platform"]

	# Salta a la plataforma de arriba si el jugador está más arriba.
	e["jump_cd"] -= delta
	if e["jump_cd"] <= 0.0:
		e["jump_cd"] = ENEMY_JUMP_COOLDOWN
		var player_above: bool = player_pos.y + PLAYER_SIZE.y < plat.position.y - 30.0
		if player_above and _platform_above(e) and randf() < 0.6:
			e["airborne"] = true
			e["vy"] = ENEMY_JUMP_VELOCITY
			return

	# IA ligera: si el jugador está en la misma plataforma y cerca, el
	# enemigo se voltea hacia él y acelera, en vez de solo patrullar de
	# lado a lado ignorándolo por completo.
	var same_platform: bool = player_pos.y + PLAYER_SIZE.y > plat.position.y - 6.0 \
		and player_pos.y + PLAYER_SIZE.y < plat.position.y + 26.0
	var dx: float = (player_pos.x + PLAYER_SIZE.x / 2.0) - (e["pos"].x + ENEMY_SIZE.x / 2.0)
	var aggro: bool = same_platform and absf(dx) <= AGGRO_RANGE
	var speed_now: float = e["speed"] * (AGGRO_SPEED_MULT if aggro else 1.0)
	if aggro and absf(dx) > 2.0:
		e["dir"] = 1 if dx > 0.0 else -1

	e["pos"].x += e["dir"] * speed_now * delta
	var at_left: bool = e["pos"].x < plat.position.x
	var at_right: bool = e["pos"].x + ENEMY_SIZE.x > plat.position.x + plat.size.x
	if at_left or at_right:
		# En la orilla: a veces se deja caer a la plataforma de abajo (si no
		# es el piso ni el borde de la pantalla); si no, se da la vuelta.
		var can_drop: bool = plat != PLATFORMS[0] and e["pos"].x > 2.0 and e["pos"].x < PLAY_W - ENEMY_SIZE.x - 2.0
		if can_drop and randf() < ENEMY_DROP_CHANCE:
			e["airborne"] = true
			e["vy"] = 0.0
			# Totalmente fuera de la orilla: si queda traslapado, "aterriza"
			# otra vez en su propia plataforma al siguiente frame.
			e["pos"].x = plat.position.x - ENEMY_SIZE.x - 1.0 if at_left else plat.position.x + plat.size.x + 1.0
		elif at_left:
			e["pos"].x = plat.position.x
			e["dir"] = 1
		else:
			e["pos"].x = plat.position.x + plat.size.x - ENEMY_SIZE.x
			e["dir"] = -1
	e["phase"] = fmod(float(e["phase"]) + delta * (4.4 if aggro else 3.0), 1.0)
	e["view"].position = _enemy_view_pos(e["pos"])
	e["view"].set_facing(0.0, e["dir"] < 0)
	e["view"].set_phase(e["phase"])


func _update_rolling_enemy(e: Dictionary, delta: float) -> void:
	# La bola de nieve ya no se queda pegada a la altura de la plataforma
	# donde la pateaste: si se sale de la orilla, cae de verdad (gravedad
	# real) y sigue rodando en la plataforma de abajo — así puede llegar a
	# los enemigos de pisos inferiores, como en el Snow Bros original.
	e["vel"].y += GRAVITY * delta
	var prev_bottom: float = e["pos"].y + ENEMY_SIZE.y
	e["pos"] += e["vel"] * delta

	if e["vel"].y >= 0.0:
		var new_bottom: float = e["pos"].y + ENEMY_SIZE.y
		for p: Rect2 in PLATFORMS:
			var within_x: bool = e["pos"].x + ENEMY_SIZE.x > p.position.x and e["pos"].x < p.position.x + p.size.x
			if within_x and prev_bottom <= p.position.y + 6.0 and new_bottom >= p.position.y:
				e["pos"].y = p.position.y - ENEMY_SIZE.y
				e["vel"].y = 0.0
				break

	e["view"].position = _enemy_view_pos(e["pos"])

	if e["pos"].x < 0.0 or e["pos"].x + ENEMY_SIZE.x > PLAY_W or e["pos"].y > PLAY_H \
			or abs(e["pos"].x - e["start_x"]) > SNOWBALL_MAX_DIST:
		_remove_enemy(e)
		return

	var ball_rect := Rect2(e["pos"], ENEMY_SIZE)
	if not boss.is_empty() and ball_rect.intersects(_boss_rect()):
		# La bola revienta contra el jefe y le quita vida.
		_remove_enemy(e)
		_hit_boss()
		return
	for other: Dictionary in enemies:
		if is_same(other, e) or other["state"] == "removed" or other["state"] == "rolling":
			continue
		if ball_rect.intersects(Rect2(other["pos"], ENEMY_SIZE)):
			_spawn_impact_burst(other["pos"] + ENEMY_SIZE / 2.0)
			_remove_enemy(other)
			# Cadena: cada enemigo que tumba la MISMA bola vale el doble.
			score += CHAIN_BASE_POINTS * int(pow(2.0, mini(e["chain"], 5)))
			e["chain"] += 1
			_update_hud()
			if randf() < ITEM_DROP_CHANCE:
				_spawn_item(other["pos"] + ENEMY_SIZE / 2.0)


func _spawn_impact_burst(center: Vector2) -> void:
	## Destello breve y no-bloqueante al reventar un enemigo con la bola de
	## nieve, para que el golpe se sienta con más impacto que solo hacerlo
	## desaparecer en silencio.
	var flash := EntitySprite.new()
	var fsize: Vector2 = ENEMY_VIEW_SIZE * 1.5
	flash.size = fsize
	flash.position = center - fsize / 2.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.setup("blast", Color(1, 1, 1), UIKit.COLOR_ACCENT_2)
	play_area.add_child(flash)
	var tw := create_tween()
	tw.tween_method(flash.set_phase, 0.0, 1.0, 0.26)
	tw.tween_callback(flash.queue_free)


func _remove_enemy(e: Dictionary) -> void:
	e["state"] = "removed"
	e["view"].visible = false


func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p["vel"].y += SNOW_ARC_GRAVITY * delta
		p["pos"] += p["vel"] * delta
		p["view"].position = p["pos"] - Vector2(2.0, 2.0)

		var traveled: float = p["pos"].distance_to(p["start_pos"])
		var snow_range: float = SNOW_RANGE * (RANGE_POTION_MULT if range_potion else 1.0)
		var range_t: float = clamp(traveled / snow_range, 0.0, 1.0)
		p["view"].scale = Vector2.ONE * lerp(0.85, 1.5, range_t)
		p["view"].modulate.a = 1.0 - range_t * range_t

		if p["pos"].x < 0.0 or p["pos"].x > PLAY_W or traveled >= snow_range:
			p["view"].queue_free()
			projectiles.remove_at(i)
			continue

		var proj_rect := Rect2(p["pos"], Vector2(12, 12))
		var hit := false
		if not boss.is_empty() and proj_rect.intersects(_boss_rect()):
			# La nieve no congela al jefe: se deshace contra él.
			hit = true
		for e: Dictionary in enemies:
			if hit or e["state"] != "walking":
				continue
			if proj_rect.intersects(Rect2(e["pos"], ENEMY_SIZE)):
				e["hits"] += 1
				var needed: int = _effective_freeze_hits()
				var t: float = float(e["hits"]) / float(needed)
				# Cada golpe lo frena, no solo lo tiñe: se nota que se está
				# congelando de verdad, hasta casi detenerse justo antes de
				# quedar completamente congelado.
				e["speed"] = e["base_speed"] * clamp(1.0 - t * 0.85, 0.15, 1.0)
				if e["hits"] >= needed:
					e["state"] = "frozen"
					e["frozen_timer"] = FREEZE_DURATION
					e["view"].setup("snow_enemy", UIKit.COLOR_ACCENT_2)
				else:
					var frost: Color = e["base_color"].lerp(UIKit.COLOR_ACCENT_2, t * 0.75)
					e["view"].setup("snow_enemy", frost)
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
			score += 500
		"potion_red":
			speed_potion = true
		"potion_blue":
			power_level = min(power_level + 1, MAX_POWER_LEVEL)
		"potion_yellow":
			range_potion = true
		"potion_green":
			green_timer = GREEN_DURATION
			player_view.pivot_offset = player_view.size * Vector2(0.5, 1.0)
			player_view.scale = Vector2(1.35, 1.35)
		"extra_life":
			lives += 1
	AudioManager.play_place()
	_update_hud()


## Estado de pociones visible en el HUD (se pierden al perder una vida).
func _potion_text() -> String:
	var s := ""
	if speed_potion:
		s += " 🔴"
	if power_level > 0:
		s += " 🔵" + ("x2" if power_level > 1 else "")
	if range_potion:
		s += " 🟡"
	if green_timer > 0.0:
		s += " 🟢"
	return s


func _all_enemies_cleared() -> bool:
	if not boss.is_empty():
		return false  # en nivel de jefe, se pasa solo al derrotarlo
	for e: Dictionary in enemies:
		if e["state"] != "removed":
			return false
	return true


func _lose_life() -> void:
	lives -= 1
	# Como en el original, al morir pierdes todas tus pociones.
	power_level = 0
	speed_potion = false
	range_potion = false
	green_timer = 0.0
	player_view.scale = Vector2.ONE
	invulnerable_timer = RESPAWN_INVULNERABLE
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
