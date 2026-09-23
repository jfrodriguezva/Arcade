extends Control
## Arkanoid/rompe-ladrillos. Arrastra para mover la paleta; la física
## de rebote (paredes, paleta con ángulo según punto de impacto,
## ladrillos) es manual, sin motor de físicas, consistente con el
## resto de la plataforma.

const GAME_ID := "arkanoid"
const PLAY_W := 680.0
const PLAY_H := 1000.0
const PADDLE_W := 120.0
const PADDLE_H := 18.0
const BALL_SIZE := 16.0
const BALL_VISUAL_SIZE := BALL_SIZE * 1.18
const COLS := 8
const BRICK_GAP := 4.0
const BRICK_H := 28.0
const BASE_BALL_SPEED := 420.0
const SPEED_PER_LEVEL := 20.0
const MAX_BOUNCE_VX := 380.0
const MAX_LEVEL := 10

const HELP_TEXT := "Arrastra el dedo (o el mouse) horizontalmente sobre el área de juego para mover la paleta.

Toca la pantalla para lanzar la bola. Rebota la bola para romper todos los ladrillos sin dejarla caer — el punto donde golpea la paleta cambia el ángulo del rebote.

Hay 10 niveles: cada uno tiene más filas de ladrillos, la bola es más rápida, y desde el nivel 4 aparecen ladrillos resistentes (necesitan 2 golpes, se ven más claros tras el primero).

Pierdes una vida si la bola cae debajo de la paleta. Ganas si completas los 10 niveles; pierdes si se acaban tus 3 vidas."

var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "ready" # ready | playing | game_over | won
var bricks: Array = []

var play_area: Control
var paddle: EntitySprite
var ball_view: EntitySprite
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

	# Barra de HUD delgada: puntos, nivel y vidas en una sola fila compacta.
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
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_STOP
	play_area.gui_input.connect(_on_play_area_input)
	play_panel.add_child(play_area)

	paddle = EntitySprite.new()
	paddle.size = Vector2(PADDLE_W, PADDLE_H)
	paddle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paddle.setup("paddle", UIKit.COLOR_ACCENT_2, UIKit.COLOR_ACCENT_3)
	play_area.add_child(paddle)

	ball_view = EntitySprite.new()
	ball_view.size = Vector2(BALL_VISUAL_SIZE, BALL_VISUAL_SIZE)
	ball_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_view.setup("ball", UIKit.COLOR_ACCENT_3)
	play_area.add_child(ball_view)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(220, 52)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void:
		UIKit.pulse(restart_btn)
		_new_game()
	)
	vbox.add_child(restart_btn)


func _rows_for_level(lvl: int) -> int:
	return min(3 + lvl, 9)


func _ball_speed_for_level(lvl: int) -> float:
	return BASE_BALL_SPEED + SPEED_PER_LEVEL * (lvl - 1)


func _row_gradient_color(r: int, rows: int) -> Color:
	## Degradado de color por fila (de arriba hacia abajo) para que los
	## ladrillos se sientan "reales" en vez de un color plano repetido.
	var t: float = float(r) / float(max(rows - 1, 1))
	if t < 0.5:
		return UIKit.COLOR_ACCENT_2.lerp(UIKit.COLOR_ACCENT_3, t * 2.0)
	return UIKit.COLOR_ACCENT_3.lerp(UIKit.COLOR_ACCENT, (t - 0.5) * 2.0)


func _style_brick(view: Panel, highlight: ColorRect, base_color: Color, tough: bool, cracked: bool) -> void:
	## Da a cada ladrillo un aspecto biselado (StyleBoxFlat con borde inferior
	## oscuro + sombra, más una franja superior clara) en lugar de un panel plano.
	var c: Color = base_color
	if cracked:
		c = base_color.lightened(0.55)
	elif tough:
		c = base_color.lerp(Color(0.82, 0.86, 0.92), 0.40)

	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(5)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 3
	sb.border_color = c.darkened(0.5)
	if tough and not cracked:
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_color = Color(0.92, 0.95, 1.0, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 2
	sb.anti_aliasing = true
	view.add_theme_stylebox_override("panel", sb)

	var hl: Color = c.lightened(0.5)
	highlight.color = Color(hl.r, hl.g, hl.b, 0.55)


func _build_bricks() -> void:
	for b: Dictionary in bricks:
		b["view"].queue_free()
	bricks.clear()

	var rows: int = _rows_for_level(level)
	var tough_chance: float = clamp(0.06 * (level - 3), 0.0, 0.35)
	var brick_w: float = (PLAY_W - BRICK_GAP * (COLS + 1)) / COLS

	for r in range(rows):
		for c in range(COLS):
			var x: float = BRICK_GAP + c * (brick_w + BRICK_GAP)
			var y: float = 20.0 + r * (BRICK_H + BRICK_GAP)
			var tough: bool = level >= 4 and randf() < tough_chance
			var view := Panel.new()
			view.position = Vector2(x, y)
			view.size = Vector2(brick_w, BRICK_H)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play_area.add_child(view)

			var highlight := ColorRect.new()
			highlight.position = Vector2(2, 1)
			highlight.size = Vector2(brick_w - 4.0, 2.0)
			highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(highlight)

			var color: Color = _row_gradient_color(r, rows)
			_style_brick(view, highlight, color, tough, false)
			bricks.append({
				"rect": Rect2(x, y, brick_w, BRICK_H), "alive": true, "view": view, "highlight": highlight,
				"hits": 2 if tough else 1, "base_color": color, "tough": tough,
			})


func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	state = "ready"
	_build_bricks()
	_update_hud()
	_reset_ball()


func _update_hud() -> void:
	score_label.text = "Puntos: %d      Nivel: %d/%d" % [score, level, MAX_LEVEL]
	lives_label.text = "Vidas: %d" % lives


func _sync_ball_view() -> void:
	## El nodo visual de la bola es un poco más grande que su caja de colisión
	## (BALL_SIZE) para lucir mejor con el sombreado de EntitySprite; se centra
	## sobre la posición/caja real que usa la física.
	var pad: float = (BALL_VISUAL_SIZE - BALL_SIZE) / 2.0
	ball_view.position = ball_pos - Vector2(pad, pad)


func _reset_ball() -> void:
	paddle.position = Vector2((PLAY_W - PADDLE_W) / 2.0, PLAY_H - 40.0)
	ball_pos = Vector2(paddle.position.x + PADDLE_W / 2.0 - BALL_SIZE / 2.0, paddle.position.y - BALL_SIZE - 2.0)
	ball_vel = Vector2.ZERO
	_sync_ball_view()
	status_label.text = "Toca el área de juego para lanzar la bola"


func _on_play_area_input(event: InputEvent) -> void:
	if state == "game_over" or state == "won":
		return

	var x: float = -1.0
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			x = event.position.x
	elif event is InputEventMouseButton and event.pressed:
		x = event.position.x

	if x < 0.0:
		return

	_move_paddle_to(x)

	if state == "ready":
		state = "playing"
		var speed: float = _ball_speed_for_level(level)
		ball_vel = Vector2(speed * 0.5, -speed)
		status_label.text = ""


func _move_paddle_to(x: float) -> void:
	paddle.position.x = clamp(x - PADDLE_W / 2.0, 0.0, PLAY_W - PADDLE_W)


func _process(delta: float) -> void:
	if state != "playing":
		return

	ball_pos += ball_vel * delta

	if ball_pos.x <= 0.0:
		ball_pos.x = 0.0
		ball_vel.x = abs(ball_vel.x)
	elif ball_pos.x + BALL_SIZE >= PLAY_W:
		ball_pos.x = PLAY_W - BALL_SIZE
		ball_vel.x = -abs(ball_vel.x)

	if ball_pos.y <= 0.0:
		ball_pos.y = 0.0
		ball_vel.y = abs(ball_vel.y)

	var ball_rect := Rect2(ball_pos, Vector2(BALL_SIZE, BALL_SIZE))
	var paddle_rect := Rect2(paddle.position, Vector2(PADDLE_W, PADDLE_H))

	if ball_vel.y > 0.0 and ball_rect.intersects(paddle_rect):
		var hit_pos: float = ((ball_pos.x + BALL_SIZE / 2.0) - (paddle.position.x + PADDLE_W / 2.0)) / (PADDLE_W / 2.0)
		hit_pos = clamp(hit_pos, -1.0, 1.0)
		var speed: float = _ball_speed_for_level(level)
		ball_vel.x = hit_pos * MAX_BOUNCE_VX
		ball_vel.y = -speed
		ball_pos.y = paddle.position.y - BALL_SIZE - 1.0

	for b: Dictionary in bricks:
		if not b["alive"]:
			continue
		var brick_rect: Rect2 = b["rect"]
		if ball_rect.intersects(brick_rect):
			b["hits"] -= 1
			if b["hits"] <= 0:
				b["alive"] = false
				b["view"].visible = false
				score += 10
			else:
				score += 5
				_style_brick(b["view"], b["highlight"], b["base_color"], b["tough"], true)
			_update_hud()

			var overlap_x: float = min(ball_rect.end.x, brick_rect.end.x) - max(ball_rect.position.x, brick_rect.position.x)
			var overlap_y: float = min(ball_rect.end.y, brick_rect.end.y) - max(ball_rect.position.y, brick_rect.position.y)
			if overlap_x < overlap_y:
				ball_vel.x = -ball_vel.x
			else:
				ball_vel.y = -ball_vel.y
			break

	_sync_ball_view()

	if ball_pos.y > PLAY_H:
		_lose_life()
		return

	if _all_bricks_cleared():
		_advance_level()


func _all_bricks_cleared() -> bool:
	for b: Dictionary in bricks:
		if b["alive"]:
			return false
	return true


func _lose_life() -> void:
	lives -= 1
	_update_hud()
	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over. Puntos: %d" % score
		_record_result(false)
		return
	state = "ready"
	_reset_ball()


func _advance_level() -> void:
	if level >= MAX_LEVEL:
		_win()
		return
	level += 1
	state = "ready"
	_build_bricks()
	_reset_ball()
	_update_hud()
	status_label.text = "¡Nivel %d! Toca para lanzar la bola" % level


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
