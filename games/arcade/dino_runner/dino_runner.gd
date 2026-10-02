extends Control
## Dino Corredor, al estilo del juego del dinosaurio de Chrome (el que sale
## sin internet): el T-Rex corre solo, salta cactus y esquiva pterodáctilos;
## la velocidad sube poco a poco. Cada 100 puntos suena un aviso y a los
## 700 la escena se vuelve de noche (y alterna después). Pixel art propio,
## dibujado en código.
##
## Control táctil sin botones: toca para saltar (mantén para saltar más
## alto), desliza o arrastra hacia abajo para agacharte. Teclado: espacio /
## flecha arriba para saltar y flecha abajo para agacharte.

const GAME_ID := "dino_runner"
const PLAY_W := 680.0
const PLAY_H := 420.0
const PX := 4.0                       # tamaño de cada "pixel" del arte
const GROUND_Y := 340.0
const DINO_X := 60.0
const GRAVITY := 3600.0
const JUMP_VELOCITY := -1000.0
const JUMP_CUT_VELOCITY := -480.0    # soltar antes corta el salto (salto variable)
const FAST_FALL := 5200.0
const START_SPEED := 600.0
const MAX_SPEED := 1300.0
const ACCEL := 9.0                   # px/s de velocidad ganados por segundo
const PTERO_MIN_SPEED := 860.0
const NIGHT_EVERY := 700
const SCORE_PER_PX := 0.015

## Arte en pixeles ('#' = relleno, '.' = ojo).
const DINO_BODY := [
	"           ########",
	"          ##.######",
	"          #########",
	"          #########",
	"          #####    ",
	"          ######## ",
	"#        #####     ",
	"#       ######     ",
	"##    #########    ",
	"###  ######### #   ",
	"#############      ",
	"#############      ",
	" ###########       ",
	"  #########        ",
	"   #######         ",
]
const DINO_LEGS := [
	["    ##  ##", "    #    ##", "    ##     "],
	["    ##  ##", "    ##   # ", "         ##"],
]
const DINO_DUCK := [
	"#                 ########",
	"##    ##########  ##.#####",
	"####################### ##",
	" ###################      ",
	"  ################ #      ",
	"   #############          ",
]
const DINO_DUCK_LEGS := [["    ##   ##", "    #     ##"], ["    ##   ##", "    ##    #"]]
const CACTUS_SMALL := [
	"  ##  ",
	"  ##  ",
	"# ## #",
	"# ## #",
	"# ## #",
	"######",
	"  ##  ",
	"  ##  ",
	"  ##  ",
	"  ##  ",
]
const CACTUS_LARGE := [
	"   ##   ",
	"  ####  ",
	"  #### #",
	"# #### #",
	"# #### #",
	"# #### #",
	"# ######",
	"# ####  ",
	"######  ",
	"  ####  ",
	"  ####  ",
	"  ####  ",
	"  ####  ",
	"  ####  ",
	"  ####  ",
]
const PTERO := [
	[
		"     #            ",
		"     ##           ",
		"   # ###          ",
		"  ## ####         ",
		" ###########      ",
		"################# ",
		"     ############ ",
		"       ######     ",
	],
	[
		"                  ",
		"                  ",
		"   #              ",
		"  ##              ",
		" ###########      ",
		"################# ",
		"     ######       ",
		"     ####         ",
		"     ###          ",
		"     ##           ",
		"     #            ",
	],
]

const HELP_TEXT := "El dinosaurio corre solo. Esquiva los obstáculos:

- Toca la pantalla para saltar. Si mantienes el dedo, salta más alto; si lo sueltas rápido, el salto es corto.
- Desliza o arrastra hacia abajo para agacharte (y para caer más rápido si vas en el aire).
(En teclado: espacio o ↑ para saltar, ↓ para agacharte.)

Salta los cactus y agáchate o salta los pterodáctilos según su altura. La velocidad sube poco a poco. Cada 100 puntos suena un aviso y a los 700 se hace de noche. Si chocas, toca para volver a empezar."

var dino_y: float = 0.0       # 0 = en el suelo; negativo = en el aire
var dino_vy: float = 0.0
var ducking: bool = false
var jump_held: bool = false
var speed: float = START_SPEED
var distance: float = 0.0
var score: int = 0
var high_score: int = 0
var obstacles: Array = []
var clouds: Array = []
var bumps: Array = []
var spawn_gap: float = 0.0
var anim_t: float = 0.0
var night: float = 0.0        # 0 día ... 1 noche (transición suave)
var night_target: float = 0.0
var flash_t: float = 0.0
var state: String = "ready"   # ready | playing | dead
var died_at: int = 0

var play_area: Control
var pad: GesturePad
var score_label: Label


func _ready() -> void:
	_build_ui()
	high_score = int(SaveManager.get_game_data(GAME_ID).get("best_score", 0))
	_reset()
	TouchHint.show_once(self, GAME_ID, [["👆", "Toca: salta (mantén el dedo para saltar más alto)."], ["⬇", "Desliza hacia abajo: agáchate."]])


func _build_ui() -> void:
	UIKit.apply_background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	UIKit.build_toolbar(vbox, self, "Dino Corredor", HELP_TEXT)
	score_label = UIKit.title_label("", 15, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(score_label)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(panel)
	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(PLAY_W, PLAY_H)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_area.draw.connect(_draw_play)
	panel.add_child(play_area)

	pad = GesturePad.attach(play_area)
	pad.pressed.connect(func(_p: Vector2) -> void: _on_press())
	pad.released.connect(func(_p: Vector2) -> void:
		jump_held = false
		ducking = false)
	pad.dragged.connect(func(_p: Vector2, from_start: Vector2, _s: Vector2) -> void:
		ducking = from_start.y > 30.0 and absf(from_start.y) > absf(from_start.x))


func _reset() -> void:
	dino_y = 0.0
	dino_vy = 0.0
	ducking = false
	speed = START_SPEED
	distance = 0.0
	score = 0
	obstacles.clear()
	clouds.clear()
	bumps.clear()
	for i in range(4):
		clouds.append(Vector2(randf() * PLAY_W, randf_range(40.0, 160.0)))
	for i in range(12):
		bumps.append(Vector2(randf() * PLAY_W, randf_range(4.0, 14.0)))
	spawn_gap = 500.0
	night = 0.0
	night_target = 0.0
	state = "ready"
	_update_label()


func _update_label() -> void:
	score_label.text = "HI %05d   %05d" % [high_score, score]


func _on_press() -> void:
	match state:
		"ready":
			state = "playing"
			_jump()
		"playing":
			_jump()
		"dead":
			# Medio segundo de gracia para no reiniciar sin querer.
			if Time.get_ticks_msec() - died_at > 500:
				_reset()
				state = "playing"


func _jump() -> void:
	jump_held = true
	if dino_y >= 0.0 and not ducking:
		dino_vy = JUMP_VELOCITY
		AudioManager.play_jump()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.keycode in [KEY_SPACE, KEY_UP]:
		if event.pressed and not event.echo:
			_on_press()
		elif not event.pressed:
			jump_held = false
	elif event.keycode == KEY_DOWN:
		ducking = event.pressed


func _process(delta: float) -> void:
	night = move_toward(night, night_target, delta * 1.5)
	if flash_t > 0.0:
		flash_t -= delta
	play_area.queue_redraw()
	if state != "playing":
		return
	anim_t += delta
	speed = minf(speed + ACCEL * delta, MAX_SPEED)
	var dx: float = speed * delta
	distance += dx
	var new_score: int = int(distance * SCORE_PER_PX)
	if new_score / 100 > score / 100:
		flash_t = 1.0
		AudioManager.play_coin()
	if new_score / NIGHT_EVERY > score / NIGHT_EVERY:
		night_target = 1.0 - night_target  # alterna día y noche
	score = new_score
	_update_label()

	# Física del salto (variable: soltar corta el salto; agacharse en el
	# aire hace caer más rápido).
	if dino_y < 0.0 or dino_vy < 0.0:
		if not jump_held and dino_vy < JUMP_CUT_VELOCITY:
			dino_vy = JUMP_CUT_VELOCITY
		dino_vy += (FAST_FALL if ducking else GRAVITY) * delta
		dino_y += dino_vy * delta
		if dino_y >= 0.0:
			dino_y = 0.0
			dino_vy = 0.0

	for i in range(clouds.size()):
		clouds[i].x -= dx * 0.2
		if clouds[i].x < -100.0:
			clouds[i] = Vector2(PLAY_W + randf() * 200.0, randf_range(40.0, 160.0))
	for i in range(bumps.size()):
		bumps[i].x -= dx
		if bumps[i].x < -20.0:
			bumps[i] = Vector2(PLAY_W + randf() * 60.0, randf_range(4.0, 14.0))

	for o: Dictionary in obstacles:
		o["x"] -= dx + (o.get("own_speed", 0.0) * delta)
	obstacles = obstacles.filter(func(o: Dictionary) -> bool: return o["x"] + o["w"] > -20.0)
	spawn_gap -= dx
	if spawn_gap <= 0.0:
		_spawn_obstacle()

	if _collides():
		_die()


func _spawn_obstacle() -> void:
	var o: Dictionary
	if speed >= PTERO_MIN_SPEED and randf() < 0.28:
		# Pterodáctilo a una de tres alturas: bajo (saltar), medio (agacharse
		# o saltar) o alto (pasar corriendo / agachado).
		var heights: Array = [GROUND_Y - 44.0, GROUND_Y - 92.0, GROUND_Y - 140.0]
		var y: float = heights[randi() % heights.size()]
		o = {"kind": "ptero", "x": PLAY_W + 20.0, "y": y, "w": 18 * PX, "h": 8 * PX, "own_speed": 60.0}
	else:
		var large: bool = randf() < 0.45
		var art: Array = CACTUS_LARGE if large else CACTUS_SMALL
		var count: int = 1 + (randi() % (3 if speed > 800.0 else 2))
		var w: float = art[0].length() * PX * count + (count - 1) * PX
		o = {"kind": "cactus", "art": art, "count": count, "x": PLAY_W + 20.0, "y": GROUND_Y - art.size() * PX, "w": w, "h": art.size() * PX}
	obstacles.append(o)
	# Hueco hasta el siguiente: crece con la velocidad para que siempre
	# sea posible pasarlo.
	spawn_gap = o["w"] + speed * randf_range(0.55, 1.15) + 120.0


func _dino_rect() -> Rect2:
	if ducking and dino_y >= 0.0:
		return Rect2(DINO_X + 2.0 * PX, GROUND_Y - 8.0 * PX, 22.0 * PX, 7.0 * PX)
	return Rect2(DINO_X + 2.0 * PX, GROUND_Y + dino_y - 17.0 * PX, 15.0 * PX, 16.0 * PX)


func _collides() -> bool:
	var d: Rect2 = _dino_rect().grow(-PX)
	for o: Dictionary in obstacles:
		var r := Rect2(o["x"] + PX, o["y"] + PX, o["w"] - 2.0 * PX, o["h"] - 2.0 * PX)
		if d.intersects(r):
			return true
	return false


func _die() -> void:
	AudioManager.vibrate(200)
	state = "dead"
	died_at = Time.get_ticks_msec()
	AudioManager.play_lose()
	if score > high_score:
		high_score = score
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats["best_score"] = high_score
	stats["games"] = stats.get("games", 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
	_update_label()


# ----------------------------------------------------------------- dibujo --
func _colors() -> Array:
	var day_bg := Color(0.97, 0.97, 0.97)
	var day_fg := Color(0.33, 0.33, 0.33)
	var night_bg := Color(0.13, 0.13, 0.14)
	var night_fg := Color(0.91, 0.92, 0.93)
	return [day_bg.lerp(night_bg, night), day_fg.lerp(night_fg, night)]


func _draw_art(art: Array, pos: Vector2, color: Color, eye_color: Color) -> void:
	for row in range(art.size()):
		var line: String = art[row]
		for col in range(line.length()):
			var ch: String = line[col]
			if ch == "#":
				play_area.draw_rect(Rect2(pos + Vector2(col, row) * PX, Vector2(PX, PX)), color)
			elif ch == ".":
				play_area.draw_rect(Rect2(pos + Vector2(col, row) * PX, Vector2(PX, PX)), eye_color)


func _draw_play() -> void:
	var cols: Array = _colors()
	var bg: Color = cols[0]
	var fg: Color = cols[1]
	# El panel ocupa todo el alto disponible (toda la superficie es control
	# táctil); la escena se dibuja centrada verticalmente.
	play_area.draw_rect(Rect2(Vector2.ZERO, play_area.size), bg)
	play_area.draw_set_transform(Vector2((play_area.size.x - PLAY_W) / 2.0, (play_area.size.y - PLAY_H) / 2.0))
	if night > 0.05:
		# Luna y estrellas de noche.
		play_area.draw_circle(Vector2(PLAY_W - 120.0, 70.0), 18.0, Color(fg.r, fg.g, fg.b, night))
		play_area.draw_circle(Vector2(PLAY_W - 112.0, 64.0), 16.0, bg)
		for i in range(8):
			var sx: float = fmod(i * 97.0 + 40.0, PLAY_W)
			play_area.draw_rect(Rect2(sx, 30.0 + (i * 37) % 120, 3, 3), Color(fg.r, fg.g, fg.b, night * 0.8))
	var cloud_col := Color(fg.r, fg.g, fg.b, 0.25)
	for c: Vector2 in clouds:
		play_area.draw_rect(Rect2(c + Vector2(12, 0), Vector2(36, 8)), cloud_col)
		play_area.draw_rect(Rect2(c + Vector2(0, 8), Vector2(64, 8)), cloud_col)

	# Suelo con piedritas que se desplazan.
	play_area.draw_line(Vector2(0, GROUND_Y), Vector2(PLAY_W, GROUND_Y), fg, 2.0)
	for b: Vector2 in bumps:
		play_area.draw_rect(Rect2(b.x, GROUND_Y + b.y, 6.0 + fmod(b.x, 8.0), 2.0), fg)

	for o: Dictionary in obstacles:
		if o["kind"] == "cactus":
			var art: Array = o["art"]
			for k in range(o["count"]):
				_draw_art(art, Vector2(o["x"] + k * (art[0].length() + 1) * PX, o["y"]), fg, fg)
		else:
			var frame: int = int(anim_t * 6.0) % 2
			_draw_art(PTERO[frame], Vector2(o["x"], o["y"] - (12.0 if frame == 1 else 0.0)), fg, fg)

	# Dinosaurio (corriendo, agachado o muerto).
	var legs_frame: int = int(anim_t * 12.0) % 2 if state == "playing" and dino_y >= 0.0 else 0
	if ducking and dino_y >= 0.0 and state == "playing":
		var p := Vector2(DINO_X, GROUND_Y - 8.0 * PX)
		_draw_art(DINO_DUCK, p, fg, bg)
		_draw_art(DINO_DUCK_LEGS[legs_frame], p + Vector2(0, 6.0 * PX), fg, bg)
	else:
		var p2 := Vector2(DINO_X, GROUND_Y + dino_y - 18.0 * PX)
		_draw_art(DINO_BODY, p2, fg, bg)
		_draw_art(DINO_LEGS[legs_frame] if dino_y >= 0.0 else DINO_LEGS[0], p2 + Vector2(0, 15.0 * PX), fg, bg)
		if state == "dead":
			# Ojo en X.
			var e: Vector2 = p2 + Vector2(12.0 * PX, PX)
			play_area.draw_rect(Rect2(e, Vector2(PX, PX)), bg)
			play_area.draw_line(e - Vector2(PX, PX), e + Vector2(PX * 2, PX * 2), fg, 2.0)
			play_area.draw_line(e + Vector2(PX * 2, -PX), e + Vector2(-PX, PX * 2), fg, 2.0)

	var f: Font = get_theme_default_font()
	var txt := ""
	match state:
		"ready":
			txt = "Toca para empezar"
		"dead":
			txt = "G A M E   O V E R"
	if txt != "":
		var s: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		play_area.draw_string(f, Vector2(PLAY_W / 2.0 - s.x / 2.0, 150.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, fg)
		if state == "dead":
			# Ícono de reiniciar.
			play_area.draw_arc(Vector2(PLAY_W / 2.0, 205.0), 18.0, 0.6, TAU - 0.3, 20, fg, 4.0)
			play_area.draw_colored_polygon(PackedVector2Array([Vector2(PLAY_W / 2.0 + 18, 188), Vector2(PLAY_W / 2.0 + 26, 202), Vector2(PLAY_W / 2.0 + 8, 202)]), fg)
	var shown: bool = flash_t <= 0.0 or int(flash_t * 8.0) % 2 == 0
	var sc: String = "HI %05d  %s" % [high_score, ("%05d" % score) if shown else "     "]
	var ss: Vector2 = f.get_string_size(sc, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	play_area.draw_string(f, Vector2(PLAY_W - ss.x - 16.0, 34.0), sc, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, fg)
