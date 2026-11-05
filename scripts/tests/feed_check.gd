extends SceneTree

#Checks the tables of level 1, the feed events, the spinners, the turning belts, the rolling balls and the trampolines with no scene; run: godot --headless --path . --script res://scripts/tests/feed_check.gd

var _failures := 0
var _log: Array[String] = []


func _initialize() -> void:
	_check_layout()
	_check_crossings()
	_check_connectivity()
	_check_routes()
	_check_events()
	_check_blocks()
	_check_spinners()
	_check_turns()
	_check_balls()
	_check_pads()
	print("feed_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _check_layout() -> void:
	var graph := Level01Layout.build_graph()
	var fragile := Level01Layout.fragile_edges()
	_expect(fragile.size() == 8, "hay ocho puentes frágiles")
	var disjoint := true
	for edge in fragile:
		var is_block: bool = (edge[0] == Level01Layout.BLOCK_EDGE[0] and edge[1] == Level01Layout.BLOCK_EDGE[1]) \
			or (edge[1] == Level01Layout.BLOCK_EDGE[0] and edge[0] == Level01Layout.BLOCK_EDGE[1])
		disjoint = disjoint and not is_block and graph.has_edge(edge[0], edge[1])
	_expect(disjoint, "los puentes frágiles existen y ninguno es el que cierra Bloquear")
	_expect(Level01Layout.kind_of(&"C", &"G") == Level01Layout.BELT and Level01Layout.kind_of(&"G", &"C") == Level01Layout.BELT, "C-G es una cinta, en los dos sentidos de la pregunta")
	_expect(Level01Layout.kind_of(&"S", &"B") == Level01Layout.WALK and Level01Layout.kind_of(&"S", &"M") == &"", "un puente común es común y uno que no existe no tiene tipo")
	_expect(Level01Layout.kind_of(&"N", &"Q") == Level01Layout.NARROW and Level01Layout.width_of(Level01Layout.NARROW) < Level01Layout.width_of(Level01Layout.WALK),
		"N-Q es un atajo angosto y los angostos miden menos que los comunes")
	var flow := Level01Layout.belt_flow(&"J", &"L")
	var toward_l: Vector3 = (Level01Layout.POSITIONS[&"L"] - Level01Layout.POSITIONS[&"J"])
	toward_l.y = 0.0
	_expect(flow.dot(toward_l.normalized()) > 0.99 and Level01Layout.belt_flow(&"L", &"J") == flow, "la cinta J-L fluye de J hacia L pregunte quien pregunte")
	_expect(Level01Layout.belt_flow(&"S", &"B") == Vector3.ZERO, "un puente común no arrastra")
	var checkpoints_exist := Level01Layout.CHECKPOINTS.size() == 2
	for vertex in Level01Layout.CHECKPOINTS:
		checkpoints_exist = checkpoints_exist and Level01Layout.POSITIONS.has(vertex)
	_expect(Level01Layout.STATIONS.size() == 3 and checkpoints_exist, "tres estaciones y dos checkpoints que existen")
	var climbs := Level01Layout.POSITIONS[Level01Layout.START].y < Level01Layout.POSITIONS[&"S"].y and Level01Layout.POSITIONS[&"S"].y < Level01Layout.POSITIONS[Level01Layout.GOAL].y
	_expect(climbs, "el recorrido sube de la salida a la meta")
	var gentle := true
	for edge in Level01Layout.EDGES:
		var from: Vector3 = Level01Layout.POSITIONS[edge[0]]
		var to: Vector3 = Level01Layout.POSITIONS[edge[1]]
		var run := Vector2(to.x - from.x, to.z - from.z).length() - Level01Layout.radius_of(edge[0]) - Level01Layout.radius_of(edge[1])
		gentle = gentle and absf(to.y - from.y) / run < tan(deg_to_rad(20.0))
	_expect(gentle, "ninguna rampa pasa de 20 grados")
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
	_expect(found.size() >= 4, "hay %d caminos a menos de 2 del mejor: la carrera no tiene un solo camino" % found.size())
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


func _check_blocks() -> void:
	var pusher := Level01Layout.pusher_of(&"W", &"U")
	_expect(not pusher.is_empty() and Level01Layout.pusher_of(&"U", &"W") == pusher, "el puente U-W tiene un bloque, se pregunte en el orden que se pregunte")
	_expect(Level01Layout.pusher_of(&"S", &"B").is_empty(), "un puente sin bloque no lo tiene")
	var start := Level01Hazards.block_center(pusher, 0.0)
	var quarter := Level01Hazards.block_center(pusher, float(pusher["period"]) / 4.0)
	_expect(start.distance_to(quarter) > 0.8, "el bloque cruza el puente de un lado a otro")
	_expect(Level01Hazards.block_hits(pusher, 0.0, start), "quien está dentro del bloque recibe el golpe")
	_expect(not Level01Hazards.block_hits(pusher, 0.0, start + Vector3(0.0, 1.5, 0.0)), "quien salta por encima no lo recibe")
	_expect(not Level01Hazards.block_hits(pusher, 0.0, start + Vector3(0.0, 0.0, 6.0)), "lejos del bloque se está a salvo")
	var heading := Level01Hazards.block_heading(pusher, 0.0)
	_expect(absf(heading.length() - 1.0) < 0.01 and absf(heading.y) < 0.001, "el bloque empuja hacia un lado del puente")
	var coming := Level01Hazards.block_time_to_hit(pusher, 0.0, start + Vector3(0.0, 0.0, 6.0), Vector3.ZERO, 0.0, 2.0)
	_expect(coming == -1.0 or coming >= 0.0, "predecir el golpe de quien espera siempre da un tiempo o -1")


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


func _check_turns() -> void:
	var good := Level01Layout.TURNS.size() == 5
	var swaps := true
	var warns := true
	for turn: Dictionary in Level01Layout.TURNS:
		var edge: Array = turn["edge"]
		var phase: float = turn["phase"]
		var period: float = turn["period"]
		good = good and Level01Layout.kind_of(edge[0], edge[1]) == Level01Layout.BELT and period > Level01Layout.TURN_WARNING * 3.0
		swaps = swaps and Level01Layout.belt_forward(turn, 0.0) and Level01Layout.belt_forward(turn, phase - 0.01)
		swaps = swaps and not Level01Layout.belt_forward(turn, phase + 0.01) and Level01Layout.belt_forward(turn, phase + period + 0.01)
		swaps = swaps and not Level01Layout.belt_forward(turn, phase + 2.0 * period + 0.01)
		var before := Level01Layout.belt_flow(edge[0], edge[1], phase - 0.01)
		var after := Level01Layout.belt_flow(edge[0], edge[1], phase + 0.01)
		swaps = swaps and before.dot(after) < -0.99
		warns = warns and Level01Layout.belt_warning(turn, phase - 1.0) and not Level01Layout.belt_warning(turn, phase - 3.0)
		warns = warns and not Level01Layout.belt_warning(turn, phase + 1.0) and Level01Layout.belt_warning(turn, phase + period - 1.0)
	_expect(good, "las cintas que giran son cintas y su periodo es mucho mayor que el aviso")
	_expect(swaps, "cada cinta fluye al derecho, se invierte en su fase, vuelve a su periodo y su flujo se niega")
	_expect(warns, "las flechas avisan en el segundo y medio antes de cada cambio y no después")
	var graph := Level01Layout.build_graph()
	var version := graph.version
	var edge: Array = [&"J", &"L", 2.5, 5.5, Level01Layout.BELT]
	var flipped := Level01Layout.belt_costs(edge, false)
	_expect(Level01Layout.belt_costs(edge, true) == Vector2(2.5, 5.5) and flipped == Vector2(5.5, 2.5), "al invertirse la cinta los dos costes se intercambian")
	var before := graph.shortest_path(&"J", &"L").cost
	_expect(graph.set_weights(&"J", &"L", flipped.x, flipped.y) and graph.version > version, "cambiar los costes sube la versión del grafo")
	_expect(graph.weight_of(&"J", &"L") == 5.5 and graph.weight_of(&"L", &"J") == 2.5, "J-L ahora cuesta 5,5 y L-J 2,5")
	_expect(graph.shortest_path(&"J", &"L").cost >= before, "ir de J a L cuesta lo mismo o más con la cinta en contra")
	var same := graph.version
	graph.set_weights(&"J", &"L", flipped.x, flipped.y)
	_expect(graph.version == same and not graph.set_weights(&"J", &"M", 1.0, 1.0), "repetir los mismos costes no cambia la versión y un puente que no existe se rechaza")


func _check_balls() -> void:
	var placed := true
	var motion := true
	var hits := true
	var busy := _busy_islands()
	for ball: Dictionary in Level01Layout.BALLS:
		var island: StringName = ball["island"]
		var half := Level01Hazards.ball_half_lane(ball)
		var period: float = ball["period"]
		placed = placed and Level01Layout.POSITIONS.has(island) and not busy.has(island) and half >= 2.0
		placed = placed and half + Level01Layout.BALL_RADIUS <= Level01Layout.radius_of(island)
		#Over one period the ball reaches both ends of its diameter, passes the middle and turns around
		var low := 0.0
		var high := 0.0
		var turns := 0
		var last := Level01Hazards.ball_heading(ball, 0.0)
		var time := 0.0
		while time < period:
			var share := Level01Hazards.ball_share(ball, time)
			low = minf(low, share)
			high = maxf(high, share)
			var heading := Level01Hazards.ball_heading(ball, time)
			if heading.dot(last) < 0.0:
				turns += 1
			last = heading
			time += 0.01
		motion = motion and period >= 3.0 and period <= 8.0 and low < -0.99 and high > 0.99 and turns == 2
		var middle := _middle_time(ball)
		var centre := Level01Hazards.ball_center(ball, middle)
		var floor_y: float = (Level01Layout.POSITIONS[island] as Vector3).y
		var on_floor := centre - Vector3(0.0, Level01Layout.BALL_RADIUS, 0.0)
		hits = hits and Level01Hazards.ball_hits(ball, middle, on_floor, 0.0)
		hits = hits and not Level01Hazards.ball_hits(ball, middle, on_floor, Level01Hazards.BALL_CLEAR + 0.2)
		hits = hits and not Level01Hazards.ball_hits(ball, middle, on_floor + Vector3(3.0, 0.0, 0.0).rotated(Vector3.UP, float(ball["angle"]) + PI / 2.0), 0.0)
		hits = hits and absf(centre.y - floor_y - Level01Layout.BALL_RADIUS) < 0.001
	_expect(placed, "cada bola rueda por una isla sin barra, estación ni checkpoint y su diámetro cabe en la isla")
	_expect(motion, "cada bola va y viene sin parar por su diámetro: llega a los dos extremos y da la vuelta dos veces por periodo")
	_expect(hits, "la bola golpea a quien está en su camino, no a quien salta ni a quien está a un lado")


func _check_pads() -> void:
	var placed := true
	var apart := true
	var launch := true
	var busy := _busy_islands()
	for ball: Dictionary in Level01Layout.BALLS:
		busy.append(ball["island"])
	for id in Level01Layout.PADS:
		placed = placed and Level01Layout.POSITIONS.has(id) and not busy.has(id)
		var centre: Vector3 = Level01Layout.POSITIONS[id]
		var spot := Level01Layout.pad_position(id)
		placed = placed and Vector2(spot.x - centre.x, spot.z - centre.z).length() + 1.5 <= Level01Layout.radius_of(id)
		for edge in Level01Layout.EDGES:
			if edge[0] != id and edge[1] != id:
				continue
			var other: StringName = edge[1] if edge[0] == id else edge[0]
			var toward: Vector3 = Level01Layout.POSITIONS[other] - centre
			var away := spot - centre
			apart = apart and absf(Vector2(toward.x, toward.z).angle_to(Vector2(away.x, away.z))) > 0.5
		launch = launch and Level01Hazards.pad_hits(id, spot) and not Level01Hazards.pad_hits(id, spot + Vector3(2.5, 0.0, 0.0))
		launch = launch and not Level01Hazards.pad_hits(id, spot + Vector3(0.0, 1.5, 0.0))
		launch = launch and absf(Level01Hazards.pad_launch(id, spot + Vector3(0.5, 0.0, 0.0)).y - Level01Hazards.PAD_LIFT) < 0.001
	_expect(placed, "cada trampolín está en una isla sin barra, bola ni estación, a distancia del centro y dentro de la isla")
	_expect(apart, "ningún trampolín queda en la línea de un puente: está en la parte quieta del borde")
	_expect(launch, "el trampolín lanza hacia arriba a quien lo pisa y no a quien está lejos ni a quien ya va por el aire")
	var surge_ok := true
	var surged := 0
	for id: StringName in Level01Layout.SPINNERS:
		var spinner: Dictionary = Level01Layout.SPINNERS[id]
		if not spinner.has("surge"):
			continue
		surged += 1
		var slowest := INF
		var fastest := 0.0
		var time := 0.0
		while time < 40.0:
			var speed := (Level01Hazards.angle_at(spinner, time + 0.05) - Level01Hazards.angle_at(spinner, time)) / 0.05
			surge_ok = surge_ok and speed * float(spinner["speed"]) > 0.0
			slowest = minf(slowest, absf(speed))
			fastest = maxf(fastest, absf(speed))
			time += 0.05
		surge_ok = surge_ok and fastest / slowest > 1.8
	_expect(surged == 3 and surge_ok, "tres barras tienen arranques: nunca se paran ni dan marcha atrás y su velocidad cambia al menos al doble")


#The islands that already have something to do
func _busy_islands() -> Array[StringName]:
	var busy: Array[StringName] = []
	busy.append_array(Level01Layout.SPINNERS.keys())
	busy.append_array(Level01Layout.STATIONS.values())
	busy.append_array(Level01Layout.CHECKPOINTS)
	busy.append_array([Level01Layout.START, Level01Layout.GOAL])
	return busy


#A moment in which the ball passes through the middle of the island
func _middle_time(ball: Dictionary) -> float:
	var time := 0.0
	while absf(Level01Hazards.ball_share(ball, time)) > 0.02:
		time += 0.005
	return time


#No two bridges cross or overlap, and no bridge goes through an island that is not its end: bodies that share a place trap a racer
func _check_crossings() -> void:
	var crossings := 0
	var through := 0
	var tight := 0
	var edges: Array = Level01Layout.EDGES
	for first in edges.size():
		var line_a := _bridge_line(edges[first])
		for second in range(first + 1, edges.size()):
			var shares: bool = edges[first][0] == edges[second][0] or edges[first][0] == edges[second][1] 				or edges[first][1] == edges[second][0] or edges[first][1] == edges[second][1]
			if shares:
				continue
			var line_b := _bridge_line(edges[second])
			if Geometry2D.segment_intersects_segment(line_a[0], line_a[1], line_b[0], line_b[1]) != null:
				crossings += 1
		for id: StringName in Level01Layout.POSITIONS:
			if id == edges[first][0] or id == edges[first][1]:
				continue
			var centre := Vector2(Level01Layout.POSITIONS[id].x, Level01Layout.POSITIONS[id].z)
			var near := Geometry2D.get_closest_point_to_segment(centre, line_a[0], line_a[1])
			if near.distance_to(centre) < Level01Layout.radius_of(id) + Level01Layout.width_of(edges[first][4]) / 2.0 + 0.5:
				through += 1
	for id: StringName in Level01Layout.POSITIONS:
		var centre: Vector3 = Level01Layout.POSITIONS[id]
		var angles: Array[float] = []
		var widths: Array[float] = []
		for edge in edges:
			if edge[0] == id or edge[1] == id:
				var other: Vector3 = Level01Layout.POSITIONS[edge[1] if edge[0] == id else edge[0]]
				angles.append(atan2(other.z - centre.z, other.x - centre.x))
				widths.append(Level01Layout.width_of(edge[4]))
		for a in angles.size():
			for b in range(a + 1, angles.size()):
				var clearance := 2.0 * Level01Layout.radius_of(id) * sin(absf(angle_difference(angles[a], angles[b])) / 2.0)
				if clearance < (widths[a] + widths[b]) / 2.0 + 0.1:
					tight += 1
	_expect(crossings == 0, "ningún puente cruza a otro en planta (%d cruces)" % crossings)
	_expect(through == 0, "ningún puente pasa por una isla que no es la suya (%d)" % through)
	_expect(tight == 0, "los puentes de una isla salen con espacio entre ellos y no se montan (%d pares justos)" % tight)


#The bridge as a segment on the ground, from the rim of one island to the rim of the other
func _bridge_line(edge: Array) -> Array[Vector2]:
	var from: Vector3 = Level01Layout.POSITIONS[edge[0]]
	var to: Vector3 = Level01Layout.POSITIONS[edge[1]]
	var start := Vector2(from.x, from.z)
	var finish := Vector2(to.x, to.z)
	var along := (finish - start).normalized()
	return [start + along * Level01Layout.radius_of(edge[0]), finish - along * Level01Layout.radius_of(edge[1])]
