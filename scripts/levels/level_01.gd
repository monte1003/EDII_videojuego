class_name Level01
extends RoundScene

#Level 1 "Carrera del feed": one to four racers cross a graph of islands while four bots hunt them; the scene spawns and shows,
#the rules live in Level01Rules, the feed in Level01Events and each bot hunts by its role

enum Phase { COUNTDOWN, RUNNING, ENDED }

const BOT_SCENE := preload("res://scenes/bots/chaser_bot.tscn")
const SCREEN_ID := &"level_01"
const FALL_Y := -12.0
#Meters between the starting places of the racers
const START_SPREAD := 2.2
#How hard a blow feels and how long it leaves the racer lying: a bar hits harder than a bot
const SPINNER_STRENGTH := 0.9
const SPINNER_STUN := 0.6
const BOT_STRENGTH := 0.65
const BOT_STUN := 0.5
#A rolling ball hits a bit softer than a bar: its share of the push of a bar, and how hard it feels
const BALL_PUSH_SHARE := 0.75
const BALL_STRENGTH := 0.75
const BALL_STUN := 0.5
#Seconds before the same trampoline can throw the same racer again
const PAD_REST := 1.2
#How far under its feet a body still sticks to the ground, so it follows a slide down instead of skipping over it
const SLIDE_SNAP := 0.6
#How much of the flow of a slide a racer keeps when it leaves it
const SLIDE_CARRY := 0.8
#A comment pushes this much harder than a bot (a share of the push of the bots)
const COMMENT_PUSH_SHARE := 1.4

#Tuning numbers of the round; leave empty to use the defaults
@export var settings: Level01Settings
#The first ones are used, in this order (see Level01Settings.bot_count_for)
@export var bot_appearances: Array[BotAppearance] = []

var phase := Phase.COUNTDOWN
#The course as the racers can go through it, cannons included; the bots walk the same course without them (they cannot be thrown)
var graph: WeightedGraph
var bot_graph: WeightedGraph
var rules: Level01Rules
var events: Level01Events
#The second feed, when the settings ask for one
var extra_events: Level01Events
var bots: Array[ChaserBot] = []

var _context := ChaseContext.new()
#Every racer by id
var _players: Dictionary = {}
var _locators: Dictionary = {}
var _names: Dictionary = {}
var _local_id := 0
var _rng := RandomNumberGenerator.new()
var _phase_timer := 0.0
var _countdown_shown := 0
var _hud_timer := 0.0
var _standings_timer := 0.0
#Where each racer that arrived walks to, so the gate of the goal stays free for the next one
var _cheering: Dictionary = {}
var _hints_shown: Dictionary = {}
#Bots waiting for their turn, each with the second of the round at which it is released
var _release_schedule: Array[Dictionary] = []
#The graph with every bridge open: the distance to the goal of the standings does not jump when the feed takes one down
var _cost_to_goal: Dictionary = {}
var _debug: Level01Debug
#Whether each belt that turns around flows the way it was built, by its index in Level01Layout.TURNS, and whether it is about to turn
var _belt_forward: Dictionary = {}
var _belt_warned: Dictionary = {}
#When each trampoline may throw again, by racer id and island: a racer does not bounce twice in the same jump
var _pad_ready: Dictionary = {}
#The flow of the slide each racer just left, by id: it keeps sliding a little over the island
var _slide_carry: Dictionary = {}
#The part of its cycle each comment was in the last time, to play its cues once
var _comment_stage: Dictionary = {}
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _world: Level01World = $World
@onready var _level_input: LevelInput = $LevelInput
@onready var _hud: LevelHud = $Hud


func _ready() -> void:
	super()
	if settings == null:
		settings = Level01Settings.new()
	if ScreenFlow.tree.has(SCREEN_ID):
		ScreenFlow.mark_current(SCREEN_ID)
	if settings.random_seed != 0:
		_rng.seed = settings.random_seed
	else:
		_rng.randomize()

	graph = Level01Layout.build_graph()
	bot_graph = Level01Layout.build_graph(true, false)
	_measure_the_course()
	var human_ids: Array[int] = []
	for slot in participants:
		human_ids.append(slot.player_id)
	_local_id = human_ids[0]
	rules = Level01Rules.new(settings, human_ids, Level01Layout.START)
	rules.block_changed.connect(set_bridge_closed)
	rules.outcome_decided.connect(_on_outcome)
	rules.player_fell.connect(_on_player_fell)
	rules.racer_finished.connect(_on_racer_finished)
	rules.window_opened.connect(_on_window_opened)

	_spawn_racers()
	_world.build(_locator_list(), settings.refuge_radius, settings.belt_speed)
	_setup_context()
	_spawn_bots()
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

	_debug = Level01Debug.new()
	add_child(_debug)
	_debug.setup(self, $DebugView, _hud)
	_level_input.debug_toggled.connect(_debug.toggle_view)
	_level_input.demo_toggled.connect(_debug.toggle_demo)
	_level_input.interact_pressed.connect(_on_interact)
	_hud.retry_requested.connect(_retry)
	_hud.menu_requested.connect(GameSession.abandon)

	_hud.set_time(rules.time_left)
	_hud.set_attempts(settings.attempts, settings.attempts)
	_hud.hide_countdown()
	_update_ability_chips()
	_update_standings()
	_help.setup(HelpPages.level_one(settings, bot_appearances))
	_begin_countdown()


func local_locator() -> PlayerLocator:
	return _locators[_local_id]


#A bot of the level, also used by the route demo
func make_bot(appearance: BotAppearance, vertex: StringName) -> ChaserBot:
	var bot := BOT_SCENE.instantiate() as ChaserBot
	_actors.add_child(bot)
	bot.setup(_context, appearance, vertex)
	bot.move_speed = _any_player().move_speed * settings.bot_speed_ratio
	bot.floor_snap_length = SLIDE_SNAP
	bot.recalc_interval = settings.bot_recalc_interval
	bot.push_windup = settings.bot_windup
	bot.push_cooldown = settings.bot_cooldown
	bot.lose_time = settings.bot_lose_time
	bot.push_announced.connect(_on_push_announced)
	bot.push_landed.connect(_on_push_landed)
	return bot


#Closes or opens the bridge Bloquear works on for the bots; it stays walkable for the players
func set_bridge_closed(closed: bool) -> void:
	graph.set_edge_enabled(Level01Layout.BLOCK_EDGE[0], Level01Layout.BLOCK_EDGE[1], not closed)
	bot_graph.set_edge_enabled(Level01Layout.BLOCK_EDGE[0], Level01Layout.BLOCK_EDGE[1], not closed)
	_world.set_block_visual(closed)


func _physics_process(delta: float) -> void:
	if paused:
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


#The cost of the way to the goal from every island, with every bridge open
func _measure_the_course() -> void:
	var open := Level01Layout.build_graph()
	for id: StringName in Level01Layout.POSITIONS:
		var route := open.shortest_path(id, Level01Layout.GOAL)
		_cost_to_goal[id] = route.cost if route.found else INF


func _spawn_racers() -> void:
	var points := _start_slots(participants.size())
	for player in spawn_players(_actors, points):
		player.set_input_enabled(false)
		_register_racer(player, GameState.get_player_name(player.player_id), player.player_id)
		_names[player.player_id] = "TÚ" if player.player_id == _local_id else GameState.get_player_name(player.player_id)


#Free places across the start, the middle ones first
func _start_slots(count: int) -> Array[Vector3]:
	var offsets: Array[float] = []
	for index in count:
		offsets.append(START_SPREAD * (index - (count - 1) / 2.0))
	offsets.sort_custom(func(a: float, b: float) -> bool: return absf(a) < absf(b))
	var slots: Array[Vector3] = []
	for offset in offsets:
		slots.append(_spawn_position(Level01Layout.START) + Vector3(offset, 0.0, 0.0))
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


func _locator_list() -> Array[PlayerLocator]:
	var list: Array[PlayerLocator] = []
	for locator: PlayerLocator in _locators.values():
		list.append(locator)
	return list


func _any_player() -> Player:
	return _players[_local_id]


func _setup_context() -> void:
	_context.graph = bot_graph
	_context.positions = Level01Layout.POSITIONS
	var radii: Dictionary = {}
	for id: StringName in Level01Layout.POSITIONS:
		radii[id] = Level01Layout.radius_of(id)
	_context.radii = radii
	_context.forbidden = Level01Layout.BOT_FORBIDDEN
	_context.goal = Level01Layout.GOAL
	for id: int in _players:
		var target := ChaseTarget.new()
		target.player_id = id
		target.node = _players[id]
		target.locator = _locators[id]
		target.detection_radius = settings.detection_radius
		_context.targets.append(target)


func _spawn_bots() -> void:
	var free: Array[StringName] = Level01Layout.BOT_SPAWNS.duplicate()
	#Fisher-Yates shuffle with the level's own generator, so a seed repeats the round
	for index in range(free.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var swap := free[index]
		free[index] = free[other]
		free[other] = swap
	var count := mini(settings.bot_count_for(participants.size()), bot_appearances.size())
	for index in count:
		var appearance := bot_appearances[index]
		var vertex := BotRoles.make(appearance.role).spawn_vertex(free, _context)
		free.erase(vertex)
		var bot := make_bot(appearance, vertex)
		bots.append(bot)
		_release_schedule.append({"bot": bot, "at": bot.role.release_delay(settings.bot_head_start)})


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
	_hud.show_mission("Llega a la isla %s" % Level01Layout.GOAL, [
		"%s|mover" % move_keys, "%s|saltar" % InputHints.key_label(&"jump"),
		"%s|usar" % InputHints.key_label(&"interact"), "%s|ayuda" % InputHints.key_label(&"help")], 5.0)


func _begin_round() -> void:
	phase = Phase.RUNNING
	for id: int in _players:
		(_players[id] as Player).set_input_enabled(id == _local_id)
	_hud.show_go()
	_world.set_start_lights(3, true)
	_world.cheer(2.4)


#Each bot leaves when its role says, like the ghosts leaving their house one after the other
func _release_due_bots() -> void:
	for index in range(_release_schedule.size() - 1, -1, -1):
		var entry := _release_schedule[index]
		if rules.elapsed < entry["at"]:
			continue
		(entry["bot"] as ChaserBot).activate(local_locator().vertex)
		_release_schedule.remove_at(index)
		_hint_once(&"release", "Los bots te buscan")


func _update_running(delta: float) -> void:
	rules.tick(delta)
	if phase != Phase.RUNNING:
		return
	events.tick(delta, _can_close, _edge_threat)
	if extra_events != null:
		extra_events.tick(delta, _can_close, _edge_threat)
	_release_due_bots()
	for id: int in _players.keys():
		if not _players.has(id):
			continue
		if (_players[id] as Player).global_position.y < FALL_Y:
			rules.fall(id)
			if phase != Phase.RUNNING:
				return
	_walk_finished()
	_apply_turns()
	_apply_belts()
	_apply_hazards()
	_apply_blocks()
	_apply_balls()
	_apply_pads()
	_apply_launches()
	_apply_comments()
	_apply_free_cannons()
	_update_progress()
	_update_context()
	_update_prompt()
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_hud.set_time(rules.time_left)
		_update_ability_chips()
		_update_window()
	_standings_timer += delta
	if _standings_timer >= 0.25:
		_standings_timer = 0.0
		_update_standings()
	var refuge := _local_state().refuge_left
	if refuge > 0.0 and _flat_distance(_any_player().global_position, _world.refuge_center) > settings.refuge_radius:
		rules.leave_refuge(_local_id)


#Whoever arrived walks into the goal island and stops there
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


#A conveyor bridge drags whoever is on it, racers and bots alike, and a slide carries them down much faster
func _apply_belts() -> void:
	for id: int in _players:
		var player := _players[id] as Player
		var locator := _locators[id] as PlayerLocator
		var flow := Vector3.ZERO
		if locator.on_bridge and player.is_on_floor():
			flow = Level01Layout.drift(locator.bridge_a, locator.bridge_b, rules.elapsed, settings.belt_speed)
		player.external_velocity = flow
		_carry_slide(id, player, flow)
	for bot in bots:
		var pair := bot.crossing_pair()
		bot.external_velocity = Level01Layout.drift(pair[0], pair[1], rules.elapsed, settings.belt_speed) if pair.size() == 2 else Vector3.ZERO


#Whoever comes off the end of a slide does not stop dead: the speed it had fades out over the island
func _carry_slide(id: int, player: Player, flow: Vector3) -> void:
	if flow.length() > settings.belt_speed + 0.5:
		_slide_carry[id] = flow
	elif _slide_carry.has(id):
		if player.is_on_floor():
			player.push_velocity = (_slide_carry[id] as Vector3) * SLIDE_CARRY
		_slide_carry.erase(id)


#The bars turn and whoever they touch is thrown; a jump goes over them
func _apply_hazards() -> void:
	_world.update_hazards(rules.elapsed)
	for id: int in _players:
		var locator := _locators[id] as PlayerLocator
		if locator.on_bridge or not Level01Layout.SPINNERS.has(locator.vertex):
			continue
		var player := _players[id] as Player
		var spinner: Dictionary = Level01Layout.SPINNERS[locator.vertex]
		var centre: Vector3 = Level01Layout.POSITIONS[locator.vertex]
		if not Level01Hazards.hits(centre, spinner, rules.elapsed, player.global_position, player.global_position.y - centre.y):
			continue
		if not rules.register_hit(id):
			continue
		var direction := Level01Hazards.push_direction(centre, spinner, player.global_position)
		_hit_racer(player, direction * settings.spinner_push, SPINNER_STRENGTH, SPINNER_STUN)
		if id == _local_id:
			_hud.flash(Palette.CORAL, 0.35, 0.4)


#The belts turn around by the clock: the graph costs change and the arrows blink first
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
				bot_graph.set_weights(edge[0], edge[1], costs.x, costs.y)
		_world.set_belt_direction(edge[0], edge[1], forward)
		_hint_once(&"turn", "Las cintas cambian de sentido")


#A ball that rolls across an island throws whoever it touches; a jump goes over it
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
			if not rules.register_hit(id):
				continue
			var push := Level01Hazards.ball_push(ball, rules.elapsed, player.global_position)
			_hit_racer(player, push * settings.spinner_push * BALL_PUSH_SHARE, BALL_STRENGTH, BALL_STUN)
			if id == _local_id:
				_hud.flash(Palette.CORAL, 0.35, 0.4)


#A trampoline throws up whoever steps on it
func _apply_pads() -> void:
	var now := rules.elapsed
	for id: int in _players:
		var locator := _locators[id] as PlayerLocator
		if locator.on_bridge or not Level01Layout.PADS.has(locator.vertex):
			continue
		var player := _players[id] as Player
		var key := "%d|%s" % [id, locator.vertex]
		if now < _pad_ready.get(key, 0.0) or not Level01Hazards.pad_hits(locator.vertex, player.global_position):
			continue
		_pad_ready[key] = now + PAD_REST
		player.apply_push(Level01Hazards.pad_launch(locator.vertex, player.global_position))
		_world.bounce_pad(locator.vertex)


#A cannon throws whoever steps on its pad along the arc to its island
func _apply_launches() -> void:
	var now := rules.elapsed
	for id: int in _players:
		var locator := _locators[id] as PlayerLocator
		var player := _players[id] as Player
		if locator.flight_to != &"" and not player.is_flying():
			locator.flight_to = &""
		if locator.on_bridge or player.is_flying() or player.is_down():
			continue
		for launch in Level01Layout.launches_from(locator.vertex):
			var key := "%d|%s>%s" % [id, launch["from"], launch["to"]]
			if now < _pad_ready.get(key, 0.0) or not Level01Hazards.launch_hits(launch, player.global_position):
				continue
			_pad_ready[key] = now + PAD_REST
			player.launch(Level01Hazards.launch_velocity(launch, _gravity))
			locator.begin_flight(launch["to"])
			_world.fire_cannon(launch)
			if id == _local_id:
				_hint_once(&"cannon", "Cañón a la isla %s" % launch["to"])


#Each comment bubble sweeps across its bridge after its warning and pushes whoever it reaches; a jump goes over it
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
			if not Level01Hazards.comment_hits(comment, rules.elapsed, player.global_position) or not rules.register_hit(id):
				continue
			_hit_racer(player, Level01Hazards.comment_push(comment, rules.elapsed) * settings.push_speed * COMMENT_PUSH_SHARE, BOT_STRENGTH, BOT_STUN)
			if id == _local_id:
				_hud.flash(Palette.CORAL, 0.3, 0.4)
				_hint_once(&"comment", "Un comentario empuja: salta o cruza por el otro lado")


#The sound of a comment: ticks while it flashes and a swoosh when it pushes
func _comment_cue(stage: int) -> void:
	if stage == Level01Hazards.COMMENT_WARNING:
		SynthSound.play(self, SynthSound.tone(660.0, 0.3, -240.0, 0.35), -12.0)
	elif stage == Level01Hazards.COMMENT_PUSHING:
		SynthSound.play(self, SynthSound.tone(220.0, 0.22, 320.0, 0.4), -10.0)


#Whoever lands on a deck is lifted back to the island at the start of its bridge by the pad of the deck; the cannon of a ledge throws far ahead
func _apply_free_cannons() -> void:
	var now := rules.elapsed
	var cannons: Array[Dictionary] = Level01Layout.deck_returns()
	cannons.append_array(Level01Layout.hop_cannons())
	for id: int in _players:
		var player := _players[id] as Player
		if id == _local_id:
			for hop: Dictionary in Level01Layout.HOPS:
				var ledge := Level01Layout.hop_ledge(hop)
				var near := Vector2(player.global_position.x - ledge.x, player.global_position.z - ledge.z).length()
				if near < float(hop["gap"]) + float(hop["radius"]) + 6.0 and absf(player.global_position.y - ledge.y) < 1.0:
					_hint_once(&"hop", "Hueco largo: salto y barrido para cruzar")
		if player.is_flying() or player.is_down():
			continue
		for launch: Dictionary in cannons:
			var key := "%d|%s>%s" % [id, launch["from"], launch["to"]]
			if now < _pad_ready.get(key, 0.0) or not Level01Hazards.launch_hits(launch, player.global_position):
				continue
			_pad_ready[key] = now + PAD_REST
			if launch.has("deck"):
				_lift_back(id, player, launch)
				continue
			player.launch(Level01Hazards.launch_velocity(launch, _gravity))
			(_locators[id] as PlayerLocator).begin_flight(launch["to"])
			_world.fire_cannon(launch)


#The pad of a deck lifts whoever steps on it back to the middle of the island at the start of its bridge
func _lift_back(id: int, player: Player, launch: Dictionary) -> void:
	var to: StringName = launch["to"]
	_world.fire_cannon(launch)
	player.global_position = _spawn_position(to) + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
	player.clear_motion()
	(_locators[id] as PlayerLocator).force_vertex(to)
	ImpactFx.confetti(self, player.global_position + Vector3(0.0, 0.6, 0.0), 24, 55.0, 4.0)
	if id == _local_id:
		_hint_once(&"deck", "Plataforma de regreso a la isla %s" % to)


#The blocks that sweep some bridges throw whoever they touch off to the side; a jump goes over them
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
		if not rules.register_hit(id):
			continue
		_world.pulse_block(pusher)
		_hit_racer(player, Level01Hazards.block_heading(pusher, rules.elapsed) * settings.spinner_push, SPINNER_STRENGTH, SPINNER_STUN)
		if id == _local_id:
			_hud.flash(Palette.CORAL, 0.35, 0.4)


#How far each racer is from the goal, for the standings and for the bots that wait for the leader
func _update_progress() -> void:
	for id: int in _players:
		var value := _progress_of(id)
		rules.state_of(id).progress = value
		var target := _context.target_of(id)
		if target != null:
			target.progress = value


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


#The doors of the goal close a while after the first racer arrives
func _update_window() -> void:
	if rules.window_left > 0.0:
		_hud.show_window("LA META CIERRA EN %d" % ceili(rules.window_left))
	else:
		_hud.hide_window()


func _update_context() -> void:
	for target in _context.targets:
		target.detection_radius = rules.detection_radius(target.player_id)
		target.protected = rules.is_protected(target.player_id)
	if rules.is_protected(_local_id):
		_hud.show_protection("Protegido")
	else:
		_hud.hide_protection()


func _update_ability_chips() -> void:
	_world.set_station_active(&"block", rules.active_left(_local_id, Level01Rules.Ability.BLOCK) > 0.0)
	_world.set_station_active(&"silence", rules.active_left(_local_id, Level01Rules.Ability.SILENCE) > 0.0)
	_world.set_station_active(&"refuge", rules.active_left(_local_id, Level01Rules.Ability.REFUGE) > 0.0)
	_hud.set_ability(&"block", _ability_text(Level01Rules.Ability.BLOCK), rules.cooldown_left(_local_id, Level01Rules.Ability.BLOCK) <= 0.0)
	_hud.set_ability(&"silence", _ability_text(Level01Rules.Ability.SILENCE), rules.cooldown_left(_local_id, Level01Rules.Ability.SILENCE) <= 0.0)
	_hud.set_ability(&"pause", _ability_text(Level01Rules.Ability.REFUGE), rules.cooldown_left(_local_id, Level01Rules.Ability.REFUGE) <= 0.0)


func _ability_text(ability: int) -> String:
	var active := rules.active_left(_local_id, ability)
	if active > 0.0:
		return "Activo %d s" % ceili(active)
	var cooldown := rules.cooldown_left(_local_id, ability)
	if cooldown > 0.0:
		return "Recarga %d s" % ceili(cooldown)
	return "Listo"


func _local_state() -> Level01Rules.PlayerState:
	return rules.state_of(_local_id)


func _on_interact() -> void:
	if phase == Phase.RUNNING and not paused and _local_state().is_racing():
		_try_interact()


func _near(station: StringName) -> bool:
	return _flat_distance(_any_player().global_position, _world.station_positions[station]) <= settings.station_radius


func _try_interact() -> void:
	if _near(&"block"):
		_use(Level01Rules.Ability.BLOCK, "Bloquear", "Puente bloqueado para los bots")
	elif _near(&"silence"):
		_use(Level01Rules.Ability.SILENCE, "Silenciar", "Los bots te ven menos")
	elif _near(&"refuge"):
		_use(Level01Rules.Ability.REFUGE, "Pausa digital", "Nadie te empuja")


func _use(ability: int, shown_name: String, done: String) -> void:
	if rules.use_ability(_local_id, ability) == Level01Rules.Use.COOLDOWN:
		_hud.toast("%s: recarga %d s" % [shown_name, ceili(rules.cooldown_left(_local_id, ability))])
	else:
		_hud.toast(done)


func _update_prompt() -> void:
	var action := ""
	if not _local_state().is_racing():
		_hud.hide_prompt()
		return
	if _near(&"block"):
		action = "BLOQUEAR"
	elif _near(&"silence"):
		action = "SILENCIAR"
	elif _near(&"refuge"):
		action = "PAUSA DIGITAL"
	if action == "":
		_hud.hide_prompt()
	else:
		_hud.show_prompt(InputHints.key_label(&"interact"), action)


func _on_place_changed(player_id: int) -> void:
	if phase != Phase.RUNNING or not _players.has(player_id):
		return
	var locator := _locators[player_id] as PlayerLocator
	if locator.on_bridge:
		if player_id == _local_id and Level01Layout.kind_of(locator.bridge_a, locator.bridge_b) == Level01Layout.SLIDE:
			_hint_once(&"slide", "Tobogán: te lleva rápido, pero solo se baja")
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
		_station_hint(vertex)


#Whether "vertex" is closer to the goal than the checkpoint that racer has saved, so going back never takes a checkpoint away
func _is_further(vertex: StringName, player_id: int) -> bool:
	return _cost_to_goal.get(vertex, INF) < _cost_to_goal.get(rules.state_of(player_id).checkpoint, INF)


#Each station explains itself the first time the player reaches its island
func _station_hint(vertex: StringName) -> void:
	var text := ""
	var stations: Dictionary = Level01Layout.STATIONS
	if vertex == stations[&"block"]:
		text = "%s junto al letrero cierra el puente %s-%s a los bots" % [
			InputHints.key_label(&"interact"), Level01Layout.BLOCK_EDGE[0], Level01Layout.BLOCK_EDGE[1]]
	elif vertex == stations[&"silence"]:
		text = "%s junto a la campana: los bots te ven menos %d s" % [InputHints.key_label(&"interact"), int(settings.silence_duration)]
	elif vertex == stations[&"refuge"]:
		text = "Entra a la burbuja y pulsa %s: nadie te empuja" % InputHints.key_label(&"interact")
	elif not Level01Layout.launches_from(vertex).is_empty():
		text = "Pisa el cañón del borde: te lanza por el aire a otra isla"
	elif Level01Layout.SPINNERS.has(vertex):
		text = "Una barra gira: salta sobre ella o rodéala"
	if text != "":
		_hint_once(vertex, text)


func _hint_once(key: StringName, text: String) -> void:
	if _hints_shown.has(key):
		return
	_hints_shown[key] = true
	_hud.toast(text)


func _on_player_fell(player_id: int, attempts_left: int) -> void:
	if player_id == _local_id:
		_hud.set_attempts(attempts_left, settings.attempts)
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


#A racer out of attempts leaves the course
func _retire(player_id: int) -> void:
	_hud.toast("%s se quedó sin intentos" % _names.get(player_id, "Un jugador"))
	var target := _context.target_of(player_id)
	if target != null:
		_context.targets.erase(target)
	var player := _players[player_id] as Player
	_players.erase(player_id)
	_locators[player_id].queue_free()
	_locators.erase(player_id)
	player.queue_free()


func _on_racer_finished(player_id: int, place: int) -> void:
	_cheering[player_id] = Level01Layout.POSITIONS[Level01Layout.GOAL] + Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5))
	var total := rules.racers_in_race()
	(_players[player_id] as Player).victory_hop()
	_world.celebrate_finish()
	if player_id == _local_id:
		var player := _players[player_id] as Player
		player.set_input_enabled(false)
		_hud.warn("META" if total == 1 else _ordinal(place))
	else:
		_hud.toast("%s llegó %s" % [_names.get(player_id, "Alguien"), _ordinal(place)])
	_update_standings()


#Every blow of the level is the same hit as in the street: it throws the racer, flips it, leaves it lying and gets it up
func _hit_racer(player: Player, push: Vector3, strength: float, stun: float) -> void:
	var hit := Player.Hit.new()
	hit.push = push
	hit.stun = stun
	hit.flips = true
	hit.strength = strength
	player.take_hit(hit)


func _on_racer_hit(hit: Player.Hit, player: Player) -> void:
	ImpactFx.blow(self, player, hit, _rng, player.player_id == _local_id)


#Every landing of the racer of this screen and the hard ones of the rest
func _on_racer_landed(_at: Vector3, hard: bool, player: Player) -> void:
	if hard or player.player_id == _local_id:
		ImpactFx.landing(self, player, hard, _rng)


func _on_window_opened(_seconds: float) -> void:
	if _local_state().is_racing():
		_hud.warn("La meta cierra")


#The feed announces the bridge that is about to fall: it flashes
func _on_feed_warned(a: StringName, b: StringName, seconds: float) -> void:
	_world.flash_bridge(a, b, true)
	_hint_once(&"saturated", "Ruta saturada: se cierra en %d s" % int(seconds))


func _on_feed_closed(a: StringName, b: StringName) -> void:
	graph.set_edge_enabled(a, b, false)
	bot_graph.set_edge_enabled(a, b, false)
	_world.flash_bridge(a, b, false)
	_world.set_bridge_open(a, b, false)
	_world.cheer(1.8)
	_hint_once(&"feed", "Ruta cerrada: hay otro camino")


func _on_feed_reopened(a: StringName, b: StringName) -> void:
	graph.set_edge_enabled(a, b, true)
	bot_graph.set_edge_enabled(a, b, true)
	_world.set_bridge_open(a, b, true)


#Meters from the middle of a bridge to the nearest racer still running
func _edge_threat(a: StringName, b: StringName) -> float:
	var middle: Vector3 = (Level01Layout.POSITIONS[a] + Level01Layout.POSITIONS[b]) / 2.0
	var nearest := INF
	for id: int in _players:
		if rules.state_of(id).is_racing():
			nearest = minf(nearest, _flat_distance((_players[id] as Player).global_position, middle))
	return nearest


#A bridge may fall only if nobody is on it when it is chosen (whoever steps on it afterwards saw its sign) and every racer that is still
#running keeps a way to the goal, counting the bridges the feed is about to drop as down too
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


#Whether one of the feeds is already flashing or holding down the bridge between a and b
func _feed_holds(a: StringName, b: StringName) -> bool:
	for feed in [events, extra_events]:
		if feed != null and not feed.edge.is_empty() and ((feed.edge[0] == a and feed.edge[1] == b) or (feed.edge[0] == b and feed.edge[1] == a)):
			return true
	return false


func _on_push_announced(bot: ChaserBot) -> void:
	_hud.flash(Palette.GOLD, 0.3, 0.35)
	SynthSound.play(self, SynthSound.tone(330.0, 0.3, 360.0, 0.35), -12.0)
	if bot.appearance.tip != "":
		_hint_once(bot.appearance.id, bot.appearance.tip)


func _on_push_landed(_bot: ChaserBot, direction: Vector3, player_id: int) -> void:
	if not _players.has(player_id) or not rules.register_hit(player_id):
		return
	_hit_racer(_players[player_id] as Player, direction * settings.push_speed, BOT_STRENGTH, BOT_STUN)
	if player_id == _local_id:
		_hud.flash(Palette.CORAL, 0.35, 0.4)


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
	for bot in bots:
		bot.deactivate()
	#A late Esc press must not open the pause menu over the final panel
	_pause_menu.set_process_unhandled_input(false)
	_hud.hide_prompt()
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
	#One line and one fact on the screen for a moment, then the results
	var banner := title.to_upper()
	if victory:
		banner = "META" if rules.racers_in_race() == 1 else _ordinal(state.place)
	_hud.show_banner(banner, "%d s" % ceili(state.finish_time) if victory else "", Palette.PAPER if victory else Palette.GOLD)
	var result := RoundResult.make(SCREEN_ID, victory, title, message, lines).with_score(_score_of(state), _points_of_everybody())
	get_tree().create_timer(1.8).timeout.connect(_report.bind(result, victory))


#Share of the course a racer covered, from 0 at the start to 1 at the goal
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


#The score of a racer with how it adds up: arriving, the time and the attempts kept
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
