class_name PlayingCard
extends Button
## Carta de baraja dibujada (esquina con rango+palo, símbolo grande al centro,
## respaldo con patrón), no texto plano centrado.

const RED_SUITS := ["♥", "♦"]
const FACE_COLOR := Color(0.97, 0.96, 0.93)
const BACK_COLOR := Color(0.306, 0.804, 0.769)
const BACK_PATTERN := Color(0.145, 0.157, 0.216, 0.55)
const BORDER_COLOR := Color(0.12, 0.13, 0.17)
const HIGHLIGHT_COLOR := Color(1.0, 0.820, 0.400)
const EMPTY_COLOR := Color(0.180, 0.196, 0.271, 0.5)

var rank: int = 1
var suit: String = "♠"
var face_up: bool = true
var highlighted: bool = false
var is_empty_slot: bool = false
var hint_text: String = ""


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE


func set_card(new_rank: int, new_suit: String, up: bool = true) -> void:
	rank = new_rank
	suit = new_suit
	face_up = up
	is_empty_slot = false
	queue_redraw()


func set_empty(hint: String = "") -> void:
	is_empty_slot = true
	hint_text = hint
	queue_redraw()


func set_highlighted(v: bool) -> void:
	highlighted = v
	queue_redraw()


func _rank_label(r: int) -> String:
	match r:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_: return str(r)


func _draw() -> void:
	var s: Vector2 = size
	var border: Color = HIGHLIGHT_COLOR if highlighted else BORDER_COLOR
	var border_width: float = 3.0 if highlighted else 1.5

	if is_empty_slot:
		draw_rect(Rect2(Vector2.ZERO, s), EMPTY_COLOR, true)
		draw_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), border, false, border_width)
		if hint_text != "":
			var font: Font = ThemeDB.fallback_font
			draw_string(font, Vector2(0, s.y * 0.58), hint_text, HORIZONTAL_ALIGNMENT_CENTER, s.x, int(s.y * 0.3), Color(1, 1, 1, 0.5))
		return

	if not face_up:
		draw_rect(Rect2(Vector2.ZERO, s), BACK_COLOR, true)
		draw_rect(Rect2(s.x * 0.14, s.y * 0.14, s.x * 0.72, s.y * 0.72), BACK_PATTERN, true)
		draw_rect(Rect2(Vector2.ZERO, s), border, false, border_width)
		return

	draw_rect(Rect2(Vector2.ZERO, s), FACE_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, s), border, false, border_width)

	var is_red: bool = RED_SUITS.has(suit)
	var color: Color = Color(0.80, 0.14, 0.20) if is_red else Color(0.10, 0.10, 0.13)
	var font: Font = ThemeDB.fallback_font
	var rank_text: String = _rank_label(rank)
	var corner_size: int = int(clamp(s.y * 0.20, 8, 22))

	draw_string(font, Vector2(s.x * 0.08, s.y * 0.26), rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, corner_size, color)
	draw_string(font, Vector2(s.x * 0.08, s.y * 0.26 + corner_size * 0.95), suit, HORIZONTAL_ALIGNMENT_LEFT, -1, corner_size, color)

	var big_size: int = int(clamp(s.y * 0.42, 12, 40))
	draw_string(font, Vector2(0, s.y * 0.72), suit, HORIZONTAL_ALIGNMENT_CENTER, s.x, big_size, color)
