extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Obtener la gravedad de la configuración del proyecto
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	# Aplicar gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Saltar con la barra espaciadora ("ui_accept" por defecto)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Obtener la dirección en la que el jugador presiona (WASD o Flechas)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Calcular la dirección en 3D
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Mover al personaje
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# Función interna de Godot que aplica la velocidad y maneja las colisiones
	move_and_slide()
