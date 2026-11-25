class_name Level01Events
extends RefCounted

#The feed: a fragile bridge flashes and falls for a while, never cutting a racer's route

signal warned(a: StringName, b: StringName, seconds: float)
signal closed(a: StringName, b: StringName)
signal reopened(a: StringName, b: StringName)

enum Phase { WAITING, WARNING, CLOSED }

#Share of times it picks the bridge nearest a racer
const FOCUS_CHANCE := 0.7

var phase := Phase.WAITING
#Flashing or fallen bridge; empty when none
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


#"can_close" says if a bridge may fall now; "threat" gives its distance to the nearest racer
func tick(delta: float, can_close: Callable, threat := Callable()) -> void:
	#No fragile bridges, no feed
	if _candidates.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	match phase:
		Phase.WAITING:
			var pick := _pick(can_close, threat)
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


func delay_by(seconds: float) -> void:
	_timer += seconds


func is_down(a: StringName, b: StringName) -> bool:
	return phase == Phase.CLOSED and not edge.is_empty() \
		and ((edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a))


#In a room the server picks; the others apply its changes
func apply(change: String, a: StringName, b: StringName, seconds: float) -> void:
	match change:
		"warn":
			edge.assign([a, b])
			phase = Phase.WARNING
			_timer = seconds
			warned.emit(a, b, seconds)
		"close":
			edge.assign([a, b])
			phase = Phase.CLOSED
			_timer = _settings.feed_duration
			closed.emit(a, b)
		"open":
			edge.clear()
			phase = Phase.WAITING
			_timer = _settings.feed_interval.x
			reopened.emit(a, b)


func time_left() -> float:
	return maxf(_timer, 0.0)


func _pick(can_close: Callable, threat: Callable) -> Array:
	var options: Array[Array] = _candidates.duplicate()
	#Shuffled with the level generator so a seed repeats the round
	for index in range(options.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var swap := options[index]
		options[index] = options[other]
		options[other] = swap
	if threat.is_valid() and _rng.randf() < FOCUS_CHANCE:
		options.sort_custom(func(first: Array, second: Array) -> bool:
			return float(threat.call(first[0], first[1])) < float(threat.call(second[0], second[1])))
	for option in options:
		if can_close.call(option[0], option[1]):
			return option
	return []
