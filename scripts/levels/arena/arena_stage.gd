class_name ArenaStage
extends Node3D

#The game-show set around an arena map, standing on the same ground just past its fence: sky and light, a ring of candy pillars
#joined by bunting with sweeping beams, grandstands with a crowd that cheers, balloons, clouds on the horizon, a rainbow and a
#big wheel. None of it collides and all of it is always drawn

const PILLAR_COUNT := 10
const PILLAR_SIZE := 1.8
const PILLAR_BASE := 0.0
const STAND_WIDTH := 16.0
const STAND_TIERS := 4
const SEA_COLORS: Array[Color] = [Color("ffffff"), Color("f3ecff"), Color("fde8f1")]
const CHEER_TIME := 1.6

var _rng := RandomNumberGenerator.new()
var _crowd: CrowdField
var _beams: Array[Dictionary] = []
var _cheer: Tween
var _clock := 0.0
var _radius := 40.0


#"radius" is how far the map reaches from its middle; the set stands just outside it
func build(radius: float, seed_value: int, top_height: float) -> void:
	_radius = radius
	_rng.seed = seed_value
	_build_sky(radius)
	_build_clouds()
	_build_pillars(top_height)
	_build_stands()
	_build_backdrop()
	add_child(PartyKit.sparkles(Vector3(radius, 10.0, radius), 70))


#The crowd jumps higher for a moment
func cheer(power: float) -> void:
	if _cheer != null and _cheer.is_valid():
		_cheer.kill()
	_crowd.set_excitement(power)
	_cheer = create_tween()
	_cheer.tween_method(_crowd.set_excitement, power, 1.0, CHEER_TIME).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_clock += delta
	for entry in _beams:
		var pivot: Node3D = entry["pivot"]
		var wave: float = _clock * entry["speed"] + entry["phase"]
		pivot.basis = (entry["lean"] as Basis) * Basis(Vector3.RIGHT, sin(wave) * 0.22) * Basis(Vector3.BACK, cos(wave * 0.8) * 0.22)


func _build_sky(radius: float) -> void:
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
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.04
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.9, 0.8, 0.98)
	environment.fog_density = 0.8
	environment.fog_depth_begin = radius * 2.2
	environment.fog_depth_end = radius * 4.5
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color(1, 0.95, 0.9)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)


#Clouds are far scenery only: a ring of big ones on the horizon, never over the map
func _build_clouds() -> void:
	var rim := CloudField.new()
	rim.setup(Vector2(-_radius * 3.2, _radius * 3.2))
	for index in 14:
		var angle := TAU * index / 14.0 + _rng.randf_range(-0.15, 0.15)
		var distance := _radius * _rng.randf_range(2.4, 3.0)
		rim.add_cloud(Vector3(cos(angle) * distance, _rng.randf_range(7.0, 20.0), sin(angle) * distance), _rng.randf_range(8.0, 12.0),
			SEA_COLORS[index % SEA_COLORS.size()], _rng.randf_range(0.2, 0.5), _rng)
	add_child(rim)
	rim.commit()


#Candy pillars standing past the fence, each with a sweeping beam, and bunting from one to the next
func _build_pillars(top_height: float) -> void:
	var caps: Array[Vector3] = []
	var ring := _radius + 9.0
	for index in PILLAR_COUNT:
		var angle := TAU * (index + 0.5) / PILLAR_COUNT
		var top := top_height + 11.0 + (index % 2) * 5.0
		var color := PartyKit.PALETTE[index % PartyKit.PALETTE.size()]
		var pillar := PartyKit.pillar(top - PILLAR_BASE, PILLAR_SIZE, color, PartyKit.WHITE)
		pillar.position = Vector3(cos(angle) * ring, PILLAR_BASE, sin(angle) * ring)
		add_child(pillar)
		caps.append(Vector3(pillar.position.x, top, pillar.position.z))
		var pivot := Node3D.new()
		pivot.position = caps[index] + Vector3(0.0, PILLAR_SIZE * 1.3, 0.0)
		pivot.add_child(PartyKit.beam(Color(color, 1.0).lerp(Color.WHITE, 0.35), 48.0, 3.4, 0.4))
		add_child(pivot)
		var inward := Vector3(-cos(angle), 0.0, -sin(angle))
		_beams.append({"pivot": pivot, "phase": _rng.randf() * TAU, "speed": _rng.randf_range(0.5, 0.9),
			"lean": Basis(Quaternion(Vector3.UP, (inward * 0.5 + Vector3.UP).normalized()))})
	for index in PILLAR_COUNT:
		var from := caps[index] + Vector3(0.0, -2.5, 0.0)
		var to := caps[(index + 1) % PILLAR_COUNT] + Vector3(0.0, -2.5, 0.0)
		add_child(PartyKit.bunting(from, to, 2.6, 16, 1.8, PartyKit.PALETTE))


#Four grandstands on the diagonals facing the middle, with balloons tied at their ends; one crowd for all of them
func _build_stands() -> void:
	_crowd = CrowdField.new()
	add_child(_crowd)
	var balloons := BalloonField.new()
	add_child(balloons)
	var ring := _radius + 7.0
	for index in 4:
		var angle := TAU * index / 4.0 + PI / 4.0
		var at := Vector3(cos(angle) * ring, 0.0, sin(angle) * ring)
		var facing := Basis(Vector3.UP, atan2(-at.x, -at.z))
		var color := PartyKit.PALETTE[(index * 2 + 1) % PartyKit.PALETTE.size()]
		add_child(PartyKit.stand(_crowd, Transform3D(facing, at), STAND_WIDTH, STAND_TIERS, color, _rng))
		for side: float in [-1.0, 1.0]:
			var tie := at + facing * Vector3(side * (STAND_WIDTH / 2.0 + 1.0), 0.6, 0.0)
			for balloon in 4:
				balloons.add(tie, _rng.randf_range(4.5, 8.5), _rng.randf_range(0.9, 1.3),
					PartyKit.PALETTE[(index + balloon) % PartyKit.PALETTE.size()], _rng.randf() * TAU)
	_crowd.commit()
	balloons.commit()


#The far scenery: a rainbow and a big wheel
func _build_backdrop() -> void:
	var rainbow := PartyKit.rainbow(_radius * 1.5, 2.6, [PartyKit.PINK, PartyKit.ORANGE, PartyKit.YELLOW, PartyKit.GREEN, PartyKit.CYAN, PartyKit.VIOLET])
	rainbow.position = Vector3(0.0, -26.0, -_radius * 2.3)
	add_child(rainbow)
	var wheel := FerrisWheel.new()
	wheel.position = Vector3(-_radius * 1.75, 0.0, -_radius * 0.9)
	wheel.rotation.y = atan2(_radius * 1.75, _radius * 0.9)
	add_child(wheel)
	wheel.build(15.0, PartyKit.PALETTE)
