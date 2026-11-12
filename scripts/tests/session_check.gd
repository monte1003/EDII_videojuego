extends SceneTree

#Checks the decision tree of rounds, the planner and the lobby; run: godot --headless --path . --script res://scripts/tests/session_check.gd

const ROUNDS := 4

var _failures := 0


func _initialize() -> void:
	_check_tree_sizes()
	_check_no_repeats()
	_check_planner()
	_check_catalog()
	_check_lobby()
	_check_standings()
	print("session_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _pool(count: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for index in count:
		ids.append(StringName("m%d" % index))
	return ids


func _check_tree_sizes() -> void:
	var six := DecisionTree.build(_pool(6), ROUNDS)
	_expect(six.leaf_count() == 6 * 5 * 4 * 3, "6 minijuegos y 4 rondas: 360 recorridos (%d)" % six.leaf_count())
	_expect(six.node_count() == 1 + 6 + 30 + 120 + 360, "6 minijuegos: 517 nodos (%d)" % six.node_count())
	var two := DecisionTree.build(_pool(2), ROUNDS)
	_expect(two.leaf_count() == 2, "2 minijuegos: solo 2 recorridos, alternando (%d)" % two.leaf_count())
	var one := DecisionTree.build(_pool(1), ROUNDS)
	_expect(one.leaf_count() == 1, "1 minijuego: un solo recorrido, se repite sin remedio")
	_expect(DecisionTree.build(_pool(0), ROUNDS).root.children.is_empty(), "sin minijuegos el árbol queda vacío")


func _check_no_repeats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for count in [2, 3, 4, 5, 6]:
		var tree := DecisionTree.build(_pool(count), ROUNDS)
		var consecutive := false
		var repeated := false
		for attempt in 200:
			var path := tree.random_path(rng)
			if path.size() != ROUNDS:
				consecutive = true
			for index in range(1, path.size()):
				consecutive = consecutive or path[index] == path[index - 1]
			var seen: Dictionary = {}
			for id in path:
				repeated = repeated or seen.has(id)
				seen[id] = true
		_expect(not consecutive, "%d minijuegos: nunca el mismo dos rondas seguidas y siempre %d rondas" % [count, ROUNDS])
		if count >= ROUNDS:
			_expect(not repeated, "%d minijuegos: ninguno se repite en la partida" % count)
		else:
			_expect(repeated, "%d minijuegos: con menos que rondas repiten, pero alternando" % count)


func _check_planner() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var plan := RoundPlanner.plan(MinigameCatalog.ready_entries(), ROUNDS, rng)
	_expect(plan.size() == ROUNDS, "el plan tiene %d rondas (%d)" % [ROUNDS, plan.size()])
	var all_known := true
	for id in plan:
		all_known = all_known and MinigameCatalog.find(id) != null
	_expect(all_known, "todo id del plan existe en el catálogo")


func _check_catalog() -> void:
	var ready := MinigameCatalog.ready_entries()
	_expect(ready.size() >= 1 and ready.size() <= MinigameCatalog.PLANNED, "hay entre 1 y %d minijuegos listos (%d)" % [MinigameCatalog.PLANNED, ready.size()])
	var scenes_load := true
	for info in ready:
		scenes_load = scenes_load and load(info.scene_path) is PackedScene
	_expect(scenes_load, "la escena de cada minijuego listo carga")
	_expect(MinigameCatalog.find(&"no_existe") == null, "un id desconocido no devuelve nada")
	_expect(ready.size() == 5, "hay cinco minijuegos listos de los %d previstos" % MinigameCatalog.PLANNED)
	var briefed := true
	var ids: Dictionary = {}
	for info in ready:
		ids[info.id] = true
		briefed = briefed and info.brief != "" and info.brief.split(" ").size() <= 7 and info.keys.size() >= 1 and info.keys.size() <= 3
	_expect(briefed, "cada minijuego trae un objetivo de siete palabras como mucho y de una a tres teclas")
	_expect(ids.size() == ready.size() and ids.has(&"trend_war") and ids.has(&"perfect_selfie"), "ningún id se repite y están los dos minijuegos nuevos")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var seen: Dictionary = {}
	for attempt in 300:
		for id in RoundPlanner.plan(ready, ROUNDS, rng):
			seen[id] = true
	_expect(seen.size() == 5, "en 300 partidas sorteadas salen los cinco minijuegos")
	var tree := DecisionTree.build(_pool(5), ROUNDS)
	_expect(tree.leaf_count() == 5 * 4 * 3 * 2, "con cinco minijuegos el árbol de decisión tiene 120 partidas posibles (%d)" % tree.leaf_count())


func _check_lobby() -> void:
	var lobby := LobbyState.new()
	_expect(not lobby.all_ready() and lobby.free_places() == LobbyState.CAPACITY, "sala vacía: nadie listo y %d plazas libres" % LobbyState.CAPACITY)
	_expect(lobby.join(PlayerSlot.new(1, "A", null)), "entra el jugador 1")
	_expect(not lobby.join(PlayerSlot.new(1, "A otra vez", null)), "el mismo id no ocupa dos plazas")
	_expect(not lobby.all_ready(), "con alguien sin confirmar no están todos listos")
	lobby.set_ready(1, true)
	_expect(lobby.all_ready() and lobby.ready_count() == 1, "con el único jugador listo, todos listos")
	for id in [2, 3, 4]:
		lobby.join(PlayerSlot.new(id, "J%d" % id, null))
	_expect(not lobby.join(PlayerSlot.new(5, "J5", null)) and lobby.slots.size() == LobbyState.CAPACITY, "la plaza %d no existe" % (LobbyState.CAPACITY + 1))
	_expect(not lobby.all_ready() and lobby.free_places() == 0, "sala llena y sin todos listos")
	lobby.set_ready(99, true)
	_expect(lobby.ready_count() == 1, "confirmar un id desconocido no cambia nada")
	lobby.leave(1)
	_expect(lobby.find(1) == null and lobby.free_places() == 1, "al salir se libera la plaza")
	lobby.clear()
	_expect(lobby.slots.is_empty() and not lobby.all_ready(), "al limpiar la sala queda vacía")


#The AVL tree of the standings: a key made of points, tie-break and player id, so ties never lose anybody
func _check_standings() -> void:
	var tree := AVLTree.new()
	for entry: Array in [[2400, 1, 900], [3100, 2, 950], [2400, 3, 700], [2400, 4, 900], [1800, 5, 600], [3100, 6, 990], [500, 7, 300]]:
		tree.insert(entry[0], entry[1], entry[2])
	var order: Array[int] = []
	for node in tree.standings():
		order.append(node.player_id)
	_expect(tree.size() == 7, "siete puntajes con empates: ninguno se pierde (%d)" % tree.size())
	_expect(order == [6, 2, 1, 4, 3, 5, 7], "de mayor a menor: gana el total, luego la mejor ronda y luego el id menor %s" % [order])
	var places := tree.places()
	_expect(places[6] == 1 and places[2] == 2 and places[1] == 3 and places[4] == 3 and places[3] == 5 and places[5] == 6 and places[7] == 7,
		"quien empata en total y mejor ronda comparte puesto, y el siguiente se lo salta")
	var upward: Array[int] = []
	for node in tree.get_inorder_array():
		upward.append(node.points)
	_expect(upward == [500, 1800, 2400, 2400, 2400, 3100, 3100], "el inorden va de menor a mayor %s" % [upward])
	_expect(not tree.insert(2400, 1, 900) and tree.size() == 7, "la misma clave completa no entra dos veces")
	_expect(tree.insert(2400, 1, 901) and tree.size() == 8, "el mismo jugador con otro desempate es otra clave")
	var chain := AVLTree.new()
	for value in 64:
		chain.insert(value * 10, value % 4 + 1, value)
	_expect(chain.is_balanced() and chain.get_height(chain.root) == 7 and chain.rotations > 0,
		"64 puntajes en orden quedan balanceados: altura %d con %d rotaciones" % [chain.get_height(chain.root), chain.rotations])
	var same := AVLTree.new()
	for id in [3, 1, 4, 2]:
		same.insert(1000, id, 500)
	var tied: Array[int] = []
	for node in same.standings():
		tied.append(node.player_id)
	var shared := same.places()
	_expect(tied == [1, 2, 3, 4] and shared[1] == 1 and shared[4] == 1, "cuatro empatados del todo: salen por id y todos son primeros")
	_expect(AVLTree.new().standings().is_empty() and AVLTree.new().places().is_empty(), "un árbol vacío no da posiciones")
