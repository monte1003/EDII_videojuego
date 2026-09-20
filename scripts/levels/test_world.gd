extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

#Used when the scene runs without going through character select
@export var default_character: CharacterData

@onready var _spawn_point: Marker3D = $SpawnPoint
@onready var _pause_menu: PauseMenu = $PauseMenu

# Diccionario para guardar las plataformas (ej. {1: NodoRaiz, 2: HijoIzq...})
var platforms: Dictionary = {}

# El Árbol Lógico
var avl_tree: AVLTree

func _ready() -> void:
	# 1. Encontrar las plataformas que pusiste a mano en el editor
	_find_manual_platforms()
	
	# 2. Inicializar el cerebro matemático
	avl_tree = AVLTree.new()
	add_child(avl_tree)
	avl_tree.build_fixed_tree()
	
	# 3. Conectar los nervios (Señales Matemáticas -> Físicas)
	avl_tree.alarm_triggered.connect(_on_avl_alarm)
	avl_tree.critical_rotation.connect(_on_avl_critical)
	avl_tree.balance_restored.connect(_on_avl_restored)
	
	var character := GameState.get_character(GameState.PLAYER_ONE)
	if character == null:
		character = default_character

	var player := PLAYER_SCENE.instantiate() as Player
	player.player_id = GameState.PLAYER_ONE
	add_child(player)
	player.global_transform = _spawn_point.global_transform
	player.set_character(character)

	_pause_menu.opened.connect(player.set_input_enabled.bind(false))
	_pause_menu.closed.connect(player.set_input_enabled.bind(true))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _find_manual_platforms():
	# Recorremos todos los nodos hijos que hayas puesto en first_level
	for child in get_children():
		# Si el nodo tiene el script AVLPlatform, lo guardamos en el diccionario
		if child is AVLPlatform:
			platforms[child.node_id] = child
			# Conectamos la señal de la báscula al gestor
			child.weight_changed.connect(_on_platform_weight_changed)
			print("✅ Plataforma conectada. ID: ", child.node_id)

# --- SISTEMA DE PESOS ---
func _on_platform_weight_changed(node_id: int, amount: int):
	# Cuando una plataforma nos avisa que su peso cambió, se lo pasamos al árbol matemático
	if amount > 0:
		avl_tree.add_weight(node_id, amount)
	else:
		avl_tree.remove_weight(node_id, abs(amount))

# --- REACCIONES FÍSICAS AL DESBALANCE ---

func _on_avl_alarm(node_id: int, direction: int):
	print("⚠️ ALARMA en el nodo ", node_id, ". El lado pesado se hunde...")
	if platforms.has(node_id):
		platforms[node_id].warn_tilt(direction)
		
	# Si la alarma es en la raíz, todo el subárbol pesado también se inclina un poco
	if node_id == 1:
		if direction < 0: # Izquierda pesada
			platforms[2].warn_tilt(direction)
			platforms[4].warn_tilt(direction)
			platforms[5].warn_tilt(direction)
		elif direction > 0: # Derecha pesada
			platforms[3].warn_tilt(direction)
			platforms[6].warn_tilt(direction)
			platforms[7].warn_tilt(direction)

var is_rotating_tree: bool = false

func _on_avl_critical(node_id: int, direction: int):
	# Para simplificar la primera entrega, solo hacemos la rotación masiva en la raíz
	if node_id != 1 or is_rotating_tree: 
		return 
		
	is_rotating_tree = true
	
	# Consultamos a las matemáticas para saber QUÉ caso de AVL es exactamente
	var fe_root = avl_tree.get_balance(avl_tree.nodes[1])
	
	var p1 = platforms[1]
	var p2 = platforms[2]
	var p3 = platforms[3]
	
	var pos1 = p1.global_position
	var pos2 = p2.global_position
	var pos3 = p3.global_position
	
	if fe_root <= -3: # Pesado a la Izquierda
		var fe_left = avl_tree.get_balance(avl_tree.nodes[2])
		if fe_left <= 0:
			print("🚨 ROTACIÓN SIMPLE DERECHA (Caso LL) INICIADA 🚨")
			# 2 al centro(1), 1 a la derecha(3), 3 a la izquierda(2)
			p2.fly_to_position(pos1, 1)
			p1.fly_to_position(pos3, 3)
			p3.fly_to_position(pos2, 2)
		else:
			print("🚨 ROTACIÓN DOBLE DERECHA (Caso LR) INICIADA 🚨")
			# El problema está en el nieto interior (Plataforma 5). Ella sube a la raíz.
			var p5 = platforms[5]
			p5.fly_to_position(pos1, 1)
			p1.fly_to_position(pos3, 3)
			p3.fly_to_position(p5.base_position, 5)
			
	elif fe_root >= 3: # Pesado a la Derecha
		var fe_right = avl_tree.get_balance(avl_tree.nodes[3])
		if fe_right >= 0:
			print("🚨 ROTACIÓN SIMPLE IZQUIERDA (Caso RR) INICIADA 🚨")
			# 3 al centro(1), 1 a la izquierda(2), 2 a la derecha(3)
			p3.fly_to_position(pos1, 1)
			p1.fly_to_position(pos2, 2)
			p2.fly_to_position(pos3, 3)
		else:
			print("🚨 ROTACIÓN DOBLE IZQUIERDA (Caso RL) INICIADA 🚨")
			# El problema está en el nieto interior (Plataforma 6). Ella sube a la raíz.
			var p6 = platforms[6]
			p6.fly_to_position(pos1, 1)
			p1.fly_to_position(pos2, 2)
			p2.fly_to_position(p6.base_position, 6)
		
	# Esperar a que terminen de volar (3 segundos de tween + margen)
	await get_tree().create_timer(3.1).timeout
	
	# 1. Actualizar el diccionario con las nuevas identidades de los nodos
	var new_platforms = {}
	for p in platforms.values():
		new_platforms[p.node_id] = p
	platforms = new_platforms
	
	# 2. Borrar la memoria matemática del árbol
	avl_tree.reset_weights_in_subtree(1)
	
	# 3. Forzar a las plataformas a re-evaluar la realidad física y enviar sus pesos
	for p in platforms.values():
		p.weight = 0
		p._recalculate_weight()
		
	is_rotating_tree = false
	print("✅ ROTACIÓN COMPLETADA Y PESOS RECALCULADOS")

func _on_avl_restored(node_id: int):
	print("⚖️ Equilibrio restaurado en el nodo ", node_id)
	
	# Levantamos todas las plataformas para asegurar que todo vuelve a la normalidad
	for id in platforms.keys():
		platforms[id].reset_tilt()
