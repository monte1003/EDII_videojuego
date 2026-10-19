class_name MinHeap
extends RefCounted

#Binary min-heap used as the priority queue of Dijkstra.
#Equal priorities leave in insertion order, so the routes are deterministic.

var _items: Array[Variant] = []
var _priorities: Array[float] = []
var _order: Array[int] = []
var _counter := 0


func is_empty() -> bool:
	return _items.is_empty()


func size() -> int:
	return _items.size()


func push(item: Variant, priority: float) -> void:
	_items.append(item)
	_priorities.append(priority)
	_order.append(_counter)
	_counter += 1
	_sift_up(_items.size() - 1)


#Removes and returns the item with the lowest priority
func pop() -> Variant:
	var top: Variant = _items[0]
	var last := _items.size() - 1
	_swap(0, last)
	_items.pop_back()
	_priorities.pop_back()
	_order.pop_back()
	if not _items.is_empty():
		_sift_down(0)
	return top


func _less(a: int, b: int) -> bool:
	if _priorities[a] != _priorities[b]:
		return _priorities[a] < _priorities[b]
	return _order[a] < _order[b]


func _swap(a: int, b: int) -> void:
	var item: Variant = _items[a]
	_items[a] = _items[b]
	_items[b] = item
	var priority := _priorities[a]
	_priorities[a] = _priorities[b]
	_priorities[b] = priority
	var order := _order[a]
	_order[a] = _order[b]
	_order[b] = order


func _sift_up(index: int) -> void:
	while index > 0:
		var parent := floori((index - 1) / 2.0)
		if not _less(index, parent):
			return
		_swap(index, parent)
		index = parent


func _sift_down(index: int) -> void:
	var count := _items.size()
	while true:
		var left := index * 2 + 1
		var right := left + 1
		var smallest := index
		if left < count and _less(left, smallest):
			smallest = left
		if right < count and _less(right, smallest):
			smallest = right
		if smallest == index:
			return
		_swap(index, smallest)
		index = smallest
