class_name TrendBubbles
extends Node3D

#Draws the bubbles of the board: a toy of its kind turning inside a soap bubble. A ring grows on the floor where a bubble is about to be
#born, and then it pops out of it. The ones of the trend of the player of this screen shine in their colour over a ring and a beam of
#light; the others stay dim, and whoever goes through one makes it wobble like jelly. The viral bubble is golden. An old bubble blinks
#before it moves. A bubble bursts when it is taken and deflates when it goes. It only shows what the board says

const SHELL: Shader = preload("res://assets/shaders/bubble.gdshader")
const RADIUS := 0.95
const TOY_HEIGHT := 1.05
const RING_RADIUS := 1.25
const BEAM_LENGTH := 13.0
const BEAT := 4.0
const VIRAL_COLOR := Color("ffc928")
#How long a wobble lasts and how fast it fades
const WOBBLE_TIME := 0.9

var _board: TrendBoard
var _layout: TrendLayout
#Bubble id -> what draws it; the entries of bubbles that went are kept to be used again
var _entries: Dictionary = {}
var _spare: Array[Dictionary] = []
var _shell_mesh: SphereMesh
var _ring_mesh: TorusMesh
var _birth_mesh: TorusMesh
var _clock := 0.0


func build(board: TrendBoard, layout: TrendLayout) -> void:
	_board = board
	_layout = layout
	_shell_mesh = SphereMesh.new()
	_shell_mesh.radius = RADIUS
	_shell_mesh.height = RADIUS * 2.0
	_shell_mesh.radial_segments = 24
	_shell_mesh.rings = 12
	_ring_mesh = TorusMesh.new()
	_ring_mesh.outer_radius = RING_RADIUS
	_ring_mesh.inner_radius = RING_RADIUS - 0.16
	_ring_mesh.rings = 32
	_ring_mesh.ring_segments = 6
	_birth_mesh = TorusMesh.new()
	_birth_mesh.outer_radius = 1.0
	_birth_mesh.inner_radius = 0.86
	_birth_mesh.rings = 28
	_birth_mesh.ring_segments = 4
	board.bubble_announced.connect(_on_announced)
	board.bubble_spawned.connect(_on_spawned)
	board.bubble_gone.connect(_on_gone)


#Somebody that does not follow its kind went through it: it trembles like jelly and lets it pass
func wobble(id: int) -> void:
	if _entries.has(id):
		_entries[id]["wobble"] = _clock


func is_wobbling(id: int) -> bool:
	return _entries.has(id) and _clock - float(_entries[id]["wobble"]) < WOBBLE_TIME * 0.5


#Moves and lights every bubble: "wanted" says whether a kind is a trend for the player of this screen
func refresh(time: float, wanted: Callable) -> void:
	_clock = time
	for id: int in _entries:
		var entry: Dictionary = _entries[id]
		var holder: Node3D = entry["holder"]
		var at := _board.position_of(id)
		var floor_height: float = _layout.slots[_board.slot_of(id)]["floor"]
		var birth: MeshInstance3D = entry["birth"]
		if not _board.is_live(id):
			#Only the ring on the floor: it closes in and brightens until the bubble pops out
			var share := _board.birth_share(id)
			birth.visible = true
			birth.position = Vector3(at.x, floor_height + 0.05, at.z)
			birth.scale = Vector3.ONE * lerpf(2.2, 1.0, share)
			holder.visible = false
			continue
		birth.visible = false
		holder.position = at
		var kind := _board.kind_of(id)
		var shines: bool = wanted.call(kind)
		(entry["toy"] as Node3D).rotation.y = time * 1.3 + float(entry["phase"])
		var shell: ShaderMaterial = entry["shell"]
		var old := _board.age_share(id)
		var flicker := 1.0 if old < 0.8 else 0.45 + 0.55 * absf(sin(time * 12.0))
		shell.set_shader_parameter("glow", (1.9 if shines else 0.55) * (1.6 if kind == TrendRules.VIRAL else 1.0))
		shell.set_shader_parameter("fade", flicker)
		#A wobble is a spring that rings out: the skin ripples and the bubble squashes and swells
		var since := time - float(entry["wobble"])
		var spring := 0.0
		if since < WOBBLE_TIME:
			spring = exp(-since * 5.0) * sin(since * 30.0)
		shell.set_shader_parameter("jiggle", absf(spring))
		if not entry["popping"]:
			holder.scale = Vector3(1.0 + 0.22 * spring, 1.0 - 0.25 * spring, 1.0 + 0.22 * spring)
		(entry["toy"] as Node3D).position = Vector3(spring * 0.15, 0.0, -spring * 0.1)
		(entry["toy"] as Node3D).scale = Vector3.ONE * (1.0 if shines else 0.82)
		var marks: Node3D = entry["marks"]
		marks.visible = shines
		marks.position = Vector3(at.x, floor_height, at.z)
		(entry["ring"] as Node3D).scale = Vector3.ONE * (1.0 + 0.1 * sin(time * BEAT + float(entry["phase"])))


func _on_announced(id: int) -> void:
	var entry: Dictionary = _spare.pop_back() if not _spare.is_empty() else _make_entry()
	entry["phase"] = (_board.bubbles[id] as TrendBoard.Bubble).phase
	entry["wobble"] = -10.0
	entry["popping"] = false
	_entries[id] = entry
	_dress(entry, _board.kind_of(id))
	(entry["holder"] as Node3D).hide()
	(entry["marks"] as Node3D).hide()


#It pops out of its ring with a bounce
func _on_spawned(id: int) -> void:
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	var holder: Node3D = entry["holder"]
	holder.position = _board.position_of(id)
	holder.show()
	holder.scale = Vector3.ONE * 0.01
	entry["popping"] = true
	var tween := create_tween()
	tween.tween_property(holder, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_end_pop.bind(id))
	(entry["tween"] as Array).append(tween)


#The bounce of its birth is over (the bubble may be gone already). It goes by id, so the tween never holds its entry
func _end_pop(id: int) -> void:
	if _entries.has(id):
		(_entries[id] as Dictionary)["popping"] = false


#Taken, it swells and bursts; gone, it lets its air out and shrinks away
func _on_gone(id: int, taken: bool) -> void:
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	_entries.erase(id)
	var holder: Node3D = entry["holder"]
	(entry["marks"] as Node3D).hide()
	(entry["birth"] as Node3D).hide()
	for running: Tween in entry["tween"]:
		if running.is_valid():
			running.kill()
	(entry["tween"] as Array).clear()
	entry["popping"] = true
	(entry["shell"] as ShaderMaterial).set_shader_parameter("jiggle", 0.0)
	if not holder.visible:
		_spare.append(entry)
		return
	var tween := create_tween()
	if taken:
		tween.tween_property(holder, "scale", Vector3.ONE * 1.35, 0.07)
		tween.tween_property(holder, "scale", Vector3.ONE * 0.01, 0.1)
	else:
		tween.tween_property(holder, "scale", Vector3(1.12, 0.7, 1.12), 0.09)
		tween.tween_property(holder, "scale", Vector3.ONE * 0.01, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(holder.hide)
	tween.tween_callback(_spare.append.bind(entry))


func _make_entry() -> Dictionary:
	var holder := Node3D.new()
	holder.hide()
	add_child(holder)
	var toy := Node3D.new()
	holder.add_child(toy)
	var shell := ShaderMaterial.new()
	shell.shader = SHELL
	var sphere := MeshInstance3D.new()
	sphere.mesh = _shell_mesh
	sphere.material_override = shell
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(sphere)
	#What marks a bubble of the trend on the floor: a ring and a beam of light
	var marks := Node3D.new()
	marks.hide()
	add_child(marks)
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(ring)
	#The ring on the floor where it is about to be born
	var birth := MeshInstance3D.new()
	birth.mesh = _birth_mesh
	birth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	birth.hide()
	add_child(birth)
	return {"holder": holder, "toy": toy, "shell": shell, "marks": marks, "ring": ring, "beam": null, "birth": birth, "phase": 0.0, "kind": -1,
		"tween": [], "wobble": -10.0, "popping": false}


#Gives a bubble the toy and the colour of its kind; the viral one holds a golden trophy
func _dress(entry: Dictionary, kind: int) -> void:
	if int(entry["kind"]) == kind:
		return
	entry["kind"] = kind
	var toy: Node3D = entry["toy"]
	for child in toy.get_children():
		child.queue_free()
	var viral := kind == TrendRules.VIRAL
	var model := PropKit.make_tall(&"trophy", TOY_HEIGHT, VIRAL_COLOR, false) if viral else TrendCatalog.make_toy(kind, TOY_HEIGHT)
	#Wide toys are fitted by their width, so they never poke out of the bubble
	var box := PropKit.measure(model)
	var widest := maxf(box.size.x, box.size.z)
	if widest > TOY_HEIGHT:
		model.scale = Vector3.ONE * TOY_HEIGHT / widest
	model.position.y = -TOY_HEIGHT / 2.0 * model.scale.y
	toy.add_child(model)
	var color := VIRAL_COLOR if viral else TrendCatalog.COLORS[kind]
	(entry["shell"] as ShaderMaterial).set_shader_parameter("tint", color)
	(entry["ring"] as MeshInstance3D).material_override = PartyKit.paint(color, 2.2, 0.4)
	(entry["birth"] as MeshInstance3D).material_override = PartyKit.paint(color.lightened(0.3), 2.5, 0.4)
	var marks: Node3D = entry["marks"]
	if entry["beam"] != null:
		(entry["beam"] as Node3D).queue_free()
	var beam := PartyKit.beam(color.lerp(Color.WHITE, 0.25), BEAM_LENGTH * (1.6 if viral else 1.0), 1.5, 0.5)
	marks.add_child(beam)
	entry["beam"] = beam
