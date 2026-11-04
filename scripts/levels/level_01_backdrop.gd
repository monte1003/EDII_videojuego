class_name Level01Backdrop
extends Node3D

#Giant hearts, chat bubbles, bells, phones, islands and clouds around the course: they give the level depth and its theme and never collide

#What floats around: model, how many, its size range (the measure that is fitted) and whether it is tall or long
const KINDS: Array[Dictionary] = [
	{"id": &"heart", "count": 6, "size": Vector2(4.5, 8.0), "tall": true},
	{"id": &"bubble", "count": 6, "size": Vector2(6.0, 10.0), "tall": false},
	{"id": &"bell", "count": 4, "size": Vector2(4.5, 7.5), "tall": true},
	{"id": &"phone", "count": 4, "size": Vector2(8.0, 13.0), "tall": true},
	{"id": &"island", "count": 6, "size": Vector2(9.0, 15.0), "tall": false},
	{"id": &"cloud", "count": 10, "size": Vector2(14.0, 26.0), "tall": false},
]
#The cloud sea under the course: big white clouds in one draw call
const SEA_COUNT := 90
const SEA_COLORS: Array[Color] = [Color("ffffff"), Color("f4f0ff"), Color("eaf3ff")]

var _items: Array[Dictionary] = []
var _clock := 0.0


func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var index := 0
	for kind in KINDS:
		for _step in kind["count"] as int:
			var side := -1.0 if index % 2 == 0 else 1.0
			index += 1
			var size := rng.randf_range((kind["size"] as Vector2).x, (kind["size"] as Vector2).y)
			var item: Node3D
			if kind["tall"]:
				item = PropKit.make_tall(kind["id"], size, Color.WHITE, false)
			else:
				item = PropKit.make_long(kind["id"], size, Color.WHITE, false)
			#Big pieces keep further out so they never swallow the course
			var gap := 84.0 + size * 0.6
			var at := Vector3(side * (gap + rng.randf_range(0.0, 50.0)), rng.randf_range(-6.0, 26.0), rng.randf_range(-175.0, 40.0))
			_add(item, at, atan2(-side, 0.8), rng)
	var sea := CloudField.new()
	sea.setup(Vector2(-170.0, 170.0))
	for cloud in SEA_COUNT:
		sea.add_cloud(Vector3(rng.randf_range(-170.0, 170.0), rng.randf_range(-38.0, -26.0), rng.randf_range(-230.0, 70.0)),
			rng.randf_range(4.0, 9.0), SEA_COLORS[cloud % SEA_COLORS.size()], rng.randf_range(0.5, 1.6), rng)
	add_child(sea)
	sea.commit()
	var sparks := PartyKit.sparkles(Vector3(70.0, 9.0, 75.0), 90)
	sparks.position = Vector3(0.0, 6.0, -58.0)
	add_child(sparks)


func _process(delta: float) -> void:
	_clock += delta
	for entry in _items:
		var node: Node3D = entry["node"]
		var wave: float = _clock * entry["speed"] + entry["phase"]
		node.position.y = entry["base_y"] + sin(wave) * 0.9
		node.rotation.y = entry["yaw"] + sin(wave * 0.7) * 0.22


func _add(item: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	item.position = at
	item.rotation.y = yaw
	add_child(item)
	_items.append({"node": item, "base_y": at.y, "yaw": yaw, "phase": rng.randf() * TAU, "speed": rng.randf_range(0.35, 0.8)})
