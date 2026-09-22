extends Control
## Gato (Tic-Tac-Toe) local, 2 jugadores en el mismo dispositivo.

const GAME_ID := "tictactoe"
const WIN_LINES := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6],
]

var board: Array[String] = []
var current_player: String = "X"
var game_over: bool = false
var cell_buttons: Array[Button] = []

var status_label: Label


func _ready() -> void:
	_build_ui()
	_new_game()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var back_btn := Button.new()
	back_btn.text = "< Volver"
	back_btn.pressed.connect(func() -> void: GameManager.go_to_hub())
	vbox.add_child(back_btn)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(status_label)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_center)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid_center.add_child(grid)

	for i in range(9):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(96, 96)
		cell.add_theme_font_size_override("font_size", 40)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(cell)
		cell_buttons.append(cell)

	var restart_btn := Button.new()
	restart_btn.text = "Reiniciar"
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _new_game() -> void:
	board.clear()
	for i in range(9):
		board.append("")
	current_player = "X"
	game_over = false
	for cell: Button in cell_buttons:
		cell.text = ""
		cell.disabled = false
	status_label.text = "Turno: %s" % current_player


func _on_cell_pressed(index: int) -> void:
	if game_over or board[index] != "":
		return

	board[index] = current_player
	cell_buttons[index].text = current_player
	cell_buttons[index].disabled = true

	var winner := _check_winner()
	if winner != "":
		game_over = true
		status_label.text = "¡Gana %s!" % winner
		_record_result(winner)
		return

	if not board.has(""):
		game_over = true
		status_label.text = "Empate"
		_record_result("draw")
		return

	current_player = "O" if current_player == "X" else "X"
	status_label.text = "Turno: %s" % current_player


func _check_winner() -> String:
	for line: Array in WIN_LINES:
		var a: String = board[line[0]]
		var b: String = board[line[1]]
		var c: String = board[line[2]]
		if a != "" and a == b and b == c:
			return a
	return ""


func _record_result(result: String) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[result] = stats.get(result, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
