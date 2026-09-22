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
	_update_category_highlight()
	_refresh_grid()


const CATEGORY_ACCENTS := {
	"mesa": UIKit.COLOR_ACCENT_2,
	"arcade": UIKit.COLOR_ACCENT,
}

var category_buttons: Dictionary = {}


func _build_ui() -> void:
	UIKit.apply_background(self)

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

	var title_label := UIKit.title_label("🕹  ARCADE PLATFORM", 34, UIKit.COLOR_ACCENT_3)
	vbox.add_child(title_label)

	var category_bar := HBoxContainer.new()
	category_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	category_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(category_bar)

	for category_id: String in CATEGORY_LABELS.keys():
		var btn := Button.new()
		btn.text = CATEGORY_LABELS[category_id]
		btn.custom_minimum_size = Vector2(160, 48)
		UIKit.style_button(btn, CATEGORY_ACCENTS.get(category_id, UIKit.COLOR_ACCENT))
		btn.pressed.connect(_on_category_pressed.bind(category_id))
		category_bar.add_child(btn)
		category_buttons[category_id] = btn

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
	_update_category_highlight()
	_refresh_grid()


func _update_category_highlight() -> void:
	for category_id: String in category_buttons.keys():
		var btn: Button = category_buttons[category_id]
		var accent: Color = CATEGORY_ACCENTS.get(category_id, UIKit.COLOR_ACCENT)
		if category_id == current_category:
			btn.add_theme_stylebox_override("normal", UIKit.stylebox(accent, accent, 14, 2))
			btn.add_theme_color_override("font_color", UIKit.COLOR_BG)
		else:
			UIKit.style_button(btn, accent)


func _refresh_grid() -> void:
	for child: Node in grid.get_children():
		child.queue_free()

	var list: Array[Dictionary] = GameManager.get_games_by_category(current_category)
	if list.is_empty():
		grid.add_child(UIKit.title_label("Próximamente...", 20, UIKit.COLOR_TEXT_DIM))
		return

	for game: Dictionary in list:
		grid.add_child(_build_game_card(game))


func _build_game_card(game: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 130)
	UIKit.style_button(btn, CATEGORY_ACCENTS.get(game.get("category", ""), UIKit.COLOR_ACCENT), 18)
	btn.pressed.connect(func() -> void: GameManager.go_to_game(game["id"]))

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 4)
	btn.add_child(inner)

	var icon_label := UIKit.title_label(game.get("icon", "🎮"), 40, UIKit.COLOR_TEXT)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon_label)

	var title_lbl := UIKit.title_label(game.get("title", game.get("id", "?")), 18, UIKit.COLOR_TEXT)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(title_lbl)

	return btn
