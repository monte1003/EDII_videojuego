class_name Level01TrapView
extends Node3D

#Draws the Level01Traps obstacles where the clock says

const STORY_SHADER: Shader = preload("res://assets/shaders/story_tile.gdshader")
const SKY := Color("62b7ff")
const VIOLET := Color("a584ff")
const TANGERINE := Color("ffa84f")
const LIME := Color("86e05f")
const ROSE := Color("ff7fb2")
const AQUA := Color("4fd3e8")
const INK := Color("2a2145")
#Side colour of the comment letters
const WORD_SIDE := Color("4636a3")
#Axe rod radius, gantry pillar offset and fan streak count
const ROD_RADIUS := 0.09
const GANTRY_OUT := 0.55
const STREAKS := 9
const FAN_RADIUS := 1.75
const FAN_LIFT := 1.95

#Per axe row: {"row", "pivots"}
var _axes: Array[Dictionary] = []
#Per puncher: fist, arm, housing, flash and base
var _punchers: Array[Dictionary] = []
#Per run: index, pool and lane materials
var _runs: Array[Dictionary] = []
#Per fan: blades, ring, streaks and arrows
var _fans: Array[Dictionary] = []
#Plate id -> tiles with body, view, top and shown flag
var _tiles: Dictionary = {}
var _terrain: CandyTerrain
var _rng := RandomNumberGenerator.new()


func build(tiles: Level01Tiles) -> void:
	_rng.seed = 7
	_terrain = CandyTerrain.new(self)
	for row: Dictionary in Level01Layout.AXES:
		_build_axes(row)
	for puncher: Dictionary in Level01Layout.PUNCHERS:
		_build_puncher(puncher)
	for index in Level01Layout.RUNS.size():
		_build_run(Level01Layout.RUNS[index], index)
	for fan: Dictionary in Level01Layout.FANS:
		_build_fan(fan)
	for plate: StringName in Level01Layout.TILE_PLATES:
		_build_tiles(plate)
	_terrain.commit()
	StaticBatch.join(self, _moving_nodes(), false)
	tiles.tile_dropped.connect(_on_tile_dropped)
	tiles.tile_back.connect(_on_tile_back)


#Nodes that move or hide by themselves
func _moving_nodes() -> Array[Node]:
	var found: Array[Node] = []
	var lists: Array = [_axes, _punchers, _runs, _fans]
	for plate: StringName in _tiles:
		lists.append(_tiles[plate])
	for list: Array in lists:
		for entry: Dictionary in list:
			_collect(entry, found)
	return found


func _collect(value: Variant, found: Array[Node]) -> void:
	if value is Node:
		found.append(value)
	elif value is Array:
		for item: Variant in value:
			_collect(item, found)
	elif value is Dictionary:
		for item: Variant in (value as Dictionary).values():
			_collect(item, found)


#Puts everything at "time"; "tiles" gives each tile's shake
func update(time: float, tiles: Level01Tiles) -> void:
	for entry in _axes:
		var row: Dictionary = entry["row"]
		var pivots: Array = entry["pivots"]
		for index in pivots.size():
			(pivots[index] as Node3D).rotation.z = Level01Traps.axe_angle(row, index, time)
	for entry in _punchers:
		_place_puncher(entry, time)
	for entry in _runs:
		_place_run(entry, time)
	for entry in _fans:
		_place_fan(entry, time)
	for plate: StringName in _tiles:
		var list: Array = _tiles[plate]
		for index in list.size():
			var tile: Dictionary = list[index]
			var share := tiles.shake_share(plate, index)
			var top: MeshInstance3D = tile["top"]
			top.set_instance_shader_parameter("drain", share)
			top.set_instance_shader_parameter("flash", 0.55 * absf(sin(time * 26.0)) * share)
			if tile["shown"] and tiles.state_of(plate, index) == Level01Tiles.State.SHAKING:
				var view: Node3D = tile["view"]
				view.position = Vector3(sin(time * 51.0), 0.0, cos(time * 47.0)) * 0.05 * share


#Candy gantry over the bridge with striped rods ending in comments
func _build_axes(row: Dictionary) -> void:
	var frame := Level01Traps.bridge_frame(row["edge"])
	var spots := Level01Traps.axe_spots(row)
	var along: Vector3 = frame["along"]
	var across: Vector3 = frame["across"]
	var floor_y: float = frame["floor"]
	var half := float(frame["width"]) / 2.0 + GANTRY_OUT
	var top := floor_y + Level01Layout.AXE_PIVOT
	var ends: Array[Vector3] = [spots[0] - along * 1.9, spots[-1] + along * 1.9]
	for end in ends:
		for side: float in [-1.0, 1.0]:
			var pillar := PartyKit.pillar(Level01Layout.AXE_PIVOT + Level01Layout.DECK_DEPTH + 0.5, 0.32, SKY, PartyKit.WHITE)
			pillar.position = end + across * side * half + Vector3(0.0, -Level01Layout.DECK_DEPTH, 0.0)
			add_child(pillar)
		var left := end - across * half + Vector3(0.0, Level01Layout.AXE_PIVOT + 0.25, 0.0)
		var right := end + across * half + Vector3(0.0, Level01Layout.AXE_PIVOT + 0.25, 0.0)
		_terrain.rail(PackedVector3Array([left, (left + right) / 2.0 + Vector3(0.0, 0.45, 0.0), right]), PartyKit.PINK, true)
	_terrain.rail(PackedVector3Array([Vector3(ends[0].x, top + 0.2, ends[0].z), Vector3(ends[1].x, top + 0.2, ends[1].z)]), SKY, false)
	var words: Array = row["words"]
	var pivots: Array[Node3D] = []
	for index in spots.size():
		var pivot := Node3D.new()
		pivot.position = Vector3(spots[index].x, top, spots[index].z)
		pivot.basis = Basis(across, Vector3.UP, -along)
		add_child(pivot)
		var hub := MeshInstance3D.new()
		var knob := SphereMesh.new()
		knob.radius = 0.28
		knob.height = 0.56
		knob.radial_segments = 12
		knob.rings = 6
		hub.mesh = knob
		hub.material_override = PartyKit.paint(PartyKit.YELLOW, 0.6, 0.3)
		pivot.add_child(hub)
		var rod := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = ROD_RADIUS
		stick.bottom_radius = ROD_RADIUS
		stick.height = Level01Layout.AXE_ROD - Level01Layout.AXE_BLADE.y / 2.0
		stick.radial_segments = 8
		stick.rings = 1
		rod.mesh = stick
		rod.material_override = PartyKit.candy(PartyKit.WHITE, PartyKit.PINK, 2.0, 18.0)
		rod.position.y = -stick.height / 2.0
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(rod)
		var blade := PropKit.make(&"bubble", Level01Layout.AXE_BLADE)
		blade.position.y = -Level01Layout.AXE_ROD - Level01Layout.AXE_BLADE.y / 2.0
		pivot.add_child(blade)
		#The word faces whoever comes along the bridge
		var word := Word3D.make(String(words[index % words.size()]), 0.95, Level01Layout.AXE_BLADE.x * 0.78, WORD_SIDE, 0.2)
		word.position = Vector3(0.0, -Level01Layout.AXE_ROD + 0.08, Level01Layout.AXE_BLADE.z / 2.0 + 0.02)
		pivot.add_child(word)
		pivots.append(pivot)
	_axes.append({"row": row, "pivots": pivots})


#Puncher: candy barrel on a pillar with a spring arm ending in a like
func _build_puncher(puncher: Dictionary) -> void:
	var frame := Level01Traps.bridge_frame(puncher["edge"])
	var side := float(puncher["side"])
	var across: Vector3 = frame["across"]
	var along: Vector3 = frame["along"]
	var along_at := lerpf(float(frame["start"]), float(frame["end"]), float(puncher["at"]))
	var rest := float(frame["width"]) / 2.0 + Level01Layout.PUNCH_FIST.z / 2.0
	var base := Level01Traps.bridge_point(frame, along_at, side * (rest + 1.25))
	var pillar := PartyKit.pillar(Level01Layout.DECK_DEPTH + 0.1, 0.36, ROSE, PartyKit.WHITE)
	pillar.position = base + Vector3(0.0, -Level01Layout.DECK_DEPTH, 0.0)
	add_child(pillar)
	var centre := base + Vector3(0.0, 0.85, 0.0)
	var flash := StandardMaterial3D.new()
	flash.albedo_color = ROSE
	flash.roughness = 0.35
	flash.emission_enabled = true
	flash.emission = ROSE
	flash.emission_energy_multiplier = 0.15
	var barrel := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = 0.82
	drum.bottom_radius = 0.9
	drum.height = 1.0
	drum.radial_segments = 24
	drum.rings = 1
	barrel.mesh = drum
	barrel.material_override = flash
	barrel.transform = PartyKit.stretch(centre + across * side * 0.8, centre - across * side * 0.8)
	add_child(barrel)
	#White bands and a bright mouth ring
	for share: float in [-0.55, 0.0, 0.55]:
		var band := MeshInstance3D.new()
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.84
		hoop.outer_radius = 0.98
		hoop.rings = 24
		hoop.ring_segments = 6
		band.mesh = hoop
		band.material_override = PartyKit.paint(PartyKit.WHITE if share != -0.55 else PartyKit.YELLOW, 0.3 if share != -0.55 else 1.2, 0.35)
		band.transform = PartyKit.stretch(centre - across * side * (share * 1.2 + 0.0), centre - across * side * (share * 1.2 + 0.01))
		band.transform.basis = band.transform.basis.orthonormalized()
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(band)
	var heart := PropKit.make_tall(&"heart", 0.95, Color.WHITE, false)
	heart.position = centre + Vector3(0.0, 0.82, 0.0)
	heart.rotation.y = atan2(-along.x, -along.z)
	add_child(heart)
	var arm := MeshInstance3D.new()
	var spring := CylinderMesh.new()
	spring.top_radius = 0.2
	spring.bottom_radius = 0.2
	spring.height = 1.0
	spring.radial_segments = 10
	spring.rings = 1
	arm.mesh = spring
	arm.material_override = PartyKit.candy(PartyKit.WHITE, ROSE, 2.0, 10.0)
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arm)
	var fist := Node3D.new()
	add_child(fist)
	var hand := PropKit.make_tall(&"like_hand", Level01Layout.PUNCH_FIST.y)
	hand.rotation.y = atan2(-across.x * side, -across.z * side)
	fist.add_child(hand)
	_punchers.append({"puncher": puncher, "fist": fist, "arm": arm, "flash": flash, "base": centre})


func _place_puncher(entry: Dictionary, time: float) -> void:
	var puncher: Dictionary = entry["puncher"]
	var fist: Node3D = entry["fist"]
	var at := Level01Traps.punch_fist(puncher, time)
	if Level01Traps.punch_winding(puncher, time):
		at += Vector3(sin(time * 61.0), 0.0, cos(time * 57.0)) * 0.05
	fist.position = at
	var flash: StandardMaterial3D = entry["flash"]
	flash.emission_energy_multiplier = 0.15 + (1.3 * absf(sin(time * 22.0)) if Level01Traps.punch_winding(puncher, time) else 0.0)
	var from: Vector3 = entry["base"]
	var to := at + Vector3(0.0, 0.75, 0.0)
	var arm: MeshInstance3D = entry["arm"]
	var length := from.distance_to(to)
	arm.visible = length > 0.2
	if arm.visible:
		arm.transform = PartyKit.stretch(from, to)


#Run: floor slots, lit lanes and a pool of wheels or balls
func _build_run(run: Dictionary, index: int) -> void:
	var line := Level01Layout.run_line(run)
	var along: Vector3 = line["along"]
	var across: Vector3 = line["across"]
	var rolls: bool = run["kind"] == Level01Layout.ROLLER
	var color := VIOLET if rolls else TANGERINE
	var lanes: Array[float] = []
	if rolls:
		lanes.append_array([-(Level01Layout.ROLLER_LENGTH / 2.0 + 0.05), Level01Layout.ROLLER_LENGTH / 2.0 + 0.05])
	else:
		lanes.append_array(Level01Layout.BOULDER_LANES)
	var lane_paint: Array[StandardMaterial3D] = []
	for lane in lanes:
		for end: Vector3 in [line["from"], line["to"]]:
			var slot := MeshInstance3D.new()
			slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if rolls:
				var groove := BoxMesh.new()
				groove.size = Vector3(Level01Layout.ROLLER_LENGTH + 0.2, 0.04, 1.1)
				slot.mesh = groove
				slot.basis = Basis(across, Vector3.UP, -along)
			else:
				var hole := CylinderMesh.new()
				hole.top_radius = Level01Layout.BOULDER_RADIUS + 0.2
				hole.bottom_radius = hole.top_radius
				hole.height = 0.04
				hole.radial_segments = 28
				hole.rings = 1
				slot.mesh = hole
			slot.material_override = PartyKit.paint(INK, 0.0, 0.8)
			slot.position = end + across * lane + Vector3(0.0, 0.02, 0.0)
			add_child(slot)
			var rim := MeshInstance3D.new()
			rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if rolls:
				var glow := BoxMesh.new()
				glow.size = Vector3(Level01Layout.ROLLER_LENGTH + 0.5, 0.03, 1.4)
				rim.mesh = glow
				rim.basis = slot.basis
			else:
				var band := TorusMesh.new()
				band.inner_radius = Level01Layout.BOULDER_RADIUS + 0.18
				band.outer_radius = Level01Layout.BOULDER_RADIUS + 0.42
				band.rings = 28
				band.ring_segments = 6
				rim.mesh = band
			rim.material_override = PartyKit.paint(color, 1.2, 0.4)
			rim.position = end + across * lane + Vector3(0.0, 0.012, 0.0)
			add_child(rim)
		if not rolls:
			#A giant ball lane lights up before one comes
			var strip := MeshInstance3D.new()
			var sheet := BoxMesh.new()
			sheet.size = Vector3(2.3, 0.02, float(line["length"]) - 2.0 * (Level01Layout.BOULDER_RADIUS + 0.45))
			strip.mesh = sheet
			var paint := StandardMaterial3D.new()
			paint.albedo_color = Color(TANGERINE, 0.22)
			paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			paint.emission_enabled = true
			paint.emission = TANGERINE
			paint.emission_energy_multiplier = 0.1
			strip.material_override = paint
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			strip.basis = Basis.looking_at(along, Vector3.UP)
			strip.position = ((line["from"] as Vector3) + (line["to"] as Vector3)) / 2.0 + across * lane + Vector3(0.0, 0.025, 0.0)
			add_child(strip)
			lane_paint.append(paint)
	var pool: Array[MeshInstance3D] = []
	var count := (ceili(Level01Traps.run_travel(run) / float(run["every"])) + 1) * 2
	for _slot in count:
		var thing := MeshInstance3D.new()
		if rolls:
			var wheel := CylinderMesh.new()
			wheel.top_radius = Level01Layout.ROLLER_RADIUS
			wheel.bottom_radius = Level01Layout.ROLLER_RADIUS
			wheel.height = Level01Layout.ROLLER_LENGTH
			wheel.radial_segments = 24
			wheel.rings = 1
			thing.mesh = wheel
			thing.material_override = PartyKit.candy(PartyKit.WHITE, VIOLET, 8.0)
			#Golden rims like a mouse wheel
			for end: float in [-1.0, 1.0]:
				var rim := MeshInstance3D.new()
				var hoop := TorusMesh.new()
				hoop.inner_radius = Level01Layout.ROLLER_RADIUS - 0.06
				hoop.outer_radius = Level01Layout.ROLLER_RADIUS + 0.07
				hoop.rings = 20
				hoop.ring_segments = 6
				rim.mesh = hoop
				rim.material_override = PartyKit.paint(PartyKit.YELLOW, 0.6, 0.3)
				rim.position.y = end * (Level01Layout.ROLLER_LENGTH / 2.0 - 0.05)
				rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				thing.add_child(rim)
		else:
			var ball := SphereMesh.new()
			ball.radius = Level01Layout.BOULDER_RADIUS
			ball.height = Level01Layout.BOULDER_RADIUS * 2.0
			ball.radial_segments = 24
			ball.rings = 12
			thing.mesh = ball
			thing.material_override = PartyKit.candy(Color("fff4e6"), TANGERINE, 6.0, 3.0)
		thing.hide()
		add_child(thing)
		pool.append(thing)
	_runs.append({"run": run, "index": index, "pool": pool, "lanes": lane_paint, "lane_offsets": lanes})


func _place_run(entry: Dictionary, time: float) -> void:
	var run: Dictionary = entry["run"]
	var index: int = entry["index"]
	var pool: Array = entry["pool"]
	var line := Level01Layout.run_line(run)
	var along: Vector3 = line["along"]
	var across: Vector3 = line["across"]
	var rolls: bool = run["kind"] == Level01Layout.ROLLER
	var radius := Level01Layout.ROLLER_RADIUS if rolls else Level01Layout.BOULDER_RADIUS
	var used := 0
	for item in Level01Traps.run_items(run, index, time):
		for lane: float in item["lanes"]:
			if used >= pool.size():
				break
			var thing: MeshInstance3D = pool[used]
			used += 1
			thing.show()
			var turn := Basis(Vector3.UP.cross(along).normalized(), float(item["along"]) / radius)
			if rolls:
				turn = turn * Basis(along, across, along.cross(across))
			thing.global_transform = Transform3D(turn, Level01Traps.run_point(run, float(item["along"]), lane, float(item["lift"])))
	for slot in range(used, pool.size()):
		(pool[slot] as MeshInstance3D).hide()
	var lanes: Array = entry["lanes"]
	var offsets: Array = entry["lane_offsets"]
	for lane in lanes.size():
		var warning := Level01Traps.lane_warning(run, index, float(offsets[lane]), time)
		var paint: StandardMaterial3D = lanes[lane]
		paint.emission_energy_multiplier = 0.1 + 1.6 * warning * (0.6 + 0.4 * absf(sin(time * 18.0)))
		paint.albedo_color.a = 0.22 + 0.35 * warning


#Fan: lime turbine with grill and blades, wind streaks and floor arrows
func _build_fan(fan: Dictionary) -> void:
	var frame := Level01Traps.bridge_frame(fan["edge"])
	var side := float(fan["side"])
	var across: Vector3 = frame["across"]
	var middle := lerpf(float(frame["start"]), float(frame["end"]), 0.5)
	var centre := Level01Traps.bridge_point(frame, middle, side * (float(frame["width"]) / 2.0 + 1.2)) + Vector3(0.0, FAN_LIFT, 0.0)
	var facing := -across * side
	var stand := PartyKit.pillar(Level01Layout.DECK_DEPTH + FAN_LIFT - FAN_RADIUS + 0.2, 0.45, LIME, PartyKit.WHITE)
	stand.position = centre + Vector3(0.0, -FAN_LIFT - Level01Layout.DECK_DEPTH, 0.0)
	add_child(stand)
	var holder := Node3D.new()
	holder.position = centre
	holder.basis = Basis.looking_at(facing, Vector3.UP)
	add_child(holder)
	var ring_paint := StandardMaterial3D.new()
	ring_paint.albedo_color = LIME
	ring_paint.roughness = 0.35
	ring_paint.emission_enabled = true
	ring_paint.emission = LIME
	ring_paint.emission_energy_multiplier = 0.3
	#Turbine tube painted inside too
	var tube := MeshInstance3D.new()
	var shell := CylinderMesh.new()
	shell.top_radius = FAN_RADIUS + 0.1
	shell.bottom_radius = FAN_RADIUS + 0.25
	shell.height = 1.1
	shell.radial_segments = 32
	shell.rings = 1
	shell.cap_top = false
	shell.cap_bottom = false
	tube.mesh = shell
	var tube_paint := PartyKit.candy(PartyKit.WHITE, LIME, 16.0)
	tube.material_override = tube_paint
	tube.rotation.x = PI / 2.0
	holder.add_child(tube)
	var inside := MeshInstance3D.new()
	var lining := CylinderMesh.new()
	lining.top_radius = FAN_RADIUS + 0.05
	lining.bottom_radius = FAN_RADIUS + 0.2
	lining.height = 1.08
	lining.radial_segments = 32
	lining.rings = 1
	lining.cap_top = false
	lining.cap_bottom = false
	inside.mesh = lining
	var lining_paint := StandardMaterial3D.new()
	lining_paint.albedo_color = Color("2f6e3a")
	lining_paint.cull_mode = BaseMaterial3D.CULL_FRONT
	inside.material_override = lining_paint
	inside.rotation.x = PI / 2.0
	holder.add_child(inside)
	for front: float in [-0.56, 0.56]:
		var lip := MeshInstance3D.new()
		var band := TorusMesh.new()
		band.inner_radius = FAN_RADIUS
		band.outer_radius = FAN_RADIUS + 0.38
		band.rings = 32
		band.ring_segments = 8
		lip.mesh = band
		lip.material_override = ring_paint
		lip.rotation.x = PI / 2.0
		lip.position.z = front
		holder.add_child(lip)
	#Grill: two rings and four spokes
	var grill_paint := PartyKit.paint(PartyKit.WHITE, 0.2, 0.3)
	for radius: float in [FAN_RADIUS * 0.45, FAN_RADIUS * 0.9]:
		var wire := MeshInstance3D.new()
		var circle := TorusMesh.new()
		circle.inner_radius = radius - 0.035
		circle.outer_radius = radius + 0.035
		circle.rings = 28
		circle.ring_segments = 4
		wire.mesh = circle
		wire.material_override = grill_paint
		wire.rotation.x = PI / 2.0
		wire.position.z = -0.5
		wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(wire)
	for step in 4:
		var spoke := MeshInstance3D.new()
		var rod := BoxMesh.new()
		rod.size = Vector3(0.06, FAN_RADIUS * 1.8, 0.06)
		spoke.mesh = rod
		spoke.material_override = grill_paint
		spoke.rotation.z = PI / 4.0 * step
		spoke.position.z = -0.5
		spoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(spoke)
	var blades := Node3D.new()
	holder.add_child(blades)
	var blade_paint := PartyKit.candy(PartyKit.WHITE, PartyKit.YELLOW, 1.0)
	for step in 5:
		var blade := MeshInstance3D.new()
		var vane := BoxMesh.new()
		vane.size = Vector3(0.62, FAN_RADIUS - 0.35, 0.07)
		blade.mesh = vane
		blade.material_override = blade_paint
		blade.position = Vector3(0.0, (FAN_RADIUS - 0.35) / 2.0 + 0.2, 0.0)
		blade.rotation.y = 0.45
		var arm := Node3D.new()
		arm.rotation.z = TAU * step / 5.0
		arm.add_child(blade)
		blades.add_child(arm)
	var hub := MeshInstance3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.4
	cap.height = 0.8
	cap.radial_segments = 14
	cap.rings = 7
	hub.mesh = cap
	hub.material_override = PartyKit.paint(PartyKit.PINK, 0.4, 0.3)
	blades.add_child(hub)
	var streak_paint := StandardMaterial3D.new()
	streak_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_paint.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	streak_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var streaks: Array[MeshInstance3D] = []
	for step in STREAKS:
		var streak := MeshInstance3D.new()
		var line := BoxMesh.new()
		line.size = Vector3(0.06, 0.06, 1.9)
		streak.mesh = line
		streak.material_override = streak_paint
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.hide()
		add_child(streak)
		streaks.append(streak)
	#Three floor arrows along the wind
	var arrow_paint := StandardMaterial3D.new()
	arrow_paint.albedo_color = Color(LIME, 0.5)
	arrow_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arrow_paint.emission_enabled = true
	arrow_paint.emission = LIME
	arrow_paint.emission_energy_multiplier = 0.2
	var head := PrismMesh.new()
	head.size = Vector3(1.6, 1.2, 0.04)
	for step in 3:
		var arrow := MeshInstance3D.new()
		arrow.mesh = head
		arrow.material_override = arrow_paint
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.position = Level01Traps.bridge_point(frame, middle + (step - 1) * 2.0, -side * 0.6) + Vector3(0.0, 0.03, 0.0)
		arrow.basis = Basis.looking_at(facing, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2.0)
		add_child(arrow)
	_fans.append({"fan": fan, "blades": blades, "ring": ring_paint, "streaks": streaks, "arrows": arrow_paint, "frame": frame,
		"spin": 0.0, "seeds": _streak_seeds(), "facing": facing})


func _streak_seeds() -> Array[Vector3]:
	var seeds: Array[Vector3] = []
	for _step in STREAKS:
		seeds.append(Vector3(_rng.randf(), _rng.randf_range(0.3, 2.6), _rng.randf()))
	return seeds


func _place_fan(entry: Dictionary, time: float) -> void:
	var fan: Dictionary = entry["fan"]
	var spin := Level01Traps.fan_spin(fan, time)
	var blowing := Level01Traps.fan_blowing(fan, time)
	var blades: Node3D = entry["blades"]
	entry["spin"] = float(entry["spin"]) + spin * 0.33
	blades.rotation.z = float(entry["spin"])
	var warning := spin > 0.0 and not blowing
	(entry["ring"] as StandardMaterial3D).emission_energy_multiplier = 0.3 + (1.4 * absf(sin(time * 16.0)) if warning else (1.0 if blowing else 0.0))
	(entry["arrows"] as StandardMaterial3D).emission_energy_multiplier = 0.2 + (1.6 if blowing else (0.8 * absf(sin(time * 16.0)) if warning else 0.0))
	var frame: Dictionary = entry["frame"]
	var side := float(fan["side"])
	var width := float(frame["width"])
	var streaks: Array = entry["streaks"]
	var seeds: Array = entry["seeds"]
	var facing: Vector3 = entry["facing"]
	for step in streaks.size():
		var streak: MeshInstance3D = streaks[step]
		streak.visible = blowing
		if not blowing:
			continue
		var seed_point: Vector3 = seeds[step]
		var travel := fposmod(time * 1.6 + seed_point.z, 1.0)
		var along := lerpf(float(frame["start"]) + 0.5, float(frame["end"]) - 0.5, seed_point.x)
		var lateral := side * lerpf(width / 2.0 + 0.6, -width / 2.0 - 1.5, travel)
		streak.global_position = Level01Traps.bridge_point(frame, along, lateral) + Vector3(0.0, seed_point.y, 0.0)
		streak.basis = Basis.looking_at(facing, Vector3.UP)


#Story tiles, each a body that drops and returns on its own
func _build_tiles(plate: StringName) -> void:
	var list: Array[Dictionary] = []
	var side := Level01Layout.tile_side()
	var shape := BoxShape3D.new()
	shape.size = Vector3(side, 0.6, side)
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(side, 0.55, side)
	var top_mesh := PlaneMesh.new()
	top_mesh.size = Vector2(side - 0.02, side - 0.02)
	var story := ShaderMaterial.new()
	story.shader = STORY_SHADER
	for centre in Level01Layout.tile_centers(plate):
		var body := StaticBody3D.new()
		body.position = centre + Vector3(0.0, -0.3, 0.0)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
		var view := Node3D.new()
		body.add_child(view)
		var slab := MeshInstance3D.new()
		slab.mesh = body_mesh
		slab.material_override = PartyKit.paint(AQUA.darkened(0.15), 0.0, 0.5)
		slab.position.y = 0.02
		view.add_child(slab)
		var top := MeshInstance3D.new()
		top.mesh = top_mesh
		top.material_override = story
		top.position.y = 0.302
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.add_child(top)
		list.append({"body": body, "view": view, "top": top, "collider": collider, "shown": true})
	_tiles[plate] = list


func _on_tile_dropped(plate: StringName, index: int) -> void:
	var tile: Dictionary = (_tiles[plate] as Array)[index]
	tile["shown"] = false
	(tile["collider"] as CollisionShape3D).set_deferred("disabled", true)
	var view: Node3D = tile["view"]
	view.position = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(view, "position:y", -7.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(view, "scale", Vector3.ONE * 0.5, 0.5)
	tween.tween_callback(view.hide)
	SynthSound.play(self, SynthSound.tone(520.0, 0.25, -380.0, 0.4), -14.0)


func _on_tile_back(plate: StringName, index: int) -> void:
	var tile: Dictionary = (_tiles[plate] as Array)[index]
	tile["shown"] = true
	(tile["collider"] as CollisionShape3D).set_deferred("disabled", false)
	var view: Node3D = tile["view"]
	view.show()
	view.position = Vector3.ZERO
	view.scale = Vector3.ONE * 0.2
	create_tween().tween_property(view, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
