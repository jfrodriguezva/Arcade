extends Control
## Arkanoid/rompe-ladrillos. Arrastra para mover la paleta; la física
## de rebote (paredes, paleta con ángulo según punto de impacto,
## ladrillos) es manual, sin motor de físicas, consistente con el
## resto de la plataforma.

const GAME_ID := "arkanoid"
const PLAY_W := 640.0
const PLAY_H := 880.0
const PADDLE_W := 120.0
const PADDLE_H := 18.0
const BALL_SIZE := 16.0
const COLS := 8
const ROWS := 5
const BRICK_GAP := 4.0
const BRICK_H := 30.0
const BALL_SPEED := 480.0
const MAX_BOUNCE_VX := 380.0

const HELP_TEXT := "Arrastra el dedo (o el mouse) horizontalmente sobre el área de juego para mover la paleta.

Toca la pantalla para lanzar la bola. Rebota la bola para romper todos los ladrillos sin dejarla caer — el punto donde golpea la paleta cambia el ángulo del rebote.

Pierdes una vida si la bola cae debajo de la paleta. Ganas si rompes todos los ladrillos; pierdes si se acaban tus 3 vidas."

var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var score: int = 0
var lives: int = 3
var state: String = "ready" # ready | playing | game_over | won
var bricks: Array = []

var play_area: Control
var paddle: Panel
var ball_view: GamePiece
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
		margin.add_theme_constant_override(side, 20)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Arkanoid", HELP_TEXT)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 30)
	vbox.add_child(hud)
	score_label = UIKit.title_label("Puntos: 0", 16, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("Vidas: 3", 16, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)

	status_label = UIKit.title_label("", 15, UIKit.COLOR_TEXT_DIM)
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

	paddle = Panel.new()
	paddle.size = Vector2(PADDLE_W, PADDLE_H)
	paddle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paddle.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_ACCENT, Color(0, 0, 0, 0), 8))
	play_area.add_child(paddle)

	ball_view = GamePiece.new()
	ball_view.size = Vector2(BALL_SIZE, BALL_SIZE)
	ball_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_view.set_piece(UIKit.COLOR_ACCENT_3)
	play_area.add_child(ball_view)

	_build_bricks()

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _build_bricks() -> void:
	bricks.clear()
	var brick_w: float = (PLAY_W - BRICK_GAP * (COLS + 1)) / COLS
	var row_colors: Array = [UIKit.COLOR_ACCENT, UIKit.COLOR_ACCENT_2, UIKit.COLOR_ACCENT_3, UIKit.COLOR_DANGER, UIKit.COLOR_TEXT_DIM]
	for r in range(ROWS):
		for c in range(COLS):
			var x: float = BRICK_GAP + c * (brick_w + BRICK_GAP)
			var y: float = 20.0 + r * (BRICK_H + BRICK_GAP)
			var view := Panel.new()
			view.position = Vector2(x, y)
			view.size = Vector2(brick_w, BRICK_H)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var color: Color = row_colors[r % row_colors.size()]
			view.add_theme_stylebox_override("panel", UIKit.stylebox(color, Color(0, 0, 0, 0), 4))
			play_area.add_child(view)
			bricks.append({"rect": Rect2(x, y, brick_w, BRICK_H), "alive": true, "view": view})


func _new_game() -> void:
	score = 0
	lives = 3
	state = "ready"
	for b: Dictionary in bricks:
		b["alive"] = true
		b["view"].visible = true
	_update_hud()
	_reset_ball()


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "Vidas: %d" % lives


func _reset_ball() -> void:
	paddle.position = Vector2((PLAY_W - PADDLE_W) / 2.0, PLAY_H - 40.0)
	ball_pos = Vector2(paddle.position.x + PADDLE_W / 2.0 - BALL_SIZE / 2.0, paddle.position.y - BALL_SIZE - 2.0)
	ball_vel = Vector2.ZERO
	ball_view.position = ball_pos
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
		ball_vel = Vector2(BALL_SPEED * 0.5, -BALL_SPEED)
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
		ball_vel.x = hit_pos * MAX_BOUNCE_VX
		ball_vel.y = -abs(ball_vel.y)
		ball_pos.y = paddle.position.y - BALL_SIZE - 1.0

	for b: Dictionary in bricks:
		if not b["alive"]:
			continue
		var brick_rect: Rect2 = b["rect"]
		if ball_rect.intersects(brick_rect):
			b["alive"] = false
			b["view"].visible = false
			score += 10
			_update_hud()

			var overlap_x: float = min(ball_rect.end.x, brick_rect.end.x) - max(ball_rect.position.x, brick_rect.position.x)
			var overlap_y: float = min(ball_rect.end.y, brick_rect.end.y) - max(ball_rect.position.y, brick_rect.position.y)
			if overlap_x < overlap_y:
				ball_vel.x = -ball_vel.x
			else:
				ball_vel.y = -ball_vel.y
			break

	ball_view.position = ball_pos

	if ball_pos.y > PLAY_H:
		_lose_life()
		return

	if _all_bricks_cleared():
		_win()


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


func _win() -> void:
	state = "won"
	status_label.text = "¡Ganaste! Puntos: %d" % score
	_record_result(true)


func _record_result(won: bool) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)
