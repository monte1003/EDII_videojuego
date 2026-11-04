class_name PartyKit
extends RefCounted

#Pieces of a game-show set built from code: banners, candy pillars, light beams, rainbows, grandstands and lights.
#Anything that repeats goes in a MultiMesh or a single mesh, so a whole set costs a handful of draw calls

const CANDY: Shader = preload("res://assets/shaders/candy_stripes.gdshader")
const BUNTING: Shader = preload("res://assets/shaders/bunting.gdshader")
const BEAM: Shader = preload("res://assets/shaders/light_beam.gdshader")
const BULB: Shader = preload("res://assets/shaders/bulb.gdshader")

const PINK := Color("ff5c8a")
const YELLOW := Color("ffcf3f")
const CYAN := Color("3fd3ea")
const VIOLET := Color("8a63f5")
const GREEN := Color("5fdc9c")
const ORANGE := Color("ff9340")
const WHITE := Color("fffaf5")
const INK := Color("372c58")
const PALETTE: Array[Color] = [PINK, YELLOW, CYAN, VIOLET, GREEN, ORANGE]

const STAND_STEP := 0.9
const STAND_DEPTH := 1.3
const FAN_SPACING := 1.3

static var _cache: Dictionary = {}


#Two colours in alternate stripes around a shape; the same material is shared by every piece that asks for it
static func candy(a: Color, b: Color, stripes: float, twist := 0.0, glow := 0.0) -> ShaderMaterial:
	var key := "candy_%s_%s_%s_%s_%s" % [a.to_html(), b.to_html(), stripes, twist, glow]
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = CANDY
	material.set_shader_parameter("color_a", a)
	material.set_shader_parameter("color_b", b)
	material.set_shader_parameter("stripes", stripes)
	material.set_shader_parameter("twist", twist)
	material.set_shader_parameter("glow", glow)
	_cache[key] = material
	return material


#A plain painted material, shared; "glow" above 0 makes it shine on its own
static func paint(color: Color, glow := 0.0, roughness := 0.5) -> StandardMaterial3D:
	var key := "paint_%s_%s_%s" % [color.to_html(), glow, roughness]
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	_cache[key] = material
	return material


#A unit cylinder or box (along Y) stretched so that it goes from "from" to "to"
static func stretch(from: Vector3, to: Vector3) -> Transform3D:
	var length := from.distance_to(to)
	var direction := (to - from) / maxf(length, 0.001)
	var axis := Vector3.UP.cross(direction)
	var basis := Basis.IDENTITY
	if axis.length() > 0.0001:
		basis = Basis(axis.normalized(), acos(clampf(Vector3.UP.dot(direction), -1.0, 1.0)))
	elif direction.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	return Transform3D(basis.scaled_local(Vector3(1.0, length, 1.0)), (from + to) / 2.0)


#Flags hanging from a rope between two points; the rope sags by "sag" meters in the middle
static func bunting(from: Vector3, to: Vector3, sag: float, flags: int, size: float, colors: Array[Color]) -> MeshInstance3D:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var run := flat.length()
	var rise := to.y - from.y
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rope := Color(0.24, 0.2, 0.38, 0.0)
	var points: Array[Vector3] = []
	for index in flags + 1:
		var t := float(index) / flags
		points.append(Vector3(t * run, t * rise - sag * 4.0 * t * (1.0 - t), 0.0))
	for index in flags:
		var a := points[index]
		var b := points[index + 1]
		var tip := (a + b) / 2.0 + Vector3(0.0, -size, 0.0)
		var flag := colors[index % colors.size()]
		_triangle(tool, a, tip, b, Color(flag, 0.0), Color(flag, 1.0), Color(flag, 0.0))
		var thick := Vector3(0.0, 0.05, 0.0)
		_triangle(tool, a + thick, b + thick, a - thick, rope, rope, rope)
		_triangle(tool, b + thick, b - thick, a - thick, rope, rope, rope)
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = _bunting_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = from
	instance.rotation.y = atan2(-flat.z, flat.x)
	return instance


#A pole with a flag that flutters
static func pennant(height: float, color: Color) -> Node3D:
	var root := Node3D.new()
	var pole := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.04
	tube.bottom_radius = 0.05
	tube.height = height
	tube.radial_segments = 6
	tube.rings = 1
	pole.mesh = tube
	pole.material_override = paint(WHITE, 0.0, 0.4)
	pole.position.y = height / 2.0
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pole)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.0, height, 0.0)
	var low := Vector3(0.0, height - height * 0.3, 0.0)
	_triangle(tool, top, Vector3(height * 0.42, height * 0.85, 0.0), low, Color(color, 0.0), Color(color, 1.0), Color(color, 0.0))
	var flag := MeshInstance3D.new()
	flag.mesh = tool.commit()
	flag.material_override = _bunting_material()
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flag)
	return root


#A tall striped column with a glowing cap; it stands on its base point
static func pillar(height: float, radius: float, a: Color, b: Color) -> Node3D:
	var root := Node3D.new()
	var shaft := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = height
	tube.radial_segments = 20
	tube.rings = 1
	shaft.mesh = tube
	shaft.material_override = candy(a, b, 8.0, height / (radius * 2.0) * 0.5)
	shaft.position.y = height / 2.0
	root.add_child(shaft)
	var cap := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = radius * 1.3
	ball.height = radius * 2.6
	ball.radial_segments = 16
	ball.rings = 8
	cap.mesh = ball
	cap.material_override = paint(WHITE, 0.0, 0.25)
	cap.position.y = height
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cap)
	var ring := MeshInstance3D.new()
	var band := TorusMesh.new()
	band.inner_radius = radius * 1.05
	band.outer_radius = radius * 1.55
	band.rings = 20
	band.ring_segments = 6
	ring.mesh = band
	ring.material_override = paint(a, 1.4)
	ring.position.y = height - radius * 0.6
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	return root


#A spotlight beam that goes up from the origin; it is only a soft glow, never solid
static func beam(color: Color, length: float, radius: float, strength := 0.4) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = radius
	cone.bottom_radius = 0.12
	cone.height = length
	cone.radial_segments = 14
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = BEAM
	material.set_shader_parameter("beam_color", color)
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("beam_length", length)
	var instance := MeshInstance3D.new()
	instance.mesh = cone
	instance.material_override = material
	instance.position.y = length / 2.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


#A flat arch of colour bands, "radius" to the outer edge of the first band
static func rainbow(radius: float, band: float, colors: Array[Color]) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 36
	for index in colors.size():
		var outer := radius - index * band
		var inner := outer - band
		var color := Color(colors[index], 0.9)
		for step in steps:
			var a0 := PI * step / steps
			var a1 := PI * (step + 1) / steps
			var p0 := Vector3(cos(a0), sin(a0), 0.0)
			var p1 := Vector3(cos(a1), sin(a1), 0.0)
			_triangle(tool, p0 * outer, p1 * outer, p0 * inner, color, color, color)
			_triangle(tool, p1 * outer, p1 * inner, p0 * inner, color, color, color)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_fog = true
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


#Little round lights in one draw call; each phase says when its light is on
static func bulbs(spots: Array[Transform3D], colors: Array[Color], phases: Array[float]) -> MultiMeshInstance3D:
	var ball := SphereMesh.new()
	ball.radius = 0.13
	ball.height = 0.26
	ball.radial_segments = 8
	ball.rings = 4
	var material := ShaderMaterial.new()
	material.shader = BULB
	ball.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = ball
	multi.instance_count = spots.size()
	for index in spots.size():
		multi.set_instance_transform(index, spots[index])
		multi.set_instance_color(index, colors[index])
		multi.set_instance_custom_data(index, Color(phases[index], 0.0, 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


#A slow drift of little coloured stars inside a box, so the air is never empty; the box is centred on the node
static func sparkles(extents: Vector3, amount: int) -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.amount = amount
	sparks.lifetime = 10.0
	sparks.preprocess = 10.0
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = extents
	sparks.direction = Vector3.UP
	sparks.spread = 25.0
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 1.1
	sparks.gravity = Vector3.ZERO
	sparks.angle_max = 180.0
	sparks.angular_velocity_min = -40.0
	sparks.angular_velocity_max = 40.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.1
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.2, 1.0))
	fade.add_point(Vector2(0.8, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	sparks.scale_amount_curve = fade
	var tones := Gradient.new()
	tones.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	tones.colors = PackedColorArray([Color("ffffff"), Color("ffb3d9"), Color("b3f0ff"), Color("fff0a8")])
	sparks.color_initial_ramp = tones
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = ImpactFx.star_texture()
	#The ones next to the camera fade out, so none looks like a blot over the racer
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = 6.0
	material.distance_fade_max_distance = 16.0
	quad.material = material
	sparks.mesh = quad
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sparks


#Grandstand tiers facing +Z of "place": stepped blocks in one mesh with a fan on every step, added to "crowd"
static func stand(crowd: CrowdField, place: Transform3D, width: float, tiers: int, color: Color, rng: RandomNumberGenerator) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in tiers:
		var top := STAND_STEP * (tier + 1)
		var tone := color if tier % 2 == 0 else color.lerp(WHITE, 0.45)
		_box(tool, Vector3(0.0, top / 2.0, -tier * STAND_DEPTH), Vector3(width, top, STAND_DEPTH), tone)
		var fans := int(width / FAN_SPACING)
		for index in fans:
			var x := (index - (fans - 1) / 2.0) * FAN_SPACING + rng.randf_range(-0.15, 0.15)
			var local := Vector3(x, top, -tier * STAND_DEPTH + rng.randf_range(-0.2, 0.2))
			crowd.add_fan(place * local, place.basis.get_euler().y + rng.randf_range(-0.25, 0.25),
				rng.randf_range(0.9, 1.15), CrowdField.FAN_COLORS[rng.randi() % CrowdField.FAN_COLORS.size()])
	var high := STAND_STEP * tiers
	_box(tool, Vector3(0.0, high / 2.0 + 0.4, -tiers * STAND_DEPTH - 0.2), Vector3(width, high + 0.8, 0.4), color.lerp(INK, 0.25))
	_box(tool, Vector3(0.0, 0.55, STAND_DEPTH * 0.62), Vector3(width, 0.2, 0.2), WHITE)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.7
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = material
	instance.transform = place
	return instance


#A confetti cannon aimed up and forward; "muzzle" is where the confetti comes out, in its own space
static func cannon(a: Color, b: Color) -> Node3D:
	var root := Node3D.new()
	var tube := MeshInstance3D.new()
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.55
	barrel.bottom_radius = 0.38
	barrel.height = 1.9
	barrel.radial_segments = 16
	barrel.rings = 1
	tube.mesh = barrel
	tube.material_override = candy(a, b, 6.0, 2.0)
	tube.position = Vector3(0.0, 1.1, 0.0)
	tube.rotation_degrees.x = -12.0
	root.add_child(tube)
	var foot := MeshInstance3D.new()
	var block := CylinderMesh.new()
	block.top_radius = 0.7
	block.bottom_radius = 0.85
	block.height = 0.5
	block.radial_segments = 16
	block.rings = 1
	foot.mesh = block
	foot.material_override = paint(INK, 0.0, 0.5)
	foot.position.y = 0.25
	root.add_child(foot)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 2.15, -0.45)
	root.add_child(muzzle)
	return root


static func _bunting_material() -> ShaderMaterial:
	if _cache.has("bunting"):
		return _cache["bunting"]
	var material := ShaderMaterial.new()
	material.shader = BUNTING
	_cache["bunting"] = material
	return material


#Godot draws the clockwise side of a triangle, so the normal comes from the opposite turn
static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color_a: Color, color_b: Color, color_c: Color,
		facing := Vector3.ZERO) -> void:
	var normal := facing if facing != Vector3.ZERO else (c - a).cross(b - a).normalized()
	for entry in [[a, color_a], [b, color_b], [c, color_c]]:
		tool.set_color(entry[1])
		tool.set_normal(normal)
		tool.add_vertex(entry[0])


#A solid box with its own colour, wound so that its faces look outward
static func _box(tool: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var half := size / 2.0
	for normal: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var u := Vector3.UP.cross(normal)
		if u.length() < 0.001:
			u = Vector3.RIGHT
		u = u.normalized()
		var v := normal.cross(u)
		var hn := absf(normal.dot(half))
		var hu := absf(u.dot(half))
		var hv := absf(v.dot(half))
		var p0 := center + normal * hn - u * hu - v * hv
		var p1 := center + normal * hn + u * hu - v * hv
		var p2 := center + normal * hn + u * hu + v * hv
		var p3 := center + normal * hn - u * hu + v * hv
		_triangle(tool, p0, p2, p1, color, color, color, normal)
		_triangle(tool, p0, p3, p2, color, color, color, normal)
