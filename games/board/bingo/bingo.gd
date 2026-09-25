extends Control
## Bingo (75 bolas). Vs Máquina (tu cartón vs el de la máquina, que se
## marca sola) o 2 Jugadores (ambos cartones a la vista, cada quien
## marca el suyo). Se canta una bola a la vez; gana quien complete
## primero una línea (fila, columna o diagonal) en su cartón.

const GAME_ID := "bingo"
const LETTERS := ["B", "I", "N", "G", "O"]
const RANGES := [[1, 15], [16, 30], [31, 45], [46, 60], [61, 75]]
const FREE := -1
const LETTER_COLORS := {
	"B": Color(1.0, 0.365, 0.451),
	"I": Color(0.306, 0.804, 0.769),
	"N": Color(1.0, 0.820, 0.400),
	"G": Color(0.62, 0.42, 0.91),
	"O": Color(0.40, 0.75, 0.45),
}

const HELP_TEXT := "Cada quien recibe un cartón de 5x5 (columnas B-I-N-G-O), con el centro libre de entrada.

- Toca 'Cantar bola' para sacar el siguiente número (cualquiera puede tocarlo).
- Si ese número está en tu cartón, tócalo para marcarlo.
- Gana quien complete primero una línea de 5: fila, columna o diagonal.

En 2 Jugadores ambos cartones están a la vista todo el tiempo. Si las 75 bolas salen sin que nadie complete línea, es empate."

var call_order: Array = []
var call_index: int = 0
var called_set: Dictionary = {}
var current_call: int = 0

var cards: Dictionary = {}
var marked: Dictionary = {}
var card_buttons: Dictionary = {}
var mode: String = "pve"
var game_over: bool = false

var status_label: Label
var call_ball: BingoBall
var info_label: Label
var call_btn: Button
var cards_container: VBoxContainer


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Bingo", true, false, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
	_build_cards_ui()
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

	UIKit.build_toolbar(vbox, self, "Bingo", HELP_TEXT)

	status_label = UIKit.title_label("", 20, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	var call_panel := PanelContainer.new()
	call_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 3))
	vbox.add_child(call_panel)
	var call_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		call_margin.add_theme_constant_override(side, 14)
	call_panel.add_child(call_margin)
	var call_vbox := VBoxContainer.new()
	call_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	call_vbox.add_theme_constant_override("separation", 2)
	call_margin.add_child(call_vbox)
	call_ball = BingoBall.new()
	call_ball.custom_minimum_size = Vector2(120, 120)
	call_vbox.add_child(call_ball)

	call_btn = Button.new()
	call_btn.text = "🔔  Cantar bola"
	call_btn.custom_minimum_size = Vector2(220, 52)
	UIKit.style_button(call_btn, UIKit.COLOR_ACCENT)
	call_btn.pressed.connect(_on_call_pressed)
	vbox.add_child(call_btn)

	info_label = UIKit.title_label("", 15, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(info_label)

	cards_container = VBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 12)
	vbox.add_child(cards_container)

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Bingo", true, false, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _build_cards_ui() -> void:
	for child: Node in cards_container.get_children():
		child.queue_free()
	card_buttons = {"player": [], "bot": []}

	if mode == "pve":
		cards_container.add_child(UIKit.title_label("Tu cartón", 16, UIKit.COLOR_TEXT_DIM))
		cards_container.add_child(_build_card_panel("player", UIKit.COLOR_ACCENT_2))
	else:
		cards_container.add_child(UIKit.title_label("Jugador 1 (rosa)", 16, UIKit.COLOR_ACCENT))
		cards_container.add_child(_build_card_panel("player", UIKit.COLOR_ACCENT))
		cards_container.add_child(UIKit.title_label("Jugador 2 (teal)", 16, UIKit.COLOR_ACCENT_2))
		cards_container.add_child(_build_card_panel("bot", UIKit.COLOR_ACCENT_2))


func _build_card_panel(owner: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, accent, 16, 2))
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 10)
	panel.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	m.add_child(vbox)

	var header := GridContainer.new()
	header.columns = 5
	header.add_theme_constant_override("h_separation", 4)
	vbox.add_child(header)
	for letter: String in LETTERS:
		header.add_child(UIKit.title_label(letter, 18, accent))

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	var size: Vector2 = Vector2(64, 64) if mode == "pve" else Vector2(56, 56)
	var list: Array = []
	for i in range(25):
		var btn := Button.new()
		btn.custom_minimum_size = size
		UIKit.style_button(btn, UIKit.COLOR_BG_LIGHT, 8)
		btn.pressed.connect(_on_card_pressed.bind(owner, i))
		grid.add_child(btn)
		list.append(btn)
	card_buttons[owner] = list
	return panel


func _generate_card() -> Array:
	var columns: Array = []
	for col in range(5):
		var pool: Array = range(RANGES[col][0], RANGES[col][1] + 1)
		pool.shuffle()
		columns.append(pool.slice(0, 5))

	var flat: Array = []
	for row in range(5):
		for col in range(5):
			if row == 2 and col == 2:
				flat.append(FREE)
			else:
				flat.append(columns[col][row])
	return flat


func _new_game() -> void:
	call_order = range(1, 76)
	call_order.shuffle()
	call_index = 0
	called_set = {}
	current_call = 0
	game_over = false

	cards["player"] = _generate_card()
	cards["bot"] = _generate_card()

	marked["player"] = []
	marked["bot"] = []
	for i in range(25):
		marked["player"].append(cards["player"][i] == FREE)
		marked["bot"].append(cards["bot"][i] == FREE)

	status_label.text = "Toca 'Cantar bola' para empezar"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
	_redraw_all()


func _letter_for(n: int) -> String:
	for i in range(5):
		if n >= RANGES[i][0] and n <= RANGES[i][1]:
			return LETTERS[i]
	return "?"


func _redraw_all() -> void:
	if current_call > 0:
		var letter: String = _letter_for(current_call)
		call_ball.set_ball(letter, current_call, LETTER_COLORS[letter])
	else:
		call_ball.clear_ball()
	call_btn.disabled = game_over or call_index >= call_order.size()

	if mode == "pve":
		var bot_count := 0
		for m: bool in marked["bot"]:
			if m:
				bot_count += 1
		info_label.text = "Bolas cantadas: %d/75      Máquina marcó: %d/25" % [call_index, bot_count]
		_redraw_card("player")
	else:
		info_label.text = "Bolas cantadas: %d/75" % call_index
		_redraw_card("player")
		_redraw_card("bot")


func _redraw_card(owner: String) -> void:
	for i in range(25):
		var btn: Button = card_buttons[owner][i]
		var n: int = cards[owner][i]
		if n == FREE:
			btn.text = "★"
			UIKit.style_button(btn, UIKit.COLOR_ACCENT_3, 8)
			continue

		btn.text = str(n)
		if marked[owner][i]:
			UIKit.style_button(btn, UIKit.COLOR_ACCENT_3, 8)
		elif called_set.has(n):
			UIKit.style_button(btn, UIKit.COLOR_ACCENT, 8)
		else:
			UIKit.style_button(btn, UIKit.COLOR_BG_LIGHT, 8)


func _has_line(m: Array) -> bool:
	for r in range(5):
		var row_ok := true
		for c in range(5):
			if not m[r * 5 + c]:
				row_ok = false
				break
		if row_ok:
			return true

	for c in range(5):
		var col_ok := true
		for r in range(5):
			if not m[r * 5 + c]:
				col_ok = false
				break
		if col_ok:
			return true

	var diag1 := true
	var diag2 := true
	for i in range(5):
		if not m[i * 5 + i]:
			diag1 = false
		if not m[i * 5 + (4 - i)]:
			diag2 = false
	return diag1 or diag2


func _on_call_pressed() -> void:
	if game_over or call_index >= call_order.size():
		return

	current_call = call_order[call_index]
	call_index += 1
	called_set[current_call] = true

	if mode == "pve":
		for i in range(25):
			if cards["bot"][i] == current_call:
				marked["bot"][i] = true

	_redraw_all()

	if mode == "pve" and _has_line(marked["bot"]):
		_end_game("bot")
		return

	if call_index >= call_order.size():
		status_label.text = "Última bola cantada"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		var anyone_won: bool = _has_line(marked["player"]) or (mode == "pvp" and _has_line(marked["bot"]))
		if not anyone_won:
			_end_game_draw()


func _on_card_pressed(owner: String, i: int) -> void:
	if game_over:
		return
	if mode == "pve" and owner != "player":
		return

	var n: int = cards[owner][i]
	if n == FREE:
		return
	if not called_set.has(n):
		status_label.text = "El %d todavía no ha salido" % n
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		return

	marked[owner][i] = not marked[owner][i]
	_redraw_all()

	if _has_line(marked[owner]):
		_end_game(owner)


func _end_game(winner: String) -> void:
	game_over = true
	if mode == "pve":
		if winner == "player":
			status_label.text = "¡Bingo! Completaste la línea primero"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		else:
			status_label.text = "La máquina cantó línea antes que tú"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
	else:
		var label: String = "Jugador 1 (rosa)" if winner == "player" else "Jugador 2 (teal)"
		status_label.text = "¡Bingo! Ganó %s" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
		AudioManager.play_win()
	_redraw_all()


func _end_game_draw() -> void:
	game_over = true
	status_label.text = "Se acabaron las bolas sin línea completa"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
	if mode == "pve":
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
