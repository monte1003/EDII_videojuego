class_name Level01Debug
extends Node

#Tools for the class: F3 draws the graph and the cheapest route from the player to the goal, F4 closes a bridge of that route for a few
#seconds so Dijkstra can be seen choosing another one

const ROUTE_COLOR := Color("ffd23f")
const DEMO_SECONDS := 8.0

var _level: Level01
var _view: GraphDebugView
var _hud: LevelHud
var _timer := 0.0
#The bridge the demo closed and the seconds it stays closed
var _closed: Array[StringName] = []
var _demo_left := 0.0


func setup(level: Level01, view: GraphDebugView, hud: LevelHud) -> void:
	_level = level
	_view = view
	_hud = hud
	_view.setup(level.graph, Level01Layout.POSITIONS)
	_view.visible = false


func toggle_view() -> void:
	_view.visible = not _view.visible
	_hud.set_debug_visible(_view.visible)


func toggle_demo() -> void:
	if _closed.is_empty():
		_start_demo()
	else:
		end_demo()


func tick(delta: float) -> void:
	_update_view(delta)
	if not _closed.is_empty():
		_demo_left -= delta
		if _demo_left <= 0.0:
			end_demo()


func end_demo() -> void:
	if _closed.is_empty():
		return
	_level.set_bridge_closed(_closed[0], _closed[1], false)
	_closed.clear()


#The cheapest route from where the player is to the goal, as Dijkstra sees it now
func _route() -> WeightedGraph.PathResult:
	return _level.graph.shortest_path(_level.local_locator().vertex, Level01Layout.GOAL)


func _update_view(delta: float) -> void:
	if not _view.visible:
		return
	_timer += delta
	if _timer < 0.1:
		return
	_timer = 0.0
	var routes: Array[Dictionary] = []
	var found := _route()
	if found.found:
		routes.append({"path": found.path, "color": ROUTE_COLOR, "from": _level.local_player().global_position})
	_view.redraw(routes)
	_hud.set_debug_text(_text(found))


func _text(found: WeightedGraph.PathResult) -> String:
	var graph := _level.graph
	var locator := _level.local_locator()
	var lines := PackedStringArray()
	lines.append("[b]Grafo[/b]  %d vértices · %d puentes" % [graph.vertices().size(), graph.undirected_edges().size()])
	var blocked := PackedStringArray()
	for edge in graph.undirected_edges():
		if not edge["enabled"]:
			blocked.append("%s-%s" % [edge["a"], edge["b"]])
	lines.append("Cerrados: %s" % (", ".join(blocked) if not blocked.is_empty() else "ninguno"))
	lines.append("Tú: %s" % (("puente %s-%s" % [locator.bridge_a, locator.bridge_b]) if locator.on_bridge else String(locator.vertex)))
	if found.found:
		lines.append("[color=#c08a00][b]Ruta más barata[/b][/color] · costo %s" % String.num(found.cost, 1))
		lines.append(" › ".join(PackedStringArray(found.path)))
	else:
		lines.append("[color=#c0262d]SIN CAMINO[/color] a la meta")
	return "\n".join(lines)


#Closes the first bridge of the route that can be closed with another way left, so the route changes in front of the class
func _start_demo() -> void:
	if not _level.rules.is_running():
		return
	var found := _route()
	if not found.found:
		return
	_view.visible = true
	_hud.set_debug_visible(true)
	for step in range(found.path.size() - 1):
		var a: StringName = found.path[step]
		var b: StringName = found.path[step + 1]
		_level.set_bridge_closed(a, b, true)
		if _level.graph.shortest_path(_level.local_locator().vertex, Level01Layout.GOAL).found:
			_closed = [a, b]
			_demo_left = DEMO_SECONDS
			_hud.toast("Se cierra %s-%s: Dijkstra busca otro camino" % [a, b])
			return
		_level.set_bridge_closed(a, b, false)
	_hud.toast("Ningún puente de la ruta se puede cerrar sin dejarte sin camino")
