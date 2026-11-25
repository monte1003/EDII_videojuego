class_name Level01
extends RoundScene

#Level 1 "Carrera del feed": racers cross an island graph to the goal

enum Phase { COUNTDOWN, RUNNING, ENDED }

const SCREEN_ID := &"level_01"
const FALL_Y := -12.0
#Iris lead over FALL_Y while this screen's racer falls
const IRIS_LEAD := 7.0
#Spacing of start places
const START_SPREAD := 2.2
#Blinking protection after getting up from a blow
const RECOVER_GRACE := 1.3
#Feet this far under the course floor are off it
const COURSE_DEPTH := 1.5
#Start offsets in front of the three starting bridges
const START_INSET := 4.0
const START_BACK := 1.2
#Blow strength and time down per obstacle
const SPINNER_STRENGTH := 0.9
const SPINNER_STUN := 0.6
const SOFT_STRENGTH := 0.65
const SOFT_STUN := 0.5
#Rolling ball push share and strength
const BALL_PUSH_SHARE := 0.75
const BALL_STRENGTH := 0.75
const BALL_STUN := 0.5
#Ground snap so bodies follow a slide
const SLIDE_SNAP := 0.6
#Share of slide flow kept after leaving it
const SLIDE_CARRY := 0.8
#Deck bubble: ride time, rise share and float height
const LIFT_TIME := 6.0
const LIFT_RISE_SHARE := 0.4
const LIFT_HOVER := 2.4
#Comment push multiplier
const COMMENT_PUSH_SHARE := 1.4

#Tuning numbers; empty uses the defaults
@export var settings: Level01Settings

var phase := Phase.COUNTDOWN
#Course graph: keeps routes open, ranks racers and draws routes (F3)
var graph: WeightedGraph
var rules: Level01Rules
var events: Level01Events
#Second feed when the settings ask for one
var extra_events: Level01Events
#In a room non-servers take the feed bridges from the server
var _feed_from_server := false
var tiles := Level01Tiles.new()

var _players: Dictionary = {}
var _locators: Dictionary = {}
var _names: Dictionary = {}
var _local_id := 0
var _rng := RandomNumberGenerator.new()
var _phase_timer := 0.0
var _countdown_shown := 0
var _hud_timer := 0.0
var _standings_timer := 0.0
#Where each finished racer walks, keeping the goal gate free
var _cheering: Dictionary = {}
var _hints_shown: Dictionary = {}
#Goal distance with every bridge open, so standings never jump
var _cost_to_goal: Dictionary = {}
var _debug: Level01Debug
#Turning belts: built direction and about-to-turn flag
var _belt_forward: Dictionary = {}
var _belt_warned: Dictionary = {}
#Slide flow each racer just left
var _slide_carry: Dictionary = {}
#Racers riding a deck bubble back up
var _lifts: Dictionary = {}
#Deck pads, measured once
var _deck_lifts: Array[Dictionary] = []
var _decks: Array[Dictionary] = []
#Bubble each fallen racer will ride
var _fell_onto: Dictionary = {}
#Last comment stage, to play cues once
var _comment_stage: Dictionary = {}

@onready var _world: Level01World = $World
@onready var _level_input: LevelInput = $LevelInput
@onready var _hud: LevelHud = $Hud


func _ready() -> void:
	super()
	if settings == null:
		settings = Level01Settings.new()
	#In a room the race ends when everybody arrives or time runs out
	if GameSession.is_networked() and not GameSession.practice:
		settings = settings.duplicate()
		settings.finish_window = 0.0
	if ScreenFlow.tree.has(SCREEN_ID):
		ScreenFlow.mark_current(SCREEN_ID)
	seed_rng(_rng, settings.random_seed)

	graph = Level01Layout.build_graph()
	_deck_lifts = Level01Layout.deck_lifts()
	_decks = Level01Layout.all_decks()
	_measure_the_course()
	var human_ids: Array[int] = []
	for slot in participants:
		human_ids.append(slot.player_id)
	_local_id = GameSession.local_id if human_ids.has(GameSession.local_id) else human_ids[0]
	rules = Level01Rules.new(settings, human_ids, Level01Layout.START)
	rules.outcome_decided.connect(_on_outcome)
	rules.player_fell.connect(_on_player_fell)
	rules.racer_finished.connect(_on_racer_finished)
	rules.window_opened.connect(_on_window_opened)

	_spawn_racers()
	_world.build(_locator_list(), settings.belt_speed, tiles)
	events = Level01Events.new(settings, _rng, Level01Layout.fragile_edges())
	events.warned.connect(_on_feed_warned)
	events.closed.connect(_on_feed_closed)
	events.reopened.connect(_on_feed_reopened)
	if settings.feed_extra_delay > 0.0:
		extra_events = Level01Events.new(settings, _rng, Level01Layout.fragile_edges())
		extra_events.delay_by(settings.feed_extra_delay)
		extra_events.warned.connect(_on_feed_warned)
		extra_events.closed.connect(_on_feed_closed)
		extra_events.reopened.connect(_on_feed_reopened)
	#In a room the server picks the feed bridges for everybody
	_feed_from_server = _networked_round() and not GameSession.net.is_host()
	if _networked_round() and GameSession.net.is_host():
		_tell_feed(events, 0)
		if extra_events != null:
			_tell_feed(extra_events, 1)
	#Story tiles stepped by anyone drop for everybody
	if _networked_round():
		GameSession.net.round_event.connect(_on_round_event)
		tiles.tile_stepped.connect(_on_tile_stepped)

	_debug = Level01Debug.new()
	add_child(_debug)
	_debug.setup(self, $DebugView, _hud)
	_level_input.debug_toggled.connect(_debug.toggle_view)
	_level_input.demo_toggled.connect(_debug.toggle_demo)
	_hud.retry_requested.connect(_retry)
	_hud.menu_requested.connect(GameSession.abandon)

	_hud.set_time(rules.time_left)
	_hud.set_attempts(settings.attempts, settings.attempts)
	_hud.hide_countdown()
	_update_standings()
	_help.setup(HelpPages.level_one(settings))
	_begin_countdown()


func local_locator() -> PlayerLocator:
	return _locators[_local_id]


func local_player() -> Player:
	return _players[_local_id]


#Closes or opens a bridge for the graph routes (F4 demo)
func set_bridge_closed(a: StringName, b: StringName, closed: bool) -> void:
	graph.set_edge_enabled(a, b, not closed)


func _physics_process(delta: float) -> void:
	if paused or filming:
		return
	_debug.tick(delta)
	match phase:
		Phase.COUNTDOWN:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_round()
			else:
				_hud.tick_countdown(_phase_timer)
				var shown := ceili(_phase_timer)
				if shown != _countdown_shown:
					_countdown_shown = shown
					_world.set_start_lights(shown, false)
		Phase.RUNNING:
			_update_running(delta)


func _help_allowed() -> bool:
	return phase != Phase.ENDED


#Goal cost from every island with every bridge open
func _measure_the_course() -> void:
	var open := Level01Layout.build_graph()
	for id: StringName in Level01Layout.POSITIONS:
		var route := open.shortest_path(id, Level01Layout.GOAL)
		_cost_to_goal[id] = route.cost if route.found else INF


func _spawn_racers() -> void:
	var slots := _start_slots(participants.size())
	var points: Array[Vector3] = []
	for slot in slots:
		points.append(slot[0])
	var spawned := spawn_players(_actors, points)
	for index in spawned.size():
		var player := spawned[index]
		player.face(slots[index][1])
		player.set_input_enabled(false)
		var shown := participants[index].display_name
		_register_racer(player, shown, player.player_id)
		_names[player.player_id] = "TÚ" if player.player_id == _local_id else shown


#Each racer starts in front of a random starting bridge; extras stand beside
func _start_slots(count: int) -> Array[Array]:
	var centre := _spawn_position(Level01Layout.START)
	var mouths: Array[Vector3] = []
	for edge: Array in Level01Layout.EDGES:
		if edge[0] == Level01Layout.START:
			var to: Vector3 = Level01Layout.POSITIONS[edge[1]]
			mouths.append(Vector3(to.x - centre.x, 0.0, to.z - centre.z).normalized())
	for index in range(mouths.size() - 1, 0, -1):
		var other := _rng.randi() % (index + 1)
		var kept := mouths[index]
		mouths[index] = mouths[other]
		mouths[other] = kept
	var slots: Array[Array] = []
	for index in count:
		var way := mouths[index % mouths.size()]
		var across := Vector3(-way.z, 0.0, way.x)
		var row := floori(float(index) / mouths.size())
		slots.append([centre + way * START_INSET * absf(way.x) + Vector3(0.0, 0.0, START_BACK) + across * START_SPREAD * row, way])
	return slots


func _register_racer(player: Player, shown_name: String, id: int) -> void:
	_players[id] = player
	_names[id] = shown_name
	var locator := PlayerLocator.new()
	locator.player_id = id
	locator.place_changed.connect(_on_place_changed.bind(id))
	add_child(locator)
	_locators[id] = locator
	locator.force_vertex(Level01Layout.START)
	player.hit_taken.connect(_on_racer_hit.bind(player))
	player.landed.connect(_on_racer_landed.bind(player))
	player.floor_snap_length = SLIDE_SNAP
	player.dive_enabled = true
	player.invulnerable_time = RECOVER_GRACE


func _locator_list() -> Array[PlayerLocator]:
	var list: Array[PlayerLocator] = []
	for locator: PlayerLocator in _locators.values():
		list.append(locator)
	return list


func _any_player() -> Player:
	return _players[_local_id]


func _spawn_position(vertex: StringName) -> Vector3:
	return Level01Layout.POSITIONS[vertex] + Vector3(0, 0.05, 0)


func _begin_countdown() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	phase = Phase.COUNTDOWN
	_phase_timer = settings.countdown_seconds
	_countdown_shown = ceili(_phase_timer)
	_hud.tick_countdown(_phase_timer)
	_world.set_start_lights(_countdown_shown, false)
	var move_keys := " ".join([InputHints.key_label(&"move_forward"), InputHints.key_label(&"move_left"),
		InputHints.key_label(&"move_back"), InputHints.key_label(&"move_right")])
	_hud.show_mission("Llega a la meta", [
		"move=%s|mover" % move_keys, "jump=%s|saltar" % InputHints.key_label(&"jump"), "help=%s|ayuda" % InputHints.key_label(&"help")], 5.0)


func _begin_round() -> void:
	phase = Phase.RUNNING
	for id: int in _players:
		(_players[id] as Player).set_input_enabled(id == _local_id)
	_hud.show_go()
	_world.set_start_lights(3, true)
	_world.cheer(2.4)


func _update_running(delta: float) -> void:
	rules.tick(delta)
	if phase != Phase.RUNNING:
		return
	if not _feed_from_server:
		events.tick(delta, _can_close, _edge_threat)
		if extra_events != null:
			extra_events.tick(delta, _can_close, _edge_threat)
	for id: int in _players.keys():
		if not _players.has(id):
			continue
		var falling_player := _players[id] as Player
		if id == _local_id and falling_player.global_position.y < FALL_Y + IRIS_LEAD and falling_player.velocity.y < 0.0:
			iris.close()
		if falling_player.global_position.y < FALL_Y:
			rules.fall(id)
			if phase != Phase.RUNNING:
				return
	_walk_finished()
	_apply_turns()
	_apply_belts()
	_apply_hazards()
	_apply_blocks()
	_apply_balls()
	_apply_comments()
	_apply_traps()
	_tick_tiles(delta)
	_apply_lifts(delta)
	_note_falls()
	_apply_deck_pads()
	_update_progress()
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_hud.set_time(rules.time_left)
		_update_window()
	_standings_timer += delta
	if _standings_timer >= 0.25:
		_standings_timer = 0.0
		_update_standings()


#Finished racers walk into the goal island
func _walk_finished() -> void:
	for id: int in _cheering:
		var player := _players[id] as Player
		var to: Vector3 = _cheering[id] - player.global_position
		to.y = 0.0
		if to.length() < 0.8:
			player.move_input = Vector2.ZERO
			continue
		var local := (player.get_node("CameraRig") as PlayerCamera).get_yaw_basis().inverse() * to.normalized()
		player.move_input = Vector2(local.x, local.z)


#Belts drag, slides carry faster and fans push across
func _apply_belts() -> void:
	for id: int in _players:
		var player := _players[id] as Player
		var locator := _locators[id] as PlayerLocator
		var flow := Vector3.ZERO
		var wind := Vector3.ZERO
		if locator.on_bridge:
			if player.is_on_floor():
				flow = Level01Layout.drift(locator.bridge_a, locator.bridge_b, rules.elapsed, settings.belt_speed)
			var fan := Level01Layout.fan_of(locator.bridge_a, locator.bridge_b)
			if not fan.is_empty() and not player.carried:
				wind = Level01Traps.fan_drift(fan, rules.elapsed, player.global_position)
				if wind != Vector3.ZERO and id == _local_id:
					_hint_once(&"fan", "El viento viral empuja de lado: camina contra él")
		player.external_velocity = flow + wind
		_carry_slide(id, player, flow)


#Slide speed fades over the island after leaving it
func _carry_slide(id: int, player: Player, flow: Vector3) -> void:
	if flow.length() > settings.belt_speed + 0.5:
		_slide_carry[id] = flow
	elif _slide_carry.has(id):
		if player.is_on_floor():
			player.push_velocity = (_slide_carry[id] as Vector3) * SLIDE_CARRY
		_slide_carry.erase(id)


#Spinner bars throw; a jump clears them
func _apply_hazards() -> void:
	_world.update_hazards(rules.elapsed, tiles)
	for id: int in _players:
		var locator := _locators[id] as PlayerLocator
		if locator.on_bridge or not Level01Layout.SPINNERS.has(locator.vertex):
			continue
		var player := _players[id] as Player
		var spinner: Dictionary = Level01Layout.SPINNERS[locator.vertex]
		var centre: Vector3 = Level01Layout.POSITIONS[locator.vertex]
		if not Level01Hazards.hits(centre, spinner, rules.elapsed, player.global_position, player.global_position.y - centre.y):
			continue
		if not _can_strike(id):
			continue
		var direction := Level01Hazards.push_direction(centre, spinner, player.global_position)
		_hit_racer(player, direction * settings.spinner_push, SPINNER_STRENGTH, SPINNER_STUN)
		if id == _local_id:
			_hud.flash(Palette.CORAL, 0.35, 0.4)


#Belts turn by the clock: costs change, arrows blink first
func _apply_turns() -> void:
	for index in Level01Layout.TURNS.size():
		var turn: Dictionary = Level01Layout.TURNS[index]
		var edge: Array = turn["edge"]
		var warning := Level01Layout.belt_warning(turn, rules.elapsed)
		if warning != _belt_warned.get(index, false):
			_belt_warned[index] = warning
			_world.warn_belt(edge[0], edge[1], warning)
		var forward := Level01Layout.belt_forward(turn, rules.elapsed)
		if forward == _belt_forward.get(index, true):
			continue
		_belt_forward[index] = forward
		for listed in Level01Layout.EDGES:
			if listed[0] == edge[0] and listed[1] == edge[1]:
				var costs := Level01Layout.belt_costs(listed, forward)
				graph.set_weights(edge[0], edge[1], costs.x, costs.y)
		_world.set_belt_direction(edge[0], edge[1], forward)
		_hint_once(&"turn", "La cinta del scroll cambia de sentido")


#Rolling balls throw; a jump clears them
func _apply_balls() -> void:
	for id: int in _players:
		var locator := _locators[id] as PlayerLocator
		if locator.on_bridge:
			continue
		var player := _players[id] as Player
		for ball: Dictionary in Level01Layout.BALLS:
			if ball["island"] != locator.vertex:
				continue
			var floor_y: float = (Level01Layout.POSITIONS[ball["island"]] as Vector3).y
			if not Level01Hazards.ball_hits(ball, rules.elapsed, player.global_position, player.global_position.y - floor_y):
				continue
			if not _can_strike(id):
				continue
			var push := Level01Hazards.ball_push(ball, rules.elapsed, player.global_position)
			_hit_racer(player, push * settings.spinner_push * BALL_PUSH_SHARE, BALL_STRENGTH, BALL_STUN)
			if id == _local_id:
				_hud.flash(Palette.CORAL, 0.35, 0.4)


#Comments sweep their bridge after a warning; a jump clears them
func _apply_comments() -> void:
	for index in Level01Layout.COMMENTS.size():
		var comment: Dictionary = Level01Layout.COMMENTS[index]
		var stage := int(Level01Hazards.comment_state(comment, rules.elapsed)["stage"])
		if stage != int(_comment_stage.get(index, -1)):
			_comment_stage[index] = stage
			_comment_cue(stage)
		if stage != Level01Hazards.COMMENT_PUSHING:
			continue
		for id: int in _players:
			var locator := _locators[id] as PlayerLocator
			if not locator.on_bridge or Level01Layout.comment_of(locator.bridge_a, locator.bridge_b) != comment:
				continue
			var player := _players[id] as Player
			if not Level01Hazards.comment_hits(comment, rules.elapsed, player.global_position) or not _can_strike(id):
				continue
			_hit_racer(player, Level01Hazards.comment_push(comment, rules.elapsed) * settings.push_speed * COMMENT_PUSH_SHARE, SOFT_STRENGTH, SOFT_STUN)
			if id == _local_id:
				_hud.flash(Palette.CORAL, 0.3, 0.4)
				_hint_once(&"comment", "Un comentario empuja: salta o cruza por el otro lado")


#Axes, likes, wheels and giant balls throw; bubble riders are safe
func _apply_traps() -> void:
	var now := rules.elapsed
	for id: int in _players:
		var player := _players[id] as Player
		if player.carried or _lifts.has(id):
			continue
		var locator := _locators[id] as PlayerLocator
		var feet := player.global_position
		var push := Vector3.ZERO
		var strength := SPINNER_STRENGTH
		var stun := SPINNER_STUN
		if locator.on_bridge:
			var row := Level01Layout.axes_of(locator.bridge_a, locator.bridge_b)
			if not row.is_empty():
				var axe := Level01Traps.axe_hits(row, now, feet)
				if axe >= 0:
					var across: Vector3 = Level01Traps.bridge_frame(row["edge"])["across"]
					push = (across * Level01Traps.axe_heading(row, axe, now)) * settings.axe_push
			for puncher in Level01Layout.punchers_of(locator.bridge_a, locator.bridge_b):
				if push == Vector3.ZERO and Level01Traps.punch_hits(puncher, now, feet):
					push = Level01Traps.punch_push(puncher) * settings.punch_push
		var run_index := Level01Layout.run_at(feet, 1.5)
		if push == Vector3.ZERO and run_index >= 0:
			var run: Dictionary = Level01Layout.RUNS[run_index]
			if Level01Traps.run_hits(run, run_index, now, feet):
				var rolls: bool = run["kind"] == Level01Layout.ROLLER
				push = Level01Traps.run_push(run) * (settings.roller_push if rolls else settings.boulder_push)
				if rolls:
					strength = SOFT_STRENGTH
					stun = SOFT_STUN
		if push == Vector3.ZERO or not _can_strike(id):
			continue
		_hit_racer(player, push, strength, stun)
		if id == _local_id:
			_hud.flash(Palette.CORAL, 0.35, 0.4)


#Story tiles feel the feet on them
func _tick_tiles(delta: float) -> void:
	var feet: Array[Vector3] = []
	for id: int in _players:
		var player := _players[id] as Player
		if player.is_on_floor() and not player.carried:
			feet.append(player.global_position)
	tiles.tick(delta, feet)


#Comment cue: ticks while flashing, swoosh when pushing
func _comment_cue(stage: int) -> void:
	if stage == Level01Hazards.COMMENT_WARNING:
		SynthSound.play(self, SynthSound.tone(660.0, 0.3, -240.0, 0.35), -12.0)
	elif stage == Level01Hazards.COMMENT_PUSHING:
		SynthSound.play(self, SynthSound.tone(220.0, 0.22, 320.0, 0.4), -10.0)


#A fallen racer keeps the bubble of where it landed until it rides
func _note_falls() -> void:
	for id: int in _players:
		var player := _players[id] as Player
		if player.carried or _lifts.has(id):
			continue
		var lift := Level01Layout.deck_catching(_decks, player.global_position)
		if lift.is_empty():
			if player.is_on_floor():
				_fell_onto.erase(id)
		elif not _fell_onto.has(id):
			_fell_onto[id] = lift


#Deck pad: ride back to the bridge start
func _apply_deck_pads() -> void:
	for id: int in _players:
		var player := _players[id] as Player
		if player.is_flying() or player.is_down() or _lifts.has(id):
			continue
		for lift: Dictionary in _deck_lifts:
			if Level01Hazards.lift_hits(lift, player.global_position):
				_lift_back(id, player, lift, _fell_onto.get(id, lift))
				break


#Bubble ride back to the bridge start; nothing hits a rider
func _lift_back(id: int, player: Player, pad: Dictionary, back: Dictionary) -> void:
	_world.squash_lift_pad(pad)
	player.clear_motion()
	player.carried = true
	rules.state_of(id).hit_immunity_left = LIFT_TIME + 0.5
	var bubble := _world.lift_bubble()
	player.add_child(bubble)
	_lifts[id] = {"from": player.global_position, "pad": pad["pad"], "to": back["landing"], "vertex": back["to"], "age": 0.0, "bubble": bubble}
	if id == _local_id:
		_hint_once(&"deck", "Burbuja de regreso: te sube al inicio del puente del que caíste")


#Bubbles rise beside the bridge, glide over and drop their riders
func _apply_lifts(delta: float) -> void:
	for id: int in _lifts.keys():
		var lift: Dictionary = _lifts[id]
		lift["age"] = float(lift["age"]) + delta
		var share := clampf(float(lift["age"]) / LIFT_TIME, 0.0, 1.0)
		var player := _players.get(id) as Player
		if player != null:
			player.global_position = _lift_point(lift, share)
		if share >= 1.0:
			_end_lift(id)


#Bubble point at that share of the ride
func _lift_point(lift: Dictionary, share: float) -> Vector3:
	var from: Vector3 = lift["from"]
	var pad: Vector3 = lift["pad"]
	var to: Vector3 = lift["to"]
	var top := to.y + LIFT_HOVER
	if share < LIFT_RISE_SHARE:
		var rise := smoothstep(0.0, 1.0, share / LIFT_RISE_SHARE)
		var flat := from.lerp(pad, minf(rise * 3.0, 1.0))
		return Vector3(flat.x, lerpf(from.y, top, rise), flat.z)
	var glide := smoothstep(0.0, 1.0, (share - LIFT_RISE_SHARE) / (1.0 - LIFT_RISE_SHARE))
	var start := Vector3(pad.x, top, pad.z)
	var over := Vector3(to.x, top, to.z)
	return start.lerp(over, glide).lerp(over.lerp(to, glide), glide)


func _end_lift(id: int) -> void:
	var lift: Dictionary = _lifts[id]
	_lifts.erase(id)
	_fell_onto.erase(id)
	_world.pop_bubble(lift["bubble"])
	var player := _players.get(id) as Player
	if player == null:
		return
	player.carried = false
	player.clear_motion()
	tiles.restore_at(lift["to"])
	(_locators[id] as PlayerLocator).force_vertex(lift["vertex"])


#Sweeping blocks throw sideways; a jump clears them
func _apply_blocks() -> void:
	for id: int in _players:
		var locator := _locators[id] as PlayerLocator
		if not locator.on_bridge:
			continue
		var pusher := Level01Layout.pusher_of(locator.bridge_a, locator.bridge_b)
		if pusher.is_empty():
			continue
		var player := _players[id] as Player
		if not Level01Hazards.block_hits(pusher, rules.elapsed, player.global_position):
			continue
		if not _can_strike(id):
			continue
		_world.pulse_block(pusher)
		_hit_racer(player, Level01Hazards.block_heading(pusher, rules.elapsed) * settings.spinner_push, SPINNER_STRENGTH, SPINNER_STUN)
		if id == _local_id:
			_hud.flash(Palette.CORAL, 0.35, 0.4)


#Distance to the goal for the standings
func _update_progress() -> void:
	for id: int in _players:
		rules.state_of(id).progress = _progress_of(id)


func _progress_of(id: int) -> float:
	var position := (_players[id] as Player).global_position
	var best := INF
	for vertex in (_locators[id] as PlayerLocator).chase_candidates():
		var away := Vector2(position.x - Level01Layout.POSITIONS[vertex].x, position.z - Level01Layout.POSITIONS[vertex].z).length()
		best = minf(best, _cost_to_goal.get(vertex, INF) + away / Level01Layout.UNIT)
	return best


func _update_standings() -> void:
	var order := rules.standings()
	_hud.set_place(order.find(_local_id) + 1, order.size())


#Goal doors close a while after the first arrival
func _update_window() -> void:
	if rules.window_left > 0.0:
		_hud.show_window("LA META CIERRA EN %d" % ceili(rules.window_left))
	else:
		_hud.hide_window()


func _local_state() -> Level01Rules.PlayerState:
	return rules.state_of(_local_id)


func _on_place_changed(player_id: int) -> void:
	if phase != Phase.RUNNING or not _players.has(player_id):
		return
	var locator := _locators[player_id] as PlayerLocator
	if locator.on_bridge:
		if player_id == _local_id:
			_bridge_hint(locator.bridge_a, locator.bridge_b)
		return
	var vertex := locator.vertex
	if vertex == Level01Layout.GOAL:
		rules.reach_goal(player_id)
	elif Level01Layout.CHECKPOINTS.has(vertex) and _is_further(vertex, player_id) and rules.reach_checkpoint(player_id, vertex):
		ImpactFx.confetti(self, (Level01Layout.POSITIONS[vertex] as Vector3) + Vector3(0.0, 3.2, 0.0), 50, 70.0, 6.0)
		if player_id == _local_id:
			_world.set_checkpoint_active(vertex, true)
			_hud.toast("Checkpoint guardado")
	elif player_id == _local_id:
		_place_hint(vertex)


#Checkpoints never move backward
func _is_further(vertex: StringName, player_id: int) -> bool:
	return _cost_to_goal.get(vertex, INF) < _cost_to_goal.get(rules.state_of(player_id).checkpoint, INF)


#Each obstacle explains itself the first time
func _place_hint(vertex: StringName) -> void:
	if Level01Layout.TILE_PLATES.has(vertex):
		_hint_once(&"tiles", "Las historias se caen al pisarlas: no te detengas")
	elif Level01Layout.SPINNERS.has(vertex):
		_hint_once(&"spinner", "Una barra gira: salta sobre ella cuando llegue")
	elif Level01Layout.run_at(Level01Layout.POSITIONS[vertex]) >= 0:
		var run: Dictionary = Level01Layout.RUNS[Level01Layout.run_at(Level01Layout.POSITIONS[vertex])]
		if run["kind"] == Level01Layout.ROLLER:
			_hint_once(&"roller", "Las ruedas del scroll se saltan")
		else:
			_hint_once(&"boulder", "El carril que brilla trae una bola: cámbiate de carril")


func _bridge_hint(a: StringName, b: StringName) -> void:
	if Level01Layout.kind_of(a, b) == Level01Layout.SLIDE:
		_hint_once(&"slide", "Tobogán: te lleva rápido, pero solo se baja")
	elif not Level01Layout.axes_of(a, b).is_empty():
		_hint_once(&"axes", "Espera entre dos comentarios y pasa cuando el siguiente se aleje")
	elif not Level01Layout.punchers_of(a, b).is_empty():
		_hint_once(&"punch", "La caja que tiembla va a lanzar un like: pasa después")


func _hint_once(key: StringName, text: String) -> void:
	if _hints_shown.has(key):
		return
	_hints_shown[key] = true
	_hud.toast(text)


func _on_player_fell(player_id: int, attempts_left: int) -> void:
	if player_id == _local_id:
		_hud.set_attempts(attempts_left, settings.attempts)
		iris.open()
	if attempts_left <= 0:
		if player_id != _local_id:
			_retire(player_id)
		return
	var vertex := rules.state_of(player_id).checkpoint
	var player := _players[player_id] as Player
	player.global_position = _spawn_position(vertex) + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
	player.clear_motion()
	(player.get_node("CameraRig") as PlayerCamera).rotation.y = 0.0
	(player.get_node("ModelPivot") as Node3D).rotation.y = PI
	(_locators[player_id] as PlayerLocator).force_vertex(vertex)
	if player_id == _local_id:
		_hud.toast("Caída · quedan %d" % attempts_left)
		_hud.flash(Palette.CORAL, 0.4, 0.5)


#Out of attempts: leaves the course
func _retire(player_id: int) -> void:
	_hud.toast("%s se quedó sin intentos" % _names.get(player_id, "Un jugador"))
	var player := _players[player_id] as Player
	_players.erase(player_id)
	_locators[player_id].queue_free()
	_locators.erase(player_id)
	player.queue_free()


#Opening film: over the goal, then a sweep back to the start
func _film_shots() -> Array[RoundFilm.Shot]:
	var goal: Vector3 = Level01Layout.POSITIONS[Level01Layout.GOAL]
	var start: Vector3 = Level01Layout.POSITIONS[Level01Layout.START]
	var middle := (goal + start) / 2.0
	var shots: Array[RoundFilm.Shot] = []
	shots.append(RoundFilm.Shot.new(goal + Vector3(-34.0, 46.0, -40.0), goal + Vector3(0.0, 4.0, 10.0), goal + Vector3(30.0, 40.0, -22.0), goal + Vector3(0.0, 6.0, 30.0), 3.8))
	shots.append(RoundFilm.Shot.new(middle + Vector3(-58.0, 40.0, -40.0), middle + Vector3(0.0, 0.0, -10.0), middle + Vector3(-46.0, 34.0, 50.0), middle + Vector3(0.0, 4.0, 60.0), 3.6))
	shots.append(RoundFilm.Shot.new(start + Vector3(0.0, 26.0, 34.0), start, start + Vector3(0.0, 10.0, 16.0), start + Vector3(0.0, 1.0, 0.0), 2.6))
	return shots


#Poses allowed at the start, along the way and at the goal
func _pose_allowed(_player_id: int) -> bool:
	return not paused and phase != Phase.ENDED


func _pose_shown() -> bool:
	return not paused and phase != Phase.ENDED


func _on_racer_finished(player_id: int, place: int) -> void:
	_cheering[player_id] = Level01Layout.POSITIONS[Level01Layout.GOAL] + Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5))
	var total := rules.racers_in_race()
	(_players[player_id] as Player).victory_hop()
	_world.celebrate_finish()
	if player_id == _local_id:
		var player := _players[player_id] as Player
		player.set_input_enabled(false)
		_hud.warn("META" if total == 1 else _ordinal(place))
		#In a room this computer watches the others until the race ends
		start_spectating.call_deferred()
	else:
		_hud.toast("%s llegó %s" % [_names.get(player_id, "Alguien"), _ordinal(place)])
	_update_standings()


#Hits only land outside the protection, so swinging comments cannot chain hits
func _can_strike(id: int) -> bool:
	return (_players[id] as Player).can_be_hit() and _on_course(id) and rules.register_hit(id)


#Feet on the course floor, not on a deck below
func _on_course(id: int) -> bool:
	var locator := _locators[id] as PlayerLocator
	var feet := (_players[id] as Player).global_position
	var surface: float = (Level01Layout.POSITIONS[locator.vertex] as Vector3).y
	if locator.on_bridge:
		var a: Vector3 = Level01Layout.POSITIONS[locator.bridge_a]
		var b: Vector3 = Level01Layout.POSITIONS[locator.bridge_b]
		var way := Vector2(b.x - a.x, b.z - a.z)
		var share := clampf(Vector2(feet.x - a.x, feet.z - a.z).dot(way) / maxf(way.length_squared(), 0.01), 0.0, 1.0)
		surface = lerpf(a.y, b.y, share)
	return feet.y > surface - COURSE_DEPTH


func _on_player_left(player_id: int) -> void:
	rules.withdraw(player_id)


#Every level blow is the street hit: throw, flip, lie and get up
func _hit_racer(player: Player, push: Vector3, strength: float, stun: float) -> void:
	var hit := Player.Hit.new()
	hit.push = push
	hit.stun = stun
	hit.flips = true
	hit.strength = strength
	player.take_hit(hit)


func _on_racer_hit(hit: Player.Hit, player: Player) -> void:
	ImpactFx.blow(self, player, hit, _rng, player.player_id == _local_id)


#Landings of this screen's racer and hard ones of the rest
func _on_racer_landed(_at: Vector3, hard: bool, player: Player) -> void:
	if hard or player.player_id == _local_id:
		ImpactFx.landing(self, player, hard, _rng)


func _on_window_opened(_seconds: float) -> void:
	if _local_state().is_racing():
		_hud.warn("La meta cierra")


#The bridge about to fall flashes
func _on_feed_warned(a: StringName, b: StringName, seconds: float) -> void:
	_world.flash_bridge(a, b, true)
	_hint_once(&"saturated", "Ruta saturada: se cierra en %d s" % int(seconds))


func _on_feed_closed(a: StringName, b: StringName) -> void:
	graph.set_edge_enabled(a, b, false)
	_world.flash_bridge(a, b, false)
	_world.set_bridge_open(a, b, false)
	_world.cheer(1.8)
	_hint_once(&"feed", "Ruta cerrada: hay otro camino")


func _on_feed_reopened(a: StringName, b: StringName) -> void:
	graph.set_edge_enabled(a, b, true)
	_world.set_bridge_open(a, b, true)


#Server tells feed changes to the others
func _tell_feed(feed: Level01Events, which: int) -> void:
	feed.warned.connect(func(a: StringName, b: StringName, seconds: float) -> void: _send_feed(which, "warn", a, b, seconds))
	feed.closed.connect(func(a: StringName, b: StringName) -> void: _send_feed(which, "close", a, b, 0.0))
	feed.reopened.connect(func(a: StringName, b: StringName) -> void: _send_feed(which, "open", a, b, 0.0))


func _send_feed(which: int, change: String, a: StringName, b: StringName, seconds: float) -> void:
	GameSession.net.send_round_event({"k": "feed", "w": which, "e": change, "a": String(a), "b": String(b), "s": snappedf(seconds, 0.01)})


#A local racer stepped on a story tile: tell the server, which tells all
func _on_tile_stepped(plate: StringName, index: int) -> void:
	GameSession.net.send_round_event({"k": "tile", "p": String(plate), "i": index})


#Remote tile step: drops here with its own clock; the server relays
func _take_tile(from: int, message: Dictionary) -> void:
	var plate := StringName(str(message.get("p", "")))
	var index := int(message.get("i", -1))
	if not Level01Layout.TILE_PLATES.has(plate):
		return
	tiles.shake(plate, index)
	if GameSession.net.is_host() and from != 0:
		GameSession.net.send_round_event({"k": "tile", "p": String(plate), "i": index})


#Server feed changes and tile steps
func _on_round_event(from: int, message: Dictionary) -> void:
	if int(message.get("r", -1)) != GameSession.round_index:
		return
	if str(message.get("k", "")) == "tile":
		_take_tile(from, message)
		return
	if str(message.get("k", "")) != "feed" or from != 0:
		return
	var a := StringName(str(message.get("a", "")))
	var b := StringName(str(message.get("b", "")))
	if not Level01Layout.POSITIONS.has(a) or not Level01Layout.POSITIONS.has(b):
		return
	var feed := extra_events if int(message.get("w", 0)) == 1 and extra_events != null else events
	var seconds: Variant = message.get("s", 0.0)
	feed.apply(str(message.get("e", "")), a, b, float(seconds) if seconds is float or seconds is int else 0.0)


#Distance from a bridge middle to the nearest running racer
func _edge_threat(a: StringName, b: StringName) -> float:
	var middle: Vector3 = (Level01Layout.POSITIONS[a] + Level01Layout.POSITIONS[b]) / 2.0
	var nearest := INF
	for id: int in _players:
		if rules.state_of(id).is_racing():
			nearest = minf(nearest, _flat_distance((_players[id] as Player).global_position, middle))
	return nearest


#A bridge falls only when empty and every racer keeps a way to the goal
func _can_close(a: StringName, b: StringName) -> bool:
	if not graph.is_edge_enabled(a, b) or _feed_holds(a, b):
		return false
	for id: int in _players:
		var on := _locators[id] as PlayerLocator
		if on.on_bridge and ((on.bridge_a == a and on.bridge_b == b) or (on.bridge_a == b and on.bridge_b == a)):
			return false
	var flashing: Array[Array] = []
	for feed in [events, extra_events]:
		if feed != null and feed.phase == Level01Events.Phase.WARNING:
			flashing.append([feed.edge[0], feed.edge[1]])
	for edge in flashing:
		graph.set_edge_enabled(edge[0], edge[1], false)
	graph.set_edge_enabled(a, b, false)
	var fine := true
	for id: int in _players:
		if not rules.state_of(id).is_racing():
			continue
		var reaches := false
		for vertex in (_locators[id] as PlayerLocator).chase_candidates():
			if graph.shortest_path(vertex, Level01Layout.GOAL).found:
				reaches = true
		fine = fine and reaches
	graph.set_edge_enabled(a, b, true)
	for edge in flashing:
		graph.set_edge_enabled(edge[0], edge[1], true)
	return fine


#Whether a feed is flashing or holding this bridge down
func _feed_holds(a: StringName, b: StringName) -> bool:
	for feed in [events, extra_events]:
		if feed != null and not feed.edge.is_empty() and ((feed.edge[0] == a and feed.edge[1] == b) or (feed.edge[0] == b and feed.edge[1] == a)):
			return true
	return false


func _on_outcome(outcome: int) -> void:
	var state := _local_state()
	match outcome:
		Level01Rules.Outcome.WON:
			match state.place:
				0:
					_finish("Meta cerrada", "")
				_:
					_finish("%s" % _ordinal(state.place) if rules.racers_in_race() > 1 else "Meta", "")
		Level01Rules.Outcome.LOST_TIME:
			if rules.window_left == 0.0:
				_finish("Meta cerrada", "")
			else:
				_finish("Sin tiempo", "")
		Level01Rules.Outcome.LOST_ATTEMPTS:
			_finish("Sin intentos", "")


func _finish(title: String, message: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	for id: int in _lifts.keys():
		_end_lift(id)
	var state := _local_state()
	var victory := state.reached_goal()
	_hud.set_time(rules.time_left)
	_hud.hide_window()
	_update_standings()
	_debug.end_demo()
	for id: int in _players:
		var player := _players[id] as Player
		player.set_input_enabled(false)
		player.clear_motion()
		player.external_velocity = Vector3.ZERO
	#A late Esc must not open the pause over the final panel
	_pause_menu.set_process_unhandled_input(false)
	_hud.hide_mission()
	var arrived := 0
	for other: Level01Rules.PlayerState in rules.players.values():
		if other.reached_goal():
			arrived += 1
	var lines: Array[Array] = [
		["Puesto", ("%s de %d" % [_ordinal(state.place), rules.racers_in_race()]) if victory else "sin llegar"],
		["Tiempo", ("%d s" % ceili(state.finish_time)) if victory else "%d s" % ceili(rules.elapsed)],
		["Intentos", "%d de %d" % [state.attempts_left, settings.attempts]],
		["Llegaron", "%d de %d" % [arrived, rules.racers_in_race()]],
	]
	#One line and one fact, then the results
	var banner := title.to_upper()
	if victory:
		banner = "META" if rules.racers_in_race() == 1 else _ordinal(state.place)
	_hud.show_banner(banner, "%d s" % ceili(state.finish_time) if victory else "", Palette.PAPER if victory else Palette.GOLD)
	var result := RoundResult.make(SCREEN_ID, victory, title, message, lines).with_score(_score_of(state), _points_of_everybody())
	get_tree().create_timer(1.8).timeout.connect(_report.bind(result, victory))


#Course share covered, 0 to 1
func _covered(state: Level01Rules.PlayerState) -> float:
	var whole: float = _cost_to_goal.get(Level01Layout.START, 0.0)
	if state.reached_goal():
		return 1.0
	if whole <= 0.0 or state.progress == INF:
		return 0.0
	return clampf(1.0 - state.progress / whole, 0.0, 1.0)


func _points_of(state: Level01Rules.PlayerState) -> int:
	return GameSession.score_sheet.race_points(state.reached_goal(), state.finish_time, state.attempts_left, _covered(state))


func _points_of_everybody() -> Dictionary:
	var points: Dictionary = {}
	for other: Level01Rules.PlayerState in rules.players.values():
		points[other.id] = _points_of(other)
	return points


#Score with its breakdown: arrival, time and attempts kept
func _score_of(state: Level01Rules.PlayerState) -> RoundScore:
	var sheet := GameSession.score_sheet
	var points := _points_of(state)
	if not state.reached_goal():
		return RoundScore.make(sheet, points, "Recorriste el %d %% del camino" % roundi(_covered(state) * 100.0))
	var kept := sheet.race_attempt_points * clampi(state.attempts_left, 0, sheet.race_attempts)
	return RoundScore.make(sheet, points, "Llegaste en %d s" % ceili(state.finish_time), [
		["Llegar", "+%d" % sheet.race_finish], ["Tiempo", "+%d" % (points - sheet.race_finish - kept)], ["Intentos", "+%d" % kept]])


func _report(result: RoundResult, victory: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not finish_round(result):
		_hud.show_end(result.headline, result.detail, victory)


func _retry() -> void:
	if GameSession.is_playing_round():
		GameSession.restart_round()
	else:
		ScreenFlow.reload_current()


func _ordinal(place: int) -> String:
	return "%d.º" % place


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
