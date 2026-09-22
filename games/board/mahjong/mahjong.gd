extends Control
## Mahjong Solitario (parejas). Dos capas: una base de 8x6 y una capa
## elevada de 4x4 en el centro que la cubre. Una ficha se puede tomar
## si no tiene nada encima y al menos uno de sus lados (izquierda o
## derecha) está libre — igual que el Mahjong solitario clásico, en
## versión de 2 niveles en vez de la pirámide completa de 5.

const GAME_ID := "mahjong"
const COLS := 8
const ROWS := 6
const CELL_W := 44
const CELL_H := 58

const KINDS := [
	"Bambú 1", "Bambú 2", "Bambú 3", "Bambú 4", "Bambú 5", "Bambú 6", "Bambú 7", "Bambú 8", "Bambú 9",
	"Círculo 1", "Círculo 2", "Círculo 3", "Círculo 4", "Círculo 5", "Círculo 6", "Círculo 7", "Círculo 8", "Círculo 9",
	"Carácter 1", "Carácter 2", "Carácter 3", "Carácter 4", "Carácter 5", "Carácter 6", "Carácter 7", "Carácter 8", "Carácter 9",
	"Norte", "Sur", "Este", "Oeste",
	"Dragón Rojo",
]

const HELP_TEXT := "Encuentra y toca dos fichas iguales para quitarlas del tablero.

Solo puedes tomar una ficha si:
- No tiene otra ficha encima (las de la capa elevada, con borde amarillo, tapan a las de abajo).
- Al menos uno de sus lados, izquierdo o derecho, está libre (sin ficha contigua en esa capa).

Si te quedas sin movimientos posibles, toca 'Nueva partida'. Ganas cuando el tablero queda vacío."

var tiles: Array = []
var selected_index: int = -1
var game_over: bool = false

var status_label: Label
var canvas: Control


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
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Mahjong Solitario", HELP_TEXT)

	status_label = UIKit.title_label("", 18, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 2))
	var board_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		board_margin.add_theme_constant_override(side, 12)
	board_panel.add_child(board_margin)

	var center := CenterContainer.new()
	vbox.add_child(center)
	center.add_child(board_panel)

	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(COLS * CELL_W + 8, ROWS * CELL_H + 8)
	board_margin.add_child(canvas)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _new_game() -> void:
	var pool: Array = []
	for k: String in KINDS:
		pool.append(k)
		pool.append(k)
	pool.shuffle()

	tiles = []
	var idx := 0
	for r in range(ROWS):
		for c in range(COLS):
			tiles.append({"kind": pool[idx], "layer": 0, "row": r, "col": c, "removed": false, "btn": null})
			idx += 1
	for r in range(1, 5):
		for c in range(2, 6):
			tiles.append({"kind": pool[idx], "layer": 1, "row": r, "col": c, "removed": false, "btn": null})
			idx += 1

	selected_index = -1
	game_over = false
	status_label.text = "Toca dos fichas iguales para quitarlas"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
	_build_tile_buttons()
	_redraw_all()


func _build_tile_buttons() -> void:
	for child: Node in canvas.get_children():
		child.queue_free()

	for i in range(tiles.size()):
		var t: Dictionary = tiles[i]
		var btn := Button.new()
		var base_x: float = t["col"] * CELL_W
		var base_y: float = t["row"] * CELL_H
		if t["layer"] == 1:
			btn.position = Vector2(base_x - 4, base_y - 4)
			btn.size = Vector2(CELL_W - 4, CELL_H - 4)
		else:
			btn.position = Vector2(base_x + 2, base_y + 2)
			btn.size = Vector2(CELL_W - 4, CELL_H - 4)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_tile_pressed.bind(i))
		canvas.add_child(btn)
		tiles[i]["btn"] = btn


func _short_label(kind: String) -> String:
	if kind.begins_with("Bambú"):
		return "B" + kind.split(" ")[1]
	if kind.begins_with("Círculo"):
		return "C" + kind.split(" ")[1]
	if kind.begins_with("Carácter"):
		return "M" + kind.split(" ")[1]
	if kind == "Dragón Rojo":
		return "D"
	return kind.substr(0, 1)


func _suit_color(kind: String) -> Color:
	if kind.begins_with("Bambú"):
		return UIKit.COLOR_ACCENT_2
	if kind.begins_with("Círculo"):
		return UIKit.COLOR_ACCENT_3
	if kind.begins_with("Carácter"):
		return UIKit.COLOR_ACCENT
	if kind == "Dragón Rojo":
		return UIKit.COLOR_DANGER
	return UIKit.COLOR_TEXT


func _find_tile_index(layer: int, row: int, col: int) -> int:
	for i in range(tiles.size()):
		var t: Dictionary = tiles[i]
		if t["layer"] == layer and t["row"] == row and t["col"] == col and not t["removed"]:
			return i
	return -1


func _is_covered(i: int) -> bool:
	var t: Dictionary = tiles[i]
	if t["layer"] >= 1:
		return false
	return _find_tile_index(t["layer"] + 1, t["row"], t["col"]) != -1


func _is_open(i: int) -> bool:
	if tiles[i]["removed"] or _is_covered(i):
		return false
	var t: Dictionary = tiles[i]
	var left_free: bool = _find_tile_index(t["layer"], t["row"], t["col"] - 1) == -1
	var right_free: bool = _find_tile_index(t["layer"], t["row"], t["col"] + 1) == -1
	return left_free or right_free


func _redraw_all() -> void:
	for i in range(tiles.size()):
		var t: Dictionary = tiles[i]
		var btn: Button = t["btn"]
		if t["removed"]:
			btn.visible = false
			continue

		btn.visible = true
		btn.text = _short_label(t["kind"])

		var open: bool = _is_open(i)
		var is_selected: bool = i == selected_index
		var border: Color = UIKit.COLOR_ACCENT_3 if (t["layer"] == 1) else Color(0, 0, 0, 0)
		if is_selected:
			border = UIKit.COLOR_TEXT
		var bw: int = 3 if (is_selected or t["layer"] == 1) else 1

		var bg: Color = UIKit.COLOR_PANEL if open else UIKit.COLOR_BG.lerp(UIKit.COLOR_PANEL, 0.4)
		btn.add_theme_stylebox_override("normal", UIKit.stylebox(bg, border, 6, bw))
		btn.add_theme_stylebox_override("disabled", UIKit.stylebox(bg, border, 6, bw))
		btn.disabled = not open

		var color: Color = _suit_color(t["kind"]) if open else UIKit.COLOR_TEXT_DIM
		btn.add_theme_color_override("font_color", color)
		btn.add_theme_color_override("font_disabled_color", color)


func _on_tile_pressed(i: int) -> void:
	if game_over or not _is_open(i):
		return

	if selected_index == -1:
		selected_index = i
		_redraw_all()
		return

	if selected_index == i:
		selected_index = -1
		_redraw_all()
		return

	if tiles[selected_index]["kind"] == tiles[i]["kind"]:
		tiles[selected_index]["removed"] = true
		tiles[i]["removed"] = true
		selected_index = -1
		_redraw_all()
		_check_win()
		if not game_over:
			_check_stuck()
	else:
		selected_index = i
		_redraw_all()


func _has_moves() -> bool:
	var open_kinds: Dictionary = {}
	for i in range(tiles.size()):
		if tiles[i]["removed"]:
			continue
		if _is_open(i):
			var k: String = tiles[i]["kind"]
			if open_kinds.has(k):
				return true
			open_kinds[k] = true
	return false


func _check_win() -> void:
	for t: Dictionary in tiles:
		if not t["removed"]:
			return
	game_over = true
	status_label.text = "¡Completaste el tablero!"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	_record_result()


func _check_stuck() -> void:
	if not _has_moves():
		game_over = true
		status_label.text = "Sin movimientos posibles. Toca 'Nueva partida'"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)


func _record_result() -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats["wins"] = stats.get("wins", 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
