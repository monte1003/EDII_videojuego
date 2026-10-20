class_name AVLTree
extends Node

#Logical tree node
class AVLNode:
	var value: int
	var height: int
	var left: AVLNode
	var right: AVLNode

	func _init(val: int):
		value = val
		height = 1
		left = null
		right = null

var root: AVLNode = null

#Get the height of a node
func get_height(node: AVLNode) -> int:
	if node == null:
		return 0
	return node.height

#Get the balance factor of a node
func get_balance(node: AVLNode) -> int:
	if node == null:
		return 0
	return get_height(node.left) - get_height(node.right)

#AVL rotations to keep the tree balanced
func right_rotate(y: AVLNode) -> AVLNode:
	var x = y.left
	var T2 = x.right

	#Perform rotation
	x.right = y
	y.left = T2

	#Update heights
	y.height = max(get_height(y.left), get_height(y.right)) + 1
	x.height = max(get_height(x.left), get_height(x.right)) + 1

	return x

func left_rotate(x: AVLNode) -> AVLNode:
	var y = x.right
	var T2 = y.left

	#Perform rotation
	y.left = x
	x.right = T2

	#Update heights
	x.height = max(get_height(x.left), get_height(x.right)) + 1
	y.height = max(get_height(y.left), get_height(y.right)) + 1

	return y

#Public function called from outside
func insert(val: int):
	root = _insert_node(root, val)

#Internal recursive function
func _insert_node(node: AVLNode, val: int) -> AVLNode:
	#1. Regular Binary Search Tree insertion
	if node == null:
		return AVLNode.new(val)

	if val < node.value:
		node.left = _insert_node(node.left, val)
	elif val > node.value:
		node.right = _insert_node(node.right, val)
	else:
		return node #Duplicate values are not allowed for now

	#2. Update the height of the ancestor node
	node.height = 1 + max(get_height(node.left), get_height(node.right))

	#3. Get the balance factor to check if it became unbalanced
	var balance = get_balance(node)

	#4. If the node is unbalanced, try the 4 rotation cases:

	#Left-Left case (LL)
	if balance > 1 and val < node.left.value:
		print(">> Árbol Inestable: Ejecutando Rotación Simple Derecha en el nodo ", node.value)
		return right_rotate(node)

	#Right-Right case (RR)
	if balance < -1 and val > node.right.value:
		print(">> Árbol Inestable: Ejecutando Rotación Simple Izquierda en el nodo ", node.value)
		return left_rotate(node)

	#Left-Right case (LR)
	if balance > 1 and val > node.left.value:
		print(">> Árbol Inestable: Ejecutando Rotación Doble Izquierda-Derecha en el nodo ", node.value)
		node.left = left_rotate(node.left)
		return right_rotate(node)

	#Right-Left case (RL)
	if balance < -1 and val < node.right.value:
		print(">> Árbol Inestable: Ejecutando Rotación Doble Derecha-Izquierda en el nodo ", node.value)
		node.right = right_rotate(node.right)
		return left_rotate(node)

	return node

#In-order traversal (left, root, right), useful for the podium
func get_inorder_array() -> Array:
	var result = []
	_inorder_traverse(root, result)
	return result

func _inorder_traverse(node: AVLNode, result: Array):
	if node != null:
		_inorder_traverse(node.left, result)
		result.append(node.value)
		_inorder_traverse(node.right, result)
