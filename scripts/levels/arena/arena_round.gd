class_name ArenaRound
extends RoundScene

#What the two arena rounds share: the players on the map, the countdown, the shoves, the blows of what moves, the trampolines,
#cannons and belts, the bots that get in the way and how the round ends. Each round adds its own rules on top

enum Phase { COUNTDOWN, RUNNING, ENDED }

const BOT_SCENE := preload("res://scenes/bots/chaser_bot.tscn")
#The map is solid, so nobody falls out of it; this is only a net far under the ground for whatever goes wrong
const SAFETY_DEPTH := 6.0
const RESPAWN_TIME := 1.2
const SHOVE_PUSH := 9.0
const SHOVE_STUN := 0.35
#A shoved bot is thrown this fast and cannot walk or push for this long
const BOT_SHOVE_PUSH := 8.0
const BOT_SHOVE_STUN := 1.1
const HAZARD_PUSH := 11.0
const HAZARD_STUN := 0.5
#Seconds a piece that just appeared takes before it can hit, so it is seen first
const STAGE_GRACE := 1.0
#Seconds a pad ignores the player it just threw
const PAD_REST := 0.5
const CAMERA_DISTANCE := 4.2
const CAMERA_PITCH := -24.0
const SHOVE_COLOR := Color("fff1b8")
#What shove_target says when a shove would reach nobody, and where the bots start in its answers: bot 0 is BOT_KEY, bot 1 is BOT_KEY - 1...
const NOBODY := -1
const BOT_KEY := -10

@export var bot_looks: Array[BotAppearance] = []
@export var countdown_seconds := 3.0
#Off, nothing on the map hits and no bot comes out: to learn the map or to time it
@export var hazards_enabled := true
@export var bots_enabled := true
#Speed of the bots as a share of a player's
@export var bot_speed_ratio := 0.64
#A bot warns for this long before it pushes, rests this long between pushes and stands still this long after one lands
@export var bot_windup := 0.8
@export var bot_cooldown := 3.6
@export var bot_gloat := 2.2

var layout: ArenaLayout
var phase := Phase.COUNTDOWN
#Seconds since "YA"
var clock := 0.0
var stage := 0
var brawl := ArenaBrawl.new()
#Player id -> Player, and its locator
var players: Dictionary = {}
var locators: Dictionary = {}
var bots: Array[ChaserBot] = []
var local_id := 0
var context := ChaseContext.new()
var rng := RandomNumberGenerator.new()
#The places the bots may walk; empty lets them go everywhere
var bot_places: Array[StringName] = []

var _falling: Dictionary = {}
var _pad_rest: Dictionary = {}
var _stage_since := 0.0
var _phase_timer := 0.0
var _stage_set: ArenaStage
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var world: ArenaWorld = $World
@onready var hud: RoundHud = $Hud
@onready var keys: LevelInput = $LevelInput


#Builds the map and its set, puts the players on it and starts the countdown
func setup_arena(arena: ArenaLayout) -> void:
	layout = arena
	rng.randomize()
	world.build(layout)
	_stage_set = ArenaStage.new()
	world.add_child(_stage_set)
	_stage_set.build(layout.reach(), 47, layout.top_height())
	context.graph = layout.build_graph(true)
	for id: StringName in layout.places:
		context.positions[id] = layout.position_of(id)
		context.radii[id] = layout.radius_of(id)
		if not bot_places.is_empty() and not bot_places.has(id):
			context.forbidden.append(id)
	_spawn_players()
	keys.shove_pressed.connect(_on_shove_key)
	hud.retry_requested.connect(_retry)
	hud.menu_requested.connect(GameSession.abandon)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_phase_timer = countdown_seconds
	hud.tick_countdown(_phase_timer)


func local_player() -> Player:
	return players[local_id]


func _any_player() -> Player:
	return local_player()


func cheer(power: float) -> void:
	_stage_set.cheer(power)


func set_stage(value: int) -> void:
	stage = value
	_stage_since = clock
	world.set_stage(value)


#Who a shove of this player would reach right now: a player id, a bot (BOT_KEY minus its index) or NOBODY
func shove_target(player_id: int) -> int:
	var player: Player = players[player_id]
	var others: Dictionary = {}
	for id: int in players:
		if id != player_id and not _falling.has(id):
			others[id] = (players[id] as Player).global_position
	for index in bots.size():
		others[BOT_KEY - index] = bots[index].global_position
	return brawl.pick_victim(player.global_position, player.look_direction(), others)


#Where the head of whoever a shove would reach is, for the mark over it
func shove_target_position(target: int) -> Vector3:
	if target >= 0:
		return (players[target] as Player).global_position + Vector3(0.0, 1.5, 0.0)
	return bots[BOT_KEY - target].global_position + Vector3(0.0, 1.7, 0.0)


#A player asks to shove whoever is in front of it; true when the shove went out (it may still hit nobody)
func request_shove(player_id: int) -> bool:
	if phase != Phase.RUNNING or not players.has(player_id) or _falling.has(player_id):
		return false
	var player: Player = players[player_id]
	if player.is_down() or player.is_diving() or not _can_shove(player_id) or not brawl.use_shove(player_id):
		return false
	var facing := player.look_direction()
	var target := shove_target(player_id)
	player.squash(4.0)
	player.apply_push(facing * 2.5)
	player.play_shove()
	SynthSound.play(self, SynthSound.tone(300.0, 0.14, -160.0, 0.5), -9.0, rng.randf_range(0.95, 1.1))
	var landed := false
	if target >= 0:
		var away := (players[target] as Player).global_position - player.global_position
		away.y = 0.0
		landed = strike(target, away.normalized() * SHOVE_PUSH * _shove_scale(target), 0.35)
	elif target <= BOT_KEY:
		var bot := bots[BOT_KEY - target]
		var away := bot.global_position - player.global_position
		away.y = 0.0
		bot.take_shove(away.normalized() * BOT_SHOVE_PUSH, BOT_SHOVE_STUN)
		landed = true
	_shove_effects(player, facing, target, landed)
	_on_shove_thrown(player_id, landed)
	return true


#A blow from another player or from a bot: the shield takes it, the grace ignores it, and otherwise it pushes and the round decides what it costs
func strike(player_id: int, push: Vector3, strength: float) -> bool:
	var player: Player = players[player_id]
	if _falling.has(player_id) or not player.can_be_hit():
		return false
	match brawl.strike(player_id):
		ArenaBrawl.Outcome.IGNORED:
			return false
		ArenaBrawl.Outcome.BLOCKED:
			_on_shield_broken(player_id)
			return false
	_on_struck(player_id, true, push)
	_hit(player, push, strength, SHOVE_STUN, false)
	return true


#One more bot on the map, as far from the players as it can start
func add_bot() -> void:
	if bot_looks.is_empty() or not bots_enabled:
		return
	var bot := BOT_SCENE.instantiate() as ChaserBot
	_actors.add_child(bot)
	bot.setup(context, bot_looks[bots.size() % bot_looks.size()], _far_place())
	bot.move_speed = local_player().move_speed * bot_speed_ratio
	bot.push_windup = bot_windup
	bot.push_cooldown = bot_cooldown
	bot.push_landed.connect(_on_bot_push)
	bot.push_announced.connect(_on_bot_warning)
	bots.append(bot)
	_on_bot_added(bot)
	var nearest := _nearest_locator(bot.global_position)
	bot.activate(nearest.vertex if nearest != null else layout.spawn_place)


func _physics_process(delta: float) -> void:
	world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if paused:
		return
	match phase:
		Phase.COUNTDOWN:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin()
			else:
				hud.tick_countdown(_phase_timer)
		Phase.RUNNING:
			clock += delta
			brawl.tick(delta)
			world.update(clock)
			_apply_hazards(delta)
			_check_falls(delta)
			_tick_round(delta)


func _help_allowed() -> bool:
	return phase != Phase.ENDED


func _begin() -> void:
	phase = Phase.RUNNING
	hud.show_go()
	local_player().set_input_enabled(true)
	cheer(2.2)
	_on_round_started()


#Each round fills these in
func _on_round_started() -> void:
	pass


func _tick_round(_delta: float) -> void:
	pass


#What a blow costs in this round (an item, a pose); "by_rival" tells a shove or a bot from a bar or a block
func _on_struck(_player_id: int, _by_rival: bool, _push: Vector3) -> void:
	pass


func _on_respawned(_player_id: int) -> void:
	pass


func _on_bot_added(_bot: ChaserBot) -> void:
	pass


func _can_shove(_player_id: int) -> bool:
	return true


#How much harder a shove pushes this victim
func _shove_scale(_victim_id: int) -> float:
	return 1.0


#A shove went out; "landed" tells whether it reached somebody
func _on_shove_thrown(_player_id: int, _landed: bool) -> void:
	pass


#What a shove looks like: a ring of air in front of whoever gives it and, when it lands, a wave on the floor under whoever takes it
func _shove_effects(player: Player, facing: Vector3, target: int, landed: bool) -> void:
	var chest := player.global_position + Vector3(0.0, 0.6, 0.0)
	ImpactFx.ring(self, chest + facing * 0.9, facing, SHOVE_COLOR, 0.35, 1.3 if landed else 0.8, 0.24)
	if not landed:
		return
	var feet := shove_target_position(target)
	feet.y = (players[target] as Player).global_position.y if target >= 0 else bots[BOT_KEY - target].global_position.y
	ImpactFx.ring(self, feet + Vector3(0.0, 0.08, 0.0), Vector3.UP, Palette.PAPER, 0.5, 2.6, 0.4)
	ImpactFx.dust(self, feet + Vector3(0.0, 0.1, 0.0), ImpactFx.DUST_COLOR, 8)
	SynthSound.play(self, SynthSound.thump(0.2), -6.0, rng.randf_range(1.05, 1.2))
	player.shake_camera(0.16)


func _on_shield_broken(player_id: int) -> void:
	var player: Player = players[player_id]
	ImpactFx.stars(self, player.global_position + Vector3(0.0, 0.9, 0.0), 6)
	ImpactFx.ring(self, player.global_position + Vector3(0.0, 0.6, 0.0), Vector3.UP, Color("35c3f2"), 0.8, 2.4, 0.4)
	SynthSound.play(self, SynthSound.tone(1200.0, 0.25, -500.0, 0.4), -8.0)


func _spawn_players() -> void:
	var centre := layout.position_of(layout.spawn_place)
	var points: Array[Vector3] = []
	for index in participants.size():
		#On a ring around the middle, which may hold a podium
		var angle := PI / 2.0 + TAU * index / maxf(participants.size(), 1.0)
		var away := layout.radius_of(layout.spawn_place) * 0.62
		points.append(centre + Vector3(cos(angle) * away, 0.05, sin(angle) * away))
	var spawned := spawn_players(_actors, points)
	local_id = spawned[0].player_id
	for player in spawned:
		players[player.player_id] = player
		player.set_input_enabled(false)
		player.dive_enabled = true
		player.frame_camera(CAMERA_DISTANCE, CAMERA_PITCH)
		player.hit_taken.connect(_on_player_hit.bind(player))
		player.landed.connect(_on_player_landed.bind(player))
		brawl.add(player.player_id)
		_pad_rest[player.player_id] = 0.0
		var locator := PlayerLocator.new()
		locator.player_id = player.player_id
		add_child(locator)
		world.watch(locator)
		locator.force_vertex(layout.spawn_place)
		locators[player.player_id] = locator
		var target := ChaseTarget.new()
		target.player_id = player.player_id
		target.node = player
		target.locator = locator
		target.detection_radius = 200.0
		context.targets.append(target)
	spawned[0].view_camera().make_current()


#The belts, the pads, the bars and the blocks act on every player; a piece that just appeared waits a moment first
func _apply_hazards(delta: float) -> void:
	var live := clock - _stage_since >= STAGE_GRACE
	for id: int in players:
		var player: Player = players[id]
		var at := player.global_position
		var drift := Vector3.ZERO
		_pad_rest[id] = maxf(float(_pad_rest[id]) - delta, 0.0)
		if _falling.has(id):
			player.external_velocity = drift
			continue
		if player.is_on_floor():
			for belt in layout.belts:
				if ArenaHazards.on_belt(belt, at):
					drift = ArenaHazards.belt_drift(layout, belt, stage, clock)
		player.external_velocity = drift
		for index in layout.pads.size():
			var pad := layout.pads[index]
			if float(_pad_rest[id]) > 0.0 or not ArenaLayout.is_on(pad, stage) or not ArenaHazards.pad_live(pad, clock):
				continue
			if player.velocity.y <= 0.5 and not player.is_flying() and ArenaHazards.pad_hits(pad, at):
				_throw(player, index)
		if not hazards_enabled or not player.can_be_hit():
			continue
		for spinner in layout.spinners:
			if _hazard_on(spinner, live) and ArenaHazards.spinner_hits(spinner, clock, at):
				_hazard_hit(id, Level01Hazards.push_direction(spinner["at"], spinner, at))
		for sweeper in layout.sweepers:
			if _hazard_on(sweeper, live) and ArenaHazards.block_hits(sweeper, clock, at):
				_hazard_hit(id, (ArenaHazards.block_heading(sweeper, clock) + Vector3(0.0, 0.0, 0.001)).normalized())


#A trampoline throws straight up and a cannon along its arc
func _throw(player: Player, index: int) -> void:
	var pad := layout.pads[index]
	_pad_rest[player.player_id] = PAD_REST
	if ArenaHazards.is_cannon(pad):
		player.launch(ArenaHazards.pad_launch(pad, _gravity))
		SynthSound.play(self, SynthSound.tone(150.0, 0.4, 480.0, 0.6), -5.0, rng.randf_range(0.95, 1.05))
	else:
		player.apply_push(ArenaHazards.pad_launch(pad, _gravity))
		SynthSound.play(self, SynthSound.tone(240.0, 0.3, 520.0, 0.5), -8.0, rng.randf_range(0.95, 1.08))
	world.bounce_pad(index)


func _hazard_on(entry: Dictionary, live: bool) -> bool:
	var from := int(entry.get("from", 0))
	return stage > from or (stage == from and (live or from == 0))


#A bar or a block hits: a shield takes it, otherwise the player flies
func _hazard_hit(player_id: int, direction: Vector3) -> void:
	var player: Player = players[player_id]
	if brawl.has_shield(player_id):
		brawl.give_shield(player_id, 0.0)
		_on_shield_broken(player_id)
		player.apply_push(direction * 4.0)
		return
	_on_struck(player_id, false, direction * HAZARD_PUSH)
	_hit(player, direction * HAZARD_PUSH, 0.7, HAZARD_STUN, true)


func _hit(player: Player, push: Vector3, strength: float, stun: float, flips: bool) -> void:
	var hit := Player.Hit.new()
	hit.push = push
	hit.strength = strength
	hit.stun = stun
	hit.flips = flips
	player.take_hit(hit)


#Nobody should ever get under the ground; whoever does waits a moment and comes back on the closest place, keeping what it had
func _check_falls(delta: float) -> void:
	for id: int in players:
		var player: Player = players[id]
		if _falling.has(id):
			_falling[id] = float(_falling[id]) - delta
			if float(_falling[id]) <= 0.0:
				_falling.erase(id)
				_respawn(id)
			continue
		if player.global_position.y < ArenaLayout.GROUND - SAFETY_DEPTH:
			_falling[id] = RESPAWN_TIME


func is_falling(player_id: int) -> bool:
	return _falling.has(player_id)


func _respawn(player_id: int) -> void:
	var player: Player = players[player_id]
	var place := layout.nearest_place(Vector3(player.global_position.x, ArenaLayout.GROUND, player.global_position.z))
	player.global_position = layout.position_of(place) + Vector3(0.0, 0.1, 0.0)
	player.clear_motion()
	player.set_input_enabled(player_id == local_id and phase == Phase.RUNNING)
	(locators[player_id] as PlayerLocator).force_vertex(place)
	ImpactFx.dust(self, player.global_position, ImpactFx.DUST_COLOR, 10)
	_on_respawned(player_id)


func _on_shove_key() -> void:
	request_shove(local_id)


#The bot shows its warning mark; a short rising note says it too
func _on_bot_warning(bot: ChaserBot) -> void:
	if bot.global_position.distance_to(local_player().global_position) < 6.0:
		SynthSound.play(self, SynthSound.tone(300.0, 0.35, 380.0, 0.35), -12.0)


#A push that lands: the bot stays where it is for a moment, pleased with itself, so its victim can get away
func _on_bot_push(bot: ChaserBot, direction: Vector3, player_id: int) -> void:
	if phase != Phase.RUNNING or not players.has(player_id):
		return
	if strike(player_id, direction * SHOVE_PUSH, 0.45):
		bot.hold_movement = true
		get_tree().create_timer(bot_gloat).timeout.connect(_release_bot.bind(bot))


func _release_bot(bot: ChaserBot) -> void:
	if is_instance_valid(bot):
		bot.hold_movement = false


func _on_player_hit(hit: Player.Hit, player: Player) -> void:
	ImpactFx.blow(self, player, hit, rng, player.player_id == local_id)
	if player.player_id == local_id:
		hud.flash(Palette.CORAL, 0.3 + 0.3 * hit.strength, 0.45)


func _on_player_landed(_at: Vector3, hard: bool, player: Player) -> void:
	if hard or player.player_id == local_id:
		ImpactFx.landing(self, player, hard, rng)


#The place the bots may use that is farthest from every player and from the other bots
func _far_place() -> StringName:
	var best := layout.spawn_place
	var best_distance := -1.0
	for id: StringName in layout.places:
		if context.forbidden.has(id):
			continue
		var nearest := INF
		for player: Player in players.values():
			nearest = minf(nearest, player.global_position.distance_to(layout.position_of(id)))
		for bot in bots:
			nearest = minf(nearest, bot.global_position.distance_to(layout.position_of(id)) * 2.0)
		if nearest > best_distance:
			best_distance = nearest
			best = id
	return best


func _nearest_locator(point: Vector3) -> PlayerLocator:
	var best: PlayerLocator = null
	var best_distance := INF
	for id: int in players:
		var distance := (players[id] as Player).global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = locators[id]
	return best


#A word or a number that pops over a head, rises and fades
func pop_text(at: Vector3, text: String, color: Color, size := 96, rise := 1.2) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UiKit.HEADING_FONT
	label.font_size = size
	label.pixel_size = 0.008
	label.outline_size = 26
	label.modulate = color
	label.outline_modulate = Palette.EDGE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.global_position = at
	label.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.55)
	tween.tween_property(label, "global_position", at + Vector3(0.0, rise, 0.0), 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


#The round is over: nobody moves, the banner shows for a moment and then the results take over
func end_round(result: RoundResult, banner: String, fact: String, celebrate: bool) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	for player: Player in players.values():
		player.set_input_enabled(false)
		player.posing = false
		player.external_velocity = Vector3.ZERO
	for bot in bots:
		bot.deactivate()
	_pause_menu.set_process_unhandled_input(false)
	hud.hide_mission()
	hud.set_danger(0.0)
	hud.show_banner(banner, fact, Palette.PAPER if celebrate else Palette.GOLD)
	if celebrate:
		local_player().victory_hop()
		cheer(3.0)
	get_tree().create_timer(1.8).timeout.connect(_report.bind(result))


func _report(result: RoundResult) -> void:
	if not finish_round(result):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_end(result.headline, result.detail, result.won)


func _retry() -> void:
	if GameSession.is_playing_round():
		GameSession.restart_round()
	else:
		ScreenFlow.reload_current()
