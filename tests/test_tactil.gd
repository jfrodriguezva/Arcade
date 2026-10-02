extends "res://tests/test_base.gd"
## Los controles táctiles (GesturePad) mueven y disparan en cada juego.


func _btn(pad: Control, pos: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	pad._gui_input(e)


func _move(pad: Control, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	pad._gui_input(e)


func run() -> void:
	var g: Node = await open("res://games/arcade/galaga_swarm/galaga_swarm.tscn")
	var x0: float = g.player_x
	_btn(g.pad, Vector2(100, 600), true)
	advance(g, 0.5)
	check(g.player_x < x0 - 100.0 and g.bullets.size() > 0, "galaga: la nave sigue al dedo y dispara sola")
	_btn(g.pad, Vector2(100, 600), false)

	var a: Node = await open("res://games/arcade/asteroids/asteroids.tscn")
	_btn(a.pad, a.ship_pos + Vector2(220, 0), true)
	advance(a, 0.7)
	check(a.ship_rot > 1.0 and a.ship_vel.length() > 20.0, "asteroids: gira hacia el dedo y acelera si está lejos")
	_btn(a.pad, a.ship_pos + Vector2(220, 0), false)

	var t: Node = await open("res://games/arcade/block_stacker/block_stacker.tscn")
	var px: int = t.piece_pos.x
	_btn(t.pad, Vector2(200, 300), true)
	for k in 4:
		_move(t.pad, Vector2(200 + 20 * (k + 1), 300))
	_btn(t.pad, Vector2(280, 300), false)
	check(t.piece_pos.x == px + 2, "tetris: arrastrar a la derecha mueve 2 columnas")

	var b: Node = await open("res://games/arcade/bomber_maze/bomber_maze.tscn")
	_btn(b.pad, Vector2(300, 300), true)
	_move(b.pad, Vector2(360, 300))
	check(b.current_dir == Vector2i(1, 0), "bomberman: el joystick invisible camina a la derecha")
	_btn(b.pad, Vector2(360, 300), false)
	await wait(0.4)
	_btn(b.pad, Vector2(300, 300), true)
	_btn(b.pad, Vector2(300, 300), false)
	check(b.bombs.size() == 1, "bomberman: tocar pone una bomba")

	var m: Node = await open("res://games/arcade/maze_muncher/maze_muncher.tscn")
	_btn(m.pad, Vector2(300, 300), true)
	_move(m.pad, Vector2(300, 260))
	_btn(m.pad, Vector2(300, 260), false)
	check(m.desired_dir == Vector2i(0, -1), "pac-man: deslizar hacia arriba pide subir")
