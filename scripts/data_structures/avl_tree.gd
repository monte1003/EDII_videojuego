class_name AVLTree
extends Node

# Señales para comunicarnos con el mundo 3D (test_world.gd)
signal alarm_triggered(node_id: int, direction: int) # direction: -1 (izq), 1 (der)
signal critical_rotation(node_id: int, direction: int)
signal balance_restored(node_id: int)

# Nodo lógico (Matemático)
class AVLNode:
	var id: int
	var weight: int = 0
	var left: AVLNode = null
	var right: AVLNode = null
	
	func _init(node_id: int):
		id = node_id

var root: AVLNode
var nodes: Dictionary = {} # Para acceso rápido O(1) a cualquier nodo matemático

# Construye el árbol fijo de 7 nodos exacto como dice el PDF
func build_fixed_tree():
	# 1. Crear los 7 nodos
	for i in range(1, 8):
		nodes[i] = AVLNode.new(i)
	
	# 2. Conectar jerarquía (Nivel 1 -> Nivel 2 -> Nivel 3)
	root = nodes[1]
	
	root.left = nodes[2]
	root.right = nodes[3]
	
	nodes[2].left = nodes[4]
	nodes[2].right = nodes[5]
	
	nodes[3].left = nodes[6]
	nodes[3].right = nodes[7]

# Calcula recursivamente la suma de los pesos de todas las cajas en un subárbol
func get_subtree_weight(node: AVLNode) -> int:
	if node == null:
		return 0
	return node.weight + get_subtree_weight(node.left) + get_subtree_weight(node.right)

# Calcula el FE (Factor de Desequilibrio) = Peso Derecho - Peso Izquierdo
func get_balance(node: AVLNode) -> int:
	if node == null:
		return 0
	var right_weight = get_subtree_weight(node.right)
	var left_weight = get_subtree_weight(node.left)
	return right_weight - left_weight

# Se llama cuando una caja cae o el jugador la pone en una plataforma
func add_weight(node_id: int, amount: int = 1):
	if nodes.has(node_id):
		nodes[node_id].weight += amount
		_check_balance_all()

# Se llama cuando el jugador arroja la caja al ducto
func remove_weight(node_id: int, amount: int = 1):
	if nodes.has(node_id):
		nodes[node_id].weight = max(0, nodes[node_id].weight - amount)
		_check_balance_all()

# Evalúa el estado del árbol de abajo hacia arriba (Bottom-Up)
func _check_balance_all():
	# Revisamos primero los niveles inferiores (2 y 3) antes que la raíz (1)
	# Las hojas (4,5,6,7) no pueden rotar porque no tienen hijos.
	var check_order = [2, 3, 1] 
	
	for i in check_order:
		var node = nodes[i]
		var fe = get_balance(node)
		
		# Cambiamos el umbral a 2 para promover muchísimas rotaciones constantes
		if abs(fe) >= 2:
			critical_rotation.emit(node.id, sign(fe))
			return # Rompemos para que solo rote el subárbol más profundo afectado
		elif abs(fe) <= 1:
			balance_restored.emit(node.id)

# Función para limpiar el peso de un subárbol (ej. después de que una rotación tira todo)
func reset_weights_in_subtree(node_id: int):
	if nodes.has(node_id):
		_reset_weights_recursive(nodes[node_id])
		_check_balance_all()

func _reset_weights_recursive(node: AVLNode):
	if node == null:
		return
	node.weight = 0
	_reset_weights_recursive(node.left)
	_reset_weights_recursive(node.right)
