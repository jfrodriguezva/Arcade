class_name TouchHint
extends Control
## Pantalla corta de "cómo se controla" que aparece SOLO la primera vez que
## se abre cada juego (los arcade ya no tienen botones en pantalla, así que
## los gestos hay que enseñarlos). Pausa el juego detrás y se quita con un
## toque. Lo ya visto se guarda en SaveManager ("_hub" -> "hints_seen").
##
## Uso, al final del _ready() del juego:
##   TouchHint.show_once(self, GAME_ID, [["👆", "Toca para saltar"], ...])

var steps: Array = []
var _t: float = 0.0


static func show_once(root: Control, game_id: String, gesture_steps: Array) -> void:
	var hub: Dictionary = SaveManager.get_game_data("_hub")
	var seen: Array = hub.get("hints_seen", [])
	if seen.has(game_id):
		return
	seen.append(game_id)
	hub["hints_seen"] = seen
	SaveManager.set_game_data("_hub", hub)
	var hint := TouchHint.new()
	hint.steps = gesture_steps
	root.add_child(hint)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 20, 3))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 26)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	box.add_child(UIKit.title_label("Cómo se juega", 26, UIKit.COLOR_ACCENT_3))
	for s: Array in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var icon := UIKit.title_label(s[0], 38, UIKit.COLOR_TEXT)
		icon.custom_minimum_size = Vector2(70, 0)
		icon.set_meta("pulse", true)
		row.add_child(icon)
		var txt := UIKit.title_label(s[1], 18, UIKit.COLOR_TEXT)
		txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.custom_minimum_size = Vector2(430, 0)
		row.add_child(txt)
		box.add_child(row)
	var go := UIKit.title_label("Toca la pantalla para empezar", 16, UIKit.COLOR_TEXT_DIM)
	go.name = "Go"
	box.add_child(go)


func _process(delta: float) -> void:
	_t += delta
	var go: Node = find_child("Go", true, false)
	if go:
		go.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _t > 0.4:
		accept_event()
		get_tree().paused = false
		queue_free()
