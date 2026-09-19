extends Node3D
class_name AVLPlatform

# Identificador manual de la plataforma (1 al 7) que pondrás en el Editor
@export var node_id: int = 0

var weight: int = 0
var base_rotation: Vector3

func _ready():
	base_rotation = rotation

# Actualiza el peso de esta plataforma (cantidad de cajas)
func set_weight(w: int):
	weight = w

# Estado: Alerta de Desbalance (FE = 2) - Inclinación leve
func warn_tilt(direction: float):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	# Inclina hasta 15 grados
	tween.tween_property(self, "rotation:z", deg_to_rad(15 * direction), 1.0)

# Estado: Rotación Crítica (FE = 3) - Desplome
func critical_drop(direction: float):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	# Se sacude y cae 45 grados para tirar todo
	tween.tween_property(self, "rotation:z", deg_to_rad(45 * direction), 0.5)

# Volver a la normalidad (FE = 0)
func reset_tilt():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SPRING)
	tween.tween_property(self, "rotation", base_rotation, 1.0)
