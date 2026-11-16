extends SceneTree

#Checks the daze of the arenas against the blow of a car in the street: how far a shove throws the player on flat ground, how long it
#stays without hands, the stars over its head, the short grace after it, the shield, the step back of whoever shoves, a shove in
#the air, and that a rain of shoves never keeps anyone dazed for good.
#Run: godot --headless --fixed-fps 60 --path . --script res://scripts/tests/daze_check.gd

const STEP := 1.0 / 60.0

var _failures := 0
var _scene: Node3D
var _next_id := 1


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _frames(count: int) -> void:
	for step in count:
		await physics_frame


func _make(scene_path := "res://scenes/characters/player.tscn") -> Player:
	var player := (load(scene_path) as PackedScene).instantiate() as Player
	_scene.add_child(player)
	player.player_id = _next_id
	player.global_position = Vector3((_next_id % 8) * 14.0 - 50.0, 0.05, 60.0 - floorf(_next_id / 8.0) * 30.0)
	_next_id += 1
	player.set_character(load("res://resources/characters/fire.tres") as CharacterData)
	return player


func _shove_hit(direction: Vector3) -> Player.Hit:
	var hit := Player.Hit.new()
	hit.push = direction * ArenaBrawl.SHOVE_PUSH
	hit.stun = ArenaBrawl.SHOVE_STUN
	hit.strength = 0.35
	hit.dazes = true
	return hit


#How far the player ends from where it stood, on the ground, once everything has settled
func _settle(player: Player, from: Vector3) -> float:
	await _frames(150)
	return Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()


func _run() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300.0, 1.0, 300.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_scene.add_child(floor_body)
	await _frames(10)

	#The blow of a car in the street, as the street gives it, for the comparison
	var runner := _make("res://scenes/characters/street_runner.tscn") as StreetRunner
	runner.min_x = -500.0
	runner.max_x = 500.0
	runner.min_z = -500.0
	runner.max_z = 500.0
	runner.set_input_enabled(false)
	await _frames(20)
	var street_from := runner.global_position
	var car := Player.Hit.new()
	car.push = Vector3(14.0, 0.0, 8.0)
	car.stun = 0.7
	car.flips = true
	car.strength = 0.85
	runner.take_hit(car)
	var street := await _settle(runner, street_from)
	print("INFO  golpe de auto de la calle: %.2f m" % street)

	#The shove, from rest on flat ground
	var victim := _make()
	victim.set_input_enabled(false)
	await _frames(20)
	var from := victim.global_position
	var dazed_events: Array[bool] = []
	victim.dazed_changed.connect(func(value: bool) -> void: dazed_events.append(value))
	victim.take_hit(_shove_hit(Vector3.BACK))
	var dazed_for := 0.0
	var halo_seen := false
	var tilt := 0.0
	var model := victim.find_children("*", "CharacterModel", true, false)[0] as Node3D
	while victim.is_dazed() and dazed_for < 3.0:
		await physics_frame
		dazed_for += STEP
		var halo := victim.find_children("*", "Sprite3D", true, false)
		halo_seen = halo_seen or (not halo.is_empty() and (halo[0] as Node3D).is_visible_in_tree())
		tilt = maxf(tilt, rad_to_deg(model.global_basis.y.angle_to(Vector3.UP)))
	var guard_blocks := not victim.can_be_dazed()
	await _frames(roundi(Player.DAZE_GUARD / STEP) + 2)
	var guard_over := victim.can_be_dazed()
	var shove := await _settle(victim, from)
	var share := shove / street
	_check(shove >= 3.0 and shove <= 4.0, "el empujón lanza de 3,0 a 4,0 m en suelo plano desde quieto (%.2f m)" % shove)
	_check(share >= 0.55 and share <= 4.0 / street + 0.01, "es lo más cerca del 70 %% de un golpe de auto de la calle que deja el tope de 4 m (%d %%)" % roundi(share * 100.0))
	_check(absf(dazed_for - ArenaBrawl.SHOVE_STUN) < 0.05, "el aturdimiento dura %.1f s (%.2f s medidos)" % [ArenaBrawl.SHOVE_STUN, dazed_for])
	_check(dazed_events == [true, false], "avisa al empezar y al terminar el aturdimiento")
	_check(halo_seen, "mientras dura se ven las estrellitas sobre la cabeza")
	_check(tilt < 40.0, "se tambalea sin voltearse ni quedar tendido (se inclina %d°)" % roundi(tilt))
	_check(guard_blocks and guard_over, "al terminar hay %.2f s de gracia sin otro aturdimiento, y después vuelve a poder" % Player.DAZE_GUARD)

	#No hands while dazed: it does not walk, jump or dive
	var still := _make()
	still.dive_enabled = true
	(still.get_node("PlayerInput") as Node).set_physics_process(false)
	await _frames(20)
	still.take_hit(_shove_hit(Vector3.RIGHT))
	await _frames(3)
	still.move_input = Vector2(0.0, -1.0)
	still.jump_requested = true
	await _frames(2)
	var mid := still.global_position
	var jumped := still.velocity.y > Player.DAZE_HOP + 0.5
	await _frames(20)
	var walked := still.global_position.z < mid.z - 0.3
	_check(not jumped and not still.is_diving() and not walked, "aturdido no salta, no barre y no camina")
	still.move_input = Vector2.ZERO

	#A daze while dazed does nothing
	var twice := _make()
	twice.set_input_enabled(false)
	await _frames(20)
	twice.take_hit(_shove_hit(Vector3.LEFT))
	await _frames(12)
	var left_before := twice.global_position
	twice.take_hit(_shove_hit(Vector3.RIGHT))
	await _frames(6)
	_check(twice.global_position.x < left_before.x + 0.01, "un segundo empujón durante el aturdimiento no hace nada")

	#A rain of shoves every frame for 6 s: the player still gets its hands back between them
	var rained := _make()
	rained.set_input_enabled(false)
	await _frames(20)
	var dazes := [0]
	var free_time := 0.0
	var count := func(value: bool) -> void:
		if value:
			dazes[0] += 1
	rained.dazed_changed.connect(count)
	for step in 360:
		if rained.can_be_dazed():
			rained.take_hit(_shove_hit(Vector3.FORWARD if step % 2 == 0 else Vector3.BACK))
		await physics_frame
		if not rained.is_dazed():
			free_time += STEP
	var cycle := ArenaBrawl.SHOVE_STUN + Player.DAZE_GUARD
	_check(dazes[0] <= ceili(6.0 / cycle) + 1, "con empujones sin parar, como mucho un aturdimiento cada %.2f s (%d en 6 s)" % [cycle, dazes[0]])
	_check(free_time >= 6.0 * Player.DAZE_GUARD / cycle - 0.1, "y entre uno y otro recupera el control (%.2f s libres en 6 s)" % free_time)

	#The shield takes the shove: the round asks the brawl first and the player is not dazed
	var brawl := ArenaBrawl.new()
	brawl.add(7)
	brawl.give_shield(7, 8.0)
	_check(brawl.strike(7) == ArenaBrawl.Outcome.BLOCKED and not brawl.has_shield(7), "el escudo para el empujón y se gasta")
	_check(brawl.strike(7) == ArenaBrawl.Outcome.IGNORED, "y queda un momento de gracia después")

	#Whoever shoves steps back a little
	var shover := _make()
	shover.set_input_enabled(false)
	await _frames(20)
	var shover_from := shover.global_position
	shover.apply_push(Vector3.FORWARD * -ArenaBrawl.SHOVE_RECOIL)
	var recoil := await _settle(shover, shover_from)
	_check(recoil >= 0.3 and recoil <= 0.5, "quien empuja retrocede de 0,3 a 0,5 m (%.2f m)" % recoil)

	#In the air the shove throws too
	var flier := _make()
	flier.set_input_enabled(false)
	(flier.get_node("PlayerInput") as Node).set_physics_process(false)
	await _frames(20)
	var air_from := flier.global_position
	flier.jump_requested = true
	await _frames(12)
	var was_flying := not flier.is_on_floor()
	flier.take_hit(_shove_hit(Vector3.BACK))
	var air := await _settle(flier, air_from)
	_check(was_flying and air >= 3.0 and air <= 4.6, "en el aire también lo desplaza (%.2f m)" % air)

	print("FALLOS: %d" % _failures if _failures > 0 else "OK")
	quit(1 if _failures > 0 else 0)
