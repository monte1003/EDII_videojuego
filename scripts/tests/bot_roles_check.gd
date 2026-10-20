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
	_expect(bot.role.pick_target(bot, _context, _target) == &"E", "el emboscador espera dos plataformas por delante del jugador")
	_player_at(&"H")
	var near := _bot(BotRole.Kind.AMBUSH, &"E")
	_expect(near.role.pick_target(near, _context, _target) == &"H", "si ya está cerca, deja la emboscada y persigue")
	_player_at(&"J")
	_expect(bot.role.pick_target(bot, _context, _target) == &"J", "ante la meta no espera dentro de ella: persigue")


func _check_guard() -> void:
	var guard := _bot(BotRole.Kind.GUARD, &"J")
	_expect(not guard.role.needs_sight(), "el guardián no necesita ver al jugador")
	_player_at(&"S")
	_expect(guard.role.pick_target(guard, _context, _target) == &"J", "el guardián espera en la puerta por donde irá el jugador")
	_player_at(&"I")
	_expect(guard.role.pick_target(guard, _context, _target) == &"I", "si el jugador llega a una puerta, el guardián va por él")
	var free: Array[StringName] = [&"A"]
	_expect(guard.role.spawn_vertex(free, _context) == &"J", "el guardián empieza en una puerta de la meta")
	_expect(guard.role.release_delay(5.0) == 0.0 and _bot(BotRole.Kind.CHASE, &"A").role.release_delay(5.0) == 5.0,
		"el guardián sale al empezar y el perseguidor tras la ventaja")


func _check_flank() -> void:
	var lead := _bot(BotRole.Kind.CHASE, &"B")
	var flanker := _bot(BotRole.Kind.FLANK, &"G")
	_context.bots.assign([lead, flanker])
	_player_at(&"E")
	var pick := flanker.role.pick_target(flanker, _context, _target)
	_expect(pick == &"D" or pick == &"F", "el que rodea va al lado del jugador más lejano del perseguidor: %s" % pick)
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
	var plain := graph.shortest_path(&"B", &"J")
	_expect(plain.path == [&"B", &"E", &"H", &"J"] and plain.cost == 6.0 and plain.penalty == 0.0, "sin penalizaciones B a J sigue siendo B-E-H-J por 6")
	var avoided := graph.shortest_path(&"B", &"J", [], {&"H": 10.0})
	_expect(avoided.found and not avoided.path.has(&"H"), "una plataforma muy cargada se rodea: %s" % [avoided.path])
	_expect(avoided.cost == 11.0 and avoided.penalty == 0.0, "el costo informado son los puentes: 11 y sin penalización")
	var forced := graph.shortest_path(&"B", &"J", [], {&"H": 1.0})
	_expect(forced.path == [&"B", &"E", &"H", &"J"] and forced.cost == 6.0 and is_equal_approx(forced.penalty, 1.0),
		"una penalización pequeña no cambia la ruta y se informa aparte")
