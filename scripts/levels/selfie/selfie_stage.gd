class_name SelfieStage
extends ArenaGround

#"El Plató" built from its layout with the candy ground of the game: a long island floating over a warm sea of clouds at sunset,
#each set with its own floor, backdrop, piece and name on a board (the turntable under a giant ring light, the raised runway with its
#belt and screen, the podium with its trophy, the dance floor of lit tiles under a mirror ball, the red carpet before a photo wall, the
#pool of balls, the live set with a giant phone, the troll zone with its pads and curb, the gift boxes of the unboxing, the treadmills
#and the dumbbell of the gym and the selfie sticks), and the studio around it: grandstands with an audience, light towers with sweeping
#beams, TV cameras and an on-air sign. Nothing here decides a rule

const DECK_COLOR := Color("ffe2c2")
const DECK_RIM := Color("ff6f86")
const CREAM := Color("fff8ee")
const CORAL := Color("ff7a85")
const TEAL := Color("3fbfae")
const GOLD := Color("ffc857")
const AMBER := Color("ffb347")
const PEACH := Color("ffb48a")
const RED := Color("e8364f")
const PLUM := Color("8d5bd6")
const TROLL_GREEN := Color("7df27a")
#How soon the props of the studio take their simpler shapes (1 is what the engine does by itself)
const PROP_LOD := 0.5
const TROLL_FLOOR := Color("b79cf2")
const GIFT_COLORS: Array[Color] = [Color("ff5c8a"), Color("3fd3ea"), Color("ffcf3f"), Color("8a63f5"), Color("5fdc9c"), Color("ff9340")]
#The name of each set on its board, from the language of the photos and the networks
const SET_NAMES := {&"T": "GIRO 360", &"P": "TOP 3", &"W": "RETO DE BAILE", &"C": "ALFOMBRA ROJA", &"F": "PISCINA", &"D": "EN DIRECTO",
	&"A": "PASARELA", &"Z": "ZONA TROL", &"U": "UNBOXING", &"G": "GIMNASIO FIT", &"S": "PALOS SELFIE"}
const STUDIO_BULBS: Array[Color] = [Color("ffd27a"), Color("ff8a8a"), Color("fff1dc"), Color("5fdcc0")]
const BALL_COLORS: Array[Color] = [Color("ff5c8a"), Color("ffcf3f"), Color("3fd3ea"), Color("8a63f5"), Color("5fdc9c"), Color("ff9340")]
const BELT_TEXTURE: Texture2D = preload("res://assets/textures/belt_chevrons.png")
const DANCE_SHADER: Shader = preload("res://assets/shaders/dance_floor.gdshader")
const SCREEN_SHADER: Shader = preload("res://assets/shaders/studio_screen.gdshader")
const ICONS: Array[Texture2D] = [preload("res://assets/social_icons/me_gusta.png"), preload("res://assets/social_icons/foto.png"),
	preload("res://assets/social_icons/chat.png"), preload("res://assets/social_icons/video.png"), preload("res://assets/social_icons/historia.png"),
	preload("res://assets/social_icons/directo.png")]
const SENSOR_HEIGHT := 3.0
const SENSOR_SINK := 0.4
const BELT_TILE := 3.0
const BELT_WARNING := 1.5
const POP_TIME := 0.5
const BLOCK_SIZE := Vector3(ArenaHazards.BLOCK_ACROSS, 0.9, ArenaHazards.BLOCK_ALONG)
#How deep the tall pillars reach into the clouds
const PILLAR_FOOT := -26.0
const RIG_HEIGHT := 14.5

var layout: SelfieLayout

var _terrain: CandyTerrain
var _rng := RandomNumberGenerator.new()
var _turntable: Node3D
var _disco: Node3D
var _speakers: Array[Node3D] = []
var _live_glow: StandardMaterial3D
var _belts: Array[Dictionary] = []
var _pads: Array[Dictionary] = []
var _spinners: Array[Node3D] = []
var _blocks: Array[Dictionary] = []
var _place_areas: Dictionary = {}
var _beams: Array[Dictionary] = []
var _crowd: CrowdField
var _cheer: Tween
var _on_air: StandardMaterial3D
var _stage := -1
var _beat := -1
#The lids of the gift boxes, by cell
var _lids: Array[Node3D] = []


func build(arena: ArenaLayout) -> void:
	layout = arena as SelfieLayout
	_rng.seed = 2611
	_terrain = CandyTerrain.new(self)
	_terrain.set_bulb_palette(STUDIO_BULBS)
	_build_sky()
	#The runway and the podium stand near the rim: its wall is higher than a jump from them
	_terrain.wall_height = 4.5
	_terrain.island(layout.outline, ArenaLayout.GROUND, DECK_COLOR, DECK_RIM, [], true)
	_terrain.wall_height = CandyTerrain.WALL_HEIGHT
	_build_turntable()
	_build_runway()
	_build_podium()
	_build_dance_floor()
	_build_carpet()
	_build_pool()
	_build_live_set()
	_build_troll_zone()
	_build_unboxing()
	_build_gym()
	_build_set_names()
	_build_rig()
	_build_pads()
	_build_hazards()
	_build_audience()
	_build_scenery()
	for id: StringName in layout.places:
		_build_sensor(id)
	_terrain.commit()
	set_stage(0, false)
	#The props of the studio take their simpler shapes sooner while they are small on screen; nothing is hidden
	for piece in find_children("*", "MeshInstance3D", true, false):
		(piece as MeshInstance3D).lod_bias = PROP_LOD


func watch(locator: PlayerLocator) -> void:
	for id: StringName in _place_areas:
		locator.watch_platform(id, _place_areas[id])


#Shows what starts at this stage of the round; with "pop" the new pieces grow in instead of just appearing
func set_stage(stage: int, pop := true) -> void:
	if stage == _stage:
		return
	_stage = stage
	for index in _spinners.size():
		_reveal(_spinners[index], ArenaLayout.is_on(layout.spinners[index], stage), pop)
	for block in _blocks:
		_reveal(block["node"], ArenaLayout.is_on(block["sweeper"], stage), pop)
		_reveal(block["rail"], ArenaLayout.is_on(block["sweeper"], stage), false)


#Puts everything that moves where it is at "time" seconds of the round
func update(time: float) -> void:
	_turntable.rotation.y = SelfieLayout.TURNTABLE_SPIN * time
	_disco.rotation.y = time * 0.6
	for index in _spinners.size():
		_spinners[index].rotation.y = -Level01Hazards.angle_at(layout.spinners[index], time)
	for block in _blocks:
		var node: Node3D = block["node"]
		if node.visible:
			node.global_position = ArenaHazards.block_center(block["sweeper"], time)
	var warning := layout.belt_turn_in(time) < BELT_WARNING
	for entry in _belts:
		var belt: Dictionary = entry["belt"]
		var flow := layout.belt_flow(belt, _stage, time)
		var material: StandardMaterial3D = entry["material"]
		var tiles: float = entry["tiles"]
		material.uv1_scale = Vector3(1.0, -tiles if flow >= 0.0 else tiles, 1.0)
		material.uv1_offset = Vector3(0.0, fposmod(time * float(belt.get("speed", layout.belt_speed)) / BELT_TILE, 1.0), 0.0)
		var blinks: bool = warning and belt.get("turns", false)
		material.emission_energy_multiplier = 0.25 + 1.3 * absf(sin(time * 10.0)) if blinks else 0.25
	for cell in _lids.size():
		var lid := _lids[cell]
		var phase := SelfieLayout.unbox_phase(cell, time)
		if SelfieLayout.unbox_popping(cell, time):
			var share := phase / SelfieLayout.UNBOX_POP
			lid.position.y = 1.4 * sin(share * PI * 0.5)
			lid.rotation.x = -0.6 * share
		elif SelfieLayout.unbox_rattling(cell, time):
			lid.position.y = 0.06 + 0.05 * absf(sin(time * 40.0))
			lid.rotation.x = 0.06 * sin(time * 47.0)
		else:
			lid.position.y = lerpf(lid.position.y, 0.0, 0.2)
			lid.rotation.x = lerpf(lid.rotation.x, 0.0, 0.2)
	var beat := floori(time / SelfieLayout.BEAT_PERIOD)
	if beat != _beat:
		_beat = beat
		_thump()
	_live_glow.emission_energy_multiplier = lerpf(_live_glow.emission_energy_multiplier, 0.35, 0.08)


#The trampoline dips and springs back
func bounce_pad(index: int) -> void:
	if index < 0 or index >= _pads.size():
		return
	var pad: Node3D = _pads[index]["node"]
	var tween := create_tween()
	tween.tween_property(pad, "scale", Vector3(1.15, 0.35, 1.15), 0.06)
	tween.tween_property(pad, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


#The audience jumps higher for a moment
func cheer(power: float) -> void:
	if _cheer != null and _cheer.is_valid():
		_cheer.kill()
	_crowd.set_excitement(power)
	_cheer = create_tween()
	_cheer.tween_method(_crowd.set_excitement, power, 1.0, 1.6).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	var clock := Time.get_ticks_msec() / 1000.0
	for entry in _beams:
		var pivot: Node3D = entry["pivot"]
		var wave: float = clock * float(entry["speed"]) + float(entry["phase"])
		pivot.basis = (entry["lean"] as Basis) * Basis(Vector3.RIGHT, sin(wave) * 0.18) * Basis(Vector3.BACK, cos(wave * 0.8) * 0.18)
	_on_air.emission_energy_multiplier = 1.6 if fmod(clock, 1.6) < 1.1 else 0.3


#The live set thumps: the speakers pump and the stage flashes
func _thump() -> void:
	for speaker in _speakers:
		var tween := create_tween()
		tween.tween_property(speaker, "scale", Vector3(1.12, 0.9, 1.12), 0.06)
		tween.tween_property(speaker, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_live_glow.emission_energy_multiplier = 1.4


#A warm sky of a late afternoon over a sea of clouds, a sun low on one side and a soft haze far away
func _build_sky() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.46, 0.6, 0.98)
	sky_material.sky_horizon_color = Color(1.0, 0.85, 0.7)
	sky_material.ground_bottom_color = Color(0.78, 0.8, 1.0)
	sky_material.ground_horizon_color = Color(1.0, 0.86, 0.76)
	sky_material.sky_curve = 0.18
	sky_material.ground_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.95
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.1
	environment.adjustment_contrast = 1.04
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.98, 0.9, 0.86)
	environment.fog_density = 0.75
	environment.fog_depth_begin = 90.0
	environment.fog_depth_end = 190.0
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


#The turntable: a striped disc that turns flush with the floor, a gold hub, a coral band around it and a ring of bulbs on the floor
func _build_turntable() -> void:
	var radius := SelfieLayout.TURNTABLE_RADIUS
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sectors := 20
	for index in sectors:
		var from := TAU * index / sectors
		var to := TAU * (index + 1) / sectors
		_fan(tool, 0.95, radius - 0.32, from, to, TEAL if index % 2 == 0 else CREAM, 0.045)
		_fan(tool, radius - 0.32, radius, from, to, CORAL, 0.05)
		_fan(tool, 0.0, 0.95, from, to, GOLD, 0.055)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.35
	var disc := MeshInstance3D.new()
	disc.mesh = tool.commit()
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_turntable = Node3D.new()
	_turntable.position = layout.turntable
	add_child(_turntable)
	_turntable.add_child(disc)
	var rail := PackedVector3Array()
	for step in 49:
		var angle := TAU * step / 48.0
		rail.append(layout.turntable + Vector3(cos(angle), 0.0, sin(angle)) * (radius + 0.25) + Vector3(0.0, 0.08, 0.0))
	_terrain.rail(rail, CORAL, true)


#The raised runway along the north side: a teal deck on candy pillars, two solid ramps down from its ends, the belt along it and a big
#screen behind it
func _build_runway() -> void:
	var box := SelfieLayout.RUNWAY
	var outline := _rect_outline(box)
	var middle := box.get_center().y
	var mouths: Array[Vector3] = [Vector3(box.position.x, middle, box.size.y / 2.0 + 0.2), Vector3(box.end.x, middle, box.size.y / 2.0 + 0.2)]
	_terrain.platform(outline, SelfieLayout.UPPER, SelfieLayout.UPPER - SelfieLayout.DECK_THICKNESS, TEAL, GOLD, mouths)
	for side: float in [-1.0, 1.0]:
		var ramp := layout.ramp_of(side)
		var low: Vector2 = ramp[0]
		var high: Vector2 = ramp[1]
		_terrain.wedge(Vector3(low.x, ArenaLayout.GROUND, low.y), Vector3(high.x, SelfieLayout.UPPER, high.y), float(ramp[2]) - 0.1,
			TEAL.lightened(0.3), ArenaLayout.GROUND, Color("ffd27a"))
	for spot in SelfieLayout.RUNWAY_PILLARS:
		var pillar := PartyKit.pillar(SelfieLayout.UPPER - SelfieLayout.DECK_THICKNESS, SelfieLayout.PILLAR_RADIUS - 0.02, CORAL, CREAM)
		pillar.position = Vector3(spot.x, ArenaLayout.GROUND, spot.y)
		add_child(pillar)
		var shape := CylinderShape3D.new()
		shape.radius = SelfieLayout.PILLAR_RADIUS
		shape.height = SelfieLayout.UPPER - SelfieLayout.DECK_THICKNESS
		_solid(shape, Transform3D(Basis.IDENTITY, pillar.position + Vector3(0.0, shape.height / 2.0, 0.0)))
	for belt in layout.belts:
		_build_belt(belt)
	_screen(Vector3(0.0, SelfieLayout.UPPER + 3.0, box.position.y - 0.55), Vector2(15.0, 5.2), 0.0, CORAL, AMBER)


#The podium: gold for the first place, coral for the second (with its step) and teal for the third, each with its number; a trophy
#on its own little island behind, and two confetti cannons at its front corners
func _build_podium() -> void:
	var blocks: Array[Array] = [[SelfieLayout.PODIUM, SelfieLayout.PODIUM_TOP, GOLD, "1"], [SelfieLayout.SECOND, SelfieLayout.SECOND_TOP, CORAL, "2"],
		[SelfieLayout.SECOND_STEP, SelfieLayout.LOW_TOP, CORAL.lightened(0.25), ""], [SelfieLayout.THIRD, SelfieLayout.LOW_TOP, TEAL, "3"]]
	for entry in blocks:
		var box: Rect2 = entry[0]
		_terrain.platform(_rect_outline(box), float(entry[1]), ArenaLayout.GROUND, entry[2], CREAM)
		if String(entry[3]) == "":
			continue
		#The place in a number with volume on the face toward the middle of the studio
		var number := Word3D.make(entry[3], float(entry[1]) * 0.72, box.size.y * 0.6, (entry[2] as Color).darkened(0.35), 0.14, CREAM)
		number.position = Vector3(box.end.x + 0.07, float(entry[1]) * 0.5, box.get_center().y)
		number.rotation.y = PI / 2.0
		add_child(number)
	_terrain.island(CandyTerrain.circle(Vector2(-47.5, -4.0), 3.0, 28), -0.4, GOLD.lightened(0.2), CORAL)
	var trophy := PropKit.make_tall(&"trophy", 6.5)
	trophy.position = Vector3(-47.5, -0.4, -4.0)
	trophy.rotation.y = PI / 2.0
	add_child(trophy)
	for z: float in [-9.0, 9.0]:
		var cannon := PartyKit.cannon(GOLD, CORAL)
		cannon.position = Vector3(-40.5, ArenaLayout.GROUND, z)
		cannon.rotation.y = PI / 2.0 + signf(z) * 0.5
		add_child(cannon)


#The dance floor: a disc of tiles that light up with the beat inside a gold rail with bulbs, a mirror ball hanging from a boom over
#it and a screen on the far side of the island
func _build_dance_floor() -> void:
	var center := Vector3(SelfieLayout.DANCE_CENTER.x, ArenaLayout.GROUND, SelfieLayout.DANCE_CENTER.y)
	var tiles := CylinderMesh.new()
	tiles.top_radius = SelfieLayout.DANCE_RADIUS
	tiles.bottom_radius = SelfieLayout.DANCE_RADIUS
	tiles.height = 0.04
	tiles.radial_segments = 48
	tiles.rings = 1
	var floor_material := ShaderMaterial.new()
	floor_material.shader = DANCE_SHADER
	_piece(self, tiles, floor_material, center + Vector3(0.0, 0.025, 0.0))
	var rail := PackedVector3Array()
	for step in 49:
		var angle := TAU * step / 48.0
		rail.append(center + Vector3(cos(angle), 0.0, sin(angle)) * (SelfieLayout.DANCE_RADIUS + 0.2) + Vector3(0.0, 0.08, 0.0))
	_terrain.rail(rail, GOLD, true)
	var ball_at := center + Vector3(0.0, 7.0, 0.0)
	_boom(Vector3(center.x, 0.0, -21.5), ball_at, PLUM)
	_disco = _mirror_ball(1.05)
	_disco.position = ball_at
	add_child(_disco)
	var sparkle := PartyKit.sparkles(Vector3(5.0, 3.0, 5.0), 26)
	sparkle.position = center + Vector3(0.0, 3.5, 0.0)
	add_child(sparkle)
	_screen(Vector3(center.x + 10.6, 4.6, 0.0), Vector2(9.0, 5.0), -PI / 2.0, PLUM, CORAL)


#The red carpet between gold velvet ropes, ending at a photo wall of little icons
func _build_carpet() -> void:
	var box := SelfieLayout.CARPET
	_terrain.inlay(_rect_outline(box), 0.018, RED)
	for x: float in [box.position.x + 0.12, box.end.x - 0.12]:
		_terrain.inlay(_rect_outline(Rect2(x - 0.1, box.position.y, 0.2, box.size.y)), 0.024, GOLD)
	var posts: Array[float] = [box.position.y + 0.4, box.position.y + 2.4, box.position.y + 4.4, box.end.y - 0.3]
	var gold := PartyKit.paint(GOLD, 0.25, 0.3)
	for x: float in [box.position.x - 0.45, box.end.x + 0.45]:
		for index in posts.size():
			var post := CylinderMesh.new()
			post.top_radius = 0.06
			post.bottom_radius = 0.09
			post.height = 1.0
			post.radial_segments = 10
			post.rings = 1
			_piece(self, post, gold, Vector3(x, 0.5, posts[index]))
			var knob := SphereMesh.new()
			knob.radius = 0.11
			knob.height = 0.22
			knob.radial_segments = 10
			knob.rings = 5
			_piece(self, knob, gold, Vector3(x, 1.05, posts[index]))
			if index == posts.size() - 1:
				continue
			var rope := PackedVector3Array()
			for step in 7:
				var share := step / 6.0
				var z := lerpf(posts[index], posts[index + 1], share)
				rope.append(Vector3(x, 0.92 - 0.22 * sin(PI * share), z))
			_rope(rope, RED.darkened(0.15))
	var panel := SelfieLayout.PHOTO_WALL
	var wall_at := Vector3(panel.get_center().x, 0.0, panel.get_center().y)
	var wall := Node3D.new()
	wall.position = wall_at
	add_child(wall)
	_piece(wall, _box(Vector3(panel.size.x, SelfieLayout.PHOTO_WALL_TOP, panel.size.y)), PartyKit.paint(CREAM, 0.0, 0.6), Vector3(0.0, SelfieLayout.PHOTO_WALL_TOP / 2.0, 0.0))
	var block := BoxShape3D.new()
	block.size = Vector3(panel.size.x, SelfieLayout.PHOTO_WALL_TOP, panel.size.y)
	_solid(block, Transform3D(Basis.IDENTITY, wall_at + Vector3(0.0, SelfieLayout.PHOTO_WALL_TOP / 2.0, 0.0)))
	var columns := 9
	var rows := 3
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.62)
	var paints: Array[StandardMaterial3D] = []
	for texture in ICONS:
		var icon := StandardMaterial3D.new()
		icon.albedo_texture = texture
		icon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		icon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paints.append(icon)
	for row in rows:
		for column in columns:
			#The same icons on both faces: the wall is seen from the audience too
			for face: float in [-1.0, 1.0]:
				var spot := Vector3((column - (columns - 1) / 2.0) * 0.98, 0.75 + row * 1.0 + (0.15 if column % 2 == 1 else 0.0), face * (panel.size.y / 2.0 + 0.02))
				var tile := _piece(wall, quad, paints[(row * 2 + column) % paints.size()], spot)
				tile.rotation.y = PI if face < 0.0 else 0.0
	#The wall never moves: its pieces join into one mesh per icon
	StaticBatch.join(wall, [])
	#A soft gold frame over both faces rounds its edges
	var edge := panel.size.x / 2.0 + 0.05
	for face: float in [-0.2, 0.2]:
		var rim := PackedVector3Array([wall_at + Vector3(-edge, 0.1, face), wall_at + Vector3(-edge, SelfieLayout.PHOTO_WALL_TOP + 0.1, face),
			wall_at + Vector3(edge, SelfieLayout.PHOTO_WALL_TOP + 0.1, face), wall_at + Vector3(edge, 0.1, face)])
		_terrain.rail(rim, GOLD, face < 0.0)


#The pool: a striped wall to hop over, a soft teal floor that bounces and hundreds of coloured balls; a rainbow stands behind it
func _build_pool() -> void:
	var center := SelfieLayout.POOL_CENTER
	var pieces := 28
	for index in pieces:
		var from := TAU * index / pieces
		var to := TAU * (index + 1) / pieces
		var corners := PackedVector2Array()
		for corner: Array in [[SelfieLayout.POOL_INNER, from], [SelfieLayout.POOL_OUTER, from], [SelfieLayout.POOL_OUTER, to], [SelfieLayout.POOL_INNER, to]]:
			corners.append(center + Vector2(cos(float(corner[1])), sin(float(corner[1]))) * float(corner[0]))
		_terrain.slab(corners, SelfieLayout.POOL_WALL, ArenaLayout.GROUND, TEAL if index % 2 == 0 else CREAM)
		if index % 2 == 0:
			var mid := (from + to) / 2.0
			var ring := (SelfieLayout.POOL_INNER + SelfieLayout.POOL_OUTER) / 2.0
			_terrain.add_bulb(Vector3(center.x + cos(mid) * ring, SelfieLayout.POOL_WALL + 0.14, center.y + sin(mid) * ring), mid * 2.0)
	_terrain.inlay(CandyTerrain.circle(center, SelfieLayout.POOL_INNER - 0.02, 40), 0.015, Color("9fe6dc"))
	var ball := SphereMesh.new()
	ball.radius = 0.17
	ball.height = 0.34
	ball.radial_segments = 10
	ball.rings = 5
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.22
	ball.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = ball
	multi.instance_count = 360
	for index in multi.instance_count:
		var angle := _rng.randf() * TAU
		var away := sqrt(_rng.randf()) * (SelfieLayout.POOL_INNER - 0.25)
		var height := 0.17 + 0.3 * float(index % 3) / 2.0 + _rng.randf_range(-0.04, 0.04)
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(center.x + cos(angle) * away, height, center.y + sin(angle) * away)))
		multi.set_instance_color(index, BALL_COLORS[index % BALL_COLORS.size()])
	var balls := MultiMeshInstance3D.new()
	balls.multimesh = multi
	balls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(balls)
	var rainbow := PartyKit.rainbow(4.6, 0.55, [PartyKit.PINK, PartyKit.ORANGE, PartyKit.YELLOW, PartyKit.GREEN, PartyKit.CYAN, PartyKit.VIOLET])
	rainbow.position = Vector3(center.x - 3.6, -0.3, center.y + 3.6)
	rainbow.rotation.y = PI * 0.75
	add_child(rainbow)
	for side: float in [-1.0, 1.0]:
		var puff := PropKit.make_tall(&"cloud", 1.6)
		puff.position = rainbow.position + Basis(Vector3.UP, rainbow.rotation.y) * Vector3(side * 4.3, 0.0, 0.0)
		add_child(puff)


#The live set: a round coral stage with its ramp, a giant phone behind it that shows the live, a ring light on a tripod and two
#speakers that pump to the beat of the stage
func _build_live_set() -> void:
	var center := SelfieLayout.LIVE_CENTER
	var ramp: Array = SelfieLayout.LIVE_RAMP
	var high: Vector2 = ramp[1]
	var low: Vector2 = ramp[0]
	_terrain.platform(CandyTerrain.circle(center, SelfieLayout.LIVE_RADIUS, 40), SelfieLayout.LIVE_TOP, ArenaLayout.GROUND, CORAL, GOLD,
		[Vector3(high.x, high.y, float(ramp[2]) / 2.0 + 0.3)])
	_terrain.wedge(Vector3(low.x, ArenaLayout.GROUND, low.y), Vector3(high.x, SelfieLayout.LIVE_TOP, high.y), float(ramp[2]), CORAL.lightened(0.3),
		ArenaLayout.GROUND, Color("ffd27a"))
	_live_glow = PartyKit.paint(Color("ff9aa6"), 0.35, 0.3)
	var glow_ring := TorusMesh.new()
	glow_ring.inner_radius = 2.0
	glow_ring.outer_radius = 2.25
	glow_ring.rings = 40
	glow_ring.ring_segments = 6
	_piece(self, glow_ring, _live_glow, Vector3(center.x, SelfieLayout.LIVE_TOP + 0.02, center.y))
	var away := Vector2(0.7071, 0.7071)
	var phone_at := center + away * (SelfieLayout.LIVE_RADIUS + 1.3)
	var phone := PropKit.make_tall(&"phone", 6.2)
	phone.position = Vector3(phone_at.x, ArenaLayout.GROUND, phone_at.y)
	phone.rotation.y = atan2(-away.x, -away.y)
	add_child(phone)
	var hearts := PartyKit.hearts(Vector3(1.6, 2.0, 1.0), 10)
	hearts.position = Vector3(phone_at.x, 4.2, phone_at.y) - Vector3(away.x, 0.0, away.y) * 0.6
	add_child(hearts)
	for spot: Vector2 in [center + Vector2(-0.7071, 0.7071) * (SelfieLayout.LIVE_RADIUS + 0.9), center + Vector2(0.7071, -0.7071) * (SelfieLayout.LIVE_RADIUS + 0.9)]:
		var holder := Node3D.new()
		holder.position = Vector3(spot.x, ArenaLayout.GROUND, spot.y)
		holder.rotation.y = atan2(center.x - spot.x, center.y - spot.y)
		add_child(holder)
		holder.add_child(PropKit.make_tall(&"speaker", 2.0))
		_speakers.append(holder)
	var light_at := center + Vector2(-0.95, 0.3) * (SelfieLayout.LIVE_RADIUS + 0.9)
	_ring_light(Vector3(light_at.x, ArenaLayout.GROUND, light_at.y), Vector3(center.x, 1.6, center.y), 0.85, 2.3)


#The light rig over the middle: a candy arch across the island with a giant ring light hanging over the turntable and little
#spotlights along its bar
func _build_rig() -> void:
	var ends: Array[Vector3] = [Vector3(0.0, RIG_HEIGHT, -25.6), Vector3(0.0, RIG_HEIGHT, 25.6)]
	for end in ends:
		var pillar := PartyKit.pillar(RIG_HEIGHT - PILLAR_FOOT, 0.7, CORAL, CREAM)
		pillar.position = Vector3(end.x, PILLAR_FOOT, end.z)
		add_child(pillar)
	_terrain.rail(PackedVector3Array([ends[0] + Vector3(0.0, 0.4, 0.0), ends[1] + Vector3(0.0, 0.4, 0.0)]), CORAL, true)
	var ring_at := layout.turntable + Vector3(0.0, 10.2, 0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 3.6
	ring.outer_radius = 4.3
	ring.rings = 64
	ring.ring_segments = 12
	_piece(self, ring, PartyKit.paint(Color("fff4e0"), 2.6, 0.3), ring_at)
	var shell := TorusMesh.new()
	shell.inner_radius = 4.25
	shell.outer_radius = 4.6
	shell.rings = 64
	shell.ring_segments = 8
	_piece(self, shell, PartyKit.paint(Color("4a4060"), 0.0, 0.5), ring_at + Vector3(0.0, 0.05, 0.0))
	for angle: float in [PI / 2.0, -PI / 2.0]:
		var hang := Vector3(cos(angle) * 4.4, 0.0, sin(angle) * 4.4)
		_cable(ring_at + hang, Vector3(0.0, RIG_HEIGHT + 0.4, hang.z * 1.6))
	for z: float in [-21.0, -11.0, -6.0, 6.0, 11.0, 21.0]:
		var can := CylinderMesh.new()
		can.top_radius = 0.28
		can.bottom_radius = 0.42
		can.height = 0.7
		can.radial_segments = 14
		can.rings = 1
		_piece(self, can, PartyKit.paint(Color("3c3350"), 0.0, 0.4), Vector3(0.0, RIG_HEIGHT - 0.1, z))
		var lens := CylinderMesh.new()
		lens.top_radius = 0.38
		lens.bottom_radius = 0.38
		lens.height = 0.04
		lens.radial_segments = 14
		lens.rings = 1
		_piece(self, lens, PartyKit.paint(Color("fff1c4"), 3.0, 0.2), Vector3(0.0, RIG_HEIGHT - 0.47, z))


#A trampoline is a dark base, a pink ring and a yellow skin that glows; the cannon is gold, with an arrow toward where it throws and
#hoops along its arc up to the runway
func _build_pads() -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	for pad in layout.pads:
		var node := Node3D.new()
		node.position = (pad["at"] as Vector3) + Vector3(0.0, 0.03, 0.0)
		add_child(node)
		var cannon := ArenaHazards.is_cannon(pad)
		var material := PartyKit.paint(GOLD if cannon else PartyKit.YELLOW, 1.1, 0.3)
		_piece(node, _disc(ArenaHazards.PAD_REACH + 0.2, ArenaHazards.PAD_REACH + 0.3, 0.16), PartyKit.paint(PartyKit.INK, 0.0, 0.6), Vector3(0.0, 0.08, 0.0))
		_piece(node, _disc(ArenaHazards.PAD_REACH, ArenaHazards.PAD_REACH, 0.08), material, Vector3(0.0, 0.19, 0.0))
		var ring := TorusMesh.new()
		ring.outer_radius = ArenaHazards.PAD_REACH + 0.22
		ring.inner_radius = ArenaHazards.PAD_REACH - 0.02
		ring.rings = 28
		ring.ring_segments = 8
		_piece(node, ring, PartyKit.candy(PartyKit.WHITE, CORAL if cannon else PartyKit.PINK, 12.0, 0.0, 0.2), Vector3(0.0, 0.2, 0.0))
		_pads.append({"node": node, "pad": pad})
		if not cannon:
			continue
		var to: Vector3 = pad["to"]
		var aim := Vector3(to.x - node.position.x, 0.0, to.z - node.position.z).normalized()
		var arrow := PrismMesh.new()
		arrow.size = Vector3(0.9, 0.9, 0.04)
		var mark := _piece(node, arrow, PartyKit.paint(CREAM, 0.8, 0.3), Vector3(0.0, 0.25, 0.0))
		mark.basis = Basis.looking_at(aim, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2.0)
		var hoop := TorusMesh.new()
		hoop.inner_radius = 1.0
		hoop.outer_radius = 1.25
		hoop.rings = 24
		hoop.ring_segments = 6
		var time: float = pad["time"]
		for index in 3:
			var seconds := time * float(index + 1) / 4.0
			var heading := ArenaHazards.pad_launch(pad, gravity) - Vector3(0.0, gravity * seconds, 0.0)
			var loop := _piece(self, hoop, PartyKit.paint(GOLD, 1.3, 0.4), ArenaHazards.pad_arc(pad, seconds, gravity) + Vector3(0.0, 0.9, 0.0))
			loop.basis = Basis.looking_at(heading.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)


#The boom of microphones over the dance floor and the prop boxes that sweep the runway, each on a dark rail with yellow stops
func _build_hazards() -> void:
	for spinner in layout.spinners:
		var pivot := Node3D.new()
		pivot.position = (spinner["at"] as Vector3) + Vector3(0.0, 0.02, 0.0)
		add_child(pivot)
		var arm: float = spinner["arm"]
		var gym := Vector2((spinner["at"] as Vector3).x, (spinner["at"] as Vector3).z).distance_to(SelfieLayout.GYM_CENTER) < 0.1
		for bar in int(spinner.get("arms", 1)):
			var holder := Node3D.new()
			holder.rotation.y = PI / 2.0 * bar
			pivot.add_child(holder)
			if gym:
				#A dumbbell: a striped bar with a big weight at each end
				holder.add_child(PropKit.make(&"bumper", Vector3(arm * 2.0, 0.42, 0.42), Color("c9c4d8")))
				for side: float in [-1.0, 1.0]:
					var weight := _piece(holder, _disc(0.62, 0.62, 0.34), PartyKit.candy(Color("3c3350"), CORAL, 12.0), Vector3(side * (arm - 0.2), 0.45, 0.0))
					weight.rotation.z = PI / 2.0
				continue
			holder.add_child(PropKit.make(&"bumper", Vector3(arm * 2.0, 0.6, 0.6), PLUM.lightened(0.3)))
			for side: float in [-1.0, 1.0]:
				var head := SphereMesh.new()
				head.radius = 0.42
				head.height = 0.84
				head.radial_segments = 14
				head.rings = 7
				_piece(holder, head, PartyKit.paint(Color("4a4060"), 0.0, 0.35), Vector3(side * arm, 0.7, 0.0))
		var post := PartyKit.pillar(1.2, 0.3, CORAL if gym else PLUM, CREAM)
		pivot.add_child(post)
		_spinners.append(pivot)
	for sweeper in layout.sweepers:
		var from: Vector3 = sweeper["a"]
		var to: Vector3 = sweeper["b"]
		var basis := Basis.looking_at((to - from).normalized(), Vector3.UP)
		var holder := Node3D.new()
		add_child(holder)
		if sweeper.get("stick", false):
			#A giant selfie stick: a soft base that does the pushing, a striped pole and a phone on top that looks at the set
			holder.add_child(PropKit.make(&"foam_block", BLOCK_SIZE, PartyKit.PINK.lightened(0.2)))
			var pole := _piece(holder, _disc(0.07, 0.09, 2.6), PartyKit.candy(CREAM, CORAL, 2.0, 10.0), Vector3(0.0, 2.2, 0.0))
			pole.rotation.x = -0.25
			var phone := PropKit.make_tall(&"phone", 1.2)
			phone.position = Vector3(0.0, 3.5, -0.35)
			phone.rotation.x = -0.5
			holder.add_child(phone)
		else:
			holder.add_child(PropKit.make(&"foam_block", BLOCK_SIZE, AMBER))
		holder.basis = basis
		holder.global_position = ArenaHazards.block_center(sweeper, 0.0)
		var rail := Node3D.new()
		add_child(rail)
		rail.basis = basis
		rail.global_position = (from + to) / 2.0
		var length := from.distance_to(to) + BLOCK_SIZE.z + 0.3
		_piece(rail, _box(Vector3(BLOCK_SIZE.x + 0.45, 0.03, length)), PartyKit.paint(PartyKit.INK, 0.0, 0.6), Vector3(0.0, 0.02, 0.0))
		for way: float in [-1.0, 1.0]:
			_piece(rail, _disc(0.17, 0.2, 0.42), PartyKit.paint(PartyKit.YELLOW, 0.8, 0.35), Vector3(0.0, 0.2, length / 2.0 * way))
		_blocks.append({"node": holder, "rail": rail, "sweeper": sweeper})


#The studio audience on two floating grandstands along the long sides, with balloons at their ends, and four light towers with
#sweeping beams joined by bunting
func _build_audience() -> void:
	_crowd = CrowdField.new()
	add_child(_crowd)
	var balloons := BalloonField.new()
	add_child(balloons)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(0.0, -0.8, side * 29.5)
		_terrain.island(CandyTerrain.rounded_box(Vector2(at.x, at.z), Vector2(52.0, 7.0), 3.0), at.y, PEACH.lightened(0.35), CORAL)
		var facing := Basis(Vector3.UP, PI if side > 0.0 else 0.0)
		add_child(PartyKit.stand(_crowd, Transform3D(facing, at + Vector3(0.0, 0.0, -side * 2.9)), 48.0, 4, CORAL if side < 0.0 else TEAL, _rng))
		for end: float in [-1.0, 1.0]:
			for balloon in 4:
				balloons.add(at + Vector3(end * 25.0, 0.3, 0.0), _rng.randf_range(4.5, 8.0), _rng.randf_range(0.9, 1.3),
					BALL_COLORS[(balloon + int(end + 1.0)) % BALL_COLORS.size()], _rng.randf() * TAU)
	_crowd.commit()
	balloons.commit()
	var caps: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-41.0, -22.0), Vector2(41.0, -22.0), Vector2(41.0, 22.0), Vector2(-41.0, 22.0)]:
		var top := 16.0
		var pillar := PartyKit.pillar(top - PILLAR_FOOT, 0.95, GOLD, CREAM)
		pillar.position = Vector3(corner.x, PILLAR_FOOT, corner.y)
		add_child(pillar)
		caps.append(Vector3(corner.x, top, corner.y))
		var pivot := Node3D.new()
		pivot.position = Vector3(corner.x, top + 1.2, corner.y)
		pivot.add_child(PartyKit.beam(Color("ffe2b8"), 52.0, 3.4, 0.35))
		add_child(pivot)
		var inward := Vector3(-corner.x, 0.0, -corner.y).normalized()
		_beams.append({"pivot": pivot, "phase": _rng.randf() * TAU, "speed": _rng.randf_range(0.4, 0.7),
			"lean": Basis(Quaternion(Vector3.UP, (inward * 0.55 + Vector3.UP).normalized()))})
	for index in caps.size():
		add_child(PartyKit.bunting(caps[index] + Vector3(0.0, -2.0, 0.0), caps[(index + 1) % caps.size()] + Vector3(0.0, -2.0, 0.0), 2.4, 30, 1.7,
			[CORAL, GOLD, TEAL, CREAM, PEACH]))


#Around the studio: TV cameras on floating pedestals at both ends, the on-air sign over the north grandstand, a sea of clouds below
#and big clouds on the horizon
func _build_scenery() -> void:
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 50.0, -0.5, 8.0 * side)
		_terrain.island(CandyTerrain.circle(Vector2(at.x, at.z), 2.6, 24), at.y, CREAM, TEAL)
		var camera := PropKit.make_tall(&"camera", 3.4)
		camera.position = at
		camera.rotation.y = atan2(-at.x, -at.z)
		add_child(camera)
	var sign_root := Node3D.new()
	sign_root.position = Vector3(0.0, 11.5, -33.5)
	add_child(sign_root)
	_on_air = PartyKit.paint(RED, 1.6, 0.35)
	_piece(sign_root, _box(Vector3(6.2, 1.8, 0.4)), PartyKit.paint(Color("3a2f4f"), 0.0, 0.5), Vector3.ZERO)
	_piece(sign_root, _box(Vector3(5.8, 1.45, 0.1)), _on_air, Vector3(0.0, 0.0, 0.2))
	var words := Word3D.make("AL AIRE", 0.95, 5.0, RED.darkened(0.35), 0.14, CREAM)
	words.position = Vector3(0.0, -0.02, 0.33)
	sign_root.add_child(words)
	for x: float in [-2.2, 2.2]:
		_cable(sign_root.position + Vector3(x, 0.9, 0.0), sign_root.position + Vector3(x * 1.6, 7.0, 0.0))
	var sea := CloudField.new()
	sea.setup(Vector2(-140.0, 140.0))
	var tones: Array[Color] = [Color("fff8f0"), Color("ffe9de"), Color("fbe2ec")]
	for index in 110:
		sea.add_cloud(Vector3(_rng.randf_range(-130.0, 130.0), _rng.randf_range(-30.0, -18.0), _rng.randf_range(-110.0, 110.0)),
			_rng.randf_range(7.0, 13.0), tones[index % tones.size()], _rng.randf_range(0.1, 0.35), _rng)
	for index in 14:
		var angle := TAU * index / 14.0 + _rng.randf_range(-0.15, 0.15)
		var distance := _rng.randf_range(95.0, 125.0)
		sea.add_cloud(Vector3(cos(angle) * distance, _rng.randf_range(4.0, 16.0), sin(angle) * distance), _rng.randf_range(9.0, 14.0),
			tones[index % tones.size()], _rng.randf_range(0.2, 0.4), _rng)
	add_child(sea)
	sea.commit()
	add_child(PartyKit.sparkles(Vector3(42.0, 8.0, 24.0), 70))


#A belt with its moving surface a little over the floor it lies on, its candy rails and drums
func _build_belt(belt: Dictionary) -> void:
	var from: Vector3 = belt["a"]
	var to: Vector3 = belt["b"]
	var basis := Basis.looking_at((to - from).normalized(), Vector3.UP)
	var length := from.distance_to(to)
	var material := StandardMaterial3D.new()
	material.albedo_texture = BELT_TEXTURE
	material.roughness = 0.55
	material.emission_enabled = true
	material.emission = Color("4cf2b0")
	material.emission_energy_multiplier = 0.25
	var holder := Node3D.new()
	holder.position = (from + to) / 2.0 + Vector3(0.0, 0.05, 0.0)
	holder.basis = basis
	add_child(holder)
	_piece(holder, _box(Vector3(float(belt["width"]) - 0.3, 0.06, length)), material, Vector3(0.0, -0.01, 0.0))
	BeltKit.dress(holder, length, float(belt["width"]), TEAL if from.y > 1.0 else CORAL)
	_belts.append({"belt": belt, "material": material, "tiles": length / BELT_TILE})


#The troll zone: a plum floor walled by a striped curb that a player hops over, low pads with a high one in the middle, and angry
#comments that float over it on poles
func _build_troll_zone() -> void:
	var box := SelfieLayout.TROLL
	_terrain.inlay(_rect_outline(box.grow(-SelfieLayout.CURB_THICKNESS)), 0.016, TROLL_FLOOR)
	var thick := SelfieLayout.CURB_THICKNESS
	var pieces: Array[Rect2] = [Rect2(box.position, Vector2(box.size.x, thick)), Rect2(box.position.x, box.end.y - thick, box.size.x, thick),
		Rect2(box.position.x, box.position.y + thick, thick, box.size.y - thick * 2.0), Rect2(box.end.x - thick, box.position.y + thick, thick, box.size.y - thick * 2.0)]
	for index in pieces.size():
		_terrain.slab(_rect_outline(pieces[index]), SelfieLayout.TROLL_CURB, ArenaLayout.GROUND, TROLL_GREEN if index % 2 == 0 else PLUM.lightened(0.2))
	var line := PackedVector3Array()
	for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y), box.position]:
		line.append(Vector3(corner.x, SelfieLayout.TROLL_CURB + 0.05, corner.y))
	_terrain.rail(line, TROLL_GREEN, true)
	for pad: Array in SelfieLayout.TROLL_PADS:
		var high := float(pad[2]) > 1.0
		_terrain.platform(CandyTerrain.circle(pad[0], float(pad[1]), 28), float(pad[2]), ArenaLayout.GROUND, GOLD if high else TROLL_GREEN.lightened(0.3),
			CORAL if high else PLUM)
	var words: Array[String] = ["ratio", "L", "spam", "bot", "meh", "cringe"]
	for index in words.size():
		var angle := TAU * index / words.size()
		var spot := Vector3(box.get_center().x + cos(angle) * (box.size.x / 2.0 + 1.2), 0.0, box.get_center().y + sin(angle) * (box.size.y / 2.0 + 1.2))
		var pole := PartyKit.pillar(3.0 + float(index % 2) * 0.8, 0.12, PLUM, CREAM)
		pole.position = spot
		add_child(pole)
		var bubble := PropKit.make(&"bubble", Vector3(1.8, 1.3, 0.8), Color("d9c2ff"))
		bubble.position = spot + Vector3(0.0, 3.4 + float(index % 2) * 0.8, 0.0)
		bubble.rotation.y = atan2(box.get_center().x - spot.x, box.get_center().y - spot.z)
		add_child(bubble)
		#The word is on the face that looks into the zone, where the players and the camera of its photo are
		var word := Word3D.make(words[index], 0.62, 1.5, PLUM)
		word.position = Vector3(0.0, 0.65, 0.5)
		bubble.add_child(word)


#The unboxing: a grid of gift boxes flush with the floor, each with a ribbon and a bow on its lid; the lid rattles and pops up with a
#spring when its box throws whoever stands on it
func _build_unboxing() -> void:
	var side := SelfieLayout.UNBOX_CELL - 0.18
	for cell in SelfieLayout.UNBOX_GRID * SelfieLayout.UNBOX_GRID:
		var centre := layout.unbox_center(cell)
		var color := GIFT_COLORS[cell % GIFT_COLORS.size()]
		var ribbon := GIFT_COLORS[(cell + 3) % GIFT_COLORS.size()].lightened(0.25)
		_terrain.inlay(_rect_outline(Rect2(centre.x - side / 2.0 - 0.06, centre.z - side / 2.0 - 0.06, side + 0.12, side + 0.12)), 0.012, Color("3c3350"))
		var lid := Node3D.new()
		lid.position = Vector3.ZERO
		var holder := Node3D.new()
		holder.position = centre
		add_child(holder)
		holder.add_child(lid)
		_piece(lid, _box(Vector3(side, 0.08, side)), PartyKit.paint(color, 0.1, 0.4), Vector3(0.0, 0.04, 0.0))
		_piece(lid, _box(Vector3(side + 0.02, 0.1, 0.36)), PartyKit.paint(ribbon, 0.2, 0.35), Vector3(0.0, 0.045, 0.0))
		_piece(lid, _box(Vector3(0.36, 0.1, side + 0.02)), PartyKit.paint(ribbon, 0.2, 0.35), Vector3(0.0, 0.045, 0.0))
		for turn: float in [-0.6, 0.6]:
			var loop := TorusMesh.new()
			loop.inner_radius = 0.16
			loop.outer_radius = 0.3
			loop.rings = 16
			loop.ring_segments = 6
			var bow := _piece(lid, loop, PartyKit.paint(ribbon, 0.2, 0.35), Vector3(turn * 0.35, 0.24, 0.0))
			bow.rotation = Vector3(PI / 2.0, 0.0, turn)
		_lids.append(lid)


#The gym: a rubber mat under the two treadmills, stacks of weights at its corners and a mirror on its far side
func _build_gym() -> void:
	var centre := SelfieLayout.GYM_CENTER
	_terrain.inlay(_rect_outline(Rect2(centre.x - 4.8, centre.y - 3.8, 9.6, 7.6)), 0.012, Color("4c5b7a"))
	for corner: Vector2 in [Vector2(-4.6, -3.6), Vector2(4.6, -3.6), Vector2(-4.6, 3.6), Vector2(4.6, 3.6)]:
		for level in 3:
			var plate := _piece(self, _disc(0.5 - level * 0.08, 0.5 - level * 0.08, 0.16), PartyKit.candy(Color("3c3350"), GOLD, 10.0),
				Vector3(centre.x + corner.x, 0.08 + level * 0.17, centre.y + corner.y))
			plate.rotation.y = level * 0.4


#A board with the name of each set hanging from two cables over the side of the set farthest from the middle, high enough to stay out
#of the photos and out of the way, facing the middle (the runway has its screen instead)
func _build_set_names() -> void:
	var signs := Node3D.new()
	add_child(signs)
	for spot in layout.spots:
		if spot == &"A":
			continue
		var centre := layout.position_of(spot)
		var out := Vector3(centre.x, 0.0, centre.z)
		if out.length() < 1.0:
			out = Vector3(0.0, 0.0, 1.0)
		out = out.normalized()
		var board := SignBoard.board(SET_NAMES.get(spot, String(spot)), PLUM if spot == &"Z" else CORAL, 6.2, 1.25)
		board.position = Vector3(centre.x, centre.y + 6.4, centre.z) + out * (layout.room_of(spot).length() + 0.8)
		board.rotation.y = atan2(-out.x, -out.z)
		signs.add_child(board)
		var side := Vector3(-out.z, 0.0, out.x)
		for way: float in [-1.0, 1.0]:
			var top := board.position + side * way * 2.6 + Vector3(0.0, 1.25, 0.0)
			_cable(top, top + Vector3(0.0, 14.0, 0.0), 0.035, null, signs)
	#The boards and their cables never move: they are joined into a few meshes
	StaticBatch.join(signs, [])


#A big screen standing on its long edge at "at" (its middle), turned "yaw", in a candy frame with bulbs
func _screen(at: Vector3, size: Vector2, yaw: float, a: Color, b: Color) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	add_child(holder)
	var quad := QuadMesh.new()
	quad.size = size
	var material := ShaderMaterial.new()
	material.shader = SCREEN_SHADER
	material.set_shader_parameter("color_a", a)
	material.set_shader_parameter("color_b", b)
	_piece(holder, quad, material, Vector3(0.0, 0.0, 0.1))
	_piece(holder, _box(Vector3(size.x + 0.3, size.y + 0.3, 0.14)), PartyKit.paint(Color("3a2f4f"), 0.0, 0.5), Vector3(0.0, 0.0, -0.02))
	var basis := Basis(Vector3.UP, yaw)
	var half := size / 2.0 + Vector2.ONE * 0.2
	var corners := PackedVector3Array()
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2(half.x, -half.y)]:
		corners.append(at + basis * Vector3(corner.x, corner.y, 0.12))
	_terrain.rail(corners, CREAM, true)


#A pillar that rises from the clouds and an arm over to "tip", with a cable down to what hangs there
func _boom(foot: Vector3, tip: Vector3, color: Color) -> void:
	var top := tip.y + 6.0
	var pillar := PartyKit.pillar(top - PILLAR_FOOT, 0.6, color, CREAM)
	pillar.position = Vector3(foot.x, PILLAR_FOOT, foot.z)
	add_child(pillar)
	_terrain.rail(PackedVector3Array([Vector3(foot.x, top - 0.6, foot.z), Vector3(tip.x, top - 0.6, tip.z)]), color, true)
	_cable(tip + Vector3(0.0, 1.0, 0.0), Vector3(tip.x, top - 0.6, tip.z))


#A mirror ball: a faceted sphere that shines, with a little cap
func _mirror_ball(radius: float) -> Node3D:
	var root := Node3D.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var sides := 18
	for ring in rings:
		for side in sides:
			var corners: Array[Vector3] = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var lat := PI * float(ring + corner.y) / rings - PI / 2.0
				var lon := TAU * float(side + corner.x) / sides
				corners.append(Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * radius)
			var facing := (corners[0] + corners[1] + corners[2] + corners[3]).normalized()
			for index: int in [0, 1, 2, 0, 2, 3]:
				tool.set_normal(facing)
				tool.add_vertex(corners[index])
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("dfe6ff")
	material.metallic = 1.0
	material.roughness = 0.12
	material.emission_enabled = true
	material.emission = Color("ffe9f5")
	material.emission_energy_multiplier = 0.35
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ball := MeshInstance3D.new()
	ball.mesh = tool.commit()
	ball.material_override = material
	root.add_child(ball)
	_piece(root, _disc(0.18, 0.24, 0.3), PartyKit.paint(Color("4a4060"), 0.0, 0.4), Vector3(0.0, radius + 0.1, 0.0))
	return root


#A ring light on a tripod: a glowing ring facing "look_at" and three thin legs
func _ring_light(foot: Vector3, look_at: Vector3, radius: float, height: float) -> void:
	var holder := Node3D.new()
	holder.position = foot + Vector3(0.0, height, 0.0)
	add_child(holder)
	var flat := Vector3(look_at.x - foot.x, 0.0, look_at.z - foot.z).normalized()
	holder.rotation.y = atan2(flat.x, flat.z)
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.12
	ring.outer_radius = radius
	ring.rings = 40
	ring.ring_segments = 8
	var glow := _piece(holder, ring, PartyKit.paint(Color("fff4e0"), 2.4, 0.3), Vector3.ZERO)
	glow.rotation.x = PI / 2.0
	var dark := PartyKit.paint(Color("3c3350"), 0.0, 0.45)
	for index in 3:
		var angle := TAU * index / 3.0
		var leg_foot := foot + Vector3(cos(angle) * 0.55, 0.0, sin(angle) * 0.55)
		_cable(leg_foot, foot + Vector3(0.0, height - radius - 0.1, 0.0), 0.04, dark)
	_cable(foot + Vector3(0.0, height - radius - 0.1, 0.0), holder.position + Vector3(0.0, -radius + 0.1, 0.0), 0.05, dark)


#A thin straight line between two points: a cable, a rope or a leg
func _cable(from: Vector3, to: Vector3, radius := 0.035, material: Material = null, parent: Node3D = null) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = length
	tube.radial_segments = 6
	tube.rings = 1
	var cable := _piece(parent if parent != null else self, tube, material if material != null else PartyKit.paint(Color("3c3350"), 0.0, 0.5), (from + to) / 2.0)
	cable.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


#A soft rope that hangs between posts
func _rope(points: PackedVector3Array, color: Color) -> void:
	var material := PartyKit.paint(color, 0.1, 0.5)
	for index in points.size() - 1:
		_cable(points[index], points[index + 1], 0.05, material)


#A slice of a ring on the floor between two radii and two angles, painted one colour, "height" over the floor
func _fan(tool: SurfaceTool, inner: float, outer: float, from: float, to: float, color: Color, height: float) -> void:
	var corners: Array[Vector3] = [Vector3(cos(from) * inner, height, sin(from) * inner), Vector3(cos(from) * outer, height, sin(from) * outer),
		Vector3(cos(to) * outer, height, sin(to) * outer), Vector3(cos(to) * inner, height, sin(to) * inner)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		tool.set_color(color)
		tool.set_normal(Vector3.UP)
		tool.add_vertex(corners[index])


func _build_sensor(id: StringName) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = maxf(layout.radius_of(id) - 0.1, 0.4)
	shape.height = SENSOR_HEIGHT
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	area.position = layout.position_of(id) + Vector3(0.0, SENSOR_HEIGHT / 2.0 - SENSOR_SINK, 0.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	_place_areas[id] = area


func _reveal(node: Node3D, on: bool, pop: bool) -> void:
	if node.visible == on:
		return
	node.visible = on
	if on and pop:
		node.scale = Vector3.ONE * 0.01
		create_tween().tween_property(node, "scale", Vector3.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _rect_outline(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])


func _solid(shape: Shape3D, place: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.transform = place
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _piece(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _disc(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	return mesh
