extends SceneTree

#Checks the tables of level 1, the feed events and the spinners with no scene; run: godot --headless --path . --script res://scripts/tests/feed_check.gd

var _failures := 0
var _log: Array[String] = []


func _initialize() -> void:
	_check_layout()
	_check_connectivity()
	_check_routes()
	_check_events()
	_check_spinners()
	print("feed_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _check_layout() -> void:
	var graph := Level01Layout.build_graph()
	var fragile := Level01Layout.fragile_edges()
	_expect(fragile.size() == 4, "hay cuatro puentes frágiles")
	var disjoint := true
	for edge in fragile:
		var is_block: bool = (edge[0] == Level01Layout.BLOCK_EDGE[0] and edge[1] == Level01Layout.BLOCK_EDGE[1]) \
			or (edge[1] == Level01Layout.BLOCK_EDGE[0] and edge[0] == Level01Layout.BLOCK_EDGE[1])
		disjoint = disjoint and not is_block and graph.has_edge(edge[0], edge[1])
	_expect(disjoint, "los puentes frágiles existen y ninguno es el que cierra Bloquear")
	_expect(Level01Layout.kind_of(&"C", &"G") == Level01Layout.BELT and Level01Layout.kind_of(&"G", &"C") == Level01Layout.BELT, "C-G es una cinta, en los dos sentidos de la pregunta")
	_expect(Level01Layout.kind_of(&"S", &"B") == Level01Layout.WALK and Level01Layout.kind_of(&"S", &"Z") == &"", "un puente común es común y uno que no existe no tiene tipo")
	var flow := Level01Layout.belt_flow(&"J", &"L")
	var toward_l: Vector3 = (Level01Layout.POSITIONS[&"L"] - Level01Layout.POSITIONS[&"J"])
	toward_l.y = 0.0
	_expect(flow.dot(toward_l.normalized()) > 0.99 and Level01Layout.belt_flow(&"L", &"J") == flow, "la cinta J-L fluye de J hacia L pregunte quien pregunte")
	_expect(Level01Layout.belt_flow(&"S", &"B") == Vector3.ZERO, "un puente común no arrastra")
	_expect(Level01Layout.STATIONS.size() == 3 and Level01Layout.POSITIONS.has(Level01Layout.CHECKPOINT), "tres estaciones y un checkpoint que existe")
	var apart := true
	for id: StringName in Level01Layout.POSITIONS:
		for other: StringName in Level01Layout.POSITIONS:
			if id == other:
				continue
			var gap: float = Level01Layout.POSITIONS[id].distance_to(Level01Layout.POSITIONS[other]) \
				- Level01Layout.radius_of(id) - Level01Layout.radius_of(other)
			if gap < 3.0:
				apart = false
	_expect(apart, "ninguna isla toca a otra: queda espacio para un puente")


func _check_connectivity() -> void:
	var always := true
	for edge in Level01Layout.fragile_edges():
		var graph := Level01Layout.build_graph()
		graph.set_edge_enabled(edge[0], edge[1], false)
		always = always and graph.shortest_path(Level01Layout.START, Level01Layout.GOAL).found
		#With Bloquear working at the same time, the way to the goal still exists
		graph.set_edge_enabled(Level01Layout.BLOCK_EDGE[0], Level01Layout.BLOCK_EDGE[1], false)
		always = always and graph.shortest_path(Level01Layout.START, Level01Layout.GOAL).found
	_expect(always, "con cualquier puente frágil caído, y con Bloquear a la vez, la salida sigue llegando a la meta")
	var graph := Level01Layout.build_graph()
	var from_every_vertex := true
	for id: StringName in Level01Layout.POSITIONS:
		from_every_vertex = from_every_vertex and graph.shortest_path(id, Level01Layout.GOAL).found
	_expect(from_every_vertex, "desde cualquier isla se llega a la meta")


#Simple routes from the start to the goal that cost at most "slack" more than the best one
func _check_routes() -> void:
	var graph := Level01Layout.build_graph()
	var best := graph.shortest_path(Level01Layout.START, Level01Layout.GOAL).cost
	var found: Array[Array] = []
	_walk(graph, Level01Layout.START, [Level01Layout.START], 0.0, best + 2.0, found)
	_expect(found.size() >= 6, "hay %d caminos a menos de 2 del mejor: la carrera no tiene un solo camino" % found.size())
	var first_edges := {}
	for route in found:
		first_edges[route[2]] = true
	_expect(first_edges.size() >= 2, "los caminos buenos se reparten por más de una isla del segundo piso")


func _walk(graph: WeightedGraph, at: StringName, path: Array, cost: float, limit: float, found: Array[Array]) -> void:
	if cost > limit:
		return
	if at == Level01Layout.GOAL:
		found.append(path.duplicate())
		return
	for next in graph.neighbors(at):
		if path.has(next):
			continue
		path.append(next)
		_walk(graph, next, path, cost + graph.weight_of(at, next), limit, found)
		path.pop_back()


func _check_events() -> void:
	var settings := Level01Settings.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var events := Level01Events.new(settings, rng, Level01Layout.fragile_edges())
	_log.clear()
	events.warned.connect(func(a: StringName, b: StringName, seconds: float) -> void: _log.append("aviso %s-%s %.0f" % [a, b, seconds]))
	events.closed.connect(func(a: StringName, b: StringName) -> void: _log.append("cae %s-%s" % [a, b]))
	events.reopened.connect(func(a: StringName, b: StringName) -> void: _log.append("vuelve %s-%s" % [a, b]))
	var always := func(_a: StringName, _b: StringName) -> bool: return true
	var never := func(_a: StringName, _b: StringName) -> bool: return false
	for step in int((settings.feed_first - 0.5) / 0.1):
		events.tick(0.1, always)
	_expect(_log.is_empty(), "antes del primer aviso el feed no cambia nada")
	for step in 10:
		events.tick(0.1, never)
	_expect(_log.is_empty(), "si ningún puente se puede tumbar, no hay aviso")
	for step in 30:
		events.tick(0.1, always)
	_expect(_log.size() == 1 and _log[0].begins_with("aviso") and events.phase == Level01Events.Phase.WARNING, "pasado el tiempo avisa de un puente: %s" % [_log])
	var edge: Array[StringName] = events.edge.duplicate()
	_expect(not events.is_down(edge[0], edge[1]), "mientras parpadea el puente todavía no cayó")
	for step in int(settings.feed_warning / 0.1) + 2:
		events.tick(0.1, always)
	_expect(_log.size() == 2 and _log[1] == "cae %s-%s" % [edge[0], edge[1]] and events.is_down(edge[1], edge[0]),
		"tras el aviso cae el mismo puente: %s" % [_log])
	for step in int(settings.feed_duration / 0.1) + 2:
		events.tick(0.1, always)
	_expect(_log.size() == 3 and _log[2] == "vuelve %s-%s" % [edge[0], edge[1]] and events.edge.is_empty() and not events.is_down(edge[0], edge[1]),
		"pasado el tiempo el puente vuelve: %s" % [_log])
	var only_one := {}
	for step in 4000:
		events.tick(0.1, always)
		if events.phase != Level01Events.Phase.WAITING:
			only_one[events.edge[0] + events.edge[1]] = true
	_expect(only_one.size() >= 3, "con el tiempo el feed tumba puentes distintos: %d" % only_one.size())


func _check_spinners() -> void:
	var spinner: Dictionary = {"arm": 4.4, "speed": 1.3, "phase": 0.0}
	var centre := Vector3(10.0, 0.0, -20.0)
	var along := centre + Vector3(3.0, 0.0, 0.0)
	var across := centre + Vector3(0.0, 0.0, 3.0)
	_expect(Level01Hazards.hits(centre, spinner, 0.0, along, 0.0), "la barra al empezar apunta al este y toca a quien está en ese lado")
	_expect(not Level01Hazards.hits(centre, spinner, 0.0, across, 0.0), "no toca a quien está a 3 m de lado")
	_expect(not Level01Hazards.hits(centre, spinner, 0.0, along, 1.0), "quien salta por encima no recibe el golpe")
	var quarter := (PI / 2.0) / 1.3
	_expect(Level01Hazards.hits(centre, spinner, quarter, across, 0.0), "un cuarto de vuelta después la barra apunta al sur y toca ese lado")
	_expect(Level01Hazards.hits(centre, spinner, 0.0, centre - Vector3(3.0, 0.0, 0.0), 0.0), "la barra cruza la isla entera: también toca el lado opuesto")
	_expect(not Level01Hazards.hits(centre, spinner, 0.0, centre + Vector3(5.6, 0.0, 0.0), 0.0), "más allá de la punta de la barra se está a salvo")
	var push := Level01Hazards.push_direction(centre, spinner, along)
	_expect(push.dot(Vector3.RIGHT) > 0.5 and absf(push.length() - 1.0) < 0.01, "el golpe lanza hacia fuera y a lo largo del giro")
	_expect(Level01Hazards.time_to_hit(centre, spinner, 0.0, along, 0.5) == 0.0, "quien ya está en la barra recibe el golpe de inmediato")
	var coming := Level01Hazards.time_to_hit(centre, spinner, 0.0, across, 2.0)
	_expect(coming > 0.9 and coming < 1.3, "el tiempo hasta el golpe de quien espera de lado ronda lo que tarda un cuarto de vuelta: %.2f" % coming)
	_expect(Level01Hazards.time_to_hit(centre, spinner, 0.0, across, 0.3) == -1.0, "si no llega dentro del plazo, devuelve -1")
	_expect(Level01Hazards.angle_at(Level01Layout.SPINNERS[&"G"], 1.0) < Level01Layout.SPINNERS[&"G"]["phase"],
		"la barra de la isla G gira al revés que la de la isla E")
