extends RefCounted
## Base de las pruebas: cada archivo test_*.gd hace `extends "res://tests/test_base.gd"`
## y define `func run() -> void` (puede usar await).

var tree: SceneTree
var passed: int = 0
var failed: int = 0
var _nodes: Array = []


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  OK    " + msg)
	else:
		failed += 1
		print("  FALLA " + msg)


## Abre la escena de un juego (sin la guía de gestos de la primera vez) y
## detiene su _process para que la prueba avance el tiempo a mano.
func open(path: String, stop_process: bool = true) -> Node:
	var hub: Dictionary = tree.root.get_node("SaveManager").get_game_data("_hub")
	hub["hints_seen"] = ["galaga_swarm", "invasion_espacial", "asteroids", "block_stacker", "bomber_maze", "maze_muncher",
		"snow_brawl", "arkanoid", "panic_reveal", "burbujas", "dino_runner", "ecos", "dulce_fiesta"]
	var node: Node = load(path).instantiate()
	tree.root.add_child(node)
	_nodes.append(node)
	await tree.process_frame
	await tree.process_frame
	tree.paused = false
	if stop_process:
		node.set_process(false)
	return node


## Avanza un juego `secs` segundos a 60 cuadros por segundo.
func advance(node: Node, secs: float, each_frame: Callable = Callable()) -> void:
	for i in range(int(secs * 60)):
		if each_frame.is_valid():
			each_frame.call(i)
		node._process(1.0 / 60.0)


func wait(secs: float) -> void:
	await tree.create_timer(secs).timeout


func cleanup() -> void:
	for n in _nodes:  # sin tipo: algunos juegos ya se liberaron solos
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	tree.paused = false
	await tree.process_frame
