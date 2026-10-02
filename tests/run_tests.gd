extends SceneTree
## Corre todas las pruebas automáticas del proyecto (tests/test_*.gd).
##
##   godot --headless --path . -s tests/run_tests.gd
##   godot --headless --path . -s tests/run_tests.gd -- damas ecos   (solo esas)
##
## Cada prueba juega o revisa un juego por su cuenta y reporta OK / FALLA.
## Antes de empezar se respaldan el guardado y la configuración del usuario
## (user://) y al final se restauran tal cual: las pruebas nunca deben
## borrar récords ni progreso de nadie.

const BACKUP_FILES := ["user://saves/profile.json", "user://settings.json"]

var _backup: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_backup_user_data()
	var filters: PackedStringArray = OS.get_cmdline_user_args()
	var files: Array = []
	for f: String in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_base.gd":
			if filters.is_empty() or Array(filters).any(func(x: String) -> bool: return f.contains(x)):
				files.append(f)
	files.sort()
	var total_ok := 0
	var total_fail := 0
	var failed_files: Array = []
	var t0 := Time.get_ticks_msec()
	for f: String in files:
		print("\n▶ %s" % f)
		var test = load("res://tests/" + f).new()
		test.tree = self
		var start := Time.get_ticks_msec()
		await test.run()
		await test.cleanup()
		paused = false
		print("  (%d OK, %d fallas, %.1f s)" % [test.passed, test.failed, (Time.get_ticks_msec() - start) / 1000.0])
		total_ok += test.passed
		total_fail += test.failed
		if test.failed > 0:
			failed_files.append(f)
	_restore_user_data()
	print("\n==============================")
	print("RESULTADO: %d OK, %d fallas en %d archivos (%.0f s)" % [total_ok, total_fail, files.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	if not failed_files.is_empty():
		print("Fallaron: ", ", ".join(failed_files))
	quit(1 if total_fail > 0 else 0)


func _backup_user_data() -> void:
	for p: String in BACKUP_FILES:
		_backup[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	# Las pruebas arrancan con datos vacíos (y en memoria).
	root.get_node("SaveManager").data = {"games": {}}


func _restore_user_data() -> void:
	for p: String in BACKUP_FILES:
		if _backup[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
		else:
			var file := FileAccess.open(p, FileAccess.WRITE)
			file.store_string(_backup[p])
			file.close()
	root.get_node("SaveManager").load_data()
	root.get_node("SettingsManager").load_settings()
	print("\n(guardado y configuración del usuario restaurados)")
