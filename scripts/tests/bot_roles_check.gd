extends SceneTree

#Checks each bot role choice and the Dijkstra penalties; run headless with --script

var _failures := 0
var _context: ChaseContext
var _locator: PlayerLocator
var _player: Node3D
var _target: ChaseTarget
var _nodes: Array[Node] = []


func _initialize() -> void:
	_setup()
	_check_chase()
	_check_ambush()
	_check_guard()
	_check_flank()
	_check_traffic()
	_check_penalties()
	for node in _nodes:
		node.free()
	print("bot_roles_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _setup() -> void:
	_context = ChaseContext.new()
	_context.graph = Level01Layout.build_graph(false)
	_context.positions = Level01Layout.POSITIONS
	_context.forbidden = [&"M"]
	_context.goal = Level01Layout.GOAL
	_locator = PlayerLocator.new()
	_player = Node3D.new()
	_nodes.append_array([_locator, _player])
	_target = ChaseTarget.new()
	_target.node = _player
	_target.locator = _locator
	_context.targets.append(_target)


func _bot(role_kind: int, vertex: StringName) -> ChaserBot:
	var appearance := BotAppearance.new()
	appearance.role = role_kind
	var bot := ChaserBot.new()
	bot.appearance = appearance
	bot.role = BotRoles.make(role_kind)
	bot.current_vertex = vertex
	_nodes.append(bot)
	return bot


func _player_at(vertex: StringName) -> void:
	_locator.vertex = vertex
	_locator.on_bridge = false


func _check_chase() -> void:
	var bot := _bot(BotRole.Kind.CHASE, &"N")
	_player_at(&"A3")
	_expect(bot.role.pick_target(bot, _context, _target) == &"A3", "el perseguidor va a la plataforma del jugador")
	_locator.on_bridge = true
	_locator.bridge_a = &"A2"
	_locator.bridge_b = &"A3"
	_expect(bot.role.pick_target(bot, _context, _target) == &"A3", "con el puente abierto va al extremo lejano para cruzarlo")
	_context.graph.set_edge_enabled(&"A2", &"A3", false)
	_expect(bot.role.pick_target(bot, _context, _target) == &"A2", "con el puente cerrado espera en el extremo cercano")
	_context.graph.set_edge_enabled(&"A2", &"A3", true)


func _check_ambush() -> void:
	var bot := _bot(BotRole.Kind.AMBUSH, &"A3")
	_player_at(&"N")
	_expect(bot.role.pick_target(bot, _context, _target) == &"C1", "el emboscador espera dos plataformas por delante del jugador")
	var near := _bot(BotRole.Kind.AMBUSH, &"B1")
	_expect(near.role.pick_target(near, _context, _target) == &"N", "si ya está cerca, deja la emboscada y persigue")
	_player_at(&"E")
	_expect(bot.role.pick_target(bot, _context, _target) == &"E", "ante la meta no espera dentro de ella: persigue")
	var rival := ChaseTarget.new()
	rival.node = _player
	rival.locator = PlayerLocator.new()
	_nodes.append(rival.locator)
	rival.locator.vertex = &"S"
	rival.progress = 1.0
	_target.progress = 9.0
	_context.targets.append(rival)
	_expect(bot.role.pick_target(bot, _context, _target) == &"B5", "el emboscador espera al que va primero, no al que lo está mirando")
	_context.targets.erase(rival)


func _check_guard() -> void:
	var guard := _bot(BotRole.Kind.GUARD, &"E")
	_expect(not guard.role.needs_sight(), "el guardián no necesita ver al jugador")
	_player_at(&"S")
	var post: StringName = guard.role.pick_target(guard, _context, _target)
	_expect(post == &"E", "el guardián espera en la puerta de la meta: %s" % post)
	_player_at(&"E")
	_expect(guard.role.pick_target(guard, _context, _target) == &"E", "si el jugador llega a la puerta, el guardián va por él")
	var free: Array[StringName] = [&"A1"]
	_expect(guard.role.spawn_vertex(free, _context) == &"E", "el guardián empieza en la puerta de la meta")
	_expect(guard.role.release_delay(5.0) == 0.0 and _bot(BotRole.Kind.CHASE, &"A1").role.release_delay(5.0) == 5.0,
		"el guardián sale al empezar y el perseguidor tras la ventaja")


func _check_flank() -> void:
	var lead := _bot(BotRole.Kind.CHASE, &"N")
	var flanker := _bot(BotRole.Kind.FLANK, &"B2")
	_context.bots.assign([lead, flanker])
	_player_at(&"A2")
	var pick := flanker.role.pick_target(flanker, _context, _target)
	_expect(_context.graph.neighbors(&"A2").has(pick) and _context.cost(&"N", pick) > _context.cost(&"N", &"A2"),
		"el que rodea va a una vecina del jugador más lejos del perseguidor que el jugador: %s" % pick)
	_context.bots.clear()


func _check_traffic() -> void:
	var first := _bot(BotRole.Kind.CHASE, &"B1")
	var second := _bot(BotRole.Kind.CHASE, &"A1")
	first.state = ChaserBot.State.CHASE
	first.route.assign([&"N"])
	_context.bots.assign([first, second])
	var penalties := _context.traffic_for(second)
	_expect(penalties.get(&"B1", 0.0) == ChaseContext.TRAFFIC_COST and penalties.get(&"N", 0.0) == ChaseContext.TRAFFIC_COST,
		"un bot penaliza la plataforma donde está otro y la siguiente de su ruta")
	_expect(not _context.traffic_for(first).has(&"A1"), "un bot inactivo no cuenta como tráfico")
	second.target_vertex = &"N"
	_expect(not _context.traffic_for(second).has(&"N"), "el destino propio nunca se penaliza")
	_context.bots.clear()


func _check_penalties() -> void:
	var graph := Level01Layout.build_graph(false)
	var plain := graph.shortest_path(&"N", &"S")
	_expect(plain.path.has(&"C3") and is_equal_approx(plain.cost, 14.0) and plain.penalty == 0.0, "sin penalizaciones de N a S va por Scroll por 14,0")
	var avoided := graph.shortest_path(&"N", &"S", [], {&"C3": 10.0})
	_expect(avoided.found and not avoided.path.has(&"C3"), "una plataforma muy cargada se rodea: %s" % [avoided.path])
	_expect(is_equal_approx(avoided.cost, 14.4) and avoided.penalty == 0.0, "el costo informado son los puentes: 14,4 por Comentarios y sin penalización")
	var forced := graph.shortest_path(&"N", &"S", [], {&"C3": 0.25})
	_expect(forced.path.has(&"C3") and is_equal_approx(forced.cost, 14.0) and is_equal_approx(forced.penalty, 0.25),
		"una penalización pequeña no cambia la ruta y se informa aparte")
