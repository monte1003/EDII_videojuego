class_name TrendZones
extends Node3D

#Builds and moves what the La Plaza zones add on the ground

const GLASS_COLOR := Color(0.7, 0.92, 1.0, 0.3)
const PAD_COLOR := Color("7ae6ff")
#Splash colour of a meme sea fall
const WATER_COLOR := Color("4fa8ff")
const ISLET_COLORS := {&"sink": Color("ff8f6b"), &"slide": Color("ffd166"), &"turn": Color("5fdcc0")}
const SHUT_COLOR := Color("ff4d6d")
const OPEN_COLOR := Color("4cf2b0")
const WARN_COLOR := Color("ffd23f")
const LIKE_COLOR := Color("ff5fa2")
#Height of a falling like
const LIKE_HEIGHT := 1.9
const LIKE_POOL := 10
const ISLET_THICKNESS := 0.6
#Meme sea: our memes on the platforms, wandering light on the water and foam rings
const MEMES: Array[Texture2D] = [preload("res://assets/textures/memes/meme_01.jpg"), preload("res://assets/textures/memes/meme_02.jpg"),
	preload("res://assets/textures/memes/meme_03.jpg"), preload("res://assets/textures/memes/meme_04.jpg"),
	preload("res://assets/textures/memes/meme_05.jpg"), preload("res://assets/textures/memes/meme_06.jpg"),
	preload("res://assets/textures/memes/meme_07.jpg")]
const PHOTO_SHADER: Shader = preload("res://assets/shaders/meme_photo.gdshader")
const WATER_SHADER: Shader = preload("res://assets/shaders/meme_water.gdshader")
#Story ring colours around the round platform memes
const STORY_COLORS: Array[Color] = [Color("ff7a59"), Color("ff7fb2")]
const BUBBLE_SHADER: Shader = preload("res://assets/shaders/bubble.gdshader")
const FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
#Arch board height and width; bubbles floating around the plaza screen
const GATE_HEIGHT := 4.2
const GATE_SPAN := 8.5
const PATH_WIDTH := 6.0
const HUB_BUBBLES := 7
const BEAM_LENGTH := 34.0
const BEAM_RADIUS := 7.0

var layout: TrendLayout
var obstacles: TrendObstacles

var _islets: Array[AnimatableBody3D] = []
var _photo_paint: Dictionary = {}
var _islet_paint: Array[StandardMaterial3D] = []
var _screens: Array[AnimatableBody3D] = []
var _screen_shapes: Array[CollisionShape3D] = []
var _screen_paint: Array[StandardMaterial3D] = []
var _strip_paint: Array[StandardMaterial3D] = []
var _likes: Array[Dictionary] = []
var _beams: Array[MeshInstance3D] = []
var _terrain: CandyTerrain
var _floaters: Array[Dictionary] = []


func build(plaza: TrendLayout, logic: TrendObstacles) -> void:
	layout = plaza
	obstacles = logic
	_terrain = CandyTerrain.new(self)
	_build_hub()
	_build_carpets()
	_build_gates()
	_build_decor()
	_terrain.commit()
	_build_roller()
	_build_gravity()
	_build_islands()
	_build_maze()
	_build_likes()
	for zone in TrendLayout.ZONE_COUNT:
		var beam := PartyKit.beam(layout.color_of_zone(zone).lerp(Color.WHITE, 0.2), BEAM_LENGTH, BEAM_RADIUS, 0.0)
		beam.position = layout.zone_center(zone) + Vector3(0.0, BEAM_LENGTH / 2.0, 0.0)
		beam.hide()
		add_child(beam)
		_beams.append(beam)
	update(0.0, -1, -1, 0.0)


#Moves every piece to "time"; "active" zone, "next" announced zone and "notice" 1 to 0
func update(time: float, active: int, next: int, notice: float) -> void:
	for index in _islets.size():
		var place := obstacles.islet_transform(index, time)
		if obstacles.is_shaking(index):
			place.origin += Vector3(sin(time * 47.0), 0.0, cos(time * 53.0)) * 0.05
		_islets[index].global_transform = place
		var islet: Dictionary = layout.islets[index]
		var base: Color = ISLET_COLORS[islet["kind"]]
		_islet_paint[index].albedo_color = base.lerp(WARN_COLOR, 0.6 * absf(sin(time * 14.0))) if obstacles.is_shaking(index) else base
	for index in _screens.size():
		var group := int(layout.screens[index]["group"])
		#The body sinks fully when the screen stops blocking; collision off while down
		var rise := obstacles.screen_rise(group, time)
		var solid := clampf((rise - TrendObstacles.SCREEN_BLOCKS) / (1.0 - TrendObstacles.SCREEN_BLOCKS), 0.0, 1.0)
		_screen_shapes[index].disabled = solid <= 0.0
		var top := lerpf(-0.05, TrendLayout.SCREEN_HEIGHT, solid)
		var from: Vector3 = layout.screens[index]["from"]
		var to: Vector3 = layout.screens[index]["to"]
		var middle := (from + to) / 2.0
		_screens[index].global_position = Vector3(middle.x, top - TrendLayout.SCREEN_HEIGHT / 2.0, middle.z)
	for group in 2:
		var light := obstacles.screen_light(group, time)
		var blink := absf(sin(time * 9.0))
		var wall := SHUT_COLOR if light == TrendObstacles.Light.SHUT else WARN_COLOR.lerp(SHUT_COLOR, 0.5 * blink)
		var strip := OPEN_COLOR if light == TrendObstacles.Light.OPEN else WARN_COLOR
		_screen_paint[group].albedo_color = wall
		_screen_paint[group].emission = wall
		_strip_paint[group].albedo_color = strip
		_strip_paint[group].emission = strip
		_strip_paint[group].emission_energy_multiplier = 1.2 if light == TrendObstacles.Light.OPEN else 0.4 + 1.2 * blink
	_place_likes(time)
	for zone in _beams.size():
		_beams[zone].visible = zone == active or zone == next
		var beam := _beams[zone].material_override as ShaderMaterial
		if zone == next:
			beam.set_shader_parameter("strength", 0.3 + 0.5 * absf(sin(time * 7.0)) * maxf(notice, 0.3))
		elif zone == active:
			beam.set_shader_parameter("strength", 0.45)


#Plaza heart: candy ring, a glowing petal per zone and drifting bubbles
func _build_hub() -> void:
	_terrain.rail(_ring_line(Vector3.ZERO, 8.4, 0.08), Color("ff8fc7"), true)
	for zone in TrendLayout.ZONE_COUNT:
		var heading := atan2(layout.zone_center(zone).z, layout.zone_center(zone).x)
		var petal := PackedVector2Array([Vector2(cos(heading), sin(heading)) * 8.9])
		for step in 7:
			var angle := heading + deg_to_rad(lerpf(-13.0, 13.0, step / 6.0))
			petal.append(Vector2(cos(angle), sin(angle)) * 11.2)
		_terrain.inlay(petal, 0.018, layout.color_of_zone(zone).lightened(0.25), true)
	for index in HUB_BUBBLES:
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 24
		ball.rings = 12
		var shell := ShaderMaterial.new()
		shell.shader = BUBBLE_SHADER
		shell.set_shader_parameter("tint", PartyKit.PALETTE[index % PartyKit.PALETTE.size()].lightened(0.35))
		shell.set_shader_parameter("glow", 1.2)
		var bubble := MeshInstance3D.new()
		bubble.mesh = ball
		bubble.material_override = shell
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bubble)
		_floaters.append({"node": bubble, "angle": TAU * index / HUB_BUBBLES, "radius": 6.5 + 1.6 * (index % 3), "height": 5.0 + 1.2 * (index % 4),
			"size": 0.7 + 0.25 * (index % 3)})


#Zone carpet with a rail open at the mouth and a path from the plaza
func _build_carpets() -> void:
	for zone in TrendLayout.ZONE_COUNT:
		var color := layout.color_of_zone(zone)
		var outline := layout.zone_outline(zone)
		_terrain.inlay(outline, 0.024, color.lerp(Color.WHITE, 0.55))
		var gate := layout.position_of(layout.zone_entry(zone))
		var line := PackedVector3Array()
		var points := outline.size()
		var start := 0
		var nearest := INF
		for index in points:
			var distance := outline[index].distance_to(Vector2(gate.x, gate.z))
			if distance < nearest:
				nearest = distance
				start = index
		#Rail from just past the mouth to just before it
		for step in points:
			var corner := outline[(start + step) % points]
			if corner.distance_to(Vector2(gate.x, gate.z)) < GATE_SPAN / 2.0 + 0.6:
				continue
			line.append(Vector3(corner.x, 0.22, corner.y))
		if line.size() > 2:
			_terrain.rail(line, color, true)
		var from := Vector2(0.0, 0.0) + (Vector2(gate.x, gate.z)).normalized() * (TrendLayout.HUB_RADIUS - 0.5)
		var to := Vector2(gate.x, gate.z)
		var way := (to - from).normalized()
		var side := Vector2(-way.y, way.x) * PATH_WIDTH / 2.0
		if from.distance_to(to) > 1.0:
			_terrain.inlay(PackedVector2Array([from - side, from + side, to + side, to - side]), 0.03, color.lerp(Color.WHITE, 0.3))


#Candy arch with the zone name facing the plaza
func _build_gates() -> void:
	for zone in TrendLayout.ZONE_COUNT:
		var gate := layout.position_of(layout.zone_entry(zone))
		var toward := Vector3(gate.x, 0.0, gate.z).normalized()
		var arch := SignBoard.arch(TrendLayout.LABELS[zone], layout.color_of_zone(zone).darkened(0.1), GATE_SPAN, GATE_HEIGHT, 1.45)
		arch.position = Vector3(gate.x, 0.0, gate.z)
		arch.rotation.y = atan2(toward.x, toward.z)
		add_child(arch)


#Floor between zones like a flower: cream ring, petals and a striped rim band
func _build_decor() -> void:
	_band(TrendLayout.HUB_RADIUS + 0.4, TrendLayout.HUB_RADIUS + 2.6, Color("fff4e0"), Color("fff4e0"), 0.008)
	_band(TrendLayout.BASE_RADIUS - 3.4, TrendLayout.BASE_RADIUS - 0.6, Color("c7b5ff"), Color("f3ecff"), 0.008)
	var toys: Array[StringName] = [&"heart", &"camera", &"speaker", &"sticker", &"like_hand"]
	var balloons := BalloonField.new()
	add_child(balloons)
	for zone in TrendLayout.ZONE_COUNT:
		var next := (zone + 1) % TrendLayout.ZONE_COUNT
		var heading := deg_to_rad(TrendLayout.ANGLES[zone] + 36.0)
		var out := Vector3(cos(heading), 0.0, sin(heading))
		var across := Vector3(-out.z, 0.0, out.x)
		var tone := layout.color_of_zone(zone).lerp(layout.color_of_zone(next), 0.5)
		#Petal shapes along the gap between zones
		for layer: Array in [[1.0, 0.72, 0.014], [0.62, 0.5, 0.019]]:
			var petal := PackedVector2Array()
			var length := (TrendLayout.BASE_RADIUS - 4.0 - TrendLayout.HUB_RADIUS - 3.0) * float(layer[0])
			var middle := TrendLayout.HUB_RADIUS + 3.0 + (TrendLayout.BASE_RADIUS - 4.0 - TrendLayout.HUB_RADIUS - 3.0) / 2.0
			for step in 40:
				var angle := TAU * step / 40.0
				var spot := out * (middle + cos(angle) * length / 2.0) + across * sin(angle) * 4.6 * float(layer[0]) * (0.75 + 0.25 * cos(angle))
				petal.append(Vector2(spot.x, spot.z))
			_terrain.inlay(petal, float(layer[2]), tone.lerp(Color.WHITE, float(layer[1])))
		var spot := out * (TrendLayout.BASE_RADIUS - 8.5)
		var pedestal := PartyKit.pillar(1.8, 1.4, tone, PartyKit.WHITE)
		pedestal.position = spot
		add_child(pedestal)
		var post := StaticBody3D.new()
		var round_shape := CylinderShape3D.new()
		round_shape.radius = 1.45
		round_shape.height = 1.8
		var holder := CollisionShape3D.new()
		holder.shape = round_shape
		post.add_child(holder)
		post.position = spot + Vector3(0.0, 0.9, 0.0)
		add_child(post)
		var toy := PropKit.make_tall(toys[zone], 4.2, Color.WHITE, false)
		toy.position = spot + Vector3(0.0, 2.4, 0.0)
		add_child(toy)
		_floaters.append({"node": toy, "spin": 0.4 + 0.1 * zone, "base": spot + Vector3(0.0, 2.4, 0.0)})
		for side: float in [-1.0, 1.0]:
			_lollipop(spot + across * side * 6.0 + out * 1.0, PartyKit.PALETTE[(zone * 2 + int(side + 1.0)) % PartyKit.PALETTE.size()])
		for index in 7:
			var tie := spot - out * 4.0 + across * (index - 3) * 0.5
			balloons.add(tie, 3.5 + 0.4 * (index % 3), 1.0, PartyKit.PALETTE[(index + zone) % PartyKit.PALETTE.size()], index * 0.9 + zone)
	balloons.commit()


#Two-colour striped floor ring
func _band(inner: float, outer: float, a: Color, b: Color, height: float) -> void:
	var steps := 72
	for step in steps:
		var from := TAU * step / steps
		var to := TAU * (step + 1) / steps
		var quad := PackedVector2Array([Vector2(cos(from), sin(from)) * inner, Vector2(cos(from), sin(from)) * outer,
			Vector2(cos(to), sin(to)) * outer, Vector2(cos(to), sin(to)) * inner])
		_terrain.inlay(quad, height, a if step % 2 == 0 else b)


#Giant striped lollipop
func _lollipop(at: Vector3, color: Color) -> void:
	var stick := PartyKit.pillar(4.6, 0.14, PartyKit.WHITE, color)
	stick.position = at
	add_child(stick)
	var sweet := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.35
	disc.bottom_radius = 1.35
	disc.height = 0.36
	disc.radial_segments = 28
	disc.rings = 1
	sweet.mesh = disc
	sweet.material_override = PartyKit.candy(PartyKit.WHITE, color, 10.0, 6.0)
	sweet.position = at + Vector3(0.0, 5.8, 0.0)
	sweet.rotation.x = PI / 2.0
	sweet.rotation.y = atan2(at.x, at.z)
	add_child(sweet)


func _process(_delta: float) -> void:
	var clock := Time.get_ticks_msec() / 1000.0
	for floater in _floaters:
		if floater.has("spin"):
			var toy: Node3D = floater["node"]
			toy.rotation.y = clock * float(floater["spin"])
			toy.position = (floater["base"] as Vector3) + Vector3(0.0, 0.25 * sin(clock * 1.3 + float(floater["spin"]) * 9.0), 0.0)
			continue
		var angle: float = float(floater["angle"]) + clock * 0.18
		var radius: float = floater["radius"]
		var node: MeshInstance3D = floater["node"]
		node.position = Vector3(cos(angle) * radius, float(floater["height"]) + 0.5 * sin(clock * 0.9 + float(floater["angle"]) * 3.0), sin(angle) * radius)
		node.scale = Vector3.ONE * float(floater["size"]) * (1.0 + 0.04 * sin(clock * 2.3 + radius))


#Striped warning ring at the roller reach
func _build_roller() -> void:
	var zone := TrendLayout.Zone.ROLLER
	var centre := layout.zone_center(zone)
	var rim := CandyTerrain.new(self)
	rim.rail(_ring_line(centre, TrendLayout.ROLLER_ARM + 0.9, 0.08), Color("ff6f7d"), true)
	rim.inlay(_ring_band_outline(centre, 2.2), 0.034, layout.color_of_zone(zone).lightened(0.4))
	rim.commit()


#Gravity glass on its own collision layer with pads below and on the floor
func _build_gravity() -> void:
	var zone := TrendLayout.Zone.GRAVITY
	var centre := layout.zone_center(zone)
	var glass := StaticBody3D.new()
	glass.collision_layer = TrendLayout.GLASS_BIT
	glass.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = TrendLayout.GRAVITY_RADIUS
	shape.height = TrendLayout.GLASS_THICKNESS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	glass.add_child(collider)
	glass.position = centre + Vector3(0.0, TrendLayout.GRAVITY_CEILING + TrendLayout.GLASS_THICKNESS / 2.0, 0.0)
	add_child(glass)
	var pane := StandardMaterial3D.new()
	pane.albedo_color = GLASS_COLOR
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.cull_mode = BaseMaterial3D.CULL_DISABLED
	pane.roughness = 0.1
	_disc(glass, TrendLayout.GRAVITY_RADIUS, TrendLayout.GLASS_THICKNESS, GLASS_COLOR, Vector3.ZERO, pane)
	#Candy columns, edge bulbs and a glowing floor ring
	var frame := CandyTerrain.new(self)
	var top := TrendLayout.GRAVITY_CEILING + TrendLayout.GLASS_THICKNESS + 0.1
	frame.rail(_ring_line(centre, TrendLayout.GRAVITY_RADIUS, top), Color("7ae6ff"), true)
	frame.rail(_ring_line(centre, TrendLayout.GRAVITY_RADIUS + 0.2, 0.08), Color("7ae6ff"), false)
	frame.commit()
	var yaw := layout.zone_yaw(zone)
	for step in 6:
		var angle := yaw + PI / 6.0 + TAU * step / 6.0
		var foot := centre + Vector3(cos(angle), 0.0, sin(angle)) * (TrendLayout.GRAVITY_RADIUS + 0.45)
		var column := PartyKit.pillar(top, 0.3, layout.color_of_zone(zone), PartyKit.WHITE)
		column.position = foot
		add_child(column)
		var post := StaticBody3D.new()
		var round_shape := CylinderShape3D.new()
		round_shape.radius = 0.32
		round_shape.height = top
		var holder := CollisionShape3D.new()
		holder.shape = round_shape
		post.add_child(holder)
		post.position = foot + Vector3(0.0, top / 2.0, 0.0)
		add_child(post)
	var glow := PartyKit.paint(PAD_COLOR, 1.2, 0.3)
	for pad in layout.floor_pads:
		_disc(self, TrendLayout.GRAVITY_PAD, 0.08, PAD_COLOR, pad + Vector3(0.0, 0.04, 0.0), glow)
	for pad in layout.ceiling_pads:
		_disc(self, TrendLayout.GRAVITY_PAD, 0.08, PAD_COLOR, pad - Vector3(0.0, 0.04, 0.0), glow)


#Pond and platforms that carry whoever stands on them
func _build_islands() -> void:
	var zone := TrendLayout.Zone.ISLANDS
	var water := MeshInstance3D.new()
	var sheet := BoxMesh.new()
	sheet.size = Vector3(TrendLayout.POND_HALF.y * 2.0, 0.06, TrendLayout.POND_HALF.x * 2.0)
	water.mesh = sheet
	var waves := ShaderMaterial.new()
	waves.shader = WATER_SHADER
	water.material_override = waves
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = layout.zone_center(zone) + Vector3(0.0, 0.03, 0.0)
	water.rotation.y = layout.zone_yaw(zone)
	add_child(water)
	for islet in layout.islets:
		var body := AnimatableBody3D.new()
		body.sync_to_physics = true
		var size: Vector2 = islet["size"]
		var shape: Shape3D
		var mesh: Mesh
		if islet["round"]:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = size.x
			cylinder.height = ISLET_THICKNESS
			shape = cylinder
			var drum := CylinderMesh.new()
			drum.top_radius = size.x
			drum.bottom_radius = size.x
			drum.height = ISLET_THICKNESS
			drum.radial_segments = 24
			drum.rings = 1
			mesh = drum
		else:
			var box := BoxShape3D.new()
			box.size = Vector3(size.x, ISLET_THICKNESS, size.y)
			shape = box
			var block := BoxMesh.new()
			block.size = box.size
			mesh = block
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = -ISLET_THICKNESS / 2.0
		body.add_child(collider)
		var paint := PartyKit.paint(ISLET_COLORS[islet["kind"]], 0.0, 0.5)
		var view := MeshInstance3D.new()
		view.mesh = mesh
		view.material_override = paint
		view.position.y = -ISLET_THICKNESS / 2.0
		body.add_child(view)
		#White candy edge on top
		var edge := MeshInstance3D.new()
		if islet["round"]:
			var torus := TorusMesh.new()
			torus.inner_radius = size.x - 0.16
			torus.outer_radius = size.x + 0.04
			torus.rings = 28
			torus.ring_segments = 6
			edge.mesh = torus
		else:
			var lip := BoxMesh.new()
			lip.size = Vector3(size.x + 0.08, 0.1, size.y + 0.08)
			edge.mesh = lip
		edge.material_override = PartyKit.paint(PartyKit.WHITE, 0.15, 0.4)
		edge.position.y = 0.02
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(edge)
		_dress_islet(body, islet, _islets.size())
		add_child(body)
		_islets.append(body)
		_islet_paint.append(paint)


#Feed tile look without collision: a small meme in the middle, story ring on round ones
func _dress_islet(body: Node3D, islet: Dictionary, index: int) -> void:
	var size: Vector2 = islet["size"]
	var color: Color = ISLET_COLORS[islet["kind"]]
	var round_top: bool = islet["round"]
	if round_top:
		var face := CylinderMesh.new()
		face.top_radius = size.x - 0.16
		face.bottom_radius = size.x - 0.16
		face.height = 0.03
		face.radial_segments = 24
		face.rings = 1
		var disc := MeshInstance3D.new()
		disc.mesh = face
		disc.material_override = PartyKit.paint(PartyKit.WHITE, 0.0, 0.4)
		disc.position.y = 0.015
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(disc)
	var side := size.x * 0.88 if round_top else minf(size.x, size.y) * 0.55
	if round_top:
		var ring := TorusMesh.new()
		ring.inner_radius = side / 2.0 - 0.02
		ring.outer_radius = side / 2.0 + 0.1
		ring.rings = 32
		ring.ring_segments = 6
		var story := MeshInstance3D.new()
		story.mesh = ring
		story.material_override = PartyKit.candy(STORY_COLORS[0], STORY_COLORS[1], 10.0, 0.0, 0.3)
		story.scale.y = 0.4
		story.position.y = 0.03
		story.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(story)
	var photo := _photo_quad(MEMES[index % MEMES.size()], Vector2(side, side), side / 2.0 if round_top else side * 0.1)
	#Upright for whoever comes from the dock
	photo.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
	photo.position.y = 0.04 if round_top else 0.08
	body.add_child(photo)
	#Column from under the platform to the water
	var reach := minf(size.x, size.y) * 0.5 if not round_top else size.x
	var stem := CylinderMesh.new()
	stem.top_radius = reach * 0.5
	stem.bottom_radius = reach * 0.4
	stem.height = TrendLayout.ISLE_TOP - ISLET_THICKNESS + 0.1
	stem.radial_segments = 20
	stem.rings = 1
	var column := MeshInstance3D.new()
	column.mesh = stem
	column.material_override = PartyKit.candy(color, PartyKit.WHITE, 6.0, 0.0, 0.1)
	column.position.y = -ISLET_THICKNESS - stem.height / 2.0 + 0.05
	body.add_child(column)
	var foam := TorusMesh.new()
	foam.inner_radius = stem.bottom_radius + 0.05
	foam.outer_radius = stem.bottom_radius + 0.3
	foam.rings = 24
	foam.ring_segments = 6
	var ring := MeshInstance3D.new()
	ring.mesh = foam
	ring.material_override = PartyKit.paint(PartyKit.WHITE, 0.3, 0.6)
	ring.scale.y = 0.35
	ring.position.y = -TrendLayout.ISLE_TOP + 0.08
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(ring)


#Photo quad with rounded corners, or a plain card
func _photo_quad(texture: Texture2D, size: Vector2, radius: float) -> MeshInstance3D:
	var key := "%s_%s_%s" % [texture.resource_path, size, radius]
	if not _photo_paint.has(key):
		var paint := ShaderMaterial.new()
		paint.shader = PHOTO_SHADER
		paint.set_shader_parameter("picture", texture)
		paint.set_shader_parameter("extent", size)
		paint.set_shader_parameter("radius", radius)
		_photo_paint[key] = paint
	return _quad(_photo_paint[key], size)


func _quad(material: Material, size: Vector2) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var quad := MeshInstance3D.new()
	quad.mesh = mesh
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return quad


#Maze screens rising and sinking, with a floor strip green while open
func _build_maze() -> void:
	for _group in 2:
		_screen_paint.append(PartyKit.paint(SHUT_COLOR, 0.5, 0.4))
		_strip_paint.append(PartyKit.paint(OPEN_COLOR, 1.2, 0.4))
	for screen in layout.screens:
		var from: Vector3 = screen["from"]
		var to: Vector3 = screen["to"]
		var length := from.distance_to(to) - TrendLayout.SCREEN_THICKNESS
		var basis := Basis(Vector3.UP, atan2(to.x - from.x, to.z - from.z))
		var body := AnimatableBody3D.new()
		body.sync_to_physics = true
		body.basis = basis
		var shape := BoxShape3D.new()
		shape.size = Vector3(TrendLayout.SCREEN_THICKNESS * 0.9, TrendLayout.SCREEN_HEIGHT, length)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		var panel := BoxMesh.new()
		panel.size = shape.size
		var view := MeshInstance3D.new()
		view.mesh = panel
		view.material_override = _screen_paint[int(screen["group"])]
		body.add_child(view)
		add_child(body)
		_screens.append(body)
		_screen_shapes.append(collider)
		var strip := MeshInstance3D.new()
		var line := BoxMesh.new()
		line.size = Vector3(TrendLayout.SCREEN_THICKNESS, 0.04, length)
		strip.mesh = line
		strip.material_override = _strip_paint[int(screen["group"])]
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.basis = basis
		strip.position = (from + to) / 2.0 + Vector3(0.0, 0.035, 0.0)
		add_child(strip)


#A few reused likes are enough
func _build_likes() -> void:
	var mark := PartyKit.paint(LIKE_COLOR, 1.4, 0.4)
	var ring := TorusMesh.new()
	ring.inner_radius = TrendObstacles.LIKE_REACH - 0.18
	ring.outer_radius = TrendObstacles.LIKE_REACH
	ring.rings = 24
	ring.ring_segments = 6
	for index in LIKE_POOL:
		var body := PropKit.make_tall(&"like_hand", LIKE_HEIGHT, Color.WHITE, false)
		body.hide()
		add_child(body)
		var target := MeshInstance3D.new()
		target.mesh = ring
		target.material_override = mark
		target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		target.hide()
		add_child(target)
		_likes.append({"body": body, "mark": target})


#Ring while coming, falls at the end, squashes on landing
func _place_likes(time: float) -> void:
	var falling := obstacles.likes(time)
	for index in _likes.size():
		var body: Node3D = _likes[index]["body"]
		var mark: MeshInstance3D = _likes[index]["mark"]
		if index >= falling.size():
			body.hide()
			mark.hide()
			continue
		var like := falling[index]
		var at: Vector3 = like["at"]
		var left: float = like["left"]
		mark.visible = left > 0.0
		mark.position = at + Vector3(0.0, 0.05, 0.0)
		mark.scale = Vector3.ONE * lerpf(0.4, 1.0, clampf(1.0 - left / TrendObstacles.LIKE_WARN, 0.0, 1.0))
		body.visible = left < TrendObstacles.LIKE_FALL
		#Spins while falling and lands facing the tower middle
		body.rotation.y = atan2(layout.tower_center().x - at.x, layout.tower_center().z - at.z) + maxf(left, 0.0) * (4.0 if index % 2 == 0 else -4.0)
		if left > 0.0:
			var share := left / TrendObstacles.LIKE_FALL
			body.position = at + Vector3(0.0, TrendObstacles.LIKE_DROP * share * share, 0.0)
			body.scale = Vector3.ONE
		else:
			var gone := clampf(-left / TrendObstacles.LIKE_GONE, 0.0, 1.0)
			body.position = at
			body.scale = Vector3(1.0 + 0.4 * gone, 1.0 - 0.6 * gone, 1.0 + 0.4 * gone) * (1.0 - gone * 0.8)


#Closed ring of points for a candy rail
func _ring_line(centre: Vector3, radius: float, height: float) -> PackedVector3Array:
	var line := PackedVector3Array()
	for step in 65:
		var angle := TAU * step / 64.0
		line.append(centre + Vector3(cos(angle) * radius, height, sin(angle) * radius))
	return line


func _ring_band_outline(centre: Vector3, radius: float) -> PackedVector2Array:
	return CandyTerrain.circle(Vector2(centre.x, centre.z), radius, 40)


func _disc(parent: Node3D, radius: float, height: float, color: Color, at: Vector3, material: Material = null) -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = height
	disc.radial_segments = 40 if radius > 1.5 else 20
	disc.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = disc
	view.material_override = material if material != null else PartyKit.paint(color, 0.0, 0.6)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.position = at
	parent.add_child(view)
	return view
