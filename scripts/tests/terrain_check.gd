extends SceneTree

#Checks La Plaza with real physics: collisions, fence, links, reach and trampolines

const GRID := 1.5
const FENCE_STEP := 3.0
#Seconds a walker gets for a link on top of what the graph says it costs
const WALK_SLACK := 2.5
#Seconds to climb back after a fall
const BACK_UP := Vector2(1.2, 9.0)

var _failures := 0
var _scene: Node3D


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
	await _check_map("La Plaza", TrendLayout.new())
	_check_points(TrendLayout.new())
	await _check_pads(TrendLayout.new())
	print("terrain_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _check_map(title: String, layout: ArenaLayout) -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	var world := ArenaWorld.new()
	_scene.add_child(world)
	world.build(layout)
	await _frames(5)
	_check_graph(title, layout)
	await _check_rain(title, layout)
	await _check_fence(title, layout)
	await _check_links(title, layout)
	_scene.queue_free()
	await _frames(3)


#Every place is reachable and the way back after a fall is short
func _check_graph(title: String, layout: ArenaLayout) -> void:
	var graph := layout.build_graph()
	var costs := graph.costs_from(layout.spawn_place)
	var lost: Array[StringName] = []
	for id: StringName in layout.places:
		if not costs.has(id):
			lost.append(id)
	_check(lost.is_empty(), "%s: desde el inicio se llega a sus %d lugares %s" % [title, layout.places.size(), lost])
	var back := graph.costs_from(layout.spawn_place)
	var stuck: Array[StringName] = []
	for id: StringName in layout.places:
		if not graph.costs_from(id).has(layout.spawn_place):
			stuck.append(id)
	_check(stuck.is_empty(), "%s: de todo lugar se vuelve al inicio (sin rincones sin salida) %s" % [title, stuck])
	var levels: Dictionary = {}
	var worst := Vector2(INF, 0.0)
	var slowest: StringName = &""
	for id: StringName in layout.places:
		var height := layout.position_of(id).y
		levels[snappedf(height, 0.1)] = true
		if height < 1.0:
			continue
		#A fall lands where its step down leads, or the closest lower place
		var below: StringName = &""
		var nearest := INF
		for entry in layout.links:
			if entry.kind == ArenaLayout.DROP and entry.a == id:
				below = entry.b
		if below == &"":
			for other: StringName in layout.places:
				var flat := Vector2(layout.position_of(other).x - layout.position_of(id).x, layout.position_of(other).z - layout.position_of(id).z).length()
				if layout.position_of(other).y < height - 1.0 and flat < nearest:
					nearest = flat
					below = other
		var seconds: float = graph.costs_from(below).get(id, INF)
		if seconds > worst.y:
			slowest = id
		worst = Vector2(minf(worst.x, seconds), maxf(worst.y, seconds))
	_check(levels.size() >= 3, "%s: tiene al menos tres alturas de terreno (%d)" % [title, levels.size()])
	_check(worst.x >= BACK_UP.x and worst.y <= BACK_UP.y, "%s: volver arriba tras caer cuesta de %.1f a %.1f s (lo más lento, %s)" % [title, worst.x, worst.y, slowest])
	_check(back.size() > 0 and layout.top_height() >= 4.5, "%s: el nivel alto llega a %.1f m" % [title, layout.top_height()])


#Capsules dropped all over land where the layout says
func _check_rain(title: String, layout: ArenaLayout) -> void:
	var drops: Array[CharacterBody3D] = []
	var reach := layout.reach()
	var x := -reach
	while x <= reach:
		var z := -reach
		while z <= reach:
			if layout.is_inside(x, z, 0.8) and _clear_of_edges(layout, x, z):
				var body := _capsule()
				_scene.add_child(body)
				body.global_position = Vector3(x, layout.height_at(x, z) + 1.2, z)
				drops.append(body)
			z += GRID
		x += GRID
	for step in 90:
		await physics_frame
		for body in drops:
			body.velocity.y -= 9.8 / 60.0
			body.move_and_slide()
	var wrong := 0
	var lowest := INF
	var sample := ""
	for body in drops:
		var at := body.global_position
		lowest = minf(lowest, at.y)
		if absf(at.y - layout.height_at(at.x, at.z)) > 0.3:
			wrong += 1
			if sample == "":
				sample = "(%.1f, %.1f) quedó a %.2f y el plano dice %.2f" % [at.x, at.z, at.y, layout.height_at(at.x, at.z)]
		body.queue_free()
	_check(wrong == 0, "%s: %d cápsulas caen donde dice el plano, sin huecos %s" % [title, drops.size(), sample])
	_check(lowest > -0.1, "%s: ninguna baja del suelo (la más baja a %.2f m)" % [title, lowest])


#Capsules resting half on an edge are skipped
func _clear_of_edges(layout: ArenaLayout, x: float, z: float) -> bool:
	var here := layout.height_at(x, z)
	for offset: Vector2 in [Vector2(0.45, 0.0), Vector2(-0.45, 0.0), Vector2(0.0, 0.45), Vector2(0.0, -0.45), Vector2(0.32, 0.32), Vector2(-0.32, 0.32), Vector2(0.32, -0.32), Vector2(-0.32, -0.32)]:
		if absf(layout.height_at(x + offset.x, z + offset.y) - here) > 0.25:
			return false
	return true


#Players running and diving at the edges never get out or under the floor
func _check_fence(title: String, layout: ArenaLayout) -> void:
	var runners: Array[Player] = []
	var starts: Array[Array] = []
	for island in layout.islands:
		var shape: PackedVector2Array = island["outline"]
		var middle := Vector2.ZERO
		for corner in shape:
			middle += corner / shape.size()
		var travelled := 0.0
		for index in shape.size():
			var from := shape[index]
			var to := shape[(index + 1) % shape.size()]
			var length := from.distance_to(to)
			while travelled < length:
				var edge := from.lerp(to, travelled / length)
				var inward := (middle - edge).normalized()
				starts.append([edge + inward * 5.0 + Vector2(0.13, 0.17), inward])
				travelled += FENCE_STEP
			travelled -= length
	for bridge in layout.bridges:
		var from: Vector3 = bridge["from"]
		var to: Vector3 = bridge["to"]
		var way := Vector2(to.x - from.x, to.z - from.z).normalized()
		for share: float in [0.3, 0.5, 0.7]:
			var at := Vector2(from.x, from.z).lerp(Vector2(to.x, to.z), share)
			for side: float in [-1.0, 1.0]:
				starts.append([at, Vector2(-way.y, way.x) * -side])
	for start: Array in starts:
		var spot: Vector2 = start[0]
		var inward: Vector2 = start[1]
		var player := _player(Vector3(spot.x, layout.height_at(spot.x, spot.y) + 0.1, spot.y))
		(player.get_node("CameraRig") as Node3D).rotation.y = atan2(inward.x, inward.y)
		runners.append(player)
	await _frames(10)
	for step in 260:
		for player in runners:
			player.move_input = Vector2(0.0, -1.0)
			#Every runner jumps and then dives again and again
			if step % 70 == 20 or step % 70 == 62:
				player.jump_requested = true
		await physics_frame
	var out := 0
	var under := 0
	for player in runners:
		var at := player.global_position
		if not layout.is_inside(at.x, at.z, 0.0):
			out += 1
		if at.y < -0.2:
			under += 1
		player.queue_free()
	_check(out == 0, "%s: %d corredores contra el borde de cada isla y de cada puente, con salto y barrido: ninguno sale (%d fuera)" % [title, runners.size(), out])
	_check(under == 0, "%s: ninguno queda bajo el suelo" % title)
	#From the top of every block, a jump and a dive outward always end on the ground
	var jumpers: Array[Player] = []
	for block in layout.blocks:
		if block["wall"] or float(block["top"]) < 1.0:
			continue
		var centre: Vector2 = block["center"]
		for turn in 4:
			var heading := Vector2.RIGHT.rotated(TAU * turn / 4.0 + float(block["yaw"]))
			var jumper := _player(Vector3(centre.x, float(block["top"]) + 0.1, centre.y))
			(jumper.get_node("CameraRig") as Node3D).rotation.y = atan2(-heading.x, -heading.y)
			jumpers.append(jumper)
	await _frames(10)
	for step in 300:
		for player in jumpers:
			player.move_input = Vector2(0.0, -1.0)
			if step % 80 == 50 or step % 80 == 70:
				player.jump_requested = true
		await physics_frame
	var lost := 0
	for player in jumpers:
		var at := player.global_position
		if at.y < -0.2 or not layout.is_inside(at.x, at.z, 0.0):
			lost += 1
		player.queue_free()
	_check(lost == 0, "%s: saltar y barrer desde lo alto de cada bloque siempre acaba en el suelo del mapa (%d saltos)" % [title, jumpers.size()])
	await _frames(3)


#Every walked link is walked for real both ways
func _check_links(title: String, layout: ArenaLayout) -> void:
	var walkers: Array[Dictionary] = []
	for entry in layout.links:
		if entry.kind == ArenaLayout.LAUNCH:
			continue
		walkers.append(_walker(layout, entry.a, entry.b, entry.seconds))
		if entry.back >= 0.0 and entry.kind != ArenaLayout.BELT:
			walkers.append(_walker(layout, entry.b, entry.a, entry.back))
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
			if way.length() < float(walker["near"]) and absf(player.global_position.y - to.y) < 1.2:
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
			failed.append("%s>%s" % [walker["a"], walker["b"]])
		(walker["player"] as Player).queue_free()
	_check(failed.is_empty(), "%s: sus %d tramos del grafo se caminan de verdad %s" % [title, walkers.size(), failed])
	await _frames(3)


func _walker(layout: ArenaLayout, a: StringName, b: StringName, seconds: float) -> Dictionary:
	var player := _player(layout.position_of(a) + Vector3(0.0, 0.1, 0.0))
	return {"player": player, "a": a, "b": b, "to": layout.position_of(b), "near": maxf(layout.radius_of(b) * 0.6, 0.6),
		"limit": seconds + WALK_SLACK, "done": false}


#Each bubble point is in its zone, over its floor and inside the fence
func _check_points(layout: TrendLayout) -> void:
	var fine := true
	var zones: Dictionary = {}
	var sample := ""
	for slot in layout.slots:
		var at: Vector3 = slot["position"]
		var zone: int = slot["zone"]
		var floor_height: float = slot["floor"]
		var ok := layout.is_inside(at.x, at.z, 1.0) and layout.in_zone(zone, at) and layout.zone_at(at) == zone and at.y > floor_height
		#The ones of the archipelago float over a platform, the rest over the terrain
		if zone != TrendLayout.Zone.ISLANDS:
			ok = ok and absf(layout.height_at(at.x, at.z) - floor_height) < 0.01
		if not ok and sample == "":
			sample = "%s en la zona %d" % [at.snappedf(0.1), zone]
		fine = fine and ok
		zones[zone] = int(zones.get(zone, 0)) + 1
	_check(fine, "La Plaza: sus %d puntos de burbuja están dentro de su zona, sobre su piso y dentro de la valla %s" % [layout.slots.size(), sample])
	var each := zones.size() == TrendLayout.ZONE_COUNT
	for zone: int in zones:
		each = each and int(zones[zone]) >= 9
	_check(each, "La Plaza: cada una de las cinco zonas tiene de 9 puntos en adelante %s" % zones)


#Each tower trampoline throws a real body onto its target floor
func _check_pads(layout: TrendLayout) -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	var world := ArenaWorld.new()
	_scene.add_child(world)
	world.build(layout)
	await _frames(5)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var flyers: Array[Player] = []
	for pad in layout.pads:
		var player := _player((pad["at"] as Vector3) + Vector3(0.0, 0.05, 0.0))
		flyers.append(player)
	await _frames(3)
	for index in flyers.size():
		flyers[index].launch(ArenaHazards.pad_launch(layout.pads[index], gravity))
	await _frames(150)
	var missed: Array[String] = []
	for index in flyers.size():
		var to: Vector3 = layout.pads[index]["to"]
		var at := flyers[index].global_position
		if absf(at.y - to.y) > 0.1 or Vector2(at.x - to.x, at.z - to.z).length() > 1.2:
			missed.append("%s->%s" % [at.snappedf(0.1), to.snappedf(0.1)])
		flyers[index].queue_free()
	_check(missed.is_empty(), "La Plaza: los %d trampolines de la torre dejan a un cuerpo en el piso al que apuntan %s" % [layout.pads.size(), missed])
	_scene.queue_free()
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
	return body


func _player(at: Vector3) -> Player:
	var player := (load("res://scenes/characters/player.tscn") as PackedScene).instantiate() as Player
	_scene.add_child(player)
	player.global_position = at
	(player.get_node("PlayerInput") as Node).set_physics_process(false)
	player.dive_enabled = true
	#Each walker is alone in the map: they do not bump into each other
	player.collision_layer = 2
	player.collision_mask = 1
	return player
