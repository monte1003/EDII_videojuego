extends SceneTree

#Checks the trend war with no scene: the map and its graph, the board of bubbles and the rules by player id
#run: godot --headless --path . --script res://scripts/tests/trend_check.gd

const SHEET: ScoreSheet = preload("res://resources/score_sheet.tres")
const SETTINGS: TrendSettings = preload("res://resources/levels/trend_war.tres")

var _failures := 0


func _initialize() -> void:
	_check_map()
	_check_board()
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
	var reachable := true
	for id: StringName in layout.islands:
		reachable = reachable and graph.shortest_path(TrendLayout.CORE, id).found
	_expect(reachable, "desde el núcleo se llega por puentes a las %d islas" % layout.islands.size())
	var heights: Dictionary = {}
	for id: StringName in layout.islands:
		heights[snappedf(layout.position_of(id).y, 0.1)] = true
	_expect(heights.size() >= 6, "el mapa tiene muchas alturas distintas (%d)" % heights.size())
	_expect(layout.points.size() >= TrendCatalog.COUNT * SETTINGS.copies_per_kind + 4, "hay más puntos que burbujas: %d para %d" % [
		layout.points.size(), TrendCatalog.COUNT * SETTINGS.copies_per_kind])
	var steep := 0.0
	for bridge in layout.bridges:
		var frame := layout.frame_of(bridge)
		steep = maxf(steep, absf((frame["end"] as Vector3).y - (frame["start"] as Vector3).y) / maxf(float(frame["length"]), 0.01))
	_expect(steep < 0.75, "ninguna rampa pasa de 37 grados (pendiente máxima %.2f)" % steep)
	var overlap := false
	for a: StringName in layout.islands:
		for b: StringName in layout.islands:
			if a != b and layout.position_of(a).distance_to(layout.position_of(b)) < layout.radius_of(a) + layout.radius_of(b) + 0.5:
				overlap = true
	_expect(not overlap, "ninguna isla se monta sobre otra")
	var board := TrendBoard.new(layout, SETTINGS)
	var rng := RandomNumberGenerator.new()
	var hops := 0.0
	var count := 0
	for seed_value in 40:
		rng.seed = seed_value
		board.deal(rng)
		var held := board.by_kind()
		var chain := TrendRules.make_chain(4, false, rng)
		var par := layout.par_seconds(layout.position_of(TrendLayout.CORE), chain, held)
		hops += par * ArenaLayout.WALK_SPEED / chain.size()
		count += 1
		if par == INF:
			_expect(false, "tendencia sin camino con la semilla %d" % seed_value)
	var average := hops / count
	_expect(average >= 8.0 and average <= 18.0, "de una burbuja a la siguiente hay de 8 a 18 m de camino en promedio (%.1f)" % average)


func _check_board() -> void:
	var layout := TrendLayout.new()
	var board := TrendBoard.new(layout, SETTINGS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	board.deal(rng)
	var held := board.by_kind()
	var even := held.size() == TrendCatalog.COUNT
	for kind: int in held:
		even = even and (held[kind] as Array).size() == SETTINGS.copies_per_kind
	_expect(even, "el reparto pone %d burbujas de cada una de las %d categorías" % [SETTINGS.copies_per_kind, TrendCatalog.COUNT])
	var point: int = held[0][0]
	_expect(board.take(point) == 0 and board.kinds[point] == -1 and board.take(point) == -1, "una burbuja atrapada deja su punto vacío y no se atrapa dos veces")
	var back := board.tick(SETTINGS.respawn_seconds - 0.1, rng)
	_expect(back.is_empty(), "antes de %d s no reaparece" % int(SETTINGS.respawn_seconds))
	back = board.tick(0.2, rng)
	_expect(back.size() == 1 and back[0] != point and board.kinds[back[0]] == 0, "reaparece a los %d s en otro punto" % int(SETTINGS.respawn_seconds))
	board.drop(3, Vector3.ZERO, Vector3.RIGHT, 7)
	_expect(board.loose.size() == 1 and not board.can_pick(board.loose[0], 7) and board.can_pick(board.loose[0], 8),
		"lo que suelta un golpe queda suelto: su dueño espera un momento y cualquier otro lo puede tomar")
	board.tick(SETTINGS.loose_owner_rest + 0.1, rng)
	_expect(board.can_pick(board.loose[0], 7), "pasado ese momento su dueño también puede")
	board.tick(SETTINGS.loose_seconds, rng)
	_expect(board.loose.is_empty(), "a los %d s lo suelto desaparece" % int(SETTINGS.loose_seconds))


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
