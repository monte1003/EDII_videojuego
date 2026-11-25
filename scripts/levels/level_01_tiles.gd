class_name Level01Tiles
extends RefCounted

#The plates of stories in Historias, with no nodes: every tile is up until a racer stands on it; then it shakes, drops and comes back a while
#later, like a story that lasts a day. The level gives it the feet of the racers on the floor and draws what it says. In a room a tile
#that a racer of another computer stepped on is told here (shake) and runs the same way, with its own clock

#A racer of this computer stepped on a tile: in a room the others are told
signal tile_stepped(plate: StringName, index: int)
signal tile_shaking(plate: StringName, index: int)
signal tile_dropped(plate: StringName, index: int)
signal tile_back(plate: StringName, index: int)

enum State { UP, SHAKING, GONE }

#Plate id -> Array of {"center": Vector3, "state": State, "left": seconds of its state}
var tiles: Dictionary = {}


func _init() -> void:
	for plate: StringName in Level01Layout.TILE_PLATES:
		var list: Array[Dictionary] = []
		for centre in Level01Layout.tile_centers(plate):
			list.append({"center": centre, "state": State.UP, "left": 0.0})
		tiles[plate] = list


#Moves time on: "feet" are the feet of the racers that stand on the floor
func tick(delta: float, feet: Array[Vector3]) -> void:
	for plate: StringName in tiles:
		var list: Array = tiles[plate]
		for index in list.size():
			var tile: Dictionary = list[index]
			match int(tile["state"]):
				State.UP:
					for at in feet:
						if holds(tile, at):
							shake(plate, index)
							tile_stepped.emit(plate, index)
							break
				State.SHAKING:
					tile["left"] = float(tile["left"]) - delta
					if float(tile["left"]) <= 0.0:
						tile["state"] = State.GONE
						tile["left"] = Level01Layout.TILE_GONE
						tile_dropped.emit(plate, index)
				State.GONE:
					tile["left"] = float(tile["left"]) - delta
					if float(tile["left"]) <= 0.0:
						tile["state"] = State.UP
						tile_back.emit(plate, index)


#A tile starts to shake, if it is up and exists: stepped on here or told by another computer of the room
func shake(plate: StringName, index: int) -> void:
	if not tiles.has(plate) or index < 0 or index >= (tiles[plate] as Array).size():
		return
	var tile: Dictionary = (tiles[plate] as Array)[index]
	if int(tile["state"]) != State.UP:
		return
	tile["state"] = State.SHAKING
	tile["left"] = Level01Layout.TILE_SHAKE
	tile_shaking.emit(plate, index)


#Whether feet at "at" stand on the tile: over its square and on its top
func holds(tile: Dictionary, at: Vector3) -> bool:
	var centre: Vector3 = tile["center"]
	var half := Level01Layout.tile_side() / 2.0 + Level01Traps.BODY_RADIUS * 0.5
	return absf(at.x - centre.x) <= half and absf(at.z - centre.z) <= half and absf(at.y - centre.y) < 0.35


#The tile under a point is put back at once (the bubble that brings a racer back lands on solid ground)
func restore_at(at: Vector3) -> void:
	for plate: StringName in tiles:
		var list: Array = tiles[plate]
		for index in list.size():
			var tile: Dictionary = list[index]
			var centre: Vector3 = tile["center"]
			var half := Level01Layout.tile_side() / 2.0 + 0.6
			if absf(at.x - centre.x) <= half and absf(at.z - centre.z) <= half and absf(at.y - centre.y) < 1.0 and int(tile["state"]) != State.UP:
				tile["state"] = State.UP
				tile["left"] = 0.0
				tile_back.emit(plate, index)


func state_of(plate: StringName, index: int) -> int:
	return int((tiles[plate] as Array)[index]["state"])


#How far along its shaking a tile is, 0 when it starts and 1 when it drops
func shake_share(plate: StringName, index: int) -> float:
	var tile: Dictionary = (tiles[plate] as Array)[index]
	if int(tile["state"]) != State.SHAKING:
		return 0.0
	return 1.0 - float(tile["left"]) / Level01Layout.TILE_SHAKE
