class_name Level01
extends RoundScene

#Level 1 "Escapa del feed": the scene spawns and shows; the rules live in Level01Rules and each bot hunts by its role

enum Phase { COUNTDOWN, RUNNING, ENDED }

const BOT_SCENE := preload("res://scenes/bots/chaser_bot.tscn")
const SCREEN_ID := &"level_01"
const FALL_Y := -12.0
#Meters between the starting points of several players
const START_SPREAD := 1.6

#Tuning numbers of the round; leave empty to use the defaults
@export var settings: Level01Settings
#The first ones are used, in this order (see Level01Settings.bot_count_for)
@export var bot_appearances: Array[BotAppearance] = []

var phase := Phase.COUNTDOWN
var graph: WeightedGraph
var rules: Level01Rules
var bots: Array[ChaserBot] = []

var _context := ChaseContext.new()
var _players: Dictionary = {}
var _locators: Dictionary = {}
var _local_id := 0
var _rng := RandomNumberGenerator.new()
var _phase_timer := 0.0
var _countdown_shown := 0
var _hud_timer := 0.0
var _hints_shown: Dictionary = {}
#Bots waiting for their turn, each with the second of the round at which it is released
var _release_schedule: Array[Dictionary] = []
var _debug: Level01Debug

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
	var ids: Array[int] = []
	for slot in participants:
		ids.append(slot.player_id)
	_local_id = ids[0]
	rules = Level01Rules.new(settings, ids, Level01Layout.START)
	rules.block_changed.connect(set_bridge_closed)
	rules.outcome_decided.connect(_on_outcome)
	rules.player_fell.connect(_on_player_fell)

	_spawn_players()
	_world.build(_locator_list(), settings.refuge_radius)
	_setup_context()
	_spawn_bots()

	_debug = Level01Debug.new()
	add_child(_debug)
	_debug.setup(self, $DebugView, _hud)
	_hud.help_requested.connect(open_help)
	_level_input.debug_toggled.connect(_debug.toggle_view)
	_level_input.demo_toggled.connect(_debug.toggle_demo)
	_level_input.interact_pressed.connect(_on_interact)
	_hud.retry_requested.connect(_retry)
	_hud.menu_requested.connect(GameSession.abandon)

	_hud.set_time(rules.time_left)
	_hud.set_attempts(settings.attempts, settings.attempts)
	_hud.hide_countdown()
	_update_ability_chips()
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
	bot.recalc_interval = settings.bot_recalc_interval
	bot.lose_time = settings.bot_lose_time
	bot.push_announced.connect(_on_push_announced)
	bot.push_landed.connect(_on_push_landed)
	return bot


#Closes or opens the E-H bridge for the bots; the bridge itself stays walkable for the players
func set_bridge_closed(closed: bool) -> void:
	graph.set_edge_enabled(Level01Layout.BLOCK_EDGE[0], Level01Layout.BLOCK_EDGE[1], not closed)
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
				var shown := ceili(_phase_timer)
				if shown != _countdown_shown:
					_countdown_shown = shown
					_hud.show_countdown(str(shown))
		Phase.RUNNING:
			_update_running(delta)


func _help_allowed() -> bool:
	return phase != Phase.ENDED


func _spawn_players() -> void:
	var points: Array[Vector3] = []
	for index in participants.size():
		points.append(_spawn_position(Level01Layout.START) + Vector3(START_SPREAD * (index - (participants.size() - 1) / 2.0), 0, 0))
	for player in spawn_players(_actors, points):
		player.set_input_enabled(false)
		_players[player.player_id] = player
		var locator := PlayerLocator.new()
		locator.player_id = player.player_id
		locator.place_changed.connect(_on_place_changed.bind(player.player_id))
		add_child(locator)
		_locators[player.player_id] = locator
		locator.force_vertex(Level01Layout.START)


func _locator_list() -> Array[PlayerLocator]:
	var list: Array[PlayerLocator] = []
	for locator: PlayerLocator in _locators.values():
		list.append(locator)
	return list


func _any_player() -> Player:
	return _players[_local_id]


func _setup_context() -> void:
	_context.graph = graph
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
	_hud.show_countdown(str(_countdown_shown))
	_hud.toast("Llega a la isla M · %s abre la ayuda" % InputHints.key_label(&"help"))


func _begin_round() -> void:
	phase = Phase.RUNNING
	for id: int in _players:
		(_players[id] as Player).set_input_enabled(id == _local_id)
	_hud.hide_countdown()
	_hud.toast("¡Corre! Los bots salen de a uno: el primer perseguidor, en %d s" % int(settings.bot_head_start))


#Each bot leaves when its role says, like the ghosts leaving their house one after the other
func _release_due_bots() -> void:
	for index in range(_release_schedule.size() - 1, -1, -1):
		var entry := _release_schedule[index]
		if rules.elapsed < entry["at"]:
			continue
		(entry["bot"] as ChaserBot).activate(local_locator().vertex)
		_release_schedule.remove_at(index)
		_hint_once(&"release", "¡Los bots te buscan! Cada uno lo hace a su manera")


func _update_running(delta: float) -> void:
	rules.tick(delta)
	if phase != Phase.RUNNING:
		return
	_release_due_bots()
	for id: int in _players:
		if (_players[id] as Player).global_position.y < FALL_Y:
			rules.fall(id)
			if phase != Phase.RUNNING:
				return
	_update_context()
	_update_prompt()
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_hud.set_time(rules.time_left)
		_update_ability_chips()
	var refuge := _local_state().refuge_left
	if refuge > 0.0 and _flat_distance(_any_player().global_position, _world.refuge_center) > settings.refuge_radius:
		rules.leave_refuge(_local_id)


func _update_context() -> void:
	for target in _context.targets:
		target.detection_radius = rules.detection_radius(target.player_id)
		target.protected = rules.is_protected(target.player_id)
	if rules.is_protected(_local_id):
		_hud.show_protection("Protegido %.1f s" % rules.protection_left(_local_id))
	else:
		_hud.hide_protection()


func _update_ability_chips() -> void:
	_world.set_station_active(&"E", rules.active_left(_local_id, Level01Rules.Ability.BLOCK) > 0.0)
	_world.set_station_active(&"F", rules.active_left(_local_id, Level01Rules.Ability.SILENCE) > 0.0)
	_world.set_station_active(&"D", rules.active_left(_local_id, Level01Rules.Ability.REFUGE) > 0.0)
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
	if phase == Phase.RUNNING and not paused:
		_try_interact()


func _near(id: StringName) -> bool:
	return _flat_distance(_any_player().global_position, _world.station_positions[id]) <= settings.station_radius


func _try_interact() -> void:
	if _near(&"E"):
		_use(Level01Rules.Ability.BLOCK, "Bloquear", "Bloquear: poner límites cierra el paso a quien te molesta")
	elif _near(&"F"):
		_use(Level01Rules.Ability.SILENCE, "Silenciar", "Silenciar: tú decides qué notificaciones te alcanzan")
	elif _near(&"D"):
		_use(Level01Rules.Ability.REFUGE, "La pausa digital", "Pausa digital: parar un momento también es avanzar")


func _use(ability: int, name: String, done: String) -> void:
	if rules.use_ability(_local_id, ability) == Level01Rules.Use.COOLDOWN:
		_hud.toast("%s se está recargando: %d s" % [name, ceili(rules.cooldown_left(_local_id, ability))])
	else:
		_hud.toast(done)


func _update_prompt() -> void:
	var text := ""
	if _near(&"E"):
		text = "Pulsa %s · Bloquear" % InputHints.key_markup(&"interact")
	elif _near(&"F"):
		text = "Pulsa %s · Silenciar" % InputHints.key_markup(&"interact")
	elif _near(&"D"):
		text = "Pulsa %s · Pausa digital" % InputHints.key_markup(&"interact")
	if text == "":
		_hud.hide_prompt()
	else:
		_hud.show_prompt(text)


func _on_place_changed(player_id: int) -> void:
	if phase != Phase.RUNNING or player_id != _local_id:
		return
	var locator := local_locator()
	if locator.on_bridge:
		return
	var vertex := locator.vertex
	if vertex == Level01Layout.GOAL:
		rules.reach_goal(player_id)
	elif vertex == &"H" and rules.reach_checkpoint(player_id, vertex):
		_world.set_checkpoint_active(true)
		_hud.toast("Checkpoint: guardar tu progreso es descansar sin perderlo")
	else:
		_station_hint(vertex)


#Each station explains itself the first time the player reaches its island
func _station_hint(vertex: StringName) -> void:
	var text := ""
	match vertex:
		&"E":
			text = "Isla E: pulsa %s junto al letrero para bloquear el puente E-H a los bots" % InputHints.key_label(&"interact")
		&"F":
			text = "Isla F: pulsa %s junto a la campana y los bots te ven menos %d s" % [InputHints.key_label(&"interact"), int(settings.silence_duration)]
		&"D":
			text = "Isla D: entra a la burbuja y pulsa %s: nadie te empuja un momento" % InputHints.key_label(&"interact")
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
		return
	var vertex := rules.state_of(player_id).checkpoint
	var player := _players[player_id] as Player
	player.global_position = _spawn_position(vertex)
	player.clear_motion()
	(player.get_node("CameraRig") as PlayerCamera).rotation.y = 0.0
	(player.get_node("ModelPivot") as Node3D).rotation.y = PI
	(_locators[player_id] as PlayerLocator).force_vertex(vertex)
	if player_id == _local_id:
		_hud.toast("Caíste. Te quedan %d intentos: respira y retoma" % attempts_left)


func _on_push_announced(bot: ChaserBot) -> void:
	_hud.warn("¡Esquiva!")
	if bot.appearance.tip != "":
		_hint_once(bot.appearance.id, bot.appearance.tip)


func _on_push_landed(bot: ChaserBot, direction: Vector3, player_id: int) -> void:
	if not rules.register_hit(player_id):
		return
	(_players[player_id] as Player).apply_push(direction * settings.push_speed + Vector3.UP * settings.push_lift)
	if player_id == _local_id:
		_hud.toast("¡Empujón de %s! Cuidado con el borde" % bot.appearance.display_name)


func _on_outcome(outcome: int) -> void:
	match outcome:
		Level01Rules.Outcome.WON:
			_finish(true, "¡Te desconectaste a tiempo!",
				"Llegaste a la zona de desconexión con %d s de sobra. Cuidar tu atención también es ganar." % ceili(rules.time_left))
		Level01Rules.Outcome.LOST_TIME:
			_finish(false, "Se acabó el tiempo",
				"Ir sin pausa agota. Respirar y retomar también cuenta: inténtalo de nuevo.")
		Level01Rules.Outcome.LOST_ATTEMPTS:
			_finish(false, "Sin intentos",
				"Caer no es fracasar. Prueba otra ruta y usa Bloquear para frenar a los bots.")


func _finish(victory: bool, title: String, message: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	_hud.set_time(rules.time_left)
	_debug.end_demo()
	for id: int in _players:
		var player := _players[id] as Player
		player.set_input_enabled(false)
		player.clear_motion()
	for bot in bots:
		bot.deactivate()
	#A late Esc press must not open the pause menu over the final panel
	_pause_menu.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.hide_prompt()
	var lines: Array[Array] = [
		["Tiempo restante", "%d s" % ceili(rules.time_left)],
		["Intentos", "%d de %d" % [_local_state().attempts_left, settings.attempts]],
	]
	if not finish_round(RoundResult.make(SCREEN_ID, victory, title, message, lines)):
		_hud.show_end(title, message, victory)


func _retry() -> void:
	if GameSession.is_playing_round():
		GameSession.restart_round()
	else:
		ScreenFlow.reload_current()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
