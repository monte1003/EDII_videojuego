extends SceneTree

#Checks what each bot role chooses and the Dijkstra penalties; run: godot --headless --path . --script res://scripts/tests/bot_roles_check.gd

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
	_context.graph = Level01Layout.build_graph()
	_context.positions = Level01Layout.POSITIONS
	_context.forbidden = Level01Layout.BOT_FORBIDDEN
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
	var bot := _bot(BotRole.Kind.CHASE, &"B")
	_player_at(&"H")
	_expect(bot.role.pick_target(bot, _context, _target) == &"H", "el perseguidor va a la plataforma del jugador")
	_locator.on_bridge = true
	_locator.bridge_a = &"E"
	_locator.bridge_b = &"H"
	_expect(bot.role.pick_target(bot, _context, _target) == &"H", "con el puente abierto va al extremo lejano para cruzarlo")
	_context.graph.set_edge_enabled(&"E", &"H", false)
	_expect(bot.role.pick_target(bot, _context, _target) == &"E", "con el puente cerrado espera en el extremo cercano")
	_context.graph.set_edge_enabled(&"E", &"H", true)


func _check_ambush() -> void:
	var bot := _bot(BotRole.Kind.AMBUSH, &"D")
	_player_at(&"S")
	_expect(bot.role.pick_target(bot, _context, _target) == &"F", "el emboscador espera dos plataformas por delante del jugador")
	var near := _bot(BotRole.Kind.AMBUSH, &"B")
	_expect(near.role.pick_target(near, _context, _target) == &"S", "si ya está cerca, deja la emboscada y persigue")
	_player_at(&"L")
	_expect(bot.role.pick_target(bot, _context, _target) == &"L", "ante la meta no espera dentro de ella: persigue")
	var rival := ChaseTarget.new()
	rival.node = _player
	rival.locator = PlayerLocator.new()
	_nodes.append(rival.locator)
	rival.locator.vertex = &"I"
	rival.progress = 1.0
	_target.progress = 9.0
	_context.targets.append(rival)
	_expect(bot.role.pick_target(bot, _context, _target) == &"K", "el emboscador espera al que va primero, no al que lo está mirando")
	_context.targets.erase(rival)


func _check_guard() -> void:
	var guard := _bot(BotRole.Kind.GUARD, &"K")
	_expect(not guard.role.needs_sight(), "el guardián no necesita ver al jugador")
	_player_at(&"S")
	var post: StringName = guard.role.pick_target(guard, _context, _target)
	_expect(post == &"K" or post == &"L", "el guardián espera en una puerta de la meta: %s" % post)
	_player_at(&"L")
	_expect(guard.role.pick_target(guard, _context, _target) == &"L", "si el jugador llega a una puerta, el guardián va por él")
	var free: Array[StringName] = [&"A"]
	_expect(guard.role.spawn_vertex(free, _context) == &"K", "el guardián empieza en una puerta de la meta")
	_expect(guard.role.release_delay(5.0) == 0.0 and _bot(BotRole.Kind.CHASE, &"A").role.release_delay(5.0) == 5.0,
		"el guardián sale al empezar y el perseguidor tras la ventaja")


func _check_flank() -> void:
	var lead := _bot(BotRole.Kind.CHASE, &"B")
	var flanker := _bot(BotRole.Kind.FLANK, &"G")
	_context.bots.assign([lead, flanker])
	_player_at(&"E")
	var pick := flanker.role.pick_target(flanker, _context, _target)
	_expect(_context.graph.neighbors(&"E").has(pick) and _context.cost(&"B", pick) > _context.cost(&"B", &"E"),
		"el que rodea va a una vecina del jugador más lejos del perseguidor que el jugador: %s" % pick)
	_context.bots.clear()


func _check_traffic() -> void:
	var first := _bot(BotRole.Kind.CHASE, &"B")
	var second := _bot(BotRole.Kind.CHASE, &"A")
	first.state = ChaserBot.State.CHASE
	first.route.assign([&"E"])
	_context.bots.assign([first, second])
	var penalties := _context.traffic_for(second)
	_expect(penalties.get(&"B", 0.0) == ChaseContext.TRAFFIC_COST and penalties.get(&"E", 0.0) == ChaseContext.TRAFFIC_COST,
		"un bot penaliza la plataforma donde está otro y la siguiente de su ruta")
	_expect(not _context.traffic_for(first).has(&"A"), "un bot inactivo no cuenta como tráfico")
	second.target_vertex = &"E"
	_expect(not _context.traffic_for(second).has(&"E"), "el destino propio nunca se penaliza")
	_context.bots.clear()


func _check_penalties() -> void:
	var graph := Level01Layout.build_graph()
	var plain := graph.shortest_path(&"B", &"L")
	_expect(plain.path == [&"B", &"F", &"J", &"L"] and plain.cost == 8.5 and plain.penalty == 0.0, "sin penalizaciones B a L sigue siendo B-F-J-L por 8,5")
	var avoided := graph.shortest_path(&"B", &"L", [], {&"J": 10.0})
	_expect(avoided.found and not avoided.path.has(&"J"), "una plataforma muy cargada se rodea: %s" % [avoided.path])
	_expect(avoided.cost == 9.5 and avoided.penalty == 0.0, "el costo informado son los puentes: 9,5 y sin penalización")
	var forced := graph.shortest_path(&"B", &"L", [], {&"J": 0.5})
	_expect(forced.path == [&"B", &"F", &"J", &"L"] and forced.cost == 8.5 and is_equal_approx(forced.penalty, 0.5),
		"una penalización pequeña no cambia la ruta y se informa aparte")
