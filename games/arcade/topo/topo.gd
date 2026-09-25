extends Control
## Atrapa al Topo (whack-a-mole) — arcade clásico, generado de cero. Un
## topo aparece en un hoyo al azar (nunca dos veces seguidas en el mismo)
## por un tiempo corto; tocarlo a tiempo suma un punto. Ronda de 30
## segundos con cuenta regresiva real; la velocidad de aparición sube
## conforme avanza la ronda — pura reacción y ritmo, sin física continua.

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
const WIN_SCORE := 10
const HOLE_SIZE := 96.0
const HOLE_COLOR := Color(0.243, 0.165, 0.118)
const FIELD_COLOR := Color(0.310, 0.686, 0.318)

const HELP_TEXT := "Un topo aparece en un hoyo al azar. Tócalo antes de que se esconda para sumar un punto.

Tienes 30 segundos por ronda. Entre más avanza la ronda, el topo aparece más rápido y se esconde antes — hay que estar atento.

Consigue 10 puntos o más para una ronda perfecta."

var active_hole: int = -1
var score: int = 0
var time_left: float = 0.0
var playing: bool = false
var mole_showing: bool = false
var next_appear_timer: float = 0.0
var mole_hide_timer: float = 0.0

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
	active_hole = -1
	mole_showing = false
	playing = false
	next_appear_timer = 0.0
	mole_hide_timer = 0.0
	_refresh_hud()
	for h: Button in hole_views:
		h.text = ""


func _start_round() -> void:
	_reset_round()
	playing = true
	start_btn.text = "🔄  Reiniciar"
	status_label.text = "¡Atrápalo!"
	_schedule_next_mole()


func _progress() -> float:
	return min(float(ROUND_SECONDS) - time_left, MAX_PROGRESS)


func _schedule_next_mole() -> void:
	var pause_ms: float = max(PAUSE_BASE_MS - _progress() * PAUSE_PER_PROGRESS, PAUSE_MIN_MS)
	next_appear_timer = pause_ms / 1000.0


func _mole_up_duration() -> float:
	var up_ms: float = max(MOLE_UP_BASE_MS - _progress() * MOLE_UP_PER_PROGRESS, MOLE_UP_MIN_MS)
	return up_ms / 1000.0


func _process(delta: float) -> void:
	if not playing:
		return

	time_left -= delta
	if time_left <= 0.0:
		_end_round()
		return
	time_label.text = "⏱ %d" % ceili(max(time_left, 0.0))

	if mole_showing:
		mole_hide_timer -= delta
		if mole_hide_timer <= 0.0:
			_hide_mole()
			_schedule_next_mole()
	else:
		next_appear_timer -= delta
		if next_appear_timer <= 0.0:
			_show_mole()


func _show_mole() -> void:
	active_hole = _pick_next_hole(active_hole)
	hole_views[active_hole].text = "🐹"
	mole_showing = true
	mole_hide_timer = _mole_up_duration()


func _hide_mole() -> void:
	if active_hole != -1:
		hole_views[active_hole].text = ""
	active_hole = -1
	mole_showing = false


func _whack(idx: int) -> void:
	if not playing or idx != active_hole:
		return
	score += 1
	AudioManager.play_click()
	_hide_mole()
	_schedule_next_mole()
	_refresh_hud()


func _refresh_hud() -> void:
	score_label.text = "Puntos: %d" % score
	time_label.text = "⏱ %d" % ceili(max(time_left, 0.0))


func _end_round() -> void:
	playing = false
	_hide_mole()
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


func _pick_next_hole(current: int) -> int:
	## Elige un hoyo distinto al actual sin sesgo de módulo: se multiplica
	## un azar en [0,1) por el tamaño de la lista de candidatos en vez de
	## mapear un índice fijo con `%`, que sesgaría un hoyo para que salga
	## casi el doble de veces que los demás — bug real que se encontró y
	## arregló en la versión Kotlin de este mismo juego.
	var candidates: Array = []
	for i in range(HOLES):
		if i != current:
			candidates.append(i)
	var idx: int = clampi(int(randf() * candidates.size()), 0, candidates.size() - 1)
	return candidates[idx]
