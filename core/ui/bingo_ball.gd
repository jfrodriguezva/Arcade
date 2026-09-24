class_name BingoBall
extends Control
## Bola de bingo dibujada (sombra + brillo + aro, como GamePiece) con la
## letra y el número de la bola cantada, en vez de un emoji plano.

var letter: String = ""
var number: int = 0
var ball_color: Color = Color.WHITE
var has_value: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_ball(new_letter: String, new_number: int, color: Color) -> void:
	letter = new_letter
	number = new_number
	ball_color = color
	has_value = true
	queue_redraw()


func clear_ball() -> void:
	has_value = false
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	var center: Vector2 = s / 2.0
	var radius: float = min(s.x, s.y) / 2.0 - 2.0
	if radius <= 1.0:
		return

	if not has_value:
		draw_circle(center, radius, Color(0.180, 0.196, 0.271, 0.5))
		draw_arc(center, radius - 1.0, 0, TAU, 32, Color(0.62, 0.64, 0.70, 0.6), 2.0, true)
		var hint_font: Font = ThemeDB.fallback_font
		draw_string(hint_font, Vector2(0, s.y * 0.5 + radius * 0.12), "?", HORIZONTAL_ALIGNMENT_CENTER, s.x, int(radius * 0.7), Color(0.62, 0.64, 0.70, 0.6))
		return

	draw_circle(center + Vector2(0, radius * 0.12), radius * 0.97, Color(0, 0, 0, 0.35))
	draw_circle(center, radius, ball_color)
	draw_circle(center - Vector2(radius * 0.32, radius * 0.34), radius * 0.32, ball_color.lightened(0.55))
	draw_arc(center, radius - 1.5, 0, TAU, 32, ball_color.darkened(0.45), 2.5, true)

	var font: Font = ThemeDB.fallback_font
	var text: String = "%s-%d" % [letter, number]
	var font_size: int = int(clamp(radius * 0.56, 10, 30))
	var text_color: Color = Color.WHITE if ball_color.get_luminance() < 0.6 else Color(0.1, 0.1, 0.13)
	draw_string(font, Vector2(0, s.y * 0.5 + font_size * 0.34), text, HORIZONTAL_ALIGNMENT_CENTER, s.x, font_size, text_color)
