class_name StreetWorld
extends Node3D

#Static scenery of the street minigame, built from the numbers of the game script.
#The street runs along X; the obstacles flow toward +X, where the end line is.
#The game camera looks at the street from the +Z side, so the near side only gets low things
#close to the street and its buildings stand behind the camera. The victory close-up looks
#down the street toward +X, so the street and the buildings go on far past the end line and
#a painted skyline closes the horizon all around.
#Repeated pieces (buildings, windows, trees...) are drawn with one MultiMesh per kind, so the
#whole city costs a handful of draw calls.

const SIDEWALK_HEIGHT := 0.12
const HEADING_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const BUILDING_COLORS: Array[Color] = [
	Color("cdbcf7"), Color("f8a4b3"), Color("bcc8fa"), Color("f6d29a"), Color("a9dcc8"),
]
const AWNING_COLORS: Array[Color] = [Color("fd567f"), Color("2f9fb8"), Color("e08a22"), Color("7b6cf6")]
const GLASS_COLORS: Array[Color] = [Color("eef3ff"), Color("c9d4f6")]
const LEAF_COLORS: Array[Color] = [Color("7cc59a"), Color("94d4a5"), Color("6fb8a0")]
const GRASS := Color("9fd3a8")
const ROAD := Color("4b4e63")
const SIDEWALK := Color("ddd6ea")
const SIDEWALK_JOINT := Color("cbc2de")
const PAINT := Color("f5f1fb")
const TRUNK := Color("9b7a72")
const POLE := Color("5d5873")

#Meters of street and city past the end of the obstacles' path, for the victory close-up
const EXTRA_LENGTH := 200.0
#The near side (+Z) is open grass with trees up to here; its buildings start behind it,
#out of the game camera's view
const NEAR_TREES_FROM := 11.0
const NEAR_BUILDINGS_Z := 23.0
#Near-side lamps stand only past this X, outside the game camera's frame
const NEAR_LAMPS_FROM_X := 24.0
const LAMP_SPACING := 12.0
#Painted skyline: two rings around the scene, the far one paler, for some depth
const SKYLINE_SIZE := Vector2i(2048, 512)

var _batches: Dictionary = {}


func build(street_half_width: float, sidewalk_width: float, lane_count: int,
		from_x: float, to_x: float, end_x: float) -> void:
	var far_x := maxf(to_x, end_x) + EXTRA_LENGTH
	var length := far_x - from_x
	var center_x := (from_x + far_x) / 2.0
	var outer := street_half_width + sidewalk_width
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	_add_box("solid", Vector3(0.0, -0.06, 0.0), Vector3(900.0, 0.1, 900.0), GRASS)
	_add_box("solid", Vector3(center_x, -0.03, 0.0), Vector3(length, 0.06, street_half_width * 2.0), ROAD)
	for side in [-1.0, 1.0]:
		_add_box("solid", Vector3(center_x, SIDEWALK_HEIGHT / 2.0, side * (street_half_width + sidewalk_width / 2.0)),
			Vector3(length, SIDEWALK_HEIGHT, sidewalk_width), SIDEWALK)
		#Curb
		_add_box("solid", Vector3(center_x, (SIDEWALK_HEIGHT + 0.02) / 2.0, side * (street_half_width + 0.12)),
			Vector3(length, SIDEWALK_HEIGHT + 0.02, 0.24), PAINT)
		#Paving joints across the sidewalk
		var x := from_x
		while x < far_x:
			_add_box("solid", Vector3(x, SIDEWALK_HEIGHT + 0.003, side * (street_half_width + sidewalk_width / 2.0 + 0.12)),
				Vector3(0.07, 0.006, sidewalk_width - 0.24), SIDEWALK_JOINT)
			x += 1.5

	#Dashed lines between the lanes
	var lane_width := street_half_width * 2.0 / lane_count
	for lane in range(1, lane_count):
		var z := -street_half_width + lane * lane_width
		var x := from_x
		while x < far_x:
			_add_box("solid", Vector3(x + 1.0, 0.005, z), Vector3(2.0, 0.01, 0.15), PAINT)
			x += 4.0

	_build_crosswalk(end_x + 16.0, street_half_width)
	_build_crosswalk(end_x + 90.0, street_half_width)
	_build_end_line(end_x, outer)
	#Far side: a low row along the street with shops and a taller row behind it
	_build_building_row(rng, from_x, far_x, -(outer + 1.5), 1.0, Vector2(5.0, 7.0), Vector2(3.5, 9.0), true)
	_build_building_row(rng, from_x, far_x, -(outer + 12.0), 1.0, Vector2(8.0, 12.0), Vector2(10.0, 22.0), false)
	#Near side: behind the game camera, so only the victory close-up sees them
	_build_building_row(rng, from_x, far_x, NEAR_BUILDINGS_Z, -1.0, Vector2(6.0, 9.0), Vector2(5.0, 14.0), true)
	_build_trees(rng, from_x, far_x, outer)
	_build_lamps(from_x, far_x, outer)
	_build_clouds(rng)
	_build_skyline(Color("c3b2ee"), Color("dcd2fa"), 280.0, 7, Vector2i(150, 400), 3)
	_build_skyline(Color("e3cdec"), Color(), 340.0, 9, Vector2i(220, 470), 5)
	_flush_batches()


#---- pieces ----------------------------------------------------------------------------

func _build_end_line(end_x: float, outer: float) -> void:
	_add_box("solid", Vector3(end_x, SIDEWALK_HEIGHT + 0.02, 0.0), Vector3(0.6, 0.04, outer * 2.0), Palette.CORAL)
	for side in [-1.0, 1.0]:
		_add_box("solid", Vector3(end_x, 1.2, side * (outer + 0.4)), Vector3(0.4, 2.4, 0.4), Palette.CORAL)
	var label := Label3D.new()
	label.text = "FIN"
	label.font = HEADING_FONT
	label.font_size = 160
	label.pixel_size = 0.01
	label.modulate = Palette.PAPER
	label.outline_modulate = Palette.CORAL
	label.outline_size = 36
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(end_x, 3.2, -outer - 0.4)
	add_child(label)


#Zebra stripes run along the traffic, side by side across the road
func _build_crosswalk(x: float, street_half_width: float) -> void:
	var z := -street_half_width + 0.5
	while z < street_half_width - 0.3:
		_add_box("solid", Vector3(x, 0.006, z), Vector3(2.6, 0.012, 0.5), PAINT)
		z += 1.0


#Buildings side by side from from_x to to_x. front_z is the face toward the street and
#facing the direction it looks at (+1 is +Z). With "shops" the ground floor gets a shop
#window and an awning, and the roofs get small machines
func _build_building_row(rng: RandomNumberGenerator, from_x: float, to_x: float, front_z: float,
		facing: float, depth_range: Vector2, height_range: Vector2, shops: bool) -> void:
	var x := from_x
	while x < to_x:
		var width := rng.randf_range(4.5, 7.5)
		var height := rng.randf_range(height_range.x, height_range.y)
		var depth := rng.randf_range(depth_range.x, depth_range.y)
		var color := BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()]
		var cx := x + width / 2.0
		var cz := front_z - facing * depth / 2.0
		_add_box("solid", Vector3(cx, height / 2.0, cz), Vector3(width - 0.4, height, depth), color)
		_add_box("solid", Vector3(cx, height + 0.12, cz), Vector3(width - 0.1, 0.24, depth + 0.3), color.darkened(0.12))

		var face := front_z + facing * 0.03
		var first_floor := 1.8
		if shops:
			first_floor = 4.2
			_add_box("glass", Vector3(cx, 1.3, face), Vector3(width - 1.8, 1.5, 0.06), GLASS_COLORS[1])
			var awning := AWNING_COLORS[rng.randi() % AWNING_COLORS.size()]
			_add_box("solid", Vector3(cx, 2.55, front_z + facing * 0.5), Vector3(width - 1.2, 0.14, 1.0), awning)
			_add_box("solid", Vector3(cx, 2.4, front_z + facing * 1.0), Vector3(width - 1.2, 0.3, 0.06), awning)
			if rng.randf() < 0.5:
				_add_box("solid", Vector3(cx + rng.randf_range(-1.0, 1.0), height + 0.6, cz),
					Vector3(1.2, 0.8, 1.0), Color("e7e2f0"))
		var columns := floori((width - 1.4) / 1.5)
		var y := first_floor
		while y < height - 1.0:
			for column in columns:
				if rng.randf() < 0.1:
					continue
				var wx := cx + (column - (columns - 1) / 2.0) * 1.5
				_add_box("glass", Vector3(wx, y, face), Vector3(0.8, 1.1, 0.06),
					GLASS_COLORS[rng.randi() % GLASS_COLORS.size()])
			y += 2.4
		x += width


#Low round trees on the near-side grass, and bushes along the far sidewalk
func _build_trees(rng: RandomNumberGenerator, from_x: float, to_x: float, outer: float) -> void:
	var x := from_x
	while x < to_x:
		var at := Vector3(x + rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(NEAR_TREES_FROM, NEAR_BUILDINGS_Z - 3.0))
		var size := rng.randf_range(0.8, 1.25)
		var leaves := LEAF_COLORS[rng.randi() % LEAF_COLORS.size()]
		_add("pole", Transform3D(Basis.from_scale(Vector3(0.28, 1.6, 0.28) * size), at + Vector3(0, 0.8 * size, 0)), TRUNK)
		_add("round", Transform3D(Basis.from_scale(Vector3(2.2, 1.9, 2.2) * size), at + Vector3(0, 2.3 * size, 0)), leaves)
		_add("round", Transform3D(Basis.from_scale(Vector3(1.5, 1.3, 1.5) * size),
			at + Vector3(0.5, 3.1 * size, 0.3)), leaves.lightened(0.1))
		x += rng.randf_range(3.5, 6.5)

	x = from_x + LAMP_SPACING / 2.0
	while x < to_x:
		for offset in [-1.2, 0.0, 1.1]:
			var radius := rng.randf_range(0.45, 0.65)
			_add("round", Transform3D(Basis.from_scale(Vector3(radius * 2.2, radius * 1.5, radius * 1.8)),
				Vector3(x + offset, radius * 0.6, -(outer + 0.75))), LEAF_COLORS[rng.randi() % LEAF_COLORS.size()])
		x += LAMP_SPACING


func _build_lamps(from_x: float, to_x: float, outer: float) -> void:
	var x := from_x
	while x < to_x:
		_lamp(Vector3(x, 0.0, -(outer + 0.45)), 1.0)
		if x > NEAR_LAMPS_FROM_X:
			_lamp(Vector3(x, 0.0, outer + 0.45), -1.0)
		x += LAMP_SPACING


#A street lamp whose arm reaches over the sidewalk toward the street (facing is +1 toward +Z)
func _lamp(at: Vector3, facing: float) -> void:
	_add("pole", Transform3D(Basis.from_scale(Vector3(0.14, 4.2, 0.14)), at + Vector3(0, 2.1, 0)), POLE)
	_add_box("solid", at + Vector3(0, 4.15, facing * 0.5), Vector3(0.1, 0.1, 1.1), POLE)
	_add("glow", Transform3D(Basis.from_scale(Vector3(0.42, 0.3, 0.42)), at + Vector3(0, 4.0, facing * 1.0)), Color("fff3c4"))


#Puffy clouds in the sky, more of them toward +X where the victory close-up looks
func _build_clouds(rng: RandomNumberGenerator) -> void:
	for index in 16:
		var angle := rng.randf_range(-1.1, 1.1) if index < 10 else rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(140.0, 230.0)
		var centre := Vector3(cos(angle) * distance, rng.randf_range(38.0, 70.0), sin(angle) * distance)
		var size := rng.randf_range(6.0, 11.0)
		for puff in rng.randi_range(3, 5):
			var offset := Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.2, 0.5), rng.randf_range(-0.8, 0.8)) * size
			var scale := Vector3(1.8, 0.9, 1.3) * size * rng.randf_range(0.7, 1.1)
			_add("cloud", Transform3D(Basis.from_scale(scale), centre + offset), Color.WHITE)


#A ring of painted city silhouettes around the whole scene. The texture is drawn here, so
#there is no image file to keep; window_color with alpha 0 leaves the windows out
func _build_skyline(color: Color, window_color: Color, radius: float, repeats: int,
		height_px: Vector2i, image_seed: int) -> void:
	var image := Image.create(SKYLINE_SIZE.x, SKYLINE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = image_seed
	var bottom := SKYLINE_SIZE.y
	var x := 0
	while x < SKYLINE_SIZE.x:
		var width := rng.randi_range(40, 120)
		var height := rng.randi_range(height_px.x, height_px.y)
		_wrap_rect(image, Rect2i(x, bottom - height, width, height), color)
		if rng.randf() < 0.35:
			var step := rng.randi_range(20, 60)
			_wrap_rect(image, Rect2i(x + width / 4, bottom - height - step, width / 2, step), color)
		if rng.randf() < 0.25:
			_wrap_rect(image, Rect2i(x + width / 2, bottom - height - 50, 3, 50), color)
		if window_color.a > 0.0:
			for wy in range(bottom - height + 14, bottom - 12, 18):
				for wx in range(x + 8, x + width - 12, 14):
					if rng.randf() < 0.55:
						_wrap_rect(image, Rect2i(wx, wy, 6, 8), window_color)
		x += width - rng.randi_range(0, 18)
	image.generate_mipmaps()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	#The texture keeps its proportions: its height follows from the width of one repeat
	var height := TAU * radius / repeats * SKYLINE_SIZE.y / SKYLINE_SIZE.x
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 128
	for index in segments:
		var a0 := TAU * index / segments
		var a1 := TAU * (index + 1) / segments
		var u0 := float(repeats) * index / segments
		var u1 := float(repeats) * (index + 1) / segments
		var low0 := Vector3(cos(a0) * radius, -1.0, sin(a0) * radius)
		var low1 := Vector3(cos(a1) * radius, -1.0, sin(a1) * radius)
		var high0 := low0 + Vector3(0, height, 0)
		var high1 := low1 + Vector3(0, height, 0)
		for corner in [[low0, Vector2(u0, 1)], [high0, Vector2(u0, 0)], [high1, Vector2(u1, 0)],
				[low0, Vector2(u0, 1)], [high1, Vector2(u1, 0)], [low1, Vector2(u1, 1)]]:
			surface.set_uv(corner[1])
			surface.add_vertex(corner[0])
	var ring := MeshInstance3D.new()
	ring.mesh = surface.commit()
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


#Fills a rectangle that may run past the right edge, continuing it on the left so the
#texture tiles without a seam
func _wrap_rect(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)
	if rect.end.x > image.get_width():
		image.fill_rect(Rect2i(rect.position.x - image.get_width(), rect.position.y, rect.size.x, rect.size.y), color)


#---- batching --------------------------------------------------------------------------

func _add_box(batch: String, center: Vector3, size: Vector3, color: Color) -> void:
	_add(batch, Transform3D(Basis.from_scale(size), center), color)


func _add(batch: String, xform: Transform3D, color: Color) -> void:
	if not _batches.has(batch):
		_batches[batch] = []
	(_batches[batch] as Array).append([xform, color])


#One MultiMesh per kind of piece; the colour of each piece goes in its instance colour
func _flush_batches() -> void:
	for batch: String in _batches:
		var items: Array = _batches[batch]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _batch_mesh(batch)
		multimesh.instance_count = items.size()
		for index in items.size():
			multimesh.set_instance_transform(index, items[index][0])
			multimesh.set_instance_color(index, items[index][1])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _batch_material(batch)
		if batch == "cloud" or batch == "glass":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_batches.clear()


func _batch_mesh(batch: String) -> Mesh:
	match batch:
		"round", "glow", "cloud":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 12
			sphere.rings = 6
			return sphere
		"pole":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 8
			cylinder.rings = 1
			return cylinder
		_:
			return BoxMesh.new()


func _batch_material(batch: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	match batch:
		"glass":
			material.roughness = 0.25
			material.emission_enabled = true
			material.emission = Color("6d7fb8")
			material.emission_energy_multiplier = 0.25
		"glow":
			material.emission_enabled = true
			material.emission = Color("fff3c4")
			material.emission_energy_multiplier = 1.2
		"cloud":
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
