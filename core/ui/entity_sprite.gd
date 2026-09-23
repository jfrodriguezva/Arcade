class_name EntitySprite
extends Control
## Sprite vectorial (dibujado con _draw) para los personajes/enemigos/objetos
## de los juegos arcade, en reemplazo de las "bolitas" genéricas de GamePiece.
## Un solo componente reutilizable: se configura con `shape` (string) y se
## anima con `phase` (0..1, controlado por el propio juego en su _process).
##
## Formas soportadas: "ship", "asteroid", "alien", "paddle", "ball",
## "cowboy", "bandit", "bullet", "ghost", "muncher", "pellet",
## "snow_player", "snow_enemy", "snowball", "bomber", "bomb", "blast",
## "cursor_drone", "sentry", "critter".

var shape: String = "ball"
var color: Color = Color.WHITE
var color2: Color = Color.WHITE          # color secundario (detalles)
var facing_deg: float = 0.0              # 0 = arriba, 90 = derecha, etc.
var phase: float = 0.0                   # animación 0..1 continua (caminata, aleteo, mordida)
var flipped: bool = false                # espejo horizontal (mirar a la izquierda)
var seed_i: int = 0                      # semilla estable para formas irregulares (asteroides)
var alive: bool = true                   # si false, se dibuja "apagado" / no se dibuja

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_shape: String, p_color: Color, p_color2: Color = Color.WHITE, p_seed: int = 0) -> void:
	shape = p_shape
	color = p_color
	color2 = p_color2 if p_color2 != Color.WHITE else p_color.lightened(0.4)
	seed_i = p_seed
	queue_redraw()


func set_phase(p: float) -> void:
	phase = fposmod(p, 1.0)
	queue_redraw()


func set_facing(deg: float, p_flipped: bool = false) -> void:
	facing_deg = deg
	flipped = p_flipped
	queue_redraw()


func _draw() -> void:
	if not alive:
		return
	var s: Vector2 = size
	if min(s.x, s.y) <= 1.0:
		return
	_rng.seed = seed_i

	draw_set_transform(s / 2.0, deg_to_rad(facing_deg), Vector2(-1.0 if flipped else 1.0, 1.0))
	match shape:
		"ship": _draw_ship(s)
		"asteroid": _draw_asteroid(s)
		"alien": _draw_alien(s)
		"paddle": _draw_paddle(s)
		"ball": _draw_ball(s)
		"cowboy": _draw_cowboy(s)
		"bandit": _draw_bandit(s)
		"bullet": _draw_bullet(s)
		"ghost": _draw_ghost(s)
		"muncher": _draw_muncher(s)
		"pellet": _draw_pellet(s)
		"snow_player": _draw_snow_player(s)
		"snow_enemy": _draw_snow_enemy(s)
		"snowball": _draw_snowball(s)
		"bomber": _draw_bomber(s)
		"bomb": _draw_bomb(s)
		"blast": _draw_blast(s)
		"cursor_drone": _draw_cursor_drone(s)
		"sentry": _draw_sentry(s)
		"critter": _draw_critter(s)
		_: _draw_ball(s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- helpers --
func _poly(pts: PackedVector2Array, c: Color) -> void:
	draw_colored_polygon(pts, c)


func _outline(pts: PackedVector2Array, c: Color, w: float = 1.6) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, c, w, true)


# --------------------------------------------------------------- Asteroids -
func _draw_ship(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var hull := PackedVector2Array([
		Vector2(0, -h * 0.52),
		Vector2(w * 0.30, h * 0.18),
		Vector2(w * 0.20, h * 0.34),
		Vector2(w * 0.09, h * 0.26),
		Vector2(-w * 0.09, h * 0.26),
		Vector2(-w * 0.20, h * 0.34),
		Vector2(-w * 0.30, h * 0.18),
	])
	draw_colored_polygon(hull, Color(0, 0, 0, 0.3))
	var hull2 := hull.duplicate()
	for i in hull2.size():
		hull2[i] += Vector2(0, -1.5)
	_poly(hull2, color)
	_outline(hull2, color.lightened(0.5), 1.5)
	# cabina
	draw_circle(Vector2(0, -h * 0.06), w * 0.13, color2.lightened(0.3))
	draw_circle(Vector2(0, -h * 0.06), w * 0.13, Color(1, 1, 1, 0.5))
	# motor con parpadeo
	var flame_len: float = h * (0.22 + 0.14 * sin(phase * TAU * 6.0))
	var flame := PackedVector2Array([
		Vector2(-w * 0.11, h * 0.30), Vector2(w * 0.11, h * 0.30), Vector2(0, h * 0.30 + flame_len)
	])
	_poly(flame, Color(1.0, 0.7, 0.2, 0.9))
	_poly(PackedVector2Array([Vector2(-w * 0.05, h * 0.30), Vector2(w * 0.05, h * 0.30), Vector2(0, h * 0.30 + flame_len * 0.55)]), Color(1, 1, 0.6, 0.95))


func _draw_asteroid(s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.48
	var pts := PackedVector2Array()
	var n := 9
	for i in n:
		var a: float = (float(i) / n) * TAU
		var jitter: float = 0.72 + _rng.randf() * 0.32
		pts.append(Vector2(cos(a), sin(a)) * r * jitter)
	draw_colored_polygon(pts, color)
	_outline(pts, color.darkened(0.45), 2.0)
	for i in 3:
		var cp: Vector2 = pts[(i * 3 + 1) % pts.size()] * 0.55
		draw_circle(cp, r * 0.10, color.darkened(0.3))


func _draw_alien(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var flap: float = sin(phase * TAU) * w * 0.12
	# alas
	_poly(PackedVector2Array([Vector2(-w * 0.18, -h * 0.05), Vector2(-w * 0.52 - flap, h * 0.05), Vector2(-w * 0.18, h * 0.22)]), color.darkened(0.15))
	_poly(PackedVector2Array([Vector2(w * 0.18, -h * 0.05), Vector2(w * 0.52 + flap, h * 0.05), Vector2(w * 0.18, h * 0.22)]), color.darkened(0.15))
	# cuerpo
	var body := PackedVector2Array([
		Vector2(0, -h * 0.42), Vector2(w * 0.30, -h * 0.10), Vector2(w * 0.22, h * 0.30),
		Vector2(0, h * 0.44), Vector2(-w * 0.22, h * 0.30), Vector2(-w * 0.30, -h * 0.10),
	])
	_poly(body, color)
	_outline(body, color.darkened(0.4), 1.5)
	# antenas
	draw_line(Vector2(-w * 0.10, -h * 0.40), Vector2(-w * 0.18, -h * 0.56), color2, 2.0)
	draw_line(Vector2(w * 0.10, -h * 0.40), Vector2(w * 0.18, -h * 0.56), color2, 2.0)
	draw_circle(Vector2(-w * 0.18, -h * 0.56), 2.2, color2)
	draw_circle(Vector2(w * 0.18, -h * 0.56), 2.2, color2)
	# ojos
	draw_circle(Vector2(-w * 0.11, -h * 0.02), w * 0.09, Color(0.05, 0.05, 0.08))
	draw_circle(Vector2(w * 0.11, -h * 0.02), w * 0.09, Color(0.05, 0.05, 0.08))
	draw_circle(Vector2(-w * 0.13, -h * 0.05), w * 0.03, Color(1, 1, 1, 0.8))
	draw_circle(Vector2(w * 0.09, -h * 0.05), w * 0.03, Color(1, 1, 1, 0.8))


func _draw_bullet(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var pts := PackedVector2Array([Vector2(0, -h * 0.5), Vector2(w * 0.32, h * 0.2), Vector2(0, h * 0.5), Vector2(-w * 0.32, h * 0.2)])
	_poly(pts, color)
	draw_line(Vector2(0, h * 0.1), Vector2(0, h * 0.9), Color(color.r, color.g, color.b, 0.35), w * 0.4)


func _draw_sentry(s: Vector2) -> void:
	# escudo giratorio simple usado en niveles altos de Asteroids
	var r: float = min(s.x, s.y) * 0.46
	draw_arc(Vector2.ZERO, r, phase * TAU, phase * TAU + PI * 1.4, 16, color, 3.0, true)
	draw_circle(Vector2.ZERO, r * 0.4, color.darkened(0.2))


# --------------------------------------------------------------- Arkanoid --
func _draw_paddle(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var r := Rect2(-w / 2.0, -h / 2.0, w, h)
	draw_rect(r.grow(-1), color)
	draw_rect(Rect2(-w / 2.0, -h / 2.0, w, h * 0.4), color.lightened(0.35))
	draw_rect(Rect2(-w / 2.0, h * 0.1, w, h * 0.4), color.darkened(0.25))
	for i in 4:
		var x: float = -w * 0.3 + i * (w * 0.6 / 3.0)
		draw_line(Vector2(x, -h * 0.15), Vector2(x, h * 0.15), Color(1, 1, 1, 0.35), 1.5)
	draw_circle(Vector2(-w / 2.0 + 4, 0), h * 0.4, color2)
	draw_circle(Vector2(w / 2.0 - 4, 0), h * 0.4, color2)


func _draw_ball(s: Vector2) -> void:
	var r: float = min(s.x, s.y) / 2.0 - 1.0
	if r <= 1.0:
		return
	draw_circle(Vector2(1.2, 1.4), r * 0.96, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, r, color)
	draw_circle(Vector2(-r * 0.32, -r * 0.34), r * 0.32, color.lightened(0.6))
	_outline(_circle_pts(r, 16), color.darkened(0.35), 1.2)


func _circle_pts(r: float, n: int) -> PackedVector2Array:
	return _circle_pts_at(Vector2.ZERO, r, n)


func _circle_pts_at(center: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = (float(i) / n) * TAU
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_pellet(s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.22
	draw_circle(Vector2.ZERO, r, color)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.6))


# ------------------------------------------------------------- Pistoleros --
func _draw_cowboy(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var bob: float = sin(phase * TAU) * h * 0.02
	# piernas
	draw_rect(Rect2(-w * 0.14, h * 0.18 + bob, w * 0.11, h * 0.30), Color(0.30, 0.22, 0.16))
	draw_rect(Rect2(w * 0.03, h * 0.18 + bob, w * 0.11, h * 0.30), Color(0.30, 0.22, 0.16))
	# poncho/cuerpo
	var body := PackedVector2Array([
		Vector2(-w * 0.24, -h * 0.02), Vector2(w * 0.24, -h * 0.02), Vector2(w * 0.18, h * 0.22), Vector2(-w * 0.18, h * 0.22)
	])
	_poly(body, color)
	_outline(body, color.darkened(0.4), 1.4)
	# brazo con pistola
	draw_rect(Rect2(w * 0.16, h * 0.0, w * 0.22, h * 0.08), color.darkened(0.1))
	draw_rect(Rect2(w * 0.34, -h * 0.02, w * 0.08, h * 0.05), Color(0.15, 0.15, 0.17))
	# cabeza
	draw_circle(Vector2(0, -h * 0.14), w * 0.15, Color(0.85, 0.65, 0.48))
	# sombrero
	draw_arc(Vector2(0, -h * 0.22), w * 0.26, PI, TAU, 14, color2, 4.0, true)
	draw_rect(Rect2(-w * 0.11, -h * 0.34, w * 0.22, h * 0.09), color2)


func _draw_bandit(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	draw_rect(Rect2(-w * 0.14, h * 0.18, w * 0.11, h * 0.30), Color(0.18, 0.18, 0.20))
	draw_rect(Rect2(w * 0.03, h * 0.18, w * 0.11, h * 0.30), Color(0.18, 0.18, 0.20))
	var body := PackedVector2Array([
		Vector2(-w * 0.22, -h * 0.02), Vector2(w * 0.22, -h * 0.02), Vector2(w * 0.17, h * 0.22), Vector2(-w * 0.17, h * 0.22)
	])
	_poly(body, color)
	_outline(body, color.darkened(0.4), 1.4)
	draw_circle(Vector2(0, -h * 0.14), w * 0.15, Color(0.82, 0.62, 0.46))
	# paliacate / máscara
	draw_rect(Rect2(-w * 0.15, -h * 0.17, w * 0.30, h * 0.07), Color(0.15, 0.15, 0.17))
	draw_arc(Vector2(0, -h * 0.24), w * 0.24, PI, TAU, 12, Color(0.10, 0.10, 0.11), 4.0, true)
	if phase > 0.5:
		draw_circle(Vector2(w * 0.30, -h * 0.02), 3.0, Color(1, 0.9, 0.3))


# ------------------------------------------------------------- Maze Muncher-
func _draw_ghost(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var wob: float = sin(phase * TAU * 2.0) * w * 0.06
	var pts := PackedVector2Array([
		Vector2(-w * 0.42, h * 0.44), Vector2(-w * 0.42, -h * 0.05),
	])
	var top_n := 8
	for i in range(top_n + 1):
		var a: float = PI + (float(i) / top_n) * PI
		pts.append(Vector2(cos(a) * w * 0.42, sin(a) * h * 0.42 - h * 0.05))
	pts.append(Vector2(w * 0.42, h * 0.44))
	pts.append(Vector2(w * 0.28 + wob, h * 0.30))
	pts.append(Vector2(w * 0.10 - wob, h * 0.44))
	pts.append(Vector2(-w * 0.05 + wob, h * 0.30))
	pts.append(Vector2(-w * 0.24 - wob, h * 0.44))
	_poly(pts, color)
	_outline(pts, color.darkened(0.3), 1.2)
	draw_circle(Vector2(-w * 0.15, -h * 0.08), w * 0.13, Color(0.97, 0.97, 1))
	draw_circle(Vector2(w * 0.15, -h * 0.08), w * 0.13, Color(0.97, 0.97, 1))
	draw_circle(Vector2(-w * 0.15, -h * 0.02), w * 0.06, Color(0.15, 0.2, 0.5))
	draw_circle(Vector2(w * 0.15, -h * 0.02), w * 0.06, Color(0.15, 0.2, 0.5))


func _draw_muncher(s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.46
	var mouth: float = absf(sin(phase * TAU * 3.0)) * 32.0 + 4.0
	draw_circle(Vector2(0.8, 1.0), r * 0.96, Color(0, 0, 0, 0.25))
	draw_circle_arc_poly(r, mouth)
	_outline(_arc_pts(r, mouth), color.darkened(0.3), 1.2)


func draw_circle_arc_poly(r: float, mouth_deg: float) -> void:
	_poly(_arc_pts(r, mouth_deg), color)


func _arc_pts(r: float, mouth_deg: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var start: float = deg_to_rad(mouth_deg / 2.0)
	var end: float = TAU - deg_to_rad(mouth_deg / 2.0)
	var n := 18
	for i in range(n + 1):
		var a: float = start + (end - start) * (float(i) / n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


# --------------------------------------------------------------- Snow Brawl-
func _draw_snow_player(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var squash: float = 1.0 + sin(phase * TAU) * 0.04
	draw_circle(Vector2(0, h * 0.20), w * 0.34 * squash, Color(0.96, 0.97, 1.0))
	draw_circle(Vector2(0, -h * 0.14), w * 0.26 * squash, Color(0.96, 0.97, 1.0))
	_outline(_circle_pts_at(Vector2(0, h * 0.20), w * 0.34, 16), color.darkened(0.1), 1.2)
	draw_rect(Rect2(-w * 0.22, -h * 0.30, w * 0.44, h * 0.10), color)
	draw_rect(Rect2(-w * 0.30, -h * 0.24, w * 0.60, h * 0.04), color)
	draw_circle(Vector2(-w * 0.08, -h * 0.16), 2.0, Color(0.1, 0.1, 0.12))
	draw_circle(Vector2(w * 0.08, -h * 0.16), 2.0, Color(0.1, 0.1, 0.12))
	var pts := PackedVector2Array([Vector2(-3, -h * 0.06), Vector2(3, -h * 0.06), Vector2(0, -h * 0.0)])
	_poly(pts, Color(1.0, 0.55, 0.1))
	draw_line(Vector2(-w * 0.26, h * 0.20), Vector2(-w * 0.42, h * 0.08 - sin(phase * TAU) * 4.0), color2, 3.0)
	draw_line(Vector2(w * 0.26, h * 0.20), Vector2(w * 0.42, h * 0.08 + sin(phase * TAU) * 4.0), color2, 3.0)


func _draw_snow_enemy(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var wig: float = sin(phase * TAU * 4.0) * 3.0
	draw_circle(Vector2.ZERO, min(w, h) * 0.42, color)
	_outline(_circle_pts(min(w, h) * 0.42, 14), color.darkened(0.35), 1.4)
	draw_circle(Vector2(-w * 0.12 + wig, -h * 0.06), w * 0.09, Color(0.05, 0.05, 0.08))
	draw_circle(Vector2(w * 0.12 + wig, -h * 0.06), w * 0.09, Color(0.05, 0.05, 0.08))
	var mouth := PackedVector2Array([Vector2(-w * 0.14, h * 0.14), Vector2(0, h * 0.22), Vector2(w * 0.14, h * 0.14)])
	draw_polyline(mouth, Color(0.05, 0.05, 0.08), 2.0)
	draw_line(Vector2(-w * 0.30, -h * 0.28), Vector2(-w * 0.42, -h * 0.40), color2, 2.0)
	draw_line(Vector2(w * 0.30, -h * 0.28), Vector2(w * 0.42, -h * 0.40), color2, 2.0)


func _draw_snowball(s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.42
	draw_circle(Vector2.ZERO, r, Color(0.95, 0.97, 1.0))
	_outline(_circle_pts(r, 12), Color(0.75, 0.82, 0.9), 1.3)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.8))


# -------------------------------------------------------------- Bomber Maze
func _draw_bomber(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var bob: float = sin(phase * TAU * 2.0) * h * 0.02
	draw_circle(Vector2(0, h * 0.06 + bob), w * 0.34, color)
	_outline(_circle_pts_at(Vector2(0, h * 0.06 + bob), w * 0.34, 14), color.darkened(0.35), 1.3)
	draw_rect(Rect2(-w * 0.30, -h * 0.18 + bob, w * 0.60, h * 0.14), color2)
	draw_circle(Vector2(-w * 0.11, -h * 0.02 + bob), w * 0.08, Color(1, 1, 1))
	draw_circle(Vector2(w * 0.11, -h * 0.02 + bob), w * 0.08, Color(1, 1, 1))
	draw_circle(Vector2(-w * 0.11, -h * 0.02 + bob), w * 0.035, Color(0.1, 0.1, 0.12))
	draw_circle(Vector2(w * 0.11, -h * 0.02 + bob), w * 0.035, Color(0.1, 0.1, 0.12))


func _draw_bomb(s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.36
	var pulse_r: float = r * (1.0 + sin(phase * TAU * 6.0) * 0.06)
	draw_circle(Vector2(0, r * 0.1), pulse_r, Color(0.12, 0.12, 0.15))
	draw_circle(Vector2(-pulse_r * 0.3, -pulse_r * 0.1), pulse_r * 0.28, Color(1, 1, 1, 0.25))
	draw_line(Vector2(r * 0.2, -r * 0.9), Vector2(r * 0.5, -r * 1.3), Color(0.6, 0.4, 0.2), 2.5)
	var spark_on: bool = fmod(phase * 8.0, 1.0) > 0.5
	draw_circle(Vector2(r * 0.5, -r * 1.3), 3.0, Color(1, 0.8, 0.2) if spark_on else Color(1, 0.3, 0.1))


func _draw_blast(s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.5 * (0.5 + phase * 0.5)
	var a: float = 1.0 - phase
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.75, 0.2, a * 0.85))
	draw_circle(Vector2.ZERO, r * 0.6, Color(1.0, 0.95, 0.6, a))
	var n := 8
	for i in n:
		var ang: float = (float(i) / n) * TAU
		var p1: Vector2 = Vector2(cos(ang), sin(ang)) * r * 0.5
		var p2: Vector2 = Vector2(cos(ang), sin(ang)) * r
		draw_line(p1, p2, Color(1.0, 0.6, 0.15, a), 3.0)


# ------------------------------------------------------------ Panic Reveal -
func _draw_cursor_drone(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var spin: float = phase * TAU
	draw_circle(Vector2.ZERO, min(w, h) * 0.4, color)
	_outline(_circle_pts(min(w, h) * 0.4, 12), color.darkened(0.3), 1.4)
	for i in 4:
		var a: float = spin + i * (PI / 2.0)
		var p: Vector2 = Vector2(cos(a), sin(a)) * min(w, h) * 0.28
		draw_line(Vector2.ZERO, p, color2, 2.0)
		draw_circle(p, 2.2, color2)
	draw_circle(Vector2.ZERO, min(w, h) * 0.12, Color(1, 1, 1, 0.8))


func _draw_critter(s: Vector2) -> void:
	var w: float = s.x
	var h: float = s.y
	var waddle: float = sin(phase * TAU * 5.0) * w * 0.05
	var leg_a: float = sin(phase * TAU * 5.0) * h * 0.10
	draw_line(Vector2(-w * 0.14, h * 0.30), Vector2(-w * 0.14 + waddle, h * 0.44 + leg_a), color.darkened(0.3), 4.0)
	draw_line(Vector2(w * 0.14, h * 0.30), Vector2(w * 0.14 - waddle, h * 0.44 - leg_a), color.darkened(0.3), 4.0)
	draw_circle(Vector2(0, h * 0.06), w * 0.36, color)
	_outline(_circle_pts_at(Vector2(0, h * 0.06), w * 0.36, 14), color.darkened(0.35), 1.4)
	draw_circle(Vector2(0, -h * 0.22), w * 0.20, color)
	draw_circle(Vector2(-w * 0.08 + waddle, -h * 0.24), w * 0.06, Color(0.08, 0.08, 0.1))
	draw_circle(Vector2(w * 0.08 + waddle, -h * 0.24), w * 0.06, Color(0.08, 0.08, 0.1))
	draw_line(Vector2(-w * 0.10, -h * 0.36), Vector2(-w * 0.16, -h * 0.46), color2, 2.0)
	draw_line(Vector2(w * 0.10, -h * 0.36), Vector2(w * 0.16, -h * 0.46), color2, 2.0)
	draw_circle(Vector2(-w * 0.16, -h * 0.46), 2.0, color2)
	draw_circle(Vector2(w * 0.16, -h * 0.46), 2.0, color2)
