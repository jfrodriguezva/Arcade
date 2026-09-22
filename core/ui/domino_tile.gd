class_name DominoTile
extends Button
## Ficha de dominó dibujada (puntos reales), no texto. Se usa tanto en
## la mano del jugador (clicable) como en la cadena jugada (decorativa).

const PIP_LAYOUTS := {
	0: [],
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [
		Vector2(0.27, 0.22), Vector2(0.73, 0.22),
		Vector2(0.27, 0.5), Vector2(0.73, 0.5),
		Vector2(0.27, 0.78), Vector2(0.73, 0.78),
	],
}

const TILE_COLOR := Color(0.96, 0.95, 0.92)
const PIP_COLOR := Color(0.12, 0.12, 0.15)
const DIVIDER_COLOR := Color(0.6, 0.6, 0.58)
const BORDER_COLOR := Color(0.12, 0.13, 0.17)
const HIGHLIGHT_COLOR := Color(1.0, 0.820, 0.400)

var value_a: int = 0
var value_b: int = 0
var vertical: bool = false
var highlighted: bool = false


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE


func set_values(a: int, b: int, is_vertical: bool = false) -> void:
	value_a = a
	value_b = b
	vertical = is_vertical
	queue_redraw()


func set_highlighted(v: bool) -> void:
	highlighted = v
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, s), TILE_COLOR, true)

	var rect_a: Rect2
	var rect_b: Rect2
	if vertical:
		var half := Vector2(s.x, s.y / 2.0)
		rect_a = Rect2(Vector2.ZERO, half)
		rect_b = Rect2(Vector2(0, s.y / 2.0), half)
		draw_line(Vector2(4, s.y / 2.0), Vector2(s.x - 4, s.y / 2.0), DIVIDER_COLOR, 1.5)
	else:
		var half := Vector2(s.x / 2.0, s.y)
		rect_a = Rect2(Vector2.ZERO, half)
		rect_b = Rect2(Vector2(s.x / 2.0, 0), half)
		draw_line(Vector2(s.x / 2.0, 4), Vector2(s.x / 2.0, s.y - 4), DIVIDER_COLOR, 1.5)

	_draw_pips(rect_a, value_a)
	_draw_pips(rect_b, value_b)

	var border: Color = HIGHLIGHT_COLOR if highlighted else BORDER_COLOR
	draw_rect(Rect2(Vector2.ZERO, s), border, false, 3.0 if highlighted else 2.0)


func _draw_pips(rect: Rect2, value: int) -> void:
	var radius: float = min(rect.size.x, rect.size.y) * 0.1
	for p: Vector2 in PIP_LAYOUTS.get(value, []):
		var center: Vector2 = rect.position + Vector2(rect.size.x * p.x, rect.size.y * p.y)
		draw_circle(center, radius, PIP_COLOR)
