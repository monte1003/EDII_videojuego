extends SceneTree

#Checks the tables of level 1, the feed events, the spinners, the turning belt, the slides, the decks, the rolling balls and the new obstacles (axes, likes,
#scroll wheels, giant balls, fans and stories) with no scene;
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
	_check_surges()
	_check_axes()
	_check_punchers()
	_check_runs()
	_check_fans()
	_check_tiles()
	_check_slides()
	_check_lanes()
	_check_comments()
	_check_decks()
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
	_expect(fragile.is_empty(), "no queda ningún puente frágil: desde el 24/11 los que caían son piso normal")
	var exist := true
	for edge in fragile:
		exist = exist and graph.has_edge(edge[0], edge[1])
	_expect(exist, "los puentes frágiles existen en el grafo")
	_expect(Level01Layout.kind_of(&"C4", &"Cx") == Level01Layout.BELT and Level01Layout.kind_of(&"Cx", &"C4") == Level01Layout.BELT, "C4-Cx es una cinta, en los dos sentidos de la pregunta")
	_expect(Level01Layout.kind_of(&"S", &"Bn") == Level01Layout.SLIDE and Level01Layout.kind_of(&"Bn", &"S") == Level01Layout.SLIDE, "S-Bn es un tobogán, en los dos sentidos de la pregunta")
	_expect(Level01Layout.kind_of(&"B3", &"S") == Level01Layout.WALK and Level01Layout.kind_of(&"S", &"M") == &"", "un puente común es común y uno que no existe no tiene tipo")
	var narrow := 0
	for edge in Level01Layout.EDGES:
		if edge[4] == Level01Layout.NARROW:
			narrow += 1
	_expect(narrow == 0 and Level01Layout.width_of(Level01Layout.WALK) == Level01Layout.WIDE_WIDTH, "no hay atajos angostos: todo camino es ancho")
	var flow := Level01Layout.belt_flow(&"C4", &"Cx")
	var toward_plaza: Vector3 = (Level01Layout.POSITIONS[&"Cx"] - Level01Layout.POSITIONS[&"C4"])
	toward_plaza.y = 0.0
	_expect(flow.dot(toward_plaza.normalized()) > 0.99 and Level01Layout.belt_flow(&"Cx", &"C4") == flow, "la cinta del scroll empieza a favor, hacia la plaza, pregunte quien pregunte")
	_expect(Level01Layout.belt_flow(&"B3", &"S") == Vector3.ZERO, "un puente común no arrastra")
	var checkpoints_exist := Level01Layout.CHECKPOINTS.size() == 2
	for vertex in Level01Layout.CHECKPOINTS:
		checkpoints_exist = checkpoints_exist and Level01Layout.POSITIONS.has(vertex)
	_expect(checkpoints_exist, "dos checkpoints que existen")
	var start_y: float = Level01Layout.POSITIONS[Level01Layout.START].y
	var drops := is_equal_approx(start_y, Level01Layout.POSITIONS[&"S"].y) and start_y - (Level01Layout.POSITIONS[&"E"] as Vector3).y >= 8.0
	_expect(drops, "la primera parte va por lo alto y los toboganes bajan a la segunda")
	var gentle := true
	var steep := true
	for edge in Level01Layout.EDGES:
		var from: Vector3 = Level01Layout.POSITIONS[edge[0]]
		var to: Vector3 = Level01Layout.POSITIONS[edge[1]]
		var run := Vector2(to.x - from.x, to.z - from.z).length() - Level01Layout.radius_of(edge[0]) - Level01Layout.radius_of(edge[1])
		var angle := rad_to_deg(atan2(absf(to.y - from.y), run))
		if edge[4] == Level01Layout.SLIDE:
			steep = steep and angle >= 10.0 and angle <= 25.0
		else:
			gentle = gentle and angle < 20.0
	_expect(gentle, "ninguna rampa a pie pasa de 20 grados")
	_expect(steep, "cada tramo de tobogán baja entre 10 y 25 grados")
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
		#With a second one down at the same time, the way to the goal still exists
		for other in Level01Layout.fragile_edges():
			graph.set_edge_enabled(other[0], other[1], false)
			always = always and graph.shortest_path(Level01Layout.START, Level01Layout.GOAL).found
			graph.set_edge_enabled(other[0], other[1], true)
	_expect(always, "con uno o dos puentes frágiles caídos la salida sigue llegando a la meta")
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
	_walk(graph, Level01Layout.START, [Level01Layout.START], 0.0, best + 3.0, found)
	_expect(found.size() >= 4, "hay %d caminos a menos de 3 del mejor: la carrera no tiene un solo camino" % found.size())
	var ways := {}
	var slides := {}
	for route in found:
		ways[route[2]] = true
		slides[route[route.find(&"S") + 1]] = true
	_expect(ways.size() >= 2 and slides.size() >= 2, "los caminos buenos se reparten por más de un camino y más de un tobogán")


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
	#The feed itself, on the three bridges it used to take down (today plain), so the mechanism stays checked
	var events := Level01Events.new(settings, rng, [[&"C2", &"C3"], [&"A6", &"A7"], [&"C7", &"C8"]])
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
	var pusher := Level01Layout.pusher_of(&"A3", &"A2")
	_expect(not pusher.is_empty() and Level01Layout.pusher_of(&"A2", &"A3") == pusher, "el puente A2-A3 tiene un bloque, se pregunte en el orden que se pregunte")
	_expect(Level01Layout.pusher_of(&"B3", &"S").is_empty(), "un puente sin bloque no lo tiene")
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
	_expect(Level01Hazards.angle_at(Level01Layout.SPINNERS[&"A3"], 1.0) < Level01Layout.SPINNERS[&"A3"]["phase"],
		"la barra de A3 gira al revés que la de A2")
	var cross: Dictionary = {"arm": 4.4, "speed": 1.3, "phase": 0.0, "arms": 2}
	_expect(Level01Hazards.hits(centre, cross, 0.0, along, 0.0) and Level01Hazards.hits(centre, cross, 0.0, across, 0.0),
		"con dos barras cruzadas se golpea a lo largo y de lado al mismo tiempo")


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
	var edge: Array = [&"C4", &"Cx", 1.4, 3.6, Level01Layout.BELT]
	var flipped := Level01Layout.belt_costs(edge, false)
	_expect(Level01Layout.belt_costs(edge, true) == Vector2(1.4, 3.6) and flipped == Vector2(3.6, 1.4), "al invertirse la cinta los dos costes se intercambian")
	var before := graph.shortest_path(&"C4", &"Cx").cost
	_expect(graph.set_weights(&"C4", &"Cx", flipped.x, flipped.y) and graph.version > version, "cambiar los costes sube la versión del grafo")
	_expect(is_equal_approx(graph.weight_of(&"C4", &"Cx"), 3.6) and is_equal_approx(graph.weight_of(&"Cx", &"C4"), 1.4), "C4-Cx ahora cuesta 3,6 y Cx-C4 1,4")
	_expect(graph.shortest_path(&"C4", &"Cx").cost >= before, "ir de C4 a Cx cuesta lo mismo o más con la cinta en contra")
	var same := graph.version
	graph.set_weights(&"C4", &"Cx", flipped.x, flipped.y)
	_expect(graph.version == same and not graph.set_weights(&"A1", &"M", 1.0, 1.0), "repetir los mismos costes no cambia la versión y un puente que no existe se rechaza")


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
	_expect(placed, "cada bola rueda por una isla sin barra ni checkpoint y su diámetro cabe en la isla")
	_expect(motion, "cada bola va y viene sin parar por su diámetro: llega a los dos extremos y da la vuelta dos veces por periodo")
	_expect(hits, "la bola golpea a quien está en su camino, no a quien salta ni a quien está a un lado")


func _check_surges() -> void:
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
	_expect(count == 7, "los tres toboganes suman siete tramos: Recarga uno, Cargando y Desliza tres cada uno")
	_expect(downhill, "cada tobogán baja al menos 4 m")
	_expect(carries, "el tobogán arrastra hacia abajo a la velocidad de su tabla, se pregunte en el orden que se pregunte")
	_expect(one_way, "el grafo solo tiene el arco de bajada de cada tobogán")
	_expect(Level01Layout.drift(&"B3", &"S", 0.0, 3.4) == Vector3.ZERO and is_equal_approx(Level01Layout.drift(&"Cx", &"C4", 0.0, 3.4).length(), 3.4),
		"un puente común no arrastra y una cinta arrastra a la velocidad de la cinta")


#The three ways of each part take about the same: their costs in the graph are within a couple of units of each other
func _check_lanes() -> void:
	var graph := Level01Layout.build_graph()
	var parts := {
		"primera parte": [[&"N", &"Aw", &"A1", &"A2", &"A3", &"A4", &"Ax", &"S"], [&"N", &"B1", &"B2", &"B3", &"S"],
			[&"N", &"Ce", &"C1", &"C2", &"C3", &"C4", &"Cx", &"S"]],
		"segunda parte": [[&"S", &"h1", &"h2", &"An", &"A5", &"A6", &"A7", &"A8", &"Ay", &"E"], [&"S", &"Bn", &"B5", &"B6", &"B7", &"B8", &"E"],
			[&"S", &"z1", &"z2", &"Cn", &"C5", &"C6", &"C7", &"C8", &"Cy", &"E"]],
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
		_expect(highest - lowest <= 3.0, "los tres caminos de la %s cuestan casi lo mismo: de %.1f a %.1f" % [part, lowest, highest])


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
	_expect(Level01Layout.COMMENTS.size() == 1, "hay un comentario que barre")
	_expect(placed, "cada comentario está en un puente del recorrido que no cae, y el grafo lo encuentra por sus dos extremos")
	_expect(cycle and order, "el ciclo tiene tipeo, aviso, barrido y desinflado en ese orden, con un respiro, y barre una vez por periodo")
	_expect(hits, "el barrido golpea a quien está en la burbuja y no a quien está a un lado ni delante; solo golpea durante el barrido y empuja hacia el lado donde termina")
	_expect(jumps, "quien salta por encima de la burbuja no es golpeado")
	_expect(waits, "la espera hasta el próximo barrido nunca supera el periodo y durante el aviso es menor que el aviso")


#The decks: under the lower end of their bridge, wider and longer than it, clear of the islands, with a pad that lifts back to the start
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
		var lift: Dictionary = deck["lift"]
		var pad: Vector3 = lift["pad"]
		var local_pad := basis.inverse() * (pad - centre)
		covers = covers and absf(local_pad.z) <= size.y / 2.0 - 1.0 and absf(pad.y - top) < 0.01
		#The pad stands out of the side of the bridge, so its bubble rises clear of it, and inside the rim of the deck
		var bridge_half := Level01Layout.width_of(Level01Layout.kind_of(edge[0], edge[1])) / 2.0
		covers = covers and absf(local_pad.x) >= bridge_half + 0.9 and absf(local_pad.x) <= size.x / 2.0 - 1.0
		#The bubble lands on the platform of the bridge that is closer to the start of the course: inside it, and out of reach of its bar
		var start: StringName = lift["to"]
		var other: StringName = edge[1] if start == edge[0] else edge[0]
		var own: bool = start == edge[0] or start == edge[1] or Level01Layout.LIFT_BACK.get("%s|%s" % edge, &"") == start
		returns = returns and own and (Level01Layout.POSITIONS[start] as Vector3).z >= (Level01Layout.POSITIONS[other] as Vector3).z
		var landing: Vector3 = lift["landing"]
		var off := landing - (Level01Layout.POSITIONS[start] as Vector3)
		var inside := maxf(absf(off.x), absf(off.z)) + 0.6 <= Level01Layout.PLATE / 2.0 if Level01Layout.is_plate(start) else off.length() + 1.0 <= Level01Layout.radius_of(start)
		returns = returns and inside and absf(off.y) < 0.01
		if Level01Layout.SPINNERS.has(start):
			returns = returns and Vector2(off.x, off.z).length() > float(Level01Layout.SPINNERS[start]["arm"]) + 0.6
		for ball: Dictionary in Level01Layout.BALLS:
			if ball["island"] == start:
				returns = returns and absf(Vector2(off.x, off.z).dot(Vector2(-sin(float(ball["angle"])), cos(float(ball["angle"]))))) > Level01Layout.BALL_RADIUS + 1.0
		if Level01Layout.run_at(landing, 0.3) >= 0:
			returns = false
			print("  la burbuja de %s-%s deja en lo que rueda" % [edge[0], edge[1]])
		hit = hit and Level01Hazards.lift_hits(lift, pad) and not Level01Hazards.lift_hits(lift, pad + Vector3(3.0, 0.0, 0.0))
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
	var walks := 0
	for edge in Level01Layout.EDGES:
		if edge[4] != Level01Layout.SLIDE and edge[1] != Level01Layout.GOAL:
			walks += 1
	_expect(edges.size() == walks and walks > 30, "hay una cubierta bajo cada puente de los caminos (%d)" % walks)
	_expect(under, "cada cubierta queda al menos 4 m por debajo del extremo más bajo de su puente")
	_expect(covers, "la cubierta cubre los dos extremos de su puente y su plataforma de cañón")
	_expect(clear, "ninguna cubierta toca otra isla del recorrido")
	_expect(apart, "dos cubiertas que se traslapan quedan a la misma altura (un solo piso, sin escalón) o a más de 2,5 m una de otra (pisos distintos)")
	_expect(returns, "la burbuja de cada cubierta deja en la plataforma del inicio del puente, fuera del alcance de su barra, su bola y lo que rueda")
	_expect(hit, "la plataforma de la cubierta responde a quien la pisa y no a quien está lejos")


#The floor of the decks has no pocket: from the pad of any deck a racer can walk to every free spot of every deck that touches it, around the
#pieces of the rim (a body is about 0.45 m wide); no piece of the rim stands inside another deck, the rim has no gap along the edge of the
#joined floor, and the bubble that catches a fall never goes to a bridge further on than the one above
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
			if Level01Layout.deck_holds(deck, wall["center"], Level01Layout.DECK_TUBE + 0.25) and absf(float(deck["top"]) - float((wall["center"] as Vector3).y)) < 0.01:
				inside += 1
	#Every spot of the edge of a deck that no other deck covers has a wall just inside it
	var gaps := 0
	for deck in decks:
		var centre: Vector3 = deck["center"]
		var outline := CandyTerrain.rounded_box(Vector2(centre.x, centre.z), deck["size"], Level01Layout.DECK_ROUND, -float(deck["yaw"]), 12)
		var edge_spots: Array[Vector3] = []
		for index in outline.size():
			var from := outline[index]
			var to := outline[(index + 1) % outline.size()]
			var pieces := maxi(ceili(from.distance_to(to) / 0.5), 1)
			for piece in pieces:
				var corner := from.lerp(to, float(piece) / pieces)
				edge_spots.append(Vector3(corner.x, float(deck["top"]), corner.y))
		for spot in edge_spots:
			var open := true
			for other in decks:
				if other != deck and is_equal_approx(float(other["top"]), float(deck["top"])) and Level01Layout.deck_distance(other, spot) < -0.3:
					open = false
			if not open:
				continue
			var inner := spot - Level01Layout.deck_normal(deck, spot) * Level01Layout.DECK_TUBE
			var held := false
			for wall in walls:
				var wall_size: Vector3 = wall["size"]
				var local := Basis(Vector3.UP, float(wall["yaw"])).inverse() * (inner - (wall["center"] as Vector3))
				held = held or (absf(local.x) <= wall_size.x / 2.0 + 0.2 and absf(local.z) <= wall_size.z / 2.0 + 0.2 and absf(local.y) < 0.5)
			if not held:
				gaps += 1
				print("  hueco en el borde de la cubierta en ", spot)
	#The bubble that catches a fall from the middle of a bridge goes to its start or further back, never ahead
	var ahead := 0
	for edge in edges:
		var deck := Level01Layout.deck_of(edge)
		var middle: Vector3 = ((Level01Layout.POSITIONS[edge[0]] as Vector3) + (Level01Layout.POSITIONS[edge[1]] as Vector3)) / 2.0
		var caught := Level01Layout.deck_catching(decks, Vector3(middle.x, float(deck["top"]) + 0.5, middle.z))
		if caught.is_empty() or (Level01Layout.POSITIONS[caught["to"]] as Vector3).z < (Level01Layout.POSITIONS[deck["lift"]["to"]] as Vector3).z - 0.01:
			ahead += 1
			print("  la caída del puente %s-%s sube a %s" % [edge[0], edge[1], caught.get("to", "nada")])
	var trapped := 0
	var cells := 0
	for deck in decks:
		var pad: Vector3 = deck["lift"]["pad"]
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
				if not Level01Layout.deck_holds(deck, spot, 0.0):
					continue
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
	_expect(gaps == 0, "el borde de las cubiertas no tiene huecos por donde salir del piso unido (%d)" % gaps)
	_expect(ahead == 0, "la burbuja de quien cae de un puente lo sube al inicio de ese puente o antes, nunca más adelante (%d)" % ahead)
	_expect(trapped == 0 and cells > 200, "desde el cañón de cada cubierta se camina a todo su piso, sin rincones cerrados (%d de %d celdas sin alcanzar)" % [trapped, cells])


#The axes of a row swing over their bridge: they hit whoever stands under them when they pass low, not whoever waits between two, and a jump
#does not clear them; they push across the bridge the way they swing
func _check_axes() -> void:
	var placed := true
	var reach := true
	var pockets := true
	for row: Dictionary in Level01Layout.AXES:
		var edge: Array = row["edge"]
		placed = placed and Level01Layout.kind_of(edge[0], edge[1]) == Level01Layout.WALK and not Level01Layout.axes_of(edge[1], edge[0]).is_empty()
		var spots := Level01Traps.axe_spots(row)
		placed = placed and spots.size() == int(row["count"])
		var frame := Level01Traps.bridge_frame(edge)
		var half := float(frame["width"]) / 2.0
		for index in spots.size():
			#Over a period, the blade passes low over the middle and over both edges of the bridge
			var middle := false
			var left := false
			var right := false
			var time := 0.0
			while time < float(row["period"]):
				middle = middle or Level01Traps.axe_hits(row, time, spots[index]) == index
				left = left or Level01Traps.axe_hits(row, time, spots[index] + (frame["across"] as Vector3) * (half - 0.4)) == index
				right = right or Level01Traps.axe_hits(row, time, spots[index] - (frame["across"] as Vector3) * (half - 0.4)) == index
				time += 0.02
			reach = reach and middle and left and right
			reach = reach and Level01Traps.axe_hits(row, _axe_low(row, index), spots[index] + Vector3(0.0, 1.0, 0.0)) == index
			if index > 0:
				var pocket := (spots[index] + spots[index - 1]) / 2.0
				var time_in := 0.0
				while time_in < float(row["period"]):
					pockets = pockets and Level01Traps.axe_hits(row, time_in, pocket) < 0
					time_in += 0.02
		var low := _axe_low(row, 0)
		var heading := Level01Traps.axe_heading(row, 0, low)
		var later := Level01Traps.axe_blade(row, 0, low + 0.05)["center"] as Vector3
		var now := Level01Traps.axe_blade(row, 0, low)["center"] as Vector3
		reach = reach and (later - now).dot(frame["across"] as Vector3) * heading > 0.0
	_expect(Level01Layout.AXES.size() == 2 and placed, "dos hileras de hachas, cada una con sus comentarios repartidos sobre un puente común")
	_expect(reach, "cada hacha pasa baja por el medio y por los dos bordes del puente, saltar no la esquiva y empuja hacia donde va")
	_expect(pockets, "entre dos hachas seguidas hay un hueco donde nunca se recibe golpe")


#A moment in which an axe hangs straight down
func _axe_low(row: Dictionary, index: int) -> float:
	var time := 0.0
	while absf(Level01Traps.axe_angle(row, index, time)) > 0.02:
		time += 0.002
	return time


#A like flies out across the bridge after shaking, holds and goes back: it only hits while out, never the far strip of the bridge, and it
#throws toward the side away from its barrel
func _check_punchers() -> void:
	var cycle := true
	var hits := true
	for puncher: Dictionary in Level01Layout.PUNCHERS:
		var edge: Array = puncher["edge"]
		cycle = cycle and Level01Layout.punchers_of(edge[1], edge[0]).has(puncher)
		cycle = cycle and float(puncher["period"]) > Level01Layout.PUNCH_WINDUP + Level01Layout.PUNCH_OUT + Level01Layout.PUNCH_HOLD + Level01Layout.PUNCH_BACK
		var frame := Level01Traps.bridge_frame(edge)
		var along := lerpf(float(frame["start"]), float(frame["end"]), float(puncher["at"]))
		var side := float(puncher["side"])
		var middle := Level01Traps.bridge_point(frame, along, 0.0)
		var far := Level01Traps.bridge_point(frame, along, -side * (float(frame["width"]) / 2.0 - 0.5))
		var out_time := Level01Layout.PUNCH_WINDUP + Level01Layout.PUNCH_OUT + 0.1 - float(puncher["phase"])
		hits = hits and Level01Traps.punch_live(puncher, out_time) and Level01Traps.punch_hits(puncher, out_time, middle)
		hits = hits and not Level01Traps.punch_hits(puncher, out_time - Level01Layout.PUNCH_OUT - 0.2, middle)
		hits = hits and Level01Traps.punch_winding(puncher, out_time - Level01Layout.PUNCH_OUT - 0.2)
		var time := 0.0
		while time < float(puncher["period"]):
			hits = hits and not Level01Traps.punch_hits(puncher, time, far)
			time += 0.02
		hits = hits and Level01Traps.punch_push(puncher).dot(frame["across"] as Vector3) * side < -0.99
	_expect(Level01Layout.PUNCHERS.size() == 6 and cycle, "seis cajas de likes, cada una con un ciclo que cabe en su periodo")
	_expect(hits, "el like golpea el medio del puente solo cuando sale, tiembla antes, nunca alcanza la orilla de enfrente y lanza lejos de su caja")


#Scroll wheels and giant balls roll from the middle of the far plate to the middle of the near one; a wheel is jumped, a ball is not, and the
#balls never fill the three lanes at once and light their lane before they come
func _check_runs() -> void:
	var placed := true
	var rolls := true
	var lanes := true
	for index in Level01Layout.RUNS.size():
		var run: Dictionary = Level01Layout.RUNS[index]
		var line := Level01Layout.run_line(run)
		placed = placed and Level01Layout.is_plate(run["from"]) and Level01Layout.is_plate(run["to"]) and float(line["length"]) > 10.0
		placed = placed and is_equal_approx((Level01Layout.POSITIONS[run["from"]] as Vector3).y, (Level01Layout.POSITIONS[run["to"]] as Vector3).y)
		placed = placed and (Level01Layout.POSITIONS[run["from"]] as Vector3).z < (Level01Layout.POSITIONS[run["to"]] as Vector3).z
		var is_roller: bool = run["kind"] == Level01Layout.ROLLER
		#Find a moment when a thing rolls by the middle of the run, then test it there
		var found := false
		var time := 0.0
		while time < 30.0 and not found:
			for item in Level01Traps.run_items(run, index, time):
				if item["live"] and absf(float(item["along"]) - float(line["length"]) / 2.0) < 0.1:
					var lane: float = (item["lanes"] as Array)[0]
					var feet := Level01Traps.run_point(run, float(item["along"]), lane, 1.0)
					feet.y = (line["from"] as Vector3).y
					rolls = rolls and Level01Traps.run_hits(run, index, time, feet)
					var jumped := feet + Vector3(0.0, 1.0, 0.0)
					rolls = rolls and Level01Traps.run_hits(run, index, time, jumped) != is_roller
					found = true
					break
			time += 0.01
		rolls = rolls and found
		rolls = rolls and Level01Traps.run_push(run).dot(line["along"] as Vector3) > 0.99
		if not is_roller:
			for number in 40:
				lanes = lanes and Level01Traps.run_lanes(run, index, number).size() < Level01Layout.BOULDER_LANES.size()
			var spawn := float(run["phase"]) + 3.0 * float(run["every"])
			var lit: float = Level01Traps.run_lanes(run, index, 3)[0]
			lanes = lanes and Level01Traps.lane_warning(run, index, lit, spawn - 0.1) > 0.8 and Level01Traps.lane_warning(run, index, lit, spawn - Level01Layout.BOULDER_WARN - 0.2) < 0.2
	_expect(Level01Layout.RUNS.size() == 4 and placed, "cuatro carriles de cosas que ruedan, de placa a placa, hacia la salida")
	_expect(rolls, "lo que rueda golpea a quien está en su carril; la rueda se salta y la bola gigante no; empujan hacia donde ruedan")
	_expect(lanes, "las bolas gigantes nunca llenan los tres carriles y el carril se enciende justo antes de su bola")


#A fan blows only after spinning up, across its bridge toward the side away from it, on the floor and over it, and not off its bridge
func _check_fans() -> void:
	var blows := true
	for fan: Dictionary in Level01Layout.FANS:
		var edge: Array = fan["edge"]
		blows = blows and Level01Layout.fan_of(edge[1], edge[0]) == fan
		var frame := Level01Traps.bridge_frame(edge)
		var middle := Level01Traps.bridge_point(frame, lerpf(float(frame["start"]), float(frame["end"]), 0.5), 0.0)
		var on := Level01Layout.FAN_SPIN_UP + 0.5 - float(fan["phase"])
		var drift := Level01Traps.fan_drift(fan, on, middle)
		blows = blows and drift.dot(frame["across"] as Vector3) * float(fan["side"]) < 0.0 and is_equal_approx(drift.length(), float(fan["power"]))
		blows = blows and Level01Traps.fan_drift(fan, on, middle + Vector3(0.0, 2.5, 0.0)) == drift
		blows = blows and Level01Traps.fan_drift(fan, Level01Layout.FAN_SPIN_UP * 0.5 - float(fan["phase"]), middle) == Vector3.ZERO
		blows = blows and Level01Traps.fan_spin(fan, Level01Layout.FAN_SPIN_UP * 0.5 - float(fan["phase"])) > 0.3
		blows = blows and Level01Traps.fan_drift(fan, on, middle + (frame["along"] as Vector3) * 30.0) == Vector3.ZERO
	_expect(Level01Layout.FANS.size() == 2 and blows, "dos ventiladores: giran antes de soplar y soplan de lado, en el piso y en el aire, solo sobre su puente")


#A tile of stories shakes when somebody stands on it, drops after its shake and comes back after a while; the bubble puts back the one under its landing
func _check_tiles() -> void:
	var tiles := Level01Tiles.new()
	var plate: StringName = Level01Layout.TILE_PLATES[0]
	var centres := Level01Layout.tile_centers(plate)
	var states: Array[String] = []
	tiles.tile_shaking.connect(func(_plate: StringName, index: int) -> void: states.append("tiembla %d" % index))
	tiles.tile_dropped.connect(func(_plate: StringName, index: int) -> void: states.append("cae %d" % index))
	tiles.tile_back.connect(func(_plate: StringName, index: int) -> void: states.append("vuelve %d" % index))
	var on: Array[Vector3] = [centres[4]]
	var none: Array[Vector3] = []
	tiles.tick(0.1, on)
	var shaking := tiles.state_of(plate, 4) == Level01Tiles.State.SHAKING and tiles.state_of(plate, 0) == Level01Tiles.State.UP
	for step in int(Level01Layout.TILE_SHAKE / 0.1) + 2:
		tiles.tick(0.1, none)
	var dropped := tiles.state_of(plate, 4) == Level01Tiles.State.GONE
	for step in int(Level01Layout.TILE_GONE / 0.1) + 2:
		tiles.tick(0.1, none)
	var back := tiles.state_of(plate, 4) == Level01Tiles.State.UP and ", ".join(states) == "tiembla 4, cae 4, vuelve 4"
	tiles.tick(0.1, on)
	for step in int(Level01Layout.TILE_SHAKE / 0.1) + 2:
		tiles.tick(0.1, none)
	tiles.restore_at(centres[4])
	var restored := tiles.state_of(plate, 4) == Level01Tiles.State.UP
	var air := centres[4] + Vector3(0.0, 1.0, 0.0)
	var flying: Array[Vector3] = [air]
	tiles.tick(0.1, flying)
	_expect(Level01Layout.TILE_PLATES.size() == 2 and centres.size() == Level01Layout.TILE_GRID * Level01Layout.TILE_GRID, "dos plataformas de historias de 3 x 3 baldosas")
	_expect(shaking and dropped and back, "la baldosa pisada tiembla, cae después de su temblor y vuelve después de un rato; las demás no se mueven: %s" % [states])
	_expect(restored and tiles.state_of(plate, 4) == Level01Tiles.State.UP, "la burbuja devuelve la baldosa donde aterriza, y nadie la sacude desde el aire")


#The islands that already have something to do
func _busy_islands() -> Array[StringName]:
	var busy: Array[StringName] = []
	busy.append_array(Level01Layout.SPINNERS.keys())
	busy.append_array(Level01Layout.TILE_PLATES)
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
				#A plate is open only at its two ends, so its two bridges come in straight from opposite sides
				if Level01Layout.is_plate(id):
					if absf(angle_difference(angles[a], angles[b])) < PI - 0.01:
						tight += 1
					continue
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
