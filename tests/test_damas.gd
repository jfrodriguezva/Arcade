extends "res://tests/test_base.gd"
## Damas: bobas (soplar), la IA come cuando puede y remata sin repetir.


func _empty(g: Node) -> void:
	for y in 8:
		for x in 8:
			g.board[y][x] = null


func _put(g: Node, x: int, y: int, owner: String, king: bool = false) -> void:
	g.board[y][x] = {"owner": owner, "king": king}


func run() -> void:
	var g: Node = await open("res://games/board/checkers/checkers.tscn", false)
	g._on_setup_confirmed({"mode": "pvp", "difficulty": "hard"})

	_empty(g); _put(g, 2, 5, "player"); _put(g, 6, 5, "player"); _put(g, 3, 4, "bot"); _put(g, 1, 0, "bot")
	g._begin_turn_tracking("player")
	g._on_cell_pressed(6, 5); g._on_cell_pressed(7, 4)
	check(g.board[5][2] == null and g.board[4][7] != null, "no comió: le soplan la ficha que podía comer")

	g.current_turn = "player"
	_empty(g); _put(g, 2, 5, "player"); _put(g, 3, 4, "bot"); _put(g, 7, 0, "bot"); _put(g, 0, 7, "player")
	g._begin_turn_tracking("player")
	g._on_cell_pressed(2, 5); g._on_cell_pressed(1, 4)
	check(g.board[4][1] == null, "movió la que podía comer sin comer: se pierde donde quedó")

	g.current_turn = "player"
	_empty(g); _put(g, 2, 5, "player"); _put(g, 3, 4, "bot"); _put(g, 7, 0, "bot"); _put(g, 0, 7, "player")
	g._begin_turn_tracking("player")
	g._on_cell_pressed(2, 5); g._on_cell_pressed(4, 3)
	check(g.board[3][4] != null and g.board[7][0] != null, "si come, no hay boba")

	g.mode = "pve"
	_empty(g); _put(g, 1, 2, "bot"); _put(g, 2, 3, "player"); _put(g, 6, 1, "bot"); _put(g, 6, 7, "player")
	var mv: Dictionary = g._pick_bot_move()
	check(mv["path"].size() == 2 and absi(mv["path"][1].x - mv["path"][0].x) == 2, "la IA come en vez de mover otra ficha")

	_empty(g)
	g.position_history.clear(); g.quiet_plies = 0; g.game_over = false
	_put(g, 2, 3, "bot", true); _put(g, 5, 2, "bot", true); _put(g, 3, 6, "bot", true); _put(g, 6, 7, "player", true)
	g.current_turn = "bot"
	g._begin_turn_tracking("bot")
	var plies := 0
	while not g.game_over and plies < 120:
		if g.current_turn == "bot":
			await g._bot_turn()
		else:
			var opts: Array = []
			for y in 8:
				for x in 8:
					var p = g.board[y][x]
					if p != null and p["owner"] == "player":
						for d: Vector2i in g.DIRS:
							var t: Vector2i = Vector2i(x, y) + d
							if t.x >= 0 and t.x < 8 and t.y >= 0 and t.y < 8 and g.board[t.y][t.x] == null:
								opts.append([Vector2i(x, y), t])
			if opts.is_empty():
				g._check_win()
				break
			var o: Array = opts[randi() % opts.size()]
			g._on_cell_pressed(o[0].x, o[0].y)
			g._on_cell_pressed(o[1].x, o[1].y)
		plies += 1
	check(g._count_pieces("player") == 0 or str(g.status_label.text).contains("máquina"), "con 3 reinas contra 1 la IA remata (%d medias jugadas)" % plies)
