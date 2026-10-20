class_name WeightedGraph
extends RefCounted

#Weighted graph as adjacency lists with its own Dijkstra; data and algorithms only

#A directed arc; a two-way bridge is stored as two arcs
class Edge:
	var to: StringName
	var weight: float
	var enabled := true

	func _init(target: StringName, cost: float) -> void:
		to = target
		weight = cost


#Outcome of a shortest-path query; "found" is false when no route exists
class PathResult:
	var found := false
	var path: Array[StringName] = []
	var cost := INF
	var reason := ""


#Grows on every change of vertices, edges or availability so callers can detect it cheaply
var version := 0

var _adjacency: Dictionary = {}


func add_vertex(id: StringName) -> bool:
	if _adjacency.has(id):
		return false
	_adjacency[id] = [] as Array[Edge]
	version += 1
	return true


func has_vertex(id: StringName) -> bool:
	return _adjacency.has(id)


func vertices() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _adjacency:
		ids.append(id)
	return ids


#Adds or updates a-b; bidirectional creates both arcs
func add_edge(a: StringName, b: StringName, weight: float, bidirectional := true) -> bool:
	if not _adjacency.has(a) or not _adjacency.has(b) or a == b or weight < 0.0:
		push_error("WeightedGraph: conexión inválida %s-%s" % [a, b])
		return false
	_set_arc(a, b, weight)
	if bidirectional:
		_set_arc(b, a, weight)
	version += 1
	return true


func get_edge(a: StringName, b: StringName) -> Edge:
	for edge: Edge in _adjacency.get(a, []):
		if edge.to == b:
			return edge
	return null


func has_edge(a: StringName, b: StringName) -> bool:
	return get_edge(a, b) != null


func is_edge_enabled(a: StringName, b: StringName) -> bool:
	var edge := get_edge(a, b)
	return edge != null and edge.enabled


func weight_of(a: StringName, b: StringName) -> float:
	var edge := get_edge(a, b)
	return edge.weight if edge != null else INF


func neighbors(id: StringName, include_blocked := false) -> Array[StringName]:
	var result: Array[StringName] = []
	for edge: Edge in _adjacency.get(id, []):
		if include_blocked or edge.enabled:
			result.append(edge.to)
	return result


#Blocks or unblocks the connection in both directions so a bridge never ends half closed
func set_edge_enabled(a: StringName, b: StringName, enabled: bool) -> bool:
	var forward := get_edge(a, b)
	if forward == null:
		return false
	var changed := forward.enabled != enabled
	forward.enabled = enabled
	var backward := get_edge(b, a)
	if backward != null:
		changed = changed or backward.enabled != enabled
		backward.enabled = enabled
	if changed:
		version += 1
	return true


#Each connection once (a < b for two-way edges), for drawing and listings
func undirected_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for a: StringName in _adjacency:
		for edge: Edge in _adjacency[a]:
			if has_edge(edge.to, a) and String(edge.to) < String(a):
				continue
			result.append({"a": a, "b": edge.to, "weight": edge.weight, "enabled": edge.enabled})
	return result


#Dijkstra; blocked arcs and "forbidden" vertices are skipped (the start itself may be forbidden)
func shortest_path(from: StringName, to: StringName, forbidden: Array = []) -> PathResult:
	var result := PathResult.new()
	if not _adjacency.has(from) or not _adjacency.has(to):
		result.reason = "Vértice desconocido: %s o %s" % [from, to]
		return result
	if from == to:
		result.found = true
		result.path = [from]
		result.cost = 0.0
		return result
	if forbidden.has(to):
		result.reason = "El destino %s está excluido de esta búsqueda" % to
		return result

	var dist: Dictionary = {from: 0.0}
	var previous: Dictionary = {}
	var settled: Dictionary = {}
	var queue := MinHeap.new()
	queue.push(from, 0.0)
	while not queue.is_empty():
		var current: StringName = queue.pop()
		if settled.has(current):
			continue
		settled[current] = true
		if current == to:
			break
		for edge: Edge in _adjacency[current]:
			if not edge.enabled or forbidden.has(edge.to) or settled.has(edge.to):
				continue
			var candidate: float = dist[current] + edge.weight
			if candidate < dist.get(edge.to, INF):
				dist[edge.to] = candidate
				previous[edge.to] = current
				queue.push(edge.to, candidate)

	if not settled.has(to):
		result.reason = "Sin camino de %s a %s: las conexiones habilitadas no llegan" % [from, to]
		return result
	var path: Array[StringName] = [to]
	var step: StringName = to
	while step != from:
		step = previous[step]
		path.push_front(step)
	result.found = true
	result.path = path
	result.cost = dist[to]
	return result


func _set_arc(a: StringName, b: StringName, weight: float) -> void:
	var edge := get_edge(a, b)
	if edge == null:
		(_adjacency[a] as Array[Edge]).append(Edge.new(b, weight))
	else:
		edge.weight = weight
