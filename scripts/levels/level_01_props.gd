class_name Level01Props
extends Node3D

#The pieces of level 1 with a job, each shaped like what it does (no sign, muted bell, bubble, heart, power symbol)

const LILAC := Color("a98df0")
const LILAC_DARK := Color("6d55c2")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")
const AMBER := Color("ffc857")
const INK := Color("372c58")
const PAPER := Color("fdfbff")

#Offsets of the stations from the centre of their platform
const E_STATION_OFFSET := Vector3(-2.4, 0.0, -2.4)
const F_STATION_OFFSET := Vector3(2.4, 0.0, -2.4)
const D_REFUGE_OFFSET := Vector3(-2.2, 0.0, 0.0)
const PEDESTAL_HEIGHT := 0.8

var station_positions: Dictionary = {}
var refuge_center := Vector3.ZERO

#Station id -> [material, resting energy]; it glows stronger while its effect lasts
var _glow: Dictionary = {}
var _heart_material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _bubble_material: StandardMaterial3D


func build(refuge_radius: float) -> void:
	_station(&"E", E_STATION_OFFSET, MAGENTA)
	_station(&"F", F_STATION_OFFSET, CYAN)
	_block_sign(station_positions[&"E"])
	_muted_bell(station_positions[&"F"])
	_refuge(refuge_radius)
	_checkpoint()
	_goal()


#Stronger glow while the ability is working: E, F and D
func set_active(id: StringName, active: bool) -> void:
	if not _glow.has(id):
		return
	var entry: Array = _glow[id]
	(entry[0] as StandardMaterial3D).emission_energy_multiplier = entry[1] * (2.2 if active else 1.0)
	if id == &"D":
		_bubble_material.albedo_color.a = 0.3 if active else 0.14


func set_checkpoint_active(active: bool) -> void:
	var color := MAGENTA if active else LILAC
	_heart_material.albedo_color = color
	_heart_material.emission_enabled = active
	_heart_material.emission = color
	_heart_material.emission_energy_multiplier = 1.6
	var ring := AMBER if active else CYAN
	_ring_material.albedo_color = ring
	_ring_material.emission = ring


func _station(id: StringName, offset: Vector3, color: Color) -> void:
	var at: Vector3 = Level01Layout.POSITIONS[id] + offset
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
	var material := _mat(MAGENTA, 1.4)
	_glow[&"E"] = [material, 1.4]
	var sign_root := Node3D.new()
	sign_root.position = at + Vector3(0, PEDESTAL_HEIGHT + 1.15, 0)
	add_child(sign_root)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.58
	ring.outer_radius = 0.8
	ring.rings = 32
	ring.ring_segments = 10
	var ring_instance := _add(ring, material, Vector3.ZERO, false, sign_root)
	ring_instance.rotation_degrees.x = 90.0
	var bar := _add(_box(Vector3(1.28, 0.2, 0.14)), material, Vector3.ZERO, false, sign_root)
	bar.rotation_degrees.z = -45.0
	var spin := create_tween().set_loops()
	spin.tween_property(sign_root, "rotation:y", TAU, 9.0).from(0.0)


#Silenciar: a bell with a bar across it that swings gently
func _muted_bell(at: Vector3) -> void:
	var material := _mat(CYAN, 1.2)
	_glow[&"F"] = [material, 1.2]
	var bell := Node3D.new()
	bell.position = at + Vector3(0, PEDESTAL_HEIGHT + 1.1, 0)
	add_child(bell)
	var dome := SphereMesh.new()
	dome.radius = 0.62
	dome.height = 0.62
	dome.is_hemisphere = true
	dome.radial_segments = 24
	dome.rings = 12
	_add(dome, material, Vector3(0, -0.15, 0), false, bell)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.56
	rim.outer_radius = 0.72
	rim.rings = 28
	rim.ring_segments = 8
	_add(rim, material, Vector3(0, -0.17, 0), false, bell)
	var clapper := SphereMesh.new()
	clapper.radius = 0.13
	clapper.height = 0.26
	_add(clapper, material, Vector3(0, -0.34, 0), false, bell)
	var knob := SphereMesh.new()
	knob.radius = 0.09
	knob.height = 0.18
	_add(knob, material, Vector3(0, 0.5, 0), false, bell)
	var slash := _add(_box(Vector3(1.5, 0.15, 0.1)), _mat(INK), Vector3(0, 0.05, 0.5), false, bell)
	slash.rotation_degrees.z = -45.0
	var swing := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swing.tween_property(bell, "rotation_degrees:z", 7.0, 0.9).from(-7.0)
	swing.tween_property(bell, "rotation_degrees:z", -7.0, 0.9)


#Pausa digital: a soft bubble around a bench; inside it nobody pushes you
func _refuge(radius: float) -> void:
	refuge_center = Level01Layout.POSITIONS[&"D"] + D_REFUGE_OFFSET
	station_positions[&"D"] = refuge_center
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
	_glow[&"D"] = [glow, 1.2]
	_add(edge, glow, centre + Vector3(0, 0.05, 0))
	#Bench and a warm lamp: the calm corner
	_add(_box(Vector3(2.0, 0.4, 0.7)), _mat(MAGENTA), centre + Vector3(0, 0.2, 0), true)
	_add(_box(Vector3(2.0, 0.55, 0.16)), _mat(MAGENTA), centre + Vector3(0, 0.62, -0.3), true)
	var lamp := SphereMesh.new()
	lamp.radius = 0.2
	lamp.height = 0.4
	var lamp_instance := _add(lamp, _mat(AMBER, 1.8), centre + Vector3(0, 1.9, 0))
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(lamp_instance, "position:y", centre.y + 2.1, 1.3).from(centre.y + 1.8)
	bob.tween_property(lamp_instance, "position:y", centre.y + 1.8, 1.3)


#Checkpoint: a flag pole with a heart; it lights up once the player has saved the progress
func _checkpoint() -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[&"H"]
	var ring := CylinderMesh.new()
	ring.top_radius = 1.5
	ring.bottom_radius = 1.5
	ring.height = 0.04
	ring.radial_segments = 32
	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = CYAN
	_ring_material.emission_enabled = true
	_ring_material.emission = CYAN
	_ring_material.emission_energy_multiplier = 1.4
	_add(ring, _ring_material, centre + Vector3(0, 0.03, 0))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 3.2
	pole.radial_segments = 8
	_add(pole, _mat(LILAC_DARK), centre + Vector3(0, 1.6, 0))
	_heart_material = StandardMaterial3D.new()
	_heart_material.albedo_color = LILAC
	_heart_material.roughness = 0.5
	var heart := Node3D.new()
	heart.position = centre + Vector3(0, 3.55, 0)
	add_child(heart)
	var square := _add(_box(Vector3(0.62, 0.62, 0.14)), _heart_material, Vector3(0, 0, 0), false, heart)
	square.rotation_degrees.z = 45.0
	for side in [-1.0, 1.0]:
		var lobe := CylinderMesh.new()
		lobe.top_radius = 0.31
		lobe.bottom_radius = 0.31
		lobe.height = 0.14
		lobe.radial_segments = 20
		var lobe_instance := _add(lobe, _heart_material, Vector3(side * 0.219, 0.219, 0), false, heart)
		lobe_instance.rotation_degrees.x = 90.0
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(heart, "position:y", centre.y + 3.7, 1.1).from(centre.y + 3.5)
	bob.tween_property(heart, "position:y", centre.y + 3.5, 1.1)


#Goal: a gold arch crowned with the power symbol, because arriving means switching off
func _goal() -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[Level01Layout.GOAL]
	var gold := _mat(AMBER, 0.8)
	for side in [-1.0, 1.0]:
		var pillar := CylinderMesh.new()
		pillar.top_radius = 0.35
		pillar.bottom_radius = 0.4
		pillar.height = 4.6
		pillar.radial_segments = 12
		_add(pillar, gold, centre + Vector3(side * 3.2, 2.3, 0), true)
	_add(_box(Vector3(7.2, 0.7, 0.7)), gold, centre + Vector3(0, 4.8, 0), true)
	var power := _mat(MAGENTA, 1.4)
	var symbol := Node3D.new()
	symbol.position = centre + Vector3(0, 6.3, 0)
	add_child(symbol)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.72
	ring.outer_radius = 0.95
	ring.rings = 36
	ring.ring_segments = 10
	var ring_instance := _add(ring, power, Vector3.ZERO, false, symbol)
	ring_instance.rotation_degrees.x = 90.0
	_add(_box(Vector3(0.2, 1.1, 0.2)), power, Vector3(0, 0.55, 0), false, symbol)
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
