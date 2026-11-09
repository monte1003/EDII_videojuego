class_name FerrisWheel
extends Node3D

#A big wheel in the distance that turns slowly while its cabins stay upright; it faces +Z and stands on its base point

const SPOKES := 12
const CABINS := 12
const SIDE := 1.1

var _radius := 12.0
var _speed := 0.1
var _turn := 0.0
var _clock := 0.0
var _hub_height := 0.0
var _wheel: Node3D
var _cabins: MultiMesh


func build(radius: float, colors: Array[Color]) -> void:
	_radius = radius
	_hub_height = radius + 2.5
	_wheel = Node3D.new()
	_wheel.position.y = _hub_height
	add_child(_wheel)
	for z: float in [-SIDE, SIDE]:
		var rim := MeshInstance3D.new()
		var band := TorusMesh.new()
		band.inner_radius = radius - 0.45
		band.outer_radius = radius
		band.rings = 48
		band.ring_segments = 8
		rim.mesh = band
		rim.material_override = PartyKit.candy(PartyKit.WHITE, PartyKit.PINK, 24.0)
		rim.rotation_degrees.x = 90.0
		rim.position.z = z
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wheel.add_child(rim)
	_wheel.add_child(_spokes())
	_cabins = _cabin_field(colors)
	_place_cabins()
	_legs()


func _process(delta: float) -> void:
	_clock += delta
	_turn = _speed * _clock
	_wheel.rotation.z = _turn
	_place_cabins()


#Spokes on both faces of the wheel, one draw call
func _spokes() -> MultiMeshInstance3D:
	var bar := BoxMesh.new()
	bar.size = Vector3(1.0, 0.3, 0.3)
	bar.material = PartyKit.paint(PartyKit.WHITE, 0.0, 0.5)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = bar
	multi.instance_count = SPOKES * 2
	for index in SPOKES * 2:
		var angle := TAU * (index % SPOKES) / SPOKES
		var z := -SIDE if index < SPOKES else SIDE
		var basis := Basis(Vector3.BACK, angle).scaled_local(Vector3(_radius, 1.0, 1.0))
		multi.set_instance_transform(index, Transform3D(basis, Vector3(cos(angle), sin(angle), 0.0) * _radius / 2.0 + Vector3(0.0, 0.0, z)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _cabin_field(colors: Array[Color]) -> MultiMesh:
	var cabin := BoxMesh.new()
	cabin.size = Vector3(2.0, 1.7, SIDE * 1.7)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.45
	cabin.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = cabin
	multi.instance_count = CABINS
	for index in CABINS:
		multi.set_instance_color(index, colors[index % colors.size()])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multi


#The cabins hang from the rim and never turn over
func _place_cabins() -> void:
	for index in CABINS:
		var angle := _turn + TAU * index / CABINS
		var at := Vector3(cos(angle) * _radius, _hub_height + sin(angle) * _radius - 1.15, 0.0)
		_cabins.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))


#Two A-frames, one on each face
func _legs() -> void:
	var leg := BoxMesh.new()
	leg.size = Vector3(0.7, 1.0, 0.7)
	leg.material = PartyKit.paint(PartyKit.VIOLET, 0.0, 0.5)
	for z: float in [-SIDE * 1.5, SIDE * 1.5]:
		for x: float in [-1.0, 1.0]:
			var instance := MeshInstance3D.new()
			instance.mesh = leg
			instance.transform = PartyKit.stretch(Vector3(0.0, _hub_height, z), Vector3(x * _radius * 0.55, -6.0, z))
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
