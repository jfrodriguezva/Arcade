extends Control
## Memorama (Concentración): cartas boca abajo en parejas de frutas y
## verduras. El tamaño del tablero y la cantidad de imágenes crecen con
## la dificultad (fácil 4x3, medio 6x4, difícil 6x6). Vs Máquina (con
## memoria imperfecta según la dificultad) o 2 Jugadores pasando el
## turno. Si aciertas un par, repites turno; si fallas, pasa el turno.

const GAME_ID := "memorama"
const ICONS := [
	"🍎", "🍋", "🍇", "🍓", "🍉", "🍒", "🥝", "🍑", "🍍",
	"🥥", "🍌", "🍈", "🍐", "🍊", "🍅", "🥑", "🍆", "🌽",
]
const GRID_SIZES := {"easy": [4, 3], "medium": [6, 4], "hard": [6, 6]}

const MEMORY_CHANCE := {"easy": 0.25, "medium": 0.6, "hard": 0.95}

const HELP_TEXT := "Cartas boca abajo en parejas de frutas y verduras. Puedes jugar contra la máquina (con distintos niveles de 'memoria', y tableros más grandes con más imágenes en dificultades más altas) o pasando el dispositivo entre 2 personas.

- Toca una carta para voltearla, y luego otra para intentar formar un par.
- Si coinciden, se quedan boca arriba y repites turno.
- Si no coinciden, se voltean de nuevo y pasa el turno al otro jugador.
- Gana quien forme más pares cuando se acaben todas las cartas."

var cols: int = 6
var rows: int = 4
var total: int = 24

var deck: Array = []
var matched: Array = []
var flipped: Array = []
var input_locked: bool = false
var current_turn: String = "player"
var mode: String = "pve"
var difficulty: String = "medium"
var game_over: bool = false
var scores: Dictionary = {"player": 0, "bot": 0}
var bot_memory: Dictionary = {}

var status_label: Label
var score_label: Label
var grid: GridContainer
var card_buttons: Array = []


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Memorama", true, true, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
	difficulty = config["difficulty"]
	_build_grid_ui()
	_new_game()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Memorama", HELP_TEXT)

	status_label = UIKit.title_label("", 20, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	score_label = UIKit.title_label("", 16, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(score_label)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 3))
	var panel_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		panel_margin.add_theme_constant_override(side, 10)
	panel.add_child(panel_margin)

	var center := CenterContainer.new()
	vbox.add_child(center)
	center.add_child(panel)

	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	panel_margin.add_child(grid)

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Memorama", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _build_grid_ui() -> void:
	var dims: Array = GRID_SIZES.get(difficulty, [6, 4])
	cols = dims[0]
	rows = dims[1]
	total = cols * rows

	for child: Node in grid.get_children():
		child.queue_free()
	card_buttons = []
	grid.columns = cols

	var compact: bool = total > 24
	var card_size: Vector2 = Vector2(52, 52) if compact else Vector2(64, 64)
	var font_size: int = 26 if compact else 32
	for i in range(total):
		var btn := Button.new()
		btn.custom_minimum_size = card_size
		UIKit.style_button(btn, UIKit.COLOR_BG_LIGHT, 10)
		btn.add_theme_font_size_override("font_size", font_size)
		btn.pressed.connect(_on_card_pressed.bind(i))
		grid.add_child(btn)
		card_buttons.append(btn)


func _new_game() -> void:
	var pairs: int = total / 2
	var icon_pool: Array = ICONS.duplicate()
	icon_pool.shuffle()
	var chosen_icons: Array = icon_pool.slice(0, pairs)

	deck = []
	for icon: String in chosen_icons:
		deck.append(icon)
		deck.append(icon)
	deck.shuffle()

	matched = []
	for i in range(total):
		matched.append(false)
	flipped = []
	input_locked = false
	game_over = false
	scores = {"player": 0, "bot": 0}
	bot_memory = {}
	current_turn = "player"

	_redraw_all()
	_update_status()


func _redraw_all() -> void:
	for i in range(total):
		var btn: Button = card_buttons[i]
		if matched[i]:
			btn.text = deck[i]
			UIKit.style_button(btn, UIKit.COLOR_ACCENT_3, 10)
			btn.disabled = true
		elif flipped.has(i):
			btn.text = deck[i]
			UIKit.style_button(btn, UIKit.COLOR_ACCENT_2, 10)
			btn.disabled = true
		else:
			btn.text = ""
			UIKit.style_button(btn, UIKit.COLOR_BG_LIGHT, 10)
			btn.disabled = input_locked or game_over or (mode == "pve" and current_turn != "player")

	if mode == "pve":
		score_label.text = "Tú: %d pares      Máquina: %d pares" % [scores["player"], scores["bot"]]
	else:
		score_label.text = "Jugador 1 (rosa): %d pares      Jugador 2 (teal): %d pares" % [scores["player"], scores["bot"]]


func _turn_label(owner: String) -> String:
	if mode == "pve":
		return "Tú" if owner == "player" else "La máquina"
	return "Jugador 1 (rosa)" if owner == "player" else "Jugador 2 (teal)"


func _update_status() -> void:
	if game_over:
		return
	status_label.text = "Turno: %s" % _turn_label(current_turn)
	var color: Color = UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2
	status_label.add_theme_color_override("font_color", color)


func _on_card_pressed(i: int) -> void:
	if game_over or input_locked or matched[i] or flipped.has(i):
		return
	if mode == "pve" and current_turn != "player":
		return

	_reveal(i)
	if flipped.size() == 2:
		await _resolve_flip()


func _reveal(i: int) -> void:
	flipped.append(i)
	_redraw_all()


func _resolve_flip() -> void:
	input_locked = true
	_redraw_all()
	await get_tree().create_timer(0.6).timeout

	var a: int = flipped[0]
	var b: int = flipped[1]
	var is_match: bool = deck[a] == deck[b]

	if is_match:
		matched[a] = true
		matched[b] = true
		scores[current_turn] += 1
		flipped = []
		input_locked = false
		bot_memory.erase(a)
		bot_memory.erase(b)
		_redraw_all()

		if _all_matched():
			_end_game()
			return

		_update_status()
		if mode == "pve" and current_turn == "bot":
			await get_tree().create_timer(0.5).timeout
			_bot_take_turn()
		return

	flipped = []
	input_locked = false
	current_turn = "bot" if current_turn == "player" else "player"
	_redraw_all()
	_update_status()
	if mode == "pve" and current_turn == "bot":
		await get_tree().create_timer(0.5).timeout
		_bot_take_turn()


func _all_matched() -> bool:
	for m: bool in matched:
		if not m:
			return false
	return true


func _unrevealed_indices() -> Array:
	var list: Array = []
	for i in range(total):
		if not matched[i] and not flipped.has(i):
			list.append(i)
	return list


func _bot_take_turn() -> void:
	if game_over:
		return
	var chance: float = MEMORY_CHANCE.get(difficulty, 0.6)

	var known_pair: Array = _find_known_pair()
	var first: int = -1
	var second: int = -1

	if not known_pair.is_empty() and randf() < chance:
		first = known_pair[0]
		second = known_pair[1]
	else:
		var options: Array = _unrevealed_indices()
		if options.is_empty():
			return
		first = options[randi() % options.size()]

	input_locked = true
	_reveal(first)
	bot_memory[first] = deck[first]
	await get_tree().create_timer(0.6).timeout

	if second == -1:
		var match_idx: int = _known_match_for(deck[first], first)
		if match_idx != -1 and randf() < chance:
			second = match_idx
		else:
			var options: Array = _unrevealed_indices()
			options.erase(first)
			if options.is_empty():
				return
			second = options[randi() % options.size()]

	_reveal(second)
	bot_memory[second] = deck[second]
	await _resolve_flip()


func _find_known_pair() -> Array:
	var seen: Dictionary = {}
	for idx: int in bot_memory.keys():
		if matched[idx] or flipped.has(idx):
			continue
		var icon: String = bot_memory[idx]
		if seen.has(icon):
			return [seen[icon], idx]
		seen[icon] = idx
	return []


func _known_match_for(icon: String, exclude: int) -> int:
	for idx: int in bot_memory.keys():
		if idx == exclude or matched[idx] or flipped.has(idx):
			continue
		if bot_memory[idx] == icon:
			return idx
	return -1


func _end_game() -> void:
	game_over = true
	var p: int = scores["player"]
	var b: int = scores["bot"]

	if mode == "pve":
		if p > b:
			status_label.text = "¡Ganaste! %d - %d pares" % [p, b]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		elif b > p:
			status_label.text = "Ganó la máquina %d - %d pares" % [b, p]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
		else:
			status_label.text = "Empate %d - %d pares" % [p, b]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
			_record_result("draws")
	else:
		if p == b:
			status_label.text = "Empate %d - %d pares" % [p, b]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		else:
			var winner: String = "Jugador 1 (rosa)" if p > b else "Jugador 2 (teal)"
			status_label.text = "¡Ganó %s! %d - %d pares" % [winner, max(p, b), min(p, b)]
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
