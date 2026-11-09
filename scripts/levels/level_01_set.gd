class_name Level01Set
extends Node3D

#The set around the feed race: candy pillars with sweeping beams and bunting along both sides, grandstands with a cheering crowd,
#a gantry with traffic lights over the start, confetti cannons and stands at the goal, balloons, a big wheel and a rainbow.
#It is all scenery: nothing collides and nothing touches the rules

const SIDE_X := 72.0
const PILLAR_BASE := -34.0
const PILLAR_SIZE := 1.8
const PILLAR_Z: Array[float] = [186.0, 152.0, 118.0, 84.0, 50.0, 16.0, -18.0, -52.0, -86.0, -120.0, -154.0]
const STAND_X := 58.0
const STAND_Z: Array[float] = [150.0, 100.0, 50.0, 0.0, -50.0, -100.0]
#How far under the island tops the grandstands stand
const STAND_DROP := 2.2
const STAND_WIDTH := 20.0
const STAND_TIERS := 4
const GATE_HALF_WIDTH := 6.2
const GATE_HEIGHT := 6.4
const CHEER_TIME := 1.6
const HEADING_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
#Islands that have balloons tied to their rim, and how many
const BALLOON_ISLANDS: Array[StringName] = [&"D", &"G", &"H", &"J", &"K", &"A", &"C"]
const BALLOON_COUNT := 4
#The big wheels far from the course: where each stands, how big it is and the point on the course it looks at (x, z)
const WHEELS: Array[Dictionary] = [
	{"at": Vector3(-118.0, -8.0, -78.0), "radius": 21.0, "facing": Vector2(118.0, 20.0)},
	{"at": Vector3(122.0, -14.0, 96.0), "radius": 18.0, "facing": Vector2(-122.0, -30.0)},
]
#The wave of the crowd: how long it takes to cross the course, the rest before the next one, where it starts and ends and how high the fans stand
const WAVE_TIME := 12.0
const WAVE_REST := 6.0
const WAVE_FROM := 175.0
const WAVE_TO := -135.0
const WAVE_LIFT := 0.55

var _rng := RandomNumberGenerator.new()
var _crowd: CrowdField
var _cannons: Array[Node3D] = []
var _beams: Array[Dictionary] = []
var _lights: Array[MeshInstance3D] = []
var _light_materials: Array[StandardMaterial3D] = []
var _cheer: Tween
var _clock := 0.0
var _gate_at := Vector3.ZERO


func build() -> void:
	_rng.seed = 41
	_build_pillars()
	_build_stands()
	_build_gate()
	_build_goal()
	_build_balloons()
	_build_backdrop()


#The crowd jumps higher for a moment
func cheer(power: float) -> void:
	if _cheer != null and _cheer.is_valid():
		_cheer.kill()
	_crowd.set_excitement(power)
	_cheer = create_tween()
	_cheer.tween_method(_crowd.set_excitement, power, 1.0, CHEER_TIME).set_ease(Tween.EASE_OUT)


#Somebody got to the goal: confetti and a roar
func celebrate() -> void:
	for cannon in _cannons:
		var muzzle := cannon.get_node("Muzzle") as Marker3D
		ImpactFx.confetti(self, muzzle.global_position, 90, 50.0, 9.0)
	cheer(3.0)


#The three lights of the gantry: "count" of them red while the countdown runs, all green on "go"
func set_start_lights(count: int, go: bool) -> void:
	if go:
		#The gantry throws confetti the moment the lights turn green
		for side: float in [-1.0, 1.0]:
			ImpactFx.confetti(self, _gate_at + Vector3(side * GATE_HALF_WIDTH, GATE_HEIGHT, 0.0), 60, 60.0, 8.0)
	for index in _lights.size():
		var color := Color("3fe08a") if go else (Color("ff3b4f") if index < count else Color("3a3358"))
		_light_materials[index].albedo_color = color
		_light_materials[index].emission = color
		_light_materials[index].emission_energy_multiplier = 0.0 if (not go and index >= count) else 2.2


func _process(delta: float) -> void:
	_clock += delta
	var phase := fposmod(_clock, WAVE_TIME + WAVE_REST)
	if _crowd != null:
		_crowd.set_wave(lerpf(WAVE_FROM, WAVE_TO, clampf(phase / WAVE_TIME, 0.0, 1.0)), WAVE_LIFT if phase < WAVE_TIME else 0.0)
	for entry in _beams:
		var pivot: Node3D = entry["pivot"]
		var wave: float = _clock * entry["speed"] + entry["phase"]
		pivot.basis = (entry["lean"] as Basis) * Basis(Vector3.RIGHT, sin(wave) * 0.3) * Basis(Vector3.BACK, cos(wave * 0.8) * 0.3)


#Candy pillars down both sides of the course; every other one throws a beam over it
func _build_pillars() -> void:
	for side: float in [-1.0, 1.0]:
		var tops: Array[Vector3] = []
		for index in PILLAR_Z.size():
			var top := Level01Layout.height_at(PILLAR_Z[index]) + 20.0 + (index % 2) * 6.0
			var color := PartyKit.PALETTE[(index + (0 if side < 0.0 else 3)) % PartyKit.PALETTE.size()]
			var pillar := PartyKit.pillar(top - PILLAR_BASE, PILLAR_SIZE, color, PartyKit.WHITE)
			pillar.position = Vector3(side * SIDE_X, PILLAR_BASE, PILLAR_Z[index])
			add_child(pillar)
			tops.append(Vector3(pillar.position.x, top, pillar.position.z))
			if index % 2 == 0:
				var pivot := Node3D.new()
				pivot.position = tops[index] + Vector3(0.0, PILLAR_SIZE * 1.3, 0.0)
				pivot.add_child(PartyKit.beam(color.lerp(Color.WHITE, 0.35), 70.0, 4.2, 0.4))
				add_child(pivot)
				_beams.append({"pivot": pivot, "phase": _rng.randf() * TAU, "speed": _rng.randf_range(0.4, 0.8),
					"lean": Basis(Quaternion(Vector3.UP, (Vector3(-side, 0.0, 0.0) * 0.45 + Vector3.UP).normalized()))})
		for index in tops.size() - 1:
			var rope := PartyKit.bunting(tops[index] + Vector3(0.0, -2.6, 0.0), tops[index + 1] + Vector3(0.0, -2.6, 0.0), 3.0, 16, 1.9, PartyKit.PALETTE)
			add_child(rope)


#Grandstands along both sides, facing the course
func _build_stands() -> void:
	_crowd = CrowdField.new()
	add_child(_crowd)
	for side: float in [-1.0, 1.0]:
		for index in STAND_Z.size():
			var at := Vector3(side * STAND_X, Level01Layout.height_at(STAND_Z[index]) - STAND_DROP, STAND_Z[index])
			var place := Transform3D(Basis(Vector3.UP, -side * PI / 2.0), at)
			var color := PartyKit.PALETTE[(index * 2 + (0 if side < 0.0 else 1)) % PartyKit.PALETTE.size()]
			var stand := PartyKit.stand(_crowd, place, STAND_WIDTH, STAND_TIERS, color, _rng)
			add_child(stand)
	#Two more behind the goal, facing the racers that come
	var goal: Vector3 = Level01Layout.POSITIONS[Level01Layout.GOAL]
	for side: float in [-1.0, 1.0]:
		var place := Transform3D(Basis.IDENTITY, Vector3(side * 13.0, goal.y - STAND_DROP, goal.z - 13.0))
		var stand := PartyKit.stand(_crowd, place, 16.0, 4, PartyKit.PALETTE[(3 if side > 0.0 else 0) + 1], _rng)
		add_child(stand)
	_crowd.commit()


#A gantry over the start: two candy columns, a banner with the name and three lights that follow the countdown
func _build_gate() -> void:
	var start: Vector3 = Level01Layout.POSITIONS[Level01Layout.START]
	var gate := Node3D.new()
	gate.position = start + Vector3(0.0, 0.0, -1.0)
	add_child(gate)
	for side: float in [-1.0, 1.0]:
		var column := PartyKit.pillar(GATE_HEIGHT, 0.55, PartyKit.PINK if side < 0.0 else PartyKit.CYAN, PartyKit.WHITE)
		column.position = Vector3(side * GATE_HALF_WIDTH, 0.0, 0.0)
		gate.add_child(column)
	var beam := MeshInstance3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(GATE_HALF_WIDTH * 2.0, 1.7, 0.45)
	beam.mesh = board
	beam.material_override = PartyKit.candy(PartyKit.YELLOW, PartyKit.WHITE, 22.0, 0.0, 0.0)
	beam.position = Vector3(0.0, GATE_HEIGHT + 0.2, 0.0)
	gate.add_child(beam)
	var plate := MeshInstance3D.new()
	var face := BoxMesh.new()
	face.size = Vector3(GATE_HALF_WIDTH * 1.35, 1.3, 0.5)
	plate.mesh = face
	plate.material_override = PartyKit.paint(PartyKit.INK, 0.0, 0.5)
	plate.position = Vector3(0.0, GATE_HEIGHT + 0.2, 0.0)
	gate.add_child(plate)
	for side: float in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "SALIDA"
		label.font = HEADING_FONT
		label.font_size = 150
		label.pixel_size = 0.0085
		label.modulate = PartyKit.WHITE
		label.outline_size = 18
		label.outline_modulate = PartyKit.INK
		label.position = Vector3(0.0, GATE_HEIGHT + 0.2, side * 0.27)
		label.rotation.y = 0.0 if side > 0.0 else PI
		gate.add_child(label)
	for index in 3:
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.42
		sphere.height = 0.84
		sphere.radial_segments = 14
		sphere.rings = 7
		var material := StandardMaterial3D.new()
		material.emission_enabled = true
		material.roughness = 0.3
		sphere.material = material
		bulb.mesh = sphere
		bulb.position = Vector3((index - 1) * 1.3, GATE_HEIGHT + 1.45, 0.0)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gate.add_child(bulb)
		_lights.append(bulb)
		_light_materials.append(material)
	_gate_at = gate.position
	set_start_lights(3, false)


#Cannons on each side of the goal arch
func _build_goal() -> void:
	var goal: Vector3 = Level01Layout.POSITIONS[Level01Layout.GOAL]
	for side: float in [-1.0, 1.0]:
		var cannon := PartyKit.cannon(PartyKit.PINK if side < 0.0 else PartyKit.CYAN, PartyKit.WHITE)
		cannon.position = goal + Vector3(side * 5.2, 0.0, -0.6)
		cannon.rotation.y = side * PI * 0.12
		add_child(cannon)
		_cannons.append(cannon)


#Balloons tied to the rim of some islands, on the outer side
func _build_balloons() -> void:
	var balloons := BalloonField.new()
	add_child(balloons)
	for id in BALLOON_ISLANDS:
		var centre: Vector3 = Level01Layout.POSITIONS[id]
		var outward := Vector3(signf(centre.x), 0.0, 0.0) if absf(centre.x) > 1.0 else Vector3(0.0, 0.0, 1.0)
		var tie := centre + outward * (Level01Layout.radius_of(id) - 0.6) + Vector3(0.0, 0.1, 0.0)
		for index in BALLOON_COUNT:
			var color := PartyKit.PALETTE[(index + int(absf(centre.z))) % PartyKit.PALETTE.size()]
			balloons.add(tie + Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4)), _rng.randf_range(5.0, 9.0),
				_rng.randf_range(0.9, 1.3), color, _rng.randf() * TAU)
	balloons.commit()


#A big wheel and a rainbow far from the course
func _build_backdrop() -> void:
	for entry in WHEELS:
		var wheel := FerrisWheel.new()
		wheel.position = entry["at"]
		wheel.rotation.y = atan2((entry["facing"] as Vector2).x, (entry["facing"] as Vector2).y)
		add_child(wheel)
		wheel.build(entry["radius"], PartyKit.PALETTE)
	var rainbow := PartyKit.rainbow(78.0, 3.4, [PartyKit.PINK, PartyKit.ORANGE, PartyKit.YELLOW, PartyKit.GREEN, PartyKit.CYAN, PartyKit.VIOLET])
	rainbow.position = Vector3(0.0, -30.0, -232.0)
	add_child(rainbow)
	var start_rainbow := PartyKit.rainbow(60.0, 2.8, [PartyKit.PINK, PartyKit.ORANGE, PartyKit.YELLOW, PartyKit.GREEN, PartyKit.CYAN, PartyKit.VIOLET])
	start_rainbow.position = Vector3(0.0, -26.0, 214.0)
	start_rainbow.rotation.y = PI
	add_child(start_rainbow)
