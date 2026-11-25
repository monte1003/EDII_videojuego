class_name TrendBoard
extends RefCounted

#Trend war bubbles with no nodes: born only on the open zone's points, announced by a floor ring

signal bubble_announced(id: int)
signal bubble_spawned(id: int)
signal bubble_gone(id: int, taken: bool)

#A new bubble picks among this many best free points
const CHOICES := 3


class Bubble:
	var id: int
	var slot: int
	var kind: int
	var phase := 0.0
	var age := 0.0
	#Seconds until born; only its ring shows meanwhile
	var pending := 0.0


#Every announced or live bubble by id
var bubbles: Dictionary = {}
var clock := 0.0
#Open zone, -1 for none
var zone := -1
#In a room non-servers only show what the server tells
var mirror := false

var _layout: TrendLayout
var _settings: TrendSettings
var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _on_slot: Dictionary = {}
var _slot_rest: Dictionary = {}
#Share of the zone round when the viral bubble comes, and whether it came
var _viral_at := 1.0
var _viral_done := false


func _init(layout: TrendLayout, settings: TrendSettings, seed_value: int) -> void:
	_layout = layout
	_settings = settings
	_rng.seed = seed_value


#Opens a zone: the old bubbles go and the first new ones are announced
func open_zone(new_zone: int, players: Dictionary, wanted: Dictionary) -> void:
	#A mirror keeps what the server told, even before it opens the zone
	if mirror:
		zone = new_zone
		return
	close()
	zone = new_zone
	_viral_at = _rng.randf_range(_settings.viral_window.x, _settings.viral_window.y)
	_viral_done = false
	tick(0.0, 0.0, players, wanted)


func close() -> void:
	for id: int in bubbles.keys():
		_remove(id, false)
	_slot_rest.clear()
	zone = -1


#Bubble count at that share of the round with that many players
func target_count(share: float, player_count: int) -> int:
	var base := lerpf(float(_settings.bubbles_start), float(_settings.bubbles_end), clampf(share, 0.0, 1.0))
	return mini(roundi(base) + _settings.bubbles_per_player * maxi(player_count - 1, 0), maxi(_layout.zone_slots(maxi(zone, 0)).size() - 1, 1))


#Advances time: rings hatch, old bubbles move and every followed trend gets a bubble
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


#Born, not only its ring
func is_live(id: int) -> bool:
	return bubbles.has(id) and (bubbles[id] as Bubble).pending <= 0.0


#Announced or live bubbles of a kind
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


#Bubble announced by the server
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


#Bubble removed by the server (taken or old)
func mirror_gone(id: int, taken: bool) -> void:
	if bubbles.has(id):
		_remove(id, taken)


#Ring progress: 0 announced, 1 born
func birth_share(id: int) -> float:
	return 1.0 - (bubbles[id] as Bubble).pending / maxf(_settings.spawn_notice, 0.01)


#Age: 0 young, 1 about to move
func age_share(id: int) -> float:
	return clampf((bubbles[id] as Bubble).age / _settings.bubble_life, 0.0, 1.0)


#Floats over its point, bobbing
func position_of(id: int) -> Vector3:
	var bubble: Bubble = bubbles[id]
	var at: Vector3 = _layout.slots[bubble.slot]["position"]
	return at + Vector3(0.0, sin(clock * 1.6 + bubble.phase) * 0.12, 0.0)


#Takes a bubble at once; returns its kind or -1
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


#Announces a "kind" bubble: near its player for a trend, otherwise far from everybody
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
