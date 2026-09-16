class_name AVLTree
extends Node

# ---------------------------------------------------------
# Clase interna para representar los Nodos lógicos del árbol
# ---------------------------------------------------------
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

# ---------------------------------------------------------
# Funciones Utilitarias
# ---------------------------------------------------------

# Obtener la altura de un nodo
func get_height(node: AVLNode) -> int:
	if node == null:
		return 0
	return node.height

# Obtener el factor de balance de un nodo
func get_balance(node: AVLNode) -> int:
	if node == null:
		return 0
	return get_height(node.left) - get_height(node.right)

# ---------------------------------------------------------
# Rotaciones AVL (Para mantener el árbol balanceado)
# ---------------------------------------------------------

func right_rotate(y: AVLNode) -> AVLNode:
	var x = y.left
	var T2 = x.right

	# Realizar rotación
	x.right = y
	y.left = T2

	# Actualizar alturas
	y.height = max(get_height(y.left), get_height(y.right)) + 1
	x.height = max(get_height(x.left), get_height(x.right)) + 1

	return x

func left_rotate(x: AVLNode) -> AVLNode:
	var y = x.right
	var T2 = y.left

	# Realizar rotación
	y.left = x
	x.right = T2

	# Actualizar alturas
	x.height = max(get_height(x.left), get_height(x.right)) + 1
	y.height = max(get_height(y.left), get_height(y.right)) + 1

	return y

# ---------------------------------------------------------
# Inserción
# ---------------------------------------------------------

# Función pública que llamaremos desde afuera
func insert(val: int):
	root = _insert_node(root, val)

# Función recursiva interna
func _insert_node(node: AVLNode, val: int) -> AVLNode:
	# 1. Inserción normal de un Árbol Binario de Búsqueda
	if node == null:
		return AVLNode.new(val)

	if val < node.value:
		node.left = _insert_node(node.left, val)
	elif val > node.value:
		node.right = _insert_node(node.right, val)
	else:
		return node # No permitimos valores duplicados por ahora

	# 2. Actualizar la altura del nodo ancestro
	node.height = 1 + max(get_height(node.left), get_height(node.right))

	# 3. Obtener el factor de balance para verificar si se desbalanceó
	var balance = get_balance(node)

	# 4. Si el nodo se desbalancea, probamos los 4 casos de rotación:

	# Caso Izquierda-Izquierda (LL)
	if balance > 1 and val < node.left.value:
		print(">> Árbol Inestable: Ejecutando Rotación Simple Derecha en el nodo ", node.value)
		return right_rotate(node)

	# Caso Derecha-Derecha (RR)
	if balance < -1 and val > node.right.value:
		print(">> Árbol Inestable: Ejecutando Rotación Simple Izquierda en el nodo ", node.value)
		return left_rotate(node)

	# Caso Izquierda-Derecha (LR)
	if balance > 1 and val > node.left.value:
		print(">> Árbol Inestable: Ejecutando Rotación Doble Izquierda-Derecha en el nodo ", node.value)
		node.left = left_rotate(node.left)
		return right_rotate(node)

	# Caso Derecha-Izquierda (RL)
	if balance < -1 and val < node.right.value:
		print(">> Árbol Inestable: Ejecutando Rotación Doble Derecha-Izquierda en el nodo ", node.value)
		node.right = right_rotate(node.right)
		return left_rotate(node)

	return node

# ---------------------------------------------------------
# Recorridos (Útil para mostrar el Podio de Puntos)
# ---------------------------------------------------------

# Recorrido Inorden (Izquierda, Raíz, Derecha)
func get_inorder_array() -> Array:
	var result = []
	_inorder_traverse(root, result)
	return result

func _inorder_traverse(node: AVLNode, result: Array):
	if node != null:
		_inorder_traverse(node.left, result)
		result.append(node.value)
		_inorder_traverse(node.right, result)
