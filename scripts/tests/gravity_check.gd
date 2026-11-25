extends SceneTree

#Checks player gravity: normal unchanged frame by frame, turned safe; run with --fixed-fps 60

#Path of the scripted run sampled every SAMPLE_EVERY frames
const SAMPLE_EVERY := 10
const BASELINE: Array[float] = [
	0.00000, -0.00272, 0.00000, 0.00000, -0.04900, 0.00000, 0.00000, -0.04900, -0.08333, 0.00000, -0.04900, -0.91665,
	0.00000, -0.04900, -1.74997, 0.00000, -0.04900, -2.58329, 0.00000, 0.02600, -3.41661, 0.00000, 0.62628, -4.24994,
	0.00000, 0.95433, -5.10326, 0.00000, 1.01017, -6.13658, 0.00000, 0.79378, -7.16991, 0.00000, 0.30517, -8.20323,
	0.00000, -0.04910, -9.20704, 0.00000, -0.04910, -9.82212, 0.00000, -0.04910, -9.95990, 0.00000, -0.04910, -9.95990,
	0.00000, -0.04910, -9.95990, 0.00000, -0.04910, -9.95990, 0.00000, -0.04910, -9.95990, 0.04167, -0.04910, -10.01823,
	0.45837, 0.02595, -10.60159, 0.87505, 0.62622, -11.18491, 1.29173, 0.95428, -11.76824, 1.70841, 1.01011, -12.35156,
	2.12509, 0.79372, -12.93489, 2.54177, 0.30511, -13.51821, 2.91678, -0.04910, -14.04320, 3.01682, 0.00092, -14.04320,
	3.74182, 0.35120, -14.04320, 3.96682, 0.42925, -14.04320, 3.96682, 0.23508, -14.04320, 3.96682, -0.04854, -14.04320,
	3.96682, -0.04854, -14.04320, 3.96682, 0.00013, -13.90987, 3.96682, 0.33707, -12.85154, 3.96682, 0.40179, -12.29320,
	3.96682, 0.19429, -12.19820, 3.96682, -0.04854, -12.19820, 3.96682, -0.04854, -12.19820, 3.96682, -0.04854, -12.19820,
	3.96682, -0.04854, -12.19820, 3.96682, -0.04854, -12.19820, 3.96682, -0.04854, -12.19820, 3.96682, -0.04854, -12.19820,
	3.96682, -0.04854, -12.19820, 3.96682, -0.04854, -12.19820, 3.96682, -0.04854, -12.19820, 3.96682, -0.04854, -12.19820
]
const TOLERANCE := 0.0001

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


func _make() -> Player:
	var player := (load("res://scenes/characters/player.tscn") as PackedScene).instantiate() as Player
	_scene.add_child(player)
	player.player_id = _next_id
	player.global_position = Vector3(_next_id * 12.0 - 60.0, 0.05, 40.0)
	_next_id += 1
	(player.get_node("PlayerInput") as Node).set_physics_process(false)
	player.set_character(load("res://resources/characters/fire.tres") as CharacterData)
	player.dive_enabled = true
	return player


#Runs, jumps, dives, turns, takes a push and a flip while sampling
func _trace(player: Player) -> Array[float]:
	var path: Array[float] = []
	var origin := player.global_position
	for frame in 480:
		match frame:
			20:
				player.move_input = Vector2(0.0, -1.0)
			60, 80, 200:
				player.jump_requested = true
			140:
				player.move_input = Vector2(1.0, 0.0)
			190:
				player.move_input = Vector2(0.5, -0.7)
			260:
				player.move_input = Vector2.ZERO
			270:
				player.apply_push(Vector3(6.0, 3.0, 0.0))
			330:
				var hit := Player.Hit.new()
				hit.push = Vector3(0.0, 0.0, 8.0)
				hit.stun = 0.4
				hit.flips = true
				hit.strength = 0.6
				player.take_hit(hit)
		await physics_frame
		if frame % SAMPLE_EVERY == 0:
			var offset := player.global_position - origin
			path.append_array([offset.x, offset.y, offset.z])
	return path


func _run() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_scene.add_child(floor_body)
	await _frames(10)

	var path := await _trace(_make())
	if OS.get_cmdline_user_args().has("baseline"):
		var numbers: PackedStringArray = []
		for value in path:
			numbers.append("%.5f" % value)
		print("BASELINE ", ", ".join(numbers))
		quit(0)
		return
	var worst := 0.0
	for index in mini(path.size(), BASELINE.size()):
		worst = maxf(worst, absf(path[index] - BASELINE[index]))
	_check(path.size() == BASELINE.size() and worst < TOLERANCE,
		"con la gravedad normal el recorrido es el de siempre (%.0f muestras, desvío máximo %.6f m)" % [path.size() / 3.0, worst])
	await _turned()
	print("FALLOS: %d" % _failures if _failures > 0 else "OK")
	quit(1 if _failures > 0 else 0)


#Ceiling test: float up, stand, jump down, no dive, speed cap and soft return
const CEILING := 6.0


func _turned() -> void:
	var ceiling := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 1.0, 30.0)
	shape.shape = box
	ceiling.add_child(shape)
	ceiling.position = Vector3(40.0, CEILING + 0.5, -40.0)
	_scene.add_child(ceiling)
	var player := _make()
	player.global_position = Vector3(40.0, 0.05, -40.0)
	var changes := [0]
	var count := func(_pull_sign: float, _pull_scale: float) -> void: changes[0] += 1
	player.gravity_changed.connect(count)
	var model := player.find_children("*", "CharacterModel", true, false)[0] as Node3D
	await _frames(20)

	player.set_gravity_state(-1.0, 0.35)
	player.set_gravity_state(-1.0, 0.35)
	var fastest := 0.0
	var rise := 0.0
	for step in 240:
		await physics_frame
		fastest = maxf(fastest, absf(player.velocity.y))
		if player.is_on_floor() and player.global_position.y > CEILING - 1.5:
			break
		rise += 1.0 / 60.0
	await _frames(20)
	var head_down := model.global_basis.y.dot(Vector3.DOWN) > 0.95
	_check(player.is_on_floor() and player.global_position.y > CEILING - 1.1,
		"con la gravedad al revés sube y se queda de pie en el techo (en %.2f s, a %.2f m)" % [rise, player.global_position.y])
	_check(head_down, "el cuerpo queda dado vuelta, con los pies en el techo")
	_check(changes[0] == 1 and player.up_direction == Vector3.DOWN, "avisa una sola vez del cambio y el arriba del cuerpo es hacia abajo")
	_check(fastest <= Player.FLOAT_MAX_SPEED + 0.01, "nunca pasa de %.1f m/s en vertical (%.2f m/s)" % [Player.FLOAT_MAX_SPEED, fastest])

	player.jump_requested = true
	await _frames(2)
	var jumped_down := player.velocity.y < -1.0
	player.jump_requested = true
	await _frames(15)
	player.jump_requested = true
	await _frames(15)
	_check(jumped_down and not player.is_diving(), "el salto va hacia el piso de enfrente y no se puede barrer")

	for step in 120:
		await physics_frame
		if player.is_on_floor():
			break
	var hard := [false]
	var landing := func(_at: Vector3, was_hard: bool) -> void: hard[0] = hard[0] or was_hard
	player.landed.connect(landing)
	player.jump_requested = true
	await _frames(3)
	player.set_gravity_state(1.0, 1.0)
	var fall := 0.0
	var steps := 0
	while not player.is_on_floor() and steps < 400:
		await physics_frame
		steps += 1
		fall = maxf(fall, -player.velocity.y)
	await _frames(30)
	_check(player.is_on_floor() and player.global_position.y < 0.3, "de vuelta a la gravedad normal cae al piso (%.2f m)" % player.global_position.y)
	_check(fall <= Player.SAFE_FALL_SPEED + 0.01, "y cae suave, a %.1f m/s como mucho (%.2f m/s)" % [Player.SAFE_FALL_SPEED, fall])
	_check(not hard[0] and not player.is_dazed() and not player.is_down(), "aterriza sin golpe, sin aturdirse y de pie")
	_check(model.global_basis.y.dot(Vector3.UP) > 0.95 and player.up_direction == Vector3.UP, "el cuerpo vuelve a quedar derecho")

	player.set_gravity_state(-1.0, 0.35)
	await _frames(10)
	player.clear_motion()
	_check(player.is_gravity_normal(), "al ponerlo de vuelta en un lugar la gravedad vuelve a ser la normal")
