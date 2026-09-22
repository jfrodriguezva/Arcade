extends Control
## Parchís simplificado para 2 jugadores: pista compartida circular +
## tramo final privado por jugador (en vez del tablero en cruz clásico
## de 4 jugadores, para mantenerlo jugable en pantalla chica).

const GAME_ID := "parchis"
const SHARED_TRACK_LEN := 28
const HOME_STRETCH_LEN := 6
const TOTAL_STEPS := SHARED_TRACK_LEN + HOME_STRETCH_LEN
const ENTRY_OFFSET := {"player": 0, "bot": 14}
const SAFE_SQUARES := [0, 14]

const HELP_TEXT := "Cada jugador tiene 4 fichas. Empiezan en 'Base' y deben salir con un 6 en el dado.

- Tira el dado; si sacas 6, puedes sacar una ficha de la base (y tiras otra vez de regalo).
- Toca una de tus fichas activas (resaltada en amarillo) para avanzarla la cantidad del dado.
- Si caes exacto sobre una ficha rival fuera de las casillas de salida (que son seguras), la mandas de vuelta a la base.
- Necesitas el número exacto para llegar a la meta.

Gana quien lleve sus 4 fichas a la meta 🏁 primero."

var tokens: Dictionary = {"player": [-1, -1, -1, -1], "bot": [-1, -1, -1, -1]}
var current_turn: String = "player"
var mode: String = "pve"
var difficulty: String = "medium"
var game_over: bool = false
var last_roll: int = 0
var consecutive_sixes: int = 0

var status_label: Label
var dice_label: Label
var roll_btn: Button
var track_cells: Array = []
var player_token_buttons: Array = []
var bot_token_buttons: Array = []


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Parchís", true, true, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
	difficulty = config["difficulty"]
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
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Parchís", HELP_TEXT)

	status_label = UIKit.title_label("", 18, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	dice_label = UIKit.title_label("🎲", 32, UIKit.COLOR_ACCENT_3)
	vbox.add_child(dice_label)

	roll_btn = Button.new()
	roll_btn.text = "Tirar dado"
	roll_btn.custom_minimum_size = Vector2(200, 50)
	UIKit.style_button(roll_btn, UIKit.COLOR_ACCENT)
	roll_btn.pressed.connect(_on_roll_pressed)
	vbox.add_child(roll_btn)

	vbox.add_child(UIKit.title_label("Pista compartida", 14, UIKit.COLOR_TEXT_DIM))

	var track_panel := PanelContainer.new()
	track_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(track_panel)
	var track_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		track_margin.add_theme_constant_override(side, 8)
	track_panel.add_child(track_margin)

	var track_grid := GridContainer.new()
	track_grid.columns = 14
	track_grid.add_theme_constant_override("h_separation", 2)
	track_grid.add_theme_constant_override("v_separation", 2)
	track_margin.add_child(track_grid)

	for i in range(SHARED_TRACK_LEN):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(28, 28)
		cell.add_theme_font_size_override("font_size", 10)
		cell.disabled = true
		cell.focus_mode = Control.FOCUS_NONE
		track_grid.add_child(cell)
		track_cells.append(cell)

	vbox.add_child(UIKit.title_label("Tus fichas", 14, UIKit.COLOR_ACCENT))
	var player_row := HBoxContainer.new()
	player_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_row.add_theme_constant_override("separation", 6)
	vbox.add_child(player_row)
	for i in range(4):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 44)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_token_pressed.bind("player", i))
		player_row.add_child(btn)
		player_token_buttons.append(btn)

	vbox.add_child(UIKit.title_label("Fichas rivales", 14, UIKit.COLOR_ACCENT_2))
	var bot_row := HBoxContainer.new()
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_row.add_theme_constant_override("separation", 6)
	vbox.add_child(bot_row)
	for i in range(4):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 44)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_token_pressed.bind("bot", i))
		bot_row.add_child(btn)
		bot_token_buttons.append(btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Parchís", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	tokens = {"player": [-1, -1, -1, -1], "bot": [-1, -1, -1, -1]}
	current_turn = "player"
	game_over = false
	consecutive_sixes = 0
	_start_turn()


func _start_turn() -> void:
	last_roll = 0
	_update_turn_status()
	_redraw_all()

	if mode == "pve" and current_turn == "bot":
		await get_tree().create_timer(0.5).timeout
		_perform_roll("bot")


func _update_turn_status() -> void:
	if mode == "pve":
		status_label.text = "Tu turno" if current_turn == "player" else "Turno de la máquina..."
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)
	else:
		var label: String = "Jugador 1 (rosa)" if current_turn == "player" else "Jugador 2 (teal)"
		status_label.text = "Turno: %s" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)


func _movable_tokens(owner: String) -> Array:
	var result: Array = []
	for i in range(4):
		var pos: int = tokens[owner][i]
		if pos == -1:
			if last_roll == 6:
				result.append(i)
		elif pos < TOTAL_STEPS:
			if pos + last_roll <= TOTAL_STEPS:
				result.append(i)
	return result


func _on_roll_pressed() -> void:
	if game_over or last_roll != 0:
		return
	if mode == "pve" and current_turn != "player":
		return
	_perform_roll(current_turn)


func _perform_roll(owner: String) -> void:
	last_roll = randi() % 6 + 1
	if last_roll == 6:
		consecutive_sixes += 1
	else:
		consecutive_sixes = 0
	_redraw_all()

	var movable: Array = _movable_tokens(owner)
	if movable.is_empty():
		await get_tree().create_timer(0.5).timeout
		_finish_turn(owner, false)
		return

	if mode == "pve" and owner == "bot":
		await get_tree().create_timer(0.4).timeout
		var choice: int = _bot_pick_token(movable)
		_move_token(owner, choice)
		_finish_turn(owner, true)


func _on_token_pressed(owner: String, i: int) -> void:
	if game_over or current_turn != owner or last_roll == 0:
		return
	if mode == "pve" and owner == "bot":
		return
	if not _movable_tokens(owner).has(i):
		return
	_move_token(owner, i)
	_finish_turn(owner, true)


func _move_token(owner: String, i: int) -> void:
	var pos: int = tokens[owner][i]
	var new_pos: int = 0 if pos == -1 else pos + last_roll
	tokens[owner][i] = new_pos

	if new_pos < SHARED_TRACK_LEN:
		var abs_square: int = (ENTRY_OFFSET[owner] + new_pos) % SHARED_TRACK_LEN
		if not SAFE_SQUARES.has(abs_square):
			var other: String = "bot" if owner == "player" else "player"
			for j in range(4):
				var opos: int = tokens[other][j]
				if opos == -1 or opos >= SHARED_TRACK_LEN:
					continue
				var oabs: int = (ENTRY_OFFSET[other] + opos) % SHARED_TRACK_LEN
				if oabs == abs_square:
					tokens[other][j] = -1


func _bot_pick_token(movable: Array) -> int:
	if difficulty == "easy":
		return movable[randi() % movable.size()]

	for i: int in movable:
		if tokens["bot"][i] == -1:
			return i
	var best: int = movable[0]
	for i: int in movable:
		if tokens["bot"][i] > tokens["bot"][best]:
			best = i
	return best


func _has_won(owner: String) -> bool:
	for pos: int in tokens[owner]:
		if pos != TOTAL_STEPS:
			return false
	return true


func _finish_turn(owner: String, moved: bool) -> void:
	_redraw_all()

	if _has_won(owner):
		_end_game(owner)
		return

	var bonus_turn: bool = moved and last_roll == 6 and consecutive_sixes < 3
	last_roll = 0

	if bonus_turn:
		status_label.text = "¡Sacaste 6! Tiras otra vez"
		_redraw_all()
		if mode == "pve" and owner == "bot":
			await get_tree().create_timer(0.5).timeout
			_perform_roll("bot")
		return

	consecutive_sixes = 0
	current_turn = "bot" if owner == "player" else "player"
	_start_turn()


func _end_game(owner: String) -> void:
	game_over = true
	roll_btn.disabled = true
	if mode == "pve":
		if owner == "player":
			status_label.text = "¡Ganaste! Llevaste tus 4 fichas a la meta"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		else:
			status_label.text = "Ganó la máquina"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
	else:
		var label: String = "Jugador 1 (rosa)" if owner == "player" else "Jugador 2 (teal)"
		status_label.text = "¡Ganó %s!" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)


func _record_result(key: String) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)


func _redraw_all() -> void:
	dice_label.text = "🎲 %d" % last_roll if last_roll != 0 else "🎲"

	var can_roll: bool = not game_over and last_roll == 0 and (mode == "pvp" or current_turn == "player")
	roll_btn.disabled = not can_roll

	var movable: Array = _movable_tokens(current_turn) if last_roll != 0 else []

	for i in range(4):
		_style_token_button(player_token_buttons[i], "player", i, movable)
		_style_token_button(bot_token_buttons[i], "bot", i, movable)

	for cell_idx in range(SHARED_TRACK_LEN):
		var cell: Button = track_cells[cell_idx]
		var text := ""
		var color: Color = UIKit.COLOR_TEXT_DIM
		for owner: String in ["player", "bot"]:
			for pos: int in tokens[owner]:
				if pos != -1 and pos < SHARED_TRACK_LEN:
					var abs_square: int = (ENTRY_OFFSET[owner] + pos) % SHARED_TRACK_LEN
					if abs_square == cell_idx:
						text += "●"
						color = UIKit.COLOR_ACCENT if owner == "player" else UIKit.COLOR_ACCENT_2
		cell.text = text
		cell.add_theme_color_override("font_disabled_color", color)
		var bg: Color = UIKit.COLOR_ACCENT_3.lerp(UIKit.COLOR_BG_LIGHT, 0.7) if SAFE_SQUARES.has(cell_idx) else UIKit.COLOR_BG_LIGHT
		var sb: StyleBoxFlat = UIKit.stylebox(bg, Color(0, 0, 0, 0), 4)
		cell.add_theme_stylebox_override("disabled", sb)


func _style_token_button(btn: Button, owner: String, i: int, movable: Array) -> void:
	var pos: int = tokens[owner][i]
	if pos == -1:
		btn.text = "Base"
	elif pos == TOTAL_STEPS:
		btn.text = "🏁"
	elif pos >= SHARED_TRACK_LEN:
		btn.text = "Meta %d" % (pos - SHARED_TRACK_LEN + 1)
	else:
		btn.text = str(pos + 1)

	var is_movable: bool = owner == current_turn and movable.has(i)
	var accent: Color = UIKit.COLOR_ACCENT_3 if is_movable else (UIKit.COLOR_ACCENT if owner == "player" else UIKit.COLOR_ACCENT_2)
	UIKit.style_button(btn, accent, 8)
	btn.disabled = not (is_movable and (mode == "pvp" or owner == "player"))
