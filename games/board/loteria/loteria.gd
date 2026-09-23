extends Control
## Lotería Mexicana: Vs Máquina (tu tabla vs la de la máquina, que se
## marca sola) o 2 Jugadores (ambas tablas visibles a la vez y cada
## quien marca la suya — no hay información que ocultar, como en la
## Lotería de mesa real, así que no hace falta pasar el dispositivo).
## El mazo se canta una por una; gana quien complete primero una línea
## (fila, columna o diagonal).

const GAME_ID := "loteria"

const DECK := [
	"El Gallo", "El Diablito", "La Dama", "El Catrín", "El Paraguas",
	"La Sirena", "La Escalera", "La Botella", "El Barril", "El Árbol",
	"El Melón", "El Valiente", "El Gorrito", "La Muerte", "La Pera",
	"La Bandera", "El Bandolón", "El Violoncello", "La Garza", "El Pájaro",
	"La Mano", "La Bota", "La Luna", "El Cotorro", "El Borracho",
	"El Negrito", "El Corazón", "La Sandía", "El Tambor", "El Camarón",
	"Las Jaras", "El Músico", "La Araña", "El Soldado", "La Estrella",
	"El Cazo", "El Mundo", "El Apache", "El Nopal", "El Alacrán",
	"La Rosa", "La Calavera", "La Campana", "El Cantarito", "El Venado",
	"El Sol", "La Corona", "La Chalupa", "El Pino", "El Pescado",
	"La Palma", "La Maceta", "El Arpa", "La Rana",
]

const ICONS := {
	"El Gallo": "🐓", "El Diablito": "😈", "La Dama": "👸", "El Catrín": "🎩", "El Paraguas": "☂️",
	"La Sirena": "🧜", "La Escalera": "🪜", "La Botella": "🍾", "El Barril": "🛢️", "El Árbol": "🌳",
	"El Melón": "🍈", "El Valiente": "🗡️", "El Gorrito": "🧢", "La Muerte": "💀", "La Pera": "🍐",
	"La Bandera": "🚩", "El Bandolón": "🎸", "El Violoncello": "🎻", "La Garza": "🦢", "El Pájaro": "🐦",
	"La Mano": "✋", "La Bota": "🥾", "La Luna": "🌙", "El Cotorro": "🦜", "El Borracho": "🍺",
	"El Negrito": "🧑", "El Corazón": "❤️", "La Sandía": "🍉", "El Tambor": "🥁", "El Camarón": "🦐",
	"Las Jaras": "🏹", "El Músico": "🎺", "La Araña": "🕷️", "El Soldado": "💂", "La Estrella": "⭐",
	"El Cazo": "🍲", "El Mundo": "🌍", "El Apache": "🪶", "El Nopal": "🌵", "El Alacrán": "🦂",
	"La Rosa": "🌹", "La Calavera": "☠️", "La Campana": "🔔", "El Cantarito": "🏺", "El Venado": "🦌",
	"El Sol": "☀️", "La Corona": "👑", "La Chalupa": "🛶", "El Pino": "🌲", "El Pescado": "🐟",
	"La Palma": "🌴", "La Maceta": "🪴", "El Arpa": "🎶", "La Rana": "🐸",
}

const HELP_TEXT := "Cada quien recibe una tabla de 16 cartas, tomadas al azar del mazo de 54.

- Toca 'Cantar siguiente' para revelar la próxima carta del mazo (cualquiera puede tocarlo).
- Si esa carta está en tu tabla, tócala para marcarla.
- Gana quien complete primero una línea de 4: fila, columna o diagonal.

En 2 Jugadores ambas tablas están a la vista todo el tiempo — como en la Lotería real, no hay nada que ocultar. Si el mazo se acaba sin que nadie complete línea, es empate."

var call_order: Array = []
var call_index: int = 0
var called_set: Dictionary = {}
var current_call: String = ""

var boards: Dictionary = {}
var marked: Dictionary = {}
var board_buttons: Dictionary = {}
var mode: String = "pve"
var game_over: bool = false

var status_label: Label
var call_label: Label
var info_label: Label
var call_btn: Button
var boards_container: VBoxContainer


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Lotería", true, false, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
	_build_boards_ui()
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

	UIKit.build_toolbar(vbox, self, "Lotería", HELP_TEXT)

	status_label = UIKit.title_label("", 20, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	var call_panel := PanelContainer.new()
	call_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 3))
	vbox.add_child(call_panel)
	var call_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		call_margin.add_theme_constant_override(side, 14)
	call_panel.add_child(call_margin)
	call_label = UIKit.title_label("—", 42, UIKit.COLOR_ACCENT_3)
	call_margin.add_child(call_label)

	call_btn = Button.new()
	call_btn.text = "🔔  Cantar siguiente"
	call_btn.custom_minimum_size = Vector2(220, 52)
	UIKit.style_button(call_btn, UIKit.COLOR_ACCENT)
	call_btn.pressed.connect(_on_call_pressed)
	vbox.add_child(call_btn)

	info_label = UIKit.title_label("", 15, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(info_label)

	boards_container = VBoxContainer.new()
	boards_container.add_theme_constant_override("separation", 12)
	vbox.add_child(boards_container)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Lotería", true, false, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _build_boards_ui() -> void:
	for child: Node in boards_container.get_children():
		child.queue_free()
	board_buttons = {"player": [], "bot": []}

	if mode == "pve":
		boards_container.add_child(UIKit.title_label("Tu tabla", 16, UIKit.COLOR_TEXT_DIM))
		boards_container.add_child(_build_board_panel("player", UIKit.COLOR_ACCENT_2))
	else:
		boards_container.add_child(UIKit.title_label("Jugador 1 (rosa)", 16, UIKit.COLOR_ACCENT))
		boards_container.add_child(_build_board_panel("player", UIKit.COLOR_ACCENT))
		boards_container.add_child(UIKit.title_label("Jugador 2 (teal)", 16, UIKit.COLOR_ACCENT_2))
		boards_container.add_child(_build_board_panel("bot", UIKit.COLOR_ACCENT_2))


func _build_board_panel(owner: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, accent, 16, 2))
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 10)
	panel.add_child(m)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	m.add_child(grid)

	var card_size: Vector2 = Vector2(150, 110) if mode == "pve" else Vector2(140, 100)
	var list: Array = []
	for i in range(16):
		var btn := Button.new()
		btn.custom_minimum_size = card_size
		btn.add_theme_font_size_override("font_size", 14)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		UIKit.style_button(btn, UIKit.COLOR_BG_LIGHT, 8)
		btn.pressed.connect(_on_card_pressed.bind(owner, i))
		grid.add_child(btn)
		list.append(btn)
	board_buttons[owner] = list
	return panel


func _new_game() -> void:
	call_order = DECK.duplicate()
	call_order.shuffle()
	call_index = 0
	called_set = {}
	current_call = ""
	game_over = false

	var shuffled: Array = DECK.duplicate()
	shuffled.shuffle()
	boards["player"] = shuffled.slice(0, 16)
	shuffled.shuffle()
	boards["bot"] = shuffled.slice(0, 16)

	marked["player"] = []
	marked["bot"] = []
	for i in range(16):
		marked["player"].append(false)
		marked["bot"].append(false)

	status_label.text = "Toca 'Cantar siguiente' para empezar"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
	_redraw_all()


func _redraw_all() -> void:
	call_label.text = "%s\n%s" % [ICONS.get(current_call, "🃏"), current_call] if current_call != "" else "—"
	call_btn.disabled = game_over or call_index >= call_order.size()

	if mode == "pve":
		var bot_count := 0
		for m: bool in marked["bot"]:
			if m:
				bot_count += 1
		info_label.text = "Cartas cantadas: %d/%d      Máquina marcó: %d/16" % [call_index, call_order.size(), bot_count]
		_redraw_board("player")
	else:
		info_label.text = "Cartas cantadas: %d/%d" % [call_index, call_order.size()]
		_redraw_board("player")
		_redraw_board("bot")


func _redraw_board(owner: String) -> void:
	for i in range(16):
		var btn: Button = board_buttons[owner][i]
		var name: String = boards[owner][i]
		btn.text = "%s\n%s" % [ICONS.get(name, "🃏"), name]
		if marked[owner][i]:
			UIKit.style_button(btn, UIKit.COLOR_ACCENT_3, 8)
			btn.add_theme_color_override("font_color", UIKit.COLOR_BG)
		elif called_set.has(name):
			UIKit.style_button(btn, UIKit.COLOR_ACCENT, 8)
		else:
			UIKit.style_button(btn, UIKit.COLOR_BG_LIGHT, 8)


func _has_line(m: Array) -> bool:
	for r in range(4):
		var row_ok := true
		for c in range(4):
			if not m[r * 4 + c]:
				row_ok = false
				break
		if row_ok:
			return true

	for c in range(4):
		var col_ok := true
		for r in range(4):
			if not m[r * 4 + c]:
				col_ok = false
				break
		if col_ok:
			return true

	var diag1 := true
	var diag2 := true
	for i in range(4):
		if not m[i * 4 + i]:
			diag1 = false
		if not m[i * 4 + (3 - i)]:
			diag2 = false
	return diag1 or diag2


func _on_call_pressed() -> void:
	if game_over or call_index >= call_order.size():
		return

	current_call = call_order[call_index]
	call_index += 1
	called_set[current_call] = true

	if mode == "pve":
		for i in range(16):
			if boards["bot"][i] == current_call:
				marked["bot"][i] = true

	_redraw_all()

	if mode == "pve" and _has_line(marked["bot"]):
		_end_game("bot")
		return

	if call_index >= call_order.size():
		status_label.text = "Última carta cantada"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		var anyone_won: bool = _has_line(marked["player"]) or (mode == "pvp" and _has_line(marked["bot"]))
		if not anyone_won:
			_end_game_draw()


func _on_card_pressed(owner: String, i: int) -> void:
	if game_over:
		return
	if mode == "pve" and owner != "player":
		return

	var name: String = boards[owner][i]
	if not called_set.has(name):
		status_label.text = "'%s' todavía no ha salido" % name
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
			status_label.text = "¡Lotería! Completaste la línea primero"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		else:
			status_label.text = "La máquina cantó línea antes que tú"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
	else:
		var label: String = "Jugador 1 (rosa)" if winner == "player" else "Jugador 2 (teal)"
		status_label.text = "¡Lotería! Ganó %s" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
		AudioManager.play_win()
	_redraw_all()


func _end_game_draw() -> void:
	game_over = true
	status_label.text = "Se acabó el mazo sin línea completa"
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
