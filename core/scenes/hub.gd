extends Control
## Menú principal. Pestañas: Inicio (seguir jugando, favoritos y nuevos),
## Mesa y Arcade. Cada tarjeta muestra el ícono, una frase del juego, tu
## récord y una estrella para marcarlo como favorito. Arriba hay accesos
## rápidos a estadísticas, sonido, música y vibración.
##
## La lista de juegos sale de GameManager.games, así que agregar un juego
## nuevo no requiere tocar este archivo (la frase es opcional, ver
## TAGLINES).

const TABS := [
	{"id": "inicio", "label": "⭐ Inicio"},
	{"id": "mesa", "label": "🎲 Mesa"},
	{"id": "arcade", "label": "🕹 Arcade"},
]
const CATEGORY_ACCENTS := {
	"mesa": UIKit.COLOR_ACCENT_2,
	"arcade": UIKit.COLOR_ACCENT,
}
## Juegos recién agregados (llevan la etiqueta NUEVO).
const NEW_GAMES := ["ecos", "burbujas", "dino_runner", "dulce_fiesta", "invasion_espacial"]
const TAGLINES := {
	"tictactoe": "Tres en línea clásico",
	"connect_four": "Alinea cuatro fichas",
	"othello": "Encierra y voltea fichas",
	"battleship": "Hunde la flota rival",
	"checkers": "Con bobas, como en casa",
	"chinese_checkers": "Cruza la estrella",
	"chess": "El juego de reyes",
	"backgammon": "Dados y estrategia",
	"domino": "Cuadra las fichas",
	"loteria": "¡Lotería! con las cartas",
	"bingo": "Canta y marca",
	"generala": "Póker con dados",
	"parchis": "Lleva tus fichas a casa",
	"snakes_ladders": "Sube y no resbales",
	"solitaire": "El clásico Klondike",
	"spider_solitaire": "Ordena los palos",
	"mahjong": "Encuentra parejas",
	"memorama": "Pon a prueba tu memoria",
	"dulce_fiesta": "Combina 3 dulces",
	"sudoku": "Del 1 al 9 sin repetir",
	"arkanoid": "Rompe ladrillos y vence a Doh",
	"block_stacker": "Acomoda las piezas",
	"asteroids": "Destruye las rocas",
	"galaga_swarm": "Formaciones y desafíos",
	"invasion_espacial": "Jefes, planetas y ovnis",
	"maze_muncher": "Come puntos, huye de fantasmas",
	"bomber_maze": "Bombas en el laberinto",
	"panic_reveal": "Traza y revela el paisaje",
	"snow_brawl": "Haz bolas de nieve",
	"ecos": "Juega con tus ecos",
	"burbujas": "Revienta globos con tu arpón",
	"dino_runner": "Corre y salta cactus",
}
const MAX_RECENT := 4

var current_tab: String = "inicio"
var tab_buttons: Dictionary = {}
var content: VBoxContainer
var toggles: Dictionary = {}


func _ready() -> void:
	_build_ui()
	if _hub_data().get("recent", []).is_empty() and _hub_data().get("favorites", []).is_empty():
		current_tab = "mesa"  # primera vez: no hay nada que mostrar en Inicio
	_select_tab(current_tab)


func _hub_data() -> Dictionary:
	return SaveManager.get_game_data("_hub")


func _build_ui() -> void:
	UIKit.apply_background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := UIKit.title_label("🕹  ARCADE PLATFORM", 32, UIKit.COLOR_ACCENT_3)
	vbox.add_child(title)
	var subtitle := UIKit.title_label("%d juegos de mesa y arcade" % GameManager.games.filter(func(g: Dictionary) -> bool: return g["enabled"]).size(), 14, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(subtitle)

	# Accesos rápidos: estadísticas y encender/apagar sonido, música y vibración.
	var quick := HBoxContainer.new()
	quick.alignment = BoxContainer.ALIGNMENT_CENTER
	quick.add_theme_constant_override("separation", 10)
	vbox.add_child(quick)
	var stats_btn := _small_button("📊  Estadísticas", UIKit.COLOR_ACCENT_3)
	stats_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://core/scenes/stats.tscn"))
	quick.add_child(stats_btn)
	_add_toggle(quick, "sfx", "🔊", "🔇", func() -> bool: return float(SettingsManager.get_value("sfx_volume", 0.8)) > 0.0,
		func(on: bool) -> void: SettingsManager.set_value("sfx_volume", 0.8 if on else 0.0))
	_add_toggle(quick, "music", "🎵", "🎵", func() -> bool: return float(SettingsManager.get_value("music_volume", 0.8)) > 0.0,
		func(on: bool) -> void: SettingsManager.set_value("music_volume", 0.8 if on else 0.0))
	_add_toggle(quick, "vibe", "📳", "📴", func() -> bool: return bool(SettingsManager.get_value("vibration", true)),
		func(on: bool) -> void:
			SettingsManager.set_value("vibration", on)
			if on:
				AudioManager.vibrate(60))

	var tab_bar := HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", 10)
	vbox.add_child(tab_bar)
	for t: Dictionary in TABS:
		var btn := Button.new()
		btn.text = t["label"]
		btn.custom_minimum_size = Vector2(170, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_select_tab.bind(t["id"]))
		tab_bar.add_child(btn)
		tab_buttons[t["id"]] = btn

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)


func _small_button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 16)
	UIKit.style_button(b, accent)
	return b


func _add_toggle(parent: Control, key: String, on_icon: String, off_icon: String, getter: Callable, setter: Callable) -> void:
	var b := _small_button("", UIKit.COLOR_TEXT_DIM)
	b.custom_minimum_size = Vector2(60, 44)
	b.add_theme_font_size_override("font_size", 22)
	var refresh := func() -> void:
		var on: bool = getter.call()
		b.text = on_icon if on else off_icon
		b.modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
	b.pressed.connect(func() -> void:
		setter.call(not getter.call())
		SettingsManager.save_settings()
		refresh.call())
	refresh.call()
	parent.add_child(b)
	toggles[key] = b


func _select_tab(tab_id: String) -> void:
	current_tab = tab_id
	for id: String in tab_buttons:
		var btn: Button = tab_buttons[id]
		var accent: Color = CATEGORY_ACCENTS.get(id, UIKit.COLOR_ACCENT_3)
		if id == current_tab:
			btn.add_theme_stylebox_override("normal", UIKit.stylebox(accent, accent, 14, 2))
			btn.add_theme_stylebox_override("hover", UIKit.stylebox(accent, accent, 14, 2))
			btn.add_theme_color_override("font_color", UIKit.COLOR_BG)
		else:
			UIKit.style_button(btn, accent)
			btn.remove_theme_color_override("font_color")
	_refresh()


func _refresh() -> void:
	for child: Node in content.get_children():
		child.queue_free()
	if current_tab == "inicio":
		var data: Dictionary = _hub_data()
		var recent: Array = data.get("recent", [])
		var favs: Array = data.get("favorites", [])
		_section("▶  Seguir jugando", _games_by_ids(recent), "Todavía no has jugado nada. ¡Elige un juego en Mesa o Arcade!")
		_section("★  Favoritos", _games_by_ids(favs), "Toca la ☆ de cualquier juego para tenerlo aquí.")
		_section("✨  Nuevos", _games_by_ids(NEW_GAMES), "")
	else:
		_section("", GameManager.get_games_by_category(current_tab), "Próximamente...")


func _games_by_ids(ids: Array) -> Array:
	var out: Array = []
	for id: String in ids:
		var g: Dictionary = GameManager.get_game(id)
		if not g.is_empty() and g.get("enabled", true):
			out.append(g)
	return out


func _section(title: String, games: Array, empty_text: String) -> void:
	if title != "":
		var lbl := UIKit.title_label(title, 19, UIKit.COLOR_TEXT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		content.add_child(lbl)
	if games.is_empty():
		if empty_text != "":
			var e := UIKit.title_label(empty_text, 14, UIKit.COLOR_TEXT_DIM)
			e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(e)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)
	for g: Dictionary in games:
		grid.add_child(_build_card(g))


## Récord o progreso guardado del juego, en una línea corta.
func _record_text(id: String) -> String:
	var st: Dictionary = SaveManager.get_game_data(id)
	if st.has("best_score") and int(st["best_score"]) > 0:
		return "🏆 %d" % int(st["best_score"])
	if st.has("unlocked") and int(st["unlocked"]) > 1:
		return "Nivel %d" % int(st["unlocked"])
	if st.has("wins") and int(st["wins"]) > 0:
		return "%d victoria%s" % [int(st["wins"]), "" if int(st["wins"]) == 1 else "s"]
	return ""


func _build_card(game: Dictionary) -> Control:
	var id: String = game["id"]
	var accent: Color = CATEGORY_ACCENTS.get(game.get("category", ""), UIKit.COLOR_ACCENT)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(318, 178)
	btn.add_theme_stylebox_override("normal", UIKit.stylebox(UIKit.COLOR_PANEL, accent.darkened(0.15), 18, 2))
	btn.add_theme_stylebox_override("hover", UIKit.stylebox(UIKit.COLOR_PANEL.lightened(0.06), accent, 18, 3))
	btn.add_theme_stylebox_override("pressed", UIKit.stylebox(accent.darkened(0.55), accent, 18, 3))
	btn.add_theme_stylebox_override("focus", UIKit.stylebox(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 18, 0))
	btn.pressed.connect(func() -> void: GameManager.go_to_game(id))

	# Franja de color arriba, según la categoría.
	var stripe := ColorRect.new()
	stripe.color = Color(accent.r, accent.g, accent.b, 0.25)
	stripe.position = Vector2(2, 2)
	stripe.size = Vector2(314, 50)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stripe)

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 2)
	btn.add_child(inner)
	for spec: Array in [[game.get("icon", "🎮"), 34, UIKit.COLOR_TEXT], [game.get("title", id), 18, UIKit.COLOR_TEXT],
			[TAGLINES.get(id, ""), 12, UIKit.COLOR_TEXT_DIM], [_record_text(id), 13, UIKit.COLOR_ACCENT_3]]:
		if spec[0] == "":
			continue
		var l := UIKit.title_label(spec[0], spec[1], spec[2])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(l)

	if id in NEW_GAMES:
		var badge := Label.new()
		badge.text = " NUEVO "
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", UIKit.COLOR_BG)
		var sb := UIKit.stylebox(UIKit.COLOR_ACCENT_3, Color(0, 0, 0, 0), 8)
		badge.add_theme_stylebox_override("normal", sb)
		badge.position = Vector2(10, 10)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)

	# Estrella de favorito (botón propio dentro de la tarjeta).
	var favs: Array = _hub_data().get("favorites", [])
	var star := Button.new()
	star.text = "★" if favs.has(id) else "☆"
	star.flat = true
	star.focus_mode = Control.FOCUS_NONE
	star.add_theme_font_size_override("font_size", 26)
	star.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3 if favs.has(id) else UIKit.COLOR_TEXT_DIM)
	star.position = Vector2(264, 2)
	star.size = Vector2(50, 48)
	star.pressed.connect(func() -> void: _toggle_favorite(id))
	btn.add_child(star)
	return btn


func _toggle_favorite(id: String) -> void:
	var data: Dictionary = _hub_data()
	var favs: Array = data.get("favorites", [])
	if favs.has(id):
		favs.erase(id)
	else:
		favs.append(id)
		AudioManager.play_click()
	data["favorites"] = favs
	SaveManager.set_game_data("_hub", data)
	_refresh()
