extends Node
## Guardado local en JSON. Cada juego tiene su propio bloque de datos
## bajo data["games"][game_id], para no pisarse entre sí.

const SAVE_DIR := "user://saves/"
const SAVE_FILE := SAVE_DIR + "profile.json"

var data: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		data = {"games": {}}
		return

	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	data = parsed if parsed is Dictionary else {"games": {}}
	if not data.has("games"):
		data["games"] = {}


func save_data() -> void:
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func get_game_data(game_id: String) -> Dictionary:
	if not data["games"].has(game_id):
		data["games"][game_id] = {}
	return data["games"][game_id]


func set_game_data(game_id: String, value: Dictionary) -> void:
	data["games"][game_id] = value
	save_data()
