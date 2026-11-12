class_name TrendBoard
extends RefCounted

#Which bubble is where, with no nodes: the kind at each point of the map, the ones on their way back after being fetched and the
#items that fly loose after a shove. The scene only draws what is here

#Kind at each point; -1 when the point is empty
var kinds: Array[int] = []
#Loose items: {"kind", "position", "velocity", "left", "owner", "owner_rest", "floor"}
var loose: Array[Dictionary] = []

var _layout: TrendLayout
var _settings: TrendSettings
#Kinds waiting to come back: {"kind", "left", "from"}
var _pending: Array[Dictionary] = []
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _init(layout: TrendLayout, settings: TrendSettings) -> void:
	_layout = layout
	_settings = settings
	kinds.resize(layout.points.size())
	kinds.fill(-1)


#The same number of bubbles of every kind, shuffled over the points; a few points stay empty
func deal(rng: RandomNumberGenerator) -> void:
	var order: Array[int] = []
	for index in kinds.size():
		order.append(index)
	_shuffle(order, rng)
	kinds.fill(-1)
	_pending.clear()
	loose.clear()
	var placed := 0
	for kind in TrendCatalog.COUNT:
		for copy in _settings.copies_per_kind:
			if placed < order.size():
				kinds[order[placed]] = kind
				placed += 1


#The points that hold each kind right now: {kind: [point indices]}
func by_kind() -> Dictionary:
	var found: Dictionary = {}
	for index in kinds.size():
		if kinds[index] < 0:
			continue
		if not found.has(kinds[index]):
			found[kinds[index]] = [] as Array[int]
		(found[kinds[index]] as Array[int]).append(index)
	return found


func position_of(point: int) -> Vector3:
	return _layout.points[point]["position"]


#Takes the bubble of a point: the point is left empty and its kind comes back later on another one
func take(point: int) -> int:
	var kind := kinds[point]
	if kind < 0:
		return -1
	kinds[point] = -1
	_pending.append({"kind": kind, "left": _settings.respawn_seconds, "from": point})
	return kind


#Moves time on; returns the points where a bubble just came back
func tick(delta: float, rng: RandomNumberGenerator) -> Array[int]:
	var back: Array[int] = []
	for index in range(_pending.size() - 1, -1, -1):
		var entry := _pending[index]
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) > 0.0:
			continue
		var point := _free_point(int(entry["from"]), rng)
		if point < 0:
			continue
		kinds[point] = int(entry["kind"])
		back.append(point)
		_pending.remove_at(index)
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
	return back


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


#A random empty point, never the one the bubble was just taken from unless it is the only one
func _free_point(avoid: int, rng: RandomNumberGenerator) -> int:
	var free: Array[int] = []
	for index in kinds.size():
		if kinds[index] < 0 and index != avoid:
			free.append(index)
	if free.is_empty():
		return avoid if kinds[avoid] < 0 else -1
	return free[rng.randi() % free.size()]


func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi() % (index + 1)
		var kept := values[index]
		values[index] = values[other]
		values[other] = kept
