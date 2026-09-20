extends Node
class_name BoxSpawner

@export var hate_box_scene: PackedScene
@export var level_manager: Node3D # Referencia al script first_level.gd

var current_wave: int = 1
var wave_timer: Timer
var spawn_timer: Timer

func _init():
	print("🟢 BoxSpawner instanciado en memoria!")

func _ready():
	print("🟢 BoxSpawner ha entrado al árbol y _ready se está ejecutando!")
	
	# Configurar el Temporizador de las Oleadas (30s cada una)
	wave_timer = Timer.new()
	wave_timer.wait_time = 30.0 
	wave_timer.one_shot = false
	wave_timer.timeout.connect(_on_wave_timeout)
	add_child(wave_timer)
	
	# Configurar el Temporizador de Generación de Cajas
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_spawn_box)
	add_child(spawn_timer)
	
	# Iniciar el juego
	_start_wave(1)

func _start_wave(wave: int):
	current_wave = wave
	print("🌊 ¡INICIA LA OLEADA ", current_wave, "! 🌊")
	
	# Ajustar dificultad para forzar más rotaciones constantes
	if current_wave == 1:
		spawn_timer.start(2.0)
	elif current_wave == 2:
		spawn_timer.start(1.2)
	elif current_wave == 3:
		spawn_timer.start(0.8)
	else:
		print("🏆 ¡HAS SOBREVIVIDO A TODAS LAS OLEADAS! 🏆")
		spawn_timer.stop()
		wave_timer.stop()
		return
		
	wave_timer.start()

func _on_wave_timeout():
	_start_wave(current_wave + 1)

func _get_adjacent_nodes(node_id: int) -> Array:
	match node_id:
		1: return [2, 3]
		2: return [1, 4, 5]
		3: return [1, 6, 7]
		4: return [2, 5] # Hijos de 2, físicamente cerca
		5: return [2, 4]
		6: return [3, 7] # Hijos de 3, físicamente cerca
		7: return [3, 6]
	return []

func _spawn_box():
	# Si el árbol está rotando, esperamos a la siguiente oportunidad (no caen cajas durante el caos)
	if level_manager and level_manager.is_rotating_tree:
		return
		
	print("🎲 El Spawner está intentando generar una caja...")
	
	# 1. Elegir nodo al azar entre todos los nodos (1, 2, 3, 4, 5, 6, o 7)
	var target_id = [1, 2, 3, 4, 5, 6, 7].pick_random()
	
	if not level_manager:
		return
		
	var platform = level_manager.platforms[target_id]
	
	# 1.5. Regla de Escape Seguro: Si el jugador está en target_id, comprobar si hay adyacentes libres
	var has_player = false
	var p_detector = platform.get_node_or_null("WeightDetector")
	if p_detector:
		for body in p_detector.get_overlapping_bodies():
			if body.name == "Player" or body is CharacterBody3D:
				has_player = true
				break
				
	if has_player:
		var has_free_adjacent = false
		for adj_id in _get_adjacent_nodes(target_id):
			if level_manager.platforms[adj_id].weight == 0:
				has_free_adjacent = true
				break
				
		if not has_free_adjacent:
			print("⚠️ El jugador en el nodo ", target_id, " está acorralado. El Spawner cambia de objetivo por piedad.")
			var valid_targets = [1, 2, 3, 4, 5, 6, 7]
			valid_targets.erase(target_id)
			target_id = valid_targets.pick_random()
			platform = level_manager.platforms[target_id]
	var pos = platform.global_position
	
	# 2. Crear Advertencia Visual en el piso (Sombra roja transparente)
	var warning = CSGCylinder3D.new()
	warning.radius = 1.2
	warning.height = 0.2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.4) # Rojo transparente
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning.material = mat
	warning.global_position = pos + Vector3(0, 0.5, 0)
	add_child(warning)
	
	# 3. Esperar 2 segundos de suspenso
	await get_tree().create_timer(2.0).timeout
	
	if is_instance_valid(warning):
		warning.queue_free()
				
	# 4. Instanciar la Caja Real cayendo
	if hate_box_scene:
		print("📦 ¡Caja instanciada cayendo del cielo!")
		var box = hate_box_scene.instantiate()
		get_tree().current_scene.add_child(box)
		box.global_position = pos + Vector3(0, 15, 0) # Cae desde el cielo
	else:
		print("❌ ERROR: La escena hate_box_scene no está cargada.")
