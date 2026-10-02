extends "res://tests/test_base.gd"
## Todos los juegos registrados abren sin errores, el menú se arma, y el
## sonido sintetizado no sale mudo ni saturado.


func run() -> void:
	var gm: Node = tree.root.get_node("GameManager")
	var bad: Array = []
	for g: Dictionary in gm.games:
		if not g["enabled"]:
			continue
		var scene: PackedScene = load(g["scene"])
		if scene == null:
			bad.append(g["id"])
			continue
		var node: Node = await open(g["scene"])
		await tree.process_frame
		node.queue_free()
		await tree.process_frame
	check(bad.is_empty(), "los %d juegos registrados abren (fallaron: %s)" % [gm.games.size(), bad])

	var hub: Node = await open("res://core/scenes/hub.tscn", false)
	for tab: String in ["inicio", "mesa", "arcade"]:
		hub._select_tab(tab)
		await tree.process_frame
	check(hub.content.get_child_count() > 0, "el menú arma sus pestañas")
	hub._toggle_favorite("chess")
	check(tree.root.get_node("SaveManager").get_game_data("_hub").get("favorites", []).has("chess"), "marcar un favorito se guarda")

	var am: Node = tree.root.get_node("AudioManager")
	for f: String in ["play_click", "play_place", "play_error", "play_win", "play_lose", "play_power", "play_alert",
			"play_laser", "play_explosion", "play_jump", "play_coin", "play_pop", "play_hit", "play_kick"]:
		am.call(f)
	var worst := 0.0
	var silent: Array = []
	for k: String in am._cache:
		var peak := _peak(am._cache[k])
		worst = maxf(worst, peak)
		if peak < 0.05:
			silent.append(k)
	check(silent.is_empty() and worst <= 1.0, "efectos: ninguno mudo (%s), pico máximo %d%%" % [silent, int(worst * 100)])
	var song: AudioStreamWAV = await am._build_song("arcade")
	var peak2 := _peak(song)
	check(peak2 > 0.2 and peak2 <= 1.0 and song.loop_mode == AudioStreamWAV.LOOP_FORWARD, "la música se genera en bucle (pico %d%%)" % int(peak2 * 100))


func _peak(st: AudioStreamWAV) -> float:
	var d: PackedByteArray = st.data
	var p := 0
	for i in range(0, d.size(), 2):
		p = maxi(p, absi(d.decode_s16(i)))
	return p / 32767.0
