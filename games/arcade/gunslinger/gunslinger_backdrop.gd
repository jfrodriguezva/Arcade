class_name GunslingerBackdrop
extends Control
## Telón de fondo pintado para "Pistoleros del Ocaso": cielo de atardecer
## degradado, sol bajo en el horizonte y mesas/cactus en silueta. Se dibuja
## una sola vez (no depende de _process) para vender la ambientación de
## pueblo del Viejo Oeste sin costo por fotograma.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return

	# Cielo: degradado vertical de púrpura de noche a naranja de atardecer.
	var bands := 20
	for i in range(bands):
		var t0: float = float(i) / bands
		var t1: float = float(i + 1) / bands
		draw_rect(Rect2(0, h * t0, w, h * (t1 - t0) + 1.0), _sky_color(t0), true)

	# Sol bajo, con halo suave, apenas sobre la línea de horizonte.
	var sun_center := Vector2(w * 0.74, h * 0.60)
	var sun_r: float = h * 0.15
	draw_circle(sun_center, sun_r * 1.8, Color(1.0, 0.55, 0.25, 0.14))
	draw_circle(sun_center, sun_r * 1.25, Color(1.0, 0.62, 0.28, 0.28))
	draw_circle(sun_center, sun_r, Color(1.0, 0.80, 0.40, 0.92))
	draw_circle(sun_center, sun_r * 0.65, Color(1.0, 0.92, 0.65, 0.95))

	# Mesas / colinas distantes en silueta.
	var mesa_color := Color(0.27, 0.13, 0.17)
	_draw_mesa(w * -0.02, h * 0.68, w * 0.30, h * 0.16, mesa_color)
	_draw_mesa(w * 0.26, h * 0.75, w * 0.24, h * 0.10, mesa_color.darkened(0.12))
	_draw_mesa(w * 0.55, h * 0.70, w * 0.32, h * 0.18, mesa_color)
	_draw_mesa(w * 0.84, h * 0.76, w * 0.22, h * 0.12, mesa_color.darkened(0.12))

	# Cactus decorativos recortados contra el horizonte.
	_draw_cactus(w * 0.09, h * 0.82, h * 0.11)
	_draw_cactus(w * 0.93, h * 0.84, h * 0.09)


func _sky_color(t: float) -> Color:
	var top := Color(0.12, 0.08, 0.21)
	var mid := Color(0.58, 0.23, 0.30)
	var bottom := Color(0.96, 0.58, 0.30)
	if t < 0.55:
		return top.lerp(mid, t / 0.55)
	return mid.lerp(bottom, (t - 0.55) / 0.45)


func _draw_mesa(x: float, y: float, mw: float, mh: float, c: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(x, y + mh), Vector2(x + mw * 0.15, y + mh * 0.30), Vector2(x + mw * 0.35, y + mh * 0.30),
		Vector2(x + mw * 0.40, y), Vector2(x + mw * 0.70, y), Vector2(x + mw * 0.75, y + mh * 0.30),
		Vector2(x + mw, y + mh * 0.30), Vector2(x + mw, y + mh),
	])
	draw_colored_polygon(pts, c)


func _draw_cactus(x: float, y: float, ch: float) -> void:
	var c := Color(0.20, 0.32, 0.21)
	draw_rect(Rect2(x - ch * 0.09, y - ch, ch * 0.18, ch), c)
	draw_rect(Rect2(x - ch * 0.34, y - ch * 0.62, ch * 0.25, ch * 0.12), c)
	draw_rect(Rect2(x - ch * 0.34, y - ch * 0.78, ch * 0.12, ch * 0.36), c)
	draw_rect(Rect2(x + ch * 0.09, y - ch * 0.78, ch * 0.25, ch * 0.12), c)
	draw_rect(Rect2(x + ch * 0.22, y - ch * 0.94, ch * 0.12, ch * 0.32), c)
