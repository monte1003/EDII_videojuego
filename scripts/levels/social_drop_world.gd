class_name SocialDropWorld
extends Node3D

#The SocialDrop stage: a platform of social media tiles (6 across, 5 deep) floating in the
#sky, the giant screen in front of the player where the spin is shown, and a sea of clouds
#drifting below

const COLUMNS := 6
const ROWS := 5
const TILE_SIZE := 2.75
const TILE_GAP := 0.22
const TILE_THICKNESS := 0.4
const TILE_SHADER := preload("res://assets/ui/shaders/icon_tile.gdshader")
#How far a tile falls before it hides; it comes back from half of it
const DROP_DEPTH := 14.0
const DROP_TIME := 0.9
const RISE_TIME := 0.7
#Free meters between the front edge of the platform and the screen
const SCREEN_DISTANCE := 3.0
const SCREEN_SIZE := Vector2(11.5, 6.6)
const SCREEN_HEIGHT := 3.6
#The screen leans back toward the camera above, so it does not look squashed from there
const SCREEN_TILT_DEGREES := 35.0
#Fixed camera high above the back of the platform: the whole board and the screen fit in it
const CAMERA_POSITION := Vector3(0.0, 22.2, 12.4)
const CAMERA_TARGET := Vector3(0.0, 0.0, -4.1)
const CAMERA_FOV := 60.0
const SCREEN_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const SCREEN_FONT_SIZE := 220
const TEXT_PIXEL_SIZE := 0.012
const SIDE_COLOR := Color("9d88e0")
const FRAME_COLOR := Color("372c58")
const PANEL_COLOR := Color("1d1638")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")
const AMBER := Color("ffc857")
const WARNING_TINT := Color("ff5a5a")
#The sea of clouds: how many, the box they drift in (x wraps around) and their speed
const CLOUD_COUNT := 26
const CLOUD_AREA := Rect2(-60.0, -45.0, 120.0, 80.0)
const CLOUD_DEPTH_RANGE := Vector2(-20.0, -9.0)
const CLOUD_SPEED_RANGE := Vector2(0.8, 2.2)
const CLOUD_COLORS: Array[Color] = [Color("ffffff"), Color("f3ecff"), Color("fde8f1")]
#Icon cards floating far around the platform, turning slowly
const CARD_COUNT := 10
#Round shadow under the player, on the floor even while it jumps
const SHADOW_DIAMETER := 2.1
#How much the gold marker over the player bobs up and down
const MARKER_BOB := 0.12
#Rockets fly along a row this high; they start and end this far past the sides of the board
const ROCKET_HEIGHT := 0.85
const ROCKET_RUN_OUT := 20.0
#Length of the whole rocket (flame aside) before ROCKET_SCALE, for the hit test
const ROCKET_LENGTH := 2.7
const ROCKET_SCALE := 1.45
const ROCKET_WARNING_COLOR := Color("ff1f3d")


class Tile:
	var body: StaticBody3D
	var collider: CollisionShape3D
	var top: ShaderMaterial
	var icon := 0
	var dropped := false


class Cloud:
	var node: Node3D
	var speed := 1.0


#A rocket crossing one row: its row blinks red for "delay" seconds, then it flies across
class Rocket:
	var node: Node3D
	var flame: Node3D
	var strip: MeshInstance3D
	var strip_material: StandardMaterial3D
	var direction := 1.0
	var speed := 1.0
	var delay := 0.0
	var hit := false


var camera: Camera3D

var _icons: Array[Texture2D] = []
var _tiles: Array[Tile] = []
var _clouds: Array[Cloud] = []
var _cards: Array[Node3D] = []
var _rockets: Array[Rocket] = []
var _decor_time := 0.0
var _marker: MeshInstance3D
var _shadow: MeshInstance3D
var _screen_label: Label3D
var _screen_icon: Sprite3D
var _punch_tween: Tween


func build(icons: Array[Texture2D], rng: RandomNumberGenerator) -> void:
	_icons = icons
	_build_sky()
	_build_camera()
	_build_tiles()
	_build_screen()
	_build_clouds()
	_build_cards()
	_build_player_marks()
	shuffle(rng)


#The gold triangle floats "marker_height" over the player and its shadow stays on the floor,
#smaller the higher the player jumps; the shadow goes away once the player falls
func follow_player(at: Vector3, marker_height: float) -> void:
	_marker.position = at + Vector3(0.0, marker_height + sin(_decor_time * 4.0) * MARKER_BOB, 0.0)
	_shadow.visible = at.y > -0.3
	_shadow.position = Vector3(at.x, 0.03, at.z)
	_shadow.scale = Vector3.ONE * clampf(1.0 - at.y * 0.3, 0.5, 1.0)


#With an even count the centre of the platform is a gap: start on a tile next to it
func spawn_point() -> Vector3:
	var half_step := (TILE_SIZE + TILE_GAP) / 2.0
	return Vector3(half_step if COLUMNS % 2 == 0 else 0.0, 0.05, half_step if ROWS % 2 == 0 else 0.0)


#Every icon is on at least one tile; the rest of the tiles get any icon at random
func shuffle(rng: RandomNumberGenerator) -> void:
	var deck: Array[int] = []
	for index in _tiles.size():
		deck.append(index if index < _icons.size() else rng.randi() % _icons.size())
	for index in range(deck.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := deck[index]
		deck[index] = deck[other]
		deck[other] = held
	for index in _tiles.size():
		var tile := _tiles[index]
		tile.icon = deck[index]
		tile.top.set_shader_parameter("icon", _icons[tile.icon])


#The tiles that will drop blink red three times during "seconds"
func warn(icon: int, seconds: float) -> void:
	var doomed := _doomed(icon)
	var half := seconds / 6.0
	var tween := create_tween().set_loops(3)
	tween.tween_method(_tint.bind(doomed), 0.0, 1.0, half)
	tween.tween_method(_tint.bind(doomed), 1.0, 0.0, half)


#Every tile without "icon" stops holding the player and falls out of sight
func drop(icon: int) -> void:
	for tile in _doomed(icon):
		tile.dropped = true
		tile.collider.set_deferred("disabled", true)
		var tween := create_tween()
		tween.tween_property(tile.body, "position:y", -TILE_THICKNESS / 2.0 - DROP_DEPTH, DROP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(tile.body.hide)


#A new board: the icons change places and the fallen tiles rise back; they only hold the
#player again once they are in place
func restore(rng: RandomNumberGenerator) -> void:
	shuffle(rng)
	_tint(0.0, _tiles)
	for tile in _tiles:
		if not tile.dropped:
			continue
		tile.dropped = false
		tile.body.position.y = -TILE_THICKNESS / 2.0 - DROP_DEPTH / 2.0
		tile.body.show()
		var tween := create_tween()
		tween.tween_property(tile.body, "position:y", -TILE_THICKNESS / 2.0, RISE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(tile.collider.set_deferred.bind("disabled", false))


func screen_text(text: String, color: Color) -> void:
	_screen_icon.hide()
	_screen_label.text = text
	_screen_label.modulate = color
	_screen_label.show()
	#Long words shrink to fit the screen
	var width := SCREEN_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SCREEN_FONT_SIZE).x * TEXT_PIXEL_SIZE
	_punch(_screen_label, minf(1.0, SCREEN_SIZE.x * 0.86 / maxf(width, 0.01)), 1.3)


#"settle" is the final image of a spin: it lands with a bigger bounce
func screen_icon(index: int, settle: bool) -> void:
	_screen_label.hide()
	var texture := _icons[index]
	_screen_icon.texture = texture
	_screen_icon.pixel_size = SCREEN_SIZE.y * 0.82 / maxf(texture.get_height(), 1.0)
	_screen_icon.show()
	_punch(_screen_icon, 1.0, 1.3 if settle else 1.06)


#A rocket along "row" (0 is the row next to the screen); "direction" +1 flies to the right
func launch_rocket(row: int, direction: float, warning: float, speed: float) -> void:
	var rocket := Rocket.new()
	rocket.direction = direction
	rocket.speed = speed
	rocket.delay = warning
	var z := _row_z(row)
	var half_width := COLUMNS * (TILE_SIZE + TILE_GAP) / 2.0

	rocket.strip_material = StandardMaterial3D.new()
	rocket.strip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rocket.strip_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rocket.strip_material.disable_fog = true
	rocket.strip_material.no_depth_test = true
	rocket.strip_material.albedo_color = Color(ROCKET_WARNING_COLOR, 0.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_width * 2.0 + 3.0, TILE_SIZE * 0.85)
	rocket.strip = MeshInstance3D.new()
	rocket.strip.mesh = plane
	rocket.strip.material_override = rocket.strip_material
	rocket.strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rocket.strip.position = Vector3(0.0, 0.06, z)
	add_child(rocket.strip)

	rocket.node = _build_rocket_model()
	rocket.flame = rocket.node.find_child("Flame", true, false)
	rocket.node.position = Vector3(-direction * (half_width + ROCKET_RUN_OUT), ROCKET_HEIGHT, z)
	rocket.node.rotation.y = 0.0 if direction > 0.0 else PI
	rocket.node.hide()
	add_child(rocket.node)
	_rockets.append(rocket)


#Direction (+1 or -1) of a flying rocket that runs into "at" now, 0 when none; each rocket
#hits only once. A high enough jump goes over it
func rocket_hit(at: Vector3, radius: float) -> float:
	var half_row := (TILE_SIZE + TILE_GAP) / 2.0
	for rocket in _rockets:
		if rocket.hit or rocket.delay > 0.0:
			continue
		#Over it after a jump, or already under the platform
		if at.y > ROCKET_HEIGHT - 0.25 or at.y < -0.5 or absf(at.z - rocket.node.position.z) > half_row:
			continue
		if absf(at.x - rocket.node.position.x) <= ROCKET_LENGTH * ROCKET_SCALE / 2.0 + radius:
			rocket.hit = true
			return rocket.direction
	return 0.0


#The clouds drift sideways and come back from the other side; the cards bob and turn; the
#rockets blink their row and then fly
func _process(delta: float) -> void:
	_decor_time += delta
	_update_rockets(delta)
	for cloud in _clouds:
		cloud.node.position.x += cloud.speed * delta
		if cloud.node.position.x > CLOUD_AREA.end.x:
			cloud.node.position.x -= CLOUD_AREA.size.x
	for index in _cards.size():
		var card := _cards[index]
		card.rotation.y += delta * (0.25 + 0.05 * index)
		card.position.y += sin(_decor_time * 0.9 + index) * delta * 0.35


func _update_rockets(delta: float) -> void:
	var half_width := COLUMNS * (TILE_SIZE + TILE_GAP) / 2.0
	for index in range(_rockets.size() - 1, -1, -1):
		var rocket := _rockets[index]
		#The row keeps blinking until the rocket has crossed the board
		rocket.strip_material.albedo_color.a = 0.3 + 0.4 * absf(sin(_decor_time * 9.0))
		if rocket.delay > 0.0:
			rocket.delay -= delta
			if rocket.delay <= 0.0:
				rocket.node.show()
			continue
		rocket.node.position.x += rocket.direction * rocket.speed * delta
		rocket.flame.scale = Vector3.ONE * (0.85 + 0.3 * absf(sin(_decor_time * 30.0 + index)))
		var past := rocket.node.position.x * rocket.direction
		if past > half_width + 2.0:
			rocket.strip.hide()
		if past > half_width + ROCKET_RUN_OUT:
			rocket.node.queue_free()
			rocket.strip.queue_free()
			_rockets.remove_at(index)


func _row_z(row: int) -> float:
	return (row - (ROWS - 1) / 2.0) * (TILE_SIZE + TILE_GAP)


#White body, coral nose and fins, a cyan window on top and a flickering flame; it points +X
func _build_rocket_model() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.scale = Vector3.ONE * ROCKET_SCALE
	root.add_child(body)
	#Cylinders stand on Y: turned -90 degrees around Z their top points to +X
	var pointing := Vector3(0.0, 0.0, -PI / 2.0)
	_cone(body, 0.32, 0.32, 1.8, Vector3.ZERO, pointing, _material(Palette.PAPER))
	_cone(body, 0.0, 0.32, 0.65, Vector3(1.22, 0.0, 0.0), pointing, _material(Palette.CORAL, 0.3))
	_cone(body, 0.36, 0.26, 0.25, Vector3(-0.98, 0.0, 0.0), pointing, _material(FRAME_COLOR))
	var fin_material := _material(Palette.CORAL, 0.3)
	_box(body, Vector3(0.55, 0.9, 0.07), Vector3(-0.65, 0.0, 0.0), fin_material)
	_box(body, Vector3(0.55, 0.07, 0.9), Vector3(-0.65, 0.0, 0.0), fin_material)
	var window := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	window.mesh = sphere
	window.material_override = _material(CYAN, 0.8)
	window.position = Vector3(0.4, 0.27, 0.0)
	body.add_child(window)
	var flame := Node3D.new()
	flame.name = "Flame"
	flame.position = Vector3(-1.1, 0.0, 0.0)
	body.add_child(flame)
	_cone(flame, 0.26, 0.0, 0.9, Vector3(-0.45, 0.0, 0.0), pointing, _material(AMBER, 2.0))
	_cone(flame, 0.14, 0.0, 0.55, Vector3(-0.28, 0.0, 0.0), pointing, _material(Palette.PAPER, 2.0))
	for child in body.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


func _cone(parent: Node3D, top: float, bottom: float, height: float, at: Vector3, rotation_angles: Vector3,
		material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation = rotation_angles
	parent.add_child(instance)


func _doomed(icon: int) -> Array[Tile]:
	var doomed: Array[Tile] = []
	for tile in _tiles:
		if tile.icon != icon:
			doomed.append(tile)
	return doomed


func _tint(amount: float, tiles: Array[Tile]) -> void:
	var color := Color.WHITE.lerp(WARNING_TINT, amount)
	for tile in tiles:
		tile.top.set_shader_parameter("tint", color)


func _punch(node: Node3D, base: float, from: float) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	node.scale = Vector3.ONE * base * from
	_punch_tween = create_tween()
	_punch_tween.tween_property(node, "scale", Vector3.ONE * base, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	add_child(camera)
	camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)


func _build_tiles() -> void:
	var step := TILE_SIZE + TILE_GAP
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE, TILE_THICKNESS, TILE_SIZE)
	var block_mesh := BoxMesh.new()
	block_mesh.size = shape.size
	var face_mesh := PlaneMesh.new()
	face_mesh.size = Vector2.ONE * TILE_SIZE * 0.94
	var side := _material(SIDE_COLOR)
	for row in ROWS:
		for column in COLUMNS:
			var tile := Tile.new()
			tile.body = StaticBody3D.new()
			tile.body.position = Vector3((column - (COLUMNS - 1) / 2.0) * step, -TILE_THICKNESS / 2.0,
				(row - (ROWS - 1) / 2.0) * step)
			tile.collider = CollisionShape3D.new()
			tile.collider.shape = shape
			tile.body.add_child(tile.collider)
			var block := MeshInstance3D.new()
			block.mesh = block_mesh
			block.material_override = side
			tile.body.add_child(block)
			#The icon on top keeps its colours (only a touch desaturated, see icon_tile.gdshader)
			tile.top = ShaderMaterial.new()
			tile.top.shader = TILE_SHADER
			var face := MeshInstance3D.new()
			face.mesh = face_mesh
			face.material_override = tile.top
			face.position.y = TILE_THICKNESS / 2.0 + 0.01
			face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tile.body.add_child(face)
			add_child(tile.body)
			_tiles.append(tile)


func _build_screen() -> void:
	var half := ROWS * (TILE_SIZE + TILE_GAP) / 2.0
	var screen := Node3D.new()
	screen.position = Vector3(0.0, SCREEN_HEIGHT, -(half + SCREEN_DISTANCE))
	screen.rotation.x = -deg_to_rad(SCREEN_TILT_DEGREES)
	add_child(screen)
	_box(screen, Vector3(SCREEN_SIZE.x + 1.3, SCREEN_SIZE.y + 1.3, 0.3), Vector3(0.0, 0.0, -0.2), _material(MAGENTA, 1.2))
	_box(screen, Vector3(SCREEN_SIZE.x + 0.8, SCREEN_SIZE.y + 0.8, 0.6), Vector3.ZERO, _material(FRAME_COLOR))
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	panel.mesh = quad
	panel.material_override = _material(PANEL_COLOR, 0.4)
	panel.position.z = 0.31
	screen.add_child(panel)

	_screen_icon = Sprite3D.new()
	_screen_icon.position.z = 0.34
	_screen_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_screen_icon.hide()
	screen.add_child(_screen_icon)

	_screen_label = Label3D.new()
	_screen_label.font = SCREEN_FONT
	_screen_label.font_size = SCREEN_FONT_SIZE
	_screen_label.pixel_size = TEXT_PIXEL_SIZE
	_screen_label.outline_size = 36
	_screen_label.outline_modulate = Palette.EDGE
	_screen_label.position.z = 0.36
	screen.add_child(_screen_label)


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)


#Each cloud is a flat cluster of puffs; they start spread over the whole area
func _build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var puff_mesh := SphereMesh.new()
	puff_mesh.radial_segments = 16
	puff_mesh.rings = 8
	var materials: Array[StandardMaterial3D] = []
	for color in CLOUD_COLORS:
		var material := _material(color, 0.35)
		material.roughness = 1.0
		materials.append(material)
	for index in CLOUD_COUNT:
		var cloud := Cloud.new()
		cloud.node = Node3D.new()
		cloud.node.position = Vector3(rng.randf_range(CLOUD_AREA.position.x, CLOUD_AREA.end.x),
			rng.randf_range(CLOUD_DEPTH_RANGE.x, CLOUD_DEPTH_RANGE.y),
			rng.randf_range(CLOUD_AREA.position.y, CLOUD_AREA.end.y))
		cloud.speed = rng.randf_range(CLOUD_SPEED_RANGE.x, CLOUD_SPEED_RANGE.y)
		var size := rng.randf_range(2.0, 4.5)
		var material := materials[index % materials.size()]
		for puff_index in rng.randi_range(4, 7):
			var puff := MeshInstance3D.new()
			puff.mesh = puff_mesh
			puff.material_override = material
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var radius := size * rng.randf_range(0.55, 1.0)
			puff.scale = Vector3(radius * 2.0, radius * 0.9, radius * 1.6)
			puff.position = Vector3(rng.randf_range(-1.6, 1.6) * size, rng.randf_range(-0.2, 0.3) * size,
				rng.randf_range(-0.8, 0.8) * size)
			cloud.node.add_child(puff)
		add_child(cloud.node)
		_clouds.append(cloud)


#Big icon cards around the platform, never between the camera and the board or the screen
func _build_cards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for index in CARD_COUNT:
		var side := -1.0 if index % 2 == 0 else 1.0
		var card := Sprite3D.new()
		card.texture = _icons[index % _icons.size()]
		card.pixel_size = rng.randf_range(2.2, 3.4) / maxf(card.texture.get_height(), 1.0)
		card.modulate = Color(1.0, 1.0, 1.0, 0.85)
		card.double_sided = true
		card.position = Vector3(side * rng.randf_range(16.0, 26.0), rng.randf_range(-5.0, 3.0),
			rng.randf_range(-22.0, 8.0))
		card.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		add_child(card)
		_cards.append(card)


func _build_player_marks() -> void:
	#A flat triangle pointing down that always faces the camera, drawn over everything, with a
	#dark border so it stands out on any tile
	_marker = _billboard_triangle(0.5, Palette.EDGE, 0)
	_marker.add_child(_billboard_triangle(0.38, Palette.GOLD, 1))
	add_child(_marker)

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.65))
	#Solid in the middle, soft only near the edge
	gradient.set_offset(0, 0.45)
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.disable_fog = true
	material.albedo_texture = texture
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * SHADOW_DIAMETER
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	_shadow.material_override = material
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)


#"size" is half its width; "priority" orders the triangles drawn at the same spot
func _billboard_triangle(size: float, color: Color, priority: int) -> MeshInstance3D:
	var vertices := PackedVector3Array([
		Vector3(-size, size * 0.8, 0.0), Vector3(size, size * 0.8, 0.0), Vector3(0.0, -size * 0.95, 0.0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.disable_fog = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = priority
	var triangle := MeshInstance3D.new()
	triangle.mesh = mesh
	triangle.material_override = material
	triangle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return triangle


func _build_sky() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.62, 0.68, 0.98)
	sky_material.sky_horizon_color = Color(0.86, 0.74, 0.95)
	sky_material.ground_bottom_color = Color(0.55, 0.62, 0.95)
	sky_material.ground_horizon_color = Color(0.86, 0.74, 0.95)
	sky_material.ground_curve = 0.06
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	#Linear keeps the icons' colours as they are; filmic would dull them
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	#Depth fog only reaches past the board and the screen: it fades the far clouds into the sky
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.82, 0.76, 0.97)
	environment.fog_density = 0.85
	environment.fog_depth_begin = 32.0
	environment.fog_depth_end = 75.0
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color(1, 0.95, 0.93)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _material(color: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
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
