class_name TrendZones
extends Node3D

#Builds and moves what the zones of La Plaza add to the ground: the carpet of each zone with its rail, the path to it from the plaza and
#its arch with its name, the decoration between the zones, the glass of airplane mode and its pads, the platforms and the pond of the sea
#of memes, the screens of the locked screen with their lights, the likes that rain on the tower and a beam of light over the zone that
#is played and the one that comes next. The platforms and the screens are bodies that carry and stop the players; where they are comes
#from TrendObstacles

const GLASS_COLOR := Color(0.7, 0.92, 1.0, 0.3)
const PAD_COLOR := Color("7ae6ff")
const WATER_COLOR := Color("4fa8ff")
const ISLET_COLORS := {&"sink": Color("ff8f6b"), &"slide": Color("ffd166"), &"turn": Color("5fdcc0")}
const SHUT_COLOR := Color("ff4d6d")
const OPEN_COLOR := Color("4cf2b0")
const WARN_COLOR := Color("ffd23f")
const LIKE_COLOR := Color("ff5fa2")
const LIKE_RADIUS := 0.75
const LIKE_POOL := 10
const ISLET_THICKNESS := 0.6
#The platforms of the sea of memes are app tiles: an icon of the social networks on top and a candy-striped column down to the water
const ISLET_ICONS: Array[Texture2D] = [preload("res://assets/social_icons/me_gusta.png"), preload("res://assets/social_icons/chat.png"),
	preload("res://assets/social_icons/video.png"), preload("res://assets/social_icons/foto.png"),
	preload("res://assets/social_icons/historia.png"), preload("res://assets/social_icons/directo.png")]
#How tall the beam over a zone is and how wide it opens
const BUBBLE_SHADER: Shader = preload("res://assets/shaders/bubble.gdshader")
const FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
#The arch at the mouth of each zone: how high its board hangs and how wide it is; the big bubbles that float around the screen of the plaza
const GATE_HEIGHT := 4.2
const GATE_SPAN := 8.5
const PATH_WIDTH := 6.0
const HUB_BUBBLES := 7
const BEAM_LENGTH := 34.0
const BEAM_RADIUS := 7.0

var layout: TrendLayout
var obstacles: TrendObstacles

var _islets: Array[AnimatableBody3D] = []
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


#Puts every moving piece where it is at "time"; "active" is the zone being played, "next" the one announced (or -1) and "notice" goes
#from 1 to 0 while it is announced
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
		#The body goes all the way down when the screen stops blocking (the same height the rules use), so nothing invisible is left
		#in the way; its collision is off while it is down and on again as soon as it starts to come up
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


#The heart of the plaza: a candy ring on its floor around the screen, one glowing petal of the colour of each zone pointing at its
#bridge, and big soap bubbles that drift around the screen
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


#The carpet of each zone: its floor drawn lighter in its colour, with a candy rail around it that leaves its mouth open, and a path in its
#colour from the plaza to the mouth
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
		#The rail goes once around the carpet from just past the mouth to just before it
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


#A candy arch over the mouth of each zone, its board with the name of the zone facing the plaza
func _build_gates() -> void:
	for zone in TrendLayout.ZONE_COUNT:
		var gate := layout.position_of(layout.zone_entry(zone))
		var toward := Vector3(gate.x, 0.0, gate.z).normalized()
		var arch := SignBoard.arch(TrendLayout.LABELS[zone], layout.color_of_zone(zone).darkened(0.1), GATE_SPAN, GATE_HEIGHT, 1.45)
		arch.position = Vector3(gate.x, 0.0, gate.z)
		arch.rotation.y = atan2(toward.x, toward.z)
		add_child(arch)


#The floor between the zones is drawn like a flower seen from above: a ring of cream around the plaza, a petal of soft colour between
#each two zones and a striped band along the rim. On each petal, near the rim, a giant toy turns on a pedestal between two giant lollipops
#and a bunch of balloons
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
		#The petal: a long round shape along the gap between the two zones, and a smaller one inside it
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


#A ring on the floor from "inner" to "outer" meters around the middle, in stripes of two colours
func _band(inner: float, outer: float, a: Color, b: Color, height: float) -> void:
	var steps := 72
	for step in steps:
		var from := TAU * step / steps
		var to := TAU * (step + 1) / steps
		var quad := PackedVector2Array([Vector2(cos(from), sin(from)) * inner, Vector2(cos(from), sin(from)) * outer,
			Vector2(cos(to), sin(to)) * outer, Vector2(cos(to), sin(to)) * inner])
		_terrain.inlay(quad, height, a if step % 2 == 0 else b)


#A giant candy lollipop: a striped stick and a round sweet on top with a swirl
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


#Where the roller sweeps: a striped warning ring on the floor at the reach of its bar, and a softer one inside it
func _build_roller() -> void:
	var zone := TrendLayout.Zone.ROLLER
	var centre := layout.zone_center(zone)
	var rim := CandyTerrain.new(self)
	rim.rail(_ring_line(centre, TrendLayout.ROLLER_ARM + 0.9, 0.08), Color("ff6f7d"), true)
	rim.inlay(_ring_band_outline(centre, 2.2), 0.034, layout.color_of_zone(zone).lightened(0.4))
	rim.commit()


#The glass of the gravity zone stands on a collision layer of its own; under it, its pads face down, and its floor has a disc and pads
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
	#Six candy columns hold the glass, a ring of bulbs runs along its edge and a glowing ring marks the floor under it
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


#The pond and its platforms: each platform is a body that carries whoever stands on it
func _build_islands() -> void:
	var zone := TrendLayout.Zone.ISLANDS
	var water := MeshInstance3D.new()
	var sheet := BoxMesh.new()
	sheet.size = Vector3(TrendLayout.POND_HALF.y * 2.0, 0.06, TrendLayout.POND_HALF.x * 2.0)
	water.mesh = sheet
	water.material_override = PartyKit.paint(WATER_COLOR, 0.35, 0.12)
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
		#A white candy edge on top, so each platform reads as a stepping stone over the water
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


#What makes a platform look like an app tile, with no collision of its own: a white face with the icon of a social network (two on the
#long ones) and a striped column that holds it from the water. It moves, turns and sinks with the platform
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
	#The icons lie on the face: one in the middle, or two along the platforms that are much longer than wide
	var spots: Array[float] = [0.0]
	var side := size.x * 1.2 if round_top else minf(size.x, size.y) * 0.78
	if not round_top and size.y > size.x * 2.0:
		spots = [-size.y * 0.25, size.y * 0.25]
		side = minf(size.x * 0.78, size.y * 0.5 * 0.85)
	var lift := 0.036 if round_top else 0.078
	for spot in spots.size():
		var quad := QuadMesh.new()
		quad.size = Vector2(side, side)
		var picture := StandardMaterial3D.new()
		picture.albedo_texture = ISLET_ICONS[(index + spot) % ISLET_ICONS.size()]
		picture.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		picture.roughness = 0.4
		var icon := MeshInstance3D.new()
		icon.mesh = quad
		icon.material_override = picture
		icon.rotation_degrees.x = -90.0
		icon.position = Vector3(0.0, lift, spots[spot])
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(icon)
	#The column goes from under the platform to the water, narrower than the platform so it reads as a pedestal
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


#The screens of the maze: a body each that rises out of the floor and sinks back, red while it is up, and a strip on the floor
#where it stands that is green while the way is open
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


#A few likes are enough: each one falls, lands and goes before the pool runs out
func _build_likes() -> void:
	var paint := PartyKit.paint(LIKE_COLOR, 0.4, 0.4)
	var mark := PartyKit.paint(LIKE_COLOR, 1.4, 0.4)
	var ball := SphereMesh.new()
	ball.radius = LIKE_RADIUS
	ball.height = LIKE_RADIUS * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	var ring := TorusMesh.new()
	ring.inner_radius = TrendObstacles.LIKE_REACH - 0.18
	ring.outer_radius = TrendObstacles.LIKE_REACH
	ring.rings = 24
	ring.ring_segments = 6
	for index in LIKE_POOL:
		var body := MeshInstance3D.new()
		body.mesh = ball
		body.material_override = paint
		body.hide()
		add_child(body)
		var target := MeshInstance3D.new()
		target.mesh = ring
		target.material_override = mark
		target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		target.hide()
		add_child(target)
		_likes.append({"body": body, "mark": target})


#A like shows its ring on the floor while it is coming, falls in the last moment, squashes on landing and is gone
func _place_likes(time: float) -> void:
	var falling := obstacles.likes(time)
	for index in _likes.size():
		var body: MeshInstance3D = _likes[index]["body"]
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
		if left > 0.0:
			var share := left / TrendObstacles.LIKE_FALL
			body.position = at + Vector3(0.0, LIKE_RADIUS + TrendObstacles.LIKE_DROP * share * share, 0.0)
			body.scale = Vector3.ONE
		else:
			var gone := clampf(-left / TrendObstacles.LIKE_GONE, 0.0, 1.0)
			body.position = at + Vector3(0.0, LIKE_RADIUS * (1.0 - 0.5 * gone), 0.0)
			body.scale = Vector3(1.0 + 0.4 * gone, 1.0 - 0.6 * gone, 1.0 + 0.4 * gone) * (1.0 - gone * 0.8)


#A closed ring of points on the floor around "centre", for a candy rail
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
