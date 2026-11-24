class_name TrendBoard
extends RefCounted

#The bubbles of the trend war, with no nodes. One zone is open at a time and every bubble is born on a point that zone lists, never anywhere
#else. A ring on the floor tells where a bubble is about to be born; it lives until somebody takes it or until it gets old, and then it is
#born again somewhere else. As the round of the zone goes on there are more bubbles; the trend of every player always has one somewhere, and
#once per zone the viral bubble comes. The same seed and the same players give the same game

signal bubble_announced(id: int)
signal bubble_spawned(id: int)
signal bubble_gone(id: int, taken: bool)

#Of the free points, a new bubble picks one of this many of the best
const CHOICES := 3


class Bubble:
	var id: int
	var slot: int
	var kind: int
	var phase := 0.0
	var age := 0.0
	#Seconds until it is born; while above 0 only its ring shows
	var pending := 0.0


#Every bubble announced or alive, by its id
var bubbles: Dictionary = {}
#Seconds this board has run
var clock := 0.0
#The zone that is open (-1 for none)
var zone := -1
#In a room every computer but the server only shows the bubbles the server tells: it makes none and lets none age out
var mirror := false

var _layout: TrendLayout
var _settings: TrendSettings
var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _on_slot: Dictionary = {}
var _slot_rest: Dictionary = {}
#The share of the round of the zone at which the viral bubble comes, and whether it came
var _viral_at := 1.0
var _viral_done := false


func _init(layout: TrendLayout, settings: TrendSettings, seed_value: int) -> void:
	_layout = layout
	_settings = settings
	_rng.seed = seed_value


#Opens a zone: the bubbles of the last one go and the first ones of this one are announced
func open_zone(new_zone: int, players: Dictionary, wanted: Dictionary) -> void:
	#A mirror keeps what the server told: its bubbles of the new zone may come before this computer opens it
	if mirror:
		zone = new_zone
		return
	close()
	zone = new_zone
	_viral_at = _rng.randf_range(_settings.viral_window.x, _settings.viral_window.y)
	_viral_done = false
	tick(0.0, 0.0, players, wanted)


#Every bubble goes
func close() -> void:
	for id: int in bubbles.keys():
		_remove(id, false)
	_slot_rest.clear()
	zone = -1


#How many bubbles the zone holds at that share of its round, with that many players
func target_count(share: float, player_count: int) -> int:
	var base := lerpf(float(_settings.bubbles_start), float(_settings.bubbles_end), clampf(share, 0.0, 1.0))
	return mini(roundi(base) + _settings.bubbles_per_player * maxi(player_count - 1, 0), maxi(_layout.zone_slots(maxi(zone, 0)).size() - 1, 1))


#Moves time on. "share" is how far the round of the zone is, "players" {player id: position} and "wanted" {player id: kind it follows}.
#The rings become bubbles, the old bubbles move, every trend that is followed gets a bubble when it has none, the viral one comes at its
#moment and the rest of the room is filled with kinds at random, half of them the kinds that are followed
func tick(delta: float, share: float, players: Dictionary, wanted: Dictionary) -> void:
	clock += delta
	for slot: int in _slot_rest.keys():
		_slot_rest[slot] = float(_slot_rest[slot]) - delta
		if float(_slot_rest[slot]) <= 0.0:
			_slot_rest.erase(slot)
	if zone < 0:
		return
	for id: int in bubbles.keys():
		var bubble: Bubble = bubbles[id]
		if bubble.pending > 0.0:
			bubble.pending -= delta
			if bubble.pending <= 0.0:
				bubble.pending = 0.0
				bubble_spawned.emit(id)
			continue
		bubble.age += delta
		if not mirror and bubble.age >= _settings.bubble_life and bubble.kind != TrendRules.VIRAL:
			_remove(id, false)
	if mirror:
		return
	for id: int in wanted:
		var kind := int(wanted[id])
		if kind >= 0 and count_of(kind) == 0:
			_spawn(kind, players, players.get(id, Vector3.ZERO))
	if not _viral_done and share >= _viral_at:
		_viral_done = true
		_spawn(TrendRules.VIRAL, players, Vector3.ZERO)
	var target := target_count(share, players.size())
	var followed: Array[int] = []
	for id: int in wanted:
		if int(wanted[id]) >= 0:
			followed.append(int(wanted[id]))
	while bubbles.size() < target:
		var kind := _rng.randi() % TrendCatalog.COUNT
		if not followed.is_empty() and _rng.randf() < 0.5:
			kind = followed[_rng.randi() % followed.size()]
		if _spawn(kind, players, Vector3.ZERO) == null:
			break


func kind_of(id: int) -> int:
	return (bubbles[id] as Bubble).kind if bubbles.has(id) else -1


#Whether the bubble is born (not only its ring)
func is_live(id: int) -> bool:
	return bubbles.has(id) and (bubbles[id] as Bubble).pending <= 0.0


#How many bubbles of a kind are announced or alive
func count_of(kind: int) -> int:
	var count := 0
	for bubble: Bubble in bubbles.values():
		if bubble.kind == kind:
			count += 1
	return count


func slot_of(id: int) -> int:
	return (bubbles[id] as Bubble).slot


func bob_of(id: int) -> float:
	return (bubbles[id] as Bubble).phase


#A bubble the server announced, with its id, point, kind and bob
func mirror_add(id: int, slot: int, kind: int, bob: float) -> void:
	if bubbles.has(id) or slot < 0 or slot >= _layout.slots.size() or kind < 0 or kind > TrendRules.VIRAL:
		return
	var bubble := Bubble.new()
	bubble.id = id
	bubble.slot = slot
	bubble.kind = kind
	bubble.phase = bob
	bubble.pending = _settings.spawn_notice
	bubbles[id] = bubble
	_on_slot[slot] = id
	bubble_announced.emit(id)


#A bubble the server took away (taken by somebody or old)
func mirror_gone(id: int, taken: bool) -> void:
	if bubbles.has(id):
		_remove(id, taken)


#How far its ring is from being a bubble: 0 when it is announced, 1 when it is born
func birth_share(id: int) -> float:
	return 1.0 - (bubbles[id] as Bubble).pending / maxf(_settings.spawn_notice, 0.01)


#How close to moving away an old bubble is, 0 young and 1 about to go
func age_share(id: int) -> float:
	return clampf((bubbles[id] as Bubble).age / _settings.bubble_life, 0.0, 1.0)


#Where a bubble floats: over its point, bobbing a little
func position_of(id: int) -> Vector3:
	var bubble: Bubble = bubbles[id]
	var at: Vector3 = _layout.slots[bubble.slot]["position"]
	return at + Vector3(0.0, sin(clock * 1.6 + bubble.phase) * 0.12, 0.0)


#Takes a bubble: it is gone at once; another one will be born on another point. Returns its kind, or -1 when it was not there or not born
func take(id: int) -> int:
	if not is_live(id):
		return -1
	var kind := (bubbles[id] as Bubble).kind
	_remove(id, true)
	return kind


func _remove(id: int, taken: bool) -> void:
	var bubble: Bubble = bubbles[id]
	bubbles.erase(id)
	_on_slot.erase(bubble.slot)
	_slot_rest[bubble.slot] = _settings.point_rest
	bubble_gone.emit(id, taken)


#A new bubble of "kind" announced on a free point of the zone. For somebody's trend ("for_player" its position) the point is one of the
#closest to it that is not on top of it; otherwise it is about as far from every player. Never on a point that rests or next to a player
func _spawn(kind: int, players: Dictionary, for_player: Vector3) -> Bubble:
	var slot := _pick_slot(players, for_player)
	if slot < 0:
		return null
	var bubble := Bubble.new()
	bubble.id = _next_id
	_next_id += 1
	bubble.slot = slot
	bubble.kind = kind
	bubble.phase = _rng.randf() * TAU
	bubble.pending = _settings.spawn_notice
	bubbles[bubble.id] = bubble
	_on_slot[slot] = bubble.id
	bubble_announced.emit(bubble.id)
	return bubble


func _pick_slot(players: Dictionary, for_player: Vector3) -> int:
	var scored: Array[Array] = []
	var crowded: Array[Array] = []
	for slot in _layout.zone_slots(zone):
		if _on_slot.has(slot) or _slot_rest.has(slot):
			continue
		var at: Vector3 = _layout.slots[slot]["position"]
		var closest := INF
		var farthest := 0.0
		for id: int in players:
			var meters := at.distance_to(players[id])
			closest = minf(closest, meters)
			farthest = maxf(farthest, meters)
		#A random part keeps the points changing
		var score := _rng.randf() * 3.0
		if for_player != Vector3.ZERO:
			score += for_player.distance_to(at)
		elif players.size() > 1:
			score += farthest - closest
		if closest < _settings.spawn_clear:
			crowded.append([score, slot])
		else:
			scored.append([score, slot])
	if scored.is_empty():
		scored = crowded
	if scored.is_empty():
		return -1
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return scored[_rng.randi() % mini(CHOICES, scored.size())][1]
