class_name TrendBubbles
extends Node3D

#Draws the bubbles of the board: a toy of its kind turning inside a soap bubble. The ones the player of this screen needs shine
#in their colour over a ring and a beam of light; the others stay dim. A bubble is born with a bounce, bursts when it is fetched
#and deflates when its time is up; as it gets old its ring shrinks, beats faster and at the end blinks. It only shows what the
#board says

const SHELL: Shader = preload("res://assets/shaders/bubble.gdshader")
const RADIUS := 0.95
const TOY_HEIGHT := 1.05
const RING_RADIUS := 1.25
const BEAM_LENGTH := 13.0
#How much of the ring is left when the bubble is about to go, and how fast it beats when new and when old
const RING_END := 0.5
const BEAT_SLOW := 4.0
const BEAT_FAST := 13.0

var _board: TrendBoard
var _settings: TrendSettings
var _layout: TrendLayout
#Bubble id -> what draws it; the entries of bubbles that went are kept to be used again
var _entries: Dictionary = {}
var _spare: Array[Dictionary] = []
var _loose: Array[Dictionary] = []
var _shell_mesh: SphereMesh
var _ring_mesh: TorusMesh
var _drift := false


func build(board: TrendBoard, settings: TrendSettings, layout: TrendLayout) -> void:
	_board = board
	_settings = settings
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
	board.bubble_spawned.connect(_on_spawned)
	board.bubble_gone.connect(_on_gone)
	for id: int in board.bubbles:
		_on_spawned(id)


#Touched by somebody who does not need it: it wobbles and stays
func wobble(id: int) -> void:
	if not _entries.has(id):
		return
	var holder: Node3D = _entries[id]["holder"]
	var tween := create_tween()
	tween.tween_property(holder, "scale", Vector3(1.25, 0.8, 1.25), 0.07)
	tween.tween_property(holder, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


#Moves and lights every bubble: "needed" is the kind the player of this screen has to fetch (-1 for none), "fade" goes from 1 to 0
#in the last seconds of a trend and "drift" makes them wander
func refresh(time: float, needed: int, fade: float, drift: bool) -> void:
	_drift = drift
	for id: int in _entries:
		var entry: Dictionary = _entries[id]
		var holder: Node3D = entry["holder"]
		var at := _board.position_of(id, drift)
		holder.position = at
		(entry["toy"] as Node3D).rotation.y = time * 1.3 + float(entry["phase"])
		var kind := _board.kind_of(id)
		var wanted := kind == needed
		var old := _board.life_share(id)
		var shell: ShaderMaterial = entry["shell"]
		#Old age shows in the last seconds of a bubble, and in the last seconds of a trend every bubble flickers out
		var dying := clampf(1.0 - _board.life_left(id) / _settings.aging_seconds, 0.0, 1.0)
		var blink := lerpf(1.0, 0.3 + 0.7 * absf(sin(time * 11.0)), dying)
		var flicker := lerpf(0.35 + 0.3 * absf(sin(time * 9.0)), 1.0, fade)
		shell.set_shader_parameter("glow", 1.9 if wanted else 0.55)
		shell.set_shader_parameter("fade", flicker * blink)
		(entry["toy"] as Node3D).scale = Vector3.ONE * (1.0 if wanted else 0.82) * lerpf(1.0, 0.86, dying)
		var marks: Node3D = entry["marks"]
		marks.visible = wanted
		var floor_at: Vector3 = _layout.points[(_board.bubbles[id] as TrendBoard.Bubble).point]["position"]
		marks.position = Vector3(at.x, floor_at.y, at.z)
		var beat := sin(time * lerpf(BEAT_SLOW, BEAT_FAST, old * old) + float(entry["phase"]))
		(entry["ring"] as Node3D).scale = Vector3.ONE * lerpf(1.0, RING_END, old) * (1.0 + 0.1 * beat)
	_refresh_loose(time, needed)


func _on_spawned(id: int) -> void:
	var entry: Dictionary = _spare.pop_back() if not _spare.is_empty() else _make_entry()
	entry["phase"] = (_board.bubbles[id] as TrendBoard.Bubble).phase
	_entries[id] = entry
	_dress(entry, _board.kind_of(id))
	var holder: Node3D = entry["holder"]
	holder.position = _board.position_of(id, _drift)
	holder.show()
	holder.scale = Vector3.ONE * 0.01
	(entry["tween"] as Array).clear()
	var tween := create_tween()
	tween.tween_property(holder, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	(entry["tween"] as Array).append(tween)


#Fetched, it swells and bursts; out of time, it lets its air go and shrinks away
func _on_gone(id: int, taken: bool) -> void:
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	_entries.erase(id)
	var holder: Node3D = entry["holder"]
	(entry["marks"] as Node3D).hide()
	for running: Tween in entry["tween"]:
		if running.is_valid():
			running.kill()
	(entry["tween"] as Array).clear()
	var tween := create_tween()
	if taken:
		tween.tween_property(holder, "scale", Vector3.ONE * 1.35, 0.07)
		tween.tween_property(holder, "scale", Vector3.ONE * 0.01, 0.1)
	else:
		tween.tween_property(holder, "scale", Vector3(1.12, 0.7, 1.12), 0.09)
		tween.tween_property(holder, "scale", Vector3.ONE * 0.01, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(holder.hide)
	tween.tween_callback(_spare.append.bind(entry))


#Loose items after a shove: a smaller bubble that flies, lands and blinks while it lasts
func _refresh_loose(time: float, needed: int) -> void:
	while _loose.size() < _board.loose.size():
		_loose.append(_make_entry())
	for index in _loose.size():
		var entry := _loose[index]
		var holder: Node3D = entry["holder"]
		(entry["marks"] as Node3D).hide()
		if index >= _board.loose.size():
			holder.hide()
			entry["kind"] = -1
			continue
		var item := _board.loose[index]
		if int(entry["kind"]) != int(item["kind"]):
			_dress(entry, int(item["kind"]))
		holder.show()
		holder.scale = Vector3.ONE * 0.75
		holder.position = item["position"]
		(entry["toy"] as Node3D).rotation.y = time * 4.0
		var shell: ShaderMaterial = entry["shell"]
		shell.set_shader_parameter("glow", 1.9 if int(item["kind"]) == needed else 0.8)
		shell.set_shader_parameter("fade", 0.45 + 0.55 * absf(sin(time * 10.0)))


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
	#What marks the bubble to fetch on the floor: a ring and a beam of light
	var marks := Node3D.new()
	marks.hide()
	add_child(marks)
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(ring)
	return {"holder": holder, "toy": toy, "shell": shell, "marks": marks, "ring": ring, "beam": null, "phase": 0.0, "kind": -1, "tween": []}


#Gives a bubble the toy and the colour of its kind
func _dress(entry: Dictionary, kind: int) -> void:
	if int(entry["kind"]) == kind:
		return
	entry["kind"] = kind
	var toy: Node3D = entry["toy"]
	for child in toy.get_children():
		child.queue_free()
	var model := TrendCatalog.make_toy(kind, TOY_HEIGHT)
	#Wide toys are fitted by their width, so they never poke out of the bubble
	var box := PropKit.measure(model)
	var widest := maxf(box.size.x, box.size.z)
	if widest > TOY_HEIGHT:
		model.scale = Vector3.ONE * TOY_HEIGHT / widest
	model.position.y = -TOY_HEIGHT / 2.0 * model.scale.y
	toy.add_child(model)
	var color := TrendCatalog.COLORS[kind]
	(entry["shell"] as ShaderMaterial).set_shader_parameter("tint", color)
	(entry["ring"] as MeshInstance3D).material_override = PartyKit.paint(color, 2.2, 0.4)
	var marks: Node3D = entry["marks"]
	if entry["beam"] != null:
		(entry["beam"] as Node3D).queue_free()
	var beam := PartyKit.beam(color.lerp(Color.WHITE, 0.25), BEAM_LENGTH, 1.5, 0.5)
	marks.add_child(beam)
	entry["beam"] = beam
