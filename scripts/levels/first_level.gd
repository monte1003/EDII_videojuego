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
			print("✅ Plataforma conectada. ID: ", child.node_id)

# --- REACCIONES FÍSICAS AL DESBALANCE ---

func _on_avl_alarm(node_id: int, direction: int):
	print("⚠️ ALARMA en el nodo ", node_id, ". El lado pesado se hunde...")
	if platforms.has(node_id):
		platforms[node_id].warn_tilt(direction)

func _on_avl_critical(node_id: int, direction: int):
	print("🚨 DESPLOME CRÍTICO en el nodo ", node_id, "!")
	if platforms.has(node_id):
		platforms[node_id].critical_drop(direction)
		
	# En un juego real, aquí tiraríamos las cajas al vacío.
	# Por ahora, sanamos el árbol matemático después de 2 segundos para que se levante
	await get_tree().create_timer(2.0).timeout
	avl_tree.reset_weights_in_subtree(node_id)

func _on_avl_restored(node_id: int):
	print("⚖️ Equilibrio restaurado en el nodo ", node_id)
	if platforms.has(node_id):
		platforms[node_id].reset_tilt()

