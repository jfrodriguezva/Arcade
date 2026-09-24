extends Control
## Dominó clásico (set doble-seis, 28 fichas). Vs Máquina o 2 Jugadores
## en el mismo dispositivo (con pantalla de "pasa el dispositivo" para
## que nadie vea la mano del otro). Gana quien se quede sin fichas
## primero; si el juego se tranca, gana quien tenga menos puntos en mano.

const GAME_ID := "domino"

const HELP_TEXT := "Cada quien empieza con 7 fichas; el resto queda en el pozo.

- Toca una ficha de tu mano para seleccionarla.
- Toca 'Extremo izquierdo' o 'Extremo derecho' para colocarla ahí, si alguno de sus números coincide con ese extremo.
- Si ninguna ficha te sirve, toca 'Robar' para tomar del pozo.
- Si no puedes jugar y el pozo está vacío, toca 'Pasar'.

En 2 Jugadores verás una pantalla para pasar el dispositivo entre turnos, así nadie ve la mano del otro.

Gana quien se quede sin fichas primero. Si el juego se tranca (nadie puede jugar), gana quien tenga menos puntos sumados en la mano."

var hands: Dictionary = {}
var boneyard: Array = []
var chain: Array = []
var left_open: int = -1
var right_open: int = -1
var selected_tile_index: int = -1
var current_turn: String = "player"
var mode: String = "pve"
var game_over: bool = false

const TABLE_W := 660.0
## Ficha normal: acostada a lo largo de la cadena (más ancha que alta).
## Ficha doble: girada 90°, cruzada sobre la cadena (más alta que ancha) —
## así se acomodan en la mesa como en la realidad, no como fichas de pie
## todas iguales.
const TILE_LONG := 104.0
const TILE_SHORT := 52.0
const TILE_GAP := 5.0

var status_label: Label
var hand_title_label: Label
var chain_canvas: Control
var info_label: Label
var hand_row: HFlowContainer
var end_left_btn: Button
var end_right_btn: Button
var draw_btn: Button
var pass_btn: Button


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Dominó", true, false, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
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

	# Sin ScrollContainer aquí a propósito: el panel se agranda solo según
	# el contenido de la cadena (chain_canvas ajusta su custom_minimum_size
	# en cada redibujo), en vez de recortar a una altura fija y obligar a
	# scrolear dentro del tablero.
	var chain_panel := PanelContainer.new()
	chain_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 14, 2))
	vbox.add_child(chain_panel)
	var chain_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		chain_margin.add_theme_constant_override(side, 10)
	chain_panel.add_child(chain_margin)
	chain_canvas = Control.new()
	chain_canvas.custom_minimum_size = Vector2(TABLE_W, TILE_LONG + 20)
	chain_margin.add_child(chain_canvas)

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

	hand_title_label = UIKit.title_label("Tu mano", 16, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(hand_title_label)

	# HFlowContainer en vez de una fila con scroll horizontal: si no caben
	# todas las fichas en una línea, pasa las que sobran a la siguiente
	# fila automáticamente, sin necesitar scrolear para verlas todas.
	hand_row = HFlowContainer.new()
	hand_row.add_theme_constant_override("h_separation", 8)
	hand_row.add_theme_constant_override("v_separation", 8)
	vbox.add_child(hand_row)

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
	restart_btn.text = "↻  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Dominó", true, false, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _opponent(owner: String) -> String:
	return "bot" if owner == "player" else "player"


func _build_tiles() -> Array:
	var tiles: Array = []
	for i in range(7):
		for j in range(i, 7):
			tiles.append({"a": i, "b": j})
	return tiles


func _new_game() -> void:
	var tiles: Array = _build_tiles()
	tiles.shuffle()

	hands = {"player": tiles.slice(0, 7), "bot": tiles.slice(7, 14)}
	boneyard = tiles.slice(14, 28)
	chain = []
	left_open = -1
	right_open = -1
	selected_tile_index = -1
	game_over = false

	current_turn = "player" if randi() % 2 == 0 else "bot"
	_redraw_all()
	_update_turn_status()

	if mode == "pve" and current_turn == "bot":
		await get_tree().create_timer(0.6).timeout
		_bot_turn()


func _update_turn_status() -> void:
	if mode == "pve":
		hand_title_label.text = "Tu mano"
		if current_turn == "player":
			status_label.text = "Tu turno: elige una ficha y toca un extremo"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
		else:
			status_label.text = "Turno de la máquina..."
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
	else:
		var label: String = "Jugador 1 (rosa)" if current_turn == "player" else "Jugador 2 (teal)"
		hand_title_label.text = "Mano de %s" % label
		status_label.text = "Turno: %s" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)


func _redraw_all() -> void:
	_redraw_chain_table()

	if chain.is_empty():
		end_left_btn.text = "Colocar ficha"
		end_right_btn.text = "Colocar ficha"
	else:
		end_left_btn.text = "◀  Extremo %d" % left_open
		end_right_btn.text = "Extremo %d  ▶" % right_open

	var hand: Array = hands[current_turn]
	for child: Node in hand_row.get_children():
		child.queue_free()
	for i in range(hand.size()):
		var tile: Dictionary = hand[i]
		var t := DominoTile.new()
		t.custom_minimum_size = Vector2(90, 130)
		t.set_values(tile["a"], tile["b"], true)
		t.set_highlighted(i == selected_tile_index)
		t.pressed.connect(_on_hand_tile_pressed.bind(i))
		hand_row.add_child(t)

	var opponent_label: String = "Máquina" if mode == "pve" else ("Jugador 2" if current_turn == "player" else "Jugador 1")
	info_label.text = "%s: %d fichas      Pozo: %d fichas" % [opponent_label, hands[_opponent(current_turn)].size(), boneyard.size()]

	var can_move: bool = _has_valid_move(hand)
	var can_act: bool = mode == "pvp" or current_turn == "player"
	draw_btn.disabled = game_over or not can_act or boneyard.is_empty()
	pass_btn.disabled = game_over or not can_act or can_move or not boneyard.is_empty()


func _redraw_chain_table() -> void:
	for child: Node in chain_canvas.get_children():
		child.queue_free()

	if chain.is_empty():
		chain_canvas.custom_minimum_size = Vector2(TABLE_W, TILE_LONG + 20)
		var empty_lbl := UIKit.title_label("(vacío, coloca la primera ficha)", 14, UIKit.COLOR_TEXT_DIM)
		empty_lbl.position = Vector2(10, 10)
		chain_canvas.add_child(empty_lbl)
		return

	# Acomodo real: las fichas normales van acostadas en fila; las dobles
	# van giradas 90° cruzando la cadena, como se ponen en una mesa de
	# verdad. La fila avanza por ancho acumulado (no por conteo de fichas,
	# ya que las dobles ocupan menos "a lo largo" de la cadena) y dobla en
	# serpiente cuando ya no cabe una ficha más.
	var row := 0
	var cursor_x := 0.0
	var direction := 1

	for tile: Dictionary in chain:
		var is_double: bool = tile["a"] == tile["b"]
		var tw: float = TILE_SHORT if is_double else TILE_LONG
		var th: float = TILE_LONG if is_double else TILE_SHORT

		if cursor_x > 0.0 and cursor_x + tw > TABLE_W:
			cursor_x = 0.0
			row += 1
			direction *= -1

		var t := DominoTile.new()
		t.custom_minimum_size = Vector2(tw, th)
		t.size = Vector2(tw, th)
		t.disabled = true
		t.set_values(tile["a"], tile["b"], is_double)

		var display_x: float = cursor_x if direction == 1 else (TABLE_W - cursor_x - tw)
		var y_offset: float = (TILE_LONG - th) / 2.0
		t.position = Vector2(display_x, row * (TILE_LONG + TILE_GAP) + y_offset)
		chain_canvas.add_child(t)

		cursor_x += tw + TILE_GAP

	var total_rows: int = row + 1
	chain_canvas.custom_minimum_size = Vector2(TABLE_W, total_rows * (TILE_LONG + TILE_GAP) + 10)


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
	if game_over or (mode == "pve" and current_turn != "player"):
		return
	selected_tile_index = -1 if selected_tile_index == i else i
	_redraw_all()


func _on_end_pressed(side: String) -> void:
	if game_over or (mode == "pve" and current_turn != "player") or selected_tile_index == -1:
		return

	var hand: Array = hands[current_turn]
	var tile: Dictionary = hand[selected_tile_index]

	if not chain.is_empty():
		var open_value: int = left_open if side == "left" else right_open
		if tile["a"] != open_value and tile["b"] != open_value:
			status_label.text = "Esa ficha no encaja en ese extremo"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			return

	var mover: String = current_turn
	_place_tile(tile, side)
	hand.remove_at(selected_tile_index)
	selected_tile_index = -1

	if hand.is_empty():
		_redraw_all()
		_end_game_win(mover)
		return

	_advance_turn(mover)


func _on_draw_pressed() -> void:
	if game_over or (mode == "pve" and current_turn != "player") or boneyard.is_empty():
		return
	hands[current_turn].append(boneyard.pop_back())
	selected_tile_index = -1
	_redraw_all()


func _on_pass_pressed() -> void:
	if game_over or (mode == "pve" and current_turn != "player"):
		return
	var mover: String = current_turn
	if _has_valid_move(hands[mover]) or not boneyard.is_empty():
		return

	if not _has_valid_move(hands[_opponent(mover)]):
		_end_game_block()
		return

	_advance_turn(mover)


func _advance_turn(mover: String) -> void:
	current_turn = _opponent(mover)

	if mode == "pve":
		_redraw_all()
		_update_turn_status()
		if current_turn == "bot":
			await get_tree().create_timer(0.6).timeout
			_bot_turn()
		return

	var next_label: String = "Jugador 1 (rosa)" if current_turn == "player" else "Jugador 2 (teal)"
	UIKit.show_pass_cover(self, "Pásale el dispositivo a %s" % next_label, _on_pass_confirmed)


func _on_pass_confirmed() -> void:
	selected_tile_index = -1
	_redraw_all()
	_update_turn_status()


func _bot_choose_tile() -> Dictionary:
	var bot_hand: Array = hands["bot"]
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
	var bot_hand: Array = hands["bot"]
	while not _has_valid_move(bot_hand) and not boneyard.is_empty():
		bot_hand.append(boneyard.pop_back())

	if not _has_valid_move(bot_hand):
		if not _has_valid_move(hands["player"]) and boneyard.is_empty():
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

	if bot_hand.is_empty():
		_redraw_all()
		_end_game_win("bot")
		return

	current_turn = "player"
	_redraw_all()
	_update_turn_status()


func _end_game_win(winner: String) -> void:
	game_over = true
	if mode == "pve":
		if winner == "player":
			status_label.text = "¡Ganaste! Te quedaste sin fichas"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		else:
			status_label.text = "Ganó la máquina, se quedó sin fichas"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
	else:
		var label: String = "Jugador 1 (rosa)" if winner == "player" else "Jugador 2 (teal)"
		status_label.text = "¡Ganó %s! Se quedó sin fichas" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
		AudioManager.play_win()
	_redraw_all()


func _end_game_block() -> void:
	game_over = true
	var p_sum: int = _hand_sum(hands["player"])
	var b_sum: int = _hand_sum(hands["bot"])

	if mode == "pve":
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
	else:
		if p_sum == b_sum:
			status_label.text = "Juego trancado. Empate (%d vs %d)" % [p_sum, b_sum]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		else:
			var winner_label: String = "Jugador 1 (rosa)" if p_sum < b_sum else "Jugador 2 (teal)"
			status_label.text = "Juego trancado. ¡Ganó %s! (%d vs %d)" % [winner_label, min(p_sum, b_sum), max(p_sum, b_sum)]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			AudioManager.play_win()
	_redraw_all()


func _record_result(key: String) -> void:
	if key.begins_with("win") or key.begins_with("completed"):
		AudioManager.play_win()
	elif key.begins_with("loss") or key.begins_with("fail"):
		AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
