extends Control
## Estilo Qix / Gals Panic: trazas líneas desde el borde seguro hacia
## el área sin revelar para encerrar territorio; al volver al borde,
## esa zona (el lado más chico) se captura y revela la foto de abajo. Si
## una araña toca tu traza antes de cerrarla, pierdes una vida.
##
## El "arte a revelar" es una foto de naturaleza por nivel (LANDSCAPES),
## estilo fondos de pantalla de Windows. Lo "sin revelar" es otra capa (cover_mask.gdshader)
## que lee una máscara de 1 texel por celda lógica del tablero, pero
## muestreada con filtro bilineal para que el borde de revelado salga
## suave en vez de un escalón duro por celda; la lógica de juego
## (colisiones, captura, IA) sigue usando la cuadrícula GRID_W×GRID_H
## normalmente, solo cambió cómo se dibuja.

const GAME_ID := "panic_reveal"
const GRID_W := 20
const GRID_H := 27
const CELL := 34.0
## Radio alrededor del centro del marcador en el que el dedo cuenta como
## "ya llegué, detente". Antes era 12px, MENOS que media celda (17px): con
## el dedo a 13-17px del centro el marcador avanzaba una celda, quedaba ~20px
## DETRÁS del dedo y se regresaba... sobre su propia traza. Con 0.75 celda,
## tras un paso (recto 34px o diagonal 48px) el dedo siempre cae dentro del
## radio y el marcador se queda quieto en vez de rebotar.
const DRAG_DEADZONE := CELL * 0.75
const NO_CELL := Vector2i(-1, -1)
## Una foto de naturaleza por nivel (estilo fondos de Windows). Son fotos
## CC0 de Unsplash vía Wikimedia Commons, recortadas a 1080x1458 (la
## proporción del tablero); fuentes en landscapes/CREDITOS.md.
const LANDSCAPES := [
	"res://games/arcade/panic_reveal/landscapes/01_lago_montana.jpg",
	"res://games/arcade/panic_reveal/landscapes/02_playa_turquesa.jpg",
	"res://games/arcade/panic_reveal/landscapes/03_cascada.jpg",
	"res://games/arcade/panic_reveal/landscapes/04_bryce_canyon.jpg",
	"res://games/arcade/panic_reveal/landscapes/05_bosque_otono.jpg",
	"res://games/arcade/panic_reveal/landscapes/06_playa_nagtabon.jpg",
	"res://games/arcade/panic_reveal/landscapes/07_lago_nubes.jpg",
	"res://games/arcade/panic_reveal/landscapes/08_antelope_canyon.jpg",
	"res://games/arcade/panic_reveal/landscapes/09_aurora_lofoten.jpg",
	"res://games/arcade/panic_reveal/landscapes/10_aurora_colores.jpg",
]
## Probabilidad por paso de que una araña cambie de rumbo sin haber chocado
## (para que no vayan en línea recta de pared a pared), y de que el jefe
## gire hacia tu marcador mientras estás trazando.
const ENEMY_TURN_CHANCE := 0.12
const BOSS_CHASE_CHANCE := 0.30
const SPIDER_COLOR := Color(0.95, 0.42, 0.18)
const SPIDER_COLOR2 := Color(1.0, 0.92, 0.35)
const KILL_SCORE := 30
const BOSS_KILL_SCORE := 500
const CLEAR_BONUS_SCORE := 1000  # por eliminar a todas las arañas del nivel
const MOVE_INTERVAL := 0.09
const CAPTURE_TARGET := 80.0  # el arcade original pide 80%, no 75%
const MAX_LEVEL := 10
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DRONE_SPIN_IDLE := 0.7   # vueltas/seg cuando el marcador está en zona segura
const DRONE_SPIN_TRACE := 2.6  # vueltas/seg cuando está trazando una línea activa
const ENEMY_FLAP_SPEED := 1.5  # vueltas/seg del ciclo de animación del alien
const LEVEL_TIME_BASE := 75.0
const LEVEL_TIME_MIN := 42.0
const SPARX_MIN_LEVEL := 3
const SPARX_SPEED := 6.0  # celdas de borde por segundo
# --- Barra "chica/monstruo" (la mecánica que le da nombre al juego: Panic) -
# Revelar la silueta ("sujeto") empuja la barra hacia monstruo; revelar
# fondo la regresa hacia chica; y se va hacia monstruo sola con el tiempo.
# Si llegas a la meta de captura con la barra del lado monstruo, el arcade
# original NO da el nivel por completado -- hay que seguir revelando fondo
# hasta recuperarla.
const PANIC_START := 0.7
# El drift original de 0.012/seg bajaba la barra de PANIC_START al umbral
# en ~32s aunque el jugador no tocara la silueta ni una vez -- demasiado
# castigo para un nivel de 42-75s. A 0.006/seg tarda ~63s en cruzar sola,
# presión real hacia el final del nivel sin sentirse injusta desde el inicio.
const PANIC_DRIFT_PER_SEC := 0.006
const PANIC_SUBJECT_PENALTY := 0.016  # por celda de silueta revelada
const PANIC_BACKGROUND_BONUS := 0.015  # por celda de fondo revelado
const PANIC_MONSTER_THRESHOLD := 0.32
const DIAGONAL_FACTOR := 1.41421356  # sqrt(2): un paso diagonal recorre más distancia real,
	# así que tarda lo mismo por segundo (no "más rápido") que uno recto, igual que en el
	# arcade original donde el marcador se mueve a velocidad constante en cualquier dirección.
## La araña jefa crece, se oscurece y acelera con el tiempo del nivel. El
## tamaño visual se queda por debajo de ~1.2 celdas: la colisión es por
## celda, y un sprite mucho más grande que su celda "toca" tu traza a la
## vista sin matarte (o parece matarte de lejos).
const MONSTER_STAGES := [
	{"shape": "spider", "color": Color(0.62, 0.28, 0.85), "color2": Color(1.0, 0.35, 0.35), "scale": 1.0, "speed_mult": 1.0},
	{"shape": "spider", "color": Color(0.80, 0.16, 0.30), "color2": Color(1.0, 0.75, 0.2), "scale": 1.1, "speed_mult": 1.3},
	{"shape": "spider", "color": Color(0.30, 0.04, 0.10), "color2": Color(1.0, 0.15, 0.15), "scale": 1.2, "speed_mult": 1.65},
]

const HELP_TEXT := "Toca y arrastra en cualquier parte del tablero: el marcador se mueve hacia donde esté tu dedo, en las 8 direcciones, igual que con el joystick del arcade original — todo el display es el control, no hay botones aparte.

- Mientras estés en el borde o en zona ya capturada, estás a salvo de las arañas. Desde el nivel 3 patrullan el borde exterior unos centinelas violeta (Sparx): si te tocan, aunque estés en zona 'segura', pierdes una vida igual.
- Al entrar a la zona sin revelar, vas dejando una traza. Si una araña toca tu traza antes de que regreses al borde, pierdes una vida y la traza se borra. Tu propia traza no te mata: el marcador simplemente no puede pasar sobre ella.
- Al cerrar la traza se captura siempre el lado MÁS CHICO; el lado más grande queda abierto. Toda araña que quede en la parte capturada muere — incluida la araña jefa (morada, crece y acelera con el tiempo): enciérrala en un rincón y vale muchos puntos.
- El área encerrada se revela como si se corriera una cortina. Entre más grande el área capturada de una vez, más puntos.
- Arriba hay una barra chica/monstruo: revelar la silueta la empuja hacia monstruo, revelar el fondo (todo lo que no es la silueta) la regresa, y se va sola hacia monstruo con el tiempo. Si llegas al 80% con la barra del lado monstruo, el nivel NO se completa todavía — sigue revelando fondo hasta recuperarla.
- Cada nivel esconde una ☄️ tormenta de asteroides bajo alguna celda de fondo. Al revelarla, destruye a todas las arañas chicas en pantalla (la jefa es inmune).
- Si eliminas a TODAS las arañas (incluida la jefa), el paisaje completo se revela solo y pasas de nivel, sin importar el % ni la barra chica/monstruo. +1000 puntos.
- Cada nivel es una foto de naturaleza distinta: lagos de montaña, playas turquesa, cascada, cañones y auroras boreales.
- Hay un límite de tiempo por nivel (arriba a la derecha). Si se agota, pierdes una vida y se reinicia el reloj.

Captura el 80% del área (con la barra del lado chica) para pasar de nivel. Hay 10 niveles, cada uno con más enemigos, más rápidos y menos tiempo. Pierdes si se acaban tus 3 vidas."

var grid_state: Array = []
## landscape_bg muestra la foto del nivel (con el tinte de "modo monstruo"
## y un poco más de saturación, ver panic_tint.gdshader), y
## cover_layer pinta el "opaco" encima usando mask_image/mask_texture (un
## texel por celda lógica, muestreado con filtro bilineal + smoothstep en
## el shader para que el borde de revelado se vea suave, no en escalones).
var landscape_bg: TextureRect
var cover_layer: ColorRect
var mask_image: Image
var mask_texture: ImageTexture
## "Sujeto" = la silueta central (cabeza+cuerpo, como la chica del original)
## cuyas celdas cuentan distinto que el fondo para la barra chica/monstruo
## (ver _build_subject_mask). Se dibuja como un tinte sutil sobre lo que
## sigue sin revelar en esa zona, para que se pueda planear la ruta.
var subject_mask: Dictionary = {}
var subject_image: Image
var subject_texture: ImageTexture
## 1.0 = totalmente del lado "chica" (seguro), 0.0 = totalmente "monstruo".
## Ver PANIC_* arriba y _update_panic_gauge/_update_panic_visual.
var panic_gauge: float = PANIC_START
var panic_in_monster: bool = false
## Ítem "tormenta de asteroides": una celda de fondo al azar por nivel que,
## al revelarse, destruye a todos los enemigos chicos en pantalla (el jefe
## es inmune). bonus_icon_view aparece un instante ahí para avisar.
var bonus_cell: Vector2i = Vector2i(-1, -1)
var bonus_triggered: bool = false
var bonus_icon_view: Label

var player_cell: Vector2i = Vector2i.ZERO
var current_dir: Vector2i = Vector2i.ZERO
## Control tipo joystick sobre todo el tablero: mientras el dedo está
## abajo, la dirección es la del vector desde el marcador hacia el
## punto tocado, redondeada a una de 8 direcciones — no hay botones de
## flechas aparte, el display completo es el control.
var dragging: bool = false
## Última posición conocida del dedo/mouse mientras se arrastra. La
## dirección ya no se recalcula solo cuando llega un evento de input
## (ScreenDrag/MouseMotion) -- se recalcula cada frame en _process a
## partir de este punto, porque player_cell (la referencia) también
## avanza cada tick sin generar un evento de input nuevo. Si el dedo se
## queda quieto justo cuando el marcador lo alcanza o lo rebasa, la
## dirección leída con el último evento viejo podía apuntar de vuelta
## hacia la celda recién trazada -- eso era lo que a veces cortaba el
## trazo con una muerte que no tenía que ver con ningún enemigo.
var last_pointer_pos: Vector2 = Vector2.ZERO
var move_timer: float = 0.0
## El marcador (y los enemigos) ya no "saltan" de celda en celda: cada
## paso se interpola suavemente entre la posición anterior y la nueva a
## lo largo del mismo tick, para que el recorrido se sienta continuo en
## vez de cuadriculado. La lógica de colisión/captura sigue siendo por
## celda (grid_state), solo cambia cómo se dibuja el movimiento.
var player_prev_pos: Vector2 = Vector2.ZERO
var player_target_pos: Vector2 = Vector2.ZERO
var trail: Array = []
var trail_origin: Vector2i = Vector2i.ZERO
var trail_line: Line2D
var drone_phase: float = 0.0
## Tween de la "cortina" de revelado (_reveal_new_cells). Si al cerrar el
## área que completa el nivel se lanza _setup_level() mientras esta tween
## sigue viva, sigue pintando celdas del nivel VIEJO sobre mask_image/
## mask_texture (el mismo objeto, reusado entre niveles) después de que ya
## se reseteó para el nivel nuevo -- eso es lo que hacía que el nivel
## siguiente apareciera con parches ya revelados y la transición se viera
## congelada a medias. _complete_capture ahora espera a que termine antes
## de avanzar de nivel.
var reveal_tween: Tween = null
## Celdas que reveal_tween está animando ahora mismo. Si _reveal_new_cells
## se llama otra vez antes de que termine (p.ej. la captura principal y,
## en el mismo cierre, el bonus por matar a un qix arrinconado), estas
## celdas se fijan a "revelado" de inmediato en vez de dejarlas a medias --
## el mismo tipo de residuo que ya causó el bug del nivel "precompletado".
var reveal_cells: Array = []
## Se incrementa cada vez que arranca una partida nueva. _complete_capture
## lo captura antes de esperar la pausa de "nivel completo"; si cambió al
## despertar (el jugador le dio a "Nueva partida" en medio de la espera),
## esa espera quedó obsoleta y no debe pisar la partida que ya arrancó.
var game_session: int = 0

var enemies: Array = []
var perimeter_cells: Array = []
var time_left: float = LEVEL_TIME_BASE

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var player_view: EntitySprite
var score_label: Label
var lives_label: Label
var status_label: Label
var percent_label: Label
var percent_bar: ProgressBar
var panic_bar: ProgressBar
var panic_icon_label: Label
var time_label: Label


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
		margin.add_theme_constant_override(side, 12)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Revela el Paisaje", HELP_TEXT)

	# --- HUD compacto: una sola franja delgada con nivel/puntos/vidas y una
	# barra de progreso de captura (en vez de tres filas de texto separadas).
	var hud_panel := PanelContainer.new()
	hud_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 10, 1))
	vbox.add_child(hud_panel)

	var hud_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		hud_margin.add_theme_constant_override(side, 8)
	hud_panel.add_child(hud_margin)

	var hud_vbox := VBoxContainer.new()
	hud_vbox.add_theme_constant_override("separation", 4)
	hud_margin.add_child(hud_vbox)

	var hud_row := HBoxContainer.new()
	hud_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_row.add_theme_constant_override("separation", 20)
	hud_vbox.add_child(hud_row)
	status_label = UIKit.title_label("Nivel 1/%d" % MAX_LEVEL, 13, UIKit.COLOR_TEXT_DIM)
	hud_row.add_child(status_label)
	score_label = UIKit.title_label("★ 0", 13, UIKit.COLOR_TEXT)
	hud_row.add_child(score_label)
	lives_label = UIKit.title_label("♥ 3", 13, UIKit.COLOR_ACCENT)
	hud_row.add_child(lives_label)
	time_label = UIKit.title_label("⏱ 75", 13, UIKit.COLOR_ACCENT_2)
	hud_row.add_child(time_label)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	hud_vbox.add_child(progress_row)
	percent_bar = ProgressBar.new()
	percent_bar.custom_minimum_size = Vector2(0, 14)
	percent_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	percent_bar.max_value = CAPTURE_TARGET
	percent_bar.show_percentage = false
	percent_bar.add_theme_stylebox_override("background", UIKit.stylebox(UIKit.COLOR_BG, Color(0, 0, 0, 0), 6))
	percent_bar.add_theme_stylebox_override("fill", UIKit.stylebox(UIKit.COLOR_ACCENT_2, Color(0, 0, 0, 0), 6))
	progress_row.add_child(percent_bar)
	percent_label = UIKit.title_label("0%% / %d%%" % int(CAPTURE_TARGET), 12, UIKit.COLOR_ACCENT_2)
	progress_row.add_child(percent_label)

	# Barra chica/monstruo (la mecánica "Panic" del original): revelar la
	# silueta la empuja hacia monstruo, revelar fondo la regresa.
	var panic_row := HBoxContainer.new()
	panic_row.add_theme_constant_override("separation", 8)
	hud_vbox.add_child(panic_row)
	panic_icon_label = UIKit.title_label("😊", 14, UIKit.COLOR_TEXT)
	panic_row.add_child(panic_icon_label)
	panic_bar = ProgressBar.new()
	panic_bar.custom_minimum_size = Vector2(0, 10)
	panic_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panic_bar.max_value = 100.0
	panic_bar.show_percentage = false
	panic_bar.add_theme_stylebox_override("background", UIKit.stylebox(UIKit.COLOR_BG, Color(0, 0, 0, 0), 6))
	panic_bar.add_theme_stylebox_override("fill", UIKit.stylebox(UIKit.COLOR_ACCENT_2, Color(0, 0, 0, 0), 6))
	panic_row.add_child(panic_bar)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 10, 2))
	vbox.add_child(play_panel)

	# El tablero completo ES el control: se toca y arrastra directamente
	# sobre él para mover el marcador (ver _on_play_area_input), como el
	# joystick del arcade original — por eso ya no hay un d-pad aparte
	# quitándole espacio a la pantalla.
	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(GRID_W * CELL, GRID_H * CELL)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_STOP
	play_area.gui_input.connect(_on_play_area_input)
	play_panel.add_child(play_area)

	var board_size := Vector2(GRID_W * CELL, GRID_H * CELL)

	# Foto del nivel (ver LANDSCAPES), ya recortada a la proporción del
	# tablero; STRETCH_KEEP_ASPECT_COVERED por si acaso nunca se deforma.
	landscape_bg = TextureRect.new()
	landscape_bg.size = board_size
	landscape_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	landscape_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	landscape_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	landscape_bg.material = ShaderMaterial.new()
	landscape_bg.material.shader = load("res://games/arcade/panic_reveal/panic_tint.gdshader")
	play_area.add_child(landscape_bg)

	mask_image = Image.create(GRID_W, GRID_H, false, Image.FORMAT_R8)
	mask_texture = ImageTexture.create_from_image(mask_image)
	subject_image = Image.create(GRID_W, GRID_H, false, Image.FORMAT_R8)
	subject_texture = ImageTexture.create_from_image(subject_image)

	cover_layer = ColorRect.new()
	cover_layer.size = board_size
	cover_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_layer.material = ShaderMaterial.new()
	cover_layer.material.shader = load("res://games/arcade/panic_reveal/cover_mask.gdshader")
	cover_layer.material.set_shader_parameter("mask_tex", mask_texture)
	cover_layer.material.set_shader_parameter("subject_tex", subject_texture)
	play_area.add_child(cover_layer)

	# Ítem bonus "tormenta de asteroides" del original: oculto bajo una
	# celda de fondo al azar cada nivel, aparece un instante al revelarse y
	# destruye a todos los enemigos chicos en pantalla (el jefe es inmune,
	# igual que a la captura).
	bonus_icon_view = UIKit.title_label("☄️", 20, UIKit.COLOR_TEXT)
	bonus_icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bonus_icon_view.custom_minimum_size = Vector2(CELL, CELL)
	bonus_icon_view.size = Vector2(CELL, CELL)
	bonus_icon_view.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_icon_view.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bonus_icon_view.modulate.a = 0.0
	play_area.add_child(bonus_icon_view)

	# La traza activa ya no se pinta celda por celda (eso es lo que se veía
	# "cuadriculado"): es una sola línea suave tipo trazo de pluma, que
	# sigue la posición interpolada del marcador en vez de saltar de
	# centro-de-celda en centro-de-celda.
	trail_line = Line2D.new()
	trail_line.width = CELL * 0.22
	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.antialiased = true
	var trail_gradient := Gradient.new()
	trail_gradient.set_color(0, Color(UIKit.COLOR_ACCENT_3.r, UIKit.COLOR_ACCENT_3.g, UIKit.COLOR_ACCENT_3.b, 0.65))
	trail_gradient.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
	trail_line.gradient = trail_gradient
	play_area.add_child(trail_line)

	player_view = EntitySprite.new()
	player_view.size = Vector2(CELL * 0.9, CELL * 0.9)
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.setup("cursor_drone", UIKit.COLOR_TEXT, UIKit.COLOR_ACCENT_2)
	play_area.add_child(player_view)

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 40)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


const OCTANTS := [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]
const OCTANT_STEP := PI / 4.0
## Con histéresis 0 (la frontera exacta a 22.5°), un ángulo de dedo real
## que tiembla justo ahí hace que la dirección lea PARA UN LADO Y PARA EL
## OTRO frame a frame -- eso era lo que a veces "fallaba" el trazo: el
## marcador daba un paso, luego el ruido lo mandaba a la celda de la que
## venía (que ya es "trail"), y eso cuenta como tocar tu propia traza.
## Con histéresis, una vez que ya vas en una dirección hace falta un
## ángulo más lejos de ella (no solo cruzar la frontera de 22.5°) para
## soltarla -- el trazo ya no tiembla por puro ruido del touch/mouse.
const OCTANT_HYSTERESIS := 0.15  # fracción extra de OCTANT_STEP que hay que rebasar para cambiar de octante

func _direction_from_vector(v: Vector2, current: Vector2i = Vector2i.ZERO) -> Vector2i:
	if v.length() < DRAG_DEADZONE:
		return Vector2i.ZERO
	var raw_angle: float = v.angle()
	if current != Vector2i.ZERO:
		var current_idx: int = OCTANTS.find(current)
		if current_idx != -1:
			var diff: float = wrapf(raw_angle - current_idx * OCTANT_STEP, -PI, PI)
			if abs(diff) < OCTANT_STEP * (0.5 + OCTANT_HYSTERESIS):
				return current
	var octant: int = int(round(raw_angle / OCTANT_STEP))
	octant = ((octant % 8) + 8) % 8
	return OCTANTS[octant]


func _on_play_area_input(event: InputEvent) -> void:
	if state != "playing":
		return

	var pos: Vector2
	var active: bool

	if event is InputEventScreenTouch:
		dragging = event.pressed
		active = dragging
		pos = event.position
	elif event is InputEventScreenDrag:
		active = dragging
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		active = dragging
		pos = event.position
	elif event is InputEventMouseMotion:
		active = dragging
		pos = event.position
	else:
		return

	if not active:
		current_dir = Vector2i.ZERO
		return

	# Solo se guarda dónde está el dedo/mouse; la dirección se recalcula
	# cada frame en _process (ver _update_direction_from_pointer), no aquí.
	# Antes se calculaba solo cuando llegaba un evento de input nuevo, pero
	# player_cell avanza cada tick de movimiento SIN generar un evento --
	# si el dedo se quedaba quieto justo cuando el marcador lo alcanzaba o
	# lo rebasaba, la dirección se quedaba con el último valor leído (a
	# veces apuntando de vuelta hacia la celda recién trazada) y el trazo
	# se cortaba con una muerte que no tenía que ver con ningún enemigo.
	last_pointer_pos = pos


func _new_game() -> void:
	game_session += 1
	score = 0
	lives = 3
	level = 1
	state = "playing"
	_setup_level()


func _setup_level() -> void:
	grid_state = []
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			var is_border: bool = x == 0 or y == 0 or x == GRID_W - 1 or y == GRID_H - 1
			row.append("captured" if is_border else "open")
		grid_state.append(row)
	landscape_bg.texture = load(LANDSCAPES[(level - 1) % LANDSCAPES.size()])
	_rebuild_mask()
	_build_subject_mask()
	panic_gauge = PANIC_START
	panic_in_monster = false
	status_label.remove_theme_color_override("font_color")
	_update_panic_visual()
	_pick_bonus_cell()

	player_cell = Vector2i(0, 0)
	current_dir = Vector2i.ZERO
	dragging = false
	move_timer = 0.0
	player_prev_pos = Vector2.ZERO
	player_target_pos = Vector2.ZERO
	player_view.position = _view_pos(Vector2.ZERO, player_view)
	trail.clear()
	trail_line.points = PackedVector2Array()
	_build_perimeter()
	time_left = _level_time_limit()

	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()
	# Arañas: la primera es la jefa (morada, crece con el tiempo), las demás
	# son arañas chicas naranjas. Nacen lejos de la esquina de salida del
	# jugador para que el arranque del nivel no sea una muerte regalada.
	var enemy_count: int = min(1 + level / 2, 6)
	var enemy_interval: float = max(0.10, 0.30 - level * 0.018)
	for i in range(enemy_count):
		var pos := Vector2i(1 + randi() % (GRID_W - 2), 1 + randi() % (GRID_H - 2))
		while pos.x + pos.y < 8:
			pos = Vector2i(1 + randi() % (GRID_W - 2), 1 + randi() % (GRID_H - 2))
		var view := EntitySprite.new()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.size = Vector2(CELL * 0.92, CELL * 0.92)
		view.pivot_offset = view.size / 2.0
		view.setup("spider", SPIDER_COLOR, SPIDER_COLOR2, i)
		play_area.add_child(view)
		var start_dir: Vector2i = OCTANTS[randi() % OCTANTS.size()]
		view.set_facing(_dir_to_deg(start_dir))
		var pix: Vector2 = Vector2(pos) * CELL
		view.position = _view_pos(pix, view)
		var e := {
			"kind": "qix", "pos": pos, "dir": start_dir, "view": view,
			"interval": enemy_interval, "timer": 0.0, "phase": randf(),
			"prev_pixel": pix, "target_pixel": pix,
			# Solo la primera araña del nivel se vuelve monstruo con el
			# tiempo — que todas escalen a la vez sería demasiado, y en el
			# arcade original es un único enemigo el que se transforma.
			"is_lead": i == 0, "monster_stage": 0, "base_interval": enemy_interval,
		}
		if i == 0:
			_evolve_monster(e, 0)
		enemies.append(e)

	# Sparx: centinelas que patrullan el borde exterior desde el nivel 3 —
	# son peligrosos aunque el jugador esté en zona "segura", igual que en
	# el arcade original (donde la orilla no siempre es garantía de vida).
	var sparx_count: int = 0
	if level >= SPARX_MIN_LEVEL:
		sparx_count = 1 + (level - SPARX_MIN_LEVEL) / 3
	sparx_count = min(sparx_count, 3)
	for i in range(sparx_count):
		# Se reparten por el borde empezando lejos de (0,0), que es donde
		# arranca el jugador — spawnear un Sparx justo ahí sería una
		# pérdida de vida instantánea e injusta al iniciar el nivel.
		var spacing: int = perimeter_cells.size() / max(sparx_count, 1)
		var s0: int = posmod(perimeter_cells.size() / 3 + spacing * i, perimeter_cells.size())
		var pos: Vector2i = perimeter_cells[s0]
		var view := EntitySprite.new()
		view.size = Vector2(CELL * 0.78, CELL * 0.78)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.setup("sentry", Color(0.678, 0.478, 0.925), UIKit.COLOR_TEXT, i)
		play_area.add_child(view)
		var spix: Vector2 = Vector2(pos) * CELL
		view.position = _view_pos(spix, view)
		enemies.append({
			"kind": "sparx", "s": s0, "step": 1 if i % 2 == 0 else -1,
			"pos": pos, "view": view, "interval": 1.0 / SPARX_SPEED, "timer": 0.0, "phase": randf(),
			"prev_pixel": spix, "target_pixel": spix,
		})

	status_label.text = "Nivel %d/%d" % [level, MAX_LEVEL]
	_update_hud()


func _level_time_limit() -> float:
	return max(LEVEL_TIME_MIN, LEVEL_TIME_BASE - (level - 1) * 3.5)


func _update_monster_evolution() -> void:
	## Uno de los enemigos se pone más grande, rojo y rápido mientras más
	## tiempo pase en el nivel, como el temporizador que "convierte a
	## monstruo" del arcade original — presión extra por no tardarse.
	var limit: float = _level_time_limit()
	if limit <= 0.0:
		return
	var elapsed_ratio: float = 1.0 - clamp(time_left / limit, 0.0, 1.0)
	var stage := 0
	if elapsed_ratio >= 0.75:
		stage = 2
	elif elapsed_ratio >= 0.4:
		stage = 1
	for e: Dictionary in enemies:
		if e.get("is_lead", false) and e["monster_stage"] != stage:
			_evolve_monster(e, stage)


func _evolve_monster(e: Dictionary, stage: int) -> void:
	e["monster_stage"] = stage
	var s: Dictionary = MONSTER_STAGES[stage]
	var sz: float = CELL * 1.0 * float(s["scale"])
	var view: EntitySprite = e["view"]
	view.size = Vector2(sz, sz)
	view.pivot_offset = view.size / 2.0
	view.setup(s["shape"], s["color"], s["color2"], view.seed_i)
	e["interval"] = float(e["base_interval"]) / float(s["speed_mult"])


## Posición (esquina superior izquierda) de un sprite para que quede
## CENTRADO en la celda cuya esquina es `cell_pixel`. Antes los sprites se
## anclaban a la esquina de la celda, así que los más grandes que la celda
## (la jefa) se salían hacia abajo/derecha y los choques se veían corridos.
func _view_pos(cell_pixel: Vector2, view: Control) -> Vector2:
	return cell_pixel + (Vector2(CELL, CELL) - view.size) / 2.0


func _build_perimeter() -> void:
	## Recorre el anillo exterior del grid en orden, para que los Sparx
	## puedan patrullarlo incrementando/decrementando un solo índice.
	perimeter_cells.clear()
	for x in range(GRID_W):
		perimeter_cells.append(Vector2i(x, 0))
	for y in range(1, GRID_H):
		perimeter_cells.append(Vector2i(GRID_W - 1, y))
	for x in range(GRID_W - 2, -1, -1):
		perimeter_cells.append(Vector2i(x, GRID_H - 1))
	for y in range(GRID_H - 2, 0, -1):
		perimeter_cells.append(Vector2i(0, y))


func _update_hud() -> void:
	score_label.text = "★ %d" % score
	lives_label.text = "♥ %d" % lives
	time_label.text = "⏱ %d" % ceili(max(time_left, 0.0))
	var pct: float = _capture_percent()
	percent_bar.value = pct
	percent_label.text = "%.0f%% / %d%%" % [pct, int(CAPTURE_TARGET)]


func _capture_percent() -> float:
	var captured := 0
	for y in range(GRID_H):
		for x in range(GRID_W):
			if grid_state[y][x] == "captured":
				captured += 1
	return float(captured) / float(GRID_W * GRID_H) * 100.0


func _build_subject_mask() -> void:
	## Silueta central (cabeza + cuerpo) que hace de "sujeto" para la barra
	## chica/monstruo -- el original usa la foto de la chica, acá usamos una
	## forma simple ya que el arte es un paisaje sin persona. Misma forma cada
	## nivel, centrada, para que el jugador aprenda a ubicarla.
	subject_mask.clear()
	var cx: float = GRID_W / 2.0
	var head_cy: float = GRID_H * 0.28
	var head_r: float = GRID_W * 0.115
	var body_cy: float = GRID_H * 0.58
	var body_rx: float = GRID_W * 0.155
	var body_ry: float = GRID_H * 0.225
	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			var dx: float = x - cx
			var head_dy: float = y - head_cy
			var in_head: bool = dx * dx + head_dy * head_dy <= head_r * head_r
			var body_dy: float = y - body_cy
			var in_body: bool = (dx * dx) / (body_rx * body_rx) + (body_dy * body_dy) / (body_ry * body_ry) <= 1.0
			if in_head or in_body:
				subject_mask[Vector2i(x, y)] = true
	for y in range(GRID_H):
		for x in range(GRID_W):
			var v: float = 1.0 if subject_mask.has(Vector2i(x, y)) else 0.0
			subject_image.set_pixel(x, y, Color(v, v, v))
	subject_texture.update(subject_image)


func _pick_bonus_cell() -> void:
	## Elige una celda de fondo (fuera de la silueta) al azar para esconder
	## ahí la "tormenta de asteroides" de este nivel.
	bonus_triggered = false
	bonus_icon_view.modulate.a = 0.0
	var candidates: Array = []
	for y in range(1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			var c := Vector2i(x, y)
			if not subject_mask.has(c):
				candidates.append(c)
	bonus_cell = candidates[randi() % candidates.size()]
	bonus_icon_view.position = Vector2(bonus_cell) * CELL + Vector2(CELL, CELL) / 2.0 - bonus_icon_view.size / 2.0


func _trigger_asteroid_storm() -> void:
	## Ítem bonus del original: destruye a todos los enemigos chicos en
	## pantalla de un jalón (el jefe es inmune, igual que a la captura).
	bonus_triggered = true
	var tw := create_tween()
	tw.tween_property(bonus_icon_view, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.5)
	tw.tween_property(bonus_icon_view, "modulate:a", 0.0, 0.4)

	for e: Dictionary in enemies.duplicate():
		if e["kind"] != "qix" or e.get("is_lead", false):
			continue
		_kill_enemy(e)
		score += 40
	_update_hud()
	AudioManager.play_power()


func _update_panic_gauge(cells: Array) -> void:
	## Revelar silueta empuja la barra a "monstruo"; revelar fondo la regresa
	## a "chica" -- la tensión central del arcade original (de ahí "Panic").
	for c: Vector2i in cells:
		if subject_mask.has(c):
			panic_gauge -= PANIC_SUBJECT_PENALTY
		else:
			panic_gauge += PANIC_BACKGROUND_BONUS
	panic_gauge = clamp(panic_gauge, 0.0, 1.0)
	_update_panic_visual()


func _update_panic_visual() -> void:
	panic_bar.value = panic_gauge * 100.0
	var now_in_monster: bool = panic_gauge < PANIC_MONSTER_THRESHOLD
	var intensity: float = 0.0
	if now_in_monster:
		intensity = clamp((PANIC_MONSTER_THRESHOLD - panic_gauge) / PANIC_MONSTER_THRESHOLD, 0.0, 1.0)
	landscape_bg.material.set_shader_parameter("panic", intensity)
	if now_in_monster != panic_in_monster:
		panic_in_monster = now_in_monster
		panic_bar.add_theme_stylebox_override("fill", UIKit.stylebox(UIKit.COLOR_DANGER if panic_in_monster else UIKit.COLOR_ACCENT_2, Color(0, 0, 0, 0), 6))
		panic_icon_label.text = "👹" if panic_in_monster else "😊"
		if panic_in_monster:
			AudioManager.play_alert()
		else:
			AudioManager.play_click()


func _update_direction_from_pointer() -> void:
	if not dragging:
		return
	var player_center: Vector2 = Vector2(player_cell) * CELL + Vector2(CELL, CELL) / 2.0
	current_dir = _direction_from_vector(last_pointer_pos - player_center, current_dir)
	if current_dir != Vector2i.ZERO:
		player_view.set_facing(rad_to_deg(atan2(current_dir.x, -current_dir.y)))


func _process(delta: float) -> void:
	if state != "playing":
		return

	_update_direction_from_pointer()
	panic_gauge = clamp(panic_gauge - PANIC_DRIFT_PER_SEC * delta, 0.0, 1.0)
	_update_panic_visual()
	time_left -= delta
	time_label.text = "⏱ %d" % ceili(max(time_left, 0.0))
	if time_left <= 0.0:
		_time_out()
		return

	_update_monster_evolution()

	move_timer += delta
	var tick_interval: float = MOVE_INTERVAL * (DIAGONAL_FACTOR if (current_dir.x != 0 and current_dir.y != 0) else 1.0)
	if move_timer >= tick_interval:
		move_timer = 0.0
		player_prev_pos = Vector2(player_cell) * CELL
		if current_dir != Vector2i.ZERO:
			_try_move_player()
		player_target_pos = Vector2(player_cell) * CELL
	if state == "playing":
		var pt: float = clamp(move_timer / tick_interval, 0.0, 1.0)
		player_view.position = _view_pos(player_prev_pos.lerp(player_target_pos, pt), player_view)

	# El marcador gira más rápido mientras traza una línea activa (peligro),
	# y despacio cuando está a salvo en el borde o en zona ya capturada.
	var spin: float = DRONE_SPIN_TRACE if not trail.is_empty() else DRONE_SPIN_IDLE
	drone_phase = fposmod(drone_phase + delta * spin, 1.0)
	player_view.set_phase(drone_phase)
	_update_trail_line()

	for e: Dictionary in enemies:
		e["timer"] += delta
		if e["timer"] >= e["interval"]:
			e["timer"] = 0.0
			e["prev_pixel"] = Vector2(e["pos"]) * CELL
			if e["kind"] == "sparx":
				_move_sparx(e)
			else:
				_move_enemy(e)
			e["target_pixel"] = Vector2(e["pos"]) * CELL
		var et: float = clamp(e["timer"] / e["interval"], 0.0, 1.0)
		e["view"].position = _view_pos(e["prev_pixel"].lerp(e["target_pixel"], et), e["view"])
		e["phase"] = fposmod(e["phase"] + delta * ENEMY_FLAP_SPEED, 1.0)
		e["view"].set_phase(e["phase"])

	_check_enemy_collisions()


## 0 = arriba, 90 = derecha... también para las 4 diagonales.
func _dir_to_deg(d: Vector2i) -> float:
	if d == Vector2i.ZERO:
		return 0.0
	return rad_to_deg(atan2(float(d.x), float(-d.y)))


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < GRID_W and c.y >= 0 and c.y < GRID_H


func _cell_is(c: Vector2i, what: String) -> bool:
	return _in_grid(c) and grid_state[c.y][c.x] == what


func _try_move_player() -> void:
	var next: Vector2i = player_cell + current_dir
	if not _in_grid(next):
		return

	var next_state: String = grid_state[next.y][next.x]

	# Tu propia traza es una pared, no una muerte: como en el original, el
	# marcador simplemente no puede regresarse sobre su línea. Antes esto
	# costaba una vida, y era justo lo que "fallaba" al trazar: el dedo
	# temblaba o el marcador rebasaba al dedo, el siguiente paso apuntaba a
	# la celda de la que venías y morías sin que ninguna araña te tocara.
	if next_state == "trail":
		return
	# Tampoco se vale cruzar tu traza en diagonal "por la esquina" (pasar
	# entre dos celdas de traza que se tocan en diagonal): partiría el trazo
	# en dos y la captura saldría rara.
	if current_dir.x != 0 and current_dir.y != 0:
		if _cell_is(player_cell + Vector2i(current_dir.x, 0), "trail") and _cell_is(player_cell + Vector2i(0, current_dir.y), "trail"):
			return

	if next_state == "captured":
		player_cell = next
		if not trail.is_empty():
			_complete_capture()
		return

	for e: Dictionary in enemies:
		if e["kind"] == "qix" and e["pos"] == next:
			_lose_life()
			return

	if trail.is_empty():
		trail_origin = player_cell
	grid_state[next.y][next.x] = "trail"
	trail.append(next)
	player_cell = next


func _complete_capture() -> void:
	# Regla de captura: al cerrar, la traza parte lo abierto en regiones; se
	# queda abierta SOLO la más grande y todas las demás se capturan. Toda
	# araña que quede en lo capturado muere -- incluida la jefa (ver
	# _kill_enemies_in_cells). Antes la región de la jefa nunca se
	# capturaba: si la encerrabas en un rincón chico, el juego se llevaba el
	# lado GRANDE (el que no querías) y la jefa seguía viva -- de ahí que
	# "no se podían matar las arañas".
	var newly_cells: Array = []
	for c: Vector2i in trail:
		grid_state[c.y][c.x] = "captured"
		newly_cells.append(c)

	var regions: Array = _open_regions()
	var keep: int = -1
	var boss_region: int = _region_of_boss(regions)
	for i in range(regions.size()):
		if keep == -1 or regions[i].size() > regions[keep].size() \
				or (regions[i].size() == regions[keep].size() and i == boss_region):
			keep = i
	for i in range(regions.size()):
		if i == keep:
			continue
		for c: Vector2i in regions[i]:
			grid_state[c.y][c.x] = "captured"
			newly_cells.append(c)

	trail.clear()
	trail_line.points = PackedVector2Array()
	_reveal_new_cells(newly_cells)
	# Puntaje proporcional al área encerrada de una sola vez (como el
	# arcade original: capturas grandes valen mucho más que ir celda a
	# celda), con un pequeño extra fijo por cerrar el trazo.
	score += 20 + newly_cells.size() * 2
	if not bonus_triggered and grid_state[bonus_cell.y][bonus_cell.x] == "captured":
		_trigger_asteroid_storm()
	_update_panic_gauge(newly_cells)
	_update_hud()
	_kill_enemies_in_cells(newly_cells)

	# Si ya no queda ninguna araña (ni la jefa), el paisaje se destapa
	# completo en automático y el nivel se da por ganado, sin importar el %
	# ni la barra chica/monstruo -- es la recompensa por limpiar el tablero.
	# Los Sparx (centinelas del borde) no cuentan como arañas.
	var cleared: bool = _spiders_left() == 0
	if cleared:
		var rest: Array = []
		for y in range(GRID_H):
			for x in range(GRID_W):
				if grid_state[y][x] == "open":
					grid_state[y][x] = "captured"
					rest.append(Vector2i(x, y))
		_reveal_new_cells(rest)
		score += CLEAR_BONUS_SCORE + rest.size() * 2
		_update_hud()
		AudioManager.play_power()
	elif _capture_percent() < CAPTURE_TARGET:
		return
	elif panic_gauge < PANIC_MONSTER_THRESHOLD:
		# Como en el arcade original: llegar a la meta con la barra del lado
		# "monstruo" no completa el nivel -- hay que seguir revelando fondo
		# (no la silueta) hasta recuperarla y volver a cerrar un trazo.
		status_label.text = "¡Se volvió monstruo! Revela fondo para recuperarla"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		return

	# Como en el arcade original: se ve el paisaje completo revelado un
	# momento antes de pasar de nivel, en vez de cortar la animación a
	# medias. Se bloquea el juego (state != "playing") mientras se espera, y
	# solo hasta que la cortina terminó de verdad se resetea todo para el
	# nivel nuevo -- así nunca hay una tween vieja viva escribiendo sobre la
	# máscara del nivel nuevo.
	state = "level_complete"
	status_label.remove_theme_color_override("font_color")
	if cleared:
		status_label.text = "¡Sin arañas! Paisaje revelado +%d" % CLEAR_BONUS_SCORE
	else:
		status_label.text = "¡Nivel %d completo!" % level
	var session: int = game_session
	if reveal_tween and reveal_tween.is_valid():
		await reveal_tween.finished
	# Con el tablero limpio se deja ver el paisaje completo un rato más.
	await get_tree().create_timer(2.2 if cleared else 0.85).timeout
	if session != game_session:
		return
	_advance_level()


## Componentes conexas (4 vecinos) de celdas "open". Con traza diagonal esto
## sigue siendo correcto: dos celdas abiertas a lados opuestos de una línea
## diagonal solo se tocan en diagonal, así que no se "fugan" entre sí.
func _open_regions() -> Array:
	var seen: Dictionary = {}
	var regions: Array = []
	for y in range(GRID_H):
		for x in range(GRID_W):
			var start := Vector2i(x, y)
			if grid_state[y][x] != "open" or seen.has(start):
				continue
			var region: Array = [start]
			seen[start] = true
			var stack: Array = [start]
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				for d: Vector2i in DIRS:
					var n: Vector2i = cur + d
					if not _cell_is(n, "open") or seen.has(n):
						continue
					seen[n] = true
					region.append(n)
					stack.append(n)
			regions.append(region)
	return regions


func _spiders_left() -> int:
	var n := 0
	for e: Dictionary in enemies:
		if e["kind"] == "qix":
			n += 1
	return n


func _region_of_boss(regions: Array) -> int:
	for e: Dictionary in enemies:
		if e["kind"] == "qix" and e.get("is_lead", false):
			for i in range(regions.size()):
				if regions[i].has(e["pos"]):
					return i
	return -1


func _kill_enemies_in_cells(cells: Array) -> void:
	## Toda araña que quede dentro del área recién capturada muere ahí
	## mismo, sin importar el tamaño del área -- la jefa también (vale
	## BOSS_KILL_SCORE). Los Sparx viven en el borde exterior y no cuentan.
	if cells.is_empty():
		return
	var captured_now: Dictionary = {}
	for c: Vector2i in cells:
		captured_now[c] = true
	var killed_any := false
	var killed_boss := false
	for e: Dictionary in enemies.duplicate():
		if e["kind"] != "qix" or not captured_now.has(e["pos"]):
			continue
		if e.get("is_lead", false):
			killed_boss = true
			score += BOSS_KILL_SCORE
		else:
			score += KILL_SCORE
		_kill_enemy(e)
		killed_any = true
	if killed_boss:
		var msg: String = "¡Araña jefa eliminada! +%d" % BOSS_KILL_SCORE
		status_label.text = msg
		AudioManager.play_power()
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if status_label.text == msg:
				status_label.text = "Nivel %d/%d" % [level, MAX_LEVEL])
	elif killed_any:
		AudioManager.play_click()
	_update_hud()


## Quita al enemigo de la lógica de inmediato y le da una animación corta de
## "aplastado" (crece y se desvanece) antes de liberar el nodo, para que se
## note que murió en vez de desaparecer de golpe.
func _kill_enemy(e: Dictionary) -> void:
	enemies.erase(e)
	var view: EntitySprite = e["view"]
	view.pivot_offset = view.size / 2.0
	var tw := view.create_tween().set_parallel(true)
	tw.tween_property(view, "scale", Vector2(1.7, 1.7), 0.35)
	tw.tween_property(view, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.35)
	tw.chain().tween_callback(view.queue_free)


## Las arañas caminan en 8 direcciones, cambian de rumbo de vez en cuando
## (no solo al chocar) y rebotan en lo capturado. La jefa, mientras estás
## trazando, a veces gira hacia tu marcador.
func _move_enemy(e: Dictionary) -> void:
	var dir: Vector2i = e["dir"]
	if e.get("is_lead", false) and not trail.is_empty() and randf() < BOSS_CHASE_CHANCE:
		var to_player: Vector2i = player_cell - e["pos"]
		dir = Vector2i(signi(to_player.x), signi(to_player.y))
	elif randf() < ENEMY_TURN_CHANCE:
		dir = OCTANTS[randi() % OCTANTS.size()]
	var next: Vector2i = _enemy_step(e["pos"], dir)
	var tries := 0
	while next == NO_CELL and tries < 8:
		dir = OCTANTS[randi() % OCTANTS.size()]
		next = _enemy_step(e["pos"], dir)
		tries += 1
	if next == NO_CELL:
		return
	e["dir"] = dir
	e["pos"] = next
	e["view"].set_facing(_dir_to_deg(dir))


## Celda a la que llega una araña que avanza en `d`, o NO_CELL si ahí hay
## pared (borde o zona capturada). Las arañas SÍ pueden pisar tu traza --
## eso es justo lo que te mata (ver _check_enemy_collisions); antes solo
## podían entrar a celdas "open", así que rebotaban en la traza como si
## fuera pared y casi nunca te alcanzaban. Un paso diagonal que pasa "por la
## esquina" de tu traza cuenta como tocarla: cae sobre esa celda de traza.
func _enemy_step(from: Vector2i, d: Vector2i) -> Vector2i:
	if d == Vector2i.ZERO:
		return NO_CELL
	var to: Vector2i = from + d
	if not _enemy_can_enter(to):
		return NO_CELL
	if d.x != 0 and d.y != 0:
		var a: Vector2i = from + Vector2i(d.x, 0)
		var b: Vector2i = from + Vector2i(0, d.y)
		if _cell_is(a, "trail"):
			return a
		if _cell_is(b, "trail"):
			return b
		# No se cuela en diagonal entre dos paredes que se tocan en esquina.
		if not _enemy_can_enter(a) and not _enemy_can_enter(b):
			return NO_CELL
	return to


func _enemy_can_enter(p: Vector2i) -> bool:
	if p.x <= 0 or p.x >= GRID_W - 1 or p.y <= 0 or p.y >= GRID_H - 1:
		return false
	var s: String = grid_state[p.y][p.x]
	return s == "open" or s == "trail"


func _move_sparx(e: Dictionary) -> void:
	e["s"] = posmod(e["s"] + e["step"], perimeter_cells.size())
	e["pos"] = perimeter_cells[e["s"]]


func _check_enemy_collisions() -> void:
	for e: Dictionary in enemies:
		if e["kind"] == "sparx":
			# Los Sparx patrullan el borde: te alcanzan aunque estés en
			# zona "segura" (a diferencia de los Qix, que solo amenazan
			# tu traza dentro del área sin revelar).
			if e["pos"] == player_cell:
				_lose_life()
				return
			continue
		if e["pos"] == player_cell and not trail.is_empty():
			_lose_life()
			return
		if grid_state[e["pos"].y][e["pos"].x] == "trail":
			_lose_life()
			return


func _time_out() -> void:
	time_left = _level_time_limit()
	_lose_life()


func _lose_life() -> void:
	lives -= 1
	for c: Vector2i in trail:
		grid_state[c.y][c.x] = "open"
	trail.clear()
	player_cell = Vector2i(0, 0)
	current_dir = Vector2i.ZERO
	dragging = false
	move_timer = 0.0
	# Reinicio instantáneo (no un planeo desde donde murió): tanto el punto
	# de partida como el de llegada de la interpolación quedan en el origen.
	player_prev_pos = Vector2.ZERO
	player_target_pos = Vector2.ZERO
	player_view.position = _view_pos(Vector2.ZERO, player_view)
	trail_line.points = PackedVector2Array()
	_update_hud()

	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over. Puntos: %d" % score
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result(false)


func _advance_level() -> void:
	if level >= MAX_LEVEL:
		_win()
		return
	level += 1
	state = "playing"
	_setup_level()


func _win() -> void:
	state = "won"
	status_label.text = "¡Completaste los %d niveles! Puntos: %d" % [MAX_LEVEL, score]
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	_record_result(true)


func _record_result(won: bool) -> void:
	AudioManager.play_win() if won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)


func _rebuild_mask() -> void:
	## Reconstruye mask_image completo desde grid_state (1.0 = capturada,
	## 0.0 = todavía no) y lo sube a mask_texture. Solo hace falta al
	## arrancar un nivel — capturar celdas nuevas se anima aparte con
	## _reveal_new_cells(), y perder una vida no cambia qué está capturado.
	for y in range(GRID_H):
		for x in range(GRID_W):
			var v: float = 1.0 if grid_state[y][x] == "captured" else 0.0
			mask_image.set_pixel(x, y, Color(v, v, v))
	mask_texture.update(mask_image)


func _reveal_new_cells(cells: Array) -> void:
	## El área recién encerrada no aparece de golpe: su valor en la máscara
	## sube de 0 a 1 en un tween corto, así que el shader de cover_mask las
	## va destapando con un fundido — el equivalente con el sistema nuevo
	## a la "cortina" que antes barría celda por celda.
	if cells.is_empty():
		return
	if reveal_tween and reveal_tween.is_valid():
		reveal_tween.kill()
		_apply_reveal_progress(1.0, reveal_cells)
	var duration: float = clamp(0.15 + cells.size() * 0.006, 0.2, 0.9)
	reveal_cells = cells
	reveal_tween = create_tween()
	reveal_tween.tween_method(_apply_reveal_progress.bind(cells), 0.0, 1.0, duration)


func _apply_reveal_progress(t: float, cells: Array) -> void:
	for c: Vector2i in cells:
		mask_image.set_pixel(c.x, c.y, Color(t, t, t))
	mask_texture.update(mask_image)


func _update_trail_line() -> void:
	## La traza en curso se dibuja como una sola línea suave (tipo trazo de
	## pluma) en vez de celdas cuadriculadas: arranca en el punto exacto del
	## borde seguro que se dejó (trail_origin), pasa por el centro de cada
	## celda ya trazada, y su punta sigue la posición interpolada del
	## marcador (no la celda lógica) para que se vea continua, no a saltos.
	if trail.is_empty():
		trail_line.points = PackedVector2Array()
		return
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2(trail_origin) * CELL + Vector2(CELL, CELL) / 2.0)
	for c: Vector2i in trail:
		pts.append(Vector2(c) * CELL + Vector2(CELL, CELL) / 2.0)
	pts.append(player_view.position + player_view.size / 2.0)
	trail_line.points = pts
