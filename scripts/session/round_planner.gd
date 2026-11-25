class_name RoundPlanner
extends RefCounted

#Draws the minigame ids of a session in play order


static func plan(pool: Array[MinigameInfo], rounds: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var ids: Array[StringName] = []
	for info in pool:
		ids.append(info.id)
	if ids.is_empty():
		push_error("RoundPlanner: no hay minijuegos listos")
		return []
	return DecisionTree.build(ids, rounds).random_path(rng)
