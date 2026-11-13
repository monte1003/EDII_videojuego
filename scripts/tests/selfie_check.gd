extends SceneTree

#Checks the perfect selfie with no scene: the map, the bag of photo spots, the frame, the followers of a photo, the pose,
#the power-ups and the shoves by player id
#run: godot --headless --path . --script res://scripts/tests/selfie_check.gd

const SHEET: ScoreSheet = preload("res://resources/score_sheet.tres")
const SETTINGS: SelfieSettings = preload("res://resources/levels/perfect_selfie.tres")

var _failures := 0
var _layout := SelfieLayout.new()


func _initialize() -> void:
	_check_map()
	_check_bag()
	_check_frame()
	_check_followers()
	_check_pose()
	_check_powers()
	_check_brawl()
	_check_whole_round()
	print("selfie_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _rules(ids: Array[int], seed_value := 3) -> SelfieRules:
	return SelfieRules.new(SETTINGS, SHEET, _layout, ids, seed_value)


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


func _check_map() -> void:
	var costs := _layout.build_graph().costs_from(SelfieLayout.HUB)
	var reachable := true
	for spot in _layout.spots:
		reachable = reachable and costs.has(spot)
	_expect(reachable and _layout.spots.size() == 8, "ocho sets de foto, todos alcanzables a pie desde el centro")
	var fits := true
	for spot in _layout.spots:
		var room := _layout.room_of(spot)
		fits = fits and minf(room.x, room.y) * 2.0 >= SETTINGS.frame_start * 1.22 + 0.7
	_expect(fits, "el marco más grande (%.1f m) cabe entero en el piso plano de cada set" % SETTINGS.frame_start)
	var heights: Dictionary = {}
	for id: StringName in _layout.places:
		heights[snappedf(_layout.position_of(id).y, 0.1)] = true
	_expect(heights.size() >= 5, "el mapa tiene muchas alturas distintas (%d)" % heights.size())
	var cannons := 0
	for pad in _layout.pads:
		cannons += int(ArenaHazards.is_cannon(pad))
	_expect(cannons >= 2 and _layout.ramps.size() >= 5, "hay rampas, pasarelas y %d cañones para subir a las azoteas" % cannons)
	var steep := 0.0
	for ramp in _layout.ramps:
		var from: Vector3 = ramp["from"]
		var to: Vector3 = ramp["to"]
		steep = maxf(steep, absf(to.y - from.y) / maxf(Vector2(to.x - from.x, to.z - from.z).length(), 0.01))
	_expect(steep < 0.75, "ninguna rampa pasa de 37 grados (pendiente máxima %.2f)" % steep)
	var seconds := (SETTINGS.travel_seconds + SETTINGS.frame_seconds + SETTINGS.lock_seconds + SETTINGS.reveal_seconds) * SETTINGS.photo_count
	_expect(seconds >= 90.0 and seconds <= 120.0, "las ocho fotos duran de 90 a 120 s (%.0f)" % seconds)
	_expect(_layout.pedestals.size() >= 4 and _layout.pedestals.size() <= 6, "de cuatro a seis pedestales (%d)" % _layout.pedestals.size())
	var path := _layout.flight_path(_layout.spots[0], _layout.spots[5])
	_expect(path.size() >= 2 and path[0].y > _layout.position_of(_layout.spots[0]).y + 5.0, "el dron vuela por los lugares de la ruta más corta (%d paradas)" % path.size())


func _check_bag() -> void:
	var rng := RandomNumberGenerator.new()
	var whole := true
	var orders: Dictionary = {}
	for seed_value in 60:
		rng.seed = seed_value
		var bag := SelfieRules.shuffled_spots(_layout.spots, rng)
		var seen: Dictionary = {}
		for spot in bag:
			seen[spot] = true
		whole = whole and bag.size() == 8 and seen.size() == 8
		orders[str(bag)] = true
	_expect(whole, "la bolsa trae los ocho lugares, ninguno repetido")
	_expect(orders.size() > 40, "el orden cambia de una partida a otra (%d órdenes en 60)" % orders.size())
	var table := _layout.travel_table(_layout.build_graph())
	var walkable := true
	var complete := true
	var far := 0
	for seed_value in 60:
		rng.seed = seed_value
		var route := SelfieRules.reachable_order(SelfieRules.shuffled_spots(_layout.spots, rng), table, SelfieLayout.HUB, SETTINGS.reach_seconds)
		var once: Dictionary = {}
		var at := SelfieLayout.HUB
		for spot in route:
			once[spot] = true
			if float(table[at][spot]) > SETTINGS.reach_seconds:
				far += 1
			at = spot
		complete = complete and route.size() == 8 and once.size() == 8
	walkable = far <= 30
	_expect(complete, "ordenada para poder caminarla, la bolsa sigue trayendo los ocho lugares una vez")
	_expect(walkable, "casi ninguna foto queda a más de %.1f s a pie de la anterior (%d de 480)" % [SETTINGS.reach_seconds, far])
	var rules := _rules([1])
	var visited: Array[StringName] = []
	rules.photo_announced.connect(func(_index: int, spot: StringName) -> void: visited.append(spot))
	_until(rules, SelfieRules.Phase.DONE)
	var unique: Dictionary = {}
	for spot in visited:
		unique[spot] = true
	_expect(visited.size() == 8 and unique.size() == 8, "una ronda entera fotografía cada lugar una sola vez")


func _check_frame() -> void:
	var rules := _rules([1], 11)
	_until(rules, SelfieRules.Phase.TRAVEL)
	_expect(not rules.frame_visible(), "mientras el dron viaja no hay marco")
	_expect(is_equal_approx(rules.final_size(0), SETTINGS.frame_start) and is_equal_approx(rules.final_size(7), SETTINGS.frame_end),
		"el marco baja de %.1f a %.1f m" % [SETTINGS.frame_start, SETTINGS.frame_end])
	_expect(rules.lock_seconds_of(7) < rules.lock_seconds_of(0), "las últimas fotos parpadean más rápido")
	var inside_island := true
	var moved := 0.0
	for photo in 8:
		_until(rules, SelfieRules.Phase.FRAME)
		var spot := _layout.position_of(rules.spot())
		var room := _layout.room_of(rules.spot())
		var before := rules.frame_center()
		while rules.phase == SelfieRules.Phase.FRAME:
			var centre := rules.frame_center()
			var half := rules.frame_size() / 2.0
			inside_island = inside_island and absf(centre.x - spot.x) + half <= room.x + 0.01 and absf(centre.z - spot.z) + half <= room.y + 0.01
			rules.tick(0.05)
		if photo == 7:
			moved = before.distance_to(rules.frame_center())
		var fixed := rules.frame_center()
		rules.tick(0.3)
		inside_island = inside_island and fixed.is_equal_approx(rules.frame_center()) and is_equal_approx(rules.frame_size(), rules.final_size(photo))
		_until(rules, SelfieRules.Phase.REVEAL)
		if photo < 7:
			_until(rules, SelfieRules.Phase.TRAVEL)
	_expect(inside_island, "el marco nunca se sale del piso de su set y queda quieto y a su tamaño cuando se fija")
	_expect(moved > 0.3, "en las últimas fotos el marco se mueve antes de fijarse (%.1f m)" % moved)


func _check_followers() -> void:
	var rules := _rules([1, 2, 3, 4])
	_to_shot(rules)
	var centre := rules.frame_center()
	var size := rules.final_size(0)
	rules.place(1, centre, true, false)
	rules.place(2, centre + Vector3(size * 0.4, 0.0, 0.0), true, false)
	rules.place(3, centre + Vector3(size * 0.6, 0.0, 0.0), true, false)
	rules.place(4, centre, false, false)
	var taken: Array[Dictionary] = []
	rules.photo_taken.connect(func(_index: int, shots: Dictionary) -> void: taken.append(shots))
	rules.tick(0.1)
	var shots: Dictionary = taken[0]
	var first: SelfieRules.Shot = shots[1]
	var second: SelfieRules.Shot = shots[2]
	var third: SelfieRules.Shot = shots[3]
	var fourth: SelfieRules.Shot = shots[4]
	_expect(first.inside and first.centered and second.inside and not second.centered, "dentro del marco salen los dos; solo uno está en el centro")
	_expect(not third.inside and third.followers == 0, "fuera del marco no se sale")
	_expect(not fourth.inside and fourth.followers == 0, "en el aire al disparo no se sale")
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
	_expect(bombed.state_of(1).followers == 50, "un bot dentro del marco cuenta como alguien más (%d)" % bombed.state_of(1).followers)
	var out := _rules([1])
	_to_shot(out)
	out.place(1, out.frame_center(), true, true)
	out.tick(0.1)
	_expect(out.state_of(1).followers == 0, "quien se cayó del mapa no sale aunque su posición coincida")
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
	_expect(late.state_of(1).poses == 0 and late.state_of(1).followers == 75, "una pose de última hora no cuenta: necesita %.1f s" % SETTINGS.pose_hold)
	var held := _rules([1])
	_until(held, SelfieRules.Phase.LOCK)
	held.place(1, held.frame_center(), true, false)
	held.set_posing(1, true)
	_until(held, SelfieRules.Phase.REVEAL)
	_expect(held.state_of(1).poses == 1 and held.state_of(1).followers == 195, "centro y pose a tiempo, solo en la foto: 130 por 1,5 (%d)" % held.state_of(1).followers)
	_check_toggle()


#One press of the key poses and the next one drops it; each pose is a different style from the one before
func _check_toggle() -> void:
	var rules := _rules([1])
	_until(rules, SelfieRules.Phase.FRAME)
	rules.place(1, rules.frame_center(), true, false)
	var styles: Array[int] = []
	var events: Array[Array] = []
	var on_pose := func(id: int, posing: bool, style: int) -> void: events.append([id, posing, style])
	rules.pose_changed.connect(on_pose)
	var same := false
	var out_of_range := false
	for press in 40:
		rules.toggle_pose(1)
		var style := rules.state_of(1).pose_style
		styles.append(style)
		out_of_range = out_of_range or style < 0 or style >= SETTINGS.pose_styles
		rules.toggle_pose(1)
	for index in range(1, styles.size()):
		same = same or styles[index] == styles[index - 1]
	rules.pose_changed.disconnect(on_pose)
	var distinct: Dictionary = {}
	for style in styles:
		distinct[style] = true
	_expect(events.size() == 80 and events[0][1] and not events[1][1], "una pulsación inicia la pose y la siguiente la quita (%d avisos)" % events.size())
	_expect(not same and not out_of_range, "cada pose es de un estilo distinto al anterior y siempre uno de los %d" % SETTINGS.pose_styles)
	_expect(distinct.size() == SETTINGS.pose_styles, "al azar salen los %d estilos (%d en 40 poses)" % [SETTINGS.pose_styles, distinct.size()])
	rules.place(1, rules.frame_center(), true, false)
	rules.toggle_pose(1)
	rules.strike(1)
	_expect(not rules.is_posing(1), "un golpe sobre quien posa la quita y se puede volver a posar con otra pulsación")
	_expect(rules.toggle_pose(1) and rules.is_posing(1), "con una pulsación nueva vuelve a posar")


func _check_powers() -> void:
	var rules := _rules([1, 2])
	rules.start()
	var jump := rules.pedestal_kinds.find(SelfieRules.Power.JUMP)
	var speed := rules.pedestal_kinds.find(SelfieRules.Power.SPEED)
	var shield := rules.pedestal_kinds.find(SelfieRules.Power.SHIELD)
	_expect(jump >= 0 and speed >= 0 and shield >= 0, "al empezar hay salto, velocidad y escudo en los pedestales")
	var given: Array[Array] = []
	rules.power_taken.connect(func(id: int, _pedestal: int, kind: int, seconds: float) -> void: given.append([id, kind, seconds]))
	_expect(rules.take_power(1, jump) and not rules.take_power(2, jump), "un potenciador se toma una sola vez")
	_expect(rules.jump_scale(1) > 1.2 and is_equal_approx(rules.jump_scale(2), 1.0), "el salto es de quien lo tomó")
	rules.take_power(2, speed)
	_expect(is_equal_approx(rules.speed_scale(2), SETTINGS.speed_scale) and is_equal_approx(rules.speed_scale(1), 1.0), "la velocidad sube %.2f veces" % SETTINGS.speed_scale)
	rules.tick(SETTINGS.boost_seconds + 0.1)
	_expect(is_equal_approx(rules.jump_scale(1), 1.0) and is_equal_approx(rules.speed_scale(2), 1.0), "a los %d s se acaban" % int(SETTINGS.boost_seconds))
	rules.take_power(1, shield)
	_expect(given.back()[1] == SelfieRules.Power.SHIELD and is_equal_approx(given.back()[2], SETTINGS.shield_seconds), "el escudo dura hasta %d s" % int(SETTINGS.shield_seconds))
	var returned: Array[int] = []
	rules.power_returned.connect(func(pedestal: int, _kind: int) -> void: returned.append(pedestal))
	rules.tick(SETTINGS.power_respawn - SETTINGS.boost_seconds - 0.5)
	_expect(returned.is_empty(), "un pedestal vacío espera %d s" % int(SETTINGS.power_respawn))
	rules.tick(1.0)
	_expect(returned.has(jump) and rules.pedestal_kinds[jump] >= 0, "y entonces vuelve a tener un potenciador")
	rules.state_of(1).followers = 300
	_expect(rules.is_last(2) and not rules.is_last(1), "con varios, va último quien tiene menos seguidores")
	_expect(not _rules([1]).is_last(1), "en solitario nadie va último")
	var free := rules.pedestal_kinds.find(SelfieRules.Power.SPEED)
	if free < 0:
		free = rules.pedestal_kinds.find(SelfieRules.Power.JUMP)
	rules.take_power(2, free)
	_expect(given.back()[0] == 2 and is_equal_approx(given.back()[2], SETTINGS.boost_seconds * SETTINGS.behind_bonus), "a quien va último le dura más (%.1f s)" % given.back()[2])
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
	brawl.tick(brawl.grace)
	_expect(brawl.strike(2) == ArenaBrawl.Outcome.STRUCK, "el siguiente ya pega")
	brawl.give_shield(1, 8.0)
	brawl.tick(8.1)
	_expect(not brawl.has_shield(1), "un escudo sin usar se acaba a los 8 s")
	_expect(not brawl.use_shove(99) and brawl.strike(99) == ArenaBrawl.Outcome.IGNORED, "un jugador que no existe no rompe nada")
	var others := {2: Vector3(0.0, 0.0, 1.2), 3: Vector3(0.0, 0.0, -1.0), 4: Vector3(0.0, 0.0, 5.0), 5: Vector3(0.3, 0.0, 0.8)}
	_expect(brawl.pick_victim(Vector3.ZERO, Vector3.BACK, others) == 5, "el empujón le da al más cercano de los que tiene delante")
	_expect(brawl.pick_victim(Vector3.ZERO, Vector3.RIGHT, {3: Vector3(0.0, 0.0, -1.0)}) == -1, "a quien está al lado o detrás no le da")
	_expect(brawl.pick_victim(Vector3.ZERO, Vector3.BACK, {4: Vector3(0.0, 0.0, 5.0)}) == -1, "ni a quien está lejos")


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
