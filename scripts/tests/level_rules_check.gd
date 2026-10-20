extends SceneTree

#Checks the rules of level 1 with no scene; run: godot --headless --path . --script res://scripts/tests/level_rules_check.gd

const STEP := 0.1

var _failures := 0
var _outcomes: Array[int] = []
var _blocks: Array[bool] = []


func _initialize() -> void:
	_check_time()
	_check_abilities()
	_check_falls()
	_check_hits_and_protection()
	_check_goal()
	_check_checkpoint_and_detection()
	print("level_rules_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _rules(player_ids: Array[int]) -> Level01Rules:
	_outcomes.clear()
	_blocks.clear()
	var rules := Level01Rules.new(Level01Settings.new(), player_ids, &"S")
	rules.outcome_decided.connect(func(outcome: int) -> void: _outcomes.append(outcome))
	rules.block_changed.connect(func(active: bool) -> void: _blocks.append(active))
	return rules


func _run(rules: Level01Rules, seconds: float) -> void:
	for step in int(seconds / STEP):
		rules.tick(STEP)


func _check_time() -> void:
	var rules := _rules([1])
	_run(rules, 60.0)
	_expect(is_equal_approx(rules.time_left, 60.0) and rules.is_running(), "pasan 60 s y la ronda sigue: quedan %.1f" % rules.time_left)
	_run(rules, 70.0)
	_expect(rules.outcome == Level01Rules.Outcome.LOST_TIME and rules.time_left == 0.0, "al acabarse el reloj se pierde por tiempo")
	_expect(_outcomes == [Level01Rules.Outcome.LOST_TIME], "el resultado se avisa una sola vez")
	var elapsed := rules.elapsed
	_run(rules, 5.0)
	_expect(rules.elapsed == elapsed, "con la ronda decidida el tiempo ya no avanza")


func _check_abilities() -> void:
	var rules := _rules([1, 2])
	_expect(rules.use_ability(1, Level01Rules.Ability.BLOCK) == Level01Rules.Use.OK, "Bloquear se puede usar al empezar")
	_expect(rules.use_ability(1, Level01Rules.Ability.BLOCK) == Level01Rules.Use.COOLDOWN, "Bloquear se está recargando justo después")
	_expect(rules.use_ability(2, Level01Rules.Ability.BLOCK) == Level01Rules.Use.OK, "cada jugador tiene su propia recarga")
	_run(rules, 0.5)
	_expect(rules.block_active() and _blocks == [true], "el puente se cierra mientras alguien tiene Bloquear activo")
	_run(rules, rules.settings.block_duration)
	_expect(not rules.block_active() and _blocks == [true, false], "al terminar Bloquear el puente se abre una vez")
	_expect(rules.cooldown_left(1, Level01Rules.Ability.BLOCK) > 0.0, "sigue la recarga después de que termine el efecto")
	_run(rules, rules.settings.block_cooldown)
	_expect(rules.use_ability(1, Level01Rules.Ability.BLOCK) == Level01Rules.Use.OK, "pasada la recarga se vuelve a poder")
	_expect(rules.use_ability(99, Level01Rules.Ability.BLOCK) == Level01Rules.Use.COOLDOWN, "un jugador desconocido no usa nada")


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
	var shelter := _rules([1])
	shelter.use_ability(1, Level01Rules.Ability.REFUGE)
	_expect(shelter.is_protected(1) and not shelter.register_hit(1), "dentro del refugio no te empujan")
	shelter.leave_refuge(1)
	_expect(not shelter.is_protected(1), "salir del refugio termina la protección")


func _check_goal() -> void:
	var solo := _rules([1])
	solo.reach_goal(1)
	_expect(solo.outcome == Level01Rules.Outcome.WON, "con un solo jugador, llegar a la meta gana")
	var pair := _rules([1, 2])
	pair.reach_goal(1)
	_expect(pair.is_running(), "con dos jugadores, uno solo no gana la ronda")
	pair.reach_goal(2)
	_expect(pair.outcome == Level01Rules.Outcome.WON, "con los dos en la meta se gana")


func _check_checkpoint_and_detection() -> void:
	var rules := _rules([1])
	_expect(rules.reach_checkpoint(1, &"H") and not rules.reach_checkpoint(1, &"H"), "el checkpoint cuenta solo la primera vez")
	_expect(rules.state_of(1).checkpoint == &"H", "el checkpoint se guarda")
	_expect(rules.detection_radius(1) == rules.settings.detection_radius, "sin silencio los bots ven de lejos")
	rules.use_ability(1, Level01Rules.Ability.SILENCE)
	_expect(rules.detection_radius(1) == rules.settings.silenced_detection_radius, "con silencio ven de cerca")
	_run(rules, rules.settings.silence_duration + 0.5)
	_expect(rules.detection_radius(1) == rules.settings.detection_radius, "el silencio se acaba")
	_expect(Level01Settings.new().bot_count_for(1) == 3 and Level01Settings.new().bot_count_for(2) == 4 and Level01Settings.new().bot_count_for(4) == 4,
		"los bots crecen con los jugadores hasta 4")
