extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const HATE_BOX_SCENE := preload("res://assets/models/hate_box.tscn")
const BOX_SPAWNER_SCRIPT := preload("res://scripts/levels/box_spawner.gd")

#Used when the scene runs without going through character select
@export var default_character: CharacterData

@onready var _spawn_point: Marker3D = $SpawnPoint
@onready var _pause_menu: PauseMenu = $PauseMenu

# Diccionario para guardar las plataformas (ej. {1: NodoRaiz, 2: HijoIzq...})
var platforms: Dictionary = {}

# El Árbol Lógico
var avl_tree: AVLTree
var spawner: BoxSpawner

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
	
	# 4. Iniciar el gestor de oleadas
	print("⚙️ Preparando para instanciar el BoxSpawner...")
	spawner = BOX_SPAWNER_SCRIPT.new()
	spawner.hate_box_scene = HATE_BOX_SCENE
	spawner.level_manager = self
	add_child(spawner)
	print("⚙️ BoxSpawner instanciado y añadido al árbol!")

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
	if is_rotating_tree: return # Ignoramos alarmas si hay una rotación crítica en curso
	
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
	# Solo rotamos nodos que tengan hijos (1, 2 o 3)
	if node_id not in [1, 2, 3] or is_rotating_tree: 
		return 
		
	is_rotating_tree = true
	
	var r = node_id
	var l = 0
	var d = 0
	var interior_l = 0
	var interior_d = 0
	
	if node_id == 1:
		l = 2
		d = 3
		interior_l = 5
		interior_d = 6
	elif node_id == 2:
		l = 4
		d = 5
	elif node_id == 3:
		l = 6
		d = 7
		
	# Consultamos a las matemáticas para saber QUÉ caso de AVL es exactamente
	var fe_root = avl_tree.get_balance(avl_tree.nodes[r])
	
	var pr = platforms[r]
	var pl = platforms[l]
	var pd = platforms[d]
	
	var pos_r = pr.global_position
	var pos_l = pl.global_position
	var pos_d = pd.global_position
	
	if fe_root <= -2: # Pesado a la Izquierda
		var fe_left = avl_tree.get_balance(avl_tree.nodes[l])
		if fe_left <= 0 or interior_l == 0:
			print("🚨 ROTACIÓN SIMPLE DERECHA (Caso LL) EN NODO ", r, " 🚨")
			pl.fly_to_position(pos_r, r)
			pr.fly_to_position(pos_d, d)
			pd.fly_to_position(pos_l, l)
		else:
			print("🚨 ROTACIÓN DOBLE DERECHA (Caso LR) EN NODO ", r, " 🚨")
			var p_interior = platforms[interior_l]
			p_interior.fly_to_position(pos_r, r)
			pr.fly_to_position(pos_d, d)
			pd.fly_to_position(p_interior.base_position, interior_l)
			
	elif fe_root >= 2: # Pesado a la Derecha
		var fe_right = avl_tree.get_balance(avl_tree.nodes[d])
		if fe_right >= 0 or interior_d == 0:
			print("🚨 ROTACIÓN SIMPLE IZQUIERDA (Caso RR) EN NODO ", r, " 🚨")
			pd.fly_to_position(pos_r, r)
			pr.fly_to_position(pos_l, l)
			pl.fly_to_position(pos_d, d)
		else:
			print("🚨 ROTACIÓN DOBLE IZQUIERDA (Caso RL) EN NODO ", r, " 🚨")
			var p_interior = platforms[interior_d]
			p_interior.fly_to_position(pos_r, r)
			pr.fly_to_position(pos_l, l)
			pl.fly_to_position(p_interior.base_position, interior_d)
		
	# Esperar a que terminen de volar (3 segundos de tween + margen)
	await get_tree().create_timer(3.1).timeout
	
	# Destruir las cajas causantes del desbalance
	var sub_tree = []
	if node_id == 1:
		sub_tree = [1, 2, 3, 4, 5, 6, 7]
	elif node_id == 2:
		sub_tree = [2, 4, 5]
	elif node_id == 3:
		sub_tree = [3, 6, 7]
		
	for id in sub_tree:
		if platforms.has(id):
			platforms[id].clear_boxes()
			
	await get_tree().process_frame # Esperar 1 frame físico a que mueran los nodos
	
	# 1. Actualizar el diccionario con las nuevas identidades de los nodos
	var new_platforms = {}
	for p in platforms.values():
		new_platforms[p.node_id] = p
	platforms = new_platforms
	
	# 2. Borrar la memoria matemática del sub-árbol rotado
	avl_tree.reset_weights_in_subtree(node_id)
	
	# 3. Forzar a las plataformas a re-evaluar la realidad física y enviar sus pesos
	for p in platforms.values():
		p.weight = 0
		p._recalculate_weight()
		
	is_rotating_tree = false
	print("✅ ROTACIÓN COMPLETADA Y CAJAS DESTRUIDAS")

func _on_avl_restored(node_id: int):
	if is_rotating_tree: return # Ignoramos restauraciones si hay rotación crítica en curso
	print("⚖️ Equilibrio restaurado en el nodo ", node_id)
	
	# Levantamos todas las plataformas para asegurar que todo vuelve a la normalidad
	for id in platforms.keys():
		platforms[id].reset_tilt()
