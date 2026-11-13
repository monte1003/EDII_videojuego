extends SceneTree

#Checks the trend war with no scene: the map and its graph, the board of bubbles and the rules by player id
#run: godot --headless --path . --script res://scripts/tests/trend_check.gd

const SHEET: ScoreSheet = preload("res://resources/score_sheet.tres")
const SETTINGS: TrendSettings = preload("res://resources/levels/trend_war.tres")

var _failures := 0


func _initialize() -> void:
	_check_map()
	_check_board()
	_check_fairness()
	_check_seed()
	_check_chains()
	_check_order_and_points()
	_check_places_and_ties()
	_check_strike()
	_check_timeout()
	print("trend_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _rules(ids: Array[int], seed_value := 5) -> TrendRules:
	return TrendRules.new(SETTINGS, SHEET, ids, seed_value)


#Runs the rules until the clock of the current trend is on
func _to_run(rules: TrendRules) -> void:
	rules.start()
	while rules.phase != TrendRules.Phase.RUN:
		rules.tick(0.1)


func _check_map() -> void:
	var layout := TrendLayout.new()
	var graph := layout.build_graph()
	var costs := graph.costs_from(TrendLayout.CORE)
	var reachable := true
	for id: StringName in layout.places:
		reachable = reachable and costs.has(id)
	_expect(reachable, "desde la plaza se llega a los %d lugares del mapa" % layout.places.size())
	var heights: Dictionary = {}
	for id: StringName in layout.places:
		heights[snappedf(layout.position_of(id).y, 0.1)] = true
	_expect(heights.size() >= 5, "el terreno tiene muchas alturas distintas (%d)" % heights.size())
	var by_zone: Dictionary = {}
	for point in layout.points:
		by_zone[point["zone"]] = int(by_zone.get(point["zone"], 0)) + 1
	var spread := true
	for zone in TrendLayout.ZONE_COUNT:
		spread = spread and int(by_zone.get(zone, 0)) >= 5
	_expect(spread, "cada una de las cinco zonas tiene al menos 5 puntos de burbuja %s" % by_zone)
	_expect(layout.points.size() >= SETTINGS.bubble_target + 8, "hay más puntos que burbujas: %d para %d" % [layout.points.size(), SETTINGS.bubble_target])
	var steep := 0.0
	for ramp in layout.ramps:
		var from: Vector3 = ramp["from"]
		var to: Vector3 = ramp["to"]
		steep = maxf(steep, absf(to.y - from.y) / maxf(Vector2(to.x - from.x, to.z - from.z).length(), 0.01))
	_expect(steep < 0.75, "ninguna rampa pasa de 37 grados (pendiente máxima %.2f)" % steep)
	#The haters walk the graph without drops or launches, and with everything but the maze forbidden they never leave it
	var bot_graph := layout.build_graph(true)
	var forbidden: Array[StringName] = []
	for id: StringName in layout.places:
		if not layout.maze_places.has(id):
			forbidden.append(id)
	var roam := bot_graph.costs_from(layout.maze_places[0], forbidden)
	var inside := roam.size() == layout.maze_places.size()
	for id: StringName in roam:
		inside = inside and layout.maze_places.has(id)
	_expect(inside and layout.maze_places.size() == 16, "los haters recorren las 16 celdas del laberinto y ningún otro lugar")
	var leg := layout.expected_leg(float(SETTINGS.bubble_target) / TrendCatalog.COUNT)
	_expect(leg >= 2.5 and leg <= 8.0, "de una burbuja a la siguiente de su categoría hay unos %.1f s de camino en promedio" % leg)
	var pars: Array[float] = []
	var roomy := true
	for index in SETTINGS.lengths.size():
		pars.append(layout.par_seconds(SETTINGS.lengths[index], SETTINGS))
		roomy = roomy and pars[index] < SETTINGS.limits[index] * 0.75 and pars[index] > 2.0
	_expect(roomy, "el par de cada tendencia sale del grafo y deja margen frente a su límite %s" % [pars.map(func(par: float) -> float: return snappedf(par, 0.1))])


#The player of the simulations: it walks from place to place around the map
func _stroll(layout: TrendLayout, time: float, offset: int) -> Vector3:
	var stops: Array[StringName] = [&"C", &"tw_in", &"K0", &"bl_in", &"K1", &"bo_in", &"K2", &"mz_in", &"K3", &"ba_in", &"K4"]
	var along := time / 8.0 + offset * 2.2
	var from := layout.position_of(stops[int(along) % stops.size()])
	var to := layout.position_of(stops[(int(along) + 1) % stops.size()])
	return from.lerp(to, fposmod(along, 1.0))


func _check_board() -> void:
	var layout := TrendLayout.new()
	var board := TrendBoard.new(layout, SETTINGS, 9)
	var births: Dictionary = {}
	var lives: Array[float] = []
	var early := [0]
	var too_close := [0]
	var where := [Vector3.ZERO]
	var on_spawn := func(id: int) -> void:
		births[id] = board.clock
		var bubble: TrendBoard.Bubble = board.bubbles[id]
		if board.clock > 0.0 and layout.seconds_from(where[0], bubble.point) < SETTINGS.spawn_clear_seconds - 0.01:
			too_close[0] += 1
	var on_gone := func(id: int, taken: bool) -> void:
		if not taken:
			var lived: float = board.clock - float(births[id])
			lives.append(lived)
			if lived < SETTINGS.life_seconds.x - 0.2 and float(births[id]) > 0.0:
				early[0] += 1
	board.bubble_spawned.connect(on_spawn)
	board.bubble_gone.connect(on_gone)
	where[0] = layout.position_of(TrendLayout.CORE)
	board.fill({1: where[0]})
	_expect(board.bubbles.size() == SETTINGS.bubble_target, "al empezar hay %d burbujas vivas" % SETTINGS.bubble_target)
	var low := 999
	var high := 0
	var fewest := 999
	var most := 0
	var one_zone := 0
	var reachable := 0
	var ticks := 0
	var taken := 0
	var need := 0
	for step in 3000:
		var time := step * 0.1
		where[0] = _stroll(layout, time, 0)
		#Now and then the player fetches the bubble it needs when it is right there, and then needs the next kind
		for id: int in board.bubbles.keys():
			if board.kind_of(id) == need and layout.seconds_from(where[0], (board.bubbles[id] as TrendBoard.Bubble).point) < 1.5:
				board.take(id)
				taken += 1
				need = (need + 1) % TrendCatalog.COUNT
				break
		board.tick(0.1, {1: where[0]}, {1: need})
		ticks += 1
		low = mini(low, board.bubbles.size())
		high = maxi(high, board.bubbles.size())
		for kind in TrendCatalog.COUNT:
			fewest = mini(fewest, board.count_of(kind))
			most = maxi(most, board.count_of(kind))
			if board.zones_of(kind).size() < 2:
				one_zone += 1
		if board.within_reach(where[0], need):
			reachable += 1
	_expect(low >= SETTINGS.bubble_target - 1 and high <= SETTINGS.bubble_target + 1,
		"en 300 s la cantidad se mantiene: de %d a %d (objetivo %d, margen 1)" % [low, high, SETTINGS.bubble_target])
	_expect(fewest >= SETTINGS.min_per_kind and most <= SETTINGS.max_per_kind, "cada categoría tiene siempre de %d a %d burbujas" % [fewest, most])
	_expect(one_zone == 0, "ninguna categoría queda toda en una sola zona")
	_expect(too_close[0] == 0, "ninguna burbuja nace a menos de %.1f s a pie del jugador" % SETTINGS.spawn_clear_seconds)
	var longest := 0.0
	for lived in lives:
		longest = maxf(longest, lived)
	_expect(longest <= SETTINGS.life_seconds.y + 0.2 and early[0] <= board.rescues,
		"una burbuja vive de %d a %d s; solo se van antes las %d que cedieron su sitio a una necesaria" % [
			int(SETTINGS.life_seconds.x), int(SETTINGS.life_seconds.y), board.rescues])
	_expect(float(reachable) / ticks > 0.97, "la categoría que toca casi nunca falta al alcance (%.1f %% del tiempo; %d atrapadas)" % [100.0 * reachable / ticks, taken])
	board.bubble_spawned.disconnect(on_spawn)
	board.bubble_gone.disconnect(on_gone)
	_expect(board.take(-5) == -1, "una burbuja que no existe no se atrapa")
	board.drop(3, Vector3.ZERO, Vector3.RIGHT, 7)
	_expect(board.loose.size() == 1 and not board.can_pick(board.loose[0], 7) and board.can_pick(board.loose[0], 8),
		"lo que suelta un golpe queda suelto: su dueño espera un momento y cualquier otro lo puede tomar")
	board.tick(SETTINGS.loose_owner_rest + 0.1, {}, {})
	_expect(board.can_pick(board.loose[0], 7), "pasado ese momento su dueño también puede")
	board.tick(SETTINGS.loose_seconds, {}, {})
	_expect(board.loose.is_empty(), "a los %d s lo suelto desaparece" % int(SETTINGS.loose_seconds))


#With several players the bubbles are born about as far from each of them, and with one, at a middle distance
func _check_fairness() -> void:
	var layout := TrendLayout.new()
	for count in [1, 2, 3, 4]:
		var board := TrendBoard.new(layout, SETTINGS, 30 + count)
		var players: Dictionary = {}
		for id in count:
			players[id + 1] = _stroll(layout, 0.0, id)
		var sums: Dictionary = {}
		var spawns := [0]
		var on_spawn := func(id: int) -> void:
			spawns[0] += 1
			for player: int in players:
				sums[player] = float(sums.get(player, 0.0)) + layout.seconds_from(players[player], (board.bubbles[id] as TrendBoard.Bubble).point)
		board.bubble_spawned.connect(on_spawn)
		board.fill(players)
		for step in 2400:
			for id in count:
				players[id + 1] = _stroll(layout, step * 0.1, id)
			board.tick(0.1, players, {})
		board.bubble_spawned.disconnect(on_spawn)
		var nearest := INF
		var farthest := 0.0
		for player: int in sums:
			nearest = minf(nearest, float(sums[player]) / spawns[0])
			farthest = maxf(farthest, float(sums[player]) / spawns[0])
		if count == 1:
			_expect(nearest >= 3.0 and nearest <= 9.0, "con un jugador las burbujas nacen a una distancia media (%.1f s a pie)" % nearest)
		else:
			_expect(farthest / nearest < 1.2, "con %d jugadores nacen casi igual de lejos de cada uno (de %.1f a %.1f s en promedio)" % [count, nearest, farthest])


#The same seed and the same players give the very same bubbles; another seed gives others
func _check_seed() -> void:
	var layout := TrendLayout.new()
	var logs: Array[Array] = []
	for seed_value in [77, 77, 78]:
		var board := TrendBoard.new(layout, SETTINGS, seed_value)
		var record: Array = []
		var on_spawn := func(id: int) -> void:
			record.append([id, (board.bubbles[id] as TrendBoard.Bubble).point, board.kind_of(id)])
		board.bubble_spawned.connect(on_spawn)
		board.fill({1: layout.position_of(TrendLayout.CORE)})
		for step in 900:
			board.tick(0.1, {1: _stroll(layout, step * 0.1, 0)}, {1: floori(step / 100.0) % TrendCatalog.COUNT})
		board.bubble_spawned.disconnect(on_spawn)
		logs.append(record)
	_expect(logs[0] == logs[1] and logs[0].size() > 100, "con la misma semilla el reparto se repite idéntico (%d burbujas)" % logs[0].size())
	_expect(logs[0] != logs[2], "y con otra semilla cambia")


func _check_chains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var clean := true
	var repeats := true
	for attempt in 200:
		for length in [2, 3, 4]:
			var plain := TrendRules.make_chain(length, false, rng)
			var seen: Dictionary = {}
			for kind in plain:
				clean = clean and not seen.has(kind) and kind >= 0 and kind < TrendCatalog.COUNT
				seen[kind] = true
			clean = clean and plain.size() == length
		for length in [3, 4]:
			var twice := TrendRules.make_chain(length, true, rng)
			var counts: Dictionary = {}
			for index in twice.size():
				counts[twice[index]] = counts.get(twice[index], 0) + 1
				repeats = repeats and (index == 0 or twice[index] != twice[index - 1])
			repeats = repeats and counts[twice[0]] == 2
	_expect(clean, "sin repetición, una tendencia no trae dos veces la misma categoría")
	_expect(repeats, "con repetición, la primera categoría vuelve una vez y nunca dos seguidas")
	var rules := _rules([1])
	rules.start()
	var lengths: Array[int] = []
	var limits: Array[float] = []
	for index in rules.round_count():
		lengths.append(rules.chain.size())
		limits.append(rules.limit_of(index))
		while rules.round_index == index and rules.phase != TrendRules.Phase.DONE:
			rules.tick(0.5)
	_expect(lengths == [2, 3, 3, 4, 4] and limits == [18.0, 21.0, 23.0, 26.0, 28.0], "cinco tendencias de %s categorías con %s s" % [lengths, limits])
	_expect(rules.phase == TrendRules.Phase.DONE and rules.total_of(1) == 0, "quien no atrapa nada termina con 0 puntos")


func _check_order_and_points() -> void:
	var rules := _rules([1])
	_to_run(rules)
	rules.set_par(1, 6.0)
	var chain := rules.chain.duplicate()
	_expect(rules.needed(1) == chain[0], "toca la primera categoría de la tendencia")
	_expect(not rules.collect(1, chain[1]) and rules.state_of(1).collected == 0, "atrapar la segunda antes que la primera no cuenta")
	_expect(not rules.collect(1, -1), "una burbuja vacía no cuenta")
	rules.tick(2.0)
	_expect(rules.collect(1, chain[0]) and rules.needed(1) == chain[1], "atrapar la que toca avanza a la siguiente")
	var left := rules.left_share(1)
	_expect(rules.collect(1, chain[1]), "atrapar la última completa la tendencia")
	var state := rules.state_of(1)
	_expect(state.done and state.completed == 1 and state.round_points == SHEET.trend_points(left, 1), "los puntos salen del tiempo que sobraba: %d" % state.round_points)
	_expect(rules.phase == TrendRules.Phase.REST, "cuando todos completan, la tendencia termina sin esperar al reloj")
	_expect(rules.needed(1) == -1 and not rules.collect(1, chain[0]), "completada la tendencia no se atrapa más")
	var fast := _rules([1])
	_to_run(fast)
	fast.set_par(1, 6.0)
	for kind in fast.chain.duplicate():
		fast.collect(1, kind)
	var slow := _rules([1])
	_to_run(slow)
	slow.set_par(1, 6.0)
	slow.tick(9.0)
	for kind in slow.chain.duplicate():
		slow.collect(1, kind)
	_expect(fast.total_of(1) == 200 and slow.total_of(1) < fast.total_of(1) and slow.total_of(1) >= 60,
		"completar al instante da 200 y más tarde da menos, nunca menos de 60 (%d)" % slow.total_of(1))


func _check_places_and_ties() -> void:
	var rules := _rules([1, 2, 3, 4])
	_to_run(rules)
	for id in [1, 2, 3, 4]:
		rules.set_par(id, 6.0)
	var chain := rules.chain.duplicate()
	var order: Array[int] = [3, 1, 4, 2]
	for id in order:
		for kind in chain:
			rules.collect(id, kind)
	var places: Array[int] = []
	var points: Array[int] = []
	for id in order:
		places.append(rules.state_of(id).place)
		points.append(rules.state_of(id).round_points)
	_expect(places == [1, 2, 3, 4], "los puestos van en el orden en que completan %s" % [places])
	_expect(points == [200, 140, 100, 70], "con el mismo tiempo, cada puesto vale 1,0, 0,7, 0,5 y 0,35 %s" % [points])
	var solo := _rules([9])
	_to_run(solo)
	solo.set_par(9, 6.0)
	for kind in solo.chain.duplicate():
		solo.collect(9, kind)
	_expect(solo.state_of(9).round_points == 200, "en solitario el factor de puesto siempre es 1")
	var totals := rules.totals()
	_expect(totals.size() == 4 and totals[3] == 200 and totals[2] == 70, "cada puntaje pertenece a su jugador por id")


func _check_strike() -> void:
	var rules := _rules([1, 2])
	_to_run(rules)
	var chain := rules.chain.duplicate()
	_expect(rules.strike(1) == -1, "un golpe a quien no lleva nada no le quita nada")
	rules.collect(1, chain[0])
	_expect(rules.strike(1) == chain[0] and rules.state_of(1).collected == 0 and rules.needed(1) == chain[0],
		"un golpe quita lo último atrapado y hay que volver por ello")
	_expect(rules.state_of(2).collected == 0, "el golpe a un jugador no toca al otro")
	for kind in chain:
		rules.collect(2, kind)
	_expect(rules.strike(2) == -1 and rules.state_of(2).done, "a quien ya completó la tendencia un golpe no le quita nada")


func _check_timeout() -> void:
	var rules := _rules([1, 2])
	_to_run(rules)
	rules.set_par(1, 6.0)
	rules.set_par(2, 6.0)
	var chain := rules.chain.duplicate()
	for kind in chain:
		rules.collect(1, kind)
	rules.collect(2, chain[0])
	_expect(rules.phase == TrendRules.Phase.RUN, "con alguien sin completar, el reloj sigue")
	rules.tick(rules.limit_of(0) + 0.1)
	_expect(rules.phase == TrendRules.Phase.REST and rules.total_of(2) == 0 and rules.total_of(1) > 0, "quien no completa a tiempo no gana puntos en esa tendencia")
	while rules.phase != TrendRules.Phase.RUN:
		rules.tick(0.1)
	_expect(rules.round_index == 1 and rules.state_of(1).collected == 0 and not rules.state_of(1).done and rules.total_of(1) > 0,
		"la tendencia siguiente empieza de cero y conserva los puntos ganados")
