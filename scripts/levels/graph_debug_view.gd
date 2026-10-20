class_name GraphDebugView
extends Node3D

#Draws the graph the bots really use: vertex ids, bridges with their costs and every bot's route

const OPEN_COLOR := Color("3ddc84")
const BLOCKED_COLOR := Color("ff3b3b")

var _graph: WeightedGraph
var _positions: Dictionary = {}
var _mesh := ImmediateMesh.new()
var _edge_labels: Dictionary = {}


func setup(graph: WeightedGraph, positions: Dictionary) -> void:
	_graph = graph
	_positions = positions
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 20
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

	for id: StringName in positions:
		var label := _make_label(String(id), 110, Color("fdfbff"))
		label.position = positions[id] + Vector3(0, 3.0, 0)
		add_child(label)
	for edge in graph.undirected_edges():
		var key := _edge_key(edge["a"], edge["b"])
		var label := _make_label("", 96, OPEN_COLOR)
		label.position = (positions[edge["a"]] + positions[edge["b"]]) / 2.0 + Vector3(0, 1.4, 0)
		add_child(label)
		_edge_labels[key] = label


func redraw(bots: Array[ChaserBot]) -> void:
	_mesh.clear_surfaces()
	var quads := 0
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge in _graph.undirected_edges():
		var a: Vector3 = _positions[edge["a"]]
		var b: Vector3 = _positions[edge["b"]]
		var open: bool = edge["enabled"]
		var color := OPEN_COLOR if open else BLOCKED_COLOR
		_ribbon(a, b, 0.25, 0.18, color)
		quads += 1
		if not open:
			var mid := (a + b) / 2.0
			_ribbon(mid + Vector3(-1.2, 0, -1.2), mid + Vector3(1.2, 0, 1.2), 0.25, 0.3, color)
			_ribbon(mid + Vector3(-1.2, 0, 1.2), mid + Vector3(1.2, 0, -1.2), 0.25, 0.3, color)
			quads += 2
		var label := _edge_labels[_edge_key(edge["a"], edge["b"])] as Label3D
		label.text = "%s-%s: %s%s" % [edge["a"], edge["b"], String.num(edge["weight"], 0), "" if open else " BLOQ."]
		label.modulate = color
	for index in bots.size():
		var bot := bots[index]
		if not bot.route_found:
			continue
		var color := bot.appearance.debug_color
		var path := bot.planned_vertices()
		var height := 0.55 + index * 0.18
		for step in range(path.size() - 1):
			_ribbon(_positions[path[step]], _positions[path[step + 1]], 0.4, height, color)
			quads += 1
		#Line from the bot to the first vertex it is heading to
		if not path.is_empty():
			_ribbon(bot.global_position, _positions[path[0]], 0.2, height, color)
			quads += 1
	if quads == 0:
		#An empty surface is not allowed: draw a degenerate triangle
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_end()


func _make_label(text: String, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.016
	label.modulate = color
	label.outline_size = 14
	label.outline_modulate = Color("2a2145")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.render_priority = 30
	return label


func _edge_key(a: StringName, b: StringName) -> String:
	return "%s|%s" % [a, b] if String(a) < String(b) else "%s|%s" % [b, a]


#A flat strip between two points, thick enough to read from the game camera
func _ribbon(from: Vector3, to: Vector3, width: float, height: float, color: Color) -> void:
	var a := Vector3(from.x, height, from.z)
	var b := Vector3(to.x, height, to.z)
	var direction := b - a
	if direction.length() < 0.01:
		return
	var side := direction.normalized().cross(Vector3.UP) * (width / 2.0)
	var corners := [a - side, a + side, b + side, b - side]
	for index in [0, 1, 2, 0, 2, 3]:
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(corners[index])
