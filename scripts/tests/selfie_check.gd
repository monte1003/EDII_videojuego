extends SceneTree

#Checks the perfect selfie with no scene: the studio (its sets, its two levels, its graph, and every way of it within what a player
#can do with a fifth to spare), the order of the photos, the frame, who comes out at the shot (in the air too), the followers, the
#pose, the power-ups, the shoves, the tricks of the floor and how the photo frames four players
#run: godot --headless --path . --script res://scripts/tests/selfie_check.gd

const SHEET: ScoreSheet = preload("res://resources/score_sheet.tres")
const SETTINGS: SelfieSettings = preload("res://resources/levels/perfect_selfie.tres")
#A player only manages this share of what it could, and no slope may be steeper than 20 degrees
const SHARE := 0.8
const MAX_SLOPE := 0.364
#How wide a body is, to keep a way clear of pillars
const BODY := 0.4
#The highest ledge a trampoline throws a body onto, measured with a body by the playability gate (player_limits)
const TRAMPOLINE_LEDGE := 2.64

var _failures := 0
var _layout := SelfieLayout.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _speed := 5.0
var _jump_velocity := 4.5
var _jump_height := 1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := (load("res://scenes/characters/player.tscn") as PackedScene).instantiate() as Player
	_speed = player.move_speed
	_jump_velocity = player.jump_velocity
	_jump_height = SelfieRules.jump_height_of(player.jump_velocity)
	player.free()
	print("Player: velocidad %.2f m/s, salto %.2f m/s, altura del salto %.2f m, alcance plano %.2f m, gravedad %.2f, barrido %.1f m" % [
		_speed, _jump_velocity, _jump_height, _flat_jump(), _gravity, Player.DIVE_MAX_REACH])
	_check_studio()
	_check_ways()
	_check_reach()
	_check_order()
	_check_frame()
	_check_detection()
	_check_followers()
	_check_pose()
	_check_powers()
	_check_brawl()
	_check_floor()
	_check_photo()
	await _check_camera()
	_check_whole_round()
	print("selfie_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _rules(ids: Array[int], seed_value := 3) -> SelfieRules:
	var rules := SelfieRules.new(SETTINGS, SHEET, _layout, ids, seed_value)
	rules.jump_height = _jump_height
	return rules


func _until(rules: SelfieRules, phase: SelfieRules.Phase) -> void:
	if rules.phase == SelfieRules.Phase.WAITING:
		rules.start()
	var guard := 0
	while rules.phase != phase and guard < 5000:
		rules.tick(0.05)
		guard += 1


#Leaves the fixed frame one tick away from its shot
func _to_shot(rules: SelfieRules) -> void:
	_until(rules, SelfieRules.Phase.LOCK)
	while rules.time_left > 0.06:
		rules.tick(0.05)


#Meters a plain jump covers on flat ground at full run
func _flat_jump() -> float:
	return 2.0 * _jump_velocity / _gravity * _speed


func _check_studio() -> void:
	var size := SelfieLayout.HALF * 2.0
	_expect(absf(size.x / size.y - 1.9) < 0.3 and size.x * size.y >= 3600.0, "el plató es alargado, %.0f x %.0f m (%.1f a 1), y mide %.0f m2 (el doble del de antes o más)" % [size.x, size.y, size.x / size.y, size.x * size.y])
	_expect(_layout.blocks.is_empty() and _layout.ramps.is_empty() and _layout.drums.is_empty(), "el estudio no usa las piezas de terreno del kit de arena: su geometría es propia")
	var tricks: Dictionary = {}
	for spot in _layout.spots:
		tricks[_layout.trick_of(spot)] = true
	_expect(_layout.spots.size() == 11 and tricks.size() == 11 and not tricks.has(SelfieLayout.Trick.NONE), "once sets, cada uno con su reto propio")
	var levels: Array[float] = []
	for spot in _layout.spots:
		levels.append(_layout.position_of(spot).y)
	var has_level := func(height: float) -> bool: return levels.any(func(level: float) -> bool: return is_equal_approx(level, height))
	_expect(has_level.call(0.0) and has_level.call(SelfieLayout.UPPER) and has_level.call(SelfieLayout.PODIUM_TOP) and has_level.call(SelfieLayout.LIVE_TOP),
		"cuatro alturas de set: el piso a 0, el escenario de directo a %.1f m, el podio a %.1f y la pasarela a %.1f" % [SelfieLayout.LIVE_TOP, SelfieLayout.PODIUM_TOP, SelfieLayout.UPPER])
	var deck := SelfieLayout.RUNWAY.get_center() + Vector2(0.3, 2.2)
	var runway := _layout.height_at(deck.x, deck.y)
	var under := _layout.height_at(deck.x, deck.y, 1.0)
	_expect(is_equal_approx(runway, SelfieLayout.UPPER) and is_equal_approx(under, 0.0) and SelfieLayout.UPPER - SelfieLayout.DECK_THICKNESS >= 1.0 + _jump_height,
		"la pasarela está a %.1f m y por debajo se camina y se salta sin chocar (%.1f m libres)" % [runway, SelfieLayout.UPPER - SelfieLayout.DECK_THICKNESS])
	_expect(SelfieLayout.RUNWAY.size.y >= 3.0, "la pasarela y sus rampas miden 3 m de ancho o más (%.1f m)" % SelfieLayout.RUNWAY.size.y)
	var biggest := SETTINGS.frame_start * 1.22 + SelfieLayout.FRAME_MARGIN * 2.0
	var flat := true
	var worst := ""
	for spot in _layout.spots:
		var centre := _layout.position_of(spot)
		var room := _layout.room_of(spot)
		flat = flat and minf(room.x, room.y) * 2.0 >= biggest
		var usable := room - Vector2.ONE * SelfieLayout.FRAME_MARGIN
		for step_x in 9:
			for step_z in 9:
				var x := centre.x + lerpf(-usable.x, usable.x, step_x / 8.0)
				var z := centre.z + lerpf(-usable.y, usable.y, step_z / 8.0)
				var here := _layout.height_at(x, z, centre.y + 0.5)
				if absf(here - centre.y) > 0.01 or not _layout.is_inside(x, z, 0.2):
					flat = false
					worst = "%s (%.1f, %.1f) a %.2f" % [spot, x, z, here]
		if _layout.trick_of(spot) == SelfieLayout.Trick.SPIN:
			flat = flat and room.length() <= SelfieLayout.TURNTABLE_RADIUS
	_expect(flat, "el piso de cada set es plano y cabe el marco más grande en movimiento (%.1f m) %s" % [biggest, worst])
	var feint := true
	for spot in _layout.spots:
		feint = feint and _layout.frame_room(spot, SETTINGS.frame_end) >= SETTINGS.feint_shift
	_expect(feint, "en todos los sets cabe el marco pequeño con su finta (%.1f m)" % SETTINGS.feint_shift)
	var trick_spots := true
	for spot in _layout.spots:
		var trick := _layout.trick_of(spot)
		if trick in [SelfieLayout.Trick.SPIN, SelfieLayout.Trick.WAX, SelfieLayout.Trick.CARPET, SelfieLayout.Trick.PIT, SelfieLayout.Trick.BEAT]:
			trick_spots = trick_spots and _layout.trick_at(_layout.position_of(spot)) == trick
	var belt_spot := _layout.position_of(&"A")
	var on_belt := false
	for belt in _layout.belts:
		on_belt = on_belt or ArenaHazards.on_belt(belt, belt_spot)
	_expect(trick_spots and on_belt, "el truco de cada set está bajo su marco: giratorio, pista resbalosa, alfombra, piscina, escenario que late y cinta")


#Every way of the graph from place to place, walked over the plan of the floors: a body never meets a step, a slope steeper than
#20 degrees or a pillar, and from anywhere there is a way back to where the players start
func _check_ways() -> void:
	var graph := _layout.build_graph()
	var from_hub := graph.costs_from(SelfieLayout.HUB)
	var lost: Array[StringName] = []
	var stuck: Array[StringName] = []
	for id: StringName in _layout.places:
		if not from_hub.has(id):
			lost.append(id)
		if not graph.costs_from(id).has(SelfieLayout.HUB):
			stuck.append(id)
	_expect(lost.is_empty() and stuck.is_empty(), "desde el inicio se llega a los %d lugares y de todos se vuelve (sin rincones sin salida) %s %s" % [_layout.places.size(), lost, stuck])
	var walkable := _layout.bot_places()
	var zone := SelfieLayout.TROLL.grow(-SelfieLayout.CURB_THICKNESS)
	var troll_set := _layout.position_of(&"Z")
	var troll_room := _layout.room_of(&"Z")
	var fenced := zone.encloses(Rect2(Vector2(troll_set.x, troll_set.z) - troll_room, troll_room * 2.0))
	_expect(walkable == ([&"Z"] as Array[StringName]) and fenced, "los bots viven solo en la zona trol, y su set (con su marco) cabe dentro del bordillo que no cruzan")
	var bad: Array[String] = []
	var steepest := 0.0
	var count := 0
	for entry in _layout.links:
		if entry.kind != ArenaLayout.WALK:
			continue
		count += 1
		var problem := _walk_problem(_layout.position_of(entry.a), _layout.position_of(entry.b))
		steepest = maxf(steepest, float(problem["slope"]))
		if problem["text"] != "":
			bad.append("%s-%s %s" % [entry.a, entry.b, problem["text"]])
	_expect(bad.is_empty(), "sus %d tramos a pie no tienen escalones, ni rampas de más de 20 grados (la más empinada %.0f grados), ni pilares en medio %s" % [count, rad_to_deg(atan(steepest)), bad])
	var blocked: Array[String] = []
	for entry in _layout.links:
		if entry.kind == ArenaLayout.DROP and _drop_blocked(_layout.position_of(entry.a), _layout.position_of(entry.b)):
			blocked.append("%s>%s" % [entry.a, entry.b])
	_expect(blocked.is_empty(), "las caídas del grafo bajan sin atravesar nada (un telón, una pared) %s" % [blocked])
	var high_hops: Array[String] = []
	var hops := 0
	for entry in _layout.links:
		if entry.kind != ArenaLayout.HOP:
			continue
		hops += 1
		var rise := absf(_layout.position_of(entry.b).y - _layout.position_of(entry.a).y)
		var curb := SelfieLayout.POOL_WALL if entry.b == &"F" else 0.0
		if maxf(rise, curb) > _jump_height * SHARE:
			high_hops.append("%s-%s %.2f m" % [entry.a, entry.b, maxf(rise, curb)])
	_expect(hops > 0 and high_hops.is_empty(), "sus %d saltitos (los escalones del podio y el bordillo de la piscina) suben menos que un salto al 80 %% (%.2f m) %s" % [
		hops, _jump_height * SHARE, high_hops])


#Whether a step down from "a" toward "b" meets something solid at the height of a body while it is still up there
func _drop_blocked(a: Vector3, b: Vector3) -> bool:
	var steps := maxi(ceili(Vector2(b.x - a.x, b.z - a.z).length() / 0.1), 1)
	for step in range(1, steps + 1):
		var point := a.lerp(b, float(step) / steps)
		if _layout.height_at(point.x, point.z, a.y + 0.3) < a.y - 0.05:
			return false
		if _layout.solid_at(Vector3(point.x, a.y + 0.5, point.z)):
			return true
	return false


#Walks the plan from "a" to "b" in steps of 10 cm, following the floor it stands on
func _walk_problem(a: Vector3, b: Vector3) -> Dictionary:
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	var steps := maxi(ceili(length / 0.1), 1)
	var height := a.y
	var slope := 0.0
	for step in range(1, steps + 1):
		var point := a.lerp(b, float(step) / steps)
		var next := _layout.height_at(point.x, point.z, height + 0.3)
		var rise := next - height
		if absf(rise) > 0.06:
			return {"text": "escalón de %.2f m en (%.1f, %.1f)" % [rise, point.x, point.z], "slope": slope}
		slope = maxf(slope, absf(rise) / (length / steps))
		height = next
		if height < SelfieLayout.UPPER - SelfieLayout.DECK_THICKNESS:
			for pillar in SelfieLayout.RUNWAY_PILLARS:
				if Vector2(point.x, point.z).distance_to(pillar) < SelfieLayout.PILLAR_RADIUS + BODY:
					return {"text": "pilar en (%.1f, %.1f)" % [point.x, point.z], "slope": slope}
		if not _layout.is_inside(point.x, point.z, BODY):
			return {"text": "pared en (%.1f, %.1f)" % [point.x, point.z], "slope": slope}
	if absf(height - b.y) > 0.06:
		return {"text": "acaba a %.2f m y el lugar está a %.2f" % [height, b.y], "slope": slope}
	return {"text": "" if slope <= MAX_SLOPE else "pendiente de %.0f grados" % rad_to_deg(atan(slope)), "slope": slope}


#What the studio asks of a player against what it can do with a fifth to spare: the podium by trampoline, the upper level only by
#its ramps, and the next set always within the time of a photo
func _check_reach() -> void:
	_expect(SelfieLayout.PODIUM_TOP <= TRAMPOLINE_LEDGE * SHARE and SelfieLayout.PODIUM_TOP > _jump_height * SETTINGS.jump_scale,
		"el podio (%.1f m) se alcanza con el trampolín (llega a un saliente de %.2f m; %.0f %% de eso) y no saltando, ni con el potenciador (%.2f m)" % [
			SelfieLayout.PODIUM_TOP, TRAMPOLINE_LEDGE, SelfieLayout.PODIUM_TOP / TRAMPOLINE_LEDGE * 100.0, _jump_height * SETTINGS.jump_scale])
	var pads_fine := true
	var trampolines := 0
	for pad in _layout.pads:
		if ArenaHazards.is_cannon(pad):
			var target: Vector3 = pad["to"]
			pads_fine = pads_fine and SelfieLayout.RUNWAY.grow(-0.8).has_point(Vector2(target.x, target.z)) and is_equal_approx(target.y, SelfieLayout.UPPER)
			continue
		trampolines += 1
		var at: Vector3 = pad["at"]
		var edge := _distance_to_box(Vector2(at.x, at.z), SelfieLayout.PODIUM)
		#The time the jump of the pad stays over the top of the podium, run at a fifth less than full speed
		var lift := ArenaHazards.PAD_LIFT
		var spread := sqrt(lift * lift - 2.0 * _gravity * SelfieLayout.PODIUM_TOP)
		var leave := (lift + spread) / _gravity
		var arrive := (lift - spread) / _gravity
		pads_fine = pads_fine and edge >= ArenaHazards.PAD_REACH + 0.3 and edge + 0.6 <= _speed * SHARE * leave
		print("  trampolín en (%.1f, %.1f): %.2f m al borde del podio; sobre él de %.2f a %.2f s, a 80 %% llega a %.1f m" % [at.x, at.z, edge, arrive, leave, _speed * SHARE * leave])
	_expect(pads_fine and trampolines == 1, "desde el trampolín se cae sobre el podio corriendo al 80 %%, y el cañón deja en medio de la pasarela")
	_expect(SelfieLayout.UPPER > _jump_height * SETTINGS.jump_scale, "el nivel alto (%.1f m) pide rampa: ni el salto potenciado llega (%.2f m)" % [SelfieLayout.UPPER, _jump_height * SETTINGS.jump_scale])
	var table := _layout.travel_table(_layout.build_graph())
	var window := SETTINGS.travel_seconds + SETTINGS.frame_seconds + SETTINGS.lock_seconds
	var farthest := 0.0
	var pair := ""
	for a in _layout.spots:
		for b in _layout.spots:
			if float(table[a][b]) > farthest:
				farthest = float(table[a][b])
				pair = "%s>%s" % [a, b]
	print("  los dos sets más lejanos: %s a %.1f s a pie (%.1f s al 80 %%)" % [pair, farthest, farthest / SHARE])
	var slowest := 0.0
	var late := 0
	for seed_value in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var order := SelfieRules.photo_order(_layout.spots, SETTINGS.photo_count, table, SelfieLayout.HUB, SETTINGS.reach_seconds, rng)
		var at := SelfieLayout.HUB
		for spot in order:
			var seconds := float(table[at][spot]) / SHARE
			slowest = maxf(slowest, seconds)
			late += int(seconds > window)
			at = spot
	_expect(late == 0, "en 200 órdenes de fotos, cada set se alcanza a tiempo corriendo al 80 %%: el tramo más largo %.1f s de %.1f (%d tarde)" % [slowest, window, late])


func _distance_to_box(point: Vector2, box: Rect2) -> float:
	var nearest := Vector2(clampf(point.x, box.position.x, box.end.x), clampf(point.y, box.position.y, box.end.y))
	return point.distance_to(nearest)


func _check_order() -> void:
	var table := _layout.travel_table(_layout.build_graph())
	var complete := true
	var repeats := true
	var twice := true
	var orders: Dictionary = {}
	for seed_value in 80:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var order := SelfieRules.photo_order(_layout.spots, SETTINGS.photo_count, table, SelfieLayout.HUB, SETTINGS.reach_seconds, rng)
		var seen: Dictionary = {}
		for index in order.size():
			seen[order[index]] = int(seen.get(order[index], 0)) + 1
			if index > 0 and order[index] == order[index - 1]:
				repeats = false
		for spot: StringName in seen:
			twice = twice and int(seen[spot]) <= 2
		complete = complete and order.size() == SETTINGS.photo_count and seen.size() == mini(SETTINGS.photo_count, _layout.spots.size())
		orders[str(order)] = true
	_expect(complete, "las %d fotos caen siempre en sets distintos de los %d" % [SETTINGS.photo_count, _layout.spots.size()])
	_expect(repeats and twice, "ningún set sale dos veces seguidas ni más de dos veces")
	_expect(orders.size() > 50, "el orden cambia de una partida a otra (%d órdenes en 80)" % orders.size())
	var rules := _rules([1])
	var visited: Array[StringName] = []
	rules.photo_announced.connect(func(_index: int, spot: StringName) -> void: visited.append(spot))
	_until(rules, SelfieRules.Phase.DONE)
	_expect(visited.size() == SETTINGS.photo_count and visited == rules.order, "una ronda entera toma sus %d fotos en ese orden" % visited.size())


func _check_frame() -> void:
	var rules := _rules([1], 11)
	_until(rules, SelfieRules.Phase.TRAVEL)
	_expect(not rules.frame_visible(), "mientras el dron viaja no hay marco")
	_expect(is_equal_approx(rules.final_size(0), SETTINGS.frame_start) and is_equal_approx(rules.final_size(SETTINGS.photo_count - 1), SETTINGS.frame_end),
		"el marco baja de %.1f a %.1f m" % [SETTINGS.frame_start, SETTINGS.frame_end])
	_expect(rules.lock_seconds_of(7) < rules.lock_seconds_of(0), "las últimas fotos parpadean más rápido")
	var inside_set := true
	var moved := 0.0
	for photo in SETTINGS.photo_count:
		_until(rules, SelfieRules.Phase.FRAME)
		var spot := _layout.position_of(rules.spot())
		var room := _layout.room_of(rules.spot())
		var before := rules.frame_center()
		while rules.phase == SelfieRules.Phase.FRAME:
			var centre := rules.frame_center()
			var half := rules.frame_size() / 2.0
			inside_set = inside_set and absf(centre.x - spot.x) + half <= room.x + 0.01 and absf(centre.z - spot.z) + half <= room.y + 0.01
			rules.tick(0.05)
		if photo == SETTINGS.photo_count - 1:
			moved = before.distance_to(rules.frame_center())
		var fixed := rules.frame_center()
		rules.tick(0.3)
		inside_set = inside_set and fixed.is_equal_approx(rules.frame_center()) and is_equal_approx(rules.frame_size(), rules.final_size(photo))
		_until(rules, SelfieRules.Phase.REVEAL)
		if photo < SETTINGS.photo_count - 1:
			_until(rules, SelfieRules.Phase.TRAVEL)
	_expect(inside_set, "el marco nunca se sale del piso de su set y queda quieto y a su tamaño cuando se fija")
	_expect(moved > 0.3, "en las últimas fotos el marco se mueve antes de fijarse (%.1f m)" % moved)


#Who comes out at the shot: over the square of the frame and, in height, from a little under the floor of the set up to a jump and
#a meter over it. A jump at the very shot counts, at the edge and in the middle
func _check_detection() -> void:
	var ceiling := _jump_height + SETTINGS.air_room
	print("  dentro en altura: de %.2f m bajo el piso del set a %.2f m sobre él (salto %.2f + %.1f)" % [SETTINGS.below_floor, ceiling, _jump_height, SETTINGS.air_room])
	var cases: Array[Array] = [
		["salta justo en el disparo en el centro, en lo alto del salto", Vector3(0.0, _jump_height, 0.0), false, true],
		["salta en el disparo en el borde del marco (x)", Vector3(0.499, _jump_height, 0.0), false, true],
		["salta en el disparo en el borde del marco (z)", Vector3(0.0, _jump_height * 0.5, -0.499), false, true],
		["salta en el disparo en una esquina", Vector3(-0.499, 0.3, 0.499), false, true],
		["en el aire justo bajo el techo (salto + 1 m)", Vector3(0.2, ceiling - 0.03, 0.0), false, true],
		["de pie en el centro", Vector3.ZERO, true, true],
		["de pie en el borde", Vector3(0.0, 0.0, 0.499), true, true],
		["más alto que el salto + 1 m", Vector3(0.0, ceiling + 0.05, 0.0), false, false],
		["muy por encima del marco", Vector3(0.0, 4.0, 0.0), false, false],
		["fuera en x, en el aire", Vector3(0.52, _jump_height, 0.0), false, false],
		["fuera en z, de pie", Vector3(0.0, 0.0, 0.52), true, false],
		["por debajo del piso del set", Vector3(0.0, -SETTINGS.below_floor - 0.1, 0.0), false, false],
	]
	for spot in _layout.spots:
		var all_fine := true
		var failed: Array[String] = []
		for entry in cases:
			var rules := _rules_at(spot)
			var centre := rules.frame_center()
			var size := rules.final_size(rules.photo_index)
			var offset: Vector3 = entry[1]
			var at := centre + Vector3(offset.x * size, offset.y, offset.z * size)
			var taken: Array[Dictionary] = []
			rules.photo_taken.connect(func(_index: int, shots: Dictionary) -> void: taken.append(shots))
			rules.place(1, at, entry[2], false)
			rules.tick(0.1)
			var shot: SelfieRules.Shot = taken[0][1]
			var fine: bool = shot.inside == entry[3] and shot.at.is_equal_approx(at) and (not shot.inside or rules.photo_feet.has(at))
			if spot == &"T":
				_expect(fine, "%s: %s" % ["dentro" if entry[3] else "fuera", entry[0]])
			elif not fine:
				failed.append(entry[0])
			all_fine = all_fine and fine
		if spot != &"T":
			_expect(all_fine, "set %s (piso a %.1f m): los mismos %d casos de dentro y fuera %s" % [spot, _layout.position_of(spot).y, cases.size(), failed])
	var fell := _rules_at(&"T")
	fell.place(1, fell.frame_center(), true, true)
	var gone: Array[Dictionary] = []
	fell.photo_taken.connect(func(_index: int, shots: Dictionary) -> void: gone.append(shots))
	fell.tick(0.1)
	_expect(not (gone[0][1] as SelfieRules.Shot).inside, "quien se cayó del mapa no sale aunque su posición coincida")
	var air := _rules_at(&"T")
	air.place(1, air.frame_center() + Vector3(0.0, 0.8, 0.0), false, false)
	air.tick(0.1)
	var ground := _rules_at(&"T")
	ground.place(1, ground.frame_center(), true, false)
	ground.tick(0.1)
	var bonus := air.state_of(1).followers - ground.state_of(1).followers
	_expect(bonus > 0 and bonus <= roundi(SHEET.selfie_pose * 0.1 * SHEET.selfie_crowd[0]), "una foto en el aire suma un poco: %d seguidores, no más del 10 %% de la pose" % bonus)


#Rules whose current photo is on "spot", one tick away from its shot (nobody came out in the photos before)
func _rules_at(spot: StringName) -> SelfieRules:
	for seed_value in 200:
		var rules := _rules([1], seed_value)
		rules.start()
		var guard := 0
		while rules.phase != SelfieRules.Phase.DONE and guard < 20000:
			if rules.phase == SelfieRules.Phase.TRAVEL and rules.spot() == spot:
				_to_shot(rules)
				return rules
			rules.tick(0.05)
			guard += 1
	return null


func _check_followers() -> void:
	var rules := _rules([1, 2, 3, 4])
	_to_shot(rules)
	var centre := rules.frame_center()
	var size := rules.final_size(0)
	rules.place(1, centre, true, false)
	rules.place(2, centre + Vector3(size * 0.4, 0.0, 0.0), true, false)
	rules.place(3, centre + Vector3(size * 0.6, 0.0, 0.0), true, false)
	rules.place(4, centre + Vector3(0.0, 5.0, 0.0), false, false)
	var taken: Array[Dictionary] = []
	rules.photo_taken.connect(func(_index: int, shots: Dictionary) -> void: taken.append(shots))
	rules.tick(0.1)
	var shots: Dictionary = taken[0]
	var first: SelfieRules.Shot = shots[1]
	var second: SelfieRules.Shot = shots[2]
	var third: SelfieRules.Shot = shots[3]
	var fourth: SelfieRules.Shot = shots[4]
	_expect(first.inside and first.centered and second.inside and not second.centered, "dentro del marco salen los dos; solo uno está en el centro")
	_expect(not third.inside and third.followers == 0 and not fourth.inside, "fuera del marco o muy alto no se sale")
	_expect(first.crowd == 2 and first.followers == 50 and second.followers == 30, "con dos en la foto: 50 en el centro y 30 fuera de él (%d, %d)" % [first.followers, second.followers])
	_expect(rules.state_of(1).followers == 50 and rules.state_of(3).followers == 0 and rules.state_of(1).photos == 1, "los seguidores quedan a nombre de cada jugador")
	var alone := _rules([1])
	_to_shot(alone)
	alone.place(1, alone.frame_center(), true, false)
	alone.tick(0.1)
	_expect(alone.state_of(1).followers == 75, "solo en la foto y en el centro: 50 por 1,5 (%d)" % alone.state_of(1).followers)
	var bombed := _rules([1])
	_to_shot(bombed)
	bombed.place(1, bombed.frame_center(), true, false)
	bombed.extras = [bombed.frame_center() + Vector3(1.0, 0.0, 0.0), bombed.frame_center() + Vector3(50.0, 0.0, 0.0)]
	bombed.tick(0.1)
	_expect(bombed.state_of(1).followers == 50 and bombed.photo_feet.size() == 2, "un bot dentro del marco cuenta como alguien más y sale en la foto (%d)" % bombed.state_of(1).followers)
	_expect(SHEET.selfie_points(SHEET.selfie_max_followers()) == 1000 and alone.points_of(1) == SHEET.selfie_points(75), "los seguidores se convierten a puntos con la hoja")


func _check_pose() -> void:
	var rules := _rules([1, 2])
	_expect(not rules.set_posing(1, true), "antes de empezar no se posa")
	_until(rules, SelfieRules.Phase.LOCK)
	rules.place(1, rules.frame_center(), false, false)
	_expect(not rules.set_posing(1, true), "en el aire no se posa")
	rules.place(1, rules.frame_center(), true, false)
	rules.place(2, rules.frame_center(), true, false)
	_expect(rules.set_posing(1, true) and rules.is_posing(1), "en el piso sí")
	rules.strike(1)
	_expect(not rules.is_posing(1), "un golpe rompe la pose")
	rules.set_posing(1, true)
	rules.place(1, rules.frame_center(), false, false)
	_expect(not rules.is_posing(1), "despegar del piso rompe la pose")
	var late := _rules([1])
	_to_shot(late)
	late.place(1, late.frame_center(), true, false)
	late.set_posing(1, true)
	late.tick(0.1)
	_expect(late.state_of(1).poses == 1 and late.state_of(1).followers == 195, "una pose de última hora cuenta entera (%d seguidores)" % late.state_of(1).followers)
	var held := _rules([1])
	_until(held, SelfieRules.Phase.LOCK)
	held.place(1, held.frame_center(), true, false)
	held.set_posing(1, true)
	_until(held, SelfieRules.Phase.REVEAL)
	_expect(held.state_of(1).poses == 1 and held.state_of(1).followers == 195, "centro y pose a tiempo, solo en la foto: 130 por 1,5 (%d)" % held.state_of(1).followers)
	var toggle := _rules([1])
	_until(toggle, SelfieRules.Phase.FRAME)
	toggle.place(1, toggle.frame_center(), true, false)
	var styles: Array[int] = []
	var same := false
	for press in 40:
		toggle.toggle_pose(1)
		styles.append(toggle.state_of(1).pose_style)
		toggle.toggle_pose(1)
	var distinct: Dictionary = {}
	for index in styles.size():
		distinct[styles[index]] = true
		same = same or (index > 0 and styles[index] == styles[index - 1])
	_expect(not same and distinct.size() == SETTINGS.pose_styles, "cada pose es de un estilo distinto al anterior y salen los %d" % SETTINGS.pose_styles)
	_expect(not toggle.is_posing(1) and toggle.toggle_pose(1) and toggle.is_posing(1), "una pulsación pone la pose y la siguiente la quita")


func _check_powers() -> void:
	var rules := _rules([1, 2])
	rules.start()
	var jump := rules.pedestal_kinds.find(SelfieRules.Power.JUMP)
	var speed := rules.pedestal_kinds.find(SelfieRules.Power.SPEED)
	var shield := rules.pedestal_kinds.find(SelfieRules.Power.SHIELD)
	_expect(jump >= 0 and speed >= 0 and shield >= 0 and _layout.pedestals.size() == 5, "cinco pedestales con salto, velocidad y escudo")
	var given: Array[Array] = []
	rules.power_taken.connect(func(id: int, _pedestal: int, kind: int, seconds: float) -> void: given.append([id, kind, seconds]))
	_expect(rules.take_power(1, jump) and not rules.take_power(2, jump), "un potenciador se toma una sola vez")
	_expect(rules.jump_scale(1) > 1.2 and is_equal_approx(rules.jump_scale(2), 1.0), "el salto es de quien lo tomó")
	rules.take_power(2, speed)
	_expect(is_equal_approx(rules.speed_scale(2), SETTINGS.speed_scale), "la velocidad sube %.2f veces" % SETTINGS.speed_scale)
	rules.tick(SETTINGS.boost_seconds + 0.1)
	_expect(is_equal_approx(rules.jump_scale(1), 1.0) and is_equal_approx(rules.speed_scale(2), 1.0), "a los %d s se acaban" % int(SETTINGS.boost_seconds))
	rules.take_power(1, shield)
	_expect(given.back()[1] == SelfieRules.Power.SHIELD and is_equal_approx(given.back()[2], SETTINGS.shield_seconds), "el escudo dura hasta %d s" % int(SETTINGS.shield_seconds))
	rules.state_of(1).followers = 300
	_expect(rules.is_last(2) and not rules.is_last(1) and not _rules([1]).is_last(1), "con varios, va último quien tiene menos seguidores; en solitario nadie")
	_expect(not rules.take_power(1, -1) and not rules.take_power(1, 99) and not rules.take_power(77, 0), "un pedestal o un jugador que no existe no rompe nada")


func _check_brawl() -> void:
	var brawl := ArenaBrawl.new()
	brawl.add(1)
	brawl.add(2)
	_expect(brawl.use_shove(1) and not brawl.use_shove(1), "el empujón descansa después de usarse")
	brawl.tick(brawl.shove_rest + 0.01)
	_expect(brawl.can_shove(1), "a los %.1f s vuelve" % brawl.shove_rest)
	_expect(brawl.strike(2) == ArenaBrawl.Outcome.STRUCK and brawl.strike(2) == ArenaBrawl.Outcome.IGNORED, "tras un golpe hay gracia: el siguiente no cuenta")
	brawl.tick(brawl.grace + 0.01)
	brawl.give_shield(2, 8.0)
	_expect(brawl.strike(2) == ArenaBrawl.Outcome.BLOCKED and not brawl.has_shield(2), "el escudo bloquea un golpe y se gasta")
	var others := {2: Vector3(0.0, 0.0, 1.2), 3: Vector3(0.0, 0.0, -1.0), 5: Vector3(0.3, 0.0, 0.8)}
	_expect(brawl.pick_victim(Vector3.ZERO, Vector3.BACK, others) == 5 and brawl.pick_victim(Vector3.ZERO, Vector3.RIGHT, {3: Vector3(0.0, 0.0, -1.0)}) == -1,
		"el empujón le da al más cercano de los que tiene delante y no a quien está al lado")


#The tricks of the floor, step by step with no bodies: the drag of the turntable, the slide of the wax, the slow carpet and the
#bounce of the mattress; on plain floor none of them does anything
func _check_floor() -> void:
	var floor_rules := SelfieFloor.new(_layout)
	var dt := 1.0 / 60.0
	var rim := floor_rules.step(1, Vector3(4.0, 0.0, 0.0), true, Vector3.ZERO, 0.0, dt)
	var middle := floor_rules.step(2, Vector3(0.0, 0.0, 0.0), true, Vector3.ZERO, 0.0, dt)
	var flying := floor_rules.step(3, Vector3(4.0, 0.5, 0.0), false, Vector3.ZERO, 2.0, dt)
	_expect(is_equal_approx(rim.drift.length(), SelfieLayout.TURNTABLE_SPIN * 4.0) and absf(rim.drift.dot(Vector3.RIGHT)) < 0.001 and middle.drift.length() < 0.001 and flying.drift == Vector3.ZERO,
		"el giratorio arrastra de lado a %.1f m/s a 4 m del centro, nada en el centro ni a quien va en el aire" % rim.drift.length())
	var wax := SelfieLayout.DANCE_CENTER
	var at := Vector3(wax.x, 0.0, wax.y)
	var run := Vector3(_speed, 0.0, 0.0)
	for step in 90:
		floor_rules.step(4, at, true, run, 0.0, dt)
	var slid := 0.0
	for step in 120:
		var effect := floor_rules.step(4, at, true, Vector3.ZERO, 0.0, dt)
		slid += effect.drift.length() * dt
	var dry := 0.0
	for step in 90:
		floor_rules.step(5, Vector3(-12.0, 0.0, 2.0), true, run, 0.0, dt)
	for step in 120:
		dry += floor_rules.step(5, Vector3(-12.0, 0.0, 2.0), true, Vector3.ZERO, 0.0, dt).drift.length() * dt
	var waxed := floor_rules.step(4, at, true, Vector3.ZERO, 0.0, dt)
	_expect(slid > 0.8 and dry < 0.01 and waxed.push_decay < 18.0, "en la pista de baile se resbala %.1f m al soltar la carrera (en el piso normal %.2f) y un empujón llega más lejos" % [slid, dry])
	var carpet_middle := SelfieLayout.CARPET.get_center()
	var carpet := floor_rules.step(6, Vector3(carpet_middle.x, 0.0, carpet_middle.y), true, Vector3.ZERO, 0.0, dt)
	_expect(carpet.speed_scale < 0.7 and carpet.jump_scale < 1.0, "la alfombra frena: corre al %.0f %% y salta al %.0f %%" % [carpet.speed_scale * 100.0, carpet.jump_scale * 100.0])
	var pit := Vector3(SelfieLayout.POOL_CENTER.x, 0.0, SelfieLayout.POOL_CENTER.y)
	floor_rules.step(7, pit + Vector3(0.0, 1.0, 0.0), false, Vector3.ZERO, -6.0, dt)
	var bounce := floor_rules.step(7, pit, true, Vector3.ZERO, 0.0, dt)
	floor_rules.step(8, pit + Vector3(0.0, 0.3, 0.0), false, Vector3.ZERO, -2.0, dt)
	var soft := floor_rules.step(8, pit, true, Vector3.ZERO, 0.0, dt)
	floor_rules.step(9, Vector3(-12.0, 1.0, 2.0), false, Vector3.ZERO, -6.0, dt)
	var hard := floor_rules.step(9, Vector3(-12.0, 0.0, 2.0), true, Vector3.ZERO, 0.0, dt)
	_expect(bounce.bounce > 2.0 and soft.bounce == 0.0 and hard.bounce == 0.0, "el piso de la piscina devuelve hacia arriba a quien cae fuerte (%.1f m/s), no a quien solo pisa, y el piso normal no rebota" % bounce.bounce)
	var stage := Vector3(SelfieLayout.LIVE_CENTER.x, SelfieLayout.LIVE_TOP, SelfieLayout.LIVE_CENTER.y)
	var lifts := 0
	floor_rules.clock = 0.1
	for step in 260:
		floor_rules.clock += dt
		lifts += int(floor_rules.step(10, stage, true, Vector3.ZERO, 0.0, dt).bounce > 0.0)
	_expect(lifts == 2, "el escenario de directo late cada %.1f s y levanta a quien está encima (%d veces en %.1f s)" % [SelfieLayout.BEAT_PERIOD, lifts, 260.0 * dt])


#The view of the photo: isometric (tilted 32 degrees and turned 45 from the frame) into the back corner of each set, with its frame
#whole when nobody is in it, and four players close together at least 30 % of its height each
func _check_photo() -> void:
	var aspect := float(SelfieCamera.PHOTO_PIXELS.x) / SelfieCamera.PHOTO_PIXELS.y
	_expect(SelfieCamera.PHOTO_PIXELS.x >= 960 and SelfieCamera.PHOTO_PIXELS.y >= 540 and SelfieCamera.PREVIEW_PIXELS == Vector2i(480, 270) and is_equal_approx(SelfieCamera.PREVIEW_RATE, 20.0),
		"la foto se dibuja a %dx%d y la vista previa a %dx%d, 20 veces por segundo" % [SelfieCamera.PHOTO_PIXELS.x, SelfieCamera.PHOTO_PIXELS.y, SelfieCamera.PREVIEW_PIXELS.x, SelfieCamera.PREVIEW_PIXELS.y])
	var whole := true
	var iso := true
	var clipped := true
	var deepest := ""
	for spot in _layout.spots:
		var centre := _layout.position_of(spot)
		var side := SETTINGS.frame_start
		var view := SelfieCamera.compose(centre, [], _layout.camera_turn(spot), side, aspect)
		var basis := view.transform.basis
		var pitch := rad_to_deg(asin(basis.z.y))
		var yaw := fposmod(rad_to_deg(atan2(basis.z.x, basis.z.z)), 90.0)
		iso = iso and pitch >= 30.0 and pitch <= 35.0 and absf(yaw - 45.0) < 0.5
		var room := _layout.room_of(spot)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var point := centre + Vector3(corner.x * side / 2.0, 0.0, corner.y * side / 2.0)
			var local := view.transform.affine_inverse() * point
			whole = whole and absf(local.y) <= view.size / 2.0 and absf(local.x) <= view.size * aspect / 2.0
			#The nearest corner a frame reaches, with a head on top of the highest jump that still counts, stands behind the clip
			var far := centre + Vector3(corner.x * (room.x - SelfieLayout.FRAME_MARGIN), _jump_height + SETTINGS.air_room + IsoFrame.BODY_HEIGHT, corner.y * (room.y - SelfieLayout.FRAME_MARGIN))
			var depth := (far - centre).dot(basis.z)
			if depth >= _layout.camera_clip(spot):
				clipped = false
				deepest = "%s a %.1f m" % [spot, depth]
	_expect(iso, "la cámara de cada set es isométrica: inclinada de 30 a 35 grados y girada 45 sobre el marco")
	_expect(whole, "sin nadie, la foto encuadra el marco entero")
	_expect(clipped, "nadie que salga en la foto, ni saltando en la esquina más cercana del marco, queda delante del recorte de su set %s" % deepest)
	var hidden: Array[String] = []
	var rays := 0
	for spot in _layout.spots:
		var centre := _layout.position_of(spot)
		var room := _layout.room_of(spot) - Vector2.ONE * SelfieLayout.FRAME_MARGIN
		var toward := SelfieCamera.compose(centre, [], _layout.camera_turn(spot), SETTINGS.frame_start, aspect).transform.basis.z
		var blocked := 0
		for step_x in 7:
			for step_z in 7:
				#A body stands on whatever floor is there (a pad of the troll zone too), and shows when its feet or its head do
				var x := centre.x + lerpf(-room.x, room.x, step_x / 6.0)
				var z := centre.z + lerpf(-room.y, room.y, step_z / 6.0)
				var base := Vector3(x, _layout.height_at(x, z, centre.y + 2.0), z)
				var clip := _layout.camera_clip(spot)
				rays += 3
				var feet := _sight_blocked(base + Vector3(0.0, 0.02, 0.0), toward, centre, clip)
				var head := _sight_blocked(base + Vector3(0.0, IsoFrame.BODY_HEIGHT, 0.0), toward, centre, clip)
				var leap := _sight_blocked(base + Vector3(0.0, _jump_height + SETTINGS.air_room + IsoFrame.BODY_HEIGHT, 0.0), toward, centre, clip)
				if (feet and head) or leap:
					blocked += 1
		if blocked > 0:
			hidden.append("%s: %d" % [spot, blocked])
	_expect(hidden.is_empty(), "nada tapa a quien está en el marco: %d rayos desde los pies, las cabezas y los saltos hacia la cámara de cada set; de cada cuerpo se ven los pies o la cabeza, y su salto siempre %s" % [rays, hidden])
	for spot in _layout.spots:
		var centre := _layout.position_of(spot)
		var close_four: Array[Vector3] = [centre + Vector3(-0.6, 0.0, -0.6), centre + Vector3(0.6, 0.0, -0.6), centre + Vector3(0.6, 0.0, 0.6), centre + Vector3(-0.6, 0.0, 0.6)]
		var share := SelfieCamera.compose(centre, close_four, _layout.camera_turn(spot), SETTINGS.frame_end, aspect).body_share(IsoFrame.BODY_HEIGHT)
		var half := SETTINGS.frame_end / 2.0 - 0.05
		var spread: Array[Vector3] = [centre + Vector3(-half, 0.0, -half), centre + Vector3(half, 0.0, -half), centre + Vector3(half, 0.0, half), centre + Vector3(-half, 0.0, half)]
		var worst := SelfieCamera.compose(centre, spread, _layout.camera_turn(spot), SETTINGS.frame_end, aspect).body_share(IsoFrame.BODY_HEIGHT)
		var lone: Array[Vector3] = [centre]
		var single := SelfieCamera.compose(centre, lone, _layout.camera_turn(spot), SETTINGS.frame_end, aspect).body_share(IsoFrame.BODY_HEIGHT)
		if spot == &"T":
			print("  cuerpo en la foto: solo %.0f %%, cuatro juntos %.0f %%, cuatro en las esquinas del marco de %.1f m %.0f %%" % [single * 100.0, share * 100.0, SETTINGS.frame_end, worst * 100.0])
		_expect(share >= 0.3, "set %s: cuatro jugadores juntos miden %.0f %% del alto de la foto cada uno" % [spot, share * 100.0])


#Whether something solid stands between a point and the drone, closer to the set than the clip of its photo
func _sight_blocked(point: Vector3, toward: Vector3, centre: Vector3, clip: float) -> bool:
	var along := 0.15
	while (point + toward * along - centre).dot(toward) < clip:
		if _layout.solid_at(point + toward * along):
			return true
		along += 0.1
	return false


#The camera itself: the photo comes out once per shot as a picture of its own at full size, ready to shrink
func _check_camera() -> void:
	var camera := SelfieCamera.new()
	root.add_child(camera)
	var photos: Array[Texture2D] = []
	camera.developed.connect(func(_index: int, photo: Texture2D) -> void: photos.append(photo))
	var four: Array[Vector3] = [Vector3(-0.6, 0.0, -0.6), Vector3(0.6, 0.0, -0.6), Vector3(0.6, 0.0, 0.6), Vector3(-0.6, 0.0, 0.6)]
	camera.take(0, SelfieCamera.compose(Vector3.ZERO, four, 45.0, SETTINGS.frame_end), 6.0)
	for frame in 6:
		await process_frame
	var camera3d := camera.photo_camera()
	_expect(photos.size() == 1 and photos[0].get_width() == SelfieCamera.PHOTO_PIXELS.x and photos[0].get_height() == SelfieCamera.PHOTO_PIXELS.y,
		"la foto sale una vez y a su tamaño (%s)" % (str(photos[0].get_size()) if not photos.is_empty() else "nada"))
	_expect(camera3d.projection == Camera3D.PROJECTION_ORTHOGONAL and camera3d.cull_mask & SelfieCamera.layer_bit(SelfieCamera.FRAME_LAYER) == 0 \
		and camera3d.cull_mask & SelfieCamera.layer_bit(SelfieCamera.GUIDE_LAYER) == 0 and camera3d.cull_mask & 1 == 1,
		"la cámara de la foto es ortogonal y deja fuera el marco del piso, el haz del dron y las guías")
	_expect(not camera.is_live(), "la vista previa no se dibuja si no hay foto en camino")
	camera.queue_free()


#A whole round of somebody who always stands in the middle and poses in time
func _check_whole_round() -> void:
	var rules := _rules([1], 17)
	rules.start()
	while rules.phase != SelfieRules.Phase.DONE:
		if rules.frame_visible():
			rules.place(1, rules.frame_center(), true, false)
			if rules.phase == SelfieRules.Phase.LOCK and not rules.is_posing(1):
				rules.set_posing(1, true)
		elif rules.is_posing(1):
			rules.set_posing(1, false)
		rules.tick(0.05)
	var state := rules.state_of(1)
	_expect(state.photos == 8 and state.poses == 8 and state.followers == SHEET.selfie_max_followers(), "la ronda perfecta da el máximo: %d seguidores" % state.followers)
	_expect(SHEET.medal_for(rules.points_of(1)) == ScoreSheet.Medal.DIAMOND, "y vale Diamante (%d puntos)" % rules.points_of(1))
