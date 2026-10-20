class_name BotLook
extends Node3D

#What the bot AI knows of its look, whether primitives or a final model

@export var alert_height := 1.62

var _alert_mark: Node3D
var _alert_tween: Tween


func _ready() -> void:
	_alert_mark = _build_alert_mark()
	add_child(_alert_mark)


#Shown while the bot winds up a push, so the player can dodge it
func set_alert(active: bool) -> void:
	_alert_mark.visible = active
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()
	_alert_mark.scale = Vector3.ONE
	if active:
		_alert_tween = create_tween().set_loops()
		_alert_tween.tween_property(_alert_mark, "scale", Vector3.ONE * 1.4, 0.15)
		_alert_tween.tween_property(_alert_mark, "scale", Vector3.ONE, 0.15)


func set_moving(_moving: bool) -> void:
	pass


func play_push() -> void:
	pass


func _build_alert_mark() -> Node3D:
	var mark := Node3D.new()
	mark.position = Vector3(0.0, alert_height, 0.0)
	mark.visible = false
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.GOLD
	material.roughness = 0.55
	material.emission_enabled = true
	material.emission = Palette.GOLD
	material.emission_energy_multiplier = 1.2
	for part in [[Vector3(0.12, 0.3, 0.12), 0.12], [Vector3(0.12, 0.12, 0.12), -0.1]]:
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.position = Vector3(0.0, part[1], 0.0)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.add_child(instance)
	return mark
