class_name Level01Tiles
extends RefCounted

#Historias story tiles with no nodes: stepped tiles shake, drop and come back

#A local racer stepped on a tile: in a room the others are told
signal tile_stepped(plate: StringName, index: int)
signal tile_shaking(plate: StringName, index: int)
signal tile_dropped(plate: StringName, index: int)
signal tile_back(plate: StringName, index: int)

enum State { UP, SHAKING, GONE }

#Plate id -> [{"center", "state", "left"}]
var tiles: Dictionary = {}


func _init() -> void:
	for plate: StringName in Level01Layout.TILE_PLATES:
		var list: Array[Dictionary] = []
		for centre in Level01Layout.tile_centers(plate):
			list.append({"center": centre, "state": State.UP, "left": 0.0})
		tiles[plate] = list


#Advances time with the feet of the racers on the floor
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


#Starts shaking if up and valid: stepped here or told by another computer
func shake(plate: StringName, index: int) -> void:
	if not tiles.has(plate) or index < 0 or index >= (tiles[plate] as Array).size():
		return
	var tile: Dictionary = (tiles[plate] as Array)[index]
	if int(tile["state"]) != State.UP:
		return
	tile["state"] = State.SHAKING
	tile["left"] = Level01Layout.TILE_SHAKE
	tile_shaking.emit(plate, index)


#Feet over the tile square and on its top
func holds(tile: Dictionary, at: Vector3) -> bool:
	var centre: Vector3 = tile["center"]
	var half := Level01Layout.tile_side() / 2.0 + Level01Traps.BODY_RADIUS * 0.5
	return absf(at.x - centre.x) <= half and absf(at.z - centre.z) <= half and absf(at.y - centre.y) < 0.35


#The tile under a point comes back at once, so bubble landings are solid
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


#Shake progress, 0 to 1
func shake_share(plate: StringName, index: int) -> float:
	var tile: Dictionary = (tiles[plate] as Array)[index]
	if int(tile["state"]) != State.SHAKING:
		return 0.0
	return 1.0 - float(tile["left"]) / Level01Layout.TILE_SHAKE
