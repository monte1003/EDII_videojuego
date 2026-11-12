class_name Level01Backdrop
extends Node3D

#Giant hearts, chat bubbles, bells, phones, islands and clouds around the course: they give the level depth and its theme and never collide.
#Each one keeps clear of the big wheels and of every other piece, and sleeps when no camera is near

#What floats around: model, how many, its size range (the measure that is fitted) and whether it is tall or long
const KINDS: Array[Dictionary] = [
	{"id": &"heart", "count": 10, "size": Vector2(4.5, 8.0), "tall": true},
	{"id": &"bubble", "count": 10, "size": Vector2(6.0, 10.0), "tall": false},
	{"id": &"bell", "count": 6, "size": Vector2(4.5, 7.5), "tall": true},
	{"id": &"phone", "count": 6, "size": Vector2(8.0, 13.0), "tall": true},
	{"id": &"island", "count": 8, "size": Vector2(9.0, 15.0), "tall": false},
	{"id": &"cloud", "count": 14, "size": Vector2(14.0, 26.0), "tall": false},
]
#The cloud sea under the course: big white clouds, a few draw calls
const SEA_COUNT := 150
const SEA_COLORS: Array[Color] = [Color("ffffff"), Color("f4f0ff"), Color("eaf3ff")]
#The stretch of the course where pieces may float, away from the rainbows at both ends
const Z_RANGE := Vector2(-216.0, 192.0)
#Free air around each piece on top of its own size, and how many places are tried before a piece is left out
const BREATHING := 3.0
const TRIES := 30

var _items: Array[Dictionary] = []
#The balls (centre and radius) that are already taken: the wheels of the set and the pieces placed so far
var _taken: Array[Vector4] = []
var _clock := 0.0


func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for wheel in Level01Set.WHEELS:
		var at: Vector3 = wheel["at"]
		_taken.append(Vector4(at.x, at.y + float(wheel["radius"]) + 2.5, at.z, float(wheel["radius"]) + 3.0))
	var index := 0
	for kind in KINDS:
		for _step in kind["count"] as int:
			var size := rng.randf_range((kind["size"] as Vector2).x, (kind["size"] as Vector2).y)
			var reach := size * 0.75 + 1.0
			var place: Variant = _free_place(rng, size, reach, index)
			index += 1
			if place == null:
				continue
			var at := place as Vector3
			var item: Node3D
			if kind["tall"]:
				item = PropKit.make_tall(kind["id"], size, Color.WHITE, false)
			else:
				item = PropKit.make_long(kind["id"], size, Color.WHITE, false)
			_taken.append(Vector4(at.x, at.y, at.z, reach))
			_add(item, at, atan2(-signf(at.x), 0.8), rng)
	var sea := CloudField.new()
	sea.setup(Vector2(-170.0, 170.0))
	for cloud in SEA_COUNT:
		sea.add_cloud(Vector3(rng.randf_range(-170.0, 170.0), rng.randf_range(-38.0, -26.0), rng.randf_range(-310.0, 240.0)),
			rng.randf_range(4.0, 9.0), SEA_COLORS[cloud % SEA_COLORS.size()], rng.randf_range(0.5, 1.6), rng)
	add_child(sea)
	sea.commit()
	var sparks := PartyKit.sparkles(Vector3(80.0, 14.0, 190.0), 170)
	sparks.position = Vector3(0.0, 14.0, 20.0)
	add_child(sparks)
	#Little hearts float up over the whole course, like the likes of the crowd
	var likes := PartyKit.hearts(Vector3(70.0, 12.0, 150.0), 90)
	likes.position = Vector3(0.0, 14.0, 20.0)
	add_child(likes)


func _process(delta: float) -> void:
	_clock += delta
	for entry in _items:
		var node: Node3D = entry["node"]
		var wave: float = _clock * entry["speed"] + entry["phase"]
		node.position.y = entry["base_y"] + sin(wave) * 0.9
		node.rotation.y = entry["yaw"] + sin(wave * 0.7) * 0.22


#A spot beside the course (big pieces keep further out so they never swallow it) where a ball of radius "reach" touches nothing, or null
func _free_place(rng: RandomNumberGenerator, size: float, reach: float, index: int) -> Variant:
	for attempt in TRIES:
		var side := -1.0 if (index + attempt) % 2 == 0 else 1.0
		var gap := 84.0 + size * 0.6
		var at := Vector3(side * (gap + rng.randf_range(0.0, 50.0)), rng.randf_range(0.0, 44.0), rng.randf_range(Z_RANGE.x, Z_RANGE.y))
		var free := true
		for other in _taken:
			if at.distance_to(Vector3(other.x, other.y, other.z)) < reach + other.w + BREATHING:
				free = false
				break
		if free:
			return at
	return null


func _add(item: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	item.position = at
	item.rotation.y = yaw
	add_child(item)
	_items.append({"node": item, "base_y": at.y, "yaw": yaw, "phase": rng.randf() * TAU, "speed": rng.randf_range(0.35, 0.8)})
