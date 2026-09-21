class_name ScreenTree
extends RefCounted

#A screen of the game and the screens it can open from there
class ScreenNode:
	var id: StringName
	var title: String
	var scene_path: String
	var parent: ScreenNode
	var children: Array[ScreenNode] = []

	func _init(node_id: StringName, node_title: String, path: String) -> void:
		id = node_id
		title = node_title
		scene_path = path

	func depth() -> int:
		return 0 if parent == null else parent.depth() + 1


var root: ScreenNode

var _by_id: Dictionary = {}


func add_root(id: StringName, title: String, scene_path: String) -> ScreenNode:
	root = ScreenNode.new(id, title, scene_path)
	_by_id[id] = root
	return root


func add_screen(parent_id: StringName, id: StringName, title: String, scene_path: String) -> ScreenNode:
	var parent := find(parent_id)
	if parent == null:
		push_error("ScreenTree: la pantalla padre %s no existe" % parent_id)
		return null
	var node := ScreenNode.new(id, title, scene_path)
	node.parent = parent
	parent.children.append(node)
	_by_id[id] = node
	return node


func find(id: StringName) -> ScreenNode:
	return _by_id.get(id) as ScreenNode


func has(id: StringName) -> bool:
	return _by_id.has(id)


#Root down to the given screen, which is the trail shown at the top of each screen
func path_to(id: StringName) -> Array[ScreenNode]:
	var trail: Array[ScreenNode] = []
	var node := find(id)
	while node != null:
		trail.push_front(node)
		node = node.parent
	return trail


#Preorder walk, used by the screen that draws the whole tree
func preorder(from: ScreenNode = null) -> Array[ScreenNode]:
	var visited: Array[ScreenNode] = []
	_walk(from if from != null else root, visited)
	return visited


func _walk(node: ScreenNode, visited: Array[ScreenNode]) -> void:
	if node == null:
		return
	visited.append(node)
	for child in node.children:
		_walk(child, visited)
