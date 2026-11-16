extends SceneTree

#Checks the trend war: the five zones on one island and that every bubble point is inside its own zone; that every point, jump, step
#and trampoline can be reached with the real numbers of the player and 20 % to spare; the board of bubbles one zone at a time, growing,
#with the trend of every player always there and the viral bubble; airplane mode with a real body in the real scene; the seed; and the
#rules by player id: one round per zone, a trend at a time, the viral one and the points.
#run: godot --headless --fixed-fps 60 --path . --script res://scripts/tests/trend_check.gd

const SHEET: ScoreSheet = preload("res://resources/score_sheet.tres")
const SETTINGS: TrendSettings = preload("res://resources/levels/trend_war.tres")
#The player only manages this share of what it could do in theory
const MARGIN := 0.8

var _failures := 0
#The real numbers of the player
var _speed := 0.0
var _jump := 0.0
var _gravity := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_measure()
	_check_zones()
	_check_roller()
	_check_glass()
	_check_islands()
	_check_maze()
	_check_tower()
	_check_par()
	_check_board()
	_check_seed()
	_check_rounds()
	_check_trends()
	_check_points()
	await _check_gravity_body()
	await _check_roller_body()
	print("trend_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _measure() -> void:
	var player := (load("res://scenes/characters/player.tscn") as PackedScene).instantiate() as Player
	_speed = player.move_speed
	_jump = player.jump_velocity
	player.free()
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	print("Constantes: velocidad %.2f m/s, salto %.2f m/s, gravedad %.2f; con el 80 %%: salto de %.2f m de alto y %.2f m de largo; con gravedad %.2f, %.2f m de alto" % [
		_speed, _jump, _gravity, _apex(1.0) * MARGIN, _reach(1.0) * MARGIN, TrendLayout.GRAVITY_SCALE, _apex(TrendLayout.GRAVITY_SCALE) * MARGIN])


#How high and how far a jump goes on flat ground with the pull of the ground times "scale"
func _apex(scale: float) -> float:
	return _jump * _jump / (2.0 * _gravity * scale)


func _reach(scale: float) -> float:
	return 2.0 * _jump / (_gravity * scale) * _speed


#Whether the middle of a body standing with its feet at "feet" reaches a bubble at "height"
func _touches_from(feet: float, height: float) -> bool:
	return absf(height - (feet + Player.TUMBLE_CENTER)) <= SETTINGS.touch_height


func _rules(ids: Array[int], seed_value := 5) -> TrendRules:
	return TrendRules.new(SETTINGS, SHEET, ids, seed_value)


#Runs the rules until the clock of the current trend is on
func _to_run(rules: TrendRules) -> void:
	rules.start()
	while rules.phase != TrendRules.Phase.RUN:
		rules.tick(0.1)


func _check_zones() -> void:
	var layout := TrendLayout.new()
	_expect(layout.islands.size() == 1 and layout.bridges.is_empty(), "el mapa es una sola isla, sin puentes ni vacío entre las zonas")
	var on_base := true
	for zone in TrendLayout.ZONE_COUNT:
		for corner in layout.zone_outline(zone):
			on_base = on_base and layout.is_inside(corner.x, corner.y, 1.0)
	_expect(on_base, "la alfombra de cada zona queda entera sobre la isla")
	var graph := layout.build_graph()
	var costs := graph.costs_from(TrendLayout.CORE)
	var reachable := true
	for id: StringName in layout.places:
		reachable = reachable and costs.has(id)
	_expect(reachable, "desde la plaza se llega a los %d lugares del mapa" % layout.places.size())
	var apart := true
	for a in TrendLayout.ZONE_COUNT:
		for b in range(a + 1, TrendLayout.ZONE_COUNT):
			apart = apart and layout.zone_center(a).distance_to(layout.zone_center(b)) > TrendLayout.SPANS[a] + TrendLayout.SPANS[b] + 4.0
	_expect(apart, "las cinco zonas no se tocan entre sí")
	var inside := true
	var wrong := ""
	for index in layout.slots.size():
		var slot: Dictionary = layout.slots[index]
		var at: Vector3 = slot["position"]
		var ok := layout.in_zone(int(slot["zone"]), at, 0.5) and layout.zone_at(at) == int(slot["zone"]) and layout.zone_slots(int(slot["zone"])).has(index)
		if not ok and wrong == "":
			wrong = "%s" % at.snappedf(0.1)
		inside = inside and ok
	_expect(inside, "cada uno de los %d puntos de burbuja está dentro de su zona %s" % [layout.slots.size(), wrong])
	var plenty := true
	for zone in TrendLayout.ZONE_COUNT:
		plenty = plenty and layout.zone_slots(zone).size() >= SETTINGS.bubbles_end + 1
	_expect(plenty, "cada zona tiene más puntos que burbujas a la vez, al final de su ronda")
	#From the plaza to where the play of every zone starts, and from one zone to the farthest of the others, on foot
	var walks: Array[float] = []
	var fine := true
	for zone in TrendLayout.ZONE_COUNT:
		var seconds := layout.approach_seconds(zone)
		walks.append(snappedf(seconds, 0.1))
		fine = fine and seconds <= 5.0
	_expect(fine, "de la plaza a la boca de cada zona hay 5 s a pie o menos %s" % [walks])
	var farthest := 0.0
	for a in TrendLayout.ZONE_COUNT:
		for b in TrendLayout.ZONE_COUNT:
			farthest = maxf(farthest, layout.seconds_by_route(layout.zone_start(a), layout.zone_start(b)))
	_expect(farthest <= SETTINGS.next_notice + 4.0, "entre las bocas de dos zonas cualesquiera hay %.1f s a pie: se llega poco después del aviso" % farthest)
	var labels := true
	for label in TrendLayout.LABELS:
		labels = labels and label.split(" ").size() <= 3 and label.length() <= 18
	_expect(labels, "el nombre de cada zona es corto: tres palabras como mucho")
	var steep := 0.0
	for ramp in layout.ramps:
		var from: Vector3 = ramp["from"]
		var to: Vector3 = ramp["to"]
		steep = maxf(steep, rad_to_deg(atan2(absf(to.y - from.y), Vector2(to.x - from.x, to.z - from.z).length())))
	_expect(steep <= 36.0, "toda subida a pie es una rampa de 36 grados o menos (la más empinada, %.0f)" % steep)
	var described := layout.describe()
	_expect((described["bubbles"] as Array).size() == layout.slots.size() and (described["zones"] as Array).size() == 5 and (described["floors"] as Array).size() > 20,
		"describe() entrega el mapa para medirlo desde fuera (%d pisos, %d muros, %d enlaces)" % [(described["floors"] as Array).size(),
			(described["walls"] as Array).size(), (described["links"] as Array).size()])


#The roller: its bar is low enough to jump with room to spare, and fast or slow it is crossed in less time than the feet stay over it
func _check_roller() -> void:
	var layout := TrendLayout.new()
	var spinner: Dictionary = layout.spinners[0]
	var height := Level01Hazards.BAR_HEIGHT
	_expect(height < _apex(1.0) * MARGIN, "la barra del rodillo (%.2f m) se salta con el 80 %% del salto (%.2f m)" % [height, _apex(1.0) * MARGIN])
	var lift := sqrt(MARGIN) * _jump
	var over := 2.0 * sqrt(lift * lift - 2.0 * _gravity * height) / _gravity
	var crossing := 2.0 * Level01Hazards.BAR_REACH / _speed
	_expect(crossing < over, "corriendo contra ella se cruza en %.2f s y los pies pasan %.2f s por encima" % [crossing, over])
	var slowest := INF
	var fastest := 0.0
	for step in 400:
		var time := step * 0.05
		var turn := Level01Hazards.angle_at(spinner, time + 0.01) - Level01Hazards.angle_at(spinner, time)
		slowest = minf(slowest, turn / 0.01)
		fastest = maxf(fastest, turn / 0.01)
	_expect(fastest > slowest * 2.0, "gira a velocidad que cambia: de %.2f a %.2f rad/s" % [slowest, fastest])
	var fine := true
	for index in layout.zone_slots(TrendLayout.Zone.ROLLER):
		var at: Vector3 = layout.slots[index]["position"]
		var flat := Vector2(at.x - spinner["at"].x, at.z - spinner["at"].z).length()
		fine = fine and _touches_from(0.0, at.y) and flat > TrendLayout.ROLLER_POST + 0.5 and flat < TrendLayout.ROLLER_ARM
	_expect(fine, "sus burbujas están bajo la barra, fuera del poste y se tocan de pie")


#The gravity zone: every bubble is reached by a jump from the floor, standing on the glass, or floating from a pad
func _check_glass() -> void:
	var layout := TrendLayout.new()
	var scale := TrendLayout.GRAVITY_SCALE
	var low := _apex(scale) * MARGIN
	var ceiling_feet := TrendLayout.GRAVITY_CEILING - 1.0
	var fine := true
	var ways: Dictionary = {}
	for index in layout.zone_slots(TrendLayout.Zone.GRAVITY):
		var at: Vector3 = layout.slots[index]["position"]
		var how := ""
		if at.y - (Player.TUMBLE_CENTER + low) <= SETTINGS.touch_height:
			how = "salto"
		elif _touches_from(ceiling_feet, at.y):
			how = "techo"
		else:
			#Floating up from the closest pad: the time to get to its height, and how far the player steers meanwhile
			var pad := layout.floor_pads[0]
			for other in layout.floor_pads:
				if Vector2(other.x - at.x, other.z - at.z).length() < Vector2(pad.x - at.x, pad.z - at.z).length():
					pad = other
			var rise := _float_time(at.y - Player.TUMBLE_CENTER, scale)
			if Vector2(pad.x - at.x, pad.z - at.z).length() <= _speed * MARGIN * rise + SETTINGS.touch_radius:
				how = "flotando"
		ways[how] = int(ways.get(how, 0)) + 1
		fine = fine and how != ""
		var centre := layout.zone_center(TrendLayout.Zone.GRAVITY)
		fine = fine and Vector2(at.x - centre.x, at.z - centre.z).length() <= TrendLayout.GRAVITY_RADIUS - 1.0
	_expect(fine, "cada burbuja de la gravedad se alcanza saltando, de pie en el cristal o flotando desde una almohadilla %s" % ways)
	_expect(ways.size() >= 3, "la zona pide las tres maneras: hay burbujas para cada una")
	_expect(low > _apex(1.0) * 2.0, "con gravedad %.2f el salto llega a %.2f m (con el 80 %%), más del doble que el normal" % [scale, low])


#Seconds from the floor pad until the feet are "height" up, with the kick of the pad and the turned pull, under the cap
func _float_time(height: float, scale: float) -> float:
	var speed := SETTINGS.pad_kick
	var climbed := 0.0
	var seconds := 0.0
	while climbed < height and seconds < 5.0:
		speed = minf(speed + _gravity * scale / 60.0, Player.FLOAT_MAX_SPEED)
		climbed += speed / 60.0
		seconds += 1.0 / 60.0
	return seconds


#The archipelago: from the dock every platform with a bubble is reached hop by hop, never by a gap longer than 80 % of a jump; the
#platforms never run into each other nor into the walls; one that sinks holds a moment first
func _check_islands() -> void:
	var layout := TrendLayout.new()
	var obstacles := TrendObstacles.new(layout)
	var hop := _reach(1.0) * MARGIN
	var count := layout.islets.size()
	var links: Dictionary = {}
	var widest := 0.0
	for a in range(-1, count):
		links[a] = []
	for a in range(-1, count):
		for b in range(a + 1, count):
			var best := INF
			for step in 96:
				best = minf(best, obstacles.islet_gap(a, b, step * 0.25))
			if best <= hop:
				(links[a] as Array).append(b)
				(links[b] as Array).append(a)
				widest = maxf(widest, best)
	var seen: Dictionary = {-1: true}
	var queue: Array = [-1]
	while not queue.is_empty():
		var node: int = queue.pop_front()
		for next: int in links[node]:
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	_expect(seen.size() == count + 1, "desde el muelle se llega a las %d plataformas saltando huecos de %.2f m como mucho (80 %% del salto)" % [count, hop])
	var clear := true
	var sample := ""
	for step in 96:
		var time := step * 0.25
		for a in count:
			var wall := false
			for point in obstacles._rim(a, time):
				var local := layout.to_zone(TrendLayout.Zone.ISLANDS, point)
				wall = wall or absf(local.x) > TrendLayout.POND_HALF.x or absf(local.y) > TrendLayout.POND_HALF.y
			if wall and sample == "":
				sample = "la %d contra la pared a los %.2f s" % [a, time]
			clear = clear and not wall
			for b in range(a + 1, count):
				var gap := obstacles.islet_gap(a, b, time)
				if gap <= 0.15 and sample == "":
					sample = "la %d y la %d a %.2f m a los %.2f s" % [a, b, gap, time]
				clear = clear and gap > 0.15
	_expect(clear, "ninguna plataforma choca con otra ni sale del estanque en todo su ciclo %s" % sample)
	var kinds: Dictionary = {}
	for islet in layout.islets:
		kinds[islet["kind"]] = true
	_expect(kinds.size() == 3 and TrendObstacles.SINK_SHAKE >= 0.5, "hay plataformas que se mueven, que giran y que se hunden (aguantan %.1f s antes de bajar)" % TrendObstacles.SINK_SHAKE)
	var above := true
	for index in layout.zone_slots(TrendLayout.Zone.ISLANDS):
		var at: Vector3 = layout.slots[index]["position"]
		var near := false
		for islet in count:
			#Standing on a platform at rest, 0.3 m inside its edge, the bubble is within reach
			var spot := Vector3(at.x, TrendLayout.ISLE_TOP, at.z)
			var middle: Vector3 = layout.islets[islet]["at"]
			if layout.islets[islet]["kind"] == &"slide":
				middle = (middle + (layout.islets[islet]["to"] as Vector3)) / 2.0
			var way := Vector3(spot.x - middle.x, 0.0, spot.z - middle.z)
			var stand := middle + way.limit_length(float((layout.islets[islet]["size"] as Vector2).x) - 0.3) if layout.islets[islet]["round"] else middle
			near = near or Vector2(stand.x - at.x, stand.z - at.z).length() <= SETTINGS.touch_radius
		above = above and near and _touches_from(TrendLayout.ISLE_TOP, at.y)
	_expect(above, "cada burbuja del archipiélago se toca de pie sobre una plataforma")
	var walls := TrendLayout.POND_WALL - TrendLayout.ISLE_TOP
	_expect(walls > _apex(1.0) * 1.2, "las paredes del estanque (%.1f m sobre el muelle) no se suben saltando" % walls)
	var fall := layout.zone_spot(TrendLayout.Zone.ISLANDS, 2.0, 1.0)
	_expect(obstacles.in_pond(fall) and layout.over_pond(obstacles.pond_exit(fall)) == false and not obstacles.in_pond(obstacles.pond_exit(fall) + Vector3(0.0, 0.05, 0.0)),
		"quien cae al agua vuelve al muelle, fuera del agua")


#The maze: with either group of screens up every cell is reached from the mouths, the walls are too high to jump, and its bubbles
#are inside cells
func _check_maze() -> void:
	var layout := TrendLayout.new()
	var obstacles := TrendObstacles.new(layout)
	var cycle := 2.0 * (TrendObstacles.SCREEN_UP + TrendObstacles.SCREEN_MOVE)
	var worst := 99
	var shut := 0.0
	for step in roundi(cycle * 10.0):
		var time := step * 0.1
		var open_count := _cells_open(layout, obstacles, time)
		if open_count < layout.maze_cells.size():
			shut += 0.1
		worst = mini(worst, open_count)
	_expect(shut <= 2.0 * TrendObstacles.SCREEN_MOVE + 0.25, "en cada instante se llega a todas las celdas, salvo mientras las pantallas se mueven (%.1f s de cada %.0f)" % [shut, cycle])
	var a_up := _cells_open(layout, obstacles, 1.0)
	var b_up := _cells_open(layout, obstacles, 1.0 + TrendObstacles.SCREEN_UP + TrendObstacles.SCREEN_MOVE)
	_expect(a_up == 16 and b_up == 16, "con un grupo arriba o con el otro, las 16 celdas se alcanzan desde las bocas")
	var turn := TrendObstacles.SCREEN_UP + TrendObstacles.SCREEN_MOVE
	_expect(obstacles.screen_rise(0, 1.0) == 1.0 and obstacles.screen_rise(1, 1.0) == 0.0 and obstacles.screen_rise(1, 1.0 + turn) == 1.0
		and obstacles.screen_rise(0, 1.0 + turn) == 0.0, "los dos grupos de pantallas suben por turnos, %.1f s cada uno" % TrendObstacles.SCREEN_UP)
	_expect(TrendLayout.SCREEN_HEIGHT > _apex(1.0) * 1.5, "sus muros y pantallas (%.1f m) no se saltan" % TrendLayout.SCREEN_HEIGHT)
	_expect(obstacles.screen_light(0, TrendObstacles.SCREEN_UP - 0.5) == TrendObstacles.Light.WARN and obstacles.screen_light(0, 1.0) == TrendObstacles.Light.SHUT
		and obstacles.screen_light(1, 1.0) == TrendObstacles.Light.OPEN, "la luz es roja arriba, verde abajo y avisa antes de cambiar")
	var inside := true
	for index in layout.zone_slots(TrendLayout.Zone.MAZE):
		var at: Vector3 = layout.slots[index]["position"]
		var local := layout.to_zone(TrendLayout.Zone.MAZE, at)
		inside = inside and absf(local.x) < TrendLayout.CELL * 2.0 and absf(local.y) < TrendLayout.CELL * 2.0 and _touches_from(0.0, at.y)
	_expect(inside, "sus burbujas están dentro de las celdas y se tocan de pie")
	var moved := obstacles.screen_nudge(_screen_middle(layout, 0), cycle - TrendObstacles.SCREEN_MOVE + 0.1)
	_expect(moved.length() > 0.2, "a quien está donde sube una pantalla se le saca de ahí (%.2f m)" % moved.length())


func _screen_middle(layout: TrendLayout, group: int) -> Vector3:
	for screen in layout.screens:
		if int(screen["group"]) == group:
			return ((screen["from"] as Vector3) + (screen["to"] as Vector3)) / 2.0
	return Vector3.ZERO


func _cells_open(layout: TrendLayout, obstacles: TrendObstacles, time: float) -> int:
	var seen: Dictionary = {}
	var queue: Array = []
	for mouth in layout.maze_mouths:
		seen[mouth] = true
		queue.append(mouth)
	while not queue.is_empty():
		var cell: int = queue.pop_front()
		for link in layout.maze_links:
			if not obstacles.maze_open(link, time):
				continue
			for pair: Array in [[link[0], link[1]], [link[1], link[0]]]:
				if int(pair[0]) == cell and not seen.has(int(pair[1])):
					seen[int(pair[1])] = true
					queue.append(int(pair[1]))
	return seen.size()


#The tower: no floor is climbed with a jump; every trampoline clears the edge of the floor it aims at; from the ground there is a
#way up to every floor that holds a bubble; the likes fall in turns on every floor and throw outward
func _check_tower() -> void:
	var layout := TrendLayout.new()
	var obstacles := TrendObstacles.new(layout)
	var step := TrendLayout.TOWER_TOPS[0]
	_expect(step > _apex(1.0) * 1.5, "cada piso de la torre (%.1f m) solo se sube con trampolín" % step)
	var lowest := INF
	var reached: Dictionary = {0: true}
	for pad in layout.pads:
		var from: Vector3 = pad["at"]
		var to: Vector3 = pad["to"]
		var level := layout.tower_level(to + Vector3(0.0, 0.05, 0.0))
		reached[level] = true
		var edge: float = TrendLayout.TOWER_RADII[level - 1]
		var push := ArenaHazards.pad_launch(pad, _gravity)
		var centre := layout.tower_center()
		var flat := Vector2(push.x, push.z)
		var start := Vector2(from.x - centre.x, from.z - centre.z)
		#The moment the arc crosses the edge, and how high the feet are over that floor then
		var seconds := 0.0
		while (start + flat * seconds).length() > edge and seconds < 3.0:
			seconds += 0.005
		var height := from.y + push.y * seconds - 0.5 * _gravity * seconds * seconds
		lowest = minf(lowest, height - to.y)
	_expect(lowest >= 0.3, "cada trampolín cruza el borde del piso al que va con los pies %.2f m por encima o más" % lowest)
	_expect(reached.size() == 4, "desde el suelo hay trampolines hasta los tres pisos")
	var levels: Dictionary = {}
	var fine := true
	for index in layout.zone_slots(TrendLayout.Zone.TOWER):
		var at: Vector3 = layout.slots[index]["position"]
		var floor_height: float = layout.slots[index]["floor"]
		levels[layout.tower_level(Vector3(at.x, floor_height + 0.05, at.z))] = true
		fine = fine and _touches_from(floor_height, at.y)
	_expect(fine and levels.size() == 4, "hay burbujas en los cuatro niveles y se tocan de pie")
	var falls: Dictionary = {}
	var outward := true
	for tick in 600:
		var time := tick * 0.05
		for like in obstacles.likes(time):
			if float(like["left"]) <= 0.0 and float(like["left"]) > -0.05:
				falls[like["level"]] = int(falls.get(like["level"], 0)) + 1
				var at: Vector3 = like["at"]
				var push := obstacles.like_push(at + Vector3(0.3, 0.0, 0.0), time)
				var away := Vector3(at.x - layout.tower_center().x, 0.0, at.z - layout.tower_center().z).normalized()
				outward = outward and push.dot(away) > 0.8
	_expect(falls.size() == 3 and outward, "en 30 s caen likes en los tres pisos %s y empujan hacia afuera" % falls)


#The par of the round: what a good player completes, a little less with more players to share the bubbles
func _check_par() -> void:
	var alone := SETTINGS.par_for(1)
	var crowd := SETTINGS.par_for(4)
	_expect(alone > 15.0 and alone < 60.0 and crowd < alone and crowd > alone * 0.6, "el par de la ronda es de %.0f tendencias solo y %.0f con cuatro" % [alone, crowd])


#The board: one zone at a time, every bubble on its points and announced by a ring first; more bubbles as the round goes on; the trend of
#every player always has a bubble; the viral one comes once; an old bubble moves somewhere else
func _check_board() -> void:
	var layout := TrendLayout.new()
	var board := TrendBoard.new(layout, SETTINGS, 9)
	var spot := layout.position_of(layout.zone_entry(TrendLayout.Zone.MAZE))
	var outside := [0]
	var announced := [0]
	var on_spawn := func(id: int) -> void:
		if not layout.zone_slots(board.zone).has(board.slot_of(id)):
			outside[0] += 1
	var on_announce := func(_id: int) -> void: announced[0] += 1
	board.bubble_spawned.connect(on_spawn)
	board.bubble_announced.connect(on_announce)
	board.open_zone(TrendLayout.Zone.MAZE, {1: spot}, {1: 2})
	var live := 0
	for id: int in board.bubbles:
		live += 1 if board.is_live(id) else 0
	_expect(board.bubbles.size() == SETTINGS.bubbles_start and live == 0 and board.count_of(2) >= 1,
		"al abrir la zona se anuncian %d burbujas con su anillo, ninguna nacida aún, y la tendencia del jugador está entre ellas" % board.bubbles.size())
	board.tick(SETTINGS.spawn_notice + 0.05, 0.0, {1: spot}, {1: 2})
	live = 0
	for id: int in board.bubbles:
		live += 1 if board.is_live(id) else 0
	_expect(live == board.bubbles.size(), "pasado el aviso, todas nacen")
	#A player follows its trends one after the other for the whole round of the zone
	var wanted := 2
	var missing := 0.0
	var taken := 0
	var most := 0
	var viral := 0
	var share := 0.0
	var step := 0
	while share < 1.0:
		share = step * 0.1 / SETTINGS.zone_seconds
		if step % 15 == 0:
			for id: int in board.bubbles.keys():
				if board.is_live(id) and (board.kind_of(id) == wanted or board.kind_of(id) == TrendRules.VIRAL):
					viral += 1 if board.kind_of(id) == TrendRules.VIRAL else 0
					spot = layout.slots[board.slot_of(id)]["position"]
					board.take(id)
					taken += 1
					wanted = (wanted + 1) % TrendCatalog.COUNT
					break
		board.tick(0.1, share, {1: spot}, {1: wanted})
		if board.count_of(wanted) == 0:
			missing += 0.1
		most = maxi(most, board.bubbles.size())
		step += 1
	_expect(outside[0] == 0 and announced[0] > taken, "ninguna burbuja nace fuera de la zona abierta, y cada una se anuncia (%d atrapadas)" % taken)
	_expect(missing < 0.01, "la tendencia que se sigue siempre tiene una burbuja en la zona")
	_expect(most >= SETTINGS.bubbles_end - 1 and most <= SETTINGS.bubbles_end + 1, "las burbujas van de %d a %d con la ronda (máximo %d)" % [SETTINGS.bubbles_start, SETTINGS.bubbles_end, most])
	_expect(viral == 1, "una burbuja viral por zona (%d)" % viral)
	var crowd := TrendBoard.new(layout, SETTINGS, 10)
	crowd.zone = TrendLayout.Zone.MAZE
	_expect(crowd.target_count(0.0, 4) == crowd.target_count(0.0, 1) + 3 * SETTINGS.bubbles_per_player, "con más jugadores hay más burbujas")
	#An old bubble goes and another one is announced somewhere else
	var still := TrendBoard.new(layout, SETTINGS, 11)
	still.open_zone(TrendLayout.Zone.ROLLER, {1: layout.zone_center(TrendLayout.Zone.ROLLER)}, {1: 1})
	var first: Array = still.bubbles.keys()
	var aged := 0.0
	while aged < SETTINGS.bubble_life + SETTINGS.spawn_notice + 0.3:
		still.tick(0.1, 0.0, {1: layout.zone_center(TrendLayout.Zone.ROLLER)}, {1: 1})
		aged += 0.1
	var renewed := true
	for id in first:
		renewed = renewed and not still.bubbles.has(id)
	_expect(renewed and still.bubbles.size() >= SETTINGS.bubbles_start, "una burbuja vieja se va y nace otra en otro punto")
	board.open_zone(TrendLayout.Zone.TOWER, {1: spot}, {1: wanted})
	var moved := true
	for id: int in board.bubbles:
		moved = moved and layout.zone_slots(TrendLayout.Zone.TOWER).has(board.slot_of(id))
	_expect(moved and outside[0] == 0, "la zona siguiente abre sus puntos y las burbujas de la anterior se van")
	board.close()
	_expect(board.bubbles.is_empty() and board.zone == -1, "al cerrar no queda ninguna burbuja")
	board.bubble_spawned.disconnect(on_spawn)
	board.bubble_announced.disconnect(on_announce)
	_expect(board.take(-5) == -1, "una burbuja que no existe no se atrapa")


#The same seed gives the same order of zones and the same bubbles; another seed gives others. Every zone comes once
func _check_seed() -> void:
	var layout := TrendLayout.new()
	var logs: Array[Array] = []
	for seed_value in [77, 77, 78]:
		var board := TrendBoard.new(layout, SETTINGS, seed_value)
		var record: Array = []
		var on_spawn := func(id: int) -> void:
			record.append([board.slot_of(id), board.kind_of(id)])
		board.bubble_spawned.connect(on_spawn)
		var order := TrendLayout.draw_zones(seed_value)
		record.append(order)
		for zone in order:
			board.open_zone(zone, {1: layout.zone_center(zone)}, {1: zone % 6})
			for step in 60:
				for id: int in board.bubbles.keys():
					if board.is_live(id) and board.kind_of(id) == zone % 6 and step % 7 == 0:
						board.take(id)
						break
				board.tick(0.1, step / 60.0, {1: layout.zone_center(zone)}, {1: zone % 6})
		board.bubble_spawned.disconnect(on_spawn)
		logs.append(record)
	_expect(logs[0] == logs[1] and logs[0].size() > 40, "con la misma semilla las zonas y las burbujas se repiten idénticas (%d nacimientos)" % (logs[0].size() - 1))
	_expect(logs[0] != logs[2], "y con otra semilla cambian")
	var once := true
	var orders: Dictionary = {}
	for seed_value in 40:
		var order := TrendLayout.draw_zones(seed_value)
		var sorted := order.duplicate()
		sorted.sort()
		once = once and sorted == [0, 1, 2, 3, 4]
		orders[str(order)] = true
	_expect(once and orders.size() > 20, "cada zona sale una vez por partida, en %d órdenes distintos con 40 semillas" % orders.size())


#One round per zone: the first is announced, then each one lasts its seconds and the next is announced before it ends
func _check_rounds() -> void:
	var rules := _rules([1])
	var log: Array[String] = []
	rules.zone_announced.connect(func(index: int, seconds: float) -> void: log.append("aviso %d %.0f" % [index, seconds]))
	rules.zone_started.connect(func(index: int) -> void: log.append("zona %d" % index))
	rules.finished.connect(func() -> void: log.append("fin"))
	rules.start()
	_expect(rules.phase == TrendRules.Phase.REVEAL and rules.needed(1) == -1, "al empezar se anuncia la primera zona y aún no se atrapa nada")
	var elapsed := 0.0
	while rules.phase != TrendRules.Phase.DONE and elapsed < 300.0:
		rules.tick(0.05)
		elapsed += 0.05
	var expected := ["aviso 0 %.0f" % SETTINGS.reveal_seconds, "zona 0"]
	for index in range(1, TrendLayout.ZONE_COUNT):
		expected.append("aviso %d %.0f" % [index, SETTINGS.next_notice])
		expected.append("zona %d" % index)
	expected.append("fin")
	_expect(", ".join(log) == ", ".join(expected), "aviso, zona, aviso de la siguiente antes de terminar... y fin: %s" % [log])
	var total := SETTINGS.reveal_seconds + SETTINGS.zone_seconds * TrendLayout.ZONE_COUNT
	_expect(absf(elapsed - total) < 0.2, "la ronda dura %.0f s (%.1f)" % [total, elapsed])
	_expect(rules.needed(1) == -1 and not rules.collect(1, 0), "terminada la ronda no se atrapa más")


#Every player follows one trend: only that kind or the viral one counts; completing it draws another one, never the same
func _check_trends() -> void:
	var rules := _rules([1, 2])
	_to_run(rules)
	var mine := rules.needed(1)
	_expect(mine >= 0 and mine < TrendCatalog.COUNT and rules.needed(2) >= 0, "cada jugador tiene una tendencia")
	var other := (mine + 1) % TrendCatalog.COUNT
	_expect(not rules.wants(1, other) and not rules.collect(1, other) and rules.state_of(1).completed == 0, "una burbuja de otra categoría no cuenta")
	_expect(rules.wants(1, TrendRules.VIRAL) and rules.wants(2, TrendRules.VIRAL), "la viral es la tendencia de todos")
	var changed := true
	for step in 60:
		var kind := rules.needed(1)
		_expect_quiet(rules.collect(1, kind))
		changed = changed and rules.needed(1) != kind
	_expect(changed and rules.state_of(1).completed == 60, "cumplir una tendencia suma una y trae otra distinta (60 seguidas)")
	var before := rules.needed(2)
	_expect(rules.collect(2, TrendRules.VIRAL) and rules.state_of(2).completed == SETTINGS.viral_value and rules.needed(2) == before,
		"la viral suma %d y no cambia la tendencia de quien la toma" % SETTINGS.viral_value)


func _expect_quiet(condition: bool) -> void:
	if not condition:
		_expect(false, "una tendencia que tocaba no contó")


#The points come from the trends against the par: the par gives all of them, half gives half, and each player keeps its own
func _check_points() -> void:
	var rules := _rules([1, 2])
	rules.par = 30.0
	_to_run(rules)
	for step in 30:
		rules.collect(1, rules.needed(1))
	for step in 15:
		rules.collect(2, rules.needed(2))
	_expect(rules.points_of(1) == 1000 and rules.points_of(2) == 500, "el par da 1000 y la mitad, 500 (%d y %d)" % [rules.points_of(1), rules.points_of(2)])
	for step in 10:
		rules.collect(1, rules.needed(1))
	var totals := rules.totals()
	_expect(rules.points_of(1) == 1000 and totals.size() == 2 and totals[2] == 500, "más del par no pasa de 1000 y cada puntaje es de su jugador")
	_expect(SHEET.trend_score(0, 30.0) == 0 and SHEET.trend_score(5, 0.0) == 1000, "sin tendencias 0, y un par imposible no rompe nada")


#The gravity zone in the real scene with a real body: it walks in (weak pull), steps on a pad (the pull turns and it floats up), stands
#on the glass upside down, steps on a pad up there (it turns back and floats down), and walks out (normal pull, on its feet)
func _check_gravity_body() -> void:
	var scene := (load("res://scenes/levels/trend_war.tscn") as PackedScene).instantiate()
	scene.hazards_enabled = false
	root.add_child(scene)
	current_scene = scene
	while int(scene.phase) != 1:
		await physics_frame
	var layout: TrendLayout = scene.layout
	var player: Player = scene.local_player()
	(player.get_node("PlayerInput") as Node).set_physics_process(false)
	var centre := layout.zone_center(TrendLayout.Zone.GRAVITY)
	var pad := layout.floor_pads[1]
	var start := centre + (pad - centre) * 1.55
	player.global_position = Vector3(start.x, 0.1, start.z)
	player.clear_motion()
	await _frames(20)
	_expect(not player.is_gravity_normal() and player.gravity_sign > 0.0 and is_equal_approx(player.gravity_scale, TrendLayout.GRAVITY_SCALE),
		"al entrar al cilindro la gravedad baja a %.2f sin darse vuelta" % player.gravity_scale)
	var hops := [0]
	player.gravity_changed.connect(func(_pull_sign: float, _pull_scale: float) -> void: hops[0] += 1)
	var turned := false
	var highest := 0.0
	for frame in 240:
		_walk(player, pad)
		await physics_frame
		highest = maxf(highest, player.global_position.y)
		if player.gravity_sign < 0.0:
			turned = true
		if turned and player.is_on_floor():
			break
	player.move_input = Vector2.ZERO
	await _frames(25)
	var model := player.find_children("*", "CharacterModel", true, false)[0] as Node3D
	_expect(turned, "al pisar una almohadilla la gravedad se invierte")
	_expect(player.is_on_floor() and player.global_position.y > TrendLayout.GRAVITY_CEILING - 1.3 and model.global_basis.y.dot(Vector3.DOWN) > 0.9,
		"flota hasta el cristal y queda de pie en él, cabeza abajo (a %.2f m)" % player.global_position.y)
	var above := layout.ceiling_pads[1]
	var down := false
	var lowest := 99.0
	for frame in 360:
		_walk(player, above)
		await physics_frame
		lowest = minf(lowest, player.global_position.y)
		if player.gravity_sign > 0.0:
			down = true
		if down and player.is_on_floor() and player.global_position.y < 0.5:
			break
	player.move_input = Vector2.ZERO
	await _frames(25)
	_expect(down and player.is_on_floor() and player.global_position.y < 0.3 and model.global_basis.y.dot(Vector3.UP) > 0.9,
		"una almohadilla del techo la vuelve a invertir: baja flotando y queda de pie en el piso")
	_expect(hops[0] >= 2, "cada rebote en una almohadilla invierte la gravedad (%d cambios)" % hops[0])
	var away := centre + Vector3(TrendLayout.GRAVITY_RADIUS + 4.0, 0.0, 0.0)
	var left := false
	for frame in 300:
		_walk(player, away)
		await physics_frame
		if not scene.obstacles.in_glass(player.global_position) and player.is_gravity_normal():
			left = true
			break
	player.move_input = Vector2.ZERO
	await _frames(20)
	_expect(left and player.is_gravity_normal() and player.up_direction == Vector3.UP and player.is_on_floor(),
		"al salir caminando vuelve la gravedad normal, de pie y sin quedar volteado")
	#From the glass, walking off its edge: a soft fall and back on its feet
	player.global_position = centre + Vector3(0.0, TrendLayout.GRAVITY_CEILING - 1.05, 0.0)
	player.clear_motion()
	player.set_gravity_state(-1.0, TrendLayout.GRAVITY_SCALE)
	await _frames(40)
	var hard := [false]
	player.landed.connect(func(_at: Vector3, was_hard: bool) -> void: hard[0] = hard[0] or was_hard)
	var fastest := 0.0
	var edge := centre + Vector3(0.0, 0.0, TrendLayout.GRAVITY_RADIUS + 3.0)
	for frame in 400:
		_walk(player, edge)
		await physics_frame
		fastest = maxf(fastest, -player.velocity.y)
		if player.is_gravity_normal() and player.is_on_floor() and player.global_position.y < 0.3:
			break
	player.move_input = Vector2.ZERO
	var before := player.global_position
	await _frames(30)
	_walk(player, before + Vector3(5.0, 0.0, 0.0))
	await _frames(20)
	player.move_input = Vector2.ZERO
	_expect(player.is_gravity_normal() and player.global_position.y < 0.3 and fastest <= Player.SAFE_FALL_SPEED + 0.05 and not hard[0] and not player.is_dazed(),
		"al salir por el borde del cristal cae suave (%.1f m/s como mucho) y aterriza sin golpe" % fastest)
	_expect(model.global_basis.y.dot(Vector3.UP) > 0.9 and player.global_position.distance_to(before) > 1.0, "y queda derecho y se puede mover (no queda pegado)")
	scene.queue_free()
	await _frames(3)


#The roller in the real scene: a body that waits in the way of its bar is thrown like a car in the street, flipped and down a moment
func _check_roller_body() -> void:
	var scene := (load("res://scenes/levels/trend_war.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	while int(scene.phase) != 1:
		await physics_frame
	var layout: TrendLayout = scene.layout
	var player: Player = scene.local_player()
	(player.get_node("PlayerInput") as Node).set_physics_process(false)
	var spinner: Dictionary = layout.spinners[0]
	var centre: Vector3 = spinner["at"]
	var spot := centre + Vector3(TrendLayout.ROLLER_ARM * 0.6, 0.1, 0.0)
	player.global_position = spot
	player.clear_motion()
	var hits: Array[Player.Hit] = []
	player.hit_taken.connect(func(hit: Player.Hit) -> void: hits.append(hit))
	var down := false
	var farthest := 0.0
	for frame in 900:
		await physics_frame
		if not hits.is_empty():
			down = down or player.is_down()
			farthest = maxf(farthest, Vector2(player.global_position.x - spot.x, player.global_position.z - spot.z).length())
			if frame > 0 and player.is_on_floor() and not player.is_down() and farthest > 0.5:
				break
	_expect(not hits.is_empty() and hits[0].flips and not hits[0].dazes and hits[0].push.length() >= 12.0,
		"la barra del rodillo golpea como un auto: voltea y lanza a %.1f m/s" % (hits[0].push.length() if not hits.is_empty() else 0.0))
	_expect(down and farthest > 3.0, "quien recibe el rodillo queda en el piso un momento y sale lanzado %.1f m" % farthest)
	scene.queue_free()
	await _frames(3)


func _walk(player: Player, goal: Vector3) -> void:
	var way := Vector3(goal.x - player.global_position.x, 0.0, goal.z - player.global_position.z)
	if way.length() < 0.15:
		player.move_input = Vector2.ZERO
		return
	var local: Vector3 = (player.get_node("CameraRig") as PlayerCamera).get_yaw_basis().inverse() * way.normalized()
	player.move_input = Vector2(local.x, local.z)


func _frames(count: int) -> void:
	for step in count:
		await physics_frame
