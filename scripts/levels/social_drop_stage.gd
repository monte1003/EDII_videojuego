class_name SocialDropStage
extends Node3D

#The set around the SocialDrop board: sky and light, a ring of candy pillars joined by bunting, grandstands with a cheering crowd,
#balloons, a big wheel, a rainbow, sweeping beams, confetti cannons and a sea of drifting clouds. None of it collides

const PILLAR_COUNT := 8
const PILLAR_RADIUS := 31.0
const PILLAR_SIZE := 1.7
const PILLAR_BASE := -30.0
const STAND_RADIUS := 31.0
const STAND_WIDTH := 14.0
const STAND_TIERS := 4
const STAND_HEIGHT := -1.6
#Where the cannons and the balloons stand: the four corners of the board, outside the screens
const CORNER := Vector2(9.0, 9.0)
const SEA_COUNT := 30
const SEA_AREA := Rect2(-60.0, -45.0, 120.0, 80.0)
const SEA_DEPTH := Vector2(-20.0, -9.0)
const SEA_COLORS: Array[Color] = [Color("ffffff"), Color("f3ecff"), Color("fde8f1")]
const HORIZON_COUNT := 14
const FLOATING_ICONS := 10
const CHEER_TIME := 1.6
#Giant toy props on floating pedestals around the board; the speakers beat with the music, the others just float and turn a little
const BEAT := 0.52
const PROPS: Array[Dictionary] = [
	{"id": &"speaker", "height": 6.5, "at": Vector3(17.5, -1.5, 8.5), "beat": true},
	{"id": &"speaker", "height": 6.5, "at": Vector3(-17.5, -1.5, 8.5), "beat": true},
	{"id": &"speaker", "height": 6.5, "at": Vector3(17.5, -1.5, -8.5), "beat": true},
	{"id": &"speaker", "height": 6.5, "at": Vector3(-17.5, -1.5, -8.5), "beat": true},
	{"id": &"trophy", "height": 8.0, "at": Vector3(0.0, -1.0, -21.0), "beat": false},
	{"id": &"like_hand", "height": 6.0, "at": Vector3(20.0, -0.5, 17.0), "beat": false},
	{"id": &"like_hand", "height": 6.0, "at": Vector3(-20.0, -0.5, 17.0), "beat": false},
	{"id": &"camera", "height": 5.0, "at": Vector3(23.0, 0.0, -15.0), "beat": false},
	{"id": &"camera", "height": 5.0, "at": Vector3(-23.0, 0.0, -15.0), "beat": false},
	{"id": &"clapper", "height": 5.0, "at": Vector3(9.5, -1.0, 23.0), "beat": false},
	{"id": &"clapper", "height": 5.0, "at": Vector3(-9.5, -1.0, 23.0), "beat": false},
]

var _rng := RandomNumberGenerator.new()
var _crowd: CrowdField
var _cannons: Array[Node3D] = []
var _beams: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _cards: Array[Node3D] = []
var _cheer: Tween
var _clock := 0.0
#The props that float (holder, height they float at, phase) and the ones that beat (holder, glow ring)
var _bobbers: Array[Dictionary] = []
var _speakers: Array[Dictionary] = []


func build(icons: Array[Texture2D]) -> void:
	_rng.seed = 31
	_build_sky()
	_build_clouds()
	_build_pillars()
	_build_stands()
	_build_corners()
	_build_backdrop()
	_build_floating_icons(icons)
	_build_props()
	add_child(PartyKit.sparkles(Vector3(36.0, 10.0, 36.0), 70))
	var likes := PartyKit.hearts(Vector3(26.0, 5.0, 26.0), 26)
	likes.position = Vector3(0.0, 2.0, 0.0)
	add_child(likes)


#The crowd jumps higher for a moment, as when a drop is survived
func cheer(power: float) -> void:
	if _cheer != null and _cheer.is_valid():
		_cheer.kill()
	_crowd.set_excitement(power)
	_cheer = create_tween()
	_cheer.tween_method(_crowd.set_excitement, power, 1.0, CHEER_TIME).set_ease(Tween.EASE_OUT)


#Confetti from every cannon and a crowd gone wild
func celebrate() -> void:
	for cannon in _cannons:
		var muzzle := cannon.get_node("Muzzle") as Marker3D
		ImpactFx.confetti(self, muzzle.global_position, 100, 55.0, 10.0)
	cheer(3.0)


func _process(delta: float) -> void:
	_clock += delta
	#The speakers throb on the beat and the pedestals of the props rock gently
	var pulse := pow(1.0 - fposmod(_clock, BEAT) / BEAT, 4.0)
	for entry in _speakers:
		(entry["model"] as Node3D).scale = Vector3.ONE * (1.0 + 0.08 * pulse)
		var ring := entry["ring"] as StandardMaterial3D
		ring.emission_energy_multiplier = 0.8 + 2.4 * pulse
	for entry in _bobbers:
		var holder: Node3D = entry["holder"]
		holder.position.y = entry["base_y"] + sin(_clock * 0.9 + entry["phase"]) * 0.45
	for entry in _beams:
		var pivot: Node3D = entry["pivot"]
		var wave: float = _clock * entry["speed"] + entry["phase"]
		pivot.basis = (entry["lean"] as Basis) * Basis(Vector3.RIGHT, sin(wave) * 0.22) * Basis(Vector3.BACK, cos(wave * 0.8) * 0.22)
	for entry in _floaters:
		var node: Node3D = entry["node"]
		var wave: float = _clock * entry["speed"] + entry["phase"]
		node.position.y = entry["base_y"] + sin(wave) * 0.9
		node.rotation.y = entry["yaw"] + sin(wave * 0.7) * 0.25
	for index in _cards.size():
		_cards[index].rotation.y += delta * (0.25 + 0.05 * index)
		_cards[index].position.y += sin(_clock * 0.9 + index) * delta * 0.35


func _build_sky() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.3, 0.46, 0.98)
	sky_material.sky_horizon_color = Color(1.0, 0.8, 0.88)
	sky_material.ground_bottom_color = Color(0.5, 0.45, 0.93)
	sky_material.ground_horizon_color = Color(1.0, 0.8, 0.88)
	sky_material.sky_curve = 0.2
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
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.04
	#Depth fog only reaches past the set: it fades the far clouds into the sky
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.9, 0.8, 0.98)
	environment.fog_density = 0.8
	environment.fog_depth_begin = 55.0
	environment.fog_depth_end = 130.0
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color(1, 0.95, 0.9)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


#A sea of clouds under the board and a ring of big ones on the horizon
func _build_clouds() -> void:
	var sea := CloudField.new()
	sea.setup(Vector2(SEA_AREA.position.x, SEA_AREA.end.x))
	for index in SEA_COUNT:
		sea.add_cloud(Vector3(_rng.randf_range(SEA_AREA.position.x, SEA_AREA.end.x), _rng.randf_range(SEA_DEPTH.x, SEA_DEPTH.y),
			_rng.randf_range(SEA_AREA.position.y, SEA_AREA.end.y)), _rng.randf_range(2.0, 4.5), SEA_COLORS[index % SEA_COLORS.size()],
			_rng.randf_range(0.8, 2.2), _rng)
	add_child(sea)
	sea.commit()
	var rim := CloudField.new()
	rim.setup(Vector2(-130.0, 130.0))
	for index in HORIZON_COUNT:
		var angle := TAU * index / HORIZON_COUNT + _rng.randf_range(-0.15, 0.15)
		var distance := _rng.randf_range(78.0, 105.0)
		rim.add_cloud(Vector3(cos(angle) * distance, _rng.randf_range(-12.0, 2.0), sin(angle) * distance), _rng.randf_range(7.0, 11.0),
			SEA_COLORS[index % SEA_COLORS.size()], _rng.randf_range(0.2, 0.5), _rng)
	add_child(rim)
	rim.commit()


#Candy pillars rising from the clouds, each with a sweeping beam, and bunting from one to the next
func _build_pillars() -> void:
	var caps: Array[Vector3] = []
	for index in PILLAR_COUNT:
		var angle := TAU * (index + 0.5) / PILLAR_COUNT
		var top := 13.0 + (index % 2) * 5.0
		var color := PartyKit.PALETTE[index % PartyKit.PALETTE.size()]
		var pillar := PartyKit.pillar(top - PILLAR_BASE, PILLAR_SIZE, color, PartyKit.WHITE)
		pillar.position = Vector3(cos(angle) * PILLAR_RADIUS, PILLAR_BASE, sin(angle) * PILLAR_RADIUS)
		add_child(pillar)
		caps.append(Vector3(pillar.position.x, top, pillar.position.z))
		var pivot := Node3D.new()
		pivot.position = caps[index] + Vector3(0.0, PILLAR_SIZE * 1.3, 0.0)
		pivot.add_child(PartyKit.beam(Color(color, 1.0).lerp(Color.WHITE, 0.35), 46.0, 3.4, 0.42))
		add_child(pivot)
		var inward := Vector3(-cos(angle), 0.0, -sin(angle))
		_beams.append({"pivot": pivot, "phase": _rng.randf() * TAU, "speed": _rng.randf_range(0.5, 0.9),
			"lean": Basis(Quaternion(Vector3.UP, (inward * 0.5 + Vector3.UP).normalized()))})
	for index in PILLAR_COUNT:
		var from := caps[index] + Vector3(0.0, -2.5, 0.0)
		var to := caps[(index + 1) % PILLAR_COUNT] + Vector3(0.0, -2.5, 0.0)
		add_child(PartyKit.bunting(from, to, 2.4, 14, 1.7, PartyKit.PALETTE))


#Four grandstands on the diagonals, facing the board, in one mesh each and one crowd for all of them
func _build_stands() -> void:
	_crowd = CrowdField.new()
	add_child(_crowd)
	for index in 4:
		var angle := TAU * index / 4.0 + PI / 4.0
		var at := Vector3(cos(angle) * STAND_RADIUS, STAND_HEIGHT, sin(angle) * STAND_RADIUS)
		var facing := Basis(Vector3.UP, atan2(-at.x, -at.z))
		var color := PartyKit.PALETTE[(index * 2 + 1) % PartyKit.PALETTE.size()]
		add_child(PartyKit.stand(_crowd, Transform3D(facing, at), STAND_WIDTH, STAND_TIERS, color, _rng))
	_crowd.commit()


#Each corner of the board has a confetti cannon and a bunch of balloons tied next to it
func _build_corners() -> void:
	var balloons := BalloonField.new()
	add_child(balloons)
	for index in 4:
		var corner := Vector2(CORNER.x if index % 2 == 0 else -CORNER.x, CORNER.y if index < 2 else -CORNER.y)
		var base := Vector3(corner.x, 0.0, corner.y)
		var cannon := PartyKit.cannon(PartyKit.PALETTE[index], PartyKit.WHITE)
		cannon.position = base
		cannon.rotation.y = atan2(-base.x, -base.z)
		add_child(cannon)
		_cannons.append(cannon)
		var tie := base + Vector3(corner.x * 0.12, 0.2, corner.y * 0.12)
		for balloon in 5:
			var color := PartyKit.PALETTE[(index + balloon) % PartyKit.PALETTE.size()]
			balloons.add(tie, _rng.randf_range(4.5, 8.5), _rng.randf_range(0.9, 1.3), color, _rng.randf() * TAU)
	balloons.commit()


#The far scenery: a rainbow, a big wheel and giant props that float and sway
func _build_backdrop() -> void:
	var rainbow := PartyKit.rainbow(54.0, 2.4, [PartyKit.PINK, PartyKit.ORANGE, PartyKit.YELLOW, PartyKit.GREEN, PartyKit.CYAN, PartyKit.VIOLET])
	rainbow.position = Vector3(0.0, -24.0, -84.0)
	add_child(rainbow)
	var wheel := FerrisWheel.new()
	wheel.position = Vector3(-62.0, -10.0, -34.0)
	wheel.rotation.y = atan2(62.0, 34.0)
	add_child(wheel)
	wheel.build(15.0, PartyKit.PALETTE)
	var specs := [
		[&"heart", 7.0, Vector3(-44.0, 12.0, 30.0)], [&"heart", 9.0, Vector3(50.0, 16.0, -12.0)], [&"heart", 6.0, Vector3(14.0, 20.0, -48.0)],
		[&"bubble", 10.0, Vector3(38.0, 9.0, 38.0)], [&"bubble", 8.0, Vector3(-30.0, 18.0, -50.0)], [&"bubble", 9.0, Vector3(-52.0, 6.0, 4.0)],
		[&"phone", 12.0, Vector3(58.0, 12.0, 26.0)], [&"phone", 11.0, Vector3(-14.0, 26.0, 52.0)],
		[&"bell", 6.0, Vector3(26.0, 24.0, -40.0)], [&"island", 14.0, Vector3(-68.0, -4.0, 34.0)], [&"island", 12.0, Vector3(66.0, -2.0, -46.0)],
	]
	for spec in specs:
		var id: StringName = spec[0]
		var item: Node3D
		if id == &"island":
			item = PropKit.make_long(id, spec[1], Color.WHITE, false)
		else:
			item = PropKit.make_tall(id, spec[1], Color.WHITE, false)
		var at: Vector3 = spec[2]
		item.position = at
		item.rotation.y = atan2(-at.x, -at.z)
		add_child(item)
		_floaters.append({"node": item, "base_y": at.y, "yaw": item.rotation.y, "phase": _rng.randf() * TAU, "speed": _rng.randf_range(0.35, 0.8)})


#The giant toy props: each one stands on a candy pedestal with a ring of light under it, floats a little and looks at the board
func _build_props() -> void:
	for spec in PROPS:
		var at: Vector3 = spec["at"]
		var holder := Node3D.new()
		holder.position = at
		holder.rotation.y = atan2(-at.x, -at.z)
		add_child(holder)
		var color := PartyKit.PALETTE[_rng.randi() % PartyKit.PALETTE.size()]
		var base := CylinderMesh.new()
		base.top_radius = 2.5
		base.bottom_radius = 1.7
		base.height = 1.3
		base.radial_segments = 28
		base.rings = 1
		var pedestal := MeshInstance3D.new()
		pedestal.mesh = base
		pedestal.material_override = PartyKit.candy(PartyKit.WHITE, color, 14.0, 0.0, 0.1)
		pedestal.position.y = -0.65
		holder.add_child(pedestal)
		var halo := TorusMesh.new()
		halo.outer_radius = 1.95
		halo.inner_radius = 1.65
		halo.rings = 32
		halo.ring_segments = 6
		var glow := PartyKit.paint(color, 1.4, 0.4).duplicate() as StandardMaterial3D
		var ring := MeshInstance3D.new()
		ring.mesh = halo
		ring.material_override = glow
		ring.position.y = -1.4
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(ring)
		var model := PropKit.make_tall(spec["id"], spec["height"], Color.WHITE, false)
		holder.add_child(model)
		_bobbers.append({"holder": holder, "base_y": at.y, "phase": _rng.randf() * TAU})
		if spec["beat"]:
			_speakers.append({"model": model, "ring": glow})


#Big app icons far around the set, turning slowly
func _build_floating_icons(icons: Array[Texture2D]) -> void:
	for index in FLOATING_ICONS:
		var side := -1.0 if index % 2 == 0 else 1.0
		var card := Sprite3D.new()
		card.texture = icons[index % icons.size()]
		card.pixel_size = _rng.randf_range(2.6, 4.0) / maxf(card.texture.get_height(), 1.0)
		card.modulate = Color(1.0, 1.0, 1.0, 0.9)
		card.double_sided = true
		card.position = Vector3(side * _rng.randf_range(20.0, 36.0), _rng.randf_range(5.0, 18.0), _rng.randf_range(-30.0, 26.0))
		card.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3))
		add_child(card)
		_cards.append(card)
