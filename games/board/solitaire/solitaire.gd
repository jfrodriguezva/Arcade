extends Control
## Solitario Klondike simplificado: solo se puede tomar y mover la carta
## de hasta arriba de cada pila (no secuencias completas). Sigue siendo
## un solitario completo y jugable, solo más fácil de operar por toques.

const GAME_ID := "solitaire"
const SUITS := ["♠", "♥", "♦", "♣"]
const RED_SUITS := ["♥", "♦"]

const HELP_TEXT := "Objetivo: enviar las 52 cartas a los 4 fundamentos (arriba a la derecha), ordenadas por palo de As a Rey.

- Toca el mazo (arriba a la izquierda) para robar una carta.
- Toca la carta de hasta arriba de una columna o del descarte para seleccionarla (queda con borde amarillo).
- Toca otra columna para moverla ahí, si el color alterna (rojo/negro) y el número es uno menos.
- Toca un fundamento para enviarla si sigue la secuencia A, 2, 3... del mismo palo.
- Solo se mueve la carta superior de cada pila (versión simplificada, sin arrastrar secuencias)."

var stock: Array = []
var waste: Array = []
var foundations: Dictionary = {}
var tableau: Array = []
var selected: Dictionary = {}

var status_label: Label
var stock_btn: PlayingCard
var waste_btn: PlayingCard
var foundation_buttons: Dictionary = {}
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

	UIKit.build_toolbar(vbox, self, "Solitario", HELP_TEXT)

	status_label = UIKit.title_label("", 18, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	stock_btn = _make_card_button()
	stock_btn.pressed.connect(_on_stock_pressed)
	top_row.add_child(stock_btn)

	waste_btn = _make_card_button()
	waste_btn.pressed.connect(_on_waste_pressed)
	top_row.add_child(waste_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(20, 1)
	top_row.add_child(spacer)

	for suit: String in SUITS:
		var f_btn := _make_card_button()
		f_btn.pressed.connect(_on_foundation_pressed.bind(suit))
		top_row.add_child(f_btn)
		foundation_buttons[suit] = f_btn

	var tableau_row := HBoxContainer.new()
	tableau_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tableau_row)

	for col in range(7):
		var col_control := Control.new()
		col_control.custom_minimum_size = Vector2(72, 460)
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
	for suit: String in SUITS:
		for rank in range(1, 14):
			deck.append({"suit": suit, "rank": rank})
	deck.shuffle()
	return deck


func _new_game() -> void:
	selected = {}
	foundations = {"♠": [], "♥": [], "♦": [], "♣": []}
	tableau.clear()

	var deck := _build_deck()
	for col in range(7):
		var pile: Array = []
		for i in range(col + 1):
			pile.append(deck.pop_back())
		tableau.append(pile)

	stock = deck
	waste.clear()

	status_label.text = "Toca el mazo para robar y arma las secuencias"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
	_redraw_all()


func _redraw_all() -> void:
	if stock.is_empty():
		_render_empty(stock_btn, "↻")
	else:
		_render_back(stock_btn)

	if waste.is_empty():
		_render_empty(waste_btn, "")
	else:
		_render_card(waste_btn, waste.back(), selected.get("source", "") == "waste")
	waste_btn.disabled = waste.is_empty()

	for suit: String in SUITS:
		var pile: Array = foundations[suit]
		var btn: PlayingCard = foundation_buttons[suit]
		if pile.is_empty():
			_render_empty(btn, suit)
		else:
			_render_card(btn, pile.back())

	for col in range(7):
		var container: Control = tableau_containers[col]
		for child: Node in container.get_children():
			child.queue_free()

		var pile: Array = tableau[col]
		if pile.is_empty():
			var placeholder := _make_card_button()
			_render_empty(placeholder, "K")
			placeholder.position = Vector2.ZERO
			placeholder.pressed.connect(_on_tableau_pressed.bind(col))
			container.add_child(placeholder)
			continue

		for i in range(pile.size()):
			var y := i * 24
			if i == pile.size() - 1:
				var btn := _make_card_button()
				var is_selected: bool = selected.get("source", "") == "tableau" and selected.get("col", -1) == col
				_render_card(btn, pile[i], is_selected)
				btn.position = Vector2(0, y)
				btn.pressed.connect(_on_tableau_pressed.bind(col))
				container.add_child(btn)
			else:
				var strip := PlayingCard.new()
				strip.custom_minimum_size = Vector2(64, 24)
				strip.disabled = true
				strip.set_card(0, "♠", false)
				strip.position = Vector2(0, y)
				container.add_child(strip)


func _render_card(card_view: PlayingCard, card: Dictionary, highlighted: bool = false) -> void:
	card_view.disabled = false
	card_view.set_card(card["rank"], card["suit"], true)
	card_view.set_highlighted(highlighted)


func _render_empty(card_view: PlayingCard, hint: String) -> void:
	card_view.disabled = false
	card_view.set_empty(hint)


func _render_back(card_view: PlayingCard) -> void:
	card_view.disabled = false
	card_view.set_card(0, "♠", false)


func _on_stock_pressed() -> void:
	if stock.is_empty():
		waste.reverse()
		stock = waste.duplicate()
		waste.clear()
	else:
		waste.append(stock.pop_back())
	selected = {}
	_redraw_all()


func _on_waste_pressed() -> void:
	if waste.is_empty():
		return
	if selected.get("source", "") == "waste":
		selected = {}
	else:
		selected = {"source": "waste", "card": waste.back()}
	_redraw_all()


func _on_tableau_pressed(col: int) -> void:
	var pile: Array = tableau[col]

	if selected.is_empty():
		if pile.is_empty():
			return
		selected = {"source": "tableau", "col": col, "card": pile.back()}
		_redraw_all()
		return

	if selected.get("source", "") == "tableau" and selected.get("col", -1) == col:
		selected = {}
		_redraw_all()
		return

	var card: Dictionary = selected["card"]
	var can_place := false
	if pile.is_empty():
		can_place = card["rank"] == 13
	else:
		var top: Dictionary = pile.back()
		var top_red: bool = RED_SUITS.has(top["suit"])
		var card_red: bool = RED_SUITS.has(card["suit"])
		can_place = top_red != card_red and top["rank"] == card["rank"] + 1

	if can_place:
		_remove_selected_card()
		tableau[col].append(card)
		selected = {}
		_redraw_all()
		_check_win()
	elif not pile.is_empty():
		selected = {"source": "tableau", "col": col, "card": pile.back()}
		_redraw_all()
	else:
		selected = {}
		_redraw_all()


func _on_foundation_pressed(suit: String) -> void:
	if selected.is_empty():
		return

	var card: Dictionary = selected["card"]
	if card["suit"] != suit:
		selected = {}
		_redraw_all()
		return

	var pile: Array = foundations[suit]
	var needed_rank: int = pile.size() + 1
	if card["rank"] == needed_rank:
		_remove_selected_card()
		foundations[suit].append(card)
		selected = {}
		_redraw_all()
		_check_win()
	else:
		selected = {}
		_redraw_all()


func _remove_selected_card() -> void:
	if selected["source"] == "waste":
		waste.pop_back()
	else:
		var col: int = selected["col"]
		tableau[col].pop_back()


func _check_win() -> void:
	for suit: String in SUITS:
		if foundations[suit].size() < 13:
			return
	status_label.text = "¡Ganaste! Las 4 secuencias están completas"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	_record_result()


func _record_result() -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats["wins"] = stats.get("wins", 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
