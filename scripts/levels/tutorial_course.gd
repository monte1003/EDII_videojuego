class_name TutorialCourse
extends Node3D

const LILAC := Color("cdbcf7")
const LILAC_DARK := Color("9d88e0")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")

const PATH_WIDTH := 3.6
const PLATFORM_HEIGHT := 0.6
const GATE_HEIGHT := 2.6
const WALL_DEPTH := 0.7

#Respawn points for zones 2 to 4 (zone 1 uses the level's SpawnPoint)
var checkpoints: Array[Vector3] = []
#The step n+1 starts once the player is past zone_enter_z[n] (the course runs toward -Z)
var zone_enter_z: Array[float] = []
var move_mark := Vector3.ZERO
var beacon_position := Vector3.ZERO
var jump_mark := Vector3.ZERO
var exit_mark := Vector3.ZERO

var _gates: Array[StaticBody3D] = []
var _top_material := _make_material(LILAC)
var _skirt_material := _make_material(LILAC_DARK)
var _wall_material := _make_material(MAGENTA, 0.35)
var _glow_material := _make_material(CYAN, 1.2)
var _beacon_material := _make_material(MAGENTA, 1.6)
var _beacon_light: OmniLight3D


#Every size comes from the player's real jump so the course matches the controller
func build(jump_height: float, jump_reach: float) -> void:
	var low := snappedf(jump_height * 0.45, 0.05)
	var gap_small := snappedf(jump_reach * 0.45, 0.1)
	var gap_wide := snappedf(jump_reach * 0.55, 0.1)

	#Zone 1: walk to the mark
	_platform(Vector3(0, 0, 0), 6.0)
	move_mark = Vector3(0, 0, -3.0)
	_mark(move_mark)
	_path(-5.8, -12.2)
	_gate(-7.5)
	_arrows(-8.5, -11.0)

	#Zone 2: turn the camera toward the beacon
	_platform(Vector3(0, 0, -18), 6.0)
	checkpoints.append(Vector3(0, 0.05, -13.5))
	zone_enter_z.append(-12.5)
	beacon_position = Vector3(-4.2, 0, -15.2)
	_beacon(beacon_position)
	_path(-23.8, -30.2)
	_gate(-25.5)
	_arrows(-26.5, -29.0)

	#Zone 3: low obstacles and small gaps
	_platform(Vector3(0, 0, -35), 5.0)
	checkpoints.append(Vector3(0, 0.05, -31.5))
	zone_enter_z.append(-30.6)
	_wall(-35.0, -36.5, 5.0, low)
	var p3b := -40.0 - gap_small - 3.5
	_platform(Vector3(0, 0, p3b), 3.5)
	_wall(p3b, p3b + 0.4, 3.5, low)
	var p3c := p3b - 3.5 - gap_wide - 4.0
	_platform(Vector3(0, 0, p3c), 4.0)
	jump_mark = Vector3(0, 0, p3c)
	_mark(jump_mark)
	_path(p3c - 3.8, p3c - 10.4)
	_gate(p3c - 5.4)
	_arrows(p3c - 6.4, p3c - 9.0)

	#Zone 4: everything together, the exit is off to the side
	var z4 := p3c - 10.4 - 5.0 + 0.2
	_platform(Vector3(0, 0, z4), 5.0)
	checkpoints.append(Vector3(0, 0.05, z4 + 4.5))
	zone_enter_z.append(z4 + 5.4)
	_wall(z4, z4 + 0.5, 5.0, low)
	var p4b := z4 - 5.0 - gap_small - 4.5
	_platform(Vector3(0, 0, p4b), 4.5)
	_wall(p4b, p4b + 1.4, 4.5, low)
	var exit_x := 4.5 + gap_wide + 3.5
	_platform(Vector3(exit_x, 0, p4b), 3.5)
	exit_mark = Vector3(exit_x, 0, p4b)
	_mark(exit_mark, true)

	_scatter_decor()
	_pulse_glow()


func open_gate(index: int) -> void:
	if index >= _gates.size():
		return
	var gate := _gates[index]
	#Collisions go off at once so nothing can block the player while it fades
	gate.collision_layer = 0
	var material := (gate.get_child(1) as MeshInstance3D).material_override as StandardMaterial3D
	var tween := create_tween().set_parallel()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.5)
	tween.chain().tween_callback(gate.queue_free)


func set_beacon_aligned(aligned: bool) -> void:
	var color := CYAN if aligned else MAGENTA
	_beacon_material.albedo_color = color
	_beacon_material.emission = color
	_beacon_light.light_color = color


func _make_material(color: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
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


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, casts_shadow := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_body(shape: Shape3D, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body


#Round island with a glowing rim; its top surface sits at y = 0
func _platform(center: Vector3, radius: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = PLATFORM_HEIGHT
	var body := _add_body(shape, Vector3(center.x, -PLATFORM_HEIGHT / 2.0, center.z))

	var top := CylinderMesh.new()
	top.top_radius = radius
	top.bottom_radius = radius
	top.height = PLATFORM_HEIGHT
	top.radial_segments = 64
	top.rings = 1
	_add_mesh(body, top, _top_material, Vector3.ZERO)

	var skirt := CylinderMesh.new()
	skirt.top_radius = radius * 0.97
	skirt.bottom_radius = radius * 0.5
	skirt.height = 1.6
	skirt.radial_segments = 64
	skirt.rings = 1
	_add_mesh(body, skirt, _skirt_material, Vector3(0, -PLATFORM_HEIGHT / 2.0 - 0.8, 0))

	var rim := TorusMesh.new()
	rim.outer_radius = radius
	rim.inner_radius = radius - 0.14
	rim.rings = 64
	rim.ring_segments = 8
	_add_mesh(body, rim, _glow_material, Vector3(0, PLATFORM_HEIGHT / 2.0, 0), false)


func _path(from_z: float, to_z: float) -> void:
	var length := absf(from_z - to_z)
	var shape := BoxShape3D.new()
	shape.size = Vector3(PATH_WIDTH, PLATFORM_HEIGHT, length)
	var body := _add_body(shape, Vector3(0, -PLATFORM_HEIGHT / 2.0, (from_z + to_z) / 2.0))
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	_add_mesh(body, mesh, _top_material, Vector3.ZERO)


#A low bar across a platform, as wide as the platform is at that depth
func _wall(platform_z: float, wall_z: float, radius: float, height: float) -> void:
	var offset := wall_z - platform_z
	var width := 2.0 * sqrt(maxf(radius * radius - offset * offset, 0.25)) - 0.04
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, WALL_DEPTH)
	var body := _add_body(shape, Vector3(0, height / 2.0, wall_z))
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	_add_mesh(body, mesh, _wall_material, Vector3.ZERO)


#A translucent barrier that stays until the step of its zone is done
func _gate(z: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(PATH_WIDTH + 0.4, GATE_HEIGHT, 0.3)
	var body := _add_body(shape, Vector3(0, GATE_HEIGHT / 2.0, z))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(shape.size.x, shape.size.y, 0.1)
	_add_mesh(body, mesh, _make_material(MAGENTA, 1.2, 0.4), Vector3.ZERO, false)
	_gates.append(body)


#Flat chevrons on the floor that point toward -Z
func _arrows(from_z: float, to_z: float) -> void:
	var prism := PrismMesh.new()
	prism.size = Vector3(1.1, 1.0, 0.03)
	var z := from_z
	while z >= to_z:
		var arrow := _add_mesh(self, prism, _glow_material, Vector3(0, 0.03, z), false)
		arrow.rotation_degrees.x = -90.0
		z -= 1.4


#Glowing disc, ring and a faint beam so the goal is visible from afar
func _mark(at: Vector3, is_exit := false) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.04
	_add_mesh(self, disc, _glow_material, at + Vector3(0, 0.02, 0), false)

	var ring := TorusMesh.new()
	ring.outer_radius = 1.25
	ring.inner_radius = 1.1
	ring.rings = 48
	ring.ring_segments = 8
	_add_mesh(self, ring, _make_material(MAGENTA, 1.4), at + Vector3(0, 0.06, 0), false)

	var beam := CylinderMesh.new()
	beam.top_radius = 0.7 if is_exit else 0.5
	beam.bottom_radius = 0.9 if is_exit else 0.6
	beam.height = 9.0 if is_exit else 5.0
	beam.rings = 1
	_add_mesh(self, beam, _make_material(CYAN, 0.8, 0.16), at + Vector3(0, beam.height / 2.0, 0), false)


func _beacon(at: Vector3) -> void:
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.3
	pillar.bottom_radius = 0.4
	pillar.height = 7.0
	_add_mesh(self, pillar, _beacon_material, at + Vector3(0, 3.5, 0), false)
	var orb := SphereMesh.new()
	orb.radius = 0.7
	orb.height = 1.4
	_add_mesh(self, orb, _beacon_material, at + Vector3(0, 7.2, 0), false)
	_beacon_light = OmniLight3D.new()
	_beacon_light.light_color = MAGENTA
	_beacon_light.light_energy = 1.4
	_beacon_light.omni_range = 9.0
	_beacon_light.position = at + Vector3(0, 3.0, 0)
	add_child(_beacon_light)


#Soft floating shapes far from the route; no collisions
func _scatter_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var materials: Array[StandardMaterial3D] = [
		_make_material(Color("f6e9ff")),
		_make_material(LILAC_DARK),
		_make_material(Palette.SKY_BOTTOM),
	]
	for i in 48:
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(
			side * rng.randf_range(14.0, 42.0),
			rng.randf_range(-12.0, 6.0),
			rng.randf_range(-105.0, 20.0))
		var radius := rng.randf_range(1.2, 3.2)
		var mesh: Mesh
		match i % 3:
			0:
				var sphere := SphereMesh.new()
				sphere.radius = radius
				sphere.height = radius * 2.0
				mesh = sphere
			1:
				var stone := CylinderMesh.new()
				stone.top_radius = radius
				stone.bottom_radius = radius * 0.6
				stone.height = radius * 0.8
				mesh = stone
			_:
				var capsule := CapsuleMesh.new()
				capsule.radius = radius * 0.6
				capsule.height = radius * 2.4
				mesh = capsule
		var instance := _add_mesh(self, mesh, materials[i % 3], at, false)
		instance.rotation.y = rng.randf_range(0.0, TAU)
		instance.scale.y = rng.randf_range(0.6, 1.0)


#Marks, rims and arrows breathe together; the tween dies with this node
func _pulse_glow() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_glow_material, "emission_energy_multiplier", 2.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_glow_material, "emission_energy_multiplier", 0.8, 0.9).set_trans(Tween.TRANS_SINE)
