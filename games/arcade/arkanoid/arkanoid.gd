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

const CAPSULE_DROP_CHANCE := 0.18
const CAPSULE_SIZE := Vector2(38, 20)
const CAPSULE_FALL_SPEED := 150.0
const POWERUP_DURATION := 12.0
const LASER_COOLDOWN := 0.4
const PADDLE_EXPAND_MULT := 1.6
const PADDLE_SHRINK_MULT := 0.62
const SLOW_MULT := 0.62
const CAPSULE_WEIGHTS := {"expand": 24, "shrink": 14, "slow": 16, "multiball": 20, "laser": 16, "life": 10}
const CAPSULE_LETTER := {"expand": "E", "shrink": "S", "slow": "◐", "multiball": "M", "laser": "L", "life": "❤"}
const CAPSULE_COLOR := {
	"expand": UIKit.COLOR_ACCENT_2, "shrink": UIKit.COLOR_DANGER, "slow": UIKit.COLOR_TEXT_DIM,
	"multiball": UIKit.COLOR_ACCENT_3, "laser": UIKit.COLOR_ACCENT, "life": Color(1.0, 0.478, 0.706),
}

const HELP_TEXT := "Arrastra el dedo (o el mouse) horizontalmente sobre el área de juego para mover la paleta.

Toca la pantalla para lanzar la bola. Rebota la bola para romper todos los ladrillos sin dejarla caer — el punto donde golpea la paleta cambia el ángulo del rebote.

Al romper ladrillos a veces cae una cápsula: atrápala con la paleta.
E = paleta más grande · S = paleta más chica (¡evítala!) · ◐ = bola más lenta · M = bola extra (multibola) · L = láser automático que rompe ladrillos desde la paleta · ❤ = vida extra.

Hay 10 niveles: cada uno tiene más filas de ladrillos, la bola es más rápida, y desde el nivel 4 aparecen ladrillos resistentes (necesitan 2 golpes, se ven más claros tras el primero).

Pierdes una vida si TODAS tus bolas caen debajo de la paleta. Ganas si completas los 10 niveles; pierdes si se acaban tus 3 vidas."

var balls: Array = []  # cada bola: {"pos":Vector2,"vel":Vector2,"view":EntitySprite}
var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "ready" # ready | playing | game_over | won
var bricks: Array = []

var paddle_w: float = PADDLE_W
var capsules: Array = []
var laser_bolts: Array = []
var expand_timer: float = 0.0
var shrink_timer: float = 0.0
var slow_timer: float = 0.0
var laser_timer: float = 0.0
var laser_fire_cooldown: float = 0.0

var play_area: Control
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
	paddle.size = Vector2(paddle_w, PADDLE_H)
	paddle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paddle.setup("paddle", UIKit.COLOR_ACCENT_2, UIKit.COLOR_ACCENT_3)
	play_area.add_child(paddle)

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


func _sync_ball_view(b: Dictionary) -> void:
	## El nodo visual de la bola es un poco más grande que su caja de colisión
	## (BALL_SIZE) para lucir mejor con el sombreado de EntitySprite; se centra
	## sobre la posición/caja real que usa la física.
	var pad: float = (BALL_VISUAL_SIZE - BALL_SIZE) / 2.0
	b["view"].position = b["pos"] - Vector2(pad, pad)


func _spawn_ball(pos: Vector2, vel: Vector2) -> Dictionary:
	var view := EntitySprite.new()
	view.size = Vector2(BALL_VISUAL_SIZE, BALL_VISUAL_SIZE)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup("ball", UIKit.COLOR_ACCENT_3)
	play_area.add_child(view)
	var b: Dictionary = {"pos": pos, "vel": vel, "view": view}
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
	expand_timer = 0.0
	shrink_timer = 0.0
	slow_timer = 0.0
	laser_timer = 0.0
	_set_paddle_width(PADDLE_W)
	paddle.position = Vector2((PLAY_W - paddle_w) / 2.0, PLAY_H - 40.0)
	_spawn_ball(Vector2(paddle.position.x + paddle_w / 2.0 - BALL_SIZE / 2.0, paddle.position.y - BALL_SIZE - 2.0), Vector2.ZERO)
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
		balls[0]["vel"] = Vector2(speed * 0.5, -speed)
		status_label.text = ""


func _move_paddle_to(x: float) -> void:
	paddle.position.x = clamp(x - paddle_w / 2.0, 0.0, PLAY_W - paddle_w)


func _process(delta: float) -> void:
	if state != "playing":
		return

	if expand_timer > 0.0:
		expand_timer -= delta
		if expand_timer <= 0.0 and shrink_timer <= 0.0:
			_set_paddle_width(PADDLE_W)
	if shrink_timer > 0.0:
		shrink_timer -= delta
		if shrink_timer <= 0.0 and expand_timer <= 0.0:
			_set_paddle_width(PADDLE_W)
	if slow_timer > 0.0:
		slow_timer -= delta
	if laser_timer > 0.0:
		laser_timer -= delta
	_update_laser(delta)

	var speed_mult: float = SLOW_MULT if slow_timer > 0.0 else 1.0
	var paddle_rect := Rect2(paddle.position, Vector2(paddle_w, PADDLE_H))

	for i in range(balls.size() - 1, -1, -1):
		var b: Dictionary = balls[i]
		b["pos"] += b["vel"] * speed_mult * delta

		if b["pos"].x <= 0.0:
			b["pos"].x = 0.0
			b["vel"].x = abs(b["vel"].x)
		elif b["pos"].x + BALL_SIZE >= PLAY_W:
			b["pos"].x = PLAY_W - BALL_SIZE
			b["vel"].x = -abs(b["vel"].x)
		if b["pos"].y <= 0.0:
			b["pos"].y = 0.0
			b["vel"].y = abs(b["vel"].y)

		var ball_rect := Rect2(b["pos"], Vector2(BALL_SIZE, BALL_SIZE))
		if b["vel"].y > 0.0 and ball_rect.intersects(paddle_rect):
			var hit_pos: float = ((b["pos"].x + BALL_SIZE / 2.0) - (paddle.position.x + paddle_w / 2.0)) / (paddle_w / 2.0)
			hit_pos = clamp(hit_pos, -1.0, 1.0)
			var speed: float = _ball_speed_for_level(level)
			b["vel"].x = hit_pos * MAX_BOUNCE_VX
			b["vel"].y = -speed
			b["pos"].y = paddle.position.y - BALL_SIZE - 1.0

		_check_ball_bricks(b)
		_sync_ball_view(b)

		if b["pos"].y > PLAY_H:
			b["view"].queue_free()
			balls.remove_at(i)

	_update_capsules(delta)

	if balls.is_empty():
		_lose_life()
		return

	if _all_bricks_cleared():
		_advance_level()


func _check_ball_bricks(b: Dictionary) -> void:
	var ball_rect := Rect2(b["pos"], Vector2(BALL_SIZE, BALL_SIZE))
	for brick: Dictionary in bricks:
		if not brick["alive"]:
			continue
		var brick_rect: Rect2 = brick["rect"]
		if not ball_rect.intersects(brick_rect):
			continue
		_damage_brick(brick)
		var overlap_x: float = min(ball_rect.end.x, brick_rect.end.x) - max(ball_rect.position.x, brick_rect.position.x)
		var overlap_y: float = min(ball_rect.end.y, brick_rect.end.y) - max(ball_rect.position.y, brick_rect.position.y)
		if overlap_x < overlap_y:
			b["vel"].x = -b["vel"].x
		else:
			b["vel"].y = -b["vel"].y
		break


func _damage_brick(brick: Dictionary) -> void:
	brick["hits"] -= 1
	if brick["hits"] <= 0:
		brick["alive"] = false
		brick["view"].visible = false
		score += 10
		if randf() < CAPSULE_DROP_CHANCE:
			var r: Rect2 = brick["rect"]
			_spawn_capsule(Vector2(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0))
	else:
		score += 5
		_style_brick(brick["view"], brick["highlight"], brick["base_color"], brick["tough"], true)
	_update_hud()


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
	return "expand"


func _spawn_capsule(center: Vector2) -> void:
	var kind: String = _roll_capsule_kind()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(CAPSULE_COLOR[kind].darkened(0.4), CAPSULE_COLOR[kind].lightened(0.3), 9, 2))
	panel.size = CAPSULE_SIZE
	panel.position = center - CAPSULE_SIZE / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = CAPSULE_LETTER[kind]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
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


func _apply_capsule(kind: String) -> void:
	AudioManager.play_place()
	match kind:
		"expand":
			shrink_timer = 0.0
			expand_timer = POWERUP_DURATION
			_set_paddle_width(PADDLE_W * PADDLE_EXPAND_MULT)
		"shrink":
			expand_timer = 0.0
			shrink_timer = POWERUP_DURATION
			_set_paddle_width(PADDLE_W * PADDLE_SHRINK_MULT)
		"slow":
			slow_timer = POWERUP_DURATION
		"multiball":
			if not balls.is_empty():
				var base: Dictionary = balls[0]
				var base_speed: float = maxf(base["vel"].length(), _ball_speed_for_level(level))
				for ang: float in [-0.5, 0.5]:
					var dir: Vector2 = base["vel"].normalized().rotated(ang) if base["vel"].length() > 1.0 else Vector2(sin(ang), -cos(ang))
					_spawn_ball(base["pos"], dir * base_speed)
		"laser":
			laser_timer = POWERUP_DURATION
		"life":
			lives += 1
	_update_hud()


func _update_laser(delta: float) -> void:
	if laser_fire_cooldown > 0.0:
		laser_fire_cooldown -= delta
	if laser_timer > 0.0 and laser_fire_cooldown <= 0.0:
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
		if hit or l["pos"].y < -16.0:
			l["view"].queue_free()
			laser_bolts.remove_at(i)


func _fire_laser() -> void:
	for side: float in [0.22, 0.78]:
		var pos := Vector2(paddle.position.x + paddle_w * side - 2.0, paddle.position.y - 16.0)
		var view := EntitySprite.new()
		view.size = Vector2(4, 16)
		view.position = pos
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.setup("bullet", UIKit.COLOR_ACCENT, UIKit.COLOR_TEXT)
		play_area.add_child(view)
		laser_bolts.append({"pos": pos, "view": view})


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
