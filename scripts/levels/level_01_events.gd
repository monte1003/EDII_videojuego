class_name Level01Events
extends RefCounted

#The feed refreshing: now and then a fragile bridge flashes and goes down for a while; it never leaves a racer without a route

signal warned(a: StringName, b: StringName, seconds: float)
signal closed(a: StringName, b: StringName)
signal reopened(a: StringName, b: StringName)

enum Phase { WAITING, WARNING, CLOSED }

var phase := Phase.WAITING
#The bridge that is flashing or down; empty while none is
var edge: Array[StringName] = []

var _settings: Level01Settings
var _rng: RandomNumberGenerator
var _candidates: Array[Array] = []
var _timer := 0.0


func _init(config: Level01Settings, rng: RandomNumberGenerator, fragile: Array[Array]) -> void:
	_settings = config
	_rng = rng
	_candidates = fragile
	_timer = config.feed_first


#"can_close" tells whether a bridge may go down now: it receives both ends and returns a bool
func tick(delta: float, can_close: Callable) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	match phase:
		Phase.WAITING:
			var pick := _pick(can_close)
			if pick.is_empty():
				_timer = 2.0
				return
			edge.assign(pick)
			phase = Phase.WARNING
			_timer = _settings.feed_warning
			warned.emit(edge[0], edge[1], _settings.feed_warning)
		Phase.WARNING:
			phase = Phase.CLOSED
			_timer = _settings.feed_duration
			closed.emit(edge[0], edge[1])
		Phase.CLOSED:
			phase = Phase.WAITING
			_timer = _rng.randf_range(_settings.feed_interval.x, _settings.feed_interval.y)
			var done: Array[StringName] = edge.duplicate()
			edge.clear()
			reopened.emit(done[0], done[1])


func is_down(a: StringName, b: StringName) -> bool:
	return phase == Phase.CLOSED and not edge.is_empty() \
		and ((edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a))


#Seconds until the next change of the feed
func time_left() -> float:
	return maxf(_timer, 0.0)


func _pick(can_close: Callable) -> Array:
	var options: Array[Array] = _candidates.duplicate()
	#Shuffled with the level's generator so a seed repeats the round
	for index in range(options.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var swap := options[index]
		options[index] = options[other]
		options[other] = swap
	for option in options:
		if can_close.call(option[0], option[1]):
			return option
	return []
