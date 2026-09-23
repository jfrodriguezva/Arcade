extends Control
## Dominó clásico (set doble-seis, 28 fichas) contra la máquina.
## Gana quien se quede sin fichas primero; si el juego se tranca
## (nadie puede jugar y ya no hay pozo), gana quien tenga menos
## puntos sumados en la mano.

const GAME_ID := "domino"

const HELP_TEXT := "Cada quien empieza con 7 fichas; el resto queda en el pozo.

- Toca una ficha de tu mano para seleccionarla.
- Toca 'Extremo izquierdo' o 'Extremo derecho' para colocarla ahí, si alguno de sus números coincide con ese extremo.
- Si ninguna ficha te sirve, toca 'Robar' para tomar del pozo.
- Si no puedes jugar y el pozo está vacío, toca 'Pasar'.

Gana quien se quede sin fichas primero. Si el juego se tranca (nadie puede jugar), gana quien tenga menos puntos sumados en la mano."

var player_hand: Array = []
var bot_hand: Array = []
var boneyard: Array = []
var chain: Array = []
var left_open: int = -1
var right_open: int = -1
var selected_tile_index: int = -1
var current_turn: String = "player"
var game_over: bool = false

const TABLE_W := 640.0
const TILE_W := 64.0
const TILE_H := 88.0
const TILE_GAP := 5.0

var status_label: Label
var chain_canvas: Control
var chain_scroll: ScrollContainer
var info_label: Label
var hand_row: HBoxContainer
var end_left_btn: Button
var end_right_btn: Button
var draw_btn: Button
var pass_btn: Button


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

	UIKit.build_toolbar(vbox, self, "Dominó", HELP_TEXT)

	status_label = UIKit.title_label("", 20, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	info_label = UIKit.title_label("", 16, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(info_label)

	vbox.add_child(UIKit.title_label("Mesa", 14, UIKit.COLOR_TEXT_DIM))

	var chain_panel := PanelContainer.new()
	chain_panel.custom_minimum_size = Vector2(0, 260)
	chain_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 14, 2))
	vbox.add_child(chain_panel)
	var chain_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		chain_margin.add_theme_constant_override(side, 10)
	chain_panel.add_child(chain_margin)
	chain_scroll = ScrollContainer.new()
	chain_margin.add_child(chain_scroll)
	chain_canvas = Control.new()
	chain_canvas.custom_minimum_size = Vector2(TABLE_W, TILE_H + 20)
	chain_scroll.add_child(chain_canvas)

	var ends_row := HBoxContainer.new()
	ends_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ends_row.add_theme_constant_override("separation", 10)
	vbox.add_child(ends_row)

	end_left_btn = Button.new()
	end_left_btn.custom_minimum_size = Vector2(160, 48)
	UIKit.style_button(end_left_btn, UIKit.COLOR_ACCENT_2)
	end_left_btn.pressed.connect(_on_end_pressed.bind("left"))
	ends_row.add_child(end_left_btn)

	end_right_btn = Button.new()
	end_right_btn.custom_minimum_size = Vector2(160, 48)
	UIKit.style_button(end_right_btn, UIKit.COLOR_ACCENT_2)
	end_right_btn.pressed.connect(_on_end_pressed.bind("right"))
	ends_row.add_child(end_right_btn)

	vbox.add_child(UIKit.title_label("Tu mano", 16, UIKit.COLOR_TEXT_DIM))

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(hand_scroll)
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(hand_row)

	var actions_row := HBoxContainer.new()
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_row.add_theme_constant_override("separation", 10)
	vbox.add_child(actions_row)

	draw_btn = Button.new()
	draw_btn.text = "Robar"
	draw_btn.custom_minimum_size = Vector2(120, 48)
	UIKit.style_button(draw_btn, UIKit.COLOR_ACCENT)
	draw_btn.pressed.connect(_on_draw_pressed)
	actions_row.add_child(draw_btn)

	pass_btn = Button.new()
	pass_btn.text = "Pasar"
	pass_btn.custom_minimum_size = Vector2(120, 48)
	UIKit.style_button(pass_btn, UIKit.COLOR_TEXT_DIM)
	pass_btn.pressed.connect(_on_pass_pressed)
	actions_row.add_child(pass_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _build_tiles() -> Array:
	var tiles: Array = []
	for i in range(7):
		for j in range(i, 7):
			tiles.append({"a": i, "b": j})
	return tiles


func _new_game() -> void:
	var tiles: Array = _build_tiles()
	tiles.shuffle()

	player_hand = tiles.slice(0, 7)
	bot_hand = tiles.slice(7, 14)
	boneyard = tiles.slice(14, 28)
	chain = []
	left_open = -1
	right_open = -1
	selected_tile_index = -1
	game_over = false

	current_turn = "player" if randi() % 2 == 0 else "bot"
	_redraw_all()

	if current_turn == "player":
		status_label.text = "Tu turno: elige una ficha y toca un extremo"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
	else:
		status_label.text = "Turno de la máquina..."
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
		await get_tree().create_timer(0.6).timeout
		_bot_turn()


func _redraw_all() -> void:
	_redraw_chain_table()

	if chain.is_empty():
		end_left_btn.text = "Colocar ficha"
		end_right_btn.text = "Colocar ficha"
	else:
		end_left_btn.text = "◀  Extremo %d" % left_open
		end_right_btn.text = "Extremo %d  ▶" % right_open

	for child: Node in hand_row.get_children():
		child.queue_free()
	for i in range(player_hand.size()):
		var tile: Dictionary = player_hand[i]
		var t := DominoTile.new()
		t.custom_minimum_size = Vector2(90, 130)
		t.set_values(tile["a"], tile["b"], true)
		t.set_highlighted(i == selected_tile_index)
		t.pressed.connect(_on_hand_tile_pressed.bind(i))
		hand_row.add_child(t)

	info_label.text = "Máquina: %d fichas      Pozo: %d fichas" % [bot_hand.size(), boneyard.size()]

	var can_move: bool = _has_valid_move(player_hand)
	draw_btn.disabled = game_over or current_turn != "player" or boneyard.is_empty()
	pass_btn.disabled = game_over or current_turn != "player" or can_move or not boneyard.is_empty()


func _redraw_chain_table() -> void:
	for child: Node in chain_canvas.get_children():
		child.queue_free()

	if chain.is_empty():
		chain_canvas.custom_minimum_size = Vector2(TABLE_W, TILE_H + 20)
		var empty_lbl := UIKit.title_label("(vacío, coloca la primera ficha)", 14, UIKit.COLOR_TEXT_DIM)
		empty_lbl.position = Vector2(10, 10)
		chain_canvas.add_child(empty_lbl)
		return

	# Acomodo tipo "serpiente" como en una mesa real: las fichas se van
	# colocando de canto a canto en fila; cuando la fila se llena, la
	# cadena da vuelta y sigue en la fila de abajo (alternando sentido),
	# en vez de amontonarse en una sola tira horizontal.
	var cols_per_row: int = max(1, int(TABLE_W / (TILE_W + TILE_GAP)))
	var row := 0
	var col := 0
	var direction := 1

	for tile: Dictionary in chain:
		var t := DominoTile.new()
		t.custom_minimum_size = Vector2(TILE_W, TILE_H)
		t.size = Vector2(TILE_W, TILE_H)
		t.disabled = true
		t.set_values(tile["a"], tile["b"], tile["a"] == tile["b"])

		var display_col: int = col if direction == 1 else (cols_per_row - 1 - col)
		t.position = Vector2(display_col * (TILE_W + TILE_GAP), row * (TILE_H + TILE_GAP))
		chain_canvas.add_child(t)

		col += 1
		if col >= cols_per_row:
			col = 0
			row += 1
			direction *= -1

	var total_rows: int = row + 1
	chain_canvas.custom_minimum_size = Vector2(TABLE_W, total_rows * (TILE_H + TILE_GAP) + 10)


func _has_valid_move(hand: Array) -> bool:
	if chain.is_empty():
		return not hand.is_empty()
	for tile: Dictionary in hand:
		if tile["a"] == left_open or tile["b"] == left_open or tile["a"] == right_open or tile["b"] == right_open:
			return true
	return false


func _place_tile(tile: Dictionary, side: String) -> void:
	if chain.is_empty():
		chain.append(tile)
		left_open = tile["a"]
		right_open = tile["b"]
		return

	var open_value: int = left_open if side == "left" else right_open
	var other: int = tile["b"] if tile["a"] == open_value else tile["a"]
	var oriented: Dictionary = {"a": other, "b": open_value} if side == "left" else {"a": open_value, "b": other}

	if side == "left":
		chain.insert(0, oriented)
		left_open = other
	else:
		chain.append(oriented)
		right_open = other


func _hand_sum(hand: Array) -> int:
	var total := 0
	for tile: Dictionary in hand:
		total += tile["a"] + tile["b"]
	return total


func _on_hand_tile_pressed(i: int) -> void:
	if game_over or current_turn != "player":
		return
	selected_tile_index = -1 if selected_tile_index == i else i
	_redraw_all()


func _on_end_pressed(side: String) -> void:
	if game_over or current_turn != "player" or selected_tile_index == -1:
		return

	var tile: Dictionary = player_hand[selected_tile_index]

	if not chain.is_empty():
		var open_value: int = left_open if side == "left" else right_open
		if tile["a"] != open_value and tile["b"] != open_value:
			status_label.text = "Esa ficha no encaja en ese extremo"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			return

	_place_tile(tile, side)
	player_hand.remove_at(selected_tile_index)
	selected_tile_index = -1
	_redraw_all()

	if player_hand.is_empty():
		_end_game_win("player")
		return

	current_turn = "bot"
	status_label.text = "Turno de la máquina..."
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
	_redraw_all()
	await get_tree().create_timer(0.6).timeout
	_bot_turn()


func _on_draw_pressed() -> void:
	if game_over or current_turn != "player" or boneyard.is_empty():
		return
	player_hand.append(boneyard.pop_back())
	selected_tile_index = -1
	_redraw_all()


func _on_pass_pressed() -> void:
	if game_over or current_turn != "player":
		return
	if _has_valid_move(player_hand) or not boneyard.is_empty():
		return

	if not _has_valid_move(bot_hand):
		_end_game_block()
		return

	current_turn = "bot"
	status_label.text = "Pasaste. Turno de la máquina..."
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
	_redraw_all()
	await get_tree().create_timer(0.6).timeout
	_bot_turn()


func _bot_choose_tile() -> Dictionary:
	if chain.is_empty():
		return bot_hand[0]
	for tile: Dictionary in bot_hand:
		if tile["a"] == left_open or tile["b"] == left_open or tile["a"] == right_open or tile["b"] == right_open:
			return tile
	return {}


func _bot_choose_side(tile: Dictionary) -> String:
	if chain.is_empty():
		return "left"
	if tile["a"] == left_open or tile["b"] == left_open:
		return "left"
	return "right"


func _bot_turn() -> void:
	while not _has_valid_move(bot_hand) and not boneyard.is_empty():
		bot_hand.append(boneyard.pop_back())

	if not _has_valid_move(bot_hand):
		if not _has_valid_move(player_hand) and boneyard.is_empty():
			_end_game_block()
			return
		status_label.text = "La máquina no puede jugar, te toca a ti"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		current_turn = "player"
		_redraw_all()
		return

	var tile: Dictionary = _bot_choose_tile()
	var side: String = _bot_choose_side(tile)
	_place_tile(tile, side)
	bot_hand.erase(tile)
	_redraw_all()

	if bot_hand.is_empty():
		_end_game_win("bot")
		return

	current_turn = "player"
	status_label.text = "Tu turno"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
	_redraw_all()


func _end_game_win(winner: String) -> void:
	game_over = true
	if winner == "player":
		status_label.text = "¡Ganaste! Te quedaste sin fichas"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
		_record_result("wins")
	else:
		status_label.text = "Ganó la máquina, se quedó sin fichas"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result("losses")
	_redraw_all()


func _end_game_block() -> void:
	game_over = true
	var p_sum: int = _hand_sum(player_hand)
	var b_sum: int = _hand_sum(bot_hand)
	if p_sum < b_sum:
		status_label.text = "Juego trancado. ¡Ganaste con menos puntos! (%d vs %d)" % [p_sum, b_sum]
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
		_record_result("wins")
	elif b_sum < p_sum:
		status_label.text = "Juego trancado. Ganó la máquina (%d vs %d)" % [b_sum, p_sum]
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result("losses")
	else:
		status_label.text = "Juego trancado. Empate (%d vs %d)" % [p_sum, b_sum]
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		_record_result("draws")
	_redraw_all()


func _record_result(key: String) -> void:
	if key.begins_with("win") or key.begins_with("completed"):
		AudioManager.play_win()
	elif key.begins_with("loss") or key.begins_with("fail"):
		AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
