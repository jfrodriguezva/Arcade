extends Node
## Registro central de juegos y navegación entre el hub y cada juego.
## Agregar un juego nuevo = agregar una entrada aquí + crear su escena.
## El Hub no necesita tocarse.

var games: Array[Dictionary] = [
	{
		"id": "tictactoe",
		"title": "Gato",
		"icon": "❌",
		"category": "mesa",
		"scene": "res://games/board/tictactoe/tic_tac_toe.tscn",
		"enabled": true,
	},
	{
		"id": "battleship",
		"title": "Batalla Naval",
		"icon": "🚢",
		"category": "mesa",
		"scene": "res://games/board/battleship/battleship.tscn",
		"enabled": true,
	},
	{
		"id": "solitaire",
		"title": "Solitario",
		"icon": "🃏",
		"category": "mesa",
		"scene": "res://games/board/solitaire/solitaire.tscn",
		"enabled": true,
	},
	{
		"id": "checkers",
		"title": "Damas",
		"icon": "🔴",
		"category": "mesa",
		"scene": "res://games/board/checkers/checkers.tscn",
		"enabled": true,
	},
	{
		"id": "othello",
		"title": "Otelo",
		"icon": "⚫",
		"category": "mesa",
		"scene": "res://games/board/othello/othello.tscn",
		"enabled": true,
	},
	{
		"id": "domino",
		"title": "Dominó",
		"icon": "🁫",
		"category": "mesa",
		"scene": "res://games/board/domino/domino.tscn",
		"enabled": true,
	},
	{
		"id": "loteria",
		"title": "Lotería",
		"icon": "🐓",
		"category": "mesa",
		"scene": "res://games/board/loteria/loteria.tscn",
		"enabled": true,
	},
	{
		"id": "chess",
		"title": "Ajedrez",
		"icon": "♟️",
		"category": "mesa",
		"scene": "res://games/board/chess/chess.tscn",
		"enabled": true,
	},
	{
		"id": "sudoku",
		"title": "Sudoku",
		"icon": "🔢",
		"category": "mesa",
		"scene": "res://games/board/sudoku/sudoku.tscn",
		"enabled": true,
	},
	{
		"id": "snakes_ladders",
		"title": "Serpientes y Escaleras",
		"icon": "🐍",
		"category": "mesa",
		"scene": "res://games/board/snakes_ladders/snakes_ladders.tscn",
		"enabled": true,
	},
	{
		"id": "generala",
		"title": "Generala",
		"icon": "🎲",
		"category": "mesa",
		"scene": "res://games/board/generala/generala.tscn",
		"enabled": true,
	},
	{
		"id": "parchis",
		"title": "Parchís",
		"icon": "🏁",
		"category": "mesa",
		"scene": "res://games/board/parchis/parchis.tscn",
		"enabled": true,
	},
	{
		"id": "mahjong",
		"title": "Mahjong Solitario",
		"icon": "🀄",
		"category": "mesa",
		"scene": "res://games/board/mahjong/mahjong.tscn",
		"enabled": true,
	},
	{
		"id": "chinese_checkers",
		"title": "Damas Chinas",
		"icon": "🟣",
		"category": "mesa",
		"scene": "res://games/board/chinese_checkers/chinese_checkers.tscn",
		"enabled": true,
	},
	{
		"id": "backgammon",
		"title": "Backgammon",
		"icon": "🟤",
		"category": "mesa",
		"scene": "res://games/board/backgammon/backgammon.tscn",
		"enabled": true,
	},
	{
		"id": "arkanoid",
		"title": "Arkanoid",
		"icon": "🧱",
		"category": "arcade",
		"scene": "res://games/arcade/arkanoid/arkanoid.tscn",
		"enabled": true,
	},
]

var current_game_id: String = ""


func get_games_by_category(category: String) -> Array[Dictionary]:
	return games.filter(func(g: Dictionary) -> bool: return g["category"] == category and g["enabled"])


func get_game(id: String) -> Dictionary:
	for g: Dictionary in games:
		if g["id"] == id:
			return g
	return {}


func go_to_game(id: String) -> void:
	var game := get_game(id)
	if game.is_empty():
		push_error("Juego no encontrado: %s" % id)
		return
	current_game_id = id
	get_tree().change_scene_to_file(game["scene"])


func go_to_hub() -> void:
	current_game_id = ""
	get_tree().change_scene_to_file("res://core/scenes/hub.tscn")
