extends SceneTree

#Checks the two solid maps (La Plaza and El Estudio) with real physics: the collisions match the layout and leave no hole, nobody
#gets past the fence or under the ground even with a jump and a dive, every link of the graph can really be walked, every place
#can be reached, and climbing back after a fall takes a short while.
#Run: godot --headless --fixed-fps 60 --path . --script res://scripts/tests/terrain_check.gd

const GRID := 1.5
const FENCE_STEP := 3.0
#Seconds a walker gets for a link on top of what the graph says it costs
const WALK_SLACK := 2.5
#A fall is paid with time: seconds to get back up to a high place from the ground under it
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
	await _check_map("El Estudio", SelfieLayout.new())
	_check_sets(SelfieLayout.new())
	_check_points(TrendLayout.new())
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


#Every place can be reached from where the players start, and the way back up after a fall is short
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
		#Whoever falls from a place lands where its step down leads, or else on the closest place that is lower
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


#Capsules dropped all over the map land exactly where the layout says the floor is: no hole and no piece out of place
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


#The edge of a piece is where a capsule may rest half on it: those spots are left out of the rain
func _clear_of_edges(layout: ArenaLayout, x: float, z: float) -> bool:
	var here := layout.height_at(x, z)
	for offset: Vector2 in [Vector2(0.45, 0.0), Vector2(-0.45, 0.0), Vector2(0.0, 0.45), Vector2(0.0, -0.45), Vector2(0.32, 0.32), Vector2(-0.32, 0.32), Vector2(0.32, -0.32), Vector2(-0.32, -0.32)]:
		if absf(layout.height_at(x + offset.x, z + offset.y) - here) > 0.25:
			return false
	return true


#Players run at the fence from the inside all around the map, jump and dive: none gets out and none ends under the ground
func _check_fence(title: String, layout: ArenaLayout) -> void:
	var runners: Array[Player] = []
	var count := layout.outline.size()
	for index in count:
		var from := layout.outline[index]
		var to := layout.outline[(index + 1) % count]
		var steps := maxi(roundi(from.distance_to(to) / FENCE_STEP), 1)
		for step in steps:
			var edge := from.lerp(to, (step + 0.5) / steps)
			var inward := -edge.normalized()
			var start := edge + inward * 7.0
			var player := _player(Vector3(start.x, layout.height_at(start.x, start.y) + 0.1, start.y))
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
	_check(out == 0, "%s: %d corredores contra la valla con salto y barrido, ninguno sale (%d fuera)" % [title, runners.size(), out])
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


#Every link that is walked is walked for real, both ways: a body that goes straight from one place to the other arrives
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


#The eight sets of the selfie are flat and bigger than the biggest frame
func _check_sets(layout: SelfieLayout) -> void:
	var settings := SelfieSettings.new()
	var biggest := settings.frame_start * 1.22
	var flat := true
	for spot in layout.spots:
		var centre := layout.position_of(spot)
		for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var x := centre.x + corner.x * biggest / 2.0
			var z := centre.z + corner.y * biggest / 2.0
			flat = flat and absf(layout.height_at(x, z) - centre.y) < 0.01 and layout.is_inside(x, z, 0.3)
	_check(layout.spots.size() == 8 and flat, "El Estudio: los 8 sets son claros planos mayores que el marco más grande (%.1f m)" % biggest)
	var heights: Dictionary = {}
	for spot in layout.spots:
		heights[layout.position_of(spot).y] = true
	_check(heights.size() >= 4, "El Estudio: los sets están repartidos en %d alturas" % heights.size())
	var room := true
	for spot in layout.spots:
		room = room and layout.frame_room(spot, settings.frame_end) >= settings.feint_shift
	_check(room, "El Estudio: en todos cabe el marco pequeño con su finta")


#Every point where a bubble is born stands on the floor of its place, inside the fence
func _check_points(layout: TrendLayout) -> void:
	var fine := true
	var zones: Dictionary = {}
	for point in layout.points:
		var at: Vector3 = point["position"]
		fine = fine and layout.is_inside(at.x, at.z, 1.0) and absf(layout.height_at(at.x, at.z) - at.y) < 0.01
		zones[point["zone"]] = int(zones.get(point["zone"], 0)) + 1
	_check(fine and layout.points.size() >= 30, "La Plaza: sus %d puntos de burbuja están sobre el piso y dentro de la valla" % layout.points.size())
	_check(zones.size() == 6, "La Plaza: hay puntos en las cinco zonas y en la plaza %s" % zones)


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
