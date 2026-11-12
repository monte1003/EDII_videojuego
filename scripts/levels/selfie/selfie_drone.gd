class_name SelfieDrone
extends Node3D

#The camera drone: it flies from photo to photo over the islands, hovers, leans into its way and shrinks for a blink when it shoots.
#A beam of light hangs under it down to the floor, and the frame it draws there is a flat piece with its own shader

const FRAME_SHADER: Shader = preload("res://assets/shaders/photo_frame.gdshader")
const MODEL_HEIGHT := 1.9
const BEAM_COLOR := Color("fff1b8")
const FRAME_LIFT := 0.05

var _model: Node3D
var _body: Node3D
var _beam: MeshInstance3D
var _frame: MeshInstance3D
var _frame_material: ShaderMaterial
var _flash: MeshInstance3D
var _path: Array[Vector3] = []
var _lengths: Array[float] = []
var _travel_total := 1.0
var _travel_time := 1.0
var _clock := 0.0
var _last := Vector3.ZERO
var _lean := Vector2.ZERO
var _squeeze := 1.0
var _aim := Vector3.ZERO


func build(at: Vector3, center_share: float) -> void:
	position = at
	_last = at
	_body = Node3D.new()
	add_child(_body)
	_model = PropKit.make_tall(&"drone", MODEL_HEIGHT, Color.WHITE, false)
	_model.position.y = -MODEL_HEIGHT / 2.0
	_body.add_child(_model)
	#The beam hangs from the drone to the floor, wide at the bottom
	_beam = PartyKit.beam(BEAM_COLOR, SelfieLayout.DRONE_HEIGHT, 2.6, 0.5)
	_beam.rotation.x = PI
	_beam.position.y = -SelfieLayout.DRONE_HEIGHT / 2.0
	add_child(_beam)
	var glow := SphereMesh.new()
	glow.radius = 1.5
	glow.height = 3.0
	glow.radial_segments = 12
	glow.rings = 6
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	white.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	_flash = MeshInstance3D.new()
	_flash.mesh = glow
	_flash.material_override = white
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.hide()
	add_child(_flash)

	_frame_material = ShaderMaterial.new()
	_frame_material.shader = FRAME_SHADER
	_frame_material.set_shader_parameter("center_share", center_share)
	_frame_material.render_priority = 2
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_frame = MeshInstance3D.new()
	_frame.mesh = plane
	_frame.material_override = _frame_material
	_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_frame.top_level = true
	_frame.hide()
	add_child(_frame)


#Flies along "points" (the first one is where it is) in "seconds"
func fly(points: Array[Vector3], seconds: float) -> void:
	_path = points.duplicate()
	if _path.is_empty():
		return
	_path[0] = position
	_lengths.clear()
	_travel_total = 0.0
	for index in range(1, _path.size()):
		_lengths.append(_path[index - 1].distance_to(_path[index]))
		_travel_total += _lengths[-1]
	_travel_time = 0.0
	_clock = maxf(seconds, 0.05)


#Draws the frame on the floor: its middle, its side in meters and how close the shot is (0 to 1; it blinks three times on the way)
func show_frame(center: Vector3, side: float, lock: float) -> void:
	_frame.show()
	_frame.global_position = center + Vector3(0.0, FRAME_LIFT, 0.0)
	_frame.global_basis = Basis.from_scale(Vector3(side, 1.0, side))
	_frame_material.set_shader_parameter("side", side)
	_frame_material.set_shader_parameter("blink", pow(absf(sin(lock * PI * 3.0)), 0.6) if lock > 0.0 else 0.0)
	_aim = center


func hide_frame() -> void:
	_frame.hide()


#The shot: the drone shrinks for an instant and a white burst opens around it
func snap() -> void:
	_squeeze = 0.72
	_flash.show()
	_flash.scale = Vector3.ONE * 0.3
	var burst := create_tween()
	burst.tween_property(_flash, "scale", Vector3.ONE * 2.2, 0.22).set_ease(Tween.EASE_OUT)
	burst.tween_callback(_flash.hide)
	_frame_material.set_shader_parameter("fill", 0.75)
	var fade := create_tween()
	fade.tween_method(_set_fill, 0.75, 0.1, 0.5)


func _set_fill(value: float) -> void:
	_frame_material.set_shader_parameter("fill", value)


func _process(delta: float) -> void:
	if _travel_time < _clock and _path.size() > 1:
		_travel_time = minf(_travel_time + delta, _clock)
		var share := smoothstep(0.0, 1.0, _travel_time / _clock)
		position = _point_at(share * _travel_total)
	var speed := (position - _last) / maxf(delta, 0.0001)
	_last = position
	#It leans into where it goes and bobs while it hovers
	var aim := Vector2(clampf(speed.z * 0.03, -0.35, 0.35), clampf(-speed.x * 0.03, -0.35, 0.35))
	_lean = _lean.lerp(aim, 1.0 - exp(-6.0 * delta))
	_squeeze = lerpf(_squeeze, 1.0, 1.0 - exp(-9.0 * delta))
	var time := Time.get_ticks_msec() / 1000.0
	var to_aim := _aim - global_position
	var yaw := atan2(to_aim.x, to_aim.z) if Vector2(to_aim.x, to_aim.z).length() > 0.5 else _body.rotation.y
	_body.rotation.y = lerp_angle(_body.rotation.y, yaw, 1.0 - exp(-4.0 * delta))
	_body.rotation.x = _lean.x + 0.25
	_body.rotation.z = _lean.y + sin(time * 2.1) * 0.05
	_body.position.y = sin(time * 2.6) * 0.16
	_body.scale = Vector3(1.0 / sqrt(_squeeze), _squeeze, 1.0 / sqrt(_squeeze))


func _point_at(travelled: float) -> Vector3:
	var left := travelled
	for index in _lengths.size():
		if left <= _lengths[index] or index == _lengths.size() - 1:
			return _path[index].lerp(_path[index + 1], clampf(left / maxf(_lengths[index], 0.001), 0.0, 1.0))
		left -= _lengths[index]
	return _path[-1]
