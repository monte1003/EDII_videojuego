class_name CrowdField
extends Node3D

#Cheering fans as flat avatar tiles; one draw call per stretch

const SHADER: Shader = preload("res://assets/shaders/crowd_bob.gdshader")
const CARD_SIZE := 1.1
const FAN_COLORS: Array[Color] = [
	Color("ff6b8b"), Color("ffcf4a"), Color("4fd6e8"), Color("8e6bff"), Color("6ee7a5"), Color("ff9a5c"), Color("a3a9d9"),
]

var _spots: Array[Transform3D] = []
var _colors: Array[Color] = []
var _material: ShaderMaterial


#Fan at "at" facing "yaw" (0 is +Z), "size" times normal height
func add_fan(at: Vector3, yaw: float, size: float, color: Color) -> void:
	_spots.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), at))
	_colors.append(color)


#The crowd jumps higher above 1
func set_excitement(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("excitement", amount)


#Wave of standing fans at "front" along Z; "lift" 0 puts it away
func set_wave(front: float, lift: float) -> void:
	if _material != null:
		_material.set_shader_parameter("wave_front", front)
		_material.set_shader_parameter("wave_lift", lift)


func commit() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var card := _fan_mesh(_material)
	var places: Array[Vector3] = []
	for spot in _spots:
		places.append(spot.origin)
	var groups := MeshMerger.cells(places)
	for cell: int in groups:
		var members: Array[int] = groups[cell]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = card
		multi.instance_count = members.size()
		for slot in members.size():
			multi.set_instance_transform(slot, _spots[members[slot]])
			multi.set_instance_color(slot, _colors[members[slot]])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


#Flat card standing on its feet, same from both sides
func _fan_mesh(material: Material) -> QuadMesh:
	var card := QuadMesh.new()
	card.size = Vector2(CARD_SIZE, CARD_SIZE)
	card.center_offset = Vector3(0.0, CARD_SIZE / 2.0, 0.0)
	card.material = material
	return card
