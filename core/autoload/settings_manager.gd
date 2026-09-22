extends Node
## Configuración global de la plataforma (volumen, tema, etc.),
## separada del guardado de partidas.

const SETTINGS_FILE := "user://settings.json"

var settings: Dictionary = {
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"reveal_theme": "classic_art", # usado por juegos tipo "revela la imagen"
}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		save_settings()
		return

	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		for key in parsed.keys():
			settings[key] = parsed[key]


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()


func set_value(key: String, value: Variant) -> void:
	settings[key] = value
	save_settings()


func get_value(key: String, default_value: Variant = null) -> Variant:
	return settings.get(key, default_value)
