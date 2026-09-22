class_name GamePiece
extends Control
## Ficha/canica dibujada con sombra + brillo, para reemplazar el
## carácter "●" plano en Damas, Otelo, Damas Chinas y Backgammon.
## Se agrega como hijo de la celda (Button) y se muestra/oculta
## y recolorea en cada redraw; no bloquea el click de la celda.

var piece_color: Color = Color.WHITE
var show_piece: bool = false
var is_king: bool = false
var ring_color: Color = Color(0, 0, 0, 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_piece(color: Color, king: bool = false) -> void:
	piece_color = color
	is_king = king
	show_piece = true
	queue_redraw()


func hide_piece() -> void:
	show_piece = false
	queue_redraw()


func set_ring(color: Color) -> void:
	ring_color = color
	queue_redraw()


func _draw() -> void:
	if not show_piece:
		return

	var s: Vector2 = size
	var center: Vector2 = s / 2.0
	var radius: float = min(s.x, s.y) / 2.0 - 2.0
	if radius <= 1.0:
		return

	draw_circle(center + Vector2(0, radius * 0.14), radius * 0.94, Color(0, 0, 0, 0.35))
	draw_circle(center, radius, piece_color)
	draw_circle(center - Vector2(radius * 0.3, radius * 0.32), radius * 0.34, piece_color.lightened(0.55))
	draw_arc(center, radius - 1.0, 0, TAU, 28, piece_color.darkened(0.4), 2.0, true)

	if is_king:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(0, s.y * 0.66), "♛", HORIZONTAL_ALIGNMENT_CENTER, s.x, int(radius * 1.15), Color(1, 1, 1))

	if ring_color.a > 0:
		draw_arc(center, radius + 3.0, 0, TAU, 28, ring_color, 3.0, true)
