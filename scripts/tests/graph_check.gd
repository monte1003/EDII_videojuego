extends SceneTree

#Checks the graph and Dijkstra; run headless with --script

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
	_expect(graph.vertices().size() == Level01Layout.POSITIONS.size() and graph.vertices().size() == 40, "40 vértices (%d)" % graph.vertices().size())
	_expect(Level01Layout.build_graph().undirected_edges().size() == Level01Layout.EDGES.size(), "una conexión por puente y por tramo de tobogán")
	var first := graph.shortest_path(Level01Layout.START, &"S")
	_expect(first.found and is_equal_approx(first.cost, 14.0) and first.path == [&"N", &"Ce", &"C1", &"C2", &"C3", &"C4", &"Cx", &"S"],
		"de la salida a la primera plaza lo más barato es Scroll, 14,0 (Comentarios es más corto pero sus hachas cuestan): %s %s" % [first.path, first.cost])
	var second := graph.shortest_path(&"S", Level01Layout.GOAL)
	_expect(second.found and is_equal_approx(second.cost, 16.9) and second.path[1] == &"Bn" and second.path[second.path.size() - 1] == &"M",
		"de la primera plaza a la meta lo más barato es Recarga y Viral, 16,9: %s %s" % [second.path, second.cost])
	var same := graph.shortest_path(&"E", &"E")
	_expect(same.found and same.cost == 0.0 and same.path == [&"E"], "origen igual al destino")
	_expect(is_equal_approx(graph.weight_of(&"C4", &"Cx"), 1.4) and is_equal_approx(graph.weight_of(&"Cx", &"C4"), 3.6),
		"la cinta del scroll cuesta 1,4 a favor (hacia la plaza) y 3,6 en contra: el grafo es dirigido")
	var one_way := true
	for edge in Level01Layout.EDGES:
		if edge[4] == Level01Layout.SLIDE:
			one_way = one_way and not graph.has_edge(edge[1], edge[0])
	_expect(one_way, "los toboganes solo bajan: ninguno se sube")
	#Nine routes from start to goal through the plaza
	var routes := 0
	for way: Array in [[&"A1", &"Ax"], [&"B1", &"B3"], [&"C1", &"Cx"]]:
		for slide: Array in [[&"Bn", &"B8"], [&"h1", &"A8"], [&"z1", &"C8"]]:
			var forbidden: Array[StringName] = []
			for other: StringName in [&"A1", &"B1", &"C1"]:
				if other != way[0]:
					forbidden.append(other)
			var into := graph.shortest_path(Level01Layout.START, way[1], forbidden)
			var across := graph.shortest_path(&"S", slide[0])
			var out := graph.shortest_path(slide[0], slide[1])
			var home := graph.shortest_path(slide[1], Level01Layout.GOAL)
			if into.found and graph.shortest_path(way[1], &"S").found and across.found and out.found and home.found:
				routes += 1
	_expect(routes == 9, "las 9 rutas (3 caminos x 3 toboganes) llevan de la salida a la meta (%d)" % routes)


func _check_block_and_reactivate() -> void:
	var graph := Level01Layout.build_graph(false)
	var version := graph.version
	graph.set_edge_enabled(&"C2", &"C3", false)
	_expect(graph.version > version, "bloquear incrementa la versión del grafo")
	_expect(not graph.is_edge_enabled(&"C2", &"C3") and not graph.is_edge_enabled(&"C3", &"C2"), "C2-C3 queda bloqueada en los dos sentidos")
	_expect(not graph.neighbors(&"C2").has(&"C3") and graph.neighbors(&"C2", true).has(&"C3"), "neighbors omite la conexión bloqueada salvo que se pida")
	graph.set_edge_enabled(&"B1", &"B2", false)
	var detour := graph.shortest_path(Level01Layout.START, &"S")
	_expect(detour.found and is_equal_approx(detour.cost, 14.8) and detour.path[1] == &"Aw",
		"con B1-B2 y C2-C3 cerrados la ruta pasa por Likes, 14,8: %s %s" % [detour.path, detour.cost])
	graph.set_edge_enabled(&"C2", &"C3", true)
	var scroll := graph.shortest_path(Level01Layout.START, &"S")
	_expect(scroll.found and is_equal_approx(scroll.cost, 14.0) and scroll.path[1] == &"Ce", "al reabrir C2-C3 la ruta vuelve a Scroll, 14,0")
	graph.set_edge_enabled(&"B1", &"B2", true)
	var back := graph.shortest_path(Level01Layout.START, &"S")
	_expect(back.found and is_equal_approx(back.cost, 14.0), "al reabrir B1-B2 sigue Scroll, 14,0")


func _check_no_path() -> void:
	var graph := Level01Layout.build_graph(false)
	var closed := graph.shortest_path(&"S", &"M", [&"M"])
	_expect(not closed.found and closed.cost == INF and closed.reason != "", "con M excluida no se llega a M: %s" % closed.reason)
	var up := graph.shortest_path(&"E", &"S")
	_expect(not up.found, "desde la segunda parte no se vuelve a la primera: los toboganes solo bajan")
	for neighbor in [&"B8", &"Ay", &"Cy", &"M"]:
		graph.set_edge_enabled(&"E", neighbor, false)
	var isolated := graph.shortest_path(&"S", &"E")
	_expect(not isolated.found and isolated.path.is_empty(), "E aislada: sin camino (%s)" % isolated.reason)
	var unknown := graph.shortest_path(&"S", &"?")
	_expect(not unknown.found and unknown.reason != "", "vértice desconocido da resultado explícito")
	var start_forbidden := graph.shortest_path(&"M", &"M", [&"M"])
	_expect(start_forbidden.found, "el origen puede estar excluido: solo se prohíbe entrar en excluidos")


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
