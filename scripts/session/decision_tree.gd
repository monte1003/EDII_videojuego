class_name DecisionTree
extends RefCounted

#Decision tree of a session: each level is a round and each child a minigame that can be
#played in it. A session is a path from the root to a leaf.

class DecisionNode:
	var value: StringName
	var level: int
	var children: Array[DecisionNode] = []

	func _init(node_value: StringName, node_level: int) -> void:
		value = node_value
		level = node_level


var root := DecisionNode.new(&"start", 0)


#The children of a node are the minigames not played yet on its path. When all of them were
#played (fewer minigames than rounds) any but the last one can come back.
static func build(pool: Array[StringName], rounds: int) -> DecisionTree:
	var tree := DecisionTree.new()
	tree._grow(tree.root, pool, rounds, [])
	return tree


#From the root to a leaf, drawing one child at random in every level
func random_path(rng: RandomNumberGenerator) -> Array[StringName]:
	var path: Array[StringName] = []
	var node := root
	while not node.children.is_empty():
		node = node.children[rng.randi_range(0, node.children.size() - 1)]
		path.append(node.value)
	return path


func node_count() -> int:
	return _count(root, false)


func leaf_count() -> int:
	return _count(root, true)


func _grow(node: DecisionNode, pool: Array[StringName], rounds: int, path: Array[StringName]) -> void:
	if node.level >= rounds:
		return
	for option in _options(pool, path):
		var child := DecisionNode.new(option, node.level + 1)
		node.children.append(child)
		var next_path := path.duplicate()
		next_path.append(option)
		_grow(child, pool, rounds, next_path)


func _options(pool: Array[StringName], path: Array[StringName]) -> Array[StringName]:
	var fresh: Array[StringName] = []
	for id in pool:
		if not path.has(id):
			fresh.append(id)
	if not fresh.is_empty():
		return fresh
	var last: StringName = path.back() if not path.is_empty() else &""
	var others: Array[StringName] = []
	for id in pool:
		if id != last:
			others.append(id)
	return others if not others.is_empty() else pool


func _count(node: DecisionNode, leaves_only: bool) -> int:
	if node.children.is_empty():
		return 1
	var total := 0 if leaves_only else 1
	for child in node.children:
		total += _count(child, leaves_only)
	return total
