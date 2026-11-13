class_name TrendBoard
extends RefCounted

#The bubbles of the trend war, with no nodes: they are born at a point of the map, live a few seconds and go, and another one is
#born somewhere else, so there are always about as many. Where each one is born is decided here so that it is fair: kinds come
#from a shuffled bag, no kind runs short or piles up in one zone, nothing appears on top of a player, the distance to it is
#about the same for everybody, and the kind a player needs is always within reach. The same seed gives the same game

signal bubble_spawned(id: int)
signal bubble_gone(id: int, taken: bool)

#Seconds on foot that suit a new bubble when there is only one player to be fair to
const SOLO_DISTANCE := 5.5
#How many of the best points a new bubble picks from, so the map is not the same every time
const CHOICES := 3
#How much a point costs when its zone already holds bubbles of that kind, and per bubble of any kind in its zone
const SAME_ZONE_COST := 5.0
const CROWD_COST := 0.5
#A bubble for somebody who needs its kind is born between these seconds on foot from that player
const NEED_NEAR := 2.5
#Seconds a rescue for the same player rests
const NEED_REST := 0.5


class Bubble:
	var id: int
	var point: int
	var kind: int
	var age := 0.0
	var life := 10.0
	var phase := 0.0


#Every bubble alive, by its id
var bubbles: Dictionary = {}
#Loose items: {"kind", "position", "velocity", "left", "owner", "owner_rest", "floor"}
var loose: Array[Dictionary] = []
#Seconds this board has run
var clock := 0.0
#How many bubbles went before their time to make room for one that somebody needed
var rescues := 0

var _layout: TrendLayout
var _settings: TrendSettings
var _rng := RandomNumberGenerator.new()
var _next_id := 1
#Point index -> id of the bubble on it
var _on_point: Dictionary = {}
var _point_rest: Array[float] = []
var _bag: Array[int] = []
var _need_rest: Dictionary = {}
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _init(layout: TrendLayout, settings: TrendSettings, seed_value: int) -> void:
	_layout = layout
	_settings = settings
	_rng.seed = seed_value
	_point_rest.resize(layout.points.size())
	_point_rest.fill(0.0)


#The first bubbles of the round, already at different ages so they do not all go at once. "players" is {player id: position}
func fill(players: Dictionary) -> void:
	while bubbles.size() < _settings.bubble_target:
		var bubble := _spawn(_next_kind(), players, -1)
		if bubble == null:
			break
		bubble.age = _rng.randf() * bubble.life * 0.55


#Moves time on: bubbles age and go, new ones are born to keep the count, and whoever needs a kind gets one within reach.
#"players" is {player id: position} and "wanted" {player id: kind it has to fetch now}
func tick(delta: float, players: Dictionary, wanted: Dictionary) -> void:
	clock += delta
	for index in _point_rest.size():
		_point_rest[index] = maxf(_point_rest[index] - delta, 0.0)
	for id: int in _need_rest:
		_need_rest[id] = maxf(float(_need_rest[id]) - delta, 0.0)
	for bubble: Bubble in bubbles.values():
		bubble.age += delta
		if bubble.age >= bubble.life:
			_remove(bubble.id, false)
	#The count is made up first, so every kind keeps its minimum; then whoever needs a kind gets one within reach
	while bubbles.size() < _settings.bubble_target:
		if _spawn(_next_kind(), players, -1) == null:
			break
	for id: int in wanted:
		if int(wanted[id]) >= 0 and players.has(id) and float(_need_rest.get(id, 0.0)) <= 0.0 and not within_reach(players[id], wanted[id]):
			_rescue(id, wanted[id], players, wanted)
	_tick_loose(delta)


func kind_of(id: int) -> int:
	return (bubbles[id] as Bubble).kind if bubbles.has(id) else -1


#How many bubbles of a kind are alive
func count_of(kind: int) -> int:
	var count := 0
	for bubble: Bubble in bubbles.values():
		if bubble.kind == kind:
			count += 1
	return count


#The zones that hold a bubble of a kind right now
func zones_of(kind: int) -> Array[int]:
	var found: Array[int] = []
	for bubble: Bubble in bubbles.values():
		var zone: int = _layout.points[bubble.point]["zone"]
		if bubble.kind == kind and not found.has(zone):
			found.append(zone)
	return found


#How much of its life a bubble has spent, from 0 to 1, and the seconds it has left
func life_share(id: int) -> float:
	var bubble: Bubble = bubbles[id]
	return clampf(bubble.age / bubble.life, 0.0, 1.0)


func life_left(id: int) -> float:
	var bubble: Bubble = bubbles[id]
	return maxf(bubble.life - bubble.age, 0.0)


#Where a bubble floats: over its point, bobbing, and going around it in a slow circle when the bubbles drift
func position_of(id: int, drift: bool) -> Vector3:
	var bubble: Bubble = bubbles[id]
	var point: Dictionary = _layout.points[bubble.point]
	var at: Vector3 = point["position"]
	if drift:
		var turn := clock * _settings.drift_speed + bubble.phase
		at += Vector3(cos(turn), 0.0, sin(turn)) * _settings.drift_radius
	return at + Vector3(0.0, float(point["lift"]) + sin(clock * 1.6 + bubble.phase) * 0.12, 0.0)


#Takes a bubble: it is gone at once and another one will be born somewhere else. Returns its kind, or -1 when it was not there
func take(id: int) -> int:
	if not bubbles.has(id):
		return -1
	var kind := (bubbles[id] as Bubble).kind
	_remove(id, true)
	return kind


#An item knocked out of a player: it flies away from the blow and can be picked up for a while
func drop(kind: int, from: Vector3, direction: Vector3, owner: int) -> void:
	var away := Vector3(direction.x, 0.0, direction.z)
	if away.length() < 0.1:
		away = Vector3.FORWARD
	loose.append({"kind": kind, "position": from + Vector3(0.0, 1.0, 0.0), "velocity": away.normalized() * 3.2 + Vector3(0.0, 5.0, 0.0),
		"left": _settings.loose_seconds, "owner": owner, "owner_rest": _settings.loose_owner_rest, "floor": from.y + TrendLayout.BUBBLE_HEIGHT})


#Whether "player_id" may pick up a loose item now: its owner has to wait a moment
func can_pick(item: Dictionary, player_id: int) -> bool:
	return int(item["owner"]) != player_id or float(item["owner_rest"]) <= 0.0


func take_loose(index: int) -> int:
	var kind := int(loose[index]["kind"])
	loose.remove_at(index)
	return kind


func _remove(id: int, taken: bool) -> void:
	var bubble: Bubble = bubbles[id]
	bubbles.erase(id)
	_on_point.erase(bubble.point)
	_point_rest[bubble.point] = _settings.point_rest
	bubble_gone.emit(id, taken)


#The kind of the next bubble: whichever kind is running short, or else the next one of a bag that holds every kind twice,
#shuffled, so no kind comes in a streak
func _next_kind() -> int:
	var lowest := 0
	for kind in TrendCatalog.COUNT:
		if count_of(kind) < count_of(lowest):
			lowest = kind
	if count_of(lowest) < _settings.min_per_kind:
		return lowest
	#A kind that is all in one zone gets its next bubble somewhere else before the bag goes on
	for kind in TrendCatalog.COUNT:
		if zones_of(kind).size() < 2 and count_of(kind) < _settings.max_per_kind:
			return kind
	for attempt in TrendCatalog.COUNT * 2:
		if _bag.is_empty():
			for kind in TrendCatalog.COUNT:
				_bag.append(kind)
				_bag.append(kind)
			for index in range(_bag.size() - 1, 0, -1):
				var other := _rng.randi() % (index + 1)
				var kept := _bag[index]
				_bag[index] = _bag[other]
				_bag[other] = kept
		var kind: int = _bag.pop_back()
		if count_of(kind) < _settings.max_per_kind:
			return kind
	return lowest


#A new bubble of "kind" at the fairest free point. With "near" (a player id) it is born within reach of that player instead
func _spawn(kind: int, players: Dictionary, near: int) -> Bubble:
	var point := _pick_point(kind, players, near)
	if point < 0:
		return null
	var bubble := Bubble.new()
	bubble.id = _next_id
	_next_id += 1
	bubble.point = point
	bubble.kind = kind
	bubble.life = _rng.randf_range(_settings.life_seconds.x, _settings.life_seconds.y)
	bubble.phase = _rng.randf() * TAU
	bubbles[bubble.id] = bubble
	_on_point[point] = bubble.id
	bubble_spawned.emit(bubble.id)
	return bubble


#Scores every free point (the lower the better) and picks one of the best at random
func _pick_point(kind: int, players: Dictionary, near: int) -> int:
	var zones := zones_of(kind)
	var crowd: Dictionary = {}
	for bubble: Bubble in bubbles.values():
		var zone: int = _layout.points[bubble.point]["zone"]
		crowd[zone] = int(crowd.get(zone, 0)) + 1
	var scored: Array[Array] = []
	var fallback: Array[Array] = []
	for point in _layout.points.size():
		if _on_point.has(point) or _point_rest[point] > 0.0:
			continue
		var zone: int = _layout.points[point]["zone"]
		var closest := INF
		var farthest := 0.0
		for id: int in players:
			var seconds := _layout.seconds_from(players[id], point)
			closest = minf(closest, seconds)
			farthest = maxf(farthest, seconds)
		var score := CROWD_COST * int(crowd.get(zone, 0))
		if zones.has(zone):
			#A kind never ends up all in one zone: while it is in a single one, its next bubble goes elsewhere
			if zones.size() == 1 and near < 0:
				continue
			score += SAME_ZONE_COST
		if near >= 0 and players.has(near):
			var mine := _layout.seconds_from(players[near], point)
			if mine > _settings.reach_seconds - 1.0:
				continue
			score += absf(mine - (NEED_NEAR + _settings.reach_seconds) / 2.0) + (4.0 if mine < NEED_NEAR else 0.0)
		elif players.size() > 1:
			score += farthest - closest
		elif players.size() == 1:
			score += absf(closest - SOLO_DISTANCE) * 0.5
		if closest < _settings.spawn_clear_seconds:
			fallback.append([score + 20.0, point])
		else:
			scored.append([score, point])
	if scored.is_empty():
		scored = fallback
	if scored.is_empty():
		return -1
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return scored[_rng.randi() % mini(CHOICES, scored.size())][1]


#Whether a player has a bubble of a kind close enough, and with enough life left to get to it
func within_reach(spot: Vector3, kind: int) -> bool:
	for bubble: Bubble in bubbles.values():
		if bubble.kind != kind:
			continue
		var seconds := _layout.seconds_from(spot, bubble.point)
		if seconds <= _settings.reach_seconds and bubble.life - bubble.age >= seconds + 1.0:
			return true
	return false


#A bubble of the kind a player needs is born within its reach. When the map is full, or the kind is already at its top, another
#bubble gives it room: the oldest one of the kind there is most of among those that can lose one, or else one of that same kind
func _rescue(player_id: int, kind: int, players: Dictionary, wanted: Dictionary) -> void:
	_need_rest[player_id] = NEED_REST
	var full := count_of(kind) >= _settings.max_per_kind
	if bubbles.size() >= _settings.bubble_target or full:
		var from_kind := kind
		if not full:
			#The kind with the most bubbles that can lose one and is not this one; one that nobody is after comes first
			var most := -1
			for other in TrendCatalog.COUNT:
				if other == kind or count_of(other) <= _settings.min_per_kind:
					continue
				var better := most < 0 or count_of(other) > count_of(most) \
					or (count_of(other) == count_of(most) and wanted.values().has(most) and not wanted.values().has(other))
				if better:
					most = other
			from_kind = most if most >= 0 else kind
		var oldest: Bubble = null
		for bubble: Bubble in bubbles.values():
			if bubble.kind == from_kind and (oldest == null or bubble.age / bubble.life > oldest.age / oldest.life):
				oldest = bubble
		if oldest == null:
			return
		rescues += 1
		_remove(oldest.id, false)
	_spawn(kind, players, player_id)


func _tick_loose(delta: float) -> void:
	for index in range(loose.size() - 1, -1, -1):
		var item := loose[index]
		item["left"] = float(item["left"]) - delta
		item["owner_rest"] = maxf(float(item["owner_rest"]) - delta, 0.0)
		if float(item["left"]) <= 0.0:
			loose.remove_at(index)
			continue
		#It flies in an arc and stays floating a little over the floor it came from
		var velocity: Vector3 = item["velocity"]
		var position: Vector3 = item["position"]
		velocity.y -= _gravity * delta
		position += velocity * delta
		if position.y <= float(item["floor"]):
			position.y = float(item["floor"])
			velocity = Vector3.ZERO
		item["velocity"] = velocity
		item["position"] = position
