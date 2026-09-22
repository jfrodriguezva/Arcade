extends Control
## Menú principal: pestañas por categoría + grilla de juegos.
## La grilla se reconstruye desde GameManager.games, así que agregar
## un juego nuevo no requiere tocar este archivo.

const CATEGORY_LABELS := {
	"mesa": "Juegos de Mesa",
	"arcade": "Arcade",
}

var current_category: String = "mesa"

var grid: GridContainer
var status_label: Label


func _ready() -> void:
	_build_ui()
	_refresh_grid()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Arcade Platform"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var category_bar := HBoxContainer.new()
	category_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	category_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(category_bar)

	for category_id: String in CATEGORY_LABELS.keys():
		var btn := Button.new()
		btn.text = CATEGORY_LABELS[category_id]
		btn.custom_minimum_size = Vector2(160, 48)
		btn.pressed.connect(_on_category_pressed.bind(category_id))
		category_bar.add_child(btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)


func _on_category_pressed(category_id: String) -> void:
	current_category = category_id
	_refresh_grid()


func _refresh_grid() -> void:
	for child: Node in grid.get_children():
		child.queue_free()

	var list: Array[Dictionary] = GameManager.get_games_by_category(current_category)
	if list.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Próximamente..."
		grid.add_child(empty_label)
		return

	for game: Dictionary in list:
		grid.add_child(_build_game_card(game))


func _build_game_card(game: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = game.get("title", game.get("id", "?"))
	btn.custom_minimum_size = Vector2(300, 120)
	btn.pressed.connect(func() -> void: GameManager.go_to_game(game["id"]))
	return btn
