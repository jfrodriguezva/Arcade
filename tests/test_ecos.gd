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
	for lv in range(SOL.size()):
		g.level_idx = lv
		g._load_level()
		var log: Array = []
		for att: Array in SOL[lv]:
			var r: String = play_attempt(g, att)
			log.append(r)
			if r == "failed":
				await wait(1.2)
		check(g.state in ["won", "replay"], "nivel %d (%s) resuelto con %d eco(s): %s" % [lv + 1, g.LEVELS[lv]["name"], g.ecos.size(), log])
