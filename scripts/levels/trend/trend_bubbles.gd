class_name TrendBubbles
extends Node3D

#Draws the bubbles of the board: a toy of its kind turning inside a soap bubble. The ones the player of this screen needs shine in
#their colour over a ring and a beam of light; the others stay dim. It only shows what the board says

const SHELL: Shader = preload("res://assets/shaders/bubble.gdshader")
const RADIUS := 0.95
const TOY_HEIGHT := 1.05
const RING_RADIUS := 1.25
const BEAM_LENGTH := 13.0

var _board: TrendBoard
var _settings: TrendSettings
var _entries: Array[Dictionary] = []
var _loose: Array[Dictionary] = []
var _shell_mesh: SphereMesh
var _ring_mesh: TorusMesh


func build(board: TrendBoard, settings: TrendSettings) -> void:
	_board = board
	_settings = settings
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
	for point in board.kinds.size():
		_entries.append(_make_entry(board.position_of(point), point * 1.7))
		_set_kind(point, board.kinds[point], false)


#A bubble is back at a point
func appear(point: int) -> void:
	_set_kind(point, _board.kinds[point], true)


#Fetched: it swells, bursts and is gone
func pop(point: int) -> void:
	var entry := _entries[point]
	entry["kind"] = -1
	var holder: Node3D = entry["holder"]
	var tween := create_tween()
	tween.tween_property(holder, "scale", Vector3.ONE * 1.35, 0.07)
	tween.tween_property(holder, "scale", Vector3.ONE * 0.01, 0.1)
	tween.tween_callback(holder.hide)
	(entry["marks"] as Node3D).hide()


#Touched by somebody who does not need it: it wobbles and stays
func wobble(point: int) -> void:
	var holder: Node3D = _entries[point]["holder"]
	var tween := create_tween()
	tween.tween_property(holder, "scale", Vector3(1.25, 0.8, 1.25), 0.07)
	tween.tween_property(holder, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


#Where the bubble of a point floats right now
func place_of(point: int) -> Vector3:
	return (_entries[point]["holder"] as Node3D).global_position


#Moves and lights every bubble: "needed" is the kind the player of this screen has to fetch (-1 for none), "fade" goes from 1 to 0
#in the last seconds of a trend and "drift" makes them wander
func refresh(time: float, needed: int, fade: float, drift: bool) -> void:
	for point in _entries.size():
		var entry := _entries[point]
		if int(entry["kind"]) < 0:
			continue
		var holder: Node3D = entry["holder"]
		var phase: float = entry["phase"]
		var at: Vector3 = entry["base"]
		if drift:
			var turn := time * _settings.drift_speed + phase
			at += Vector3(cos(turn), 0.0, sin(turn)) * _settings.drift_radius
		holder.position = at + Vector3(0.0, TrendLayout.BUBBLE_HEIGHT + sin(time * 1.6 + phase) * 0.12, 0.0)
		(entry["toy"] as Node3D).rotation.y = time * 1.3 + phase
		var wanted := int(entry["kind"]) == needed
		var shell: ShaderMaterial = entry["shell"]
		#In the last seconds every bubble flickers out
		var flicker := lerpf(0.35 + 0.3 * absf(sin(time * 9.0)), 1.0, fade)
		shell.set_shader_parameter("glow", 1.9 if wanted else 0.55)
		shell.set_shader_parameter("fade", flicker)
		(entry["toy"] as Node3D).scale = Vector3.ONE * (1.0 if wanted else 0.82)
		var marks: Node3D = entry["marks"]
		marks.visible = wanted
		marks.position = Vector3(at.x, (entry["base"] as Vector3).y, at.z)
		(entry["ring"] as Node3D).scale = Vector3.ONE * (1.0 + 0.1 * sin(time * 5.0 + phase))
	_refresh_loose(time, needed)


#Loose items after a shove: a smaller bubble that flies, lands and blinks while it lasts
func _refresh_loose(time: float, needed: int) -> void:
	while _loose.size() < _board.loose.size():
		_loose.append(_make_entry(Vector3.ZERO, _loose.size() * 2.3))
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


func _make_entry(base: Vector3, phase: float) -> Dictionary:
	var holder := Node3D.new()
	holder.position = base + Vector3(0.0, TrendLayout.BUBBLE_HEIGHT, 0.0)
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
	marks.position = base
	marks.hide()
	add_child(marks)
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(ring)
	return {"holder": holder, "toy": toy, "shell": shell, "marks": marks, "ring": ring, "beam": null, "base": base, "phase": phase, "kind": -1}


func _set_kind(point: int, kind: int, pop_in: bool) -> void:
	var entry := _entries[point]
	var holder: Node3D = entry["holder"]
	if kind < 0:
		entry["kind"] = -1
		holder.hide()
		(entry["marks"] as Node3D).hide()
		return
	_dress(entry, kind)
	holder.show()
	holder.scale = Vector3.ONE
	if pop_in:
		holder.scale = Vector3.ONE * 0.01
		create_tween().tween_property(holder, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


#Gives a bubble the toy and the colour of its kind
func _dress(entry: Dictionary, kind: int) -> void:
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
