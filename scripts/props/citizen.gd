class_name Citizen
extends Node3D

#A person of the street, in the style of the four heroes: the body of one of them in another tone, a phone in the hands that lights
#its face, and sometimes headphones, a scarf or a backpack. It walks, sits or pedals, always looking at the screen

enum Pose { WALK, SIT, RIDE }

const BODIES: Array[StringName] = [&"fire", &"water", &"plant", &"lightning"]
#Where the colour of each body sits on the wheel (0 to 1); the tones below keep away from these so nobody looks like a player
const NATIVE_HUES := {&"fire": 0.0, &"water": 0.6, &"plant": 0.31, &"lightning": 0.13}
const TONES: Array[float] = [0.19, 0.46, 0.53, 0.66, 0.78, 0.93]
const MIN_TURN := 0.1
const TONE_SHADER: Shader = preload("res://assets/shaders/citizen_tone.gdshader")
const PHONE_SHADER: Shader = preload("res://assets/shaders/phone.gdshader")
const ANIMATIONS := {Pose.WALK: &"street/Walk", Pose.SIT: &"street/Sit", Pose.RIDE: &"street/Ride"}
const SCREEN_COLORS: Array[Color] = [Color("bfe9ff"), Color("ffd6ec"), Color("fff3b8"), Color("d9ffe9")]
const ACCESSORY_COLORS: Array[Color] = [Color("ffd23f"), Color("ff6f91"), Color("4fd6e8"), Color("fdfbff"), Color("6a52e0")]
const CASE_COLORS: Array[Color] = [Color("ff6f91"), Color("4fd6e8"), Color("ffd23f"), Color("fdfbff"), Color("6a52e0")]
const PHONE_SIZE := Vector3(0.15, 0.26, 0.026)

static var _tones: Dictionary = {}
static var _meshes: Dictionary = {}

var body_id: StringName = &"fire"
var _model: CharacterModel
var _phase := 0.0
var _skeleton: Skeleton3D
var _animation: AnimationPlayer
var _to_root := Transform3D.IDENTITY


#Builds the person with "rng" choosing body, tone and accessories; "phase" is a share of the cycle to start from
func build(pose: Pose, rng: RandomNumberGenerator, phase := 0.0) -> void:
	body_id = BODIES[rng.randi() % BODIES.size()]
	_phase = phase
	_model = (load("res://scenes/characters/%s.tscn" % body_id) as PackedScene).instantiate() as CharacterModel
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_to_root = _relative_transform(_skeleton, _model)
	_animation = _model.get_node("AnimationPlayer") as AnimationPlayer
	_animation.add_animation_library("street", load("res://assets/characters/%s/%s_street.res" % [body_id, body_id]))
	var clip: StringName = ANIMATIONS[pose]
	#The model starts its "idle" animation by itself when it enters the tree: this one is the clip it plays
	_model.idle_animation = clip
	_tint(_pick_tone(rng))
	#The accessories are measured on the skeleton at rest and the phone on its first frame, where the hands are
	if rng.randf() < 0.45 and pose != Pose.SIT:
		_add_scarf(rng)
	if rng.randf() < 0.4:
		_add_headphones(rng)
	if rng.randf() < 0.4 and pose != Pose.SIT:
		_add_backpack(rng)
	_pose_at_start(clip)
	_add_phone(rng, pose)


func _ready() -> void:
	_animation.seek(_phase * _animation.current_animation_length)


#A pedal under each foot, for the riders
func add_pedals() -> void:
	for side in ["Left", "Right"]:
		var pedal := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.09, 0.022, 0.1)
		pedal.mesh = box
		pedal.material_override = _flat(Color("2b2547"))
		pedal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var foot := _point(side + "Foot")
		_attach(side + "Foot", pedal, Transform3D(Basis.IDENTITY, foot + Vector3(0.0, -0.045, 0.03)))


func set_speed(scale_factor: float) -> void:
	_animation.speed_scale = scale_factor


func meshes() -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		list.append(node as MeshInstance3D)
	return list


func _pick_tone(rng: RandomNumberGenerator) -> Dictionary:
	var native: float = NATIVE_HUES[body_id]
	var target := native
	while absf(fposmod(target - native + 0.5, 1.0) - 0.5) < MIN_TURN:
		target = TONES[rng.randi() % TONES.size()]
	return {"hue": fposmod(target - native, 1.0), "saturation": rng.randf_range(0.7, 0.95), "value": rng.randf_range(1.0, 1.12)}


#Gives each surface the toned material of its body; the same tone is shared by every person that uses it
func _tint(tone: Dictionary) -> void:
	for mesh in meshes():
		for surface in mesh.mesh.get_surface_count():
			var base := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if base == null or base.albedo_texture == null:
				continue
			var key := "%s_%d_%s_%.2f_%.2f" % [body_id, surface, tone["hue"], tone["saturation"], tone["value"]]
			if not _tones.has(key):
				var material := ShaderMaterial.new()
				material.shader = TONE_SHADER
				material.set_shader_parameter("albedo_tex", base.albedo_texture)
				material.set_shader_parameter("hue_shift", tone["hue"])
				material.set_shader_parameter("saturation", tone["saturation"])
				material.set_shader_parameter("value", tone["value"])
				_tones[key] = material
			mesh.set_surface_override_material(surface, _tones[key])


#Applies the first frame of the clip to the skeleton, so the places of the hands can be measured, and then lets it go
func _pose_at_start(clip: StringName) -> void:
	var anim := _animation.get_animation(clip)
	for track in anim.get_track_count():
		var bone := _skeleton.find_bone(str(anim.track_get_path(track)).get_slice(":", 1))
		if bone < 0:
			continue
		if anim.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			_skeleton.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(track, 0.0))
		elif anim.track_get_type(track) == Animation.TYPE_POSITION_3D:
			_skeleton.set_bone_pose_position(bone, anim.position_track_interpolate(track, 0.0))


#Hangs "item" on a bone so it ends up at "wanted" (in the space of the person) when the skeleton is in the pose it has now
func _attach(bone_name: String, item: Node3D, wanted: Transform3D) -> void:
	var bone := _skeleton.find_bone("mixamorig_" + bone_name)
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "mixamorig_" + bone_name
	_skeleton.add_child(attachment)
	attachment.add_child(item)
	item.transform = (_to_root * _skeleton.get_bone_global_pose(bone)).affine_inverse() * wanted


#Where a bone is, in the space of the person, with the skeleton as it stands now
func _point(bone_name: String) -> Vector3:
	return (_to_root * _skeleton.get_bone_global_pose(_skeleton.find_bone("mixamorig_" + bone_name))).origin


func _add_phone(rng: RandomNumberGenerator, pose: Pose) -> void:
	var phone := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = PHONE_SIZE
	phone.mesh = box
	phone.material_override = _phone_material()
	phone.set_instance_shader_parameter("case_color", CASE_COLORS[rng.randi() % CASE_COLORS.size()])
	phone.set_instance_shader_parameter("screen_color", SCREEN_COLORS[rng.randi() % SCREEN_COLORS.size()])
	phone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	#The screen looks back and up, toward the face that looks down at it
	var basis := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.866, 0.5), Vector3(0.0, 0.5, -0.866))
	#Seated people hold it higher, so it shows above the door of the car
	var lift := 0.14 if pose == Pose.SIT else 0.03
	_attach("Spine2", phone, Transform3D(basis, _point("Spine2") + Vector3(0.0, lift, 0.2)))


func _add_scarf(rng: RandomNumberGenerator) -> void:
	var color := ACCESSORY_COLORS[rng.randi() % ACCESSORY_COLORS.size()]
	var ring := TorusMesh.new()
	ring.inner_radius = 0.1
	ring.outer_radius = 0.19
	var item := MeshInstance3D.new()
	item.mesh = ring
	item.material_override = _flat(color)
	_attach("Neck", item, Transform3D(Basis(), _point("Neck") + Vector3(0.0, 0.02, 0.0)))


#Two cups on the sides of the head and a band over it
func _add_headphones(rng: RandomNumberGenerator) -> void:
	var material := _flat(ACCESSORY_COLORS[rng.randi() % ACCESSORY_COLORS.size()])
	var item := Node3D.new()
	var band := MeshInstance3D.new()
	band.mesh = _arc_mesh(0.215, 0.022)
	band.material_override = material
	item.add_child(band)
	for side in [-1.0, 1.0]:
		var cup := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.085
		cylinder.bottom_radius = 0.085
		cylinder.height = 0.07
		cup.mesh = cylinder
		cup.material_override = material
		cup.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		cup.position = Vector3(side * 0.222, 0.0, 0.0)
		item.add_child(cup)
	_attach("Head", item, Transform3D(Basis.IDENTITY, (_point("Head") + _point("HeadTop_End")) / 2.0))


func _add_backpack(rng: RandomNumberGenerator) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.11
	capsule.height = 0.34
	var item := MeshInstance3D.new()
	item.mesh = capsule
	item.material_override = _flat(ACCESSORY_COLORS[rng.randi() % ACCESSORY_COLORS.size()])
	_attach("Spine2", item, Transform3D(Basis(), _point("Spine2") + Vector3(0.0, -0.04, -0.2)))


#A tube along the top half of a circle in the XY plane, a headphone band
func _arc_mesh(arc_radius: float, tube_radius: float) -> Mesh:
	var key := "arc_%s_%s" % [arc_radius, tube_radius]
	if _meshes.has(key):
		return _meshes[key]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 18
	var sides := 8
	for step in steps:
		for side in sides:
			var corners: Array[Vector3] = []
			for offset in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var angle := PI * float(step + offset[0]) / steps
				var ring := TAU * float(side + offset[1]) / sides
				var centre := Vector3(cos(angle), sin(angle), 0.0) * arc_radius
				var outward := Vector3(cos(angle), sin(angle), 0.0) * cos(ring) + Vector3(0.0, 0.0, sin(ring))
				corners.append(centre + outward * tube_radius)
			for index in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(corners[index])
	surface.generate_normals()
	_meshes[key] = surface.commit()
	return _meshes[key]


func _flat(color: Color) -> StandardMaterial3D:
	var key := "flat_%s" % color.to_html()
	if not _meshes.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.5
		_meshes[key] = material
	return _meshes[key]


func _phone_material() -> ShaderMaterial:
	if not _meshes.has("phone"):
		var material := ShaderMaterial.new()
		material.shader = PHONE_SHADER
		_meshes["phone"] = material
	return _meshes["phone"]


func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var step: Node = node
	while step != ancestor and step != null:
		result = (step as Node3D).transform * result
		step = step.get_parent()
	return result
