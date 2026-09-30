extends Control
## Arkanoid/rompe-ladrillos, fiel al arcade de Taito. Arrastra para mover
## la paleta; la física de rebote (paredes, paleta con ángulo según punto
## de impacto, ladrillos) es manual, sin motor de físicas.
##
## Del original: niveles con dibujo propio de 13 columnas, ladrillos de
## color con su puntaje (blanco 50 ... amarillo 120), plateados que aguantan
## varios golpes y dorados indestructibles; las 7 cápsulas (S, C, E, D, L,
## B, P) con sus colores y un solo poder a la vez; enemigos flotantes que
## bajan por las compuertas; la bola que se acelera con los golpes; y Doh,
## el jefe final, en el nivel 10.

const GAME_ID := "arkanoid"
const PLAY_W := 680.0
const PLAY_H := 1000.0
const PADDLE_W := 110.0
const PADDLE_H := 18.0
const PADDLE_Y := PLAY_H - 44.0
const BALL_SIZE := 14.0
const BALL_VISUAL_SIZE := BALL_SIZE * 1.18
const COLS := 13
const BRICK_GAP := 3.0
const BRICK_H := 26.0
const BRICK_TOP := 70.0
const BASE_BALL_SPEED := 400.0
const SPEED_PER_LEVEL := 14.0
const SPEEDUP_PER_HIT := 3.0     # la bola se acelera poco a poco con cada golpe
const MAX_SPEED_BONUS := 170.0
const MAX_BOUNCE_ANGLE := 1.05   # radianes desde la vertical
const MAX_LEVEL := 10

## Colores y puntos del arcade. '.' vacío, 'S' plateado, 'D' dorado.
const BRICK_TYPES := {
	"W": {"color": Color(0.95, 0.95, 0.95), "points": 50},
	"O": {"color": Color(1.0, 0.56, 0.1), "points": 60},
	"C": {"color": Color(0.1, 0.9, 0.95), "points": 70},
	"G": {"color": Color(0.2, 0.85, 0.25), "points": 80},
	"R": {"color": Color(0.95, 0.15, 0.15), "points": 90},
	"B": {"color": Color(0.2, 0.35, 1.0), "points": 100},
	"P": {"color": Color(1.0, 0.3, 0.8), "points": 110},
	"Y": {"color": Color(1.0, 0.92, 0.15), "points": 120},
	"S": {"color": Color(0.72, 0.74, 0.78), "points": 50},
	"D": {"color": Color(0.85, 0.66, 0.15), "points": 0},
}
## Dibujos de los niveles 1-9 (13 columnas), inspirados en las rondas del
## original. El nivel 10 es Doh.
const LAYOUTS := [
	[
		".............",
		"SSSSSSSSSSSSS",
		"RRRRRRRRRRRRR",
		"YYYYYYYYYYYYY",
		"BBBBBBBBBBBBB",
		"PPPPPPPPPPPPP",
		"GGGGGGGGGGGGG",
	],
	[
		"W............",
		"WO...........",
		"WOC..........",
		"WOCG.........",
		"WOCGR........",
		"WOCGRB.......",
		"WOCGRBP......",
		"WOCGRBPY.....",
		"WOCGRBPYW....",
		"WOCGRBPYWO...",
		"WOCGRBPYWOC..",
		"WOCGRBPYWOCG.",
		"SSSSSSSSSSSSR",
	],
	[
		"GGGGGGGGGGGGG",
		".............",
		"WWWDDDDDDDDDD",
		".............",
		"RRRRRRRRRRRRR",
		".............",
		"DDDDDDDDDDWWW",
		".............",
		"PPPPPPPPPPPPP",
		".............",
		"BBBDDDDDDDDDD",
		".............",
		"CCCCCCCCCCCCC",
	],
	[
		".O.C.G.R.B.P.",
		".O.C.G.R.B.P.",
		".O.C.G.R.B.P.",
		".O.C.G.R.B.P.",
		".S.S.S.S.S.S.",
		".O.C.G.R.B.P.",
		".O.C.G.R.B.P.",
		".O.C.G.R.B.P.",
		".O.C.G.R.B.P.",
	],
	[
		"...Y.....Y...",
		"....Y...Y....",
		"...SSSSSSS...",
		"..SSRSSSRSS..",
		".SSSSSSSSSSS.",
		".S.SSSSSSS.S.",
		".S.S.....S.S.",
		"....SS.SS....",
		".............",
		"...GGGGGGG...",
	],
	[
		"......R......",
		".....ROR.....",
		"....ROYOR....",
		"...ROYGYOR...",
		"..ROYGCGYOR..",
		".ROYGCBCGYOR.",
		"..ROYGCGYOR..",
		"...ROYGYOR...",
		"....ROYOR....",
		".....ROR.....",
		"......R......",
	],
	[
		"B.P.B.P.B.P.B",
		".C.G.C.G.C.G.",
		"R.Y.R.Y.R.Y.R",
		".S.S.S.S.S.S.",
		"O.W.O.W.O.W.O",
		".B.P.B.P.B.P.",
		"G.C.G.C.G.C.G",
	],
	[
		"DDDDDDDDDDDDD",
		"D...........D",
		"D.YYYYYYYYY.D",
		"D.Y.......Y.D",
		"D.Y.PPPPP.Y.D",
		"D.Y.P...P.Y.D",
		"D.Y.PCCCP.Y.D",
		"D...........D",
		"DDDDD...DDDDD",
	],
	[
		"SSSSSSSSSSSSS",
		"D.....D.....D",
		"D.RRR.D.BBB.D",
		"D.RRR.D.BBB.D",
		"D.....D.....D",
		"DDD.DDDDD.DDD",
		"D.....D.....D",
		"D.GGG.D.YYY.D",
		"D.GGG.D.YYY.D",
		"D.....D.....D",
		"SSSSSSSSSSSSS",
	],
]

const CAPSULE_DROP_CHANCE := 0.16
const CAPSULE_SIZE := Vector2(40, 18)
const CAPSULE_FALL_SPEED := 150.0
const LASER_COOLDOWN := 0.35
const PADDLE_EXPAND_MULT := 1.6
const SLOW_SPEED := 300.0
const CATCH_AUTO_RELEASE := 3.0
const BREAK_BONUS := 10000
## Las 7 cápsulas del arcade con sus colores: S lenta (naranja), C atrapar
## (verde), E ensanchar (azul), D disrupción = 3 bolas (cian), L láser
## (rojo), B "break" = salida al siguiente nivel (rosa) y P vida (gris).
const CAPSULE_WEIGHTS := {"S": 20, "C": 16, "E": 20, "D": 18, "L": 16, "B": 4, "P": 6}
const CAPSULE_COLOR := {
	"S": Color(1.0, 0.55, 0.1), "C": Color(0.2, 0.8, 0.25), "E": Color(0.25, 0.4, 1.0),
	"D": Color(0.1, 0.85, 0.95), "L": Color(0.95, 0.15, 0.15), "B": Color(1.0, 0.35, 0.85),
	"P": Color(0.6, 0.62, 0.66),
}

## Enemigos flotantes ("moléculas") que bajan por las compuertas de arriba
## desde el nivel 2: rebotan la bola, y chocar la paleta con ellos los
## destruye. 100 puntos.
const ENEMY_MIN_LEVEL := 2
const ENEMY_INTERVAL := 7.0
const ENEMY_MAX := 3
const ENEMY_SIZE := Vector2(30, 30)
const ENEMY_POINTS := 100
const GATES_X := [PLAY_W * 0.25, PLAY_W * 0.75]

## Doh (nivel 10): cara gigante que aguanta 16 golpes y dispara.
const DOH_HP := 16
const DOH_RECT := Rect2(PLAY_W / 2.0 - 110.0, 90.0, 220.0, 260.0)
const DOH_SHOT_INTERVAL := 2.2
const DOH_SHOT_SPEED := 230.0
const DOH_POINTS := 50000

const HELP_TEXT := "Arrastra el dedo (o el mouse) sobre el área de juego para mover la paleta. Toca para lanzar la bola.

Rompe todos los ladrillos sin dejar caer la bola; el punto donde golpea la paleta cambia el ángulo. La bola se acelera poco a poco con cada golpe.

Ladrillos: cada color vale distinto (blanco 50, naranja 60, cian 70, verde 80, rojo 90, azul 100, rosa 110, amarillo 120). Los PLATEADOS aguantan varios golpes; los DORADOS no se rompen (no hace falta romperlos para pasar).

Cápsulas (solo tienes un poder a la vez):
S (naranja) bola lenta · C (verde) la paleta atrapa la bola: toca para soltarla · E (azul) paleta más ancha · D (cian) tres bolas · L (rojo) láser · B (rosa) se abre una salida a la derecha: lleva la paleta ahí para pasar de nivel (+10 000) · P (gris) vida extra.

Desde el nivel 2 bajan enemigos flotantes: rebotan la bola y la paleta los destruye al tocarlos.

En el nivel 10 te espera DOH: pégale 16 veces y esquiva sus disparos.

Pierdes una vida si TODAS tus bolas caen. Tienes 3 vidas."

var balls: Array = []  # {"pos","vel","view","stuck","stuck_offset","stuck_time"}
var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "ready"  # ready | playing | game_over | won
var bricks: Array = []
var speed_bonus: float = 0.0

var paddle_w: float = PADDLE_W
var capsules: Array = []
var laser_bolts: Array = []
var power: String = ""  # poder activo: "", "C", "E", "L" (S y D son instantáneos)
var slow_active: bool = false
var laser_fire_cooldown: float = 0.0
var break_open: bool = false
var enemies: Array = []
var enemy_timer: float = 0.0
var doh: Dictionary = {}
var doh_shots: Array = []

var play_area: Control
var fx_layer: Control
var paddle: EntitySprite
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
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Arkanoid", HELP_TEXT)

	var hud_panel := PanelContainer.new()
	hud_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, Color(0, 0, 0, 0), 10))
	vbox.add_child(hud_panel)

	var hud_margin := MarginContainer.new()
	hud_margin.add_theme_constant_override("margin_left", 14)
	hud_margin.add_theme_constant_override("margin_right", 14)
	hud_margin.add_theme_constant_override("margin_top", 6)
	hud_margin.add_theme_constant_override("margin_bottom", 6)
	hud_panel.add_child(hud_margin)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 24)
	hud_margin.add_child(hud)
	score_label = UIKit.title_label("Puntos: 0      Nivel: 1/%d" % MAX_LEVEL, 14, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("Vidas: 3", 14, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)

	status_label = UIKit.title_label("", 13, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0.04, 0.05, 0.12), UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_STOP
	play_area.gui_input.connect(_on_play_area_input)
	play_panel.add_child(play_area)

	# Capa de dibujo para lo que no es un nodo: compuertas, salida "B",
	# Doh, sus disparos y los enemigos flotantes.
	fx_layer = Control.new()
	fx_layer.size = Vector2(PLAY_W, PLAY_H)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.draw.connect(_draw_fx)
	play_area.add_child(fx_layer)

	paddle = EntitySprite.new()
	paddle.size = Vector2(paddle_w, PADDLE_H)
	paddle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paddle.setup("paddle", Color(0.75, 0.78, 0.85), Color(0.95, 0.2, 0.2))
	play_area.add_child(paddle)

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(220, 52)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void:
		UIKit.pulse(restart_btn)
		_new_game()
	)
	vbox.add_child(restart_btn)


func _ball_speed() -> float:
	if slow_active:
		return SLOW_SPEED
	return BASE_BALL_SPEED + SPEED_PER_LEVEL * (level - 1) + speed_bonus


# -------------------------------------------------------------- ladrillos --
func _style_brick(view: Panel, highlight: ColorRect, kind: String, cracked: bool) -> void:
	var c: Color = BRICK_TYPES[kind]["color"]
	if cracked:
		c = c.lightened(0.3)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(3)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 2
	sb.border_width_bottom = 3
	sb.border_color = c.darkened(0.55)
	if kind == "S" or kind == "D":
		# Metálicos: borde claro arriba-izquierda, como el arcade.
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_color = c.darkened(0.45)
	sb.anti_aliasing = true
	view.add_theme_stylebox_override("panel", sb)
	var hl: Color = c.lightened(0.6)
	highlight.color = Color(hl.r, hl.g, hl.b, 0.7 if kind in ["S", "D"] else 0.45)


func _build_bricks() -> void:
	for b: Dictionary in bricks:
		b["view"].queue_free()
	bricks.clear()
	if level > LAYOUTS.size():
		return  # nivel de Doh: sin ladrillos
	var layout: Array = LAYOUTS[level - 1]
	var brick_w: float = (PLAY_W - BRICK_GAP * (COLS + 1)) / COLS
	# Plateados: 2 golpes, y uno más cada pocos niveles, como en el arcade.
	var silver_hits: int = 2 + (level - 1) / 4
	for r in range(layout.size()):
		var line: String = layout[r]
		for c in range(COLS):
			var kind: String = line[c]
			if kind == ".":
				continue
			var x: float = BRICK_GAP + c * (brick_w + BRICK_GAP)
			var y: float = BRICK_TOP + r * (BRICK_H + BRICK_GAP)
			var view := Panel.new()
			view.position = Vector2(x, y)
			view.size = Vector2(brick_w, BRICK_H)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play_area.add_child(view)
			play_area.move_child(view, fx_layer.get_index())
			var highlight := ColorRect.new()
			highlight.position = Vector2(2, 2)
			highlight.size = Vector2(brick_w - 5.0, 3.0)
			highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(highlight)
			_style_brick(view, highlight, kind, false)
			var hits: int = 1
			if kind == "S":
				hits = silver_hits
			elif kind == "D":
				hits = -1  # indestructible
			bricks.append({"rect": Rect2(x, y, brick_w, BRICK_H), "alive": true, "view": view,
				"highlight": highlight, "hits": hits, "kind": kind})


# ---------------------------------------------------------------- partida --
func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	state = "ready"
	_setup_level()


func _setup_level() -> void:
	_build_bricks()
	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()
	enemy_timer = 3.0
	doh = {}
	doh_shots.clear()
	if level > LAYOUTS.size():
		doh = {"hp": DOH_HP, "shot_timer": DOH_SHOT_INTERVAL, "hurt": 0.0, "t": 0.0}
	_update_hud()
	_reset_ball()
	status_label.text = ("¡Nivel %d! " % level if level > 1 else "") + ("¡DOH te espera! " if not doh.is_empty() else "") + "Toca para lanzar la bola"


func _update_hud() -> void:
	score_label.text = "Puntos: %d      Nivel: %d/%d" % [score, level, MAX_LEVEL]
	var pw: String = {"C": "  · 🟢 atrapar", "E": "  · 🔵 ancha", "L": "  · 🔴 láser"}.get(power, "")
	if slow_active:
		pw += "  · 🟠 lenta"
	lives_label.text = "Vidas: %d%s" % [lives, pw]


func _sync_ball_view(b: Dictionary) -> void:
	var pad: float = (BALL_VISUAL_SIZE - BALL_SIZE) / 2.0
	b["view"].position = b["pos"] - Vector2(pad, pad)


func _spawn_ball(pos: Vector2, vel: Vector2) -> Dictionary:
	var view := EntitySprite.new()
	view.size = Vector2(BALL_VISUAL_SIZE, BALL_VISUAL_SIZE)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("ball", Color(0.95, 0.95, 1.0))
	play_area.add_child(view)
	var b: Dictionary = {"pos": pos, "vel": vel, "view": view, "stuck": false, "stuck_offset": 0.0, "stuck_time": 0.0}
	_sync_ball_view(b)
	balls.append(b)
	return b


func _clear_balls() -> void:
	for b: Dictionary in balls:
		b["view"].queue_free()
	balls.clear()


func _set_paddle_width(w: float) -> void:
	paddle_w = w
	var center: float = paddle.position.x + paddle.size.x / 2.0
	paddle.size = Vector2(paddle_w, PADDLE_H)
	paddle.position.x = clamp(center - paddle_w / 2.0, 0.0, PLAY_W - paddle_w)


func _reset_ball() -> void:
	_clear_balls()
	for c: Dictionary in capsules:
		c["view"].queue_free()
	capsules.clear()
	for l: Dictionary in laser_bolts:
		l["view"].queue_free()
	laser_bolts.clear()
	doh_shots.clear()
	power = ""
	slow_active = false
	break_open = false
	speed_bonus = 0.0
	_set_paddle_width(PADDLE_W)
	paddle.position = Vector2((PLAY_W - paddle_w) / 2.0, PADDLE_Y)
	var b: Dictionary = _spawn_ball(Vector2.ZERO, Vector2.ZERO)
	b["stuck"] = true
	b["stuck_offset"] = paddle_w / 2.0 - BALL_SIZE / 2.0 + 12.0
	_update_hud()


func _on_play_area_input(event: InputEvent) -> void:
	if state == "game_over" or state == "won":
		return
	var x: float = -1.0
	var pressed := false
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			x = event.position.x
	elif event is InputEventMouseButton and event.pressed:
		x = event.position.x
		pressed = true
	if x < 0.0:
		return
	_move_paddle_to(x)
	if pressed or state == "ready":
		_release_stuck_balls()
		if state == "ready":
			state = "playing"
			status_label.text = ""


## Lanza las bolas pegadas a la paleta (inicio de vida o cápsula C), con
## el ángulo según dónde estén sobre la paleta.
func _release_stuck_balls() -> void:
	for b: Dictionary in balls:
		if not b["stuck"]:
			continue
		b["stuck"] = false
		var hit_pos: float = clampf(((b["stuck_offset"] + BALL_SIZE / 2.0) - paddle_w / 2.0) / (paddle_w / 2.0), -1.0, 1.0)
		var ang: float = hit_pos * MAX_BOUNCE_ANGLE * 0.8
		if absf(ang) < 0.25:
			ang = 0.25 * (1.0 if ang >= 0.0 else -1.0)
		b["vel"] = Vector2(sin(ang), -cos(ang)) * _ball_speed()


func _move_paddle_to(x: float) -> void:
	var max_x: float = PLAY_W - paddle_w + (paddle_w if break_open else 0.0)
	paddle.position.x = clamp(x - paddle_w / 2.0, 0.0, max_x)


# ------------------------------------------------------------------ bucle --
func _process(delta: float) -> void:
	fx_layer.queue_redraw()
	if state == "ready":
		_update_stuck_balls(delta)
		return
	if state != "playing":
		return

	_update_laser(delta)
	_update_enemies(delta)
	_update_doh(delta)
	if state != "playing":
		return

	# Salida "B": si la paleta entra al portal de la derecha, pasa de nivel.
	if break_open and paddle.position.x + paddle_w >= PLAY_W + paddle_w * 0.5:
		score += BREAK_BONUS
		AudioManager.play_power()
		_advance_level()
		return

	var paddle_rect := Rect2(paddle.position, Vector2(paddle_w, PADDLE_H))
	_update_stuck_balls(delta)
	for i in range(balls.size() - 1, -1, -1):
		var b: Dictionary = balls[i]
		if b["stuck"]:
			continue
		b["pos"] += b["vel"] * delta

		if b["pos"].x <= 0.0:
			b["pos"].x = 0.0
			b["vel"].x = absf(b["vel"].x)
		elif b["pos"].x + BALL_SIZE >= PLAY_W:
			b["pos"].x = PLAY_W - BALL_SIZE
			b["vel"].x = -absf(b["vel"].x)
		if b["pos"].y <= 0.0:
			b["pos"].y = 0.0
			b["vel"].y = absf(b["vel"].y)

		var ball_rect := Rect2(b["pos"], Vector2(BALL_SIZE, BALL_SIZE))
		if b["vel"].y > 0.0 and ball_rect.intersects(paddle_rect):
			if power == "C":
				# Cápsula C: la paleta atrapa la bola; se suelta al tocar.
				b["stuck"] = true
				b["stuck_offset"] = clampf(b["pos"].x - paddle.position.x, 0.0, paddle_w - BALL_SIZE)
				b["stuck_time"] = 0.0
			else:
				_bounce_off_paddle(b)

		_check_ball_bricks(b)
		_check_ball_enemies(b)
		_check_ball_doh(b)
		_sync_ball_view(b)

		if b["pos"].y > PLAY_H:
			b["view"].queue_free()
			balls.remove_at(i)

	_update_capsules(delta)

	if balls.is_empty():
		_lose_life()
		return
	if _level_cleared():
		_advance_level()


func _update_stuck_balls(delta: float) -> void:
	for b: Dictionary in balls:
		if not b["stuck"]:
			continue
		b["pos"] = Vector2(paddle.position.x + b["stuck_offset"], paddle.position.y - BALL_SIZE - 1.0)
		_sync_ball_view(b)
		if state == "playing":
			b["stuck_time"] += delta
			if b["stuck_time"] >= CATCH_AUTO_RELEASE:
				_release_stuck_balls()


func _bounce_off_paddle(b: Dictionary) -> void:
	var hit_pos: float = ((b["pos"].x + BALL_SIZE / 2.0) - (paddle.position.x + paddle_w / 2.0)) / (paddle_w / 2.0)
	hit_pos = clampf(hit_pos, -1.0, 1.0)
	var ang: float = hit_pos * MAX_BOUNCE_ANGLE
	b["vel"] = Vector2(sin(ang), -cos(ang)) * _ball_speed()
	b["pos"].y = paddle.position.y - BALL_SIZE - 1.0


func _check_ball_bricks(b: Dictionary) -> void:
	var ball_rect := Rect2(b["pos"], Vector2(BALL_SIZE, BALL_SIZE))
	for brick: Dictionary in bricks:
		if not brick["alive"]:
			continue
		var brick_rect: Rect2 = brick["rect"]
		if not ball_rect.intersects(brick_rect):
			continue
		_damage_brick(brick)
		_reflect(b, ball_rect, brick_rect)
		# Cada golpe acelera un poco la bola (como el arcade).
		speed_bonus = minf(speed_bonus + SPEEDUP_PER_HIT, MAX_SPEED_BONUS)
		b["vel"] = b["vel"].normalized() * _ball_speed()
		break


func _reflect(b: Dictionary, ball_rect: Rect2, other: Rect2) -> void:
	var overlap_x: float = minf(ball_rect.end.x, other.end.x) - maxf(ball_rect.position.x, other.position.x)
	var overlap_y: float = minf(ball_rect.end.y, other.end.y) - maxf(ball_rect.position.y, other.position.y)
	if overlap_x < overlap_y:
		b["vel"].x = -b["vel"].x
		b["pos"].x += -overlap_x if b["pos"].x < other.position.x else overlap_x
	else:
		b["vel"].y = -b["vel"].y
		b["pos"].y += -overlap_y if b["pos"].y < other.position.y else overlap_y


func _damage_brick(brick: Dictionary) -> void:
	if brick["hits"] < 0:
		# Dorado: indestructible, solo destella.
		brick["view"].modulate = Color(1.6, 1.6, 1.6)
		brick["view"].create_tween().tween_property(brick["view"], "modulate", Color.WHITE, 0.2)
		return
	brick["hits"] -= 1
	if brick["hits"] <= 0:
		brick["alive"] = false
		brick["view"].visible = false
		var kind: String = brick["kind"]
		score += BRICK_TYPES[kind]["points"] * (level if kind == "S" else 1)
		# Como en el arcade, los plateados no sueltan cápsulas y solo cae una
		# a la vez; con 3 bolas (D) tampoco caen más.
		if kind != "S" and capsules.is_empty() and balls.size() <= 1 and randf() < CAPSULE_DROP_CHANCE:
			var r: Rect2 = brick["rect"]
			_spawn_capsule(r.get_center())
	else:
		_style_brick(brick["view"], brick["highlight"], brick["kind"], true)
	_update_hud()


func _level_cleared() -> bool:
	if not doh.is_empty():
		return false
	for b: Dictionary in bricks:
		if b["alive"] and b["hits"] >= 0:
			return false
	return true


# --------------------------------------------------------------- cápsulas --
func _roll_capsule_kind() -> String:
	var total := 0
	for w: int in CAPSULE_WEIGHTS.values():
		total += w
	var r: int = randi() % total
	var acc := 0
	for kind: String in CAPSULE_WEIGHTS.keys():
		acc += CAPSULE_WEIGHTS[kind]
		if r < acc:
			return kind
	return "E"


func _spawn_capsule(center: Vector2) -> void:
	var kind: String = _roll_capsule_kind()
	var col: Color = CAPSULE_COLOR[kind]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(col, col.lightened(0.45), 9, 2))
	panel.size = CAPSULE_SIZE
	panel.position = center - CAPSULE_SIZE / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = kind
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("outline_size", 3)
	panel.add_child(lbl)
	play_area.add_child(panel)
	capsules.append({"pos": panel.position, "kind": kind, "view": panel})


func _update_capsules(delta: float) -> void:
	var paddle_rect := Rect2(paddle.position, Vector2(paddle_w, PADDLE_H))
	for i in range(capsules.size() - 1, -1, -1):
		var c: Dictionary = capsules[i]
		c["pos"].y += CAPSULE_FALL_SPEED * delta
		c["view"].position = c["pos"]
		var caught: bool = Rect2(c["pos"], CAPSULE_SIZE).intersects(paddle_rect)
		if caught or c["pos"].y > PLAY_H:
			if caught:
				_apply_capsule(c["kind"])
			c["view"].queue_free()
			capsules.remove_at(i)


## Solo un poder a la vez (como el arcade): C, E y L se reemplazan entre sí;
## S y D son instantáneos. Tomar otra cápsula quita la lentitud.
func _apply_capsule(kind: String) -> void:
	AudioManager.play_place()
	score += 1000
	if kind != "S":
		slow_active = false
	if kind in ["C", "E", "L"] and power != kind:
		if power == "E":
			_set_paddle_width(PADDLE_W)
		if power == "C":
			_release_stuck_balls()
		power = kind
	match kind:
		"S":
			slow_active = true
			for b: Dictionary in balls:
				if not b["stuck"]:
					b["vel"] = b["vel"].normalized() * _ball_speed()
		"E":
			_set_paddle_width(PADDLE_W * PADDLE_EXPAND_MULT)
		"D":
			if power == "C":
				_release_stuck_balls()
			power = ""
			_set_paddle_width(PADDLE_W)
			if not balls.is_empty():
				var base: Dictionary = balls[0]
				var dir: Vector2 = base["vel"].normalized() if base["vel"].length() > 1.0 else Vector2(0, -1)
				for ang: float in [-0.45, 0.45]:
					_spawn_ball(base["pos"], dir.rotated(ang) * _ball_speed())
		"B":
			break_open = true
			status_label.text = "¡Salida abierta! Lleva la paleta a la derecha →"
		"P":
			lives += 1
	_update_hud()


func _update_laser(delta: float) -> void:
	if laser_fire_cooldown > 0.0:
		laser_fire_cooldown -= delta
	if power == "L" and laser_fire_cooldown <= 0.0:
		laser_fire_cooldown = LASER_COOLDOWN
		_fire_laser()

	for i in range(laser_bolts.size() - 1, -1, -1):
		var l: Dictionary = laser_bolts[i]
		l["pos"].y -= 620.0 * delta
		l["view"].position = l["pos"]
		var bolt_rect := Rect2(l["pos"], Vector2(4, 16))
		var hit := false
		for brick: Dictionary in bricks:
			if brick["alive"] and bolt_rect.intersects(brick["rect"]):
				_damage_brick(brick)
				hit = true
				break
		if not hit:
			for e: Dictionary in enemies:
				if bolt_rect.intersects(Rect2(e["pos"], ENEMY_SIZE)):
					_kill_enemy(e)
					hit = true
					break
		if not hit and not doh.is_empty() and bolt_rect.intersects(DOH_RECT):
			hit = true  # el láser no le hace daño a Doh
		if hit or l["pos"].y < -16.0:
			l["view"].queue_free()
			laser_bolts.remove_at(i)


func _fire_laser() -> void:
	for side: float in [0.18, 0.82]:
		var pos := Vector2(paddle.position.x + paddle_w * side - 2.0, paddle.position.y - 16.0)
		var view := EntitySprite.new()
		view.size = Vector2(4, 16)
		view.position = pos
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.setup("bullet", Color(1.0, 0.3, 0.3), UIKit.COLOR_TEXT)
		play_area.add_child(view)
		laser_bolts.append({"pos": pos, "view": view})


# --------------------------------------------------------------- enemigos --
func _update_enemies(delta: float) -> void:
	if level >= ENEMY_MIN_LEVEL and doh.is_empty():
		enemy_timer -= delta
		if enemy_timer <= 0.0:
			enemy_timer = ENEMY_INTERVAL
			if enemies.size() < ENEMY_MAX:
				_spawn_enemy()
	var paddle_rect := Rect2(paddle.position, Vector2(paddle_w, PADDLE_H))
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		e["t"] += delta
		# Bajan flotando con un vaivén, y rebotan en paredes y ladrillos.
		var vel := Vector2(sin(e["t"] * 1.7 + e["seed"]) * 70.0 + e["drift"], 45.0)
		var np: Vector2 = e["pos"] + vel * delta
		var er := Rect2(np, ENEMY_SIZE)
		var blocked := false
		for brick: Dictionary in bricks:
			if brick["alive"] and er.intersects(brick["rect"]):
				blocked = true
				break
		if np.x < 0.0 or np.x > PLAY_W - ENEMY_SIZE.x:
			e["drift"] = -e["drift"]
			np.x = clampf(np.x, 0.0, PLAY_W - ENEMY_SIZE.x)
		if not blocked:
			e["pos"] = np
		else:
			e["drift"] = -e["drift"]
		e["view"].position = e["pos"]
		e["view"].set_phase(fmod(e["t"], 1.0))
		if Rect2(e["pos"], ENEMY_SIZE).intersects(paddle_rect):
			_kill_enemy(e)
		elif e["pos"].y > PLAY_H:
			e["view"].queue_free()
			enemies.remove_at(i)


func _spawn_enemy() -> void:
	var view := EntitySprite.new()
	view.size = ENEMY_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette: Array = [Color(0.3, 0.9, 0.5), Color(1.0, 0.6, 0.2), Color(0.6, 0.5, 1.0), Color(1.0, 0.35, 0.5)]
	view.setup("ufo", palette[randi() % palette.size()], Color(0.95, 0.95, 1.0), randi())
	play_area.add_child(view)
	var gx: float = GATES_X[randi() % GATES_X.size()]
	enemies.append({"pos": Vector2(gx - ENEMY_SIZE.x / 2.0, 20.0), "view": view, "t": 0.0,
		"seed": randf() * TAU, "drift": [-40.0, 40.0].pick_random()})


func _check_ball_enemies(b: Dictionary) -> void:
	var ball_rect := Rect2(b["pos"], Vector2(BALL_SIZE, BALL_SIZE))
	for e: Dictionary in enemies:
		var er := Rect2(e["pos"], ENEMY_SIZE)
		if ball_rect.intersects(er):
			_reflect(b, ball_rect, er)
			_kill_enemy(e)
			return


func _kill_enemy(e: Dictionary) -> void:
	score += ENEMY_POINTS
	_update_hud()
	AudioManager.play_click()
	var v: EntitySprite = e["view"]
	v.pivot_offset = v.size / 2.0
	var tw := v.create_tween().set_parallel(true)
	tw.tween_property(v, "scale", Vector2(1.8, 1.8), 0.25)
	tw.tween_property(v, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(v.queue_free)
	enemies.erase(e)


# -------------------------------------------------------------------- Doh --
func _update_doh(delta: float) -> void:
	if doh.is_empty():
		return
	doh["t"] += delta
	if doh["hurt"] > 0.0:
		doh["hurt"] -= delta
	doh["shot_timer"] -= delta
	if doh["shot_timer"] <= 0.0:
		doh["shot_timer"] = DOH_SHOT_INTERVAL
		# Escupe proyectiles desde la boca, apuntados a la paleta.
		var mouth := Vector2(DOH_RECT.get_center().x, DOH_RECT.end.y - 50.0)
		var target := Vector2(paddle.position.x + paddle_w / 2.0, PADDLE_Y)
		for spread: float in [-0.12, 0.0, 0.12]:
			doh_shots.append({"pos": mouth, "vel": (target - mouth).normalized().rotated(spread) * DOH_SHOT_SPEED})
	var paddle_rect := Rect2(paddle.position, Vector2(paddle_w, PADDLE_H))
	for i in range(doh_shots.size() - 1, -1, -1):
		var s: Dictionary = doh_shots[i]
		s["pos"] += s["vel"] * delta
		if Rect2(s["pos"] - Vector2(7, 7), Vector2(14, 14)).intersects(paddle_rect):
			doh_shots.clear()
			_lose_life()
			return
		if s["pos"].y > PLAY_H:
			doh_shots.remove_at(i)


func _check_ball_doh(b: Dictionary) -> void:
	if doh.is_empty():
		return
	var ball_rect := Rect2(b["pos"], Vector2(BALL_SIZE, BALL_SIZE))
	if not ball_rect.intersects(DOH_RECT):
		return
	_reflect(b, ball_rect, DOH_RECT)
	if doh["hurt"] > 0.0:
		return  # un golpe a la vez
	doh["hp"] -= 1
	doh["hurt"] = 0.3
	AudioManager.play_alert()
	if doh["hp"] <= 0:
		score += DOH_POINTS
		doh = {}
		doh_shots.clear()
		_update_hud()
		_win()


func _draw_fx() -> void:
	# Compuertas por donde bajan los enemigos.
	for gx: float in GATES_X:
		fx_layer.draw_rect(Rect2(gx - 30.0, 0, 60.0, 10.0), Color(0.55, 0.6, 0.7))
		fx_layer.draw_rect(Rect2(gx - 26.0, 2, 52.0, 6.0), Color(0.15, 0.17, 0.25))
	# Salida de la cápsula B: portal brillante en la pared derecha.
	if break_open:
		var glow: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
		fx_layer.draw_rect(Rect2(PLAY_W - 10.0, PADDLE_Y - 40.0, 10.0, 90.0), Color(1.0, 0.35, 0.85, glow))
		fx_layer.draw_rect(Rect2(PLAY_W - 24.0, PADDLE_Y - 40.0, 14.0, 90.0), Color(1.0, 0.35, 0.85, glow * 0.3))
	if not doh.is_empty():
		_draw_doh()


## Doh: una cabeza tipo moái gigante (dibujada con formas simples).
func _draw_doh() -> void:
	var r: Rect2 = DOH_RECT
	var hurt: bool = doh["hurt"] > 0.0
	var base: Color = Color(1.0, 0.55, 0.55) if hurt else Color(0.55, 0.42, 0.62)
	var dark: Color = base.darkened(0.45)
	var pts := PackedVector2Array([
		r.position + Vector2(r.size.x * 0.2, 0), r.position + Vector2(r.size.x * 0.8, 0),
		r.position + Vector2(r.size.x, r.size.y * 0.25), r.position + Vector2(r.size.x * 0.9, r.size.y),
		r.position + Vector2(r.size.x * 0.1, r.size.y), r.position + Vector2(0, r.size.y * 0.25),
	])
	fx_layer.draw_colored_polygon(pts, base)
	fx_layer.draw_polyline(pts + PackedVector2Array([pts[0]]), dark, 3.0, true)
	var c: Vector2 = r.get_center()
	# Cejas, ojos que brillan, nariz y boca.
	fx_layer.draw_rect(Rect2(c.x - 80, r.position.y + 70, 60, 12), dark)
	fx_layer.draw_rect(Rect2(c.x + 20, r.position.y + 70, 60, 12), dark)
	var eye: Color = Color(1.0, 0.3, 0.2) if int(doh["t"] * 3.0) % 2 == 0 else Color(1.0, 0.9, 0.3)
	fx_layer.draw_circle(Vector2(c.x - 50, r.position.y + 100), 12, eye)
	fx_layer.draw_circle(Vector2(c.x + 50, r.position.y + 100), 12, eye)
	fx_layer.draw_colored_polygon(PackedVector2Array([Vector2(c.x, r.position.y + 110), Vector2(c.x - 18, r.position.y + 175), Vector2(c.x + 18, r.position.y + 175)]), dark)
	fx_layer.draw_rect(Rect2(c.x - 45, r.end.y - 62, 90, 20), Color(0.15, 0.05, 0.1))
	# Barra de vida.
	fx_layer.draw_rect(Rect2(PLAY_W / 2.0 - 120.0, 30, 240, 12), Color(0.3, 0.05, 0.05))
	fx_layer.draw_rect(Rect2(PLAY_W / 2.0 - 120.0, 30, 240.0 * doh["hp"] / DOH_HP, 12), UIKit.COLOR_DANGER)
	for s: Dictionary in doh_shots:
		fx_layer.draw_circle(s["pos"], 7.0, Color(1.0, 0.85, 0.3))
		fx_layer.draw_circle(s["pos"], 4.0, Color(1.0, 1.0, 0.8))


# -------------------------------------------------------------- fin/nivel --
func _lose_life() -> void:
	lives -= 1
	_update_hud()
	AudioManager.play_error()
	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over. Puntos: %d" % score
		_record_result(false)
		return
	state = "ready"
	_reset_ball()
	status_label.text = "Toca para lanzar la bola"


func _advance_level() -> void:
	if level >= MAX_LEVEL:
		_win()
		return
	level += 1
	state = "ready"
	_setup_level()


func _win() -> void:
	state = "won"
	status_label.text = "¡Derrotaste a DOH! Puntos: %d" % score
	_record_result(true)


func _record_result(won: bool) -> void:
	AudioManager.play_win() if won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)
