extends Control
## Solitario Araña (Spider), variante de 1 palo (la más sencilla): 104
## cartas de picas, 10 columnas. Igual que el Solitario Klondike de esta
## colección, solo se puede tomar y mover la carta de hasta arriba de
## cada columna (no arrastrar secuencias completas).

const GAME_ID := "spider_solitaire"
const SUIT := "♠"
const NUM_COLS := 10
const NEEDED_STACKS := 8

const HELP_TEXT := "Objetivo: formar 8 secuencias completas de Rey a As (mismo palo) para ganar.

- Toca el mazo (arriba a la izquierda) para repartir una carta nueva a cada una de las 10 columnas (no puedes repartir si alguna columna está vacía).
- Toca la carta de hasta arriba de una columna para seleccionarla (queda con borde amarillo).
- Toca otra columna para moverla ahí, si su carta superior es exactamente un número más alta (por ejemplo, un 5 sobre un 6), o si esa columna está vacía.
- Cuando completas una secuencia K,Q,J,10...A de arriba hacia abajo en una columna, se retira sola y suma a tu contador.
- Solo se mueve la carta superior de cada pila (versión simplificada, sin arrastrar secuencias)."

var stock: Array = []
var tableau: Array = []
var selected: Dictionary = {}
var completed_stacks: int = 0
var game_over: bool = false

var status_label: Label
var stock_btn: PlayingCard
var stacks_label: Label
var tableau_containers: Array = []


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
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Solitario Araña", HELP_TEXT)

	status_label = UIKit.title_label("", 18, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	stock_btn = _make_card_button()
	stock_btn.pressed.connect(_on_stock_pressed)
	top_row.add_child(stock_btn)

	stacks_label = UIKit.title_label("Secuencias completas: 0/8", 16, UIKit.COLOR_ACCENT_3)
	top_row.add_child(stacks_label)

	var tableau_row := HBoxContainer.new()
	tableau_row.add_theme_constant_override("separation", 4)
	vbox.add_child(tableau_row)

	for col in range(NUM_COLS):
		var col_control := Control.new()
		col_control.custom_minimum_size = Vector2(70, 780)
		tableau_row.add_child(col_control)
		tableau_containers.append(col_control)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_card_button() -> PlayingCard:
	var card := PlayingCard.new()
	card.custom_minimum_size = Vector2(64, 90)
	card.set_empty()
	return card


func _build_deck() -> Array:
	var deck: Array = []
	for set_i in range(8):
		for rank in range(1, 14):
			deck.append({"rank": rank, "suit": SUIT, "up": false})
	deck.shuffle()
	return deck


func _new_game() -> void:
	selected = {}
	completed_stacks = 0
	game_over = false
	tableau.clear()

	var deck := _build_deck()
	for col in range(NUM_COLS):
		var count: int = 6 if col < 4 else 5
		var pile: Array = []
		for i in range(count):
			var card: Dictionary = deck.pop_back()
			card["up"] = i == count - 1
			pile.append(card)
		tableau.append(pile)

	stock = deck

	status_label.text = "Toca el mazo para repartir y arma secuencias K a As"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
	_redraw_all()


func _can_deal() -> bool:
	if stock.is_empty():
		return false
	for pile: Array in tableau:
		if pile.is_empty():
			return false
	return true


func _redraw_all() -> void:
	if stock.is_empty():
		_render_empty(stock_btn, "")
		stock_btn.disabled = true
	else:
		_render_back(stock_btn)
		stock_btn.disabled = not _can_deal()

	stacks_label.text = "Secuencias completas: %d/%d" % [completed_stacks, NEEDED_STACKS]

	for col in range(NUM_COLS):
		var container: Control = tableau_containers[col]
		for child: Node in container.get_children():
			child.queue_free()

		var pile: Array = tableau[col]
		if pile.is_empty():
			var placeholder := _make_card_button()
			_render_empty(placeholder, "")
			placeholder.position = Vector2.ZERO
			placeholder.pressed.connect(_on_tableau_pressed.bind(col))
			container.add_child(placeholder)
			continue

		for i in range(pile.size()):
			var y := i * 24
			var card: Dictionary = pile[i]
			if i == pile.size() - 1:
				var btn := _make_card_button()
				var is_selected: bool = selected.get("col", -1) == col
				btn.disabled = false
				btn.set_card(card["rank"], card["suit"], true)
				btn.set_highlighted(is_selected)
				btn.position = Vector2(0, y)
				btn.pressed.connect(_on_tableau_pressed.bind(col))
				container.add_child(btn)
			else:
				var strip := PlayingCard.new()
				strip.custom_minimum_size = Vector2(64, 24)
				strip.disabled = true
				if card["up"]:
					strip.set_card(card["rank"], card["suit"], true)
				else:
					strip.set_card(0, SUIT, false)
				strip.position = Vector2(0, y)
				container.add_child(strip)


func _render_empty(card_view: PlayingCard, hint: String) -> void:
	card_view.disabled = false
	card_view.set_empty(hint)


func _render_back(card_view: PlayingCard) -> void:
	card_view.disabled = false
	card_view.set_card(0, SUIT, false)


func _on_stock_pressed() -> void:
	if not _can_deal():
		if stock.is_empty():
			return
		status_label.text = "No puedes repartir: alguna columna está vacía"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		return

	for col in range(NUM_COLS):
		var card: Dictionary = stock.pop_back()
		card["up"] = true
		tableau[col].append(card)

	selected = {}
	for col in range(NUM_COLS):
		_check_completed(col)
	_redraw_all()
	_check_win()


func _on_tableau_pressed(col: int) -> void:
	if game_over:
		return
	var pile: Array = tableau[col]

	if selected.is_empty():
		if pile.is_empty():
			return
		selected = {"col": col}
		_redraw_all()
		return

	var src_col: int = selected["col"]
	if src_col == col:
		selected = {}
		_redraw_all()
		return

	var src_pile: Array = tableau[src_col]
	if src_pile.is_empty():
		selected = {}
		_redraw_all()
		return
	var card: Dictionary = src_pile.back()

	var can_place := false
	if pile.is_empty():
		can_place = true
	else:
		var top: Dictionary = pile.back()
		can_place = top["rank"] == card["rank"] + 1

	if can_place:
		src_pile.pop_back()
		if not src_pile.is_empty() and not src_pile.back()["up"]:
			src_pile.back()["up"] = true
		tableau[col].append(card)
		selected = {}
		_check_completed(col)
		_redraw_all()
		_check_win()
	elif not pile.is_empty():
		selected = {"col": col}
		_redraw_all()
	else:
		selected = {}
		_redraw_all()


func _check_completed(col: int) -> void:
	var pile: Array = tableau[col]
	if pile.size() < 13:
		return
	var start: int = pile.size() - 13
	for k in range(13):
		var card: Dictionary = pile[start + k]
		if not card["up"] or card["rank"] != 13 - k:
			return

	for k in range(13):
		pile.remove_at(pile.size() - 1)
	completed_stacks += 1
	AudioManager.play_win()
	if not pile.is_empty() and not pile.back()["up"]:
		pile.back()["up"] = true


func _check_win() -> void:
	if completed_stacks < NEEDED_STACKS:
		return
	game_over = true
	status_label.text = "¡Ganaste! Completaste las 8 secuencias"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	_record_result()


func _record_result() -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats["wins"] = stats.get("wins", 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
