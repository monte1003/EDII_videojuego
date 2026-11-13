extends SceneTree

#Checks the tables of level 1, the feed events, the spinners, the turning belts, the slides, the cannons, the rolling balls and the trampolines with no scene;
#run: godot --headless --path . --script res://scripts/tests/feed_check.gd

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
	_check_slides()
	_check_cannons()
	_check_lanes()
	_check_comments()
	_check_decks()
	_check_hops()
	_check_deck_floors()
	print("feed_check:%s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _check_layout() -> void:
	var graph := Level01Layout.build_graph()
	var fragile := Level01Layout.fragile_edges()
	_expect(fragile.size() == 5, "hay cinco puentes frágiles")
	var disjoint := true
	for edge in fragile:
		var is_block: bool = (edge[0] == Level01Layout.BLOCK_EDGE[0] and edge[1] == Level01Layout.BLOCK_EDGE[1]) \
			or (edge[1] == Level01Layout.BLOCK_EDGE[0] and edge[0] == Level01Layout.BLOCK_EDGE[1])
		disjoint = disjoint and not is_block and graph.has_edge(edge[0], edge[1])
	_expect(disjoint, "los puentes frágiles existen y ninguno es el que cierra Bloquear")
	_expect(Level01Layout.kind_of(&"I", &"E") == Level01Layout.BELT and Level01Layout.kind_of(&"E", &"I") == Level01Layout.BELT, "I-E es una cinta, en los dos sentidos de la pregunta")
	_expect(Level01Layout.kind_of(&"U", &"X") == Level01Layout.SLIDE and Level01Layout.kind_of(&"X", &"U") == Level01Layout.SLIDE, "U-X es un tobogán, en los dos sentidos de la pregunta")
	_expect(Level01Layout.kind_of(&"S", &"B") == Level01Layout.WALK and Level01Layout.kind_of(&"S", &"M") == &"", "un puente común es común y uno que no existe no tiene tipo")
	_expect(Level01Layout.kind_of(&"N", &"Q") == Level01Layout.NARROW and Level01Layout.width_of(Level01Layout.NARROW) < Level01Layout.width_of(Level01Layout.WALK),
		"N-Q es un atajo angosto y los angostos miden menos que los comunes")
	var flow := Level01Layout.belt_flow(&"I", &"E")
	var toward_e: Vector3 = (Level01Layout.POSITIONS[&"E"] - Level01Layout.POSITIONS[&"I"])
	toward_e.y = 0.0
	_expect(flow.dot(toward_e.normalized()) > 0.99 and Level01Layout.belt_flow(&"E", &"I") == flow, "la cinta I-E fluye de I hacia E pregunte quien pregunte")
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
	_expect(Level01Hazards.angle_at(Level01Layout.SPINNERS[&"X"], 1.0) < Level01Layout.SPINNERS[&"X"]["phase"],
		"la barra de la isla X gira al revés que la de la isla E")


func _check_turns() -> void:
	var good := Level01Layout.TURNS.size() == 1
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
	var edge: Array = [&"I", &"E", 2.5, 5.5, Level01Layout.BELT]
	var flipped := Level01Layout.belt_costs(edge, false)
	_expect(Level01Layout.belt_costs(edge, true) == Vector2(2.5, 5.5) and flipped == Vector2(5.5, 2.5), "al invertirse la cinta los dos costes se intercambian")
	var before := graph.shortest_path(&"I", &"E").cost
	_expect(graph.set_weights(&"I", &"E", flipped.x, flipped.y) and graph.version > version, "cambiar los costes sube la versión del grafo")
	_expect(graph.weight_of(&"I", &"E") == 5.5 and graph.weight_of(&"E", &"I") == 2.5, "I-E ahora cuesta 5,5 y E-I 2,5")
	_expect(graph.shortest_path(&"I", &"E").cost >= before, "ir de I a E cuesta lo mismo o más con la cinta en contra")
	var same := graph.version
	graph.set_weights(&"I", &"E", flipped.x, flipped.y)
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


#A slide only goes down: it leaves a high island for a lower one, carries along its direction and has no arc back in the graph
func _check_slides() -> void:
	var graph := Level01Layout.build_graph()
	var count := 0
	var downhill := true
	var carries := true
	var one_way := true
	for edge in Level01Layout.EDGES:
		if edge[4] != Level01Layout.SLIDE:
			continue
		count += 1
		var from: Vector3 = Level01Layout.POSITIONS[edge[0]]
		var to: Vector3 = Level01Layout.POSITIONS[edge[1]]
		downhill = downhill and from.y - to.y >= 4.0
		var flow := Level01Layout.drift(edge[0], edge[1], 0.0, 3.4)
		var toward := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
		carries = carries and flow.dot(toward) > Level01Layout.SLIDE_SPEED * 0.99 and Level01Layout.drift(edge[1], edge[0], 0.0, 3.4) == flow
		one_way = one_way and graph.has_edge(edge[0], edge[1]) and not graph.has_edge(edge[1], edge[0])
	_expect(count == 2, "hay dos toboganes")
	_expect(downhill, "cada tobogán baja al menos 4 m")
	_expect(carries, "el tobogán arrastra hacia abajo a la velocidad de su tabla, se pregunte en el orden que se pregunte")
	_expect(one_way, "el grafo solo tiene el arco de bajada de cada tobogán")
	_expect(Level01Layout.drift(&"S", &"B", 0.0, 3.4) == Vector3.ZERO and is_equal_approx(Level01Layout.drift(&"R", &"U", 0.0, 3.4).length(), 3.4),
		"un puente común no arrastra y una cinta arrastra a la velocidad de la cinta")


#A cannon: a pad on its island, away from the bridges, that throws along an arc that ends in the middle of the island it lands on, over everything else
func _check_cannons() -> void:
	var gravity := 9.8
	var placed := true
	var apart := true
	var lands := true
	var clear := true
	var hits := true
	var graph := Level01Layout.build_graph()
	var arcs := true
	var busy: Array[StringName] = []
	busy.append_array(Level01Layout.SPINNERS.keys())
	for ball: Dictionary in Level01Layout.BALLS:
		busy.append(ball["island"])
	for launch: Dictionary in Level01Layout.LAUNCHES:
		var from: StringName = launch["from"]
		var to: StringName = launch["to"]
		var centre: Vector3 = Level01Layout.POSITIONS[from]
		var spot := Level01Layout.launch_pad(launch)
		placed = placed and Level01Layout.POSITIONS.has(from) and Level01Layout.POSITIONS.has(to) and not busy.has(to)
		placed = placed and Vector2(spot.x - centre.x, spot.z - centre.z).length() + Level01Hazards.LAUNCH_REACH <= Level01Layout.radius_of(from)
		placed = placed and Level01Layout.launch_of(from, to) == launch and Level01Layout.launch_of(to, from).is_empty()
		for edge in Level01Layout.EDGES:
			if edge[0] != from and edge[1] != from:
				continue
			var other: StringName = edge[1] if edge[0] == from else edge[0]
			var toward: Vector3 = Level01Layout.POSITIONS[other] - centre
			apart = apart and absf(Vector2(toward.x, toward.z).angle_to(Vector2(spot.x - centre.x, spot.z - centre.z))) > 0.5
		arcs = arcs and graph.has_edge(from, to) and not graph.has_edge(to, from) and graph.weight_of(from, to) == launch["cost"]
		#The same steps the body takes: gravity first, then the move
		var velocity := Level01Hazards.launch_velocity(launch, gravity)
		var point := spot
		var time := 0.0
		var step := 1.0 / 60.0
		var top := spot.y
		while time < float(launch["time"]) - step / 2.0:
			velocity.y -= gravity * step
			point += velocity * step
			time += step
			top = maxf(top, point.y)
			if not _over_the_course(point, from, to):
				clear = false
				print("  arco de %s a %s a %.2f s en %s" % [from, to, time, point])
		var landing := Level01Layout.launch_landing(launch)
		lands = lands and Vector2(point.x - landing.x, point.z - landing.z).length() < 1.0 and absf(point.y - landing.y) < 0.6 and top > maxf(spot.y, landing.y) + 1.0
		hits = hits and Level01Hazards.launch_hits(launch, spot) and not Level01Hazards.launch_hits(launch, spot + Vector3(2.5, 0.0, 0.0))
		hits = hits and not Level01Hazards.launch_hits(launch, spot + Vector3(0.0, 1.5, 0.0))
	_expect(Level01Layout.LAUNCHES.size() == 3, "hay tres cañones")
	_expect(placed and arcs, "cada cañón está en una isla, a distancia del centro, y aterriza en una isla sin barra ni bola; en el grafo solo va en un sentido")
	_expect(apart, "ningún cañón queda en la línea de un puente")
	_expect(lands, "el arco termina a menos de 1 m del centro de la isla de llegada, a su altura, y pasa más de 1 m por encima de las dos islas")
	_expect(clear, "durante el vuelo el arco pasa 3 m por encima de toda isla y puente que sobrevuela")
	_expect(hits, "el cañón lanza a quien pisa su base y no a quien está lejos ni a quien ya va por el aire")


#Whether a point of a flight is at least 3 m over every island and bridge that lies under it, apart from the islands it leaves and lands on
func _over_the_course(point: Vector3, from: StringName, to: StringName) -> bool:
	var flat := Vector2(point.x, point.z)
	#Near the two islands the arc is taking off or coming down onto them
	var start: Vector3 = Level01Layout.POSITIONS[from]
	var end: Vector3 = Level01Layout.POSITIONS[to]
	if flat.distance_to(Vector2(start.x, start.z)) < Level01Layout.radius_of(from) + 3.0 or flat.distance_to(Vector2(end.x, end.z)) < Level01Layout.radius_of(to) + 6.0:
		return true
	for id: StringName in Level01Layout.POSITIONS:
		if id == from or id == to:
			continue
		var centre: Vector3 = Level01Layout.POSITIONS[id]
		if flat.distance_to(Vector2(centre.x, centre.z)) < Level01Layout.radius_of(id) + 1.0 and point.y < centre.y + 3.0:
			return false
	for edge in Level01Layout.EDGES:
		var line := _bridge_line(edge)
		var near := Geometry2D.get_closest_point_to_segment(flat, line[0], line[1])
		var higher := maxf((Level01Layout.POSITIONS[edge[0]] as Vector3).y, (Level01Layout.POSITIONS[edge[1]] as Vector3).y)
		if near.distance_to(flat) < Level01Layout.width_of(edge[4]) / 2.0 + 1.0 and point.y < higher + 3.0 + Level01Layout.SLIDE_RAIL:
			return false
	return true


#The three ways of each part take about the same: their costs in the graph are within a couple of units of each other
func _check_lanes() -> void:
	var graph := Level01Layout.build_graph()
	var parts := {
		"primera parte": [[&"N", &"Q", &"W", &"Z", &"S"], [&"N", &"O", &"R", &"U", &"X", &"Z", &"S"], [&"N", &"P", &"T", &"Y", &"Z", &"S"]],
		"segunda parte": [[&"S", &"B", &"I", &"L", &"M"], [&"S", &"A", &"D", &"K", &"M"], [&"S", &"C", &"G", &"J", &"L", &"M"]],
	}
	for part: String in parts:
		var lowest := INF
		var highest := 0.0
		for lane: Array in parts[part]:
			var cost := 0.0
			for index in range(1, lane.size()):
				cost += graph.weight_of(lane[index - 1], lane[index])
			lowest = minf(lowest, cost)
			highest = maxf(highest, cost)
		_expect(highest - lowest <= 2.5, "los tres caminos de la %s cuestan casi lo mismo: de %.1f a %.1f" % [part, lowest, highest])


#The comments: on a bridge of the course, a cycle with its parts in order, a push that only hits on the ground and across its path
func _check_comments() -> void:
	var placed := true
	var cycle := true
	var order := true
	var hits := true
	var jumps := true
	var waits := true
	var step := 0.05
	for comment: Dictionary in Level01Layout.COMMENTS:
		var edge: Array = comment["edge"]
		placed = placed and Level01Layout.POSITIONS.has(edge[0]) and Level01Layout.POSITIONS.has(edge[1]) and not Level01Layout.fragile_edges().has(edge)
		placed = placed and Level01Layout.comment_of(edge[0], edge[1]) == comment and Level01Layout.comment_of(edge[1], edge[0]) == comment
		var period: float = comment["period"]
		cycle = cycle and period > Level01Layout.COMMENT_TYPE + Level01Layout.COMMENT_WARN + Level01Layout.COMMENT_PUSH + Level01Layout.COMMENT_FADE + 1.0
		cycle = cycle and (comment["words"] as Array).size() >= 3
		var last := -1
		var pushes := 0
		var time := 0.0
		while time < period * 4.0:
			var state := Level01Hazards.comment_state(comment, time)
			var stage := int(state["stage"])
			#The parts only go forward inside a cycle: typing, warning, push, fading and then idle (which ranks last)
			var rank := 5 if stage == Level01Hazards.COMMENT_IDLE else stage
			if rank < last and int(state["cycle"]) == floori((time - step + float(comment["phase"])) / period):
				order = false
			last = rank
			if stage == Level01Hazards.COMMENT_PUSHING:
				var center := Level01Hazards.comment_center(comment, time)
				var track := Level01Hazards.block_track(comment)
				var feet := Vector3(center.x, (track["centre"] as Vector3).y, center.z)
				hits = hits and Level01Hazards.comment_hits(comment, time, feet)
				jumps = jumps and not Level01Hazards.comment_hits(comment, time, feet + Vector3(0.0, 1.2, 0.0))
				hits = hits and not Level01Hazards.comment_hits(comment, time, feet + (track["side"] as Vector3) * 3.0)
				hits = hits and not Level01Hazards.comment_hits(comment, time, feet + Vector3(-(track["side"] as Vector3).z, 0.0, (track["side"] as Vector3).x) * 3.0)
				#It pushes toward the side it ends on, away from the one it was typed on
				var side := float(state["side"])
				hits = hits and Level01Hazards.comment_push(comment, time).dot((track["side"] as Vector3) * side) < -0.99
			else:
				hits = hits and not Level01Hazards.comment_hits(comment, time, Level01Hazards.comment_center(comment, time))
			if stage == Level01Hazards.COMMENT_PUSHING and int(Level01Hazards.comment_state(comment, time - step)["stage"]) != Level01Hazards.COMMENT_PUSHING:
				pushes += 1
			var wait := Level01Hazards.comment_wait(comment, time)
			waits = waits and wait >= 0.0 and wait <= period
			if stage == Level01Hazards.COMMENT_WARNING:
				waits = waits and wait > 0.0 and wait <= Level01Layout.COMMENT_WARN + step
			time += step
		cycle = cycle and pushes == 4
	_expect(Level01Layout.COMMENTS.size() == 2, "hay dos comentarios")
	_expect(placed, "cada comentario está en un puente del recorrido que no cae, y el grafo lo encuentra por sus dos extremos")
	_expect(cycle and order, "el ciclo tiene tipeo, aviso, barrido y desinflado en ese orden, con un respiro, y barre una vez por periodo")
	_expect(hits, "el barrido golpea a quien está en la burbuja y no a quien está a un lado ni delante; solo golpea durante el barrido y empuja hacia el lado donde termina")
	_expect(jumps, "quien salta por encima de la burbuja no es golpeado")
	_expect(waits, "la espera hasta el próximo barrido nunca supera el periodo y durante el aviso es menor que el aviso")


#The decks: under the lower end of their bridge, wider and longer than it, clear of the islands, with a cannon that throws back to the start
func _check_decks() -> void:
	var edges := Level01Layout.soft_edges()
	var under := true
	var covers := true
	var clear := true
	var returns := true
	var apart := true
	var hit := true
	var outlines: Array[PackedVector2Array] = []
	for edge in edges:
		var deck := Level01Layout.deck_of(edge)
		var from: Vector3 = Level01Layout.POSITIONS[edge[0]]
		var to: Vector3 = Level01Layout.POSITIONS[edge[1]]
		var top: float = deck["top"]
		under = under and top <= minf(from.y, to.y) - 4.0 and top >= minf(from.y, to.y) - 6.0
		var size: Vector2 = deck["size"]
		var centre: Vector3 = deck["center"]
		var basis := Basis(Vector3.UP, float(deck["yaw"]))
		#Both ends of the bridge lie over the deck
		for end: Vector3 in [from, to]:
			var local := basis.inverse() * (end - centre)
			covers = covers and absf(local.x) <= size.x / 2.0 and absf(local.z) <= size.y / 2.0
		var cannon: Dictionary = deck["cannon"]
		var pad := Level01Layout.launch_pad(cannon)
		var local_pad := basis.inverse() * (pad - centre)
		covers = covers and absf(local_pad.z) <= size.y / 2.0 - 1.0 and absf(pad.y - top) < 0.01
		#The pad lifts to the middle of the island of the bridge that is closer to the start of the course
		var start: StringName = cannon["to"]
		var other: StringName = edge[1] if start == edge[0] else edge[0]
		returns = returns and (start == edge[0] or start == edge[1]) and (Level01Layout.POSITIONS[start] as Vector3).z > (Level01Layout.POSITIONS[other] as Vector3).z
		returns = returns and Level01Layout.launch_landing(cannon).is_equal_approx(Level01Layout.POSITIONS[start])
		hit = hit and Level01Hazards.launch_hits(cannon, pad) and not Level01Hazards.launch_hits(cannon, pad + Vector3(3.0, 0.0, 0.0))
		#No other island of the course stands over the deck
		for id: StringName in Level01Layout.POSITIONS:
			if id == edge[0] or id == edge[1]:
				continue
			var local_island := basis.inverse() * ((Level01Layout.POSITIONS[id] as Vector3) - centre)
			if absf(local_island.x) <= size.x / 2.0 + Level01Layout.radius_of(id) and absf(local_island.z) <= size.y / 2.0 + Level01Layout.radius_of(id) and (Level01Layout.POSITIONS[id] as Vector3).y - 2.5 < top + 2.0:
				clear = false
				print("  la cubierta %s-%s toca la isla %s" % [edge[0], edge[1], id])
		#Decks that overlap are one floor: they lie at the same height, so there is no step between them
		var outline := PackedVector2Array()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var spot := centre + basis * Vector3(corner.x * size.x / 2.0, 0.0, corner.y * size.y / 2.0)
			outline.append(Vector2(spot.x, spot.z))
		for index in outlines.size():
			var apart_by := absf(top - float(Level01Layout.deck_of(edges[index])["top"]))
			if apart_by > 0.01 and apart_by < 2.5 and not Geometry2D.intersect_polygons(outlines[index], outline).is_empty():
				apart = false
				print("  las cubiertas %s-%s y %s-%s se traslapan con un escalón o un techo bajo" % [edges[index][0], edges[index][1], edge[0], edge[1]])
		outlines.append(outline)
	_expect(edges.size() == Level01Layout.fragile_edges().size() + Level01Layout.COMMENTS.size(), "hay una cubierta por cada puente que cae y por cada comentario")
	_expect(under, "cada cubierta queda al menos 4 m por debajo del extremo más bajo de su puente")
	_expect(covers, "la cubierta cubre los dos extremos de su puente y su plataforma de cañón")
	_expect(clear, "ninguna cubierta toca otra isla del recorrido")
	_expect(apart, "dos cubiertas que se traslapan quedan a la misma altura (un solo piso, sin escalón) o a más de 2,5 m una de otra (pisos distintos)")
	_expect(returns, "la plataforma de cada cubierta devuelve al centro de la isla del inicio del puente")
	_expect(hit, "la plataforma de la cubierta responde a quien la pisa y no a quien está lejos")


#The leaps: a ledge across a gap wider than a jump and narrower than the longest dive, clear of everything, with a cannon that lands in the middle of its island
func _check_hops() -> void:
	var gravity := 9.8
	var wide := true
	var clear := true
	var lands := true
	var clean := true
	var hits := true
	var apart := true
	for hop: Dictionary in Level01Layout.HOPS:
		var from: Vector3 = Level01Layout.POSITIONS[hop["from"]]
		var ledge := Level01Layout.hop_ledge(hop)
		var radius: float = hop["radius"]
		var gap := Vector2(ledge.x - from.x, ledge.z - from.z).length() - Level01Layout.radius_of(hop["from"]) - radius
		wide = wide and absf(gap - float(hop["gap"])) < 0.01 and gap >= 5.5 and gap <= 6.8 and absf(ledge.y - from.y) < 0.01
		#Nothing else comes near the ledge: no other island, no bridge
		for id: StringName in Level01Layout.POSITIONS:
			if id != hop["from"] and Vector2(ledge.x, ledge.z).distance_to(Vector2((Level01Layout.POSITIONS[id] as Vector3).x, (Level01Layout.POSITIONS[id] as Vector3).z)) < Level01Layout.radius_of(id) + radius + 2.5:
				clear = false
				print("  el mirador toca la isla %s" % id)
		for edge in Level01Layout.EDGES:
			var line := _bridge_line(edge)
			if Geometry2D.get_closest_point_to_segment(Vector2(ledge.x, ledge.z), line[0], line[1]).distance_to(Vector2(ledge.x, ledge.z)) < Level01Layout.width_of(edge[4]) / 2.0 + radius + 2.5:
				clear = false
				print("  el mirador toca el puente %s-%s" % [edge[0], edge[1]])
		#The island it lands on has no bar or ball, and the bots cannot get to the ledge: the graph does not know it
		clean = clean and not _busy_islands().has(hop["to"]) and Level01Layout.POSITIONS.has(hop["to"])
		clean = clean and not Level01Layout.build_graph().has_vertex(StringName("hop_%s" % hop["from"]))
		var cannon := Level01Layout.hop_cannons()[0]
		var velocity := Level01Hazards.launch_velocity(cannon, gravity)
		var point := ledge
		var time := 0.0
		while time < float(cannon["time"]) - 1.0 / 120.0:
			velocity.y -= gravity / 60.0
			point += velocity / 60.0
			time += 1.0 / 60.0
			if not _over_the_course(point, hop["from"], hop["to"]):
				clear = false
				print("  el arco del mirador pasa baja sobre %s a %.2f s" % [point, time])
		var landing := Level01Layout.launch_landing(cannon)
		lands = lands and Vector2(point.x - landing.x, point.z - landing.z).length() < 1.0 and absf(point.y - landing.y) < 0.6
		hits = hits and Level01Hazards.launch_hits(cannon, ledge) and not Level01Hazards.launch_hits(cannon, ledge + Vector3(radius, 0.0, 0.0) * 1.2)
		#The cannon sits in the middle of the ledge, so the whole ledge is within the reach of the dive that lands on it
		apart = apart and Level01Layout.launch_pad(cannon).is_equal_approx(ledge)
	_expect(Level01Layout.HOPS.size() == 1, "hay un salto largo")
	_expect(wide, "el hueco mide entre 5,5 y 6,8 m (más que un salto, menos que el mejor barrido) y el mirador está a la altura de su isla")
	_expect(clear, "el mirador y el arco de su cañón no tocan otra isla ni puente: el arco pasa 3 m por encima de lo que sobrevuela")
	_expect(clean, "el cañón del mirador aterriza en una isla sin barra ni bola y el grafo no lo conoce: los bots nunca lo usan")
	_expect(lands, "el arco termina a menos de 1 m del centro de la isla de llegada, a su altura")
	_expect(hits and apart, "el cañón está en el centro del mirador y lanza a quien lo pisa, no a quien está en el borde")


#The floor of the decks has no pocket: from the pad of any deck a racer can walk to every free spot of every deck that touches it, around the
#pieces of the rim (a body is about 0.45 m wide), and no piece of the rim stands inside another deck
func _check_deck_floors() -> void:
	var edges := Level01Layout.soft_edges()
	var decks: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	for edge in edges:
		decks.append(Level01Layout.deck_of(edge))
		walls.append_array(Level01Layout.deck_walls(edge))
	var inside := 0
	for wall in walls:
		for deck in decks:
			if Level01Layout.deck_holds(deck, wall["center"], 0.6) and absf(float(deck["top"]) - float((wall["center"] as Vector3).y)) < 0.01:
				inside += 1
	var trapped := 0
	var cells := 0
	for deck in decks:
		var pad: Vector3 = Level01Layout.launch_pad(deck["cannon"])
		var size: Vector2 = deck["size"]
		var basis := Basis(Vector3.UP, float(deck["yaw"]))
		#A grid of one meter in the frame of the deck, from the cell of the pad outward over the floors of all the decks at that height
		var reached: Dictionary = {}
		var free: Dictionary = {}
		var columns := ceili(size.x)
		var rows := ceili(size.y)
		var spacing := Vector2(size.x / columns, size.y / rows)
		for column in columns:
			for row in rows:
				var spot := (deck["center"] as Vector3) + basis * Vector3((column + 0.5) * spacing.x - size.x / 2.0, 0.0, (row + 0.5) * spacing.y - size.y / 2.0)
				var blocked := false
				for wall in walls:
					if absf(float((wall["center"] as Vector3).y) - float(deck["top"])) > 0.01:
						continue
					var wall_size: Vector3 = wall["size"]
					var local := Basis(Vector3.UP, float(wall["yaw"])).inverse() * (spot - (wall["center"] as Vector3))
					blocked = blocked or (absf(local.x) <= wall_size.x / 2.0 + 0.45 and absf(local.z) <= wall_size.z / 2.0 + 0.45)
				if not blocked:
					free[Vector2i(column, row)] = spot
		var local_pad := basis.inverse() * (pad - (deck["center"] as Vector3))
		var start := Vector2i(clampi(floori((local_pad.x + size.x / 2.0) / spacing.x), 0, columns - 1), clampi(floori((local_pad.z + size.y / 2.0) / spacing.y), 0, rows - 1))
		if not free.has(start):
			trapped += 1
			continue
		var queue: Array[Vector2i] = [start]
		reached[start] = true
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = cell + step
				if free.has(next) and not reached.has(next):
					reached[next] = true
					queue.append(next)
		for cell: Vector2i in free:
			cells += 1
			if not reached.has(cell):
				trapped += 1
	_expect(inside == 0, "ninguna pieza del borde de una cubierta queda dentro del piso de otra (%d dentro)" % inside)
	_expect(trapped == 0 and cells > 200, "desde el cañón de cada cubierta se camina a todo su piso, sin rincones cerrados (%d de %d celdas sin alcanzar)" % [trapped, cells])


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
