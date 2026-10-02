extends "res://tests/test_base.gd"
## Ajedrez, Otelo y Cuatro en Línea: los motores de Difícil dan jugadas
## legales y aprovechan lo obvio.


func run() -> void:
	var ch: Node = await open("res://games/board/chess/chess.tscn", false)
	ch._on_setup_confirmed({"mode": "pve", "difficulty": "hard"})
	ch.current_turn = "bot"
	var mv: Dictionary = ch._engine_best_move()
	var legal: Array = ch._legal_moves_for(ch.board, mv["from"].x, mv["from"].y)
	check(legal.has(mv["to"]), "ajedrez: la jugada inicial de la IA es legal (%s -> %s)" % [mv["from"], mv["to"]])
	# Dama del jugador colgando: la IA debe comerla.
	for y in 8:
		for x in 8:
			ch.board[y][x] = null
	ch.board[0][4] = {"type": "K", "owner": "bot", "moved": true}
	ch.board[7][4] = {"type": "K", "owner": "player", "moved": true}
	ch.board[3][3] = {"type": "R", "owner": "bot", "moved": true}
	ch.board[3][6] = {"type": "Q", "owner": "player", "moved": true}
	var mv2: Dictionary = ch._engine_best_move()
	check(mv2["to"] == Vector2i(6, 3), "ajedrez: la IA come la dama que se deja colgando")

	var ot: Node = await open("res://games/board/othello/othello.tscn", false)
	ot._on_setup_confirmed({"mode": "pve", "difficulty": "hard"})
	var moves: Array = ot._legal_moves_on(ot.board, "bot")
	var pick: Vector2i = ot._engine_pick(moves)
	check(moves.has(pick), "otelo: la IA elige una jugada legal")

	var c4: Node = await open("res://games/board/connect_four/connect_four.tscn", false)
	c4._on_setup_confirmed({"mode": "pve", "difficulty": "hard"})
	for x in [0, 1, 2]:
		c4._drop(c4.board, x, "player")
	var col: int = c4._engine_pick(c4._valid_columns(c4.board))
	check(col == 3, "cuatro en línea: la IA bloquea el 4 en línea (eligió %d)" % col)
