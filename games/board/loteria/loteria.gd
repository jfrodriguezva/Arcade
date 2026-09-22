extends Control
## Lotería Mexicana contra la máquina. Ambos reciben una tabla de 16
## cartas; el mazo (54 cartas clásicas) se canta una por una y hay que
## marcar tu tabla a tiempo. Gana quien complete primero una línea
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

const HELP_TEXT := "Tú y la máquina reciben una tabla de 16 cartas cada uno, tomadas al azar del mazo de 54.

- Toca 'Cantar siguiente' para revelar la próxima carta del mazo.
- Si esa carta está en tu tabla, tócala para marcarla (la máquina se marca sola).
- Gana quien complete primero una línea de 4: fila, columna o diagonal.

Si el mazo se acaba sin que nadie complete línea, es un empate."

var call_order: Array = []
var call_index: int = 0
var called_set: Dictionary = {}
var current_call: String = ""

var player_board: Array = []
var player_marked: Array = []
var bot_board: Array = []
var bot_marked: Array = []
var game_over: bool = false

var status_label: Label
var call_label: Label
var info_label: Label
var call_btn: Button
var board_buttons: Array = []


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

	vbox.add_child(UIKit.title_label("Tu tabla", 16, UIKit.COLOR_TEXT_DIM))

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_2, 16, 2))
	vbox.add_child(board_panel)
	var board_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		board_margin.add_theme_constant_override(side, 10)
	board_panel.add_child(board_margin)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	board_margin.add_child(grid)

	for i in range(16):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 110)
		btn.add_theme_font_size_override("font_size", 15)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		UIKit.style_button(btn, UIKit.COLOR_BG_LIGHT, 8)
		btn.pressed.connect(_on_card_pressed.bind(i))
		grid.add_child(btn)
		board_buttons.append(btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _new_game() -> void:
	call_order = DECK.duplicate()
	call_order.shuffle()
	call_index = 0
	called_set = {}
	current_call = ""
	game_over = false

	var shuffled: Array = DECK.duplicate()
	shuffled.shuffle()
	player_board = shuffled.slice(0, 16)

	shuffled.shuffle()
	bot_board = shuffled.slice(0, 16)

	player_marked = []
	bot_marked = []
	for i in range(16):
		player_marked.append(false)
		bot_marked.append(false)

	status_label.text = "Toca 'Cantar siguiente' para empezar"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
	_redraw_all()


func _redraw_all() -> void:
	call_label.text = "%s\n%s" % [ICONS.get(current_call, "🃏"), current_call] if current_call != "" else "—"
	call_btn.disabled = game_over or call_index >= call_order.size()

	var bot_count := 0
	for m: bool in bot_marked:
		if m:
			bot_count += 1
	info_label.text = "Cartas cantadas: %d/%d      Máquina marcó: %d/16" % [call_index, call_order.size(), bot_count]

	for i in range(16):
		var btn: Button = board_buttons[i]
		var name: String = player_board[i]
		btn.text = "%s\n%s" % [ICONS.get(name, "🃏"), name]
		if player_marked[i]:
			UIKit.style_button(btn, UIKit.COLOR_ACCENT_3, 8)
			btn.add_theme_color_override("font_color", UIKit.COLOR_BG)
		elif called_set.has(name):
			UIKit.style_button(btn, UIKit.COLOR_ACCENT, 8)
		else:
			UIKit.style_button(btn, UIKit.COLOR_BG_LIGHT, 8)


func _has_line(marked: Array) -> bool:
	for r in range(4):
		var row_ok := true
		for c in range(4):
			if not marked[r * 4 + c]:
				row_ok = false
				break
		if row_ok:
			return true

	for c in range(4):
		var col_ok := true
		for r in range(4):
			if not marked[r * 4 + c]:
				col_ok = false
				break
		if col_ok:
			return true

	var diag1 := true
	var diag2 := true
	for i in range(4):
		if not marked[i * 4 + i]:
			diag1 = false
		if not marked[i * 4 + (3 - i)]:
			diag2 = false
	return diag1 or diag2


func _on_call_pressed() -> void:
	if game_over or call_index >= call_order.size():
		return

	current_call = call_order[call_index]
	call_index += 1
	called_set[current_call] = true

	for i in range(16):
		if bot_board[i] == current_call:
			bot_marked[i] = true

	_redraw_all()

	if _has_line(bot_marked):
		_end_game(false)
		return

	if call_index >= call_order.size():
		status_label.text = "Última carta cantada"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		if not _has_line(player_marked):
			_end_game_draw()


func _on_card_pressed(i: int) -> void:
	if game_over:
		return
	var name: String = player_board[i]
	if not called_set.has(name):
		status_label.text = "'%s' todavía no ha salido" % name
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		return

	player_marked[i] = not player_marked[i]
	_redraw_all()

	if _has_line(player_marked):
		_end_game(true)


func _end_game(player_won: bool) -> void:
	game_over = true
	if player_won:
		status_label.text = "¡Lotería! Completaste la línea primero"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
		_record_result("wins")
	else:
		status_label.text = "La máquina cantó línea antes que tú"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result("losses")
	_redraw_all()


func _end_game_draw() -> void:
	game_over = true
	status_label.text = "Se acabó el mazo sin línea completa"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
	_record_result("draws")
	_redraw_all()


func _record_result(key: String) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
