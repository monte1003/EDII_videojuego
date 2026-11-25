class_name PodiumPlan
extends RefCounted

#Podium places and crowns without nodes: diamond, gold, silver and bronze by place; ties share

class Entry:
	var player_id: int
	var points: int
	var place: int
	#A ScoreSheet.Medal; NONE has no crown
	var crown: int
	#Stage block: 0 middle, then left, right and far left
	var slot: int
	var height: float


#Block height per place and block positions from the middle
const HEIGHTS: Array[float] = [2.3, 1.65, 1.15, 0.75]
const SLOTS: Array[float] = [0.0, -3.4, 3.4, -6.8]
const SOLO_HEIGHT := 1.9
const CROWNS: Array[int] = [ScoreSheet.Medal.DIAMOND, ScoreSheet.Medal.GOLD, ScoreSheet.Medal.SILVER, ScoreSheet.Medal.BRONZE]


#Everybody best to worst with place, crown, block and height
static func build(tree: AVLTree, solo_medal: int) -> Array[Entry]:
	var order := tree.standings()
	var places := tree.places()
	var entries: Array[Entry] = []
	for index in order.size():
		var node := order[index]
		var entry := Entry.new()
		entry.player_id = node.player_id
		entry.points = node.points
		entry.place = int(places[node.player_id])
		entry.slot = mini(index, SLOTS.size() - 1)
		if order.size() == 1:
			entry.crown = solo_medal
			entry.height = SOLO_HEIGHT
		else:
			var rank := clampi(entry.place - 1, 0, CROWNS.size() - 1)
			entry.crown = CROWNS[rank]
			entry.height = HEIGHTS[rank]
		entries.append(entry)
	return entries


#Reveal order, last to first
static func reveal_order(tree: AVLTree, entries: Array[Entry]) -> Array[Entry]:
	var by_id: Dictionary = {}
	for entry in entries:
		by_id[entry.player_id] = entry
	var order: Array[Entry] = []
	for node in tree.get_inorder_array():
		order.append(by_id[node.player_id])
	return order


static func slot_x(slot: int) -> float:
	return SLOTS[clampi(slot, 0, SLOTS.size() - 1)]
