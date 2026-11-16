extends SceneTree

#Checks "El Estudio" of the perfect selfie with real bodies: the collisions match the plan with no hole, nobody leaves the studio
#jumping and diving at its walls, every way of the graph is walked for real at a fifth less than full speed, both trampolines put a
#body on the podium, the pit is left by its ramp and not with a jump, the tricks of the floor move real bodies, a real jump rises as
#the rules count it, and in the round itself a jump right at the shot comes out, at the edge and in the middle of the frame.
#Run: godot --headless --fixed-fps 60 --path . --script res://scripts/tests/studio_check.gd

const GRID := 1.5
const SHARE := 0.8
#Seconds a walker gets for a way on top of what the graph says it costs at a fifth less speed
const WALK_SLACK := 2.5
const STEP := 1.0 / 60.0

var _failures := 0
var _scene: Node3D
var _layout := SelfieLayout.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _floor: SelfieFloor
var _next_id := 100


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _frames(count: int) -> void:
	for step in count:
		await physics_frame


func _run() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	var stage := SelfieStage.new()
	_scene.add_child(stage)
	stage.build(_layout)
	_floor = SelfieFloor.new(_layout)
	await _frames(5)
	await _check_rain()
	await _check_walls()
	await _check_links()
	await _check_trampolines()
	await _check_pit()
	await _check_jump()
	await _check_tricks()
	_scene.queue_free()
	await _frames(3)
	await _check_round()
	print("studio_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


#Capsules dropped all over the studio land exactly where the plan says the floor is, on top of everything and under the catwalk
func _check_rain() -> void:
	var drops: Array[Dictionary] = []
	var x := -SelfieLayout.HALF.x
	while x <= SelfieLayout.HALF.x:
		var z := -SelfieLayout.HALF.y
		while z <= SelfieLayout.HALF.y:
			if _layout.is_inside(x, z, 0.6) and _clear_of_edges(x, z, INF):
				drops.append(_drop(x, z, _layout.height_at(x, z)))
			var low := _layout.height_at(x, z, 1.0)
			if low < _layout.height_at(x, z) - 1.5 and not _layout.solid_at(Vector3(x, low + 0.6, z)) and _layout.is_inside(x, z, 0.6) and _clear_of_edges(x, z, 1.0) and not _near_pillar(x, z):
				drops.append(_drop(x, z, low))
			z += GRID
		x += GRID
	for step in 90:
		await physics_frame
		for drop in drops:
			var body: CharacterBody3D = drop["body"]
			body.velocity.y -= _gravity * STEP
			body.move_and_slide()
	var wrong := 0
	var sample := ""
	for drop in drops:
		var body: CharacterBody3D = drop["body"]
		if absf(body.global_position.y - float(drop["floor"])) > 0.15:
			wrong += 1
			if sample == "":
				sample = "(%.1f, %.1f) quedó a %.2f y el plano dice %.2f" % [body.global_position.x, body.global_position.z, body.global_position.y, drop["floor"]]
		body.queue_free()
	_check(wrong == 0 and drops.size() > 500, "%d cápsulas caen donde dice el plano, encima de todo y bajo la pasarela, sin huecos %s" % [drops.size(), sample])


func _drop(x: float, z: float, floor_height: float) -> Dictionary:
	var body := _capsule()
	_scene.add_child(body)
	body.global_position = Vector3(x, floor_height + 0.6, z)
	return {"body": body, "floor": floor_height}


#The edge of a piece is where a capsule may rest half on it: those spots are left out of the rain
func _clear_of_edges(x: float, z: float, ceiling: float) -> bool:
	var here := _layout.height_at(x, z, ceiling)
	for offset: Vector2 in [Vector2(0.45, 0.0), Vector2(-0.45, 0.0), Vector2(0.0, 0.45), Vector2(0.0, -0.45), Vector2(0.32, 0.32), Vector2(-0.32, 0.32), Vector2(0.32, -0.32), Vector2(-0.32, -0.32)]:
		if absf(_layout.height_at(x + offset.x, z + offset.y, ceiling) - here) > 0.12:
			return false
	return true


func _near_pillar(x: float, z: float) -> bool:
	for pillar in SelfieLayout.RUNWAY_PILLARS:
		if Vector2(x, z).distance_to(pillar) < SelfieLayout.PILLAR_RADIUS + 0.5:
			return true
	return false


#Players run at the walls from the inside all around the studio and from the top of the podium, the runway, the live stage and
#the dance floor, jumping and diving: none gets out, none ends under the floor
func _check_walls() -> void:
	var runners: Array[Player] = []
	var count := _layout.outline.size()
	for index in count:
		var from := _layout.outline[index]
		var to := _layout.outline[(index + 1) % count]
		var steps := maxi(roundi(from.distance_to(to) / 3.0), 1)
		for step in steps:
			var edge := from.lerp(to, (step + 0.5) / steps)
			var inward := -edge.normalized()
			var start := edge + inward * 5.0 + Vector2(0.13, 0.17)
			runners.append(_runner(Vector3(start.x, _layout.height_at(start.x, start.y) + 0.1, start.y), -inward))
	for spot: Vector3 in [Vector3(-21.3, SelfieLayout.PODIUM_TOP, 0.2), Vector3(0.3, SelfieLayout.UPPER, -10.3), Vector3(10.6, SelfieLayout.LIVE_TOP, 7.9),
			Vector3(20.2, 0.0, 0.2)]:
		for turn in 4:
			runners.append(_runner(spot + Vector3(0.0, 0.1, 0.0), Vector2.RIGHT.rotated(TAU * turn / 4.0 + 0.2)))
	await _frames(10)
	for step in 300:
		for player in runners:
			player.move_input = Vector2(0.0, -1.0)
			if step % 70 == 20 or step % 70 == 62:
				player.jump_requested = true
		await physics_frame
	var out := 0
	var under := 0
	var lost := ""
	for player in runners:
		var at := player.global_position
		out += int(not _layout.is_inside(at.x, at.z, 0.0))
		under += int(at.y < ArenaLayout.GROUND - 0.2)
		if lost == "" and (not _layout.is_inside(at.x, at.z, 0.0) or at.y < ArenaLayout.GROUND - 0.2):
			lost = " (uno quedó en %s)" % at.snappedf(0.1)
		player.queue_free()
	_check(out == 0 and under == 0, "%d corredores contra las paredes y desde lo alto, con salto y barrido: ninguno sale (%d) ni queda bajo el piso (%d)%s" % [
		runners.size(), out, under, lost])
	await _frames(3)


func _runner(at: Vector3, heading: Vector2) -> Player:
	var player := _player(at)
	(player.get_node("CameraRig") as Node3D).rotation.y = atan2(heading.x, heading.y) + PI
	return player


#Every way of the graph walked for real, both ways, at a fifth less than full speed: a body that goes straight from one place to the
#other arrives in time
func _check_links() -> void:
	var walkers: Array[Dictionary] = []
	for entry in _layout.links:
		if entry.kind != ArenaLayout.WALK:
			continue
		walkers.append(_walker(entry.a, entry.b, entry.seconds))
		walkers.append(_walker(entry.b, entry.a, entry.back))
	await _frames(5)
	var longest := 0.0
	for walker in walkers:
		longest = maxf(longest, float(walker["limit"]))
	for step in ceili(longest * 60.0):
		for walker in walkers:
			if walker["done"]:
				continue
			var player: Player = walker["player"]
			var to: Vector3 = walker["to"]
			var way := Vector3(to.x - player.global_position.x, 0.0, to.z - player.global_position.z)
			if way.length() < float(walker["near"]) and absf(player.global_position.y - to.y) < 0.4:
				walker["done"] = true
				player.move_input = Vector2.ZERO
				continue
			if step > float(walker["limit"]) * 60.0:
				continue
			player.move_input = Vector2(way.normalized().x, way.normalized().z)
		await physics_frame
	var failed: Array[String] = []
	for walker in walkers:
		if not walker["done"]:
			var player: Player = walker["player"]
			failed.append("%s>%s quedó en %s" % [walker["a"], walker["b"], player.global_position.snappedf(0.1)])
		(walker["player"] as Player).queue_free()
	_check(failed.is_empty(), "sus %d tramos a pie se caminan de verdad, de ida y de vuelta, al 80 %% de velocidad %s" % [walkers.size(), failed])
	await _frames(3)


func _walker(a: StringName, b: StringName, seconds: float) -> Dictionary:
	var player := _player(_layout.position_of(a) + Vector3(0.0, 0.1, 0.0))
	player.move_speed *= SHARE
	return {"player": player, "a": a, "b": b, "to": _layout.position_of(b), "near": maxf(_layout.radius_of(b) * 0.6, 0.6),
		"limit": seconds / SHARE + WALK_SLACK, "done": false}


#From the trampoline, running at a fifth less toward the podium, a body ends on top of it; the cannon throws whoever steps on it onto
#the runway with no help
func _check_trampolines() -> void:
	var jumpers: Array[Dictionary] = []
	for pad in _layout.pads:
		var player := _player((pad["at"] as Vector3) + Vector3(0.0, 0.1, 0.0))
		player.move_speed *= SHARE
		jumpers.append({"player": player, "pad": pad, "peak": 0.0, "rest": 0.0})
	await _frames(10)
	var podium := SelfieLayout.PODIUM.get_center()
	for step in 240:
		for jumper in jumpers:
			var player: Player = jumper["player"]
			var at := player.global_position
			var cannon := ArenaHazards.is_cannon(jumper["pad"])
			jumper["rest"] = maxf(float(jumper["rest"]) - STEP, 0.0)
			if float(jumper["rest"]) <= 0.0 and player.velocity.y <= 0.5 and not player.is_flying() and ArenaHazards.pad_hits(jumper["pad"], at):
				if cannon:
					player.launch(ArenaHazards.pad_launch(jumper["pad"], _gravity))
				else:
					player.apply_push(ArenaHazards.pad_launch(jumper["pad"], _gravity))
				jumper["rest"] = 0.5
			jumper["peak"] = maxf(float(jumper["peak"]), at.y)
			var way := Vector2(podium.x - at.x, podium.y - at.z)
			player.move_input = way.normalized() if not cannon and (player.velocity.y > 1.0 or at.y > 1.0) else Vector2.ZERO
		await physics_frame
	var fine := true
	var text := ""
	for jumper in jumpers:
		var player: Player = jumper["player"]
		var at := player.global_position
		if ArenaHazards.is_cannon(jumper["pad"]):
			fine = fine and absf(at.y - SelfieLayout.UPPER) < 0.1 and SelfieLayout.RUNWAY.has_point(Vector2(at.x, at.z))
		else:
			fine = fine and absf(at.y - SelfieLayout.PODIUM_TOP) < 0.1 and SelfieLayout.PODIUM.has_point(Vector2(at.x, at.z))
		text += " %s a %.2f m (cumbre %.2f)" % [Vector2(at.x, at.z).snappedf(0.1), at.y, jumper["peak"]]
		player.queue_free()
	_check(fine, "desde el trampolín, corriendo al 80 %%, se cae sobre el podio de %.1f m, y el cañón deja sobre la pasarela de %.1f m:%s" % [
		SelfieLayout.PODIUM_TOP, SelfieLayout.UPPER, text])
	await _frames(3)


#The pool of balls: its foam curb stops a walk, and a jump goes over it, in and out
func _check_pit() -> void:
	var centre := Vector3(SelfieLayout.POOL_CENTER.x, 0.1, SelfieLayout.POOL_CENTER.y)
	var walker := _player(centre + Vector3(0.13, 0.0, -0.4))
	var leaper := _player(centre + Vector3(0.13, 0.0, 0.4))
	var comer := _player(centre + Vector3(SelfieLayout.POOL_OUTER + 2.5, 0.0, 0.13))
	await _frames(5)
	for step in 240:
		walker.move_input = Vector2(1.0, 0.0)
		leaper.move_input = Vector2(1.0, 0.0)
		comer.move_input = Vector2(-1.0, 0.0) if step < 100 else Vector2.ZERO
		if step % 40 == 20:
			leaper.jump_requested = true
			comer.jump_requested = true
		await physics_frame
	var flat := func(player: Player) -> float: return Vector2(player.global_position.x - centre.x, player.global_position.z - centre.z).length()
	_check(flat.call(walker) < SelfieLayout.POOL_INNER, "caminando contra el bordillo de %.1f m no se sale de la piscina (queda a %.1f m del centro)" % [
		SelfieLayout.POOL_WALL, flat.call(walker)])
	_check(flat.call(leaper) > SelfieLayout.POOL_OUTER and flat.call(comer) < SelfieLayout.POOL_INNER,
		"saltando se sale de la piscina (a %.1f m del centro) y se entra (a %.1f m)" % [flat.call(leaper), flat.call(comer)])
	for player: Player in [walker, leaper, comer]:
		player.queue_free()
	await _frames(3)


#A real jump rises as high as the rules count it
func _check_jump() -> void:
	var player := _player(Vector3(-6.0, 0.1, -3.0))
	await _frames(20)
	var ground := player.global_position.y
	var peak := ground
	player.jump_requested = true
	for step in 70:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
	var counted := SelfieRules.jump_height_of(player.jump_velocity)
	_check(absf(peak - ground - counted) < 0.03, "un salto real sube %.3f m y las reglas cuentan %.3f m" % [peak - ground, counted])
	player.queue_free()
	await _frames(3)


#The tricks move real bodies, applied as the round applies them
func _check_tricks() -> void:
	var spun := _player(Vector3(3.0, 0.1, 0.13))
	var waxed := _player(Vector3(SelfieLayout.DANCE_CENTER.x - 2.5, 0.1, SelfieLayout.DANCE_CENTER.y - 1.5))
	var dry := _player(Vector3(-12.0, 0.1, 2.0))
	var carpet := _player(Vector3(SelfieLayout.CARPET.position.x + 1.0, 0.1, SelfieLayout.CARPET.get_center().y))
	var bounced := _player(Vector3(SelfieLayout.POOL_CENTER.x + 0.13, 2.4, SelfieLayout.POOL_CENTER.y))
	var bodies: Array[Player] = [spun, waxed, dry, carpet, bounced]
	await _frames(15)
	var spun_from := spun.global_position
	var marks := {}
	var carpet_from := Vector3.ZERO
	var bounce_peak := -INF
	var landed_once := false
	for step in 150:
		waxed.move_input = Vector2(1.0, 0.0) if step < 60 else Vector2.ZERO
		dry.move_input = Vector2(1.0, 0.0) if step < 60 else Vector2.ZERO
		carpet.move_input = Vector2(1.0, 0.0) if step >= 30 and step < 90 else Vector2.ZERO
		if step == 60:
			marks[waxed] = waxed.global_position
			marks[dry] = dry.global_position
		if step == 30:
			carpet_from = carpet.global_position
		if step == 90:
			marks[carpet] = carpet.global_position
		for player in bodies:
			_apply_floor(player)
		if bounced.is_on_floor():
			landed_once = true
		elif landed_once:
			bounce_peak = maxf(bounce_peak, bounced.global_position.y)
		await physics_frame
	var arc := spun.global_position.distance_to(spun_from)
	var radius := Vector2(spun.global_position.x, spun.global_position.z).length()
	_check(arc > 2.5 and absf(radius - 3.0) < 0.5, "el giratorio lleva a quien está quieto a 3 m del centro: %.1f m en 2,5 s y sigue a %.1f m del centro" % [arc, radius])
	var slide := waxed.global_position.distance_to(marks[waxed])
	var stop := dry.global_position.distance_to(marks[dry])
	_check(slide > 0.8 and stop < 0.3, "en el encerado, al soltar la carrera, se resbala %.1f m; en el piso normal %.2f m" % [slide, stop])
	var pace := (marks[carpet] as Vector3).distance_to(carpet_from)
	_check(pace < 5.0 * SelfieFloor.CARPET_SPEED + 0.2 and pace > 1.0, "en la alfombra se corre más lento: %.1f m en 1 s (%.1f m/s fuera)" % [pace, carpet.move_speed / SelfieFloor.CARPET_SPEED])
	_check(bounce_peak > ArenaLayout.GROUND + 0.3, "quien cae desde 2,4 m al piso de la piscina rebota hasta %.2f m sobre él" % (bounce_peak - ArenaLayout.GROUND))
	for player in bodies:
		player.queue_free()
	await _frames(3)


#As the round does it: the drag or the slide of the floor, the slow carpet and the bounce of the mattress
func _apply_floor(player: Player) -> void:
	var rig := player.get_node("CameraRig") as PlayerCamera
	var base_speed := 5.0
	var wanted := rig.get_yaw_basis() * Vector3(player.move_input.x, 0.0, player.move_input.y) * player.move_speed
	var effect := _floor.step(player.player_id, player.global_position, player.is_on_floor(), wanted, player.velocity.y, STEP)
	player.external_velocity = effect.drift
	player.move_speed = base_speed * effect.speed_scale
	if effect.bounce > 0.0:
		player.apply_push(Vector3(player.push_velocity.x, effect.bounce, player.push_velocity.z))


#A spot "reach" meters from the middle of the frame (or the nearest one farther out), on its plain floor and clear of the pads of a
#set by the width of a body
func _clear_spot(layout: SelfieLayout, centre: Vector3, reach: float) -> Vector3:
	for ring: float in [reach, reach + 0.6, reach + 1.2, reach + 1.8, reach + 2.4]:
		for turn in 16:
			var angle := TAU * turn / 16.0
			var spot := centre + Vector3(cos(angle) * ring, 0.05, sin(angle) * ring + 0.13)
			var plain := true
			for around in 8:
				var edge := spot + Vector3(cos(TAU * around / 8.0), 0.0, sin(TAU * around / 8.0)) * 0.45
				plain = plain and absf(layout.height_at(edge.x, edge.z, centre.y + 0.5) - centre.y) < 0.01
			if plain:
				return spot
	return centre + Vector3(reach, 0.05, 0.13)


#The round itself: a jump right at the shot, at the edge of the frame and then in its middle, comes out in the photo, where the
#photo sees the player is where the rules saw it, and the photo comes out at its size
func _check_round() -> void:
	root.get_node("GameState").select_character(1, load("res://resources/characters/fire.tres") as CharacterData)
	var scene: Variant = (load("res://scenes/levels/perfect_selfie.tscn") as PackedScene).instantiate()
	scene.hazards_enabled = false
	scene.bots_enabled = false
	root.add_child(scene)
	current_scene = scene
	var player: Player = scene.local_player()
	(player.get_node("PlayerInput") as Node).set_physics_process(false)
	var rules: SelfieRules = scene.rules
	var shots: Array[Dictionary] = []
	var feet: Array[Array] = []
	rules.photo_taken.connect(func(_index: int, taken: Dictionary) -> void:
		shots.append(taken)
		feet.append((scene.rules as SelfieRules).photo_feet.duplicate()))
	var photos: Array[Texture2D] = []
	var camera: SelfieCamera = scene._camera
	camera.developed.connect(func(_index: int, photo: Texture2D) -> void: photos.append(photo))
	var offsets: Array[float] = [0.5, 0.0]
	for photo in offsets.size():
		while rules.phase != SelfieRules.Phase.LOCK or rules.photo_index != photo:
			await physics_frame
		var centre := rules.frame_center()
		var spot := _clear_spot(rules.layout, centre, (rules.final_size(photo) / 2.0 - 0.2) * offsets[photo] * 2.0)
		#On the unboxing it waits on a box of the frame that will not pop before the shot
		if rules.layout.unbox_cell(spot) >= 0:
			for cell in SelfieLayout.UNBOX_GRID * SelfieLayout.UNBOX_GRID:
				var box := rules.layout.unbox_center(cell)
				var phase := SelfieLayout.unbox_phase(cell, float(scene.clock))
				var in_frame := absf(box.x - centre.x) < rules.final_size(photo) / 2.0 - 0.3 and absf(box.z - centre.z) < rules.final_size(photo) / 2.0 - 0.3
				if in_frame and phase > SelfieLayout.UNBOX_POP and SelfieLayout.UNBOX_PERIOD - phase > rules.time_left + 0.6:
					spot = box + Vector3(0.0, 0.05, 0.13)
					break
		var jumped := false
		player.global_position = spot
		player.velocity = Vector3.ZERO
		while rules.phase == SelfieRules.Phase.LOCK:
			if not jumped:
				#It stays on its spot but falls the last centimetres onto the floor of the set by itself
				player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
				player.velocity = Vector3(0.0, player.velocity.y, 0.0)
				player.external_velocity = Vector3.ZERO
				if rules.time_left < 0.45 and player.is_on_floor():
					player.jump_requested = true
					jumped = true
			await physics_frame
	await _frames(5)
	for index in offsets.size():
		var shot: SelfieRules.Shot = shots[index][scene.local_id]
		var where := "en el borde" if offsets[index] > 0.0 else "en el centro"
		_check(shot.inside and shot.airborne and shot.at.y > 0.2 + rules.layout.position_of(rules.order[index]).y and (feet[index] as Array).has(shot.at),
			"en la ronda, un salto justo al disparo %s sale en la foto (en el aire a %.2f m sobre el piso, %d seguidores) y la foto lo encuadra donde las reglas lo vieron" % [
				where, shot.at.y - rules.layout.position_of(rules.order[index]).y, shot.followers])
	_check(photos.size() == offsets.size() and photos[0].get_size() == Vector2(SelfieCamera.PHOTO_PIXELS), "cada disparo saca una foto de %dx%d" % [SelfieCamera.PHOTO_PIXELS.x, SelfieCamera.PHOTO_PIXELS.y])
	scene.queue_free()
	await _frames(3)


func _capsule() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.5
	body.add_child(collider)
	body.collision_layer = 2
	body.collision_mask = 1
	return body


func _player(at: Vector3) -> Player:
	var player := (load("res://scenes/characters/player.tscn") as PackedScene).instantiate() as Player
	_scene.add_child(player)
	player.global_position = at
	player.player_id = _next_id
	_next_id += 1
	(player.get_node("PlayerInput") as Node).set_physics_process(false)
	player.dive_enabled = true
	player.collision_layer = 2
	player.collision_mask = 1
	return player
