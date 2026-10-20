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
