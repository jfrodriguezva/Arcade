extends Control
## Backgammon con reglas estándar: barra, reingreso, bear-off (con la
## regla de "sobrante" cuando no hay fichas más lejanas), fichas
## comidas al caer en un "blot" rival, dados dobles = 4 movimientos.
## Simplificación consciente: sin dado doblador (cubo de apuestas),
## ya que es un mecanismo de apuesta/puntaje, no de movimiento.

const GAME_ID := "backgammon"
const DIRECTION := {"player": -1, "bot": 1}
const HOME_RANGE := {"player": [1, 6], "bot": [19, 24]}
const START_PLAYER := {24: 2, 13: 5, 8: 3, 6: 5}
const START_BOT := {1: 2, 12: 5, 17: 3, 19: 5}

const HELP_TEXT := "Objetivo: llevar tus 15 fichas a tu 'casa' (puntos 1-6 para ti) y sacarlas todas (bear-off) antes que la máquina.

- Tira los dados (si salen dobles, juegas 4 movimientos de ese número en vez de 2).
- Toca una casilla con fichas tuyas para seleccionarla, luego toca el destino.
- Si caes exacto sobre UNA ficha rival (un 'blot'), la mandas a la Barra; debe reingresar antes de que su dueño pueda mover cualquier otra ficha.
- Cuando tus 15 fichas están en tu casa, puedes sacarlas (botón 'Sacar ficha') con el número exacto, o con un número mayor si no te queda ninguna ficha más lejos.

Gana quien saque sus 15 fichas primero.

(Simplificación: sin cubo doblador; y no se obliga estrictamente a usar ambos dados si hay alternativas — tú decides cómo jugarlos)."

var checkers: Dictionary = {"player": {}, "bot": {}}
var bar: Dictionary = {"player": 0, "bot": 0}
var borne_off: Dictionary = {"player": 0, "bot": 0}
var dice: Array = []
var current_turn: String = "player"
var mode: String = "pve"
var difficulty: String = "medium"
var game_over: bool = false
var selected_point: int = -1

var status_label: Label
var dice_label: Label
var bar_off_label: Label
var bear_off_btn: Button
var point_buttons: Dictionary = {}
var bar_btn: Button


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Backgammon", true, true, _on_setup_confirmed)


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
		margin.add_theme_constant_override(side, 16)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Backgammon", HELP_TEXT)

	status_label = UIKit.title_label("", 16, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	dice_label = UIKit.title_label("🎲", 26, UIKit.COLOR_ACCENT_3)
	vbox.add_child(dice_label)

	var actions_row := HBoxContainer.new()
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_row.add_theme_constant_override("separation", 8)
	vbox.add_child(actions_row)

	bear_off_btn = Button.new()
	bear_off_btn.text = "Sacar ficha"
	bear_off_btn.custom_minimum_size = Vector2(120, 44)
	UIKit.style_button(bear_off_btn, UIKit.COLOR_ACCENT_3)
	bear_off_btn.pressed.connect(_on_bear_off_pressed)
	actions_row.add_child(bear_off_btn)

	bar_off_label = UIKit.title_label("", 13, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(bar_off_label)

	bar_btn = Button.new()
	bar_btn.text = "Tu ficha en la Barra"
	bar_btn.custom_minimum_size = Vector2(220, 40)
	bar_btn.pressed.connect(_on_bar_pressed)
	vbox.add_child(bar_btn)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 14, 2))
	var board_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		board_margin.add_theme_constant_override(side, 6)
	board_panel.add_child(board_margin)
	vbox.add_child(board_panel)

	var board_vbox := VBoxContainer.new()
	board_vbox.add_theme_constant_override("separation", 4)
	board_margin.add_child(board_vbox)

	var top_row := GridContainer.new()
	top_row.columns = 12
	top_row.add_theme_constant_override("h_separation", 2)
	board_vbox.add_child(top_row)
	for p in range(24, 12, -1):
		point_buttons[p] = _make_point_button(top_row, p)

	var bottom_row := GridContainer.new()
	bottom_row.columns = 12
	bottom_row.add_theme_constant_override("h_separation", 2)
	board_vbox.add_child(bottom_row)
	for p in range(1, 13):
		point_buttons[p] = _make_point_button(bottom_row, p)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Backgammon", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _make_point_button(parent: GridContainer, p: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(48, 84)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_point_pressed.bind(p))
	parent.add_child(btn)
	return btn


func _new_game() -> void:
	checkers = {"player": START_PLAYER.duplicate(), "bot": START_BOT.duplicate()}
	bar = {"player": 0, "bot": 0}
	borne_off = {"player": 0, "bot": 0}
	dice = []
	current_turn = "player"
	game_over = false
	selected_point = -1
	_start_turn()


func _opponent(owner: String) -> String:
	return "bot" if owner == "player" else "player"


func _count_at(owner: String, point: int) -> int:
	return checkers[owner].get(point, 0)


func _opponent_count_at(owner: String, point: int) -> int:
	return checkers[_opponent(owner)].get(point, 0)


func _all_in_home(owner: String) -> bool:
	if bar[owner] > 0:
		return false
	var home: Array = HOME_RANGE[owner]
	for point: int in checkers[owner].keys():
		if checkers[owner][point] > 0 and (point < home[0] or point > home[1]):
			return false
	return true


func _distance_from_off(owner: String, point: int) -> int:
	return point if owner == "player" else 25 - point


func _can_move(owner: String, from_point: int, d: int) -> Dictionary:
	var invalid: Dictionary = {"valid": false, "to": -1, "bear_off": false}

	if from_point == 0:
		if bar[owner] <= 0:
			return invalid
		var entry: int = (25 - d) if owner == "player" else d
		if _opponent_count_at(owner, entry) >= 2:
			return invalid
		return {"valid": true, "to": entry, "bear_off": false}

	if _count_at(owner, from_point) <= 0 or bar[owner] > 0:
		return invalid

	var to: int = from_point + DIRECTION[owner] * d
	if to >= 1 and to <= 24:
		if _opponent_count_at(owner, to) >= 2:
			return invalid
		return {"valid": true, "to": to, "bear_off": false}

	if not _all_in_home(owner):
		return invalid
	var dist: int = _distance_from_off(owner, from_point)
	if dist == d:
		return {"valid": true, "to": -1, "bear_off": true}
	if d > dist:
		var home: Array = HOME_RANGE[owner]
		for p in range(home[0], home[1] + 1):
			if _count_at(owner, p) > 0 and _distance_from_off(owner, p) > dist:
				return invalid
		return {"valid": true, "to": -1, "bear_off": true}
	return invalid


func _apply_move(owner: String, from_point: int, d: int) -> void:
	var result: Dictionary = _can_move(owner, from_point, d)
	if not result["valid"]:
		return

	if from_point == 0:
		bar[owner] -= 1
	else:
		checkers[owner][from_point] -= 1
		if checkers[owner][from_point] <= 0:
			checkers[owner].erase(from_point)

	if result["bear_off"]:
		borne_off[owner] += 1
	else:
		var to: int = result["to"]
		if _opponent_count_at(owner, to) == 1:
			checkers[_opponent(owner)].erase(to)
			bar[_opponent(owner)] += 1
		checkers[owner][to] = checkers[owner].get(to, 0) + 1

	dice.erase(d)


func _has_any_legal_move(owner: String) -> bool:
	var unique_dice: Dictionary = {}
	for d: int in dice:
		unique_dice[d] = true
	for d: int in unique_dice.keys():
		if bar[owner] > 0:
			if _can_move(owner, 0, d)["valid"]:
				return true
			continue
		for point in range(1, 25):
			if _count_at(owner, point) > 0 and _can_move(owner, point, d)["valid"]:
				return true
	return false


func _start_turn() -> void:
	selected_point = -1
	var a: int = randi() % 6 + 1
	var b: int = randi() % 6 + 1
	dice = []
	_update_turn_status()
	_redraw_all()
	await UIKit.animate_dice_pair(self, dice_label, [a, b])
	dice = [a, a, a, a] if a == b else [a, b]
	_redraw_all()

	if not _has_any_legal_move(current_turn):
		status_label.text += "  (sin movimientos con %s)" % str(dice)
		await get_tree().create_timer(0.9).timeout
		_end_turn()
		return

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


func _end_turn() -> void:
	if borne_off[current_turn] >= 15:
		_end_game(current_turn)
		return
	current_turn = _opponent(current_turn)
	_start_turn()


func _on_bar_pressed() -> void:
	if game_over or (mode == "pve" and current_turn != "player"):
		return
	if bar[current_turn] <= 0 or dice.is_empty():
		return
	selected_point = 0
	_redraw_all()


func _on_point_pressed(point: int) -> void:
	if game_over or dice.is_empty():
		return
	if mode == "pve" and current_turn != "player":
		return

	var owner: String = current_turn

	if selected_point == -1:
		if bar[owner] > 0:
			return
		if _count_at(owner, point) > 0:
			selected_point = point
			_redraw_all()
		return

	if point == selected_point:
		selected_point = -1
		_redraw_all()
		return

	for d: int in dice.duplicate():
		var result: Dictionary = _can_move(owner, selected_point, d)
		if result["valid"] and not result["bear_off"] and result["to"] == point:
			_apply_move(owner, selected_point, d)
			selected_point = -1
			_after_partial_move()
			return

	if _count_at(owner, point) > 0:
		selected_point = point
	else:
		selected_point = -1
	_redraw_all()


func _on_bear_off_pressed() -> void:
	if game_over or dice.is_empty() or selected_point < 0:
		return
	if mode == "pve" and current_turn != "player":
		return

	var owner: String = current_turn
	for d: int in dice.duplicate():
		var result: Dictionary = _can_move(owner, selected_point, d)
		if result["valid"] and result["bear_off"]:
			_apply_move(owner, selected_point, d)
			selected_point = -1
			_after_partial_move()
			return


func _after_partial_move() -> void:
	if borne_off[current_turn] >= 15:
		_end_game(current_turn)
		return
	if dice.is_empty() or not _has_any_legal_move(current_turn):
		_redraw_all()
		_end_turn()
	else:
		_redraw_all()


func _pick_bot_move() -> Dictionary:
	var candidates: Array = []
	var unique_dice: Dictionary = {}
	for d: int in dice:
		unique_dice[d] = true

	var from_points: Array = [0]
	for p in range(1, 25):
		from_points.append(p)

	for from_point: int in from_points:
		if from_point == 0:
			if bar["bot"] <= 0:
				continue
		elif _count_at("bot", from_point) <= 0:
			continue
		for d: int in unique_dice.keys():
			var result: Dictionary = _can_move("bot", from_point, d)
			if result["valid"]:
				candidates.append({"from": from_point, "die": d, "result": result})

	if candidates.is_empty():
		return {}
	if difficulty == "easy":
		return candidates[randi() % candidates.size()]

	var best: Dictionary = candidates[0]
	var best_score: int = -999999
	for c: Dictionary in candidates:
		var score: int = _score_bot_move(c)
		if score > best_score:
			best_score = score
			best = c
	return best


func _score_bot_move(c: Dictionary) -> int:
	var result: Dictionary = c["result"]
	var score: int = c["die"]
	if result["bear_off"]:
		score += 50
	else:
		var to: int = result["to"]
		if _opponent_count_at("bot", to) == 1:
			score += 40
		if _count_at("bot", to) >= 1:
			score += 10
		elif difficulty == "hard":
			score -= 5
	return score


func _bot_take_turn() -> void:
	while not dice.is_empty():
		var move: Dictionary = _pick_bot_move()
		if move.is_empty():
			break
		_apply_move("bot", move["from"], move["die"])
		_redraw_all()
		await get_tree().create_timer(0.35).timeout
		if borne_off["bot"] >= 15:
			break
	_end_turn()


func _end_game(owner: String) -> void:
	game_over = true
	if mode == "pve":
		if owner == "player":
			status_label.text = "¡Ganaste! Sacaste tus 15 fichas"
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
	_redraw_all()


func _record_result(key: String) -> void:
	if key.begins_with("win") or key.begins_with("completed"):
		AudioManager.play_win()
	elif key.begins_with("loss") or key.begins_with("fail"):
		AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)


func _redraw_all() -> void:
	dice_label.text = "🎲 %s" % str(dice) if not dice.is_empty() else "🎲"

	bar_off_label.text = "Barra — Tú: %d  Máquina: %d      Fuera — Tú: %d/15  Máquina: %d/15" % [
		bar["player"], bar["bot"], borne_off["player"], borne_off["bot"],
	]

	var can_act: bool = not game_over and not dice.is_empty() and (mode == "pvp" or current_turn == "player")
	bar_btn.text = "Barra: %d ficha(s) tuyas — toca para reingresar" % bar[current_turn] if bar[current_turn] > 0 else "Barra vacía"
	bar_btn.disabled = not (can_act and bar[current_turn] > 0)
	UIKit.style_button(bar_btn, UIKit.COLOR_ACCENT_3 if selected_point == 0 else UIKit.COLOR_BG_LIGHT, 8)

	bear_off_btn.disabled = not (can_act and selected_point > 0)

	for p in range(1, 25):
		var btn: Button = point_buttons[p]
		var player_n: int = _count_at("player", p)
		var bot_n: int = _count_at("bot", p)
		var is_selected: bool = p == selected_point

		var bg: Color = UIKit.COLOR_BG_LIGHT
		if HOME_RANGE["player"][0] <= p and p <= HOME_RANGE["player"][1]:
			bg = UIKit.COLOR_ACCENT.lerp(UIKit.COLOR_BG, 0.8)
		elif HOME_RANGE["bot"][0] <= p and p <= HOME_RANGE["bot"][1]:
			bg = UIKit.COLOR_ACCENT_2.lerp(UIKit.COLOR_BG, 0.8)

		var border: Color = UIKit.COLOR_ACCENT_3 if is_selected else Color(0, 0, 0, 0)
		var bw: int = 3 if is_selected else 0
		var sb: StyleBoxFlat = UIKit.stylebox(bg, border, 4, bw)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("disabled", sb)
		btn.disabled = false

		if player_n > 0:
			btn.text = "%d\n●x%d" % [p, player_n]
			btn.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
			btn.add_theme_color_override("font_disabled_color", UIKit.COLOR_ACCENT)
		elif bot_n > 0:
			btn.text = "%d\n●x%d" % [p, bot_n]
			btn.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
			btn.add_theme_color_override("font_disabled_color", UIKit.COLOR_ACCENT_2)
		else:
			btn.text = str(p)
			btn.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
			btn.add_theme_color_override("font_disabled_color", UIKit.COLOR_TEXT_DIM)
