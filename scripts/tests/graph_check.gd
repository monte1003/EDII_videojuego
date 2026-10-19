extends SceneTree

#Checks of the graph and Dijkstra against the costs of the design guide.
#Run: godot --headless --path <project> --script res://scripts/tests/graph_check.gd

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
	var graph := Level01Layout.build_graph()
	_expect(graph.vertices().size() == 12, "12 vértices")
	_expect(graph.undirected_edges().size() == Level01Layout.EDGES.size(), "una conexión por puente")
	var route := graph.shortest_path(&"B", &"J")
	_expect(route.found and route.cost == 6.0 and route.path == [&"B", &"E", &"H", &"J"],
		"B a J cuesta 6 por B-E-H-J: %s %s" % [route.path, route.cost])
	var to_goal := graph.shortest_path(&"S", &"M")
	_expect(to_goal.found and to_goal.cost == 10.0, "S a M cuesta 10: %s" % [to_goal.path])
	var same := graph.shortest_path(&"E", &"E")
	_expect(same.found and same.cost == 0.0 and same.path == [&"E"], "origen igual al destino")


func _check_block_and_reactivate() -> void:
	var graph := Level01Layout.build_graph()
	var version := graph.version
	graph.set_edge_enabled(&"E", &"H", false)
	_expect(graph.version > version, "bloquear incrementa la versión del grafo")
	_expect(not graph.is_edge_enabled(&"E", &"H") and not graph.is_edge_enabled(&"H", &"E"),
		"E-H queda bloqueada en los dos sentidos")
	_expect(not graph.neighbors(&"E").has(&"H") and graph.neighbors(&"E", true).has(&"H"),
		"neighbors omite la conexión bloqueada salvo que se pida")
	var detour := graph.shortest_path(&"B", &"J")
	_expect(detour.found and detour.cost == 11.0 and detour.path == [&"B", &"E", &"D", &"G", &"J"],
		"con E-H bloqueada, B a J cuesta 11 por B-E-D-G-J: %s %s" % [detour.path, detour.cost])
	graph.set_edge_enabled(&"E", &"H", true)
	var back := graph.shortest_path(&"B", &"J")
	_expect(back.found and back.cost == 6.0 and back.path == [&"B", &"E", &"H", &"J"],
		"al reactivar E-H vuelve el costo 6")


func _check_no_path() -> void:
	var graph := Level01Layout.build_graph()
	var closed := graph.shortest_path(&"S", &"M", Level01Layout.BOT_FORBIDDEN)
	_expect(not closed.found and closed.cost == INF and closed.reason != "",
		"los bots no pueden llegar a M: %s" % closed.reason)
	for neighbor in [&"G", &"H", &"M"]:
		graph.set_edge_enabled(&"J", neighbor, false)
	var isolated := graph.shortest_path(&"B", &"J")
	_expect(not isolated.found and isolated.path.is_empty(), "J aislada: sin camino (%s)" % isolated.reason)
	var unknown := graph.shortest_path(&"B", &"Z")
	_expect(not unknown.found and unknown.reason != "", "vértice desconocido da resultado explícito")
	var start_forbidden := graph.shortest_path(&"M", &"H", [&"M"])
	_expect(start_forbidden.found, "el origen puede estar excluido: solo se prohíbe entrar en excluidos")
	var via_i := graph.shortest_path(&"M", &"H", [])
	_expect(via_i.found and via_i.path == [&"M", &"I", &"H"], "M llega a H por I si J está aislada: %s" % [via_i.path])


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
