class_name GesturePad
extends Control
## Capa transparente que convierte el área de juego en el control: los
## juegos arcade ya no usan botones en pantalla, se juegan tocando,
## deslizando y arrastrando directamente sobre el juego.
##
## Se pone encima del área de juego (mismo tamaño) y emite:
##   pressed(pos)            dedo abajo
##   released(pos)           dedo arriba
##   tapped(pos)             toque corto sin moverse
##   double_tapped(pos)      dos toques seguidos
##   swiped(dir)             deslizamiento rápido (dir = Vector2i de 4 lados)
##   dragged(pos, from_start, step)  mientras se arrastra
## y deja leer `is_down`, `start_pos` y `current_pos` en cualquier momento.
##
## Solo escucha eventos de mouse: con la emulación de mouse por toque (la
## opción por defecto de Godot) un toque en el celular llega como mouse, y
## así no se procesa dos veces en la web.

signal pressed(pos: Vector2)
signal released(pos: Vector2)
signal tapped(pos: Vector2)
signal double_tapped(pos: Vector2)
signal swiped(dir: Vector2i)
signal dragged(pos: Vector2, from_start: Vector2, step: Vector2)

const TAP_MAX_MOVE := 18.0
const TAP_MAX_TIME := 0.28
const DOUBLE_TAP_TIME := 0.32
const SWIPE_MIN_DIST := 45.0
const SWIPE_MAX_TIME := 0.35

var is_down: bool = false
var start_pos: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO
var moved_far: bool = false

var _down_time: float = 0.0
var _last_tap_time: float = -10.0
var _swipe_sent: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_down = true
			moved_far = false
			_swipe_sent = false
			start_pos = event.position
			current_pos = event.position
			_down_time = _now()
			pressed.emit(event.position)
		elif is_down:
			is_down = false
			current_pos = event.position
			var dt: float = _now() - _down_time
			var delta: Vector2 = event.position - start_pos
			if not moved_far and dt <= TAP_MAX_TIME:
				if _now() - _last_tap_time <= DOUBLE_TAP_TIME:
					_last_tap_time = -10.0
					double_tapped.emit(event.position)
				else:
					_last_tap_time = _now()
					tapped.emit(event.position)
			elif not _swipe_sent and dt <= SWIPE_MAX_TIME and delta.length() >= SWIPE_MIN_DIST:
				swiped.emit(_dir_of(delta))
			released.emit(event.position)
		accept_event()
	elif event is InputEventMouseMotion and is_down:
		var step: Vector2 = event.position - current_pos
		current_pos = event.position
		var from_start: Vector2 = current_pos - start_pos
		if from_start.length() > TAP_MAX_MOVE:
			moved_far = true
		dragged.emit(current_pos, from_start, step)
		accept_event()


## Deslizar "en vivo": si el dedo ya recorrió bastante rápido, se avisa sin
## esperar a soltar (útil para girar a tiempo en Pac-Man). Una sola vez por
## toque.
func _process(_delta: float) -> void:
	if not is_down or _swipe_sent:
		return
	var delta: Vector2 = current_pos - start_pos
	if delta.length() >= SWIPE_MIN_DIST * 1.4 and _now() - _down_time <= SWIPE_MAX_TIME:
		_swipe_sent = true
		swiped.emit(_dir_of(delta))


static func _dir_of(v: Vector2) -> Vector2i:
	if absf(v.x) > absf(v.y):
		return Vector2i(1 if v.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if v.y > 0.0 else -1)


## Crea la capa encima de un área de juego. Si el área vive dentro de un
## contenedor (lo normal: un PanelContainer), la capa se agrega como hermana
## posterior: el contenedor le da exactamente el mismo rectángulo (así las
## coordenadas coinciden con las del área) y queda por encima de todo lo
## que el juego agregue después dentro del área.
static func attach(area: Control) -> GesturePad:
	var pad := GesturePad.new()
	var parent: Node = area.get_parent()
	if parent is Container:
		parent.add_child(pad)
	else:
		pad.set_anchors_preset(Control.PRESET_FULL_RECT)
		area.add_child(pad)
	return pad
