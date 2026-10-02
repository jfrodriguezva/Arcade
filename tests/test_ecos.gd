extends "res://tests/test_base.gd"
## Ecos: cada nivel se puede resolver con su número de ecos. Las soluciones
## son listas de intentos; cada paso es una casilla a la cual ir, un número
## (esperar esos segundos), "tX" (esperar a que el ciclo llegue a X s) o
## "end" (terminar el intento ahí).

const SOL := [
	[[Vector2i(8, 2), "end"], [Vector2i(5, 2), Vector2i(5, 4), Vector2i(5, 6)]],
	[[Vector2i(1, 1), "end"], [Vector2i(9, 1), "end"], [Vector2i(5, 2), Vector2i(5, 6)]],
	[[Vector2i(1, 4), Vector2i(4, 4), "t3.05", Vector2i(5, 4), "end"], [Vector2i(1, 4), Vector2i(4, 4), "t3.6", Vector2i(5, 4), Vector2i(5, 9)]],
	[[Vector2i(4, 1), "end"], [Vector2i(4, 2), Vector2i(5, 2), Vector2i(5, 4), Vector2i(2, 4), "end"], [Vector2i(5, 1), Vector2i(5, 7)]],
	[[Vector2i(9, 1), Vector2i(9, 3), "end"], [4.5, Vector2i(1, 7), Vector2i(5, 7), Vector2i(5, 8)]],
	[[Vector2i(1, 4), Vector2i(4, 4), "t3.05", Vector2i(5, 4), "end"], [Vector2i(1, 4), Vector2i(4, 4), "t3.6", Vector2i(5, 4), Vector2i(5, 6), "t6.0", Vector2i(5, 7), Vector2i(8, 7), "end"], [Vector2i(1, 4), Vector2i(4, 4), "t3.6", Vector2i(5, 4), Vector2i(5, 6), "t7.2", Vector2i(5, 7), Vector2i(8, 7), Vector2i(8, 9)]],
	[[Vector2i(9, 1), "end"], [Vector2i(1, 4), Vector2i(4, 4), "t3.05", Vector2i(5, 4), "end"], [Vector2i(1, 4), Vector2i(4, 4), "t3.6", Vector2i(5, 4), Vector2i(5, 8)]],
	[[Vector2i(3, 1), Vector2i(3, 2), "end"], [Vector2i(9, 1), "end"], [1.5, Vector2i(1, 5), Vector2i(4, 5), Vector2i(4, 7)]],
	[[Vector2i(1, 1), "end"], [Vector2i(9, 1), "end"], [Vector2i(5, 2), "end"], [Vector2i(5, 8)]],
	[[Vector2i(1, 1), "end"], [Vector2i(9, 1), "end"], [Vector2i(1, 2), Vector2i(1, 4), Vector2i(4, 4), "t3.05", Vector2i(5, 4), "end"], [Vector2i(5, 2), Vector2i(9, 2), Vector2i(9, 4), Vector2i(6, 4), "t3.6", Vector2i(5, 4), Vector2i(5, 9)]],
	# 11-20
	[[Vector2i(1, 1), "end"], [Vector2i(9, 1), "end"], [3.0, Vector2i(5, 8)]],
	[[Vector2i(1, 4), Vector2i(4, 4), "t3.05", Vector2i(5, 4), Vector2i(5, 5), "end"], [Vector2i(1, 4), Vector2i(4, 4), "t3.05", Vector2i(5, 4), Vector2i(5, 9)]],
	[[Vector2i(1, 4), "t3.0", Vector2i(1, 5), "end"], [Vector2i(9, 1), Vector2i(9, 4), "t3.0", Vector2i(9, 5), "end"], [Vector2i(1, 4), "t3.4", Vector2i(1, 5), Vector2i(5, 5), Vector2i(5, 7)]],
	[[Vector2i(5, 1), "end"], [Vector2i(5, 1), "end"], [4.0, Vector2i(1, 2), Vector2i(5, 2), Vector2i(5, 4), Vector2i(9, 4), Vector2i(9, 8)]],
	[[Vector2i(9, 1), "end"], [Vector2i(9, 1), "end"], [3.0, Vector2i(1, 4), Vector2i(5, 4), Vector2i(5, 6)]],
	[[Vector2i(9, 1), "end"], [Vector2i(5, 4), Vector2i(1, 4), "end"], [Vector2i(5, 4), Vector2i(9, 4), "end"], [Vector2i(5, 9)]],
	[[Vector2i(1, 5), Vector2i(4, 5), "t3.05", Vector2i(5, 5), "end"], [Vector2i(1, 5), Vector2i(4, 5), "t3.2", Vector2i(5, 5), Vector2i(5, 9)]],
	[[Vector2i(9, 1), "end"], [Vector2i(1, 4), "t3.0", Vector2i(1, 5), "end"], [Vector2i(1, 2), Vector2i(9, 2), Vector2i(9, 4), "t3.0", Vector2i(9, 5), "end"], [Vector2i(1, 4), "t3.4", Vector2i(1, 5), Vector2i(5, 5), Vector2i(5, 8)]],
	[[0.2, "end"], [0.2, "end"], [3.5, Vector2i(1, 5), "end"], [5.0, Vector2i(1, 4), Vector2i(9, 4), Vector2i(9, 7)]],
	[[0.2, "end"], [2.5, Vector2i(8, 1), Vector2i(8, 2), "end"], [2.5, Vector2i(1, 5), Vector2i(4, 5), "t6.05", Vector2i(5, 5), "end"], [2.5, Vector2i(1, 5), Vector2i(4, 5), "t6.2", Vector2i(5, 5), Vector2i(5, 9)]],
]


## Ejecuta un intento con el "dedo" programado. Devuelve cómo terminó.
static func play_attempt(g: Node, steps: Array) -> String:
	var i := 0
	var wait_t := 0.0
	var n0: int = g.ecos.size()
	for frame in range(60 * 20):
		if g.state == "won" or g.state == "replay":
			return "won"
		if g.state == "failed":
			return "failed"
		if g.ecos.size() != n0 or (g.tick == 0 and frame > 5):
			return "loop_end"
		var d := Vector2.ZERO
		if i < steps.size():
			var st = steps[i]
			if st is String and st.begins_with("t"):
				if g.tick * g.TICK >= float(st.substr(1)):
					i += 1
			elif st is String:
				g._end_attempt()
				return "ended"
			elif st is float:
				wait_t += 1.0 / 60.0
				if wait_t >= st:
					i += 1
					wait_t = 0.0
			else:
				var v: Vector2 = g._center(st) - g.player
				if v.length() < 3.0:
					i += 1
				else:
					d = v.normalized()
		g.scripted_dir = d
		g.acc = 1.0 / 60.0
		g._process(0.0)
	return "timeout"


func run() -> void:
	var g: Node = await open("res://games/arcade/ecos/ecos.tscn")
	var g2: Node = await open("res://games/arcade/ecos/ecos.tscn")
	for lv in range(SOL.size()):
		g.level_idx = lv
		g._load_level()
		var log: Array = []
		for att: Array in SOL[lv]:
			var r: String = play_attempt(g, att)
			log.append(r if r != "failed" else "failed: " + g.flash)
			if r == "failed":
				await wait(1.2)
		check(g.state in ["won", "replay"], "nivel %d (%s) resuelto con %d eco(s): %s" % [lv + 1, g.LEVELS[lv]["name"], g.ecos.size(), log])
		# El enlace para compartir reproduce la misma solución en otro juego.
		var info: Dictionary = g.decode_solution(g.solution_code)
		var ok: bool = not info.is_empty() and info["level"] == lv and g2.simulate_solution(info)
		check(ok and g2.ecos.size() == g.ecos.size(), "   y su enlace (%d letras) se vuelve a jugar igual" % g.solution_code.length())
	check(g.decode_solution("hola!").is_empty() and g.decode_solution("AAAA").is_empty(), "un enlace roto no abre nada")
	var days := {}
	for d in ["2026-10-02", "2026-10-03", "2026-10-04", "2026-12-31", "2027-01-01"]:
		var lvd: int = g.daily_level(d)
		days[lvd] = true
		if lvd < 2 or lvd >= g.LEVELS.size():
			days = {}
			break
	check(days.size() >= 3 and g.daily_level("2026-10-02") == g.daily_level("2026-10-02"), "reto del día: cambia por fecha y siempre da un nivel válido")
	check(g._day_before("2026-03-01") == "2026-02-28" and g._day_before("2027-01-01") == "2026-12-31", "reto del día: la racha cuenta bien el día anterior")

	# Racha: ayer jugado -> hoy suma uno.
	var stats: Dictionary = tree.root.get_node("SaveManager").get_game_data("ecos")
	stats["streak"] = 4
	stats["streak_last"] = g._day_before(g._today())
	g._start_daily()
	check(g.mode == "daily" and g.level_idx == g.daily_level(g._today()), "reto del día: abre el nivel de hoy")
	g._record_daily(stats, 2, 7.5)
	check(int(stats["streak"]) == 5 and stats["daily"]["ecos"] == 2, "reto del día: resolverlo sube la racha (4 -> 5) y guarda el récord")

	# Abrir un enlace: aparece la pregunta y "Ver la solución" la repite.
	g.level_idx = 0
	g._load_level()
	play_attempt(g, SOL[0][0])
	play_attempt(g, SOL[0][1])
	tree.root.get_node("GameManager").pending_ecos = g.solution_code
	var g3: Node = await open("res://games/arcade/ecos/ecos.tscn")
	var see: Button = null
	for b in g3.find_children("*", "Button", true, false):
		if b.text.contains("Ver la solución"):
			see = b
	check(see != null and tree.root.get_node("GameManager").pending_ecos == "", "enlace: pregunta si ver la solución o intentarlo")
	if see:
		see.pressed.emit()
		check(g3.mode == "shared" and g3.state == "replay" and g3.ecos.size() == 1, "enlace: se ve la repetición de la solución")

