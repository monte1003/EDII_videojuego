class_name Level01Props
extends Node3D

#The pieces of level 1 with a job, each shaped like what it does (no sign, muted bell, shelter, heart, power symbol)

const LILAC_DARK := Color("6d55c2")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")
const AMBER := Color("ffc857")
const INK := Color("372c58")
const PAPER := Color("fdfbff")

#Offsets of the stations from the centre of their platform
const BLOCK_OFFSET := Vector3(-2.4, 0.0, -2.4)
const SILENCE_OFFSET := Vector3(2.4, 0.0, -2.4)
const REFUGE_OFFSET := Vector3(-2.2, 0.0, 0.0)
const PEDESTAL_HEIGHT := 0.8

var station_positions: Dictionary = {}
#Where each checkpoint is, by vertex
var checkpoint_positions: Dictionary = {}
var refuge_center := Vector3.ZERO

#Station id -> [materials, resting energy]; it glows stronger while its effect lasts
var _glow: Dictionary = {}
#Vertex of a checkpoint -> the materials of its heart and of its ring
var _heart_materials: Dictionary = {}
var _ring_materials: Dictionary = {}
var _bubble_material: StandardMaterial3D


func build(refuge_radius: float) -> void:
	_station(&"block", BLOCK_OFFSET, MAGENTA)
	_station(&"silence", SILENCE_OFFSET, CYAN)
	_block_sign(station_positions[&"block"])
	_muted_bell(station_positions[&"silence"])
	_refuge(refuge_radius)
	for vertex in Level01Layout.CHECKPOINTS:
		_checkpoint(vertex)
	_goal()


#Stronger glow while the ability is working: E, F and D
func set_active(id: StringName, active: bool) -> void:
	if not _glow.has(id):
		return
	var entry: Array = _glow[id]
	for material: StandardMaterial3D in entry[0]:
		material.emission_energy_multiplier = entry[1] * (2.2 if active else 1.0)
	if id == &"refuge":
		_bubble_material.albedo_color.a = 0.3 if active else 0.14


#The heart is grey-lilac until the progress is saved and then lights up
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


func _station(id: StringName, offset: Vector3, color: Color) -> void:
	var at: Vector3 = Level01Layout.POSITIONS[Level01Layout.STATIONS[id]] + offset
	station_positions[id] = at
	var base := CylinderMesh.new()
	base.top_radius = 0.55
	base.bottom_radius = 0.72
	base.height = PEDESTAL_HEIGHT
	base.radial_segments = 24
	_add(base, _mat(LILAC_DARK), at + Vector3(0, PEDESTAL_HEIGHT / 2.0, 0), true)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.7
	cap.bottom_radius = 0.7
	cap.height = 0.1
	cap.radial_segments = 24
	_add(cap, _mat(color, 0.6), at + Vector3(0, PEDESTAL_HEIGHT + 0.05, 0))
	#The pedestal is solid, so players and bots walk around it
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, PEDESTAL_HEIGHT / 2.0, 0)
	var shape := CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = PEDESTAL_HEIGHT
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	#A disc on the floor shows the area where the station answers
	var area := CylinderMesh.new()
	area.top_radius = 1.9
	area.bottom_radius = 1.9
	area.height = 0.03
	area.radial_segments = 32
	_add(area, _mat(color, 0.6, 0.3), at + Vector3(0, 0.02, 0))


#Bloquear: a prohibition sign that turns slowly above its pedestal
func _block_sign(at: Vector3) -> void:
	var sign_root := Node3D.new()
	sign_root.position = at + Vector3(0, PEDESTAL_HEIGHT + 1.35, 0)
	add_child(sign_root)
	var model := PropKit.make(&"no_sign", Vector3(0.0, 1.9, 0.0))
	model.position.y = -0.95
	sign_root.add_child(model)
	_glow[&"block"] = [_glowing(model, MAGENTA, 0.25), 0.25]
	var spin := create_tween().set_loops()
	spin.tween_property(sign_root, "rotation:y", TAU, 9.0).from(0.0)


#Silenciar: a bell with a bar across it that swings gently
func _muted_bell(at: Vector3) -> void:
	var bell := Node3D.new()
	bell.position = at + Vector3(0, PEDESTAL_HEIGHT + 1.15, 0)
	add_child(bell)
	var model := PropKit.make(&"bell", Vector3(0.0, 1.5, 0.0))
	model.position.y = -0.75
	bell.add_child(model)
	_glow[&"silence"] = [_glowing(model, CYAN, 0.25), 0.25]
	var bar := CapsuleMesh.new()
	bar.radius = 0.09
	bar.height = 2.0
	var slash := _add(bar, _mat(MAGENTA, 0.6), Vector3(0, 0.0, 0.75), false, bell)
	slash.rotation_degrees.z = -45.0
	var swing := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swing.tween_property(bell, "rotation_degrees:z", 7.0, 0.9).from(-7.0)
	swing.tween_property(bell, "rotation_degrees:z", -7.0, 0.9)


#Pausa digital: a soft bubble around a bench; inside it nobody pushes you
func _refuge(radius: float) -> void:
	refuge_center = Level01Layout.POSITIONS[Level01Layout.STATIONS[&"refuge"]] + REFUGE_OFFSET
	station_positions[&"refuge"] = refuge_center
	var centre := refuge_center
	_bubble_material = StandardMaterial3D.new()
	_bubble_material.albedo_color = Color(AMBER, 0.14)
	_bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bubble_material.emission_enabled = true
	_bubble_material.emission = AMBER
	_bubble_material.emission_energy_multiplier = 0.5
	var dome := SphereMesh.new()
	dome.radius = radius
	dome.height = radius
	dome.is_hemisphere = true
	dome.radial_segments = 32
	dome.rings = 14
	_add(dome, _bubble_material, centre)
	var floor_disc := CylinderMesh.new()
	floor_disc.top_radius = radius
	floor_disc.bottom_radius = radius
	floor_disc.height = 0.03
	floor_disc.radial_segments = 40
	_add(floor_disc, _mat(AMBER, 0.5, 0.3), centre + Vector3(0, 0.02, 0))
	var edge := TorusMesh.new()
	edge.inner_radius = radius - 0.1
	edge.outer_radius = radius
	edge.rings = 40
	edge.ring_segments = 6
	var glow := _mat(AMBER, 1.2)
	_glow[&"refuge"] = [[glow], 1.2]
	_add(edge, glow, centre + Vector3(0, 0.05, 0))
	#A bus shelter and a lamp: the calm corner
	var shelter := PropKit.make(&"bus_stop", Vector3(radius * 1.4, 0.0, 0.0))
	shelter.position = centre
	add_child(shelter)
	var lamp := PropKit.make_tall(&"lamp", 2.6)
	lamp.position = centre + Vector3(radius * 0.6, 0.0, radius * 0.3)
	add_child(lamp)


#Checkpoint: a flag pole with a heart; it lights up once the player has saved the progress
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


#Goal: an inflatable arch with the power symbol floating inside it, because arriving means switching off
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
	#A faint beam that can be seen from the start
	var beam := CylinderMesh.new()
	beam.top_radius = 0.9
	beam.bottom_radius = 1.2
	beam.height = 26.0
	beam.radial_segments = 12
	beam.rings = 1
	_add(beam, _mat(CYAN, 0.8, 0.14), centre + Vector3(0, 13.0, 0))


#Gives the model its own materials and makes them glow a little in "color"
func _glowing(model: Node3D, color: Color, energy: float) -> Array[StandardMaterial3D]:
	var materials := PropKit.own_materials(model)
	for material in materials:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
	return materials


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
