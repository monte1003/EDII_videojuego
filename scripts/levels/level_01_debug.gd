class_name Level01Debug
extends Node

#Tools for the class: F3 draws the graph and the routes, F4 shows Dijkstra reacting when a bridge closes

var _level: Level01
var _view: GraphDebugView
var _hud: LevelHud
var _timer := 0.0
var _demo_bot: ChaserBot
var _demo_time := 0.0
var _demo_blocked := false


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
	if _demo_bot == null:
		_start_demo()
	else:
		end_demo()


func tick(delta: float) -> void:
	_update_view(delta)
	_update_demo(delta)


func end_demo() -> void:
	if _demo_bot == null:
		return
	_demo_bot.queue_free()
	_demo_bot = null
	if _demo_blocked and not _level.rules.block_active():
		_level.set_bridge_closed(false)
	_demo_blocked = false


func _update_view(delta: float) -> void:
	if not _view.visible:
		return
	_timer += delta
	if _timer < 0.1:
		return
	_timer = 0.0
	var shown: Array[ChaserBot] = []
	shown.assign(_level.bots)
	if _demo_bot != null:
		shown.append(_demo_bot)
	_view.redraw(shown)
	_hud.set_debug_text(_text(shown))


func _text(shown: Array[ChaserBot]) -> String:
	var graph := _level.graph
	var locator := _level.local_locator()
	var lines := PackedStringArray()
	lines.append("[b]Grafo[/b]  %d vértices · %d puentes" % [graph.vertices().size(), graph.undirected_edges().size()])
	var blocked := PackedStringArray()
	for edge in graph.undirected_edges():
		if not edge["enabled"]:
			blocked.append("%s-%s" % [edge["a"], edge["b"]])
	lines.append("Bloqueados: %s" % (", ".join(blocked) if not blocked.is_empty() else "ninguno"))
	lines.append("Tú: %s" % (("puente %s-%s" % [locator.bridge_a, locator.bridge_b]) if locator.on_bridge else String(locator.vertex)))
	for bot in shown:
		var info := bot.debug_info()
		var name_markup := "[color=#%s][b]%s[/b][/color]" % [(info["color"] as Color).to_html(false), info["name"]]
		if not info["found"] and info["target"] != &"":
			lines.append("%s: [color=#c0262d]SIN CAMINO[/color] hacia %s" % [name_markup, info["target"]])
			lines.append("   %s" % info["message"])
		elif info["target"] == &"":
			lines.append("%s: sin destino (%s)" % [name_markup, info["state"]])
		else:
			var path: Array = info["route"]
			lines.append("%s: %s → %s · costo %s · %s" % [
				name_markup, info["from"], info["target"], String.num(info["cost"], 0), " › ".join(PackedStringArray(path))])
	return "\n".join(lines)


#A bot goes from B to J, then E-H closes and the route cost goes from 6 to 11
func _start_demo() -> void:
	if not _level.rules.is_running() or _level.bot_appearances.is_empty():
		return
	_view.visible = true
	_hud.set_debug_visible(true)
	_demo_bot = _level.make_bot(_level.bot_appearances[0], &"B")
	_demo_bot.push_enabled = false
	_demo_bot.manual_target = true
	_demo_bot.hold_movement = true
	_demo_bot.activate(&"J")
	_demo_time = 0.0
	_demo_blocked = false
	_hud.toast("Demostración: de B a J por el camino de menor costo")


func _update_demo(delta: float) -> void:
	if _demo_bot == null:
		return
	_demo_time += delta
	if _demo_time >= 3.0 and not _demo_blocked:
		_demo_blocked = true
		_level.set_bridge_closed(true)
		_hud.toast("Se bloquea E-H: Dijkstra elige otro camino")
	if _demo_time >= 5.0:
		_demo_bot.hold_movement = false
	if _demo_blocked and _demo_time >= 3.0 + _level.settings.block_duration:
		_level.set_bridge_closed(false)
	if _demo_bot.current_vertex == &"J" and not _demo_bot.is_crossing():
		end_demo()
