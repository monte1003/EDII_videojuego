class_name StreetWorld
extends Node3D

#Scenery of the street minigame: a toy-town boulevard along X, end line and giant arch at +X; the runner walks on its ground

const SIDEWALK_HEIGHT := 0.12
const CURB_WIDTH := 0.24
const HEADING_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const GRASS_TEXTURE: Texture2D = preload("res://assets/textures/grass_checker.png")
const SIDEWALK_TEXTURE: Texture2D = preload("res://assets/textures/sidewalk_tiles.png")
const CURB_TEXTURE: Texture2D = preload("res://assets/textures/curb_stripes.png")
const ROAD_COLOR := Color("5a5eb0")
const LINE_COLOR := Color("fff6ec")
#Faint tints on the cream walls: the colours of each building stay and no two neighbours look the same
const WALL_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.93, 0.95), Color(0.93, 0.97, 1.0), Color(1.0, 0.97, 0.88),
]
const BUILDING_IDS: Array[StringName] = [&"building_shop", &"building_flats"]
const CLOUD_COUNT := 16
#Meters after which the markings repeat, so the belt can slide them without end: each period holds one zebra crossing,
#five lane dashes and three arrows, and none of them touches another
const MARKS_PERIOD := 24.0
const ZEBRA_DEPTH := 2.4
const ZEBRA_STRIPE := 0.55
const ZEBRA_PITCH := 1.1
const DASH_LENGTH := 2.0
const DASH_COUNT := 5
const DASH_WIDTH := 0.15
#The arrows painted on every lane that show where the belt takes you: toward +X, away from the traffic
const CHEVRON_COUNT := 3
const CHEVRON_COLOR := Color("8e96f2")
const CHEVRON_ANGLE := deg_to_rad(38.0)
const CHEVRON_ARM := 1.1
#Meters kept free around the arch and the bus stops
const ARCH_CLEARANCE := 6.0
const STOP_CLEARANCE := 6.5

var _materials: Dictionary = {}
#The ground is a conveyor: the markings and the textures slide toward +X at this speed
var _belt_speed := 0.0
var _belt_offset := 0.0
var _marks_row: Node3D
var _clouds: Array[Dictionary] = []
var _stops: Array[Vector2] = []
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func build(street_half_width: float, sidewalk_width: float, lane_count: int,
		from_x: float, to_x: float, end_x: float) -> void:
	_rng.seed = 7
	var outer := street_half_width + sidewalk_width
	_build_ground(street_half_width, sidewalk_width, from_x, to_x)
	_build_road_marks(street_half_width, lane_count, from_x, to_x)
	_build_end(end_x, street_half_width, outer)
	_build_skyline(from_x, to_x, outer)
	_build_bus_stops(outer)
	_build_greenery(from_x, to_x, outer, end_x)
	_build_clouds(from_x, to_x)


func set_belt_speed(speed: float) -> void:
	_belt_speed = speed


func _process(delta: float) -> void:
	_clock += delta
	if _belt_speed > 0.0:
		_slide_ground(delta)
	for entry in _clouds:
		var node: Node3D = entry["node"]
		node.position.y = entry["base_y"] + sin(_clock * entry["speed"] + entry["phase"]) * 0.8


func _slide_ground(delta: float) -> void:
	_belt_offset += _belt_speed * delta
	_marks_row.position.x = fposmod(_belt_offset, MARKS_PERIOD)
	_textured(SIDEWALK_TEXTURE, 4.0).uv1_offset.x = -_belt_offset / 4.0
	_curb_material().uv1_offset.x = -_belt_offset / 4.0


func _build_ground(half: float, sidewalk_width: float, from_x: float, to_x: float) -> void:
	var length := to_x - from_x
	var center_x := (from_x + to_x) / 2.0
	var outer := half + sidewalk_width
	var span := outer * 2.0 + 40.0
	_box(Vector3(center_x, -0.06, 0.0), Vector3(length, 0.1, span), _textured(GRASS_TEXTURE, 8.0))
	_box(Vector3(center_x, -0.03, 0.0), Vector3(length, 0.06, half * 2.0), _flat(ROAD_COLOR))

	var ground := StaticBody3D.new()
	ground.position = Vector3(center_x, -0.5, 0.0)
	var slab := BoxShape3D.new()
	slab.size = Vector3(length, 1.0, span)
	var slab_collider := CollisionShape3D.new()
	slab_collider.shape = slab
	ground.add_child(slab_collider)
	add_child(ground)

	for side: float in [-1.0, 1.0]:
		#The paving starts where the curb ends, so the two never share a face
		var paving := sidewalk_width - CURB_WIDTH
		_box(Vector3(center_x, SIDEWALK_HEIGHT / 2.0, side * (half + CURB_WIDTH + paving / 2.0)),
			Vector3(length, SIDEWALK_HEIGHT, paving), _textured(SIDEWALK_TEXTURE, 4.0))
		_box(Vector3(center_x, (SIDEWALK_HEIGHT + 0.02) / 2.0, side * (half + CURB_WIDTH / 2.0)),
			Vector3(length, SIDEWALK_HEIGHT + 0.02, CURB_WIDTH), _curb_material())
		_sidewalk_collider(center_x, length, side, half, outer)


#The curb is a ramp for the physics, so the runner steps up onto the sidewalk without catching on the edge
func _sidewalk_collider(center_x: float, length: float, side: float, half: float, outer: float) -> void:
	var points := PackedVector3Array()
	for end: float in [-length / 2.0, length / 2.0]:
		points.append(Vector3(end, -0.3, side * half))
		points.append(Vector3(end, 0.0, side * half))
		points.append(Vector3(end, SIDEWALK_HEIGHT, side * (half + 0.35)))
		points.append(Vector3(end, SIDEWALK_HEIGHT, side * outer))
		points.append(Vector3(end, -0.3, side * outer))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var body := StaticBody3D.new()
	body.position = Vector3(center_x, 0.0, 0.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _build_road_marks(half: float, lane_count: int, from_x: float, to_x: float) -> void:
	_marks_row = Node3D.new()
	add_child(_marks_row)
	var lane_width := half * 2.0 / lane_count
	var stripes := int(floorf((half * 2.0 - 1.0) / ZEBRA_PITCH)) + 1
	#Equal gaps between the lane dashes and between the last dash and the zebra stripes
	var dash_gap := (MARKS_PERIOD - ZEBRA_DEPTH - DASH_COUNT * DASH_LENGTH) / (DASH_COUNT + 1.0)
	var chevron_step := MARKS_PERIOD / CHEVRON_COUNT
	var white: Array[Transform3D] = []
	var arrows: Array[Transform3D] = []
	#Zebra crossings; the first one is where the runner starts. The row slides up to one period, so it starts one period early
	var crossing_x := -7.0 - MARKS_PERIOD * ceilf((-7.0 - (from_x - MARKS_PERIOD)) / MARKS_PERIOD)
	while crossing_x < to_x + MARKS_PERIOD:
		for index in stripes:
			var z := (index - (stripes - 1) / 2.0) * ZEBRA_PITCH
			white.append(_mark(Vector3(crossing_x, 0.006, z), Vector3(ZEBRA_DEPTH, 0.01, ZEBRA_STRIPE)))
		for lane in range(1, lane_count):
			for index in DASH_COUNT:
				var dash_x := crossing_x + ZEBRA_DEPTH / 2.0 + dash_gap + (index + 0.5) * DASH_LENGTH + index * dash_gap
				white.append(_mark(Vector3(dash_x, 0.005, -half + lane * lane_width), Vector3(DASH_LENGTH, 0.01, DASH_WIDTH)))
		for lane in lane_count:
			for index in CHEVRON_COUNT:
				var tip_x := crossing_x + chevron_step / 2.0 + index * chevron_step
				_add_chevron(arrows, Vector3(tip_x + 0.48, 0.007, -half + (lane + 0.5) * lane_width))
		crossing_x += MARKS_PERIOD
	_scatter(white, _flat(LINE_COLOR))
	_scatter(arrows, _flat(CHEVRON_COLOR))


#A "V" whose point goes to +X: two bars that meet at "tip"
func _add_chevron(into: Array[Transform3D], tip: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		var direction := Vector3(-cos(CHEVRON_ANGLE), 0.0, side * sin(CHEVRON_ANGLE))
		var mark := _mark(tip + direction * CHEVRON_ARM / 2.0, Vector3(CHEVRON_ARM, 0.01, 0.2))
		mark.basis = Basis(Vector3.UP, side * CHEVRON_ANGLE) * mark.basis
		into.append(mark)


#A flat box of the unit mesh of _scatter, at "center" with the given size
func _mark(center: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), center)


#All the boxes of one colour in a single draw call
func _scatter(boxes: Array[Transform3D], material: Material) -> void:
	var mesh := BoxMesh.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = boxes.size()
	for index in boxes.size():
		multi.set_instance_transform(index, boxes[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marks_row.add_child(instance)


#A coral band on the ground marks the line; the inflatable arch over it is what shows from far away
func _build_end(end_x: float, half: float, outer: float) -> void:
	#Painted flat: over the road and over each paving, never across the curb
	var coral := _flat(Palette.CORAL)
	_box(Vector3(end_x, 0.012, 0.0), Vector3(0.6, 0.024, half * 2.0), coral)
	var paving := outer - half - CURB_WIDTH
	for side: float in [-1.0, 1.0]:
		_box(Vector3(end_x, SIDEWALK_HEIGHT + 0.006, side * (half + CURB_WIDTH + paving / 2.0)), Vector3(0.6, 0.012, paving), coral)
	var arch := PropKit.make(&"arch", Vector3((outer + 0.5) * 2.0, 0.0, 0.0))
	arch.position = Vector3(end_x, 0.0, 0.0)
	arch.rotation.y = PI / 2.0
	add_child(arch)
	var label := Label3D.new()
	label.text = "FIN"
	label.font = HEADING_FONT
	label.font_size = 160
	label.pixel_size = 0.02
	label.modulate = Palette.PAPER
	label.outline_modulate = Palette.CORAL
	label.outline_size = 36
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(end_x, outer * 1.05, 0.0)
	add_child(label)


#Two rows of toy buildings behind the greenery and a block closing each end of the street
func _build_skyline(from_x: float, to_x: float, outer: float) -> void:
	for side: float in [-1.0, 1.0]:
		var x := from_x
		while x < to_x:
			x += _place_building(Vector3(x, 0.0, side * (outer + 7.0)), Vector3.RIGHT, PI if side > 0.0 else 0.0, 9.0, 12.5) + 0.3
	for end: float in [-1.0, 1.0]:
		var edge := from_x - 1.0 if end < 0.0 else to_x + 1.0
		var z := -outer - 8.0
		while z < outer + 8.0:
			z += _place_building(Vector3(edge, 0.0, z), Vector3.BACK, -end * PI / 2.0, 14.0, 19.0) + 0.3


#Places a building starting at "start" and growing along "along", front turned to "yaw"; returns the width it takes
func _place_building(start: Vector3, along: Vector3, yaw: float, min_height: float, max_height: float) -> float:
	var id := BUILDING_IDS[_rng.randi() % BUILDING_IDS.size()]
	var height := _rng.randf_range(min_height, max_height)
	var size := PropKit.base_size(id)
	var width := size.x * height / size.y
	var building := PropKit.make_tall(id, height, WALL_TINTS[_rng.randi() % WALL_TINTS.size()], false)
	building.position = start + along * width / 2.0
	building.rotation.y = yaw
	add_child(building)
	return width


#A bus stop on each side, back to the buildings and open toward the street
func _build_bus_stops(outer: float) -> void:
	for entry in [[1.0, -20.0], [-1.0, 8.0]]:
		var side: float = entry[0]
		var x: float = entry[1]
		var stop := PropKit.make(&"bus_stop", Vector3(5.2, 0.0, 0.0))
		stop.position = Vector3(x, 0.0, side * (outer + 2.6))
		stop.rotation.y = PI if side > 0.0 else 0.0
		add_child(stop)
		_stops.append(Vector2(side, x))


#Trees and bushes on the grass strip and lamps along the curb; they leave room for the arch and the stops
func _build_greenery(from_x: float, to_x: float, outer: float, end_x: float) -> void:
	for side: float in [-1.0, 1.0]:
		var x := from_x + 4.0 + (5.0 if side > 0.0 else 0.0)
		while x < to_x - 3.0:
			if _is_free(side, x, end_x):
				var tree := PropKit.make_tall(&"tree", _rng.randf_range(5.2, 6.8))
				tree.position = Vector3(x, 0.0, side * (outer + 2.0))
				tree.rotation.y = _rng.randf() * TAU
				add_child(tree)
			var bush_x := x + _rng.randf_range(4.2, 5.4)
			if _is_free(side, bush_x, end_x):
				var bush := PropKit.make_tall(&"bush", _rng.randf_range(1.4, 2.0), Color.WHITE, false)
				bush.position = Vector3(bush_x, 0.0, side * (outer + 1.2))
				bush.rotation.y = _rng.randf() * TAU
				add_child(bush)
			x += _rng.randf_range(9.0, 11.5)
		var lamp_x := from_x + 8.0 + (8.0 if side > 0.0 else 0.0)
		while lamp_x < to_x - 3.0:
			if _is_free(side, lamp_x, end_x):
				var lamp := PropKit.make_tall(&"lamp", 5.0)
				lamp.position = Vector3(lamp_x, 0.0, side * (outer + 0.6))
				add_child(lamp)
			lamp_x += 16.0


func _is_free(side: float, x: float, end_x: float) -> bool:
	if absf(x - end_x) < ARCH_CLEARANCE:
		return false
	for stop in _stops:
		if stop.x == side and absf(x - stop.y) < STOP_CLEARANCE:
			return false
	return true


func _build_clouds(from_x: float, to_x: float) -> void:
	for index in CLOUD_COUNT:
		var side := -1.0 if index % 2 == 0 else 1.0
		var cloud := PropKit.make_long(&"cloud", _rng.randf_range(12.0, 24.0), Color.WHITE, false)
		var base_y := _rng.randf_range(17.0, 34.0)
		cloud.position = Vector3(lerpf(from_x, to_x, _rng.randf()), base_y, side * _rng.randf_range(26.0, 62.0))
		cloud.rotation.y = _rng.randf() * TAU
		add_child(cloud)
		_clouds.append({"node": cloud, "base_y": base_y, "phase": _rng.randf() * TAU, "speed": _rng.randf_range(0.25, 0.6)})


func _curb_material() -> StandardMaterial3D:
	var material := _textured(CURB_TEXTURE, 4.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material


func _flat(color: Color) -> StandardMaterial3D:
	var key := "flat_" + color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	_materials[key] = material
	return material


#World-space mapping: the texture covers "meters" meters of ground whatever the size of the box
func _textured(texture: Texture2D, meters: float) -> StandardMaterial3D:
	var key := "tex_%s_%s" % [texture.resource_path, meters]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.9
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / meters
	_materials[key] = material
	return material


func _box(center: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	(parent if parent != null else self).add_child(instance)
