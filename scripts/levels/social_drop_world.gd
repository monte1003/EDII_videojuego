class_name SocialDropWorld
extends Node3D

#SocialDrop board: nine app icon cards in a frame of lights with a giant screen on each side

const COLUMNS := 3
const ROWS := 3
const TILE_SIZE := 4.4
const TILE_GAP := 0.3
const TILE_THICKNESS := 0.4
const TILE_SHADER := preload("res://assets/ui/shaders/icon_tile.gdshader")
const PANEL_SHADER := preload("res://assets/ui/shaders/screen_panel.gdshader")
const QUESTION: Texture2D = preload("res://assets/ui/question_mark.png")
#Hidden card colours, like a chessboard
const HIDDEN_COLORS: Array[Color] = [Color("6a52e0"), Color("ff6f91")]
#Card hop height and time; the pictures roll like a slot machine
const ROLL_MIN := 0.42
const ROLL_MAX := 0.75
const ROLL_LIFT := 0.1
const ROLL_POP := 0.045
#Side in pixels of every picture in the strip
const STRIP_CELL := 256
#Cards roll as a wave from the middle out
const FLIP_STAGGER := 0.1
#Cards rise back in the same wave
const RISE_STAGGER := 0.22
#Platform corners, bevel and glowing frame
const SLAB_CORNER := 1.0
const SLAB_BEVEL := 0.2
const CARD_SHARE := 0.88
const FRAME_SHARE := 0.91
const FRAME_SHADER := preload("res://assets/ui/shaders/tile_frame.gdshader")
const CARD_REST := 0.02
#Fall depth before hiding; returns from half of it
const DROP_DEPTH := 14.0
const DROP_TIME := 1.0
const RISE_TIME := 0.85
#Gap to each screen, screen size and height
const SCREEN_DISTANCE := 3.6
const SCREEN_SIZE := Vector2(9.0, 5.0)
const SCREEN_HEIGHT := 3.2
#Screens lean back toward the players
const SCREEN_TILT_DEGREES := 12.0
const SCREEN_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const SCREEN_FONT_SIZE := 220
const TEXT_PIXEL_SIZE := 0.012
const SIDE_COLOR := Color("a48ae8")
const FRAME_COLOR := Color("372c58")
const PANEL_COLOR := Color("1d1638")
const WARNING_TINT := Color("ff5a5a")
const GOLD_EDGE := Color("ffd84a")
#Stage pips per screen and target glow
const STAGE_PIPS := 7
#Icons flashing by before the one that stays
const SPIN_STEPS := 6
const PIP_SPACING := 0.62
const FOUND_GLOW := 1.7
#Frame pulse, doomed shake and step dip
const FRAME_GLOW := 0.7
const SHAKE_REACH := 0.035
const PRESS_DEPTH := 0.07
#Screen trim colours and light spacing
const SCREEN_ACCENTS: Array[Color] = [PartyKit.PINK, PartyKit.CYAN, PartyKit.YELLOW, PartyKit.VIOLET]
const SCREEN_BULB_SPACING := 1.0
const FRAME_MARGIN := 0.55
const FRAME_BULB_SPACING := 1.3
const BUBBLE_SHADER: Shader = preload("res://assets/shaders/bubble.gdshader")
const BUBBLE_RADIUS := 0.95
class Tile:
	var body: StaticBody3D
	var collider: CollisionShape3D
	#Card face whose picture rolls between the cover and the icon
	var card: Node3D
	var top: ShaderMaterial
	var icon := 0
	var dropped := false
	var face_up := false
	var flip: Tween
	#Rest position, frame, red warning and step dip
	var base := Vector3.ZERO
	var frame: ShaderMaterial
	var glow := FRAME_GLOW
	#Strip position on the face, in cells
	var scroll := 0.0
	var warn := 0.0
	var press: Tween


var _icons: Array[Texture2D] = []
#Every icon plus the "?" cover in one tall picture
var _strip: ImageTexture
var _tiles: Array[Tile] = []
var _screen_labels: Array[Label3D] = []
var _screen_icons: Array[Sprite3D] = []
#Pips per screen and each screen colour
var _screen_pips: Array[Array] = []
var _screen_accents: Array[Color] = []
var _clock := 0.0
var _punch_tween: Tween
var _spin_tween: Tween
var _stage: SocialDropStage
var _bulb_spots: Array[Transform3D] = []
var _bulb_colors: Array[Color] = []


func build(icons: Array[Texture2D], rng: RandomNumberGenerator) -> void:
	_icons = icons
	_strip = _make_strip(icons)
	_stage = SocialDropStage.new()
	add_child(_stage)
	_stage.build(icons)
	_build_tiles()
	_build_screens()
	_build_lights()
	deal(rng, 0, 2, 4)


#Frames pulse through the set colours, red when about to fall
func _process(delta: float) -> void:
	_clock += delta
	for index in _tiles.size():
		var tile := _tiles[index]
		var color := _frame_color(index).lerp(WARNING_TINT, tile.warn)
		var level := FRAME_GLOW + 0.25 * sin(_clock * 1.6 + index * 0.8) + tile.warn * 0.9
		tile.glow = move_toward(tile.glow, level, delta * 4.0)
		tile.frame.set_shader_parameter("glow_color", color)
		tile.frame.set_shader_parameter("energy", tile.glow)


#Smooth colour slide a little behind the neighbour card
func _frame_color(index: int) -> Color:
	var position := _clock * 0.35 + index * 0.45
	var count := PartyKit.PALETTE.size()
	return PartyKit.PALETTE[int(position) % count].lerp(PartyKit.PALETTE[(int(position) + 1) % count], smoothstep(0.0, 1.0, fposmod(position, 1.0)))


#Four free places in the middle, one per player
func spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for spot in [Vector2(-1.3, -1.3), Vector2(1.3, -1.3), Vector2(-1.3, 1.3), Vector2(1.3, 1.3)]:
		points.append(Vector3(spot.x, 0.05, spot.y))
	return points


#Nearest card with "icon" to "from", or the board centre
func cell_position(icon: int, from := Vector3.ZERO) -> Vector3:
	var best := Vector3.ZERO
	var best_distance := INF
	for tile in _tiles:
		if tile.icon != icon or tile.dropped:
			continue
		var distance := Vector2(tile.body.position.x - from.x, tile.body.position.z - from.z).length()
		if distance < best_distance:
			best_distance = distance
			best = tile.body.position + Vector3(0.0, TILE_THICKNESS / 2.0, 0.0)
	return best


#Whether a standing card with its collider on is under a point
func solid_at(at: Vector3) -> bool:
	var half := TILE_SIZE / 2.0
	for tile in _tiles:
		if absf(at.x - tile.body.position.x) <= half and absf(at.z - tile.body.position.z) <= half:
			return not tile.dropped and not tile.collider.disabled
	return false


#Rescue bubble that swells in around a body, like the level 1 ride bubble
func rescue_bubble() -> Node3D:
	var ball := SphereMesh.new()
	ball.radius = BUBBLE_RADIUS
	ball.height = BUBBLE_RADIUS * 2.0
	ball.radial_segments = 24
	ball.rings = 12
	var shell := ShaderMaterial.new()
	shell.shader = BUBBLE_SHADER
	shell.set_shader_parameter("tint", Color("bfe9ff"))
	shell.set_shader_parameter("glow", 1.3)
	var bubble := MeshInstance3D.new()
	bubble.mesh = ball
	bubble.material_override = shell
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.position = Vector3(0.0, 0.85, 0.0)
	bubble.scale = Vector3.ONE * 0.2
	bubble.create_tween().tween_property(bubble, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return bubble


#Pop with confetti and a plop
func pop_bubble(bubble: Node3D) -> void:
	if not is_instance_valid(bubble):
		return
	ImpactFx.confetti(self, bubble.global_position, 24, 55.0, 4.0)
	SynthSound.play(self, SynthSound.tone(520.0, 0.18, 900.0, 0.5), -9.0)
	bubble.queue_free()


#Icon of the card under a point, -1 for none
func icon_at(at: Vector3) -> int:
	var half := TILE_SIZE / 2.0
	for tile in _tiles:
		if not tile.dropped and absf(at.x - tile.body.position.x) <= half and absf(at.z - tile.body.position.z) <= half:
			return tile.icon
	return -1


#Every card turns to show its icon or its "?"
func show_icons(up: bool) -> void:
	for tile in _tiles:
		if not tile.dropped:
			_flip(tile, up)


#Deals the round: "distinct" icons, the target on "copies" cards, every other icon at least once
func deal(rng: RandomNumberGenerator, target: int, distinct: int, copies: int) -> void:
	var others: Array[int] = []
	for index in _icons.size():
		if index != target:
			others.append(index)
	_shuffle(others, rng)
	var kinds := clampi(distinct - 1, 1, others.size())
	var deck: Array[int] = []
	for _copy in copies:
		deck.append(target)
	for index in kinds:
		deck.append(others[index])
	while deck.size() < _tiles.size():
		deck.append(others[rng.randi() % kinds])
	_shuffle(deck, rng)
	for index in _tiles.size():
		var tile := _tiles[index]
		tile.icon = deck[index]
		if tile.face_up and tile.flip == null:
			_set_card(tile, true)


#Doomed tiles blink red three times
func warn(icon: int, seconds: float) -> void:
	var doomed := _doomed(icon)
	var half := seconds / 6.0
	var tween := create_tween().set_loops(3)
	tween.tween_method(_tint.bind(doomed), 0.0, 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_tint.bind(doomed), 1.0, 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#They tremble more and more
	var shake := create_tween()
	shake.tween_method(_shake.bind(doomed), 0.0, 1.0, seconds)
	shake.tween_callback(_shake.bind(0.0, doomed))


#Every tile without "icon" falls; the one that stays shows its icon
func drop(icon: int) -> void:
	for tile in _tiles:
		if tile.icon == icon and not tile.dropped:
			_flip(tile, true)
			#Kept cards glow gold with a few stars
			var found := create_tween()
			found.tween_method(_glow_card.bind(tile), 0.0, FOUND_GLOW, 0.35)
			ImpactFx.stars(self, tile.base + Vector3(0.0, 0.6, 0.0), 4)
	for tile in _doomed(icon):
		tile.dropped = true
		tile.collider.set_deferred("disabled", true)
		if tile.press != null and tile.press.is_valid():
			tile.press.kill()
		tile.body.position = tile.base
		#Each card tumbles away its own way with dust
		var spin := Vector3(signf(sin(tile.base.x * 7.0 + tile.base.z)), signf(cos(tile.base.x + tile.base.z * 5.0)), signf(sin(tile.base.z * 3.0 + 1.0)))
		ImpactFx.dust(self, tile.base + Vector3(0.0, 0.3, 0.0), SIDE_COLOR.lightened(0.55), 10)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(tile.body, "position:y", -TILE_THICKNESS / 2.0 - DROP_DEPTH, DROP_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(tile.body, "rotation", Vector3(0.9 * spin.x, 0.6 * spin.y, 0.8 * spin.z), DROP_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.chain().tween_callback(tile.body.hide)


#New board: fallen tiles rise face down and hold again once in place
func restore() -> void:
	_tint(0.0, _tiles)
	_stage.cheer(2.2)
	for tile in _tiles:
		_glow_card(0.0, tile)
		if not tile.dropped:
			_flip(tile, false)
			continue
		tile.dropped = false
		_set_card(tile, false)
		tile.body.rotation = Vector3.ZERO
		tile.body.position.y = -TILE_THICKNESS / 2.0 - DROP_DEPTH / 2.0
		#Rises in the board wave, slowing near its place
		var tween := create_tween()
		tween.tween_interval(_wave_delay(tile, RISE_STAGGER))
		tween.tween_callback(tile.body.show)
		tween.tween_property(tile.body, "position:y", -TILE_THICKNESS / 2.0, RISE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(tile.collider.set_deferred.bind("disabled", false))


#Confetti and a crowd gone wild
func celebrate() -> void:
	_stage.celebrate()


#First "index + 1" pips lit in their screen colour
func set_stage(index: int) -> void:
	for screen in _screen_pips.size():
		for pip in STAGE_PIPS:
			var node := _screen_pips[screen][pip] as MeshInstance3D
			var lit := pip <= index
			node.material_override = _material(_screen_accents[screen] if lit else FRAME_COLOR.lightened(0.15), 1.4 if lit else 0.0)
			node.scale = Vector3.ONE * (1.25 if pip == index else 1.0)


#Card dip and frame flash on landing
func press_tile(at: Vector3) -> void:
	var half := TILE_SIZE / 2.0
	for tile in _tiles:
		if tile.dropped or absf(at.x - tile.base.x) > half or absf(at.z - tile.base.z) > half:
			continue
		if tile.press != null and tile.press.is_valid():
			tile.press.kill()
		tile.press = create_tween()
		tile.press.tween_property(tile.body, "position:y", tile.base.y - PRESS_DEPTH, 0.06)
		tile.press.tween_property(tile.body, "position:y", tile.base.y, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tile.glow = 2.6
		return


func screen_text(text: String, color: Color) -> void:
	var width := SCREEN_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SCREEN_FONT_SIZE).x * TEXT_PIXEL_SIZE
	var fit := minf(1.0, SCREEN_SIZE.x * 0.86 / maxf(width, 0.01))
	for index in _screen_labels.size():
		_screen_icons[index].hide()
		_screen_labels[index].text = text
		_screen_labels[index].modulate = color
		_screen_labels[index].show()
	_punch(_screen_labels, fit, 1.3)


#"settle" is the last image of a spin, with a bigger bounce
func screen_icon(index: int, settle: bool) -> void:
	for screen_index in _screen_icons.size():
		_screen_labels[screen_index].hide()
		_screen_icons[screen_index].show()
	if not settle:
		_show_on_screens(_icons[index])
		_punch(_screen_icons, 1.0, 1.06)
		return
	#The final icon comes out of a slowing spin
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	_spin_tween = create_tween()
	for step in SPIN_STEPS:
		_spin_tween.tween_callback(_show_on_screens.bind(_icons[(index + SPIN_STEPS - step) % _icons.size()]))
		_spin_tween.tween_interval(0.05 + 0.018 * step)
	_spin_tween.tween_callback(_show_on_screens.bind(_icons[index]))
	_spin_tween.tween_callback(_punch.bind(_screen_icons, 1.0, 1.3))


func _show_on_screens(texture: Texture2D) -> void:
	for screen_icon_node in _screen_icons:
		screen_icon_node.modulate = Color.WHITE
		screen_icon_node.texture = texture
		screen_icon_node.pixel_size = SCREEN_SIZE.y * 0.8 / maxf(texture.get_height(), 1.0)
		screen_icon_node.scale = Vector3.ONE


func _shuffle(list: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(list.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := list[index]
		list[index] = list[other]
		list[other] = held


func _doomed(icon: int) -> Array[Tile]:
	var doomed: Array[Tile] = []
	for tile in _tiles:
		if tile.icon != icon:
			doomed.append(tile)
	return doomed


func _tint(amount: float, tiles: Array[Tile]) -> void:
	var color := Color.WHITE.lerp(WARNING_TINT, amount)
	for tile in tiles:
		tile.warn = amount
		tile.top.set_shader_parameter("tint", color)


#Doomed cards tremble more over time
func _shake(progress: float, tiles: Array[Tile]) -> void:
	for tile in tiles:
		if tile.dropped:
			continue
		tile.body.position.x = tile.base.x + sin(progress * 95.0 + tile.base.z) * SHAKE_REACH * progress
		tile.body.position.z = tile.base.z + cos(progress * 83.0 + tile.base.x) * SHAKE_REACH * progress


#Gold border glow by "amount"
func _glow_card(amount: float, tile: Tile) -> void:
	tile.top.set_shader_parameter("edge_color", GOLD_EDGE)
	tile.top.set_shader_parameter("edge_glow", amount)


#The picture rolls to the icon or the cover and stops; the card never turns
func _flip(tile: Tile, up: bool) -> void:
	if tile.face_up == up and tile.flip == null:
		return
	if tile.flip != null and tile.flip.is_valid():
		tile.flip.kill()
	var cells := float(_icons.size() + 1)
	var from := tile.scroll
	var target := float(tile.icon) if up else cells - 1.0
	#Always forward; an icon goes once round the strip first
	var distance := fposmod(target - from, cells) + (cells if up else 0.0)
	tile.face_up = up
	tile.flip = create_tween()
	tile.flip.tween_interval(_wave_delay(tile, FLIP_STAGGER))
	tile.flip.tween_method(_roll_step.bind(tile, from, distance), 0.0, 1.0, clampf(0.3 + 0.05 * distance, ROLL_MIN, ROLL_MAX))
	tile.flip.tween_callback(_set_card.bind(tile, up))


#Wave delay: middle first, corners last
func _wave_delay(tile: Tile, spread: float) -> float:
	var farthest := (TILE_SIZE + TILE_GAP) * sqrt(2.0)
	return Vector2(tile.base.x, tile.base.z).length() / farthest * spread


#One roll moment: fast and blurred, slowing to a stop with a pop
func _roll_step(progress: float, tile: Tile, from: float, distance: float) -> void:
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var speed := distance * 3.0 * pow(1.0 - progress, 2.0)
	tile.scroll = from + distance * eased
	tile.top.set_shader_parameter("scroll", fposmod(tile.scroll, float(_icons.size() + 1)))
	tile.top.set_shader_parameter("blur", minf(0.9, speed * 0.04))
	tile.card.position.y = TILE_THICKNESS / 2.0 + CARD_REST + sin(progress * PI) * ROLL_LIFT
	tile.card.scale = Vector3.ONE * (1.0 + ROLL_POP * sin(clampf((progress - 0.75) / 0.25, 0.0, 1.0) * PI))


func _set_card(tile: Tile, up: bool) -> void:
	if tile.flip != null and tile.flip.is_valid():
		tile.flip.kill()
	tile.flip = null
	tile.face_up = up
	tile.scroll = float(tile.icon) if up else float(_icons.size())
	tile.top.set_shader_parameter("scroll", tile.scroll)
	tile.top.set_shader_parameter("blur", 0.0)
	tile.card.scale = Vector3.ONE
	tile.card.position.y = TILE_THICKNESS / 2.0 + CARD_REST


#Screen content grows in while fading; the last spin icon lands softly
func _punch(nodes: Array, base: float, from: float) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = create_tween().set_parallel(true)
	var settle := from > 1.2
	for node: Node3D in nodes:
		node.scale = Vector3.ONE * base * (0.72 if settle else 0.9)
		var shown: Color = node.get("modulate")
		node.set("modulate", Color(shown, 0.0))
		_punch_tween.tween_property(node, "modulate:a", 1.0, 0.2)
		_punch_tween.tween_property(node, "scale", Vector3.ONE * base, 0.5 if settle else 0.32) \
			.set_trans(Tween.TRANS_BACK if settle else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_tiles() -> void:
	var step := TILE_SIZE + TILE_GAP
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE, TILE_THICKNESS, TILE_SIZE)
	var block_mesh := _rounded_slab(TILE_SIZE, TILE_THICKNESS, SLAB_CORNER, SLAB_BEVEL)
	var face_mesh := PlaneMesh.new()
	face_mesh.size = Vector2.ONE * TILE_SIZE * CARD_SHARE
	var frame_mesh := PlaneMesh.new()
	frame_mesh.size = Vector2.ONE * TILE_SIZE * FRAME_SHARE
	var side := _material(SIDE_COLOR)
	for row in ROWS:
		for column in COLUMNS:
			var tile := Tile.new()
			tile.body = StaticBody3D.new()
			tile.body.position = Vector3((column - (COLUMNS - 1) / 2.0) * step, -TILE_THICKNESS / 2.0,
				(row - (ROWS - 1) / 2.0) * step)
			tile.base = tile.body.position
			tile.collider = CollisionShape3D.new()
			tile.collider.shape = shape
			tile.body.add_child(tile.collider)
			var block := MeshInstance3D.new()
			block.mesh = block_mesh
			block.material_override = side
			tile.body.add_child(block)
			#Face as a window on the strip; the cover alternates two colours
			tile.top = ShaderMaterial.new()
			tile.top.shader = TILE_SHADER
			tile.top.set_shader_parameter("strip", _strip)
			tile.top.set_shader_parameter("cells", float(_icons.size() + 1))
			tile.top.set_shader_parameter("hidden_color", HIDDEN_COLORS[(row + column) % 2])
			tile.top.set_shader_parameter("sparkle", 1.0)
			tile.top.set_shader_parameter("corner", _corner_share(TILE_SIZE * CARD_SHARE))
			tile.frame = ShaderMaterial.new()
			tile.frame.shader = FRAME_SHADER
			tile.frame.set_shader_parameter("corner", _corner_share(TILE_SIZE * FRAME_SHARE))
			var frame := MeshInstance3D.new()
			frame.mesh = frame_mesh
			frame.material_override = tile.frame
			frame.position.y = TILE_THICKNESS / 2.0 + 0.008
			frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tile.body.add_child(frame)
			tile.card = Node3D.new()
			tile.body.add_child(tile.card)
			tile.card.add_child(_face(face_mesh, tile.top, 0.0))
			_set_card(tile, false)
			add_child(tile.body)
			_tiles.append(tile)


#Icons and the cover stacked in STRIP_CELL squares in one picture
func _make_strip(icons: Array[Texture2D]) -> ImageTexture:
	var strip := Image.create(STRIP_CELL, STRIP_CELL * (icons.size() + 1), true, Image.FORMAT_RGBA8)
	var pictures: Array[Texture2D] = icons.duplicate()
	pictures.append(QUESTION)
	for index in pictures.size():
		var picture := pictures[index].get_image()
		if picture.is_compressed():
			picture.decompress()
		picture.convert(Image.FORMAT_RGBA8)
		picture.resize(STRIP_CELL, STRIP_CELL, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(picture, Rect2i(0, 0, STRIP_CELL, STRIP_CELL), Vector2i(0, index * STRIP_CELL))
	strip.generate_mipmaps()
	return ImageTexture.create_from_image(strip)


#Corner share of a square "size" wide
func _corner_share(size: float) -> float:
	var flat_half := TILE_SIZE / 2.0 - SLAB_BEVEL
	return maxf(SLAB_CORNER - SLAB_BEVEL - (flat_half - size / 2.0), 0.05) / size


#Rounded beveled slab in one smooth mesh
func _rounded_slab(size: float, thickness: float, corner: float, bevel: float) -> ArrayMesh:
	var half := size / 2.0 - corner
	var arc := 7
	var outline: Array[Vector2] = []
	var outward: Array[Vector2] = []
	var centres: Array[Vector2] = [Vector2(half, half), Vector2(-half, half), Vector2(-half, -half), Vector2(half, -half)]
	for quarter in 4:
		for step in arc + 1:
			var angle := PI / 2.0 * (quarter + float(step) / arc)
			var direction := Vector2(cos(angle), sin(angle))
			outline.append(centres[quarter] + direction * corner)
			outward.append(direction)
	#Profile from the bottom edge up over the bevel to the top
	var top := thickness / 2.0
	var profile: Array[Vector3] = [Vector3(0.0, -top, 0.0), Vector3(0.0, top - bevel, 0.0)]
	var bevel_steps := 5
	for step in range(1, bevel_steps + 1):
		var tilt := PI / 2.0 * step / bevel_steps
		profile.append(Vector3(bevel * (1.0 - cos(tilt)), top - bevel + bevel * sin(tilt), tilt))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := outline.size()
	for band in profile.size() - 1:
		for index in count:
			var next := (index + 1) % count
			var corners: Array[Array] = []
			for pair: Array in [[band, index], [band, next], [band + 1, next], [band + 1, index]]:
				var ring: Vector3 = profile[pair[0]]
				var spot: Vector2 = outline[pair[1]] - outward[pair[1]] * ring.x
				var look := Vector3(outward[pair[1]].x * cos(ring.z), sin(ring.z), outward[pair[1]].y * cos(ring.z))
				corners.append([Vector3(spot.x, ring.y, spot.y), look])
			_slab_triangle(tool, corners[0], corners[1], corners[2])
			_slab_triangle(tool, corners[0], corners[2], corners[3])
	var last: Vector3 = profile[profile.size() - 1]
	for index in count:
		var next := (index + 1) % count
		var a := outline[index] - outward[index] * last.x
		var b := outline[next] - outward[next] * last.x
		_slab_triangle(tool, [Vector3(0.0, top, 0.0), Vector3.UP], [Vector3(a.x, top, a.y), Vector3.UP], [Vector3(b.x, top, b.y), Vector3.UP])
		_slab_triangle(tool, [Vector3(0.0, -top, 0.0), Vector3.DOWN], [Vector3(outline[index].x, -top, outline[index].y), Vector3.DOWN],
			[Vector3(outline[next].x, -top, outline[next].y), Vector3.DOWN])
	return tool.commit()


#Triangle facing the way its normals do
func _slab_triangle(tool: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var flat := ((c[0] as Vector3) - (a[0] as Vector3)).cross((b[0] as Vector3) - (a[0] as Vector3))
	var looks := (a[1] as Vector3) + (b[1] as Vector3) + (c[1] as Vector3)
	var ordered: Array[Array] = []
	ordered.assign([a, b, c] if flat.dot(looks) >= 0.0 else [a, c, b])
	for corner in ordered:
		tool.set_normal(corner[1] as Vector3)
		tool.add_vertex(corner[0] as Vector3)


#Card face up, or down with a half turn
func _face(mesh: Mesh, material: Material, tilt: float) -> MeshInstance3D:
	var face := MeshInstance3D.new()
	face.mesh = mesh
	face.material_override = material
	face.rotation.x = tilt
	face.position.y = 0.0 if tilt == 0.0 else -0.01
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return face


#A screen on each side facing the middle
func _build_screens() -> void:
	var half_columns := COLUMNS * (TILE_SIZE + TILE_GAP) / 2.0
	var half_rows := ROWS * (TILE_SIZE + TILE_GAP) / 2.0
	var entries := [
		[Vector3(0.0, SCREEN_HEIGHT, -(half_rows + SCREEN_DISTANCE)), 0.0],
		[Vector3(half_columns + SCREEN_DISTANCE, SCREEN_HEIGHT, 0.0), -PI / 2.0],
		[Vector3(0.0, SCREEN_HEIGHT, half_rows + SCREEN_DISTANCE), PI],
		[Vector3(-(half_columns + SCREEN_DISTANCE), SCREEN_HEIGHT, 0.0), PI / 2.0],
	]
	for index in entries.size():
		_build_screen(entries[index][0], entries[index][1], SCREEN_ACCENTS[index])
	set_stage(0)


func _build_screen(at: Vector3, yaw: float, accent: Color) -> void:
	var mount := Node3D.new()
	mount.position = at
	mount.rotation.y = yaw
	add_child(mount)
	var screen := Node3D.new()
	screen.rotation.x = -deg_to_rad(SCREEN_TILT_DEGREES)
	mount.add_child(screen)
	_box(screen, Vector3(SCREEN_SIZE.x + 1.2, SCREEN_SIZE.y + 1.2, 0.3), Vector3(0.0, 0.0, -0.2), _material(accent, 0.35))
	_screen_lights(Transform3D(mount.basis * screen.basis, at), accent)
	_box(screen, Vector3(SCREEN_SIZE.x + 0.7, SCREEN_SIZE.y + 0.7, 0.6), Vector3.ZERO, _material(FRAME_COLOR))
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	panel.mesh = quad
	var glass := ShaderMaterial.new()
	glass.shader = PANEL_SHADER
	glass.set_shader_parameter("accent", accent)
	panel.material_override = glass
	panel.position.z = 0.31
	screen.add_child(panel)
	#Stage pips under the numbers
	var pips: Array = []
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.2
	pip_mesh.height = 0.4
	pip_mesh.radial_segments = 12
	pip_mesh.rings = 6
	for pip in STAGE_PIPS:
		var disc := MeshInstance3D.new()
		disc.mesh = pip_mesh
		disc.position = Vector3((pip - (STAGE_PIPS - 1) / 2.0) * PIP_SPACING, -SCREEN_SIZE.y * 0.4, 0.4)
		disc.scale = Vector3(1.0, 1.0, 0.35)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		screen.add_child(disc)
		pips.append(disc)
	_screen_pips.append(pips)
	_screen_accents.append(accent)
	#A post holds it up
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


#Lights along the screen trim
func _screen_lights(frame: Transform3D, accent: Color) -> void:
	var half := (SCREEN_SIZE + Vector2.ONE * 0.95) / 2.0
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	for index in 4:
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % 4]
		var count := roundi(from.distance_to(to) / SCREEN_BULB_SPACING)
		for step in count:
			var spot := from.lerp(to, float(step) / count)
			_light_at(frame * Vector3(spot.x, spot.y, 0.0), accent.lerp(Color.WHITE, 0.3))


#Lights around the board
func _build_lights() -> void:
	var half := Vector2(COLUMNS * (TILE_SIZE + TILE_GAP) - TILE_GAP, ROWS * (TILE_SIZE + TILE_GAP) - TILE_GAP) / 2.0 + Vector2.ONE * FRAME_MARGIN
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	var tint := 0
	for index in 4:
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % 4]
		var count := roundi(from.distance_to(to) / FRAME_BULB_SPACING)
		for step in count:
			var spot := from.lerp(to, float(step) / count)
			_light_at(Vector3(spot.x, 0.12, spot.y), PartyKit.PALETTE[tint % PartyKit.PALETTE.size()])
			tint += 1
	var colors: Array[Color] = []
	var phases: Array[float] = []
	for index in _bulb_spots.size():
		colors.append(_bulb_colors[index])
		phases.append(index * 0.7)
	add_child(PartyKit.bulbs(_bulb_spots, colors, phases))


func _light_at(at: Vector3, color: Color) -> void:
	_bulb_spots.append(Transform3D(Basis.IDENTITY, at))
	_bulb_colors.append(color)


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)


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
