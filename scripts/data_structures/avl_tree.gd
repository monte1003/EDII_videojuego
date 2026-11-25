class_name AVLTree
extends RefCounted

#AVL tree of the standings; key: points, then best round, then lower player id

class AVLNode:
	var points: int
	var tie: int
	var player_id: int
	var height := 1
	var left: AVLNode
	var right: AVLNode

	func _init(score: int, tie_break: int, id: int) -> void:
		points = score
		tie = tie_break
		player_id = id


var root: AVLNode = null
#Rotations done by the insertions, to show the balancing
var rotations := 0

var _count := 0


func size() -> int:
	return _count


func get_height(node: AVLNode) -> int:
	return node.height if node != null else 0


func get_balance(node: AVLNode) -> int:
	if node == null:
		return 0
	return get_height(node.left) - get_height(node.right)


#Below zero when "a" ranks worse than "b"; zero only for the same key
static func compare(a: AVLNode, b: AVLNode) -> int:
	if a.points != b.points:
		return a.points - b.points
	if a.tie != b.tie:
		return a.tie - b.tie
	#The lower id ranks better
	return b.player_id - a.player_id


func right_rotate(y: AVLNode) -> AVLNode:
	var x := y.left
	var moved := x.right
	x.right = y
	y.left = moved
	_update_height(y)
	_update_height(x)
	rotations += 1
	return x


func left_rotate(x: AVLNode) -> AVLNode:
	var y := x.right
	var moved := y.left
	y.left = x
	x.right = moved
	_update_height(x)
	_update_height(y)
	rotations += 1
	return y


#Adds a score; false when that key already exists
func insert(points: int, player_id: int, tie := 0) -> bool:
	var before := _count
	root = _insert_node(root, AVLNode.new(points, tie, player_id))
	return _count > before


#Best to worst: reverse in-order walk
func standings() -> Array[AVLNode]:
	var result: Array[AVLNode] = []
	_walk_down(root, result)
	return result


#In-order walk: worst to best
func get_inorder_array() -> Array[AVLNode]:
	var result: Array[AVLNode] = []
	_inorder_traverse(root, result)
	return result


#Place of each player from 1; ties only when all but the id match
func places() -> Dictionary:
	var result: Dictionary = {}
	var order := standings()
	for index in order.size():
		var entry := order[index]
		var same := index > 0 and order[index - 1].points == entry.points and order[index - 1].tie == entry.tie
		result[entry.player_id] = result[order[index - 1].player_id] if same else index + 1
	return result


func is_balanced() -> bool:
	return _balanced(root)


func _insert_node(node: AVLNode, added: AVLNode) -> AVLNode:
	if node == null:
		_count += 1
		return added
	var order := compare(added, node)
	if order < 0:
		node.left = _insert_node(node.left, added)
	elif order > 0:
		node.right = _insert_node(node.right, added)
	else:
		return node
	_update_height(node)
	var balance := get_balance(node)
	#Left-Left
	if balance > 1 and compare(added, node.left) < 0:
		return right_rotate(node)
	#Right-Right
	if balance < -1 and compare(added, node.right) > 0:
		return left_rotate(node)
	#Left-Right
	if balance > 1 and compare(added, node.left) > 0:
		node.left = left_rotate(node.left)
		return right_rotate(node)
	#Right-Left
	if balance < -1 and compare(added, node.right) < 0:
		node.right = right_rotate(node.right)
		return left_rotate(node)
	return node


func _update_height(node: AVLNode) -> void:
	node.height = 1 + maxi(get_height(node.left), get_height(node.right))


func _inorder_traverse(node: AVLNode, result: Array[AVLNode]) -> void:
	if node != null:
		_inorder_traverse(node.left, result)
		result.append(node)
		_inorder_traverse(node.right, result)


func _walk_down(node: AVLNode, result: Array[AVLNode]) -> void:
	if node != null:
		_walk_down(node.right, result)
		result.append(node)
		_walk_down(node.left, result)


func _balanced(node: AVLNode) -> bool:
	if node == null:
		return true
	return absi(get_balance(node)) <= 1 and _balanced(node.left) and _balanced(node.right)
