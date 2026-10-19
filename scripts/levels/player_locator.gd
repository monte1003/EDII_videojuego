class_name PlayerLocator
extends Node

#Tells which platform or bridge the player is on, using Area3D sensors instead of distances.
#While the player is in the air over nothing it keeps the last valid place.

signal place_changed

var vertex: StringName = &""
var on_bridge := false
var bridge_a: StringName = &""
var bridge_b: StringName = &""

var _platforms_inside: Array[StringName] = []
var _bridges_inside: Array[Array] = []


func watch_platform(id: StringName, area: Area3D) -> void:
	area.body_entered.connect(_on_body_entered.bind(id, &"", true))
	area.body_exited.connect(_on_body_exited.bind(id, &"", true))


func watch_bridge(a: StringName, b: StringName, area: Area3D) -> void:
	area.body_entered.connect(_on_body_entered.bind(a, b, false))
	area.body_exited.connect(_on_body_exited.bind(a, b, false))


#Used after the player is put somewhere on purpose (respawn)
func force_vertex(id: StringName) -> void:
	vertex = id
	on_bridge = false
	_platforms_inside.clear()
	_bridges_inside.clear()
	place_changed.emit()


#Vertices a bot may chase: the platform, or both ends of the bridge the player is on
func chase_candidates() -> Array[StringName]:
	if on_bridge:
		return [bridge_a, bridge_b]
	return [vertex]


func _on_body_entered(body: Node3D, a: StringName, b: StringName, is_platform: bool) -> void:
	if not body is Player:
		return
	if is_platform:
		if not _platforms_inside.has(a):
			_platforms_inside.append(a)
	else:
		_bridges_inside.append([a, b])
	_resolve()


func _on_body_exited(body: Node3D, a: StringName, b: StringName, is_platform: bool) -> void:
	if not body is Player:
		return
	if is_platform:
		_platforms_inside.erase(a)
	else:
		_bridges_inside.erase([a, b])
	_resolve()


func _resolve() -> void:
	var old_vertex := vertex
	var old_bridge := on_bridge
	var old_a := bridge_a
	if not _platforms_inside.is_empty():
		vertex = _platforms_inside[0]
		on_bridge = false
	elif not _bridges_inside.is_empty():
		on_bridge = true
		bridge_a = _bridges_inside[0][0]
		bridge_b = _bridges_inside[0][1]
	if vertex != old_vertex or on_bridge != old_bridge or bridge_a != old_a:
		place_changed.emit()
