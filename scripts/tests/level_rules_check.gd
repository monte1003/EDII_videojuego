extends SceneTree

#Checks the level 1 rules with no scene; run headless with --script

const STEP := 0.1

var _failures := 0
var _outcomes: Array[int] = []


func _initialize() -> void:
	_check_time()
	_check_falls()
	_check_hits_and_protection()
	_check_goal()
	_check_checkpoint()
	_check_race()
	print("level_rules_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _rules(player_ids: Array[int]) -> Level01Rules:
	_outcomes.clear()
	var rules := Level01Rules.new(Level01Settings.new(), player_ids, &"S")
	rules.outcome_decided.connect(func(outcome: int) -> void: _outcomes.append(outcome))
	return rules


func _run(rules: Level01Rules, seconds: float) -> void:
	for step in int(seconds / STEP):
		rules.tick(STEP)


func _check_time() -> void:
	var rules := _rules([1])
	_run(rules, 60.0)
	_expect(is_equal_approx(rules.time_left, rules.settings.time_limit - 60.0) and rules.is_running(),
		"pasan 60 s y la ronda sigue: quedan %.1f" % rules.time_left)
	_run(rules, rules.settings.time_limit)
	_expect(rules.outcome == Level01Rules.Outcome.LOST_TIME and rules.time_left == 0.0, "al acabarse el reloj se pierde por tiempo")
	_expect(_outcomes == [Level01Rules.Outcome.LOST_TIME], "el resultado se avisa una sola vez")
	var elapsed := rules.elapsed
	_run(rules, 5.0)
	_expect(rules.elapsed == elapsed, "con la ronda decidida el tiempo ya no avanza")


func _check_falls() -> void:
	var rules := _rules([1])
	_expect(rules.fall(1) and rules.state_of(1).attempts_left == 2, "una caída cuesta un intento y se sigue")
	_expect(rules.is_protected(1), "al reaparecer hay protección")
	_run(rules, rules.settings.respawn_protection + 0.5)
	_expect(not rules.is_protected(1), "la protección de reaparecer se acaba")
	rules.fall(1)
	_expect(not rules.fall(1) and rules.outcome == Level01Rules.Outcome.LOST_ATTEMPTS, "sin intentos se pierde por intentos")
	_expect(_outcomes == [Level01Rules.Outcome.LOST_ATTEMPTS], "perder por intentos se avisa una vez")
	_expect(not rules.fall(1), "con la ronda decidida ya no se cae")


func _check_hits_and_protection() -> void:
	var rules := _rules([1])
	_expect(rules.register_hit(1), "un empujón sin protección da")
	_expect(not rules.register_hit(1), "justo después no vuelve a dar")
	_run(rules, rules.settings.hit_immunity + 0.2)
	_expect(rules.register_hit(1), "pasada la inmunidad vuelve a dar")
	var back := _rules([1])
	back.fall(1)
	_expect(back.is_protected(1) and not back.register_hit(1), "recién vuelto de una caída nada lo golpea")


func _check_goal() -> void:
	var solo := _rules([1])
	solo.reach_goal(1)
	_expect(solo.outcome == Level01Rules.Outcome.WON, "con un solo jugador, llegar a la meta gana")
	var pair := _rules([1, 2])
	pair.reach_goal(1)
	_expect(pair.is_running(), "con dos jugadores, uno solo no gana la ronda")
	pair.reach_goal(2)
	_expect(pair.outcome == Level01Rules.Outcome.WON, "con los dos en la meta se gana")


func _check_checkpoint() -> void:
	var rules := _rules([1])
	_expect(rules.reach_checkpoint(1, &"H") and not rules.reach_checkpoint(1, &"H"), "el checkpoint cuenta solo la primera vez")
	_expect(rules.state_of(1).checkpoint == &"H", "el checkpoint se guarda")


func _race(player_ids: Array[int]) -> Level01Rules:
	_outcomes.clear()
	var rules := Level01Rules.new(Level01Settings.new(), player_ids, &"S")
	rules.outcome_decided.connect(func(outcome: int) -> void: _outcomes.append(outcome))
	return rules


func _check_race() -> void:
	var rules := _race([1, 2, 3, 4])
	_expect(rules.racers_in_race() == 4, "la carrera lleva los cuatro jugadores")
	rules.reach_goal(2)
	_expect(rules.state_of(2).place == 1 and rules.is_running(), "si un jugador llega primero, la ronda sigue para los demás")
	_expect(is_equal_approx(rules.window_left, rules.settings.finish_window), "al llegar el primero se abre la ventana de cierre")
	_run(rules, 10.0)
	_expect(rules.window_left < rules.settings.finish_window and rules.is_running(), "la ventana corre mientras alguien sigue en carrera")
	rules.reach_goal(1)
	_expect(rules.state_of(1).place == 2 and rules.is_running(), "el segundo en llegar toma el puesto 2 y la ronda sigue")
	rules.reach_goal(3)
	rules.reach_goal(4)
	_expect(rules.outcome == Level01Rules.Outcome.WON, "al llegar los cuatro la ronda termina")
	_expect(rules.standings() == [2, 1, 3, 4], "la tabla pone a cada uno en su orden de llegada: %s" % [rules.standings()])
	_expect(rules.place_of(1) == 2, "el puesto del jugador 1 es el 2")

	var late := _race([1, 2])
	late.reach_goal(2)
	_run(late, late.settings.finish_window + 1.0)
	_expect(late.outcome == Level01Rules.Outcome.WON and late.window_left == 0.0 and not late.state_of(1).reached_goal(),
		"al cerrarse la meta la ronda termina y quien no llegó queda fuera")
	_expect(_outcomes == [Level01Rules.Outcome.WON], "el cierre de la meta se avisa una vez")

	var order := _race([1, 2, 3, 4])
	order.state_of(1).progress = 8.0
	order.state_of(2).progress = 3.0
	order.state_of(3).progress = 12.0
	order.state_of(4).progress = 5.0
	_expect(order.standings() == [2, 4, 1, 3], "sin llegar, la tabla ordena por cercanía a la meta: %s" % [order.standings()])
	for index in 3:
		order.fall(4)
	_expect(order.state_of(4).eliminated and order.standings()[3] == 4, "un jugador sin intentos queda al final")
	_expect(order.is_running(), "que un jugador se quede sin intentos no termina la ronda")
	order.reach_goal(2)
	order.reach_goal(3)
	_expect(order.is_running(), "con otro jugador todavía en carrera la ronda sigue")
	for index in 3:
		order.fall(1)
	_expect(order.outcome == Level01Rules.Outcome.WON, "si el último se queda sin intentos, la ronda termina con quienes llegaron")

	var broke := _race([1, 2])
	for id in [1, 2]:
		for index in 3:
			broke.fall(id)
	_expect(broke.outcome == Level01Rules.Outcome.LOST_ATTEMPTS, "si nadie llega y todos se quedan sin intentos, pierden por intentos")

	var pair := _race([1, 2])
	pair.reach_goal(1)
	_expect(pair.is_running() and pair.state_of(1).place == 1, "con dos jugadores, que uno llegue no termina la ronda")
	pair.reach_goal(2)
	_expect(pair.outcome == Level01Rules.Outcome.WON, "cuando los dos jugadores llegaron la ronda termina")
	var arrived := _race([1, 2])
	arrived.reach_goal(1)
	_expect(not arrived.fall(1) and arrived.state_of(1).attempts_left == arrived.settings.attempts, "quien ya llegó no pierde intentos")
