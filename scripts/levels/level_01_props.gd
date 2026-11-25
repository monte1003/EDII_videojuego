class_name Level01Props
extends Node3D

#Level 1 pieces with a job: checkpoint hearts and the power symbol of the goal

const LILAC_DARK := Color("6d55c2")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")
const AMBER := Color("ffc857")
const INK := Color("372c58")
const PAPER := Color("fdfbff")

var checkpoint_positions: Dictionary = {}

#Checkpoint -> heart and ring materials
var _heart_materials: Dictionary = {}
var _ring_materials: Dictionary = {}


func build() -> void:
	for vertex in Level01Layout.CHECKPOINTS:
		_checkpoint(vertex)
	_goal()


#Grey-lilac heart that lights up once saved
func set_checkpoint_active(vertex: StringName, active: bool) -> void:
	if not _heart_materials.has(vertex):
		return
	for material: StandardMaterial3D in _heart_materials[vertex]:
		material.albedo_color = Color.WHITE if active else Color(0.74, 0.7, 0.9)
		material.emission_enabled = active
		material.emission = MAGENTA
		material.emission_energy_multiplier = 0.5
	var ring := AMBER if active else CYAN
	var ring_material: StandardMaterial3D = _ring_materials[vertex]
	ring_material.albedo_color = ring
	ring_material.emission = ring


#Checkpoint: flag pole with a heart
func _checkpoint(vertex: StringName) -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[vertex]
	checkpoint_positions[vertex] = centre
	var ring := CylinderMesh.new()
	ring.top_radius = 1.5
	ring.bottom_radius = 1.5
	ring.height = 0.04
	ring.radial_segments = 32
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = CYAN
	ring_material.emission_enabled = true
	ring_material.emission = CYAN
	ring_material.emission_energy_multiplier = 1.4
	_ring_materials[vertex] = ring_material
	_add(ring, ring_material, centre + Vector3(0, 0.03, 0))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 3.2
	pole.radial_segments = 8
	_add(pole, _mat(LILAC_DARK), centre + Vector3(0, 1.6, 0))
	#Two-faced board under the heart
	var board := SignBoard.board("CHECKPOINT", Color("f2a93b"), 3.4, 0.85)
	board.position = centre + Vector3(0.0, 2.0, 0.0)
	add_child(board)
	var heart := Node3D.new()
	heart.position = centre + Vector3(0, 3.55, 0)
	add_child(heart)
	var model := PropKit.make(&"heart", Vector3(0.0, 1.5, 0.0))
	model.position.y = -0.75
	heart.add_child(model)
	_heart_materials[vertex] = PropKit.own_materials(model)
	set_checkpoint_active(vertex, false)
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(heart, "position:y", centre.y + 3.7, 1.1).from(centre.y + 3.5)
	bob.tween_property(heart, "position:y", centre.y + 3.5, 1.1)


#Goal: inflatable arch with a floating power symbol, since arriving means switching off
func _goal() -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[Level01Layout.GOAL]
	var arch := PropKit.make(&"arch", Vector3(8.6, 0.0, 0.0))
	arch.position = centre
	add_child(arch)
	var symbol := Node3D.new()
	symbol.position = centre + Vector3(0, 3.7, 0)
	add_child(symbol)
	var power := PropKit.make(&"power", Vector3(0.0, 2.8, 0.0), Color.WHITE, false)
	power.position.y = -1.4
	symbol.add_child(power)
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(symbol, "scale", Vector3.ONE * 1.12, 1.2).from(Vector3.ONE)
	pulse.tween_property(symbol, "scale", Vector3.ONE, 1.2)
	for index in 6:
		var light := index % 2 == 0
		_add(_box(Vector3(1.0, 0.04, 0.8)), _mat(PAPER if light else INK), centre + Vector3(-2.5 + index * 1.0, 0.03, 1.2))
	#Faint beam visible from the start
	var beam := CylinderMesh.new()
	beam.top_radius = 0.9
	beam.bottom_radius = 1.2
	beam.height = 26.0
	beam.radial_segments = 12
	beam.rings = 1
	_add(beam, _mat(CYAN, 0.8, 0.14), centre + Vector3(0, 13.0, 0))


func _mat(color: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.6
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _add(mesh: Mesh, material: Material, at: Vector3, casts_shadow := false, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(instance)
	return instance
