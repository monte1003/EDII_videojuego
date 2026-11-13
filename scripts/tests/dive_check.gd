extends SceneTree

#Checks the dive of the player (a second press of the jump in the air) on a flat floor: how far it reaches, how long each part
#lasts, once per jump, what cancels it, when it is not allowed, and that with the dive off nothing changes.
#Run: godot --headless --fixed-fps 60 --path . --script res://scripts/tests/dive_check.gd

const CHARACTERS: Array[String] = ["fire", "water", "plant", "lightning"]
#Where the discs of the leap stand: high over the floor, past its far side
const HOP_TOP := 40.0
const HOP_Z := -160.0
const HOP_RUN := 8.0

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


#A player on its own lane of the floor, looking along -Z, with nobody at the keyboard
func _make(dive: bool) -> Player:
	var player := (load("res://scenes/characters/player.tscn") as PackedScene).instantiate() as Player
	_scene.add_child(player)
	player.player_id = _next_id
	player.global_position = Vector3((_next_id % 16) * 6.0 - 45.0, 0.05, 90.0 - floorf(_next_id / 16.0) * 45.0)
	_next_id += 1
	(player.get_node("PlayerInput") as Node).set_physics_process(false)
	player.set_character(load("res://resources/characters/fire.tres") as CharacterData)
	player.dive_enabled = dive
	return player


#Runs, jumps and presses the jump again "press_at" seconds after the takeoff (negative: never). Returns how far from the takeoff
#it stopped and what happened on the way
func _leap(player: Player, press_at: float, extra_press_at := -1.0) -> Dictionary:
	var dives := [0]
	var count := func(_direction: Vector3) -> void: dives[0] += 1
	player.dive_started.connect(count)
	player.move_input = Vector2(0.0, -1.0)
	await _frames(30)
	var from := player.global_position
	player.jump_requested = true
	var air := 0.0
	var landed_at := -1.0
	var started_at := -1.0
	var free_at := -1.0
	var pressed := false
	var pressed_again := false
	var clock := 0.0
	var peak := 0.0
	for step in 300:
		await physics_frame
		clock += 1.0 / 60.0
		peak = maxf(peak, player.global_position.y)
		if not player.is_on_floor():
			air = clock
		if press_at >= 0.0 and not pressed and clock >= press_at:
			pressed = true
			player.jump_requested = true
		if extra_press_at >= 0.0 and not pressed_again and clock >= extra_press_at:
			pressed_again = true
			player.jump_requested = true
		if started_at < 0.0 and player.is_diving():
			started_at = clock
		if landed_at < 0.0 and clock > 0.1 and player.is_on_floor():
			landed_at = clock
		if landed_at >= 0.0 and not player.is_diving():
			free_at = clock
			break
	player.move_input = Vector2.ZERO
	player.dive_started.disconnect(count)
	var reach := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
	await _frames(30)
	return {"reach": reach, "dives": dives[0], "landed": landed_at, "started": started_at, "free": free_at, "air": air, "peak": peak}


#A disc of ground high over the floor: a fall from it is a fall for good
func _disc(at: Vector3, radius: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 0.6
	shape.shape = cylinder
	body.add_child(shape)
	body.position = at + Vector3(0.0, -0.3, 0.0)
	_scene.add_child(body)


#Runs off the island of a leap (HOP_RUN meters before its rim), jumps "margin" meters before its rim and dives "press" seconds into the jump (negative: never).
#It says whether the player is on the ledge, across the gap, when everything is over
func _hop(press: float, margin: float, rim: float, gap: float) -> bool:
	var player := _make(true)
	player.global_position = Vector3(0.0, HOP_TOP + 0.05, HOP_Z - rim + HOP_RUN)
	player.move_input = Vector2(0.0, -1.0)
	var jumped := false
	var clock := 0.0
	var pressed := false
	for step in 330:
		await physics_frame
		if not jumped and player.global_position.z < HOP_Z - rim + margin and player.is_on_floor():
			jumped = true
			player.jump_requested = true
		if jumped:
			clock += 1.0 / 60.0
			if press >= 0.0 and not pressed and clock >= press:
				pressed = true
				player.jump_requested = true
			#The keys are let go once the dive is on its way (or the jump is over): the rest is momentum
			if clock >= (press + 0.1 if press >= 0.0 else 1.0):
				player.move_input = Vector2.ZERO
	player.move_input = Vector2.ZERO
	var stays := player.global_position.y > HOP_TOP - 0.5 and player.global_position.z < HOP_Z - rim - gap
	player.queue_free()
	await _frames(2)
	return stays


func _run() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(260.0, 1.0, 260.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_scene.add_child(floor_body)
	await _frames(10)

	#The plain jump, the measure of everything else. The player stops on landing, so "reach" is the jump alone
	var plain := await _leap(_make(true), -1.0)
	var jump: float = plain["reach"]
	_check(plain["dives"] == 0, "un salto sin segunda pulsación no barre")
	_check(jump > 4.0 and jump < 5.2, "el salto normal cubre unos 4,5 m (%.2f m en %.2f s)" % [jump, plain["air"]])

	#The dive at the top of the jump
	var top := await _leap(_make(true), 0.46)
	var gain: float = top["reach"] / jump - 1.0
	_check(top["dives"] == 1, "una segunda pulsación en el aire lanza el barrido")
	_check(gain >= 0.4 and gain <= 0.75, "en lo alto del salto llega de 40 a 75 %% más lejos (%.2f m, +%d %%)" % [top["reach"], roundi(gain * 100.0)])
	_check(top["peak"] < plain["peak"] + 0.3, "su trayectoria es baja: no sube más que el salto (%.2f m contra %.2f m)" % [top["peak"], plain["peak"]])
	var grounded: float = top["free"] - top["landed"]
	var wanted := Player.DIVE_SLIDE_TIME + Player.DIVE_DOWN_TIME + Player.DIVE_RISE_TIME
	_check(absf(grounded - wanted) < 0.08, "tras aterrizar desliza, queda tendido y se levanta en %.2f s (%.2f s medidos)" % [wanted, grounded])

	#Every moment to press it: the best one gives the reach the levels are designed against
	var best := 0.0
	var best_at := 0.0
	var worst := INF
	var press := Player.DIVE_ARM_TIME
	while press < 0.9:
		var diver := _make(true)
		var result := await _leap(diver, press)
		diver.queue_free()
		if float(result["reach"]) > best:
			best = result["reach"]
			best_at = press
		worst = minf(worst, result["reach"])
		press += 0.06
	_check(best / jump - 1.0 >= 0.5 and best / jump - 1.0 <= 0.8,
		"pulsado en el mejor momento (%.2f s) llega de 50 a 80 %% más lejos (%.2f m, +%d %%)" % [best_at, best, roundi((best / jump - 1.0) * 100.0)])
	_check(best < Player.DIVE_MAX_REACH, "y nunca pasa del alcance máximo declarado (%.2f m < %.1f m)" % [best, Player.DIVE_MAX_REACH])
	_check(worst > jump, "en cualquier momento llega más lejos que el salto (%.2f m el peor)" % worst)

	#Once per jump, and never chained
	var twice := await _leap(_make(true), 0.3, 0.5)
	_check(twice["dives"] == 1, "solo se barre una vez por salto")
	var chained := _make(true)
	chained.move_input = Vector2(0.0, -1.0)
	await _frames(20)
	chained.jump_requested = true
	await _frames(24)
	var again := [0]
	chained.dive_started.connect(func(_direction: Vector3) -> void: again[0] += 1)
	chained.jump_requested = true
	var jumped_lying := false
	for step in 110:
		await physics_frame
		if chained.is_diving() and chained.is_on_floor():
			#The key is mashed all the way through the slide, the rest and the rise
			jumped_lying = jumped_lying or chained.velocity.y > 2.0
			chained.jump_requested = true
	_check(not jumped_lying and again[0] == 1, "deslizando, tendido o levantándose no se salta ni se vuelve a barrer")
	chained.move_input = Vector2.ZERO
	await _frames(70)
	chained.jump_requested = true
	await _frames(6)
	_check(not chained.is_on_floor() and not chained.is_diving(), "de pie otra vez, vuelve a saltar")

	#A press that comes too early waits for its moment
	var early := await _leap(_make(true), 0.04)
	_check(early["dives"] == 1 and float(early["started"]) >= Player.DIVE_ARM_TIME - 0.02,
		"una pulsación algo temprana se recuerda y sale a los %.2f s del despegue (%.2f s)" % [Player.DIVE_ARM_TIME, early["started"]])

	#No steering during the dive
	var committed := _make(true)
	committed.move_input = Vector2(0.0, -1.0)
	await _frames(20)
	committed.jump_requested = true
	await _frames(26)
	committed.jump_requested = true
	await _frames(3)
	var lane := committed.global_position.x
	committed.move_input = Vector2(1.0, 0.0)
	await _frames(70)
	_check(absf(committed.global_position.x - lane) < 0.15, "en el barrido no hay control: no se desvía (%.2f m)" % absf(committed.global_position.x - lane))
	committed.move_input = Vector2.ZERO

	#Without any input it dives toward where the model looks
	var still := _make(true)
	await _frames(10)
	var facing := still.look_direction()
	var start := still.global_position
	still.jump_requested = true
	await _frames(26)
	still.jump_requested = true
	await _frames(80)
	var moved := still.global_position - start
	moved.y = 0.0
	_check(moved.length() > 3.0 and moved.normalized().dot(facing) > 0.95, "sin dirección barre hacia donde mira (%.2f m)" % moved.length())

	#A blow cancels it and the blow goes on as ever
	var struck := _make(true)
	struck.move_input = Vector2(0.0, -1.0)
	await _frames(20)
	struck.jump_requested = true
	await _frames(26)
	struck.jump_requested = true
	await _frames(4)
	var was_diving := struck.is_diving()
	var blow := Player.Hit.new()
	blow.push = Vector3(6.0, 0.0, 0.0)
	blow.stun = 0.4
	blow.flips = true
	blow.strength = 0.7
	struck.take_hit(blow)
	_check(was_diving and not struck.is_diving() and struck.is_down(), "un golpe corta el barrido y tumba como siempre")
	struck.jump_requested = true
	await _frames(3)
	_check(not struck.is_diving(), "aturdido no se barre")
	struck.move_input = Vector2.ZERO
	await _frames(120)

	#Lying after a dive the player can be hit
	var lying := _make(true)
	lying.move_input = Vector2(0.0, -1.0)
	await _frames(20)
	lying.jump_requested = true
	await _frames(26)
	lying.jump_requested = true
	for step in 120:
		await physics_frame
		if lying.dive_phase == Player.Dive.DOWN:
			break
	_check(lying.dive_phase == Player.Dive.DOWN and lying.can_be_hit(), "tendido tras el barrido se le puede golpear")
	lying.move_input = Vector2.ZERO
	lying.clear_motion()
	_check(not lying.is_diving(), "recolocar al jugador (clear_motion) termina el barrido")

	#Not while posing, and not while a cannon throws
	var poser := _make(true)
	await _frames(10)
	poser.posing = true
	poser.jump_requested = true
	await _frames(10)
	_check(poser.is_on_floor() and not poser.is_diving(), "posando no se salta ni se barre")
	poser.posing = false
	var flyer := _make(true)
	await _frames(10)
	flyer.launch(Vector3(0.0, 9.0, -6.0))
	await _frames(12)
	flyer.jump_requested = true
	await _frames(4)
	_check(flyer.is_flying() and not flyer.is_diving(), "en el vuelo de un cañón no se barre")
	await _frames(150)

	#With the dive off the player is the one of always
	var off := await _leap(_make(false), 0.46)
	_check(off["dives"] == 0 and absf(float(off["reach"]) - jump) < 0.02,
		"con dive_enabled apagado el salto es idéntico (%.3f m contra %.3f m)" % [off["reach"], jump])

	#The leap of the course: the gap of the layout is too wide for a jump, and a dive pressed in a wide stretch of the jump lands on the ledge
	var hop: Dictionary = Level01Layout.HOPS[0]
	var rim := Level01Layout.radius_of(hop["from"])
	_disc(Vector3(0.0, HOP_TOP, HOP_Z), rim)
	_disc(Vector3(0.0, HOP_TOP, HOP_Z - rim - float(hop["gap"]) - float(hop["radius"])), float(hop["radius"]))
	await _frames(5)
	var alone := false
	var narrowest := 9.9
	var every := true
	for margin in [0.0, 0.3, 0.6]:
		alone = alone or await _hop(-1.0, margin, rim, float(hop["gap"]))
		var window := 0.0
		var moment := Player.DIVE_ARM_TIME
		while moment < 0.9:
			if await _hop(moment, margin, rim, float(hop["gap"])):
				window += 0.04
			moment += 0.04
		narrowest = minf(narrowest, window)
		every = every and window > 0.0
	_check(not alone, "el hueco del salto largo no se cruza con un salto normal, salga el salto desde donde salga")
	_check(every and narrowest >= 0.2, "con barrido se queda en el mirador: hay al menos 0,2 s para pulsarlo (%.2f s la peor salida)" % narrowest)

	#Every character has the moves
	for id in CHARACTERS:
		var model := (load("res://scenes/characters/%s.tscn" % id) as PackedScene).instantiate() as CharacterModel
		root.add_child(model)
		var all := true
		for move: StringName in [CharacterModel.DIVE, CharacterModel.SLIDE, CharacterModel.RISE, CharacterModel.SHOVE, CharacterModel.STAGGER]:
			all = all and model.has_move(move)
		_check(all and model.pose_count() >= 6, "%s tiene barrido, empujón, tambaleo y %d poses" % [id, model.pose_count()])
		model.queue_free()

	print("dive_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
