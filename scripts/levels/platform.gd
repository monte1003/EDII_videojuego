extends Node3D
class_name AVLPlatform

# Identificador manual de la plataforma (1 al 7) que pondrás en el Editor
@export var node_id: int = 0

var weight: int = 0
var base_rotation: Vector3
var is_shaking: bool = false

# Señal para avisarle al gestor que nuestro peso cambió
signal weight_changed(node_id: int, amount: int)

var base_position: Vector3
var current_tween: Tween

func _ready():
	base_position = global_position

func _process(delta):
	var detector = get_node_or_null("WeightDetector")
	if not detector: return
	
	var has_player = false
	var has_box = false
	
	for body in detector.get_overlapping_bodies():
		if body.name == "Player" or body is CharacterBody3D:
			has_player = true
		elif body is RigidBody3D:
			has_box = true
			
	if has_player and has_box:
		print("💀 ¡EL JUGADOR HA MUERTO POR COMPARTIR PLATAFORMA CON UNA CAJA! 💀")
		get_tree().reload_current_scene()

# Estas funciones las conectaremos desde Godot al Area3D (la báscula)
func _on_weight_area_body_entered(body: Node3D) -> void:
	if body is RigidBody3D: 
		_recalculate_weight()

func _on_weight_area_body_exited(body: Node3D) -> void:
	if body is RigidBody3D:
		# Le damos medio segundo de tolerancia por si la caja solo saltó/rebotó
		await get_tree().create_timer(0.5).timeout
		_recalculate_weight()

func _recalculate_weight():
	var detector = get_node_or_null("WeightDetector")
	if not detector: return
	
	var real_weight = 0
	for b in detector.get_overlapping_bodies():
		if b is RigidBody3D:
			real_weight += 1
			
	if real_weight != weight:
		var diff = real_weight - weight
		weight = real_weight
		print("⚖️ Peso del Nodo ", node_id, " recalculado a: ", weight)
		weight_changed.emit(node_id, diff)

# Actualiza el peso de esta plataforma (cantidad de cajas)
func set_weight(w: int):
	weight = w

func clear_boxes():
	var detector = get_node_or_null("WeightDetector")
	if not detector: return
	for b in detector.get_overlapping_bodies():
		if b is RigidBody3D:
			b.queue_free()

func _kill_tween():
	if current_tween and current_tween.is_valid():
		current_tween.kill()

# Estado: Peligro (FE = 2) - Pequeño salto vertical para advertir
func warn_tilt(direction: float):
	_kill_tween()
	current_tween = create_tween()
	current_tween.set_loops() # Bucle infinito hasta que se cancele
	current_tween.tween_property(self, "global_position:y", base_position.y + 0.5, 0.5)
	current_tween.tween_property(self, "global_position:y", base_position.y, 0.5)

# Estado: Normal (FE = 0) - Volver a la posición base exacta
func reset_tilt():
	_kill_tween()
	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_SPRING)
	current_tween.tween_property(self, "global_position", base_position, 0.5)

# Rotación de Árbol: Volar a la nueva posición e intercambiar ID
func fly_to_position(target_pos: Vector3, new_id: int):
	_kill_tween()
	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_SINE)
	
	# Vuelo de 3 segundos para que el jugador disfrute el viaje
	current_tween.tween_property(self, "global_position", target_pos, 3.0)
	
	await current_tween.finished
	
	# Asumir la nueva identidad matemática
	node_id = new_id
	base_position = global_position
