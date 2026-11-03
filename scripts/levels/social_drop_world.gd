class_name SocialDropWorld
extends Node3D

#The SocialDrop stage: a platform of app icon tiles (6 across, 5 deep) floating in the sky, a giant screen on each side
#where the spin is shown, and a sea of clouds drifting below

const COLUMNS := 6
const ROWS := 5
const TILE_SIZE := 2.5
const TILE_GAP := 0.2
const TILE_THICKNESS := 0.4
const TILE_SHADER := preload("res://assets/ui/shaders/icon_tile.gdshader")
#How far a tile falls before it hides; it comes back from half of it
const DROP_DEPTH := 14.0
const DROP_TIME := 0.9
const RISE_TIME := 0.7
#Free meters between the edge of the platform and each screen, and the size and height of a screen
const SCREEN_DISTANCE := 4.5
const SCREEN_SIZE := Vector2(9.0, 5.0)
const SCREEN_HEIGHT := 4.8
#The screens lean back a little, so they face the players that look up at them
const SCREEN_TILT_DEGREES := 12.0
const SCREEN_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const SCREEN_FONT_SIZE := 220
const TEXT_PIXEL_SIZE := 0.012
const SIDE_COLOR := Color("a48ae8")
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


var _icons: Array[Texture2D] = []
var _tiles: Array[Tile] = []
var _clouds: Array[Cloud] = []
var _cards: Array[Node3D] = []
var _rockets: Array[Rocket] = []
var _decor_time := 0.0
var _screen_labels: Array[Label3D] = []
var _screen_icons: Array[Sprite3D] = []
var _punch_tween: Tween
var _view_yaw := 0.0


func build(icons: Array[Texture2D], rng: RandomNumberGenerator) -> void:
	_icons = icons
	_build_sky()
	_build_tiles()
	_build_screens()
	_build_clouds()
	_build_cards()
	shuffle(rng)


#Four free places along the middle row, one per player
func spawn_points() -> Array[Vector3]:
	var half_step := (TILE_SIZE + TILE_GAP) / 2.0
	var points: Array[Vector3] = []
	for index in [-3, -1, 1, 3]:
		points.append(Vector3(index * half_step, 0.05, 0.0))
	return points


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


#The icons of the tiles turn to the way the camera looks, so they always read upright
func set_view_yaw(yaw: float) -> void:
	if absf(yaw - _view_yaw) < 0.02:
		return
	_view_yaw = yaw
	for tile in _tiles:
		tile.top.set_shader_parameter("turn", yaw)


func screen_text(text: String, color: Color) -> void:
	var width := SCREEN_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SCREEN_FONT_SIZE).x * TEXT_PIXEL_SIZE
	#Long words shrink to fit the screen
	var fit := minf(1.0, SCREEN_SIZE.x * 0.86 / maxf(width, 0.01))
	for index in _screen_labels.size():
		_screen_icons[index].hide()
		_screen_labels[index].text = text
		_screen_labels[index].modulate = color
		_screen_labels[index].show()
	_punch(_screen_labels, fit, 1.3)


#"settle" is the final image of a spin: it lands with a bigger bounce
func screen_icon(index: int, settle: bool) -> void:
	var texture := _icons[index]
	for screen_index in _screen_icons.size():
		_screen_labels[screen_index].hide()
		_screen_icons[screen_index].texture = texture
		_screen_icons[screen_index].pixel_size = SCREEN_SIZE.y * 0.8 / maxf(texture.get_height(), 1.0)
		_screen_icons[screen_index].show()
	_punch(_screen_icons, 1.0, 1.3 if settle else 1.06)


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


func _punch(nodes: Array, base: float, from: float) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = create_tween().set_parallel(true)
	for node: Node3D in nodes:
		node.scale = Vector3.ONE * base * from
		_punch_tween.tween_property(node, "scale", Vector3.ONE * base, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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


#A screen on each side of the platform, facing the middle: wherever the camera turns there is one to see
func _build_screens() -> void:
	var half_columns := COLUMNS * (TILE_SIZE + TILE_GAP) / 2.0
	var half_rows := ROWS * (TILE_SIZE + TILE_GAP) / 2.0
	for entry in [
		[Vector3(0.0, SCREEN_HEIGHT, -(half_rows + SCREEN_DISTANCE)), 0.0],
		[Vector3(0.0, SCREEN_HEIGHT, half_rows + SCREEN_DISTANCE), PI],
		[Vector3(-(half_columns + SCREEN_DISTANCE), SCREEN_HEIGHT, 0.0), PI / 2.0],
		[Vector3(half_columns + SCREEN_DISTANCE, SCREEN_HEIGHT, 0.0), -PI / 2.0],
	]:
		_build_screen(entry[0], entry[1])


func _build_screen(at: Vector3, yaw: float) -> void:
	var mount := Node3D.new()
	mount.position = at
	mount.rotation.y = yaw
	add_child(mount)
	var screen := Node3D.new()
	screen.rotation.x = -deg_to_rad(SCREEN_TILT_DEGREES)
	mount.add_child(screen)
	_box(screen, Vector3(SCREEN_SIZE.x + 1.2, SCREEN_SIZE.y + 1.2, 0.3), Vector3(0.0, 0.0, -0.2), _material(MAGENTA, 1.2))
	_box(screen, Vector3(SCREEN_SIZE.x + 0.7, SCREEN_SIZE.y + 0.7, 0.6), Vector3.ZERO, _material(FRAME_COLOR))
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	panel.mesh = quad
	panel.material_override = _material(PANEL_COLOR, 0.4)
	panel.position.z = 0.31
	screen.add_child(panel)
	#A post that holds it, so it does not float
	_box(mount, Vector3(0.9, SCREEN_HEIGHT + 3.0, 0.9), Vector3(0.0, -(SCREEN_HEIGHT + 3.0) / 2.0 + 0.2, -0.6), _material(FRAME_COLOR))

	var icon := Sprite3D.new()
	icon.position.z = 0.34
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.hide()
	screen.add_child(icon)
	_screen_icons.append(icon)

	var label := Label3D.new()
	label.font = SCREEN_FONT
	label.font_size = SCREEN_FONT_SIZE
	label.pixel_size = TEXT_PIXEL_SIZE
	label.outline_size = 36
	label.outline_modulate = Palette.EDGE
	label.position.z = 0.36
	screen.add_child(label)
	_screen_labels.append(label)


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
