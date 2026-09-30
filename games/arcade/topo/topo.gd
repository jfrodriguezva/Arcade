extends Control
## Atrapa al Topo (whack-a-mole) — arcade clásico, generado de cero. Los
## topos salen en hoyos al azar (nunca dos seguidos en el mismo) por un
## tiempo corto; conforme avanza la ronda de 30 s salen más rápido y
## pueden aparecer varios a la vez. Hay topos dorados (+3) y bombas que
## restan si las golpeas.

const GAME_ID := "topo"
const HOLES := 9
const COLS := 3
const ROUND_SECONDS := 30
const MAX_PROGRESS := 20.0 # tope de "unidades de dificultad": más allá de esto la velocidad ya no sube
const MOLE_UP_BASE_MS := 900.0
const MOLE_UP_MIN_MS := 400.0
const MOLE_UP_PER_PROGRESS := 25.0
const PAUSE_BASE_MS := 500.0
const PAUSE_MIN_MS := 180.0
const PAUSE_PER_PROGRESS := 10.0
const WIN_SCORE := 20
const HOLE_SIZE := 96.0
const HOLE_COLOR := Color(0.243, 0.165, 0.118)
const GOLD_COLOR := Color(0.62, 0.48, 0.12)
const FIELD_COLOR := Color(0.310, 0.686, 0.318)
## Como en las máquinas de feria: topos dorados que valen más (y se
## esconden más rápido) y bombas que NO hay que golpear.
const GOLD_CHANCE := 0.10
const BOMB_CHANCE := 0.14

const HELP_TEXT := "Los topos salen de hoyos al azar. Tócalos antes de que se escondan.

- 🐹 topo normal: +1
- 🐹 en hoyo dorado: +3 (se esconde más rápido)
- 💣 bomba: ¡NO la toques! −2

Tienes 30 segundos por ronda. Conforme avanza la ronda salen más rápido y pueden aparecer varios a la vez.

Consigue 20 puntos o más para una ronda perfecta."

var holes: Array = []  # por hoyo: {"kind": "" | "mole" | "gold" | "bomb", "t": segundos restantes}
var last_hole: int = -1
var hits: int = 0
var score: int = 0
var time_left: float = 0.0
var playing: bool = false
var next_appear_timer: float = 0.0

var score_label: Label
var time_label: Label
var status_label: Label
var start_btn: Button
var hole_views: Array = []


func _ready() -> void:
	_build_ui()
	_reset_round()


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

	UIKit.build_toolbar(vbox, self, "Atrapa al Topo", HELP_TEXT)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 22)
	vbox.add_child(hud)
	score_label = UIKit.title_label("Puntos: 0", 16, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	time_label = UIKit.title_label("⏱ %d" % ROUND_SECONDS, 16, UIKit.COLOR_ACCENT)
	hud.add_child(time_label)

	status_label = UIKit.title_label("Toca «Jugar» para empezar", 14, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(FIELD_COLOR, Color(0, 0, 0, 0), 20))
	vbox.add_child(play_panel)

	var grid_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		grid_margin.add_theme_constant_override(side, 18)
	play_panel.add_child(grid_margin)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid_margin.add_child(grid)

	for i in range(HOLES):
		var hole := Button.new()
		hole.custom_minimum_size = Vector2(HOLE_SIZE, HOLE_SIZE)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			hole.add_theme_stylebox_override(state, UIKit.stylebox(HOLE_COLOR, Color(0, 0, 0, 0), int(HOLE_SIZE / 2.0)))
		hole.add_theme_font_size_override("font_size", 40)
		hole.text = ""
		var idx := i
		hole.pressed.connect(func() -> void: _whack(idx))
		grid.add_child(hole)
		hole_views.append(hole)

	start_btn = Button.new()
	start_btn.text = "▶  Jugar"
	start_btn.custom_minimum_size = Vector2(160, 50)
	UIKit.style_button(start_btn, UIKit.COLOR_ACCENT_3)
	start_btn.pressed.connect(_start_round)
	vbox.add_child(start_btn)



func _reset_round() -> void:
	score = 0
	time_left = float(ROUND_SECONDS)
	playing = false
	next_appear_timer = 0.0
	last_hole = -1
	hits = 0
	holes.clear()
	for i in range(HOLES):
		holes.append({"kind": "", "t": 0.0})
		_style_hole(i)
	_refresh_hud()


func _start_round() -> void:
	_reset_round()
	playing = true
	start_btn.text = "🔄  Reiniciar"
	status_label.text = "¡Atrápalos!"
	status_label.remove_theme_color_override("font_color")
	_schedule_next_mole()


func _progress() -> float:
	return min(float(ROUND_SECONDS) - time_left, MAX_PROGRESS)


func _schedule_next_mole() -> void:
	var pause_ms: float = max(PAUSE_BASE_MS - _progress() * PAUSE_PER_PROGRESS, PAUSE_MIN_MS)
	next_appear_timer = pause_ms / 1000.0


func _mole_up_duration() -> float:
	var up_ms: float = max(MOLE_UP_BASE_MS - _progress() * MOLE_UP_PER_PROGRESS, MOLE_UP_MIN_MS)
	return up_ms / 1000.0


## Como en el arcade, conforme avanza la ronda pueden salir varios a la vez.
func _max_up() -> int:
	return 1 + int(_progress() / 8.0)


func _process(delta: float) -> void:
	if not playing:
		return

	time_left -= delta
	if time_left <= 0.0:
		_end_round()
		return
	time_label.text = "⏱ %d" % ceili(max(time_left, 0.0))

	var up := 0
	for i in range(HOLES):
		var h: Dictionary = holes[i]
		if h["kind"] == "":
			continue
		h["t"] -= delta
		if h["t"] <= 0.0:
			_hide(i)
		else:
			up += 1

	next_appear_timer -= delta
	if next_appear_timer <= 0.0 and up < _max_up():
		_show_mole()
		_schedule_next_mole()


func _show_mole() -> void:
	var free: Array = []
	for i in range(HOLES):
		if holes[i]["kind"] == "" and i != last_hole:
			free.append(i)
	if free.is_empty():
		return
	var i: int = free[clampi(int(randf() * free.size()), 0, free.size() - 1)]
	last_hole = i
	var r: float = randf()
	var kind := "mole"
	if _progress() >= 4.0 and r < BOMB_CHANCE:
		kind = "bomb"
	elif r < BOMB_CHANCE + GOLD_CHANCE:
		kind = "gold"
	holes[i] = {"kind": kind, "t": _mole_up_duration() * (0.75 if kind == "gold" else 1.0)}
	_style_hole(i)


func _hide(i: int) -> void:
	holes[i] = {"kind": "", "t": 0.0}
	_style_hole(i)


func _style_hole(i: int) -> void:
	var hole: Button = hole_views[i]
	var kind: String = holes[i]["kind"] if i < holes.size() else ""
	hole.text = {"mole": "🐹", "gold": "🐹", "bomb": "💣"}.get(kind, "")
	var bg: Color = GOLD_COLOR if kind == "gold" else HOLE_COLOR
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		hole.add_theme_stylebox_override(st, UIKit.stylebox(bg, Color(1, 0.9, 0.4) if kind == "gold" else Color(0, 0, 0, 0), int(HOLE_SIZE / 2.0), 3 if kind == "gold" else 0))


func _whack(idx: int) -> void:
	if not playing:
		return
	var kind: String = holes[idx]["kind"]
	if kind == "":
		return
	match kind:
		"mole":
			score += 1
			hits += 1
			AudioManager.play_click()
		"gold":
			score += 3
			hits += 1
			AudioManager.play_power()
			status_label.text = "¡Topo dorado! +3"
		"bomb":
			score = maxi(score - 2, 0)
			AudioManager.play_error()
			status_label.text = "¡Era una bomba! −2"
	_flash_hole(idx, kind)
	_hide(idx)
	_refresh_hud()


## Destello del "martillazo" en el hoyo golpeado.
func _flash_hole(idx: int, kind: String) -> void:
	var hole: Button = hole_views[idx]
	hole.pivot_offset = hole.size / 2.0
	hole.scale = Vector2(0.86, 0.86)
	hole.modulate = Color(1.6, 0.6, 0.6) if kind == "bomb" else Color(1.4, 1.4, 1.0)
	var tw := hole.create_tween().set_parallel(true)
	tw.tween_property(hole, "scale", Vector2.ONE, 0.15)
	tw.tween_property(hole, "modulate", Color.WHITE, 0.2)


func _refresh_hud() -> void:
	score_label.text = "Puntos: %d" % score
	time_label.text = "⏱ %d" % ceili(max(time_left, 0.0))


func _end_round() -> void:
	playing = false
	for i in range(HOLES):
		_hide(i)
	time_left = 0.0
	time_label.text = "⏱ 0"
	start_btn.text = "▶  Jugar de nuevo"

	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)

	if score >= WIN_SCORE:
		status_label.text = "¡Ronda perfecta! Puntaje final: %d" % score
		AudioManager.play_win()
	else:
		status_label.text = "¡Tiempo! Puntaje final: %d" % score
		AudioManager.play_lose()
