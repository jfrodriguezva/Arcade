extends "res://tests/test_base.gd"
## Reglas principales de los arcade (jugadores automáticos y casos clave).


func run() -> void:
	await _burbujas()
	await _dino()
	await _nieve()
	await _pacman()
	await _dulce()
	await _arkanoid()


func _burbujas() -> void:
	var p: Node = await open("res://games/arcade/burbujas/burbujas.tscn")
	for stg in range(2):
		p.stage = stg
		p._start_stage()
		var frames := 0
		while p.state == "playing" and frames < 60 * 60:
			p.lives = 3
			p.hurt_t = 1.0
			if p.balls.size() > 0:
				var target: Dictionary = p.balls[0]
				for b: Dictionary in p.balls:
					if b["pos"].y > target["pos"].y:
						target = b
				p.player_x = clampf(target["pos"].x - 18.0 + 60.0 * signf(target["vel"].x), 0.0, p.PLAY_W - 36.0)
				p._fire()
			p._process(1.0 / 60.0)
			frames += 1
		check(p.state == "stage_clear", "burbujas: escenario %d superado por el bot" % (stg + 1))


func _dino() -> void:
	var d: Node = await open("res://games/arcade/dino_runner/dino_runner.tscn")
	d.state = "playing"
	var night := false
	for frame in range(60 * 60):
		var r: Rect2 = d._dino_rect()
		d.ducking = false
		d.jump_held = true
		for o: Dictionary in d.obstacles:
			var dist: float = o["x"] - r.end.x
			if dist > 0.0 and dist < d.speed * 0.28:
				if o["kind"] == "ptero" and o["y"] < d.GROUND_Y - 120.0:
					pass
				elif o["kind"] == "ptero" and o["y"] < d.GROUND_Y - 80.0:
					d.ducking = true
				elif d.dino_y >= 0.0:
					d._jump()
		d._process(1.0 / 60.0)
		night = night or d.night > 0.5
		if d.state != "playing":
			break
	check(d.state == "playing" and night, "dino: 60 s corriendo (%d puntos) y llega la noche" % d.score)


func _nieve() -> void:
	var s: Node = await open("res://games/arcade/snow_brawl/snow_brawl.tscn")
	s.level = 3
	s._setup_level()
	var e: Dictionary = s.enemies[0]
	for k in 3:
		s._cover_enemy(e)
	check(e["cover"] == 3 and e["alive"], "nieve: 3 bolazos lo cubren 3/4")
	s._cover_enemy(e)
	check(not e["alive"] and s.balls.size() == 1, "nieve: al 4o queda hecho bola")
	s._setup_level()
	for en: Dictionary in s.enemies:
		en["alive"] = false
	var a: Dictionary = s._spawn_enemy("demonio", Vector2(400, s.PLAY_H - 30 - 34))
	var b2: Dictionary = s._spawn_enemy("rana", Vector2(520, s.PLAY_H - 30 - 34))
	a["cover"] = 2
	b2["cover"] = 2
	s.balls.append({"pos": Vector2(250, s.PLAY_H - 30 - 19), "vel": Vector2.ZERO, "rolling": false, "bounces": 0,
		"chain": 0, "kind": "demonio", "life": 7.0, "pushed": false})
	s.player_pos = Vector2(250 - 19 - 34, s.PLAY_H - 30 - 42)
	s.facing = 1
	var sc0: int = s.score
	s._shoot()
	advance(s, 3.0, func(_i: int) -> void:
		s.lives = 3
		s.invuln = 1.0)
	check(not a["alive"] and not b2["alive"] and s.score - sc0 >= 1500, "nieve: la bola pateada arrolla a dos en cadena (500 + 1000)")


func _pacman() -> void:
	var m: Node = await open("res://games/arcade/maze_muncher/maze_muncher.tscn")
	check(m.dots_total == 244, "pac-man: 240 puntos + 4 bolitas")
	var seen := {m.PLAYER_START: true}
	var stack: Array = [m.PLAYER_START]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dd: Vector2i in m.DIRS:
			var nn: Vector2i = m._wrap(c + dd)
			if m._passable(nn) and not seen.has(nn):
				seen[nn] = true
				stack.append(nn)
	var unreachable := 0
	for y in 31:
		for x in 28:
			if (m.has_dot[y][x] or m.has_power[y][x]) and not seen.has(Vector2i(x, y)):
				unreachable += 1
	check(unreachable == 0, "pac-man: todos los puntos se pueden alcanzar")


func _dulce() -> void:
	var f: Node = await open("res://games/board/dulce_fiesta/dulce_fiesta.tscn")
	f.level_idx = 0
	f._start_level()
	var moves := 0
	while f.phase not in ["won", "lost"] and moves < 40:
		var steps := 0
		while f.phase not in ["idle", "won", "lost"] and steps < 3000:
			f._process(1.0 / 60.0)
			steps += 1
		if f.phase != "idle":
			break
		var mv: Array = f._find_valid_move()
		if mv.is_empty():
			break
		f._try_swap(mv[0], mv[1])
		moves += 1
	check(f.phase == "won", "dulce fiesta: el bot gana el nivel 1 (%d jugadas, %d puntos)" % [moves, f.score])


func _arkanoid() -> void:
	var k: Node = await open("res://games/arcade/arkanoid/arkanoid.tscn")
	var bad := 0
	for lay: Array in k.LAYOUTS:
		for row: String in lay:
			if row.length() != 13:
				bad += 1
	check(bad == 0, "arkanoid: 9 dibujos de nivel de 13 columnas")
	k.level = 3
	k._setup_level()
	k.state = "playing"
	k._release_stuck_balls()
	k._apply_capsule("D")
	check(k.balls.size() == 3, "arkanoid: cápsula D = tres bolas")
