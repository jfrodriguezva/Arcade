extends Node
## Registro central de juegos y navegación entre el hub y cada juego.
## Agregar un juego nuevo = agregar una entrada aquí + crear su escena.
## El Hub no necesita tocarse.

var games: Array[Dictionary] = [
	{
		"id": "tictactoe",
		"title": "Gato",
		"category": "mesa",
		"scene": "res://games/board/tictactoe/tic_tac_toe.tscn",
		"enabled": true,
	},
	{
		"id": "battleship",
		"title": "Batalla Naval",
		"category": "mesa",
		"scene": "res://games/board/battleship/battleship.tscn",
		"enabled": true,
	},
	{
		"id": "solitaire",
		"title": "Solitario",
		"category": "mesa",
		"scene": "res://games/board/solitaire/solitaire.tscn",
		"enabled": true,
	},
	{
		"id": "checkers",
		"title": "Damas",
		"category": "mesa",
		"scene": "res://games/board/checkers/checkers.tscn",
		"enabled": true,
	},
	{
		"id": "othello",
		"title": "Otelo",
		"category": "mesa",
		"scene": "res://games/board/othello/othello.tscn",
		"enabled": true,
	},
	{
		"id": "domino",
		"title": "Dominó",
		"category": "mesa",
		"scene": "res://games/board/domino/domino.tscn",
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
