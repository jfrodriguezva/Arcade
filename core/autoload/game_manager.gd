extends Node
## Registro central de juegos y navegación entre el hub y cada juego.
## Agregar un juego nuevo = agregar una entrada aquí + crear su escena.
## El Hub no necesita tocarse.
##
## El orden del arreglo es el orden en el que aparecen en el Hub, y está
## agrupado a propósito por tipo de juego (línea/territorio, estrategia
## clásica, cantar-y-marcar, dados/carrera, solitarios y rompecabezas) en
## vez de por orden de creación, para que juegos parecidos queden uno
## junto al otro.

var games: Array[Dictionary] = [
	# --- Línea / territorio (2 jugadores, rápidos) ---------------------
	{
		"id": "tictactoe",
		"title": "Gato",
		"icon": "❌",
		"category": "mesa",
		"scene": "res://games/board/tictactoe/tic_tac_toe.tscn",
		"enabled": true,
	},
	{
		"id": "connect_four",
		"title": "Cuatro en Línea",
		"icon": "🔵",
		"category": "mesa",
		"scene": "res://games/board/connect_four/connect_four.tscn",
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
		"id": "battleship",
		"title": "Batalla Naval",
		"icon": "🚢",
		"category": "mesa",
		"scene": "res://games/board/battleship/battleship.tscn",
		"enabled": true,
	},
	# --- Estrategia clásica de tablero ----------------------------------
	{
		"id": "checkers",
		"title": "Damas",
		"icon": "🔴",
		"category": "mesa",
		"scene": "res://games/board/checkers/checkers.tscn",
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
		"id": "chess",
		"title": "Ajedrez",
		"icon": "♟️",
		"category": "mesa",
		"scene": "res://games/board/chess/chess.tscn",
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
	# --- Cantar y marcar --------------------------------------------------
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
		"id": "bingo",
		"title": "Bingo",
		"icon": "🎱",
		"category": "mesa",
		"scene": "res://games/board/bingo/bingo.tscn",
		"enabled": true,
	},
	# --- Dados y carrera ----------------------------------------------
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
		"id": "snakes_ladders",
		"title": "Serpientes y Escaleras",
		"icon": "🐍",
		"category": "mesa",
		"scene": "res://games/board/snakes_ladders/snakes_ladders.tscn",
		"enabled": true,
	},
	# --- Solitarios y rompecabezas ---------------------------------------
	{
		"id": "solitaire",
		"title": "Solitario",
		"icon": "🃏",
		"category": "mesa",
		"scene": "res://games/board/solitaire/solitaire.tscn",
		"enabled": true,
	},
	{
		"id": "spider_solitaire",
		"title": "Solitario Araña",
		"icon": "🕷️",
		"category": "mesa",
		"scene": "res://games/board/spider_solitaire/spider_solitaire.tscn",
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
		"id": "memorama",
		"title": "Memorama",
		"icon": "🧠",
		"category": "mesa",
		"scene": "res://games/board/memorama/memorama.tscn",
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
	# --- Arcade: rompe-bloques / caída de piezas ------------------------
	{
		"id": "arkanoid",
		"title": "Arkanoid",
		"icon": "🧱",
		"category": "arcade",
		"scene": "res://games/arcade/arkanoid/arkanoid.tscn",
		"enabled": true,
	},
	{
		"id": "block_stacker",
		"title": "Bloques",
		"icon": "🟦",
		"category": "arcade",
		"scene": "res://games/arcade/block_stacker/block_stacker.tscn",
		"enabled": true,
	},
	# --- Arcade: disparos espaciales -------------------------------------
	{
		"id": "asteroids",
		"title": "Asteroids",
		"icon": "☄️",
		"category": "arcade",
		"scene": "res://games/arcade/asteroids/asteroids.tscn",
		"enabled": true,
	},
	{
		"id": "galaga_swarm",
		"title": "Enjambre Estelar",
		"icon": "🛸",
		"category": "arcade",
		"scene": "res://games/arcade/galaga_swarm/galaga_swarm.tscn",
		"enabled": true,
	},
	# --- Arcade: laberinto ------------------------------------------------
	{
		"id": "maze_muncher",
		"title": "Caza en el Laberinto",
		"icon": "👻",
		"category": "arcade",
		"scene": "res://games/arcade/maze_muncher/maze_muncher.tscn",
		"enabled": true,
	},
	{
		"id": "bomber_maze",
		"title": "Laberinto de Bombas",
		"icon": "💣",
		"category": "arcade",
		"scene": "res://games/arcade/bomber_maze/bomber_maze.tscn",
		"enabled": true,
	},
	{
		"id": "panic_reveal",
		"title": "Revela el Paisaje",
		"icon": "🏞️",
		"category": "arcade",
		"scene": "res://games/arcade/panic_reveal/panic_reveal.tscn",
		"enabled": true,
	},
	# --- Arcade: acción / correr y disparar -------------------------------
	{
		"id": "snow_brawl",
		"title": "Guerra de Nieve",
		"icon": "❄️",
		"category": "arcade",
		"scene": "res://games/arcade/snow_brawl/snow_brawl.tscn",
		"enabled": true,
	},
	{
		"id": "gunslinger",
		"title": "Pistoleros del Ocaso",
		"icon": "🤠",
		"category": "arcade",
		"scene": "res://games/arcade/gunslinger/gunslinger.tscn",
		"enabled": true,
	},
	# --- Arcade: reflejos --------------------------------------------------
	{
		"id": "topo",
		"title": "Atrapa al Topo",
		"icon": "🐹",
		"category": "arcade",
		"scene": "res://games/arcade/topo/topo.tscn",
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
