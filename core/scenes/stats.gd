extends Control
## Pantalla de estadísticas: recorre GameManager.games y muestra los
## datos que cada juego ya guarda en SaveManager (wins/losses/best
## score/etc, el formato varía por juego así que se listan tal cual).

const KEY_LABELS := {
	"wins": "Victorias", "losses": "Derrotas", "draws": "Empates",
	"best_score": "Mejor puntaje",
}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var toolbar := HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(toolbar)
	var back_btn := Button.new()
	back_btn.text = "<  Volver"
	back_btn.custom_minimum_size = Vector2(120, 44)
	UIKit.style_button(back_btn, UIKit.COLOR_TEXT_DIM)
	back_btn.pressed.connect(func() -> void: GameManager.go_to_hub())
	toolbar.add_child(back_btn)

	vbox.add_child(UIKit.title_label("📊  Estadísticas", 30, UIKit.COLOR_ACCENT_3))

	var mesa_label := UIKit.title_label("Juegos de Mesa", 18, UIKit.COLOR_ACCENT_2)
	vbox.add_child(mesa_label)
	for game: Dictionary in GameManager.get_games_by_category("mesa"):
		vbox.add_child(_build_row(game))

	var arcade_label := UIKit.title_label("Arcade", 18, UIKit.COLOR_ACCENT)
	vbox.add_child(arcade_label)
	for game: Dictionary in GameManager.get_games_by_category("arcade"):
		vbox.add_child(_build_row(game))


func _build_row(game: Dictionary) -> Control:
	var data: Dictionary = SaveManager.get_game_data(game["id"])

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_2, 12, 1))
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 12)
	panel.add_child(m)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	m.add_child(row)

	var icon := UIKit.title_label(game.get("icon", "🎮"), 26, UIKit.COLOR_TEXT)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var title_lbl := Label.new()
	title_lbl.text = game.get("title", "?")
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
	info.add_child(title_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = _format_stats(data)
	stats_lbl.add_theme_font_size_override("font_size", 13)
	stats_lbl.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(stats_lbl)

	return panel


func _format_stats(data: Dictionary) -> String:
	if data.is_empty():
		return "Sin partidas registradas todavía"
	var parts: Array = []
	for key: String in data.keys():
		parts.append("%s: %s" % [KEY_LABELS.get(key, key.capitalize()), data[key]])
	return "   •   ".join(parts)
