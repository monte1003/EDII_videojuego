extends SceneTree

#Checks the graph and Dijkstra; run: godot --headless --path . --script res://scripts/tests/graph_check.gd

var _failures := 0


func _initialize() -> void:
	_check_heap()
	_check_shortest_path()
	_check_block_and_reactivate()
	_check_no_path()
	_check_misc()
	print("graph_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _check_heap() -> void:
	var heap := MinHeap.new()
	for value in [5.0, 1.0, 4.0, 1.0, 3.0, 9.0, 0.5]:
		heap.push(value, value)
	var sorted: Array = []
	while not heap.is_empty():
		sorted.append(heap.pop())
	_expect(sorted == [0.5, 1.0, 1.0, 3.0, 4.0, 5.0, 9.0], "MinHeap saca en orden: %s" % [sorted])


func _check_shortest_path() -> void:
	var graph := Level01Layout.build_graph(false)
	_expect(graph.vertices().size() == Level01Layout.POSITIONS.size() and graph.vertices().size() == 26, "26 vértices")
	_expect(Level01Layout.build_graph().undirected_edges().size() == Level01Layout.EDGES.size(), "una conexión por puente")
	var route := graph.shortest_path(&"B", &"L")
	_expect(route.found and route.cost == 8.5 and route.path == [&"B", &"F", &"J", &"L"],
		"B a L cuesta 8,5 por B-F-J-L: %s %s" % [route.path, route.cost])
	var to_goal := graph.shortest_path(&"S", &"M")
	_expect(to_goal.found and to_goal.cost == 14.0 and to_goal.path.size() == 6 and to_goal.path[0] == &"S" and to_goal.path[5] == &"M",
		"S a M cuesta 14 con 5 puentes: %s" % [to_goal.path])
	var same := graph.shortest_path(&"E", &"E")
	_expect(same.found and same.cost == 0.0 and same.path == [&"E"], "origen igual al destino")
	_expect(graph.weight_of(&"J", &"L") == 2.5 and graph.weight_of(&"L", &"J") == 5.5,
		"la cinta J-L cuesta 2,5 a favor y 5,5 en contra: el grafo es dirigido")
	_expect(graph.shortest_path(&"L", &"J").cost <= 5.5, "volver de L a J nunca cuesta más que la cinta en contra")
	#Without the narrow bridges the course is the long way; with them there are shortcuts
	var shortcut_graph := Level01Layout.build_graph()
	var shortcut := shortcut_graph.shortest_path(&"B", &"L")
	_expect(shortcut.found and shortcut.cost == 7.0 and shortcut.path == [&"B", &"I", &"L"],
		"con los atajos B a L baja a 7 por B-I-L: %s %s" % [shortcut.path, shortcut.cost])
	var whole := shortcut_graph.shortest_path(Level01Layout.START, Level01Layout.GOAL)
	var long_way := graph.shortest_path(Level01Layout.START, Level01Layout.GOAL)
	_expect(whole.found and long_way.found and whole.cost < long_way.cost, "los atajos acortan la carrera entera: %s contra %s" % [whole.cost, long_way.cost])
	_expect(whole.path[0] == &"N" and whole.path[whole.path.size() - 1] == &"M", "la carrera va de la salida N a la meta M")
	var every_shortcut_pays := true
	for edge in Level01Layout.EDGES:
		if edge[4] != Level01Layout.NARROW:
			continue
		var around := graph.shortest_path(edge[0], edge[1])
		every_shortcut_pays = every_shortcut_pays and edge[2] < around.cost
	_expect(every_shortcut_pays, "cada puente angosto cuesta menos que el camino sin él")


func _check_block_and_reactivate() -> void:
	var graph := Level01Layout.build_graph(false)
	var version := graph.version
	graph.set_edge_enabled(&"F", &"J", false)
	_expect(graph.version > version, "bloquear incrementa la versión del grafo")
	_expect(not graph.is_edge_enabled(&"F", &"J") and not graph.is_edge_enabled(&"J", &"F"),
		"F-J queda bloqueada en los dos sentidos")
	_expect(not graph.neighbors(&"F").has(&"J") and graph.neighbors(&"F", true).has(&"J"),
		"neighbors omite la conexión bloqueada salvo que se pida")
	var detour := graph.shortest_path(&"B", &"L")
	_expect(detour.found and detour.cost == 9.5 and detour.path == [&"B", &"F", &"I", &"L"],
		"con F-J bloqueada, B a L cuesta 9,5 por B-F-I-L: %s %s" % [detour.path, detour.cost])
	graph.set_edge_enabled(&"F", &"J", true)
	var back := graph.shortest_path(&"B", &"L")
	_expect(back.found and back.cost == 8.5 and back.path == [&"B", &"F", &"J", &"L"],
		"al reactivar F-J vuelve el costo 8,5")


func _check_no_path() -> void:
	var graph := Level01Layout.build_graph(false)
	var closed := graph.shortest_path(&"S", &"M", Level01Layout.BOT_FORBIDDEN)
	_expect(not closed.found and closed.cost == INF and closed.reason != "",
		"los bots no pueden llegar a M: %s" % closed.reason)
	for neighbor in [&"I", &"J", &"K", &"M"]:
		graph.set_edge_enabled(&"L", neighbor, false)
	var isolated := graph.shortest_path(&"B", &"L")
	_expect(not isolated.found and isolated.path.is_empty(), "L aislada: sin camino (%s)" % isolated.reason)
	var unknown := graph.shortest_path(&"B", &"?")
	_expect(not unknown.found and unknown.reason != "", "vértice desconocido da resultado explícito")
	var start_forbidden := graph.shortest_path(&"M", &"H", [&"M"])
	_expect(start_forbidden.found, "el origen puede estar excluido: solo se prohíbe entrar en excluidos")
	var via_k := graph.shortest_path(&"M", &"H", [])
	_expect(via_k.found and via_k.path == [&"M", &"K", &"H"], "M llega a H por K si L está aislada: %s" % [via_k.path])


func _check_misc() -> void:
	var graph := WeightedGraph.new()
	graph.add_vertex(&"X")
	graph.add_vertex(&"Y")
	_expect(not graph.add_vertex(&"X"), "vértice repetido rechazado")
	graph.add_edge(&"X", &"Y", 4.0, false)
	_expect(graph.is_edge_enabled(&"X", &"Y") and not graph.has_edge(&"Y", &"X"), "arista dirigida")
	_expect(not graph.shortest_path(&"Y", &"X").found, "una arista dirigida no se recorre al revés")
	graph.add_edge(&"X", &"Y", 1.5, false)
	_expect(graph.weight_of(&"X", &"Y") == 1.5, "volver a agregar actualiza el peso")
