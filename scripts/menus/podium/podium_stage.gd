class_name PodiumStage
extends Node3D

#The stage of the end of the game at night: a round candy floor with its bulbs, a block per player in the colour of its crown with its place
#in big round numbers, a rainbow and an arch of bulbs behind, two stands of cheering fans, beams that sweep the sky, a spotlight over each
#block that lights up when its player arrives, confetti cannons and fireworks. The light of the whole stage can dim for the big reveal

const FLOOR_RADIUS := 12.0
const BLOCK_SIZE := Vector2(2.5, 2.1)
const BLOCK_CORNER := 0.4
const BACK := -6.5
const NIGHT := Color("140c2e")
const FLOOR_COLOR := Color("4a3590")
const RIM_COLOR := Color("ff7eb6")
#Colour of each crown, for its block, its light and its sparkles (by ScoreSheet.Medal)
const CROWN_COLORS: Array[Color] = [Color("8c7fb8"), Color("e08a4a"), Color("c9d4e6"), Color("ffc93a"), Color("7fe6ff")]
const WORD_COLOURS: Array[StringName] = [&"title", &"bronze", &"silver", &"gold", &"diamond"]
const FIREWORK_COLORS: Array[Color] = [Color("ff5c8a"), Color("ffd23f"), Color("3fd3ea"), Color("8a63f5"), Color("5fdc9c")]

var environment: Environment
var crowd: CrowdField

var _terrain: CandyTerrain
var _spots: Dictionary = {}
var _beams: Array[Node3D] = []
var _cannons: Array[Node3D] = []
var _key: DirectionalLight3D
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


#Builds everything for these entries (from PodiumPlan)
func build(entries: Array[PodiumPlan.Entry]) -> void:
	_rng.seed = 5
	_build_environment()
	_terrain = CandyTerrain.new(self)
	_terrain.island(CandyTerrain.circle(Vector2.ZERO, FLOOR_RADIUS, 64), 0.0, FLOOR_COLOR, RIM_COLOR)
	for entry in entries:
		_build_block(entry)
	_terrain.commit()
	_build_backdrop()
	_build_stands()
	_build_beams()
	for side: float in [-1.0, 1.0]:
		var cannon := PartyKit.cannon(PartyKit.PINK if side < 0.0 else PartyKit.CYAN, PartyKit.WHITE)
		cannon.position = Vector3(side * 8.6, 0.0, 2.6)
		cannon.rotation.y = side * 0.5
		add_child(cannon)
		_cannons.append(cannon)


func _process(delta: float) -> void:
	_clock += delta
	for index in _beams.size():
		var beam := _beams[index]
		beam.rotation.z = sin(_clock * 0.55 + index * 1.3) * 0.45
		beam.rotation.x = -0.25 + cos(_clock * 0.4 + index * 0.9) * 0.15


#The top of the block of a slot, where its player lands
func top_of(entry: PodiumPlan.Entry) -> Vector3:
	return Vector3(PodiumPlan.slot_x(entry.slot), entry.height, 0.0)


#The spotlight of a block goes on in the colour of its crown
func light_block(entry: PodiumPlan.Entry, energy := 7.0, seconds := 0.35) -> void:
	var spot: SpotLight3D = _spots.get(entry.slot)
	if spot == null:
		return
	spot.light_color = CROWN_COLORS[entry.crown].lerp(Color.WHITE, 0.35)
	create_tween().tween_property(spot, "light_energy", energy, seconds)


#The whole stage goes dark (1) or back to its light (0)
func dim(amount: float, seconds: float) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(environment, "ambient_light_energy", lerpf(0.55, 0.08, amount), seconds)
	tween.tween_property(_key, "light_energy", lerpf(0.75, 0.05, amount), seconds)
	tween.tween_property(environment, "background_energy_multiplier", lerpf(1.0, 0.35, amount), seconds)
	for beam in _beams:
		tween.tween_property(beam, "scale", Vector3.ONE * (1.0 - amount * 0.999), seconds)


func confetti() -> void:
	for cannon in _cannons:
		var muzzle := cannon.get_node("Muzzle") as Marker3D
		ImpactFx.confetti(self, muzzle.global_position, 120, 40.0, 13.0)


#A rocket bursts into a ball of sparks somewhere over the back of the stage
func firework() -> void:
	var at := Vector3(_rng.randf_range(-11.0, 11.0), _rng.randf_range(9.0, 14.0), BACK - _rng.randf_range(4.0, 10.0))
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 70
	sparks.lifetime = 1.6
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 5.0
	sparks.initial_velocity_max = 7.5
	sparks.gravity = Vector3(0.0, -3.0, 0.0)
	sparks.damping_min = 1.5
	sparks.damping_max = 2.5
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(0.7, 0.8))
	fade.add_point(Vector2(1.0, 0.0))
	sparks.scale_amount_curve = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	paint.albedo_texture = ImpactFx.star_texture()
	var color := FIREWORK_COLORS[_rng.randi() % FIREWORK_COLORS.size()]
	paint.albedo_color = color * 2.2
	quad.material = paint
	sparks.mesh = quad
	sparks.position = at
	add_child(sparks)
	sparks.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.omni_range = 16.0
	flash.light_energy = 3.0
	flash.position = at
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.8)
	tween.tween_interval(1.0)
	tween.tween_callback(sparks.queue_free)
	tween.tween_callback(flash.queue_free)
	SynthSound.play(self, SynthSound.crash(0.6), -16.0, _rng.randf_range(1.4, 1.9))


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = NIGHT
	sky_material.sky_horizon_color = Color("5a2f86")
	sky_material.ground_bottom_color = NIGHT
	sky_material.ground_horizon_color = Color("5a2f86")
	sky_material.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.55
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("3a2266")
	environment.fog_density = 0.006
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-50.0, 25.0, 0.0)
	_key.light_energy = 0.75
	_key.light_color = Color("c9c2ff")
	_key.shadow_enabled = true
	add_child(_key)
	#A warm light from the front so faces read
	var front := OmniLight3D.new()
	front.position = Vector3(0.0, 5.0, 9.0)
	front.omni_range = 18.0
	front.light_energy = 1.2
	front.light_color = Color("ffe4cc")
	add_child(front)


#A round block in the colour of its crown with its place in big round numbers on its front and a spotlight that waits over it
func _build_block(entry: PodiumPlan.Entry) -> void:
	var x := PodiumPlan.slot_x(entry.slot)
	var color := CROWN_COLORS[entry.crown]
	var outline := CandyTerrain.rounded_box(Vector2(x, 0.0), BLOCK_SIZE, BLOCK_CORNER)
	_terrain.platform(outline, entry.height, 0.0, color.darkened(0.08), color.lightened(0.5))
	var number := PuffyWord.make(StringName("n%d" % clampi(entry.place, 1, 4)), minf(entry.height * 0.55, 1.1), WORD_COLOURS[entry.crown])
	number.position = Vector3(x, entry.height * 0.5, BLOCK_SIZE.y / 2.0 + 0.2)
	add_child(number)
	var spot := SpotLight3D.new()
	spot.position = Vector3(x, entry.height + 9.0, 3.5)
	spot.spot_range = 16.0
	spot.spot_angle = 16.0
	spot.light_energy = 0.0
	add_child(spot)
	spot.look_at(Vector3(x, entry.height, 0.0))
	_spots[entry.slot] = spot


#Behind the blocks: a rainbow, two candy pillars and an arch of bulbs between them
func _build_backdrop() -> void:
	var rainbow := PartyKit.rainbow(9.5, 0.75, [PartyKit.PINK, PartyKit.ORANGE, PartyKit.YELLOW, PartyKit.GREEN, PartyKit.CYAN, PartyKit.VIOLET])
	rainbow.position = Vector3(0.0, 0.0, BACK - 1.5)
	add_child(rainbow)
	for side: float in [-1.0, 1.0]:
		var pillar := PartyKit.pillar(8.5, 0.6, PartyKit.PINK if side < 0.0 else PartyKit.CYAN, PartyKit.WHITE)
		pillar.position = Vector3(side * 10.0, 0.0, BACK)
		add_child(pillar)
	var arch := PackedVector3Array()
	for step in 25:
		var angle := PI * step / 24.0
		arch.append(Vector3(-cos(angle) * 10.0, 8.5 + sin(angle) * 2.2, BACK))
	_terrain = CandyTerrain.new(self)
	_terrain.rail(arch, PartyKit.YELLOW, true, 0.3)
	_terrain.commit()


#Two stands of fans on the sides, turned toward the blocks
func _build_stands() -> void:
	crowd = CrowdField.new()
	add_child(crowd)
	for side: float in [-1.0, 1.0]:
		var place := Transform3D(Basis(Vector3.UP, side * -1.05), Vector3(side * 15.5, 0.0, 3.0))
		add_child(PartyKit.stand(crowd, place, 9.0, 4, PartyKit.VIOLET if side < 0.0 else PartyKit.PINK, _rng))
	crowd.commit()


#Beams from the floor behind the stage that sweep the sky
func _build_beams() -> void:
	for index in 6:
		var holder := Node3D.new()
		holder.position = Vector3(-11.0 + index * 4.4, 0.2, BACK - 2.5)
		add_child(holder)
		holder.add_child(PartyKit.beam(FIREWORK_COLORS[index % FIREWORK_COLORS.size()], 30.0, 2.4, 0.22))
		_beams.append(holder)
