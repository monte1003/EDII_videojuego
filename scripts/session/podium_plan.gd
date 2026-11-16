class_name PodiumPlan
extends RefCounted

#Who stands where at the end of a game and which crown each one wears, with no nodes. With several players the crowns go by place from
#the top: the first wears diamond, the second gold, the third silver and the fourth bronze, so the winner always wears the best one, and
#players tied in a place share its crown and its height. Alone, the crown is the medal of the whole game (none under bronze). The reveal
#goes from the last to the first: the in-order walk of the tree of scores, from the smallest key up

class Entry:
	var player_id: int
	var points: int
	var place: int
	#A ScoreSheet.Medal: NONE wears no crown
	var crown: int
	#Block of the stage: 0 is the middle one, then left, right and far left
	var slot: int
	var height: float


#Height of the block of each place, from the first to the fourth, and where each block stands across the stage, from the middle one
const HEIGHTS: Array[float] = [2.3, 1.65, 1.15, 0.75]
const SLOTS: Array[float] = [0.0, -3.4, 3.4, -6.8]
const SOLO_HEIGHT := 1.9
const CROWNS: Array[int] = [ScoreSheet.Medal.DIAMOND, ScoreSheet.Medal.GOLD, ScoreSheet.Medal.SILVER, ScoreSheet.Medal.BRONZE]


#Everybody from the best to the worst, each with its place, crown, block and height
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


#The order of the reveal, from the last to the first
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
