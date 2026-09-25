extends Control
## Generala (dados, estilo Yahtzee clásico) contra la máquina, con
## 3 niveles de dificultad que afectan qué dados retiene y cómo
## elige categoría. También se puede jugar pasando el dispositivo.

const GAME_ID := "generala"
const CATEGORIES := ["1", "2", "3", "4", "5", "6", "escalera", "full", "poker", "generala"]
const CATEGORY_LABELS := {
	"1": "Unos", "2": "Doses", "3": "Treses", "4": "Cuatros", "5": "Cincos", "6": "Seises",
	"escalera": "Escalera", "full": "Full", "poker": "Póker", "generala": "Generala",
}

const HELP_TEXT := "Cada turno tienes hasta 3 tiradas de 5 dados.

- Toca 'Tirar dados' para lanzar los que no estén retenidos.
- Toca un dado para retenerlo (no se vuelve a tirar) o soltarlo.
- Cuando quieras (o al agotar las 3 tiradas), toca una categoría de tu columna para anotar el resultado ahí. Cada categoría solo se usa una vez.

Categorías: Unos a Seises suman solo esos dados. Escalera (1-2-3-4-5 o 2-3-4-5-6) = 20. Full (trío + par) = 30. Póker (4 iguales) = 40. Generala (5 iguales) = 50.

Gana quien tenga más puntos al llenar las 10 categorías."

var dice: Array = [1, 1, 1, 1, 1]
var held: Array = [false, false, false, false, false]
var rolls_left: int = 3
var current_turn: String = "player"
var mode: String = "pve"
var difficulty: String = "medium"
var scores: Dictionary = {"player": {}, "bot": {}}
var game_over: bool = false

var status_label: Label
var roll_btn: Button
var die_buttons: Array = []
var left_buttons: Dictionary = {}
var right_buttons: Dictionary = {}
var left_header: Label
var right_header: Label
var left_total_label: Label
var right_total_label: Label


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Generala", true, true, _on_setup_confirmed)


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

	UIKit.build_toolbar(vbox, self, "Generala", HELP_TEXT)

	status_label = UIKit.title_label("", 18, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	var dice_row := HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 8)
	vbox.add_child(dice_row)

	for i in range(5):
		var die := Button.new()
		die.custom_minimum_size = Vector2(68, 68)
		die.add_theme_font_size_override("font_size", 26)
		die.pressed.connect(_on_die_pressed.bind(i))
		dice_row.add_child(die)
		die_buttons.append(die)

	roll_btn = Button.new()
	roll_btn.custom_minimum_size = Vector2(220, 50)
	UIKit.style_button(roll_btn, UIKit.COLOR_ACCENT)
	roll_btn.pressed.connect(_on_roll_pressed)
	vbox.add_child(roll_btn)

	var card_panel := PanelContainer.new()
	card_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 2))
	vbox.add_child(card_panel)
	var card_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		card_margin.add_theme_constant_override(side, 12)
	card_panel.add_child(card_margin)

	var score_grid := GridContainer.new()
	score_grid.columns = 3
	score_grid.add_theme_constant_override("h_separation", 12)
	score_grid.add_theme_constant_override("v_separation", 6)
	card_margin.add_child(score_grid)

	score_grid.add_child(UIKit.title_label("Categoría", 14, UIKit.COLOR_TEXT_DIM))
	left_header = UIKit.title_label("Tú", 14, UIKit.COLOR_ACCENT)
	score_grid.add_child(left_header)
	right_header = UIKit.title_label("Máquina", 14, UIKit.COLOR_ACCENT_2)
	score_grid.add_child(right_header)

	for cat: String in CATEGORIES:
		score_grid.add_child(UIKit.title_label(CATEGORY_LABELS[cat], 14, UIKit.COLOR_TEXT))

		var lbtn := Button.new()
		lbtn.custom_minimum_size = Vector2(70, 36)
		lbtn.add_theme_font_size_override("font_size", 14)
		lbtn.pressed.connect(_on_category_pressed.bind(cat, "player"))
		score_grid.add_child(lbtn)
		left_buttons[cat] = lbtn

		var rbtn := Button.new()
		rbtn.custom_minimum_size = Vector2(70, 36)
		rbtn.add_theme_font_size_override("font_size", 14)
		rbtn.pressed.connect(_on_category_pressed.bind(cat, "bot"))
		score_grid.add_child(rbtn)
		right_buttons[cat] = rbtn

	score_grid.add_child(UIKit.title_label("Total", 15, UIKit.COLOR_ACCENT_3))
	left_total_label = UIKit.title_label("0", 15, UIKit.COLOR_ACCENT_3)
	score_grid.add_child(left_total_label)
	right_total_label = UIKit.title_label("0", 15, UIKit.COLOR_ACCENT_3)
	score_grid.add_child(right_total_label)

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Generala", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	scores = {"player": {}, "bot": {}}
	current_turn = "player"
	game_over = false
	if mode == "pvp":
		left_header.text = "Jugador 1"
		right_header.text = "Jugador 2"
	else:
		left_header.text = "Tú"
		right_header.text = "Máquina"
	_start_turn()


func _start_turn() -> void:
	dice = [1, 1, 1, 1, 1]
	held = [false, false, false, false, false]
	rolls_left = 3
	_update_turn_status()
	_redraw_all()

	if mode == "pve" and current_turn == "bot":
		await get_tree().create_timer(0.5).timeout
		_bot_take_turn()


func _update_turn_status() -> void:
	if mode == "pve":
		status_label.text = "Tu turno" if current_turn == "player" else "Turno de la máquina..."
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)
	else:
		var label: String = "Jugador 1 (rosa)" if current_turn == "player" else "Jugador 2 (teal)"
		status_label.text = "Turno: %s" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)


func _score_category(d: Array, cat: String) -> int:
	var counts: Dictionary = {}
	for v: int in d:
		counts[v] = counts.get(v, 0) + 1

	if cat in ["1", "2", "3", "4", "5", "6"]:
		var n: int = int(cat)
		return counts.get(n, 0) * n

	match cat:
		"escalera":
			var sorted_dice: Array = d.duplicate()
			sorted_dice.sort()
			if sorted_dice == [1, 2, 3, 4, 5] or sorted_dice == [2, 3, 4, 5, 6]:
				return 20
			return 0
		"full":
			var values: Array = counts.values()
			values.sort()
			if values.size() == 2 and values[0] == 2 and values[1] == 3:
				return 30
			return 0
		"poker":
			for v: int in counts.values():
				if v >= 4:
					return 40
			return 0
		"generala":
			for v: int in counts.values():
				if v == 5:
					return 50
			return 0
	return 0


func _redraw_all() -> void:
	for i in range(5):
		var die: Button = die_buttons[i]
		die.text = str(dice[i])
		var accent: Color = UIKit.COLOR_ACCENT_3 if held[i] else UIKit.COLOR_BG_LIGHT
		UIKit.style_button(die, accent, 10)

	roll_btn.text = "🎲 Tirar dados (quedan %d)" % rolls_left
	var can_roll: bool = not game_over and rolls_left > 0 and (mode == "pvp" or current_turn == "player")
	roll_btn.disabled = not can_roll

	for cat: String in CATEGORIES:
		_style_category_button(left_buttons[cat], cat, "player")
		_style_category_button(right_buttons[cat], cat, "bot")

	var player_total := 0
	for v: int in scores["player"].values():
		player_total += v
	left_total_label.text = str(player_total)

	var bot_total := 0
	for v: int in scores["bot"].values():
		bot_total += v
	right_total_label.text = str(bot_total)


func _style_category_button(btn: Button, cat: String, owner: String) -> void:
	var used: bool = scores[owner].has(cat)
	if used:
		btn.text = str(scores[owner][cat])
		btn.disabled = true
		UIKit.style_button(btn, UIKit.COLOR_PANEL, 8)
		return

	var humanly_controlled: bool = mode == "pvp" or owner == "player"
	var can_score: bool = not game_over and rolls_left < 3 and current_turn == owner and humanly_controlled
	btn.text = str(_score_category(dice, cat)) if (rolls_left < 3 and current_turn == owner) else "-"
	btn.disabled = not can_score
	UIKit.style_button(btn, UIKit.COLOR_ACCENT_2 if can_score else UIKit.COLOR_BG_LIGHT, 8)


func _on_die_pressed(i: int) -> void:
	if game_over or rolls_left == 3:
		return
	if mode == "pve" and current_turn != "player":
		return
	held[i] = not held[i]
	_redraw_all()


func _on_roll_pressed() -> void:
	if game_over or rolls_left <= 0:
		return
	if mode == "pve" and current_turn != "player":
		return
	roll_btn.disabled = true
	var final_values: Array = dice.duplicate()
	for i in range(5):
		if not held[i]:
			final_values[i] = randi() % 6 + 1
	await UIKit.animate_dice_buttons(self, die_buttons, final_values, held)
	dice = final_values
	rolls_left -= 1
	_redraw_all()


func _on_category_pressed(cat: String, owner: String) -> void:
	if game_over or rolls_left == 3:
		return
	if current_turn != owner:
		return
	if mode == "pve" and owner == "bot":
		return
	if scores[owner].has(cat):
		return

	scores[owner][cat] = _score_category(dice, cat)
	_end_turn(owner)


func _end_turn(owner: String) -> void:
	_redraw_all()
	if scores["player"].size() >= CATEGORIES.size() and scores["bot"].size() >= CATEGORIES.size():
		_end_game()
		return

	current_turn = "bot" if owner == "player" else "player"
	_start_turn()


func _bot_take_turn() -> void:
	dice = [1, 1, 1, 1, 1]
	held = [false, false, false, false, false]

	for roll_num in range(3):
		var final_values: Array = dice.duplicate()
		for i in range(5):
			if not held[i]:
				final_values[i] = randi() % 6 + 1
		await UIKit.animate_dice_buttons(self, die_buttons, final_values, held)
		dice = final_values
		_redraw_all()
		if roll_num < 2:
			_bot_decide_holds()
			await get_tree().create_timer(0.4).timeout

	var cat: String = _bot_choose_category()
	scores["bot"][cat] = _score_category(dice, cat)
	_end_turn("bot")


func _bot_decide_holds() -> void:
	if difficulty == "easy":
		for i in range(5):
			held[i] = randi() % 2 == 0
		return

	var counts: Dictionary = {}
	for d: int in dice:
		counts[d] = counts.get(d, 0) + 1
	var best_value: int = 1
	var best_count: int = 0
	for v: int in counts.keys():
		if counts[v] > best_count:
			best_count = counts[v]
			best_value = v

	for i in range(5):
		held[i] = dice[i] == best_value


func _bot_choose_category() -> String:
	var available: Array = []
	for cat: String in CATEGORIES:
		if not scores["bot"].has(cat):
			available.append(cat)

	var best_cat: String = available[0]
	var best_score: int = -1
	for cat: String in available:
		var s: int = _score_category(dice, cat)
		if difficulty == "hard" and s == 0 and cat in ["generala", "poker", "full", "escalera"]:
			s = -1
		if s > best_score:
			best_score = s
			best_cat = cat
	return best_cat


func _end_game() -> void:
	game_over = true
	var player_total := 0
	for v: int in scores["player"].values():
		player_total += v
	var bot_total := 0
	for v: int in scores["bot"].values():
		bot_total += v

	if mode == "pve":
		if player_total > bot_total:
			status_label.text = "¡Ganaste! %d - %d" % [player_total, bot_total]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		elif bot_total > player_total:
			status_label.text = "Ganó la máquina %d - %d" % [bot_total, player_total]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
		else:
			status_label.text = "Empate %d - %d" % [player_total, bot_total]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
			_record_result("draws")
	else:
		if player_total == bot_total:
			status_label.text = "Empate %d - %d" % [player_total, bot_total]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		else:
			var winner: String = "Jugador 1 (rosa)" if player_total > bot_total else "Jugador 2 (teal)"
			status_label.text = "¡Ganó %s! %d - %d" % [winner, max(player_total, bot_total), min(player_total, bot_total)]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)

	_redraw_all()


func _record_result(key: String) -> void:
	if key.begins_with("win") or key.begins_with("completed"):
		AudioManager.play_win()
	elif key.begins_with("loss") or key.begins_with("fail"):
		AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
