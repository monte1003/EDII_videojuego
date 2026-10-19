class_name BotVisual
extends Node3D

#Provisional bot made of Godot primitives. It only draws: no physics, no AI.
#A final model replaces it by setting BotAppearance.model_scene; if that scene has
#"set_alert(active: bool)" the bot calls it when it announces a push.

#Materials are shared between every bot of the same colour
static var _materials: Dictionary = {}

var _alert_mark: Node3D
var _alert_tween: Tween


static func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material


func build(appearance: BotAppearance) -> void:
	var body := appearance.body_color
	var accent := appearance.accent_color
	var dark := body.darkened(0.35)

	_add(CapsuleMesh.new(), body, Vector3(0, 0.42, 0), Vector3.ONE, func(m: CapsuleMesh) -> void:
		m.radius = 0.3
		m.height = 0.72)
	_add(SphereMesh.new(), body.lightened(0.05), Vector3(0, 0.98, 0), Vector3.ONE, func(m: SphereMesh) -> void:
		m.radius = 0.3
		m.height = 0.6)
	for side in [-1.0, 1.0]:
		_add(SphereMesh.new(), dark, Vector3(side * 0.34, 0.45, 0.02), Vector3.ONE, func(m: SphereMesh) -> void:
			m.radius = 0.1
			m.height = 0.2)
		_add(SphereMesh.new(), dark, Vector3(side * 0.14, 0.06, 0.04), Vector3(1, 0.7, 1.3), func(m: SphereMesh) -> void:
			m.radius = 0.13
			m.height = 0.26)
		#Eyes: white with a dark pupil, on the +Z face
		_add(SphereMesh.new(), Color("fdfbff"), Vector3(side * 0.13, 1.02, 0.25), Vector3.ONE, func(m: SphereMesh) -> void:
			m.radius = 0.085
			m.height = 0.17)
		_add(SphereMesh.new(), Color("1b1530"), Vector3(side * 0.13, 1.02, 0.325), Vector3.ONE, func(m: SphereMesh) -> void:
			m.radius = 0.04
			m.height = 0.08)

	match appearance.detail:
		BotAppearance.Detail.BROWS:
			for side in [-1.0, 1.0]:
				var brow := _add_box(Vector3(0.17, 0.045, 0.04), Color("1b0a12"), Vector3(side * 0.13, 1.14, 0.265))
				brow.rotation.z = side * 0.5
		BotAppearance.Detail.NOTIFICATIONS:
			for i in 3:
				_add_box(Vector3(0.2, 0.1, 0.04), accent, Vector3(-0.06 + i * 0.06, 0.58 - i * 0.14, 0.29), 0.6)
		BotAppearance.Detail.X_PLATE:
			_add_box(Vector3(0.3, 0.26, 0.04), Color("e8f6f7"), Vector3(0, 0.46, 0.29))
			for s in [-1.0, 1.0]:
				var stroke := _add_box(Vector3(0.28, 0.05, 0.03), accent, Vector3(0, 0.46, 0.32), 0.5)
				stroke.rotation.z = s * 0.75
		BotAppearance.Detail.MIRROR_PLATES:
			for side in [-1.0, 1.0]:
				_add_box(Vector3(0.05, 0.26, 0.2), accent, Vector3(side * 0.33, 1.0, 0.0), 0.5)

	_alert_mark = Node3D.new()
	_alert_mark.position = Vector3(0, 1.62, 0)
	_alert_mark.visible = false
	add_child(_alert_mark)
	var alert_color := Color("ffd23f")
	_attach(_alert_mark, _box_mesh(Vector3(0.12, 0.3, 0.12)), alert_color, Vector3(0, 0.12, 0), 1.2)
	_attach(_alert_mark, _box_mesh(Vector3(0.12, 0.12, 0.12)), alert_color, Vector3(0, -0.1, 0), 1.2)


#Shown while the bot winds up a push, so the player can dodge it
func set_alert(active: bool) -> void:
	if _alert_mark == null:
		return
	_alert_mark.visible = active
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()
	_alert_mark.scale = Vector3.ONE
	if active:
		_alert_tween = create_tween().set_loops()
		_alert_tween.tween_property(_alert_mark, "scale", Vector3.ONE * 1.4, 0.15)
		_alert_tween.tween_property(_alert_mark, "scale", Vector3.ONE, 0.15)


func _add(mesh: Mesh, color: Color, at: Vector3, mesh_scale: Vector3, configure: Callable) -> MeshInstance3D:
	configure.call(mesh)
	var instance := _attach(self, mesh, color, at, 0.0)
	instance.scale = mesh_scale
	return instance


func _add_box(size: Vector3, color: Color, at: Vector3, emission := 0.0) -> MeshInstance3D:
	return _attach(self, _box_mesh(size), color, at, emission)


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _attach(parent: Node3D, mesh: Mesh, color: Color, at: Vector3, emission: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, emission)
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
