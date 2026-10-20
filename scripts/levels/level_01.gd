class_name Level01
extends Node3D

#Level 1 "Escapa del feed": reach the goal before time or attempts run out while bots chase over the bridges

enum Phase { INTRO, COUNTDOWN, RUNNING, ENDED }

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const BOT_SCENE := preload("res://scenes/bots/chaser_bot.tscn")
const SCREEN_ID := &"level_01"
const FALL_Y := -12.0

#Used when the scene runs without going through character select
@export var default_character: CharacterData

@export_group("Round")
@export var time_limit := 120.0
@export var attempts := 3
@export var countdown_seconds := 3.0
#Seconds the player runs before the bots are released
@export var bot_head_start := 5.0

@export_group("Bots")
#The first "active_bot_count" appearances of the list are used, in that order
@export var bot_appearances: Array[BotAppearance] = []
@export_range(1, 4) var active_bot_count := 2
#Bot speed as a fraction of the player's speed (slightly below 1)
@export_range(0.3, 1.0) var bot_speed_ratio := 0.86
@export var bot_recalc_interval := 0.4
@export var bot_lose_time := 5.0
#0 picks a different random spawn each round; any other value repeats it
@export var random_seed := 0

@export_group("Detection")
@export var detection_radius := 18.0
@export var silenced_detection_radius := 6.0

@export_group("Abilities")
@export var block_duration := 6.0
@export var block_cooldown := 15.0
@export var silence_duration := 8.0
@export var silence_cooldown := 20.0
@export var refuge_duration := 3.0
@export var refuge_cooldown := 20.0
@export var respawn_protection := 2.0
@export var station_radius := 4.0
@export var refuge_radius := 3.6

@export_group("Push")
@export var push_speed := 9.0
@export var push_lift := 3.0
#Seconds in which the same shove cannot hit the player again
@export var hit_immunity := 1.5

var phase := Phase.INTRO
var time_left := 0.0
var attempts_left := 0
var graph: WeightedGraph
var bots: Array[ChaserBot] = []
var checkpoint_vertex: StringName = Level01Layout.START

var _context := ChaseContext.new()
var _player: Player
var _camera_rig: PlayerCamera
var _model_pivot: Node3D
var _rng := RandomNumberGenerator.new()
var _phase_timer := 0.0
var _round_clock := 0.0
var _bots_released := false
var _paused := false
var _checkpoint_active := false
var _block_left := 0.0
var _block_cooldown_left := 0.0
var _silence_left := 0.0
var _silence_cooldown_left := 0.0
var _refuge_left := 0.0
var _refuge_cooldown_left := 0.0
var _respawn_left := 0.0
var _hit_immunity_left := 0.0
var _tips_shown: Dictionary = {}
var _debug_dirty := true
var _debug_timer := 0.0
var _debug_graph_version := -1
var _hud_timer := 0.0
var _countdown_shown := 0
var _demo_bot: ChaserBot
var _demo_time := 0.0
var _demo_blocked := false

@onready var _actors: Node3D = $Actors
@onready var _world: Level01World = $World
@onready var _locator: PlayerLocator = $Locator
@onready var _level_input: LevelInput = $LevelInput
@onready var _debug_view: GraphDebugView = $DebugView
@onready var _hud: LevelHud = $Hud
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _help: LevelHelp = $Help


func _ready() -> void:
	if ScreenFlow.tree.has(SCREEN_ID):
		ScreenFlow.mark_current(SCREEN_ID)
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()

	graph = Level01Layout.build_graph()
	_world.build(_locator)
	_spawn_player()
	_setup_context()
	_spawn_bots()

	_debug_view.setup(graph, Level01Layout.POSITIONS)
	_debug_view.visible = false
	_pause_menu.opened.connect(_on_pause_opened)
	_pause_menu.closed.connect(_on_pause_closed)
	_hud.help_requested.connect(_open_help_review)
	_level_input.help_pressed.connect(_open_help_review)
	_level_input.debug_toggled.connect(_toggle_debug)
	_level_input.demo_toggled.connect(_toggle_demo)
	_level_input.interact_pressed.connect(_on_interact)
	_help.finished.connect(_on_help_finished)
	_hud.retry_requested.connect(_retry)
	_hud.menu_requested.connect(ScreenFlow.go_to_root)
	_locator.place_changed.connect(_on_place_changed)

	time_left = time_limit
	attempts_left = attempts
	_hud.set_time(time_left)
	_hud.set_attempts(attempts_left, attempts)
	_hud.hide_countdown()
	_update_ability_chips()
	#Pause only works once the round has started, the intro card covers the menu
	_pause_menu.set_process_unhandled_input(false)
	_help.setup(_help_config())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_help.open(true)


func _spawn_player() -> void:
	var character := GameState.get_character(GameState.PLAYER_ONE)
	if character == null:
		character = default_character
	_player = PLAYER_SCENE.instantiate() as Player
	_player.player_id = GameState.PLAYER_ONE
	_actors.add_child(_player)
	_player.global_position = _spawn_position(Level01Layout.START)
	_player.set_character(character)
	_player.set_input_enabled(false)
	_camera_rig = _player.get_node("CameraRig") as PlayerCamera
	_model_pivot = _player.get_node("ModelPivot") as Node3D
	_locator.force_vertex(Level01Layout.START)


func _setup_context() -> void:
	_context.graph = graph
	_context.positions = Level01Layout.POSITIONS
	var radii: Dictionary = {}
	for id: StringName in Level01Layout.POSITIONS:
		radii[id] = Level01Layout.radius_of(id)
	_context.radii = radii
	_context.forbidden = Level01Layout.BOT_FORBIDDEN
	_context.player = _player
	_context.locator = _locator
	_context.detection_radius = detection_radius


func _spawn_bots() -> void:
	var spawns: Array[StringName] = Level01Layout.BOT_SPAWNS.duplicate()
	#Fisher-Yates shuffle with the level's own generator, so a seed repeats the round
	for index in range(spawns.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var swap := spawns[index]
		spawns[index] = spawns[other]
		spawns[other] = swap
	var count := mini(active_bot_count, bot_appearances.size())
	for index in count:
		var bot := _make_bot(bot_appearances[index], spawns[index])
		bots.append(bot)


func _make_bot(appearance: BotAppearance, vertex: StringName) -> ChaserBot:
	var bot := BOT_SCENE.instantiate() as ChaserBot
	_actors.add_child(bot)
	bot.setup(_context, appearance, vertex)
	bot.move_speed = _player.move_speed * bot_speed_ratio
	bot.recalc_interval = bot_recalc_interval
	bot.lose_time = bot_lose_time
	bot.route_changed.connect(_on_route_changed)
	bot.push_announced.connect(_on_push_announced)
	bot.push_landed.connect(_on_push_landed)
	return bot


func _spawn_position(vertex: StringName) -> Vector3:
	return Level01Layout.POSITIONS[vertex] + Vector3(0, 0.05, 0)


#Numbers shown in the help texts, taken from the exported settings of the level
func _help_config() -> Dictionary:
	return {
		"time_limit": time_limit, "attempts": attempts, "head_start": bot_head_start,
		"block_duration": block_duration, "block_cooldown": block_cooldown,
		"silence_duration": silence_duration, "silence_cooldown": silence_cooldown,
		"silenced_radius": silenced_detection_radius, "detection_radius": detection_radius,
		"refuge_duration": refuge_duration, "refuge_cooldown": refuge_cooldown,
		"respawn_protection": respawn_protection,
	}


func _begin_countdown() -> void:
	if phase != Phase.INTRO:
		return
	_pause_menu.set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	phase = Phase.COUNTDOWN
	_phase_timer = countdown_seconds
	_countdown_shown = ceili(_phase_timer)
	_hud.show_countdown(str(_countdown_shown))


func _begin_round() -> void:
	phase = Phase.RUNNING
	_round_clock = 0.0
	_player.set_input_enabled(true)
	_hud.hide_countdown()
	_hud.toast("¡Corre! Los bots salen en %d s" % int(bot_head_start))


func _release_bots() -> void:
	_bots_released = true
	for bot in bots:
		bot.activate(_locator.vertex)
	_hud.toast("¡Los bots te persiguen! Busca otra ruta o usa Bloquear")


func _finish(victory: bool, title: String, message: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	_end_demo()
	_player.set_input_enabled(false)
	_player.clear_motion()
	for bot in bots:
		bot.deactivate()
	#A late Esc press must not open the pause menu over the final panel
	_pause_menu.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.hide_prompt()
	_hud.show_end(title, message, victory)


func _retry() -> void:
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if _paused:
		return
	_update_debug(delta)
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
	_update_demo(delta)


func _update_running(delta: float) -> void:
	_round_clock += delta
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_hud.set_time(0.0)
		_finish(false, "Se acabó el tiempo",
			"Ir sin pausa agota. Respirar y retomar también cuenta: inténtalo de nuevo.")
		return
	if not _bots_released and _round_clock >= bot_head_start:
		_release_bots()

	_tick_abilities(delta)
	if _player.global_position.y < FALL_Y:
		_on_fall()
	_update_context()
	_update_prompt()
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_hud.set_time(time_left)
		_update_ability_chips()


func _tick_abilities(delta: float) -> void:
	_hit_immunity_left = maxf(_hit_immunity_left - delta, 0.0)
	_respawn_left = maxf(_respawn_left - delta, 0.0)
	_block_cooldown_left = maxf(_block_cooldown_left - delta, 0.0)
	_silence_cooldown_left = maxf(_silence_cooldown_left - delta, 0.0)
	_refuge_cooldown_left = maxf(_refuge_cooldown_left - delta, 0.0)
	if _block_left > 0.0:
		_block_left -= delta
		if _block_left <= 0.0:
			_set_block(false)
	_silence_left = maxf(_silence_left - delta, 0.0)
	if _refuge_left > 0.0:
		_refuge_left -= delta
		#Leaving the shelter ends the protection early
		if _flat_distance(_player.global_position, _world.refuge_center) > refuge_radius:
			_refuge_left = 0.0


func _update_context() -> void:
	_context.detection_radius = silenced_detection_radius if _silence_left > 0.0 else detection_radius
	var protected := _respawn_left > 0.0 or _refuge_left > 0.0
	_context.player_protected = protected
	if protected:
		var seconds := maxf(_respawn_left, _refuge_left)
		_hud.show_protection("Protegido %.1f s" % seconds)
	else:
		_hud.hide_protection()


func _update_ability_chips() -> void:
	_hud.set_ability(&"block", _ability_text(_block_left, _block_cooldown_left), _block_cooldown_left <= 0.0)
	_hud.set_ability(&"silence", _ability_text(_silence_left, _silence_cooldown_left), _silence_cooldown_left <= 0.0)
	_hud.set_ability(&"pause", _ability_text(_refuge_left, _refuge_cooldown_left), _refuge_cooldown_left <= 0.0)


func _ability_text(active_left: float, cooldown_left: float) -> String:
	if active_left > 0.0:
		return "Activo %d s" % ceili(active_left)
	if cooldown_left > 0.0:
		return "Recarga %d s" % ceili(cooldown_left)
	return "Listo"


func _toggle_debug() -> void:
	_debug_view.visible = not _debug_view.visible
	_hud.set_debug_visible(_debug_view.visible)
	_debug_dirty = true


func _toggle_demo() -> void:
	if _demo_bot == null:
		_start_demo()
	else:
		_end_demo()


func _on_interact() -> void:
	if phase == Phase.RUNNING and not _paused:
		_try_interact()


func _near(id: StringName, radius: float) -> bool:
	return _flat_distance(_player.global_position, _world.station_positions[id]) <= radius


func _try_interact() -> void:
	if _near(&"E", station_radius):
		if _block_cooldown_left > 0.0:
			_hud.toast("Bloquear se está recargando: %d s" % ceili(_block_cooldown_left))
		else:
			_activate_block()
	elif _near(&"F", station_radius):
		if _silence_cooldown_left > 0.0:
			_hud.toast("Silenciar se está recargando: %d s" % ceili(_silence_cooldown_left))
		else:
			_silence_left = silence_duration
			_silence_cooldown_left = silence_cooldown
			_hud.toast("Silenciar: tú decides qué notificaciones te alcanzan")
	elif _near(&"D", station_radius):
		if _refuge_cooldown_left > 0.0:
			_hud.toast("La pausa digital se está recargando: %d s" % ceili(_refuge_cooldown_left))
		else:
			_refuge_left = refuge_duration
			_refuge_cooldown_left = refuge_cooldown
			_hud.toast("Pausa digital: parar un momento también es avanzar")


func _activate_block() -> void:
	_block_cooldown_left = block_cooldown
	_block_left = block_duration
	_set_block(true)
	_hud.toast("Bloquear: poner límites cierra el paso a quien te molesta")


#Closes or opens the E-H bridge for the bots; the bridge itself stays walkable for the player
func _set_block(blocked: bool) -> void:
	graph.set_edge_enabled(Level01Layout.BLOCK_EDGE[0], Level01Layout.BLOCK_EDGE[1], not blocked)
	_world.set_block_visual(blocked)
	_debug_dirty = true


func _update_prompt() -> void:
	var text := ""
	if _near(&"E", station_radius):
		text = "Pulsa %s · Bloquear" % InputHints.key_markup(&"interact")
	elif _near(&"F", station_radius):
		text = "Pulsa %s · Silenciar" % InputHints.key_markup(&"interact")
	elif _near(&"D", station_radius):
		text = "Pulsa %s · Pausa digital" % InputHints.key_markup(&"interact")
	if text == "":
		_hud.hide_prompt()
	else:
		_hud.show_prompt(text)


func _on_place_changed() -> void:
	_debug_dirty = true
	if phase != Phase.RUNNING or _locator.on_bridge:
		return
	if _locator.vertex == Level01Layout.GOAL:
		_finish(true, "¡Te desconectaste a tiempo!",
			"Llegaste a la zona de desconexión con %d s de sobra. Cuidar tu atención también es ganar." % ceili(time_left))
	elif _locator.vertex == &"H" and not _checkpoint_active:
		_checkpoint_active = true
		checkpoint_vertex = &"H"
		_world.set_checkpoint_active(true)
		_hud.toast("Checkpoint: guardar tu progreso es descansar sin perderlo")


func _on_fall() -> void:
	attempts_left -= 1
	_hud.set_attempts(attempts_left, attempts)
	if attempts_left <= 0:
		_finish(false, "Sin intentos",
			"Caer no es fracasar. Prueba otra ruta y usa Bloquear para frenar a los bots.")
		return
	_player.global_position = _spawn_position(checkpoint_vertex)
	_player.clear_motion()
	_camera_rig.rotation.y = 0.0
	_model_pivot.rotation.y = PI
	_locator.force_vertex(checkpoint_vertex)
	_respawn_left = respawn_protection
	_hud.toast("Caíste. Te quedan %d intentos: respira y retoma" % attempts_left)


func _on_route_changed(_bot: ChaserBot) -> void:
	_debug_dirty = true


func _on_push_announced(bot: ChaserBot) -> void:
	_hud.warn("¡Esquiva!")
	var id := bot.appearance.id
	if not _tips_shown.has(id) and bot.appearance.tip != "":
		_tips_shown[id] = true
		_hud.toast(bot.appearance.tip)


func _on_push_landed(bot: ChaserBot, direction: Vector3) -> void:
	if _context.player_protected or _hit_immunity_left > 0.0:
		return
	_hit_immunity_left = hit_immunity
	_player.apply_push(direction * push_speed + Vector3.UP * push_lift)
	_hud.toast("¡Empujón de %s! Cuidado con el borde" % bot.appearance.display_name)


#Help during the round: the game is frozen like in the pause menu while it is open
func _open_help_review() -> void:
	if _help.is_open() or phase == Phase.ENDED or phase == Phase.INTRO:
		return
	_paused = true
	_actors.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#Esc closes the help, it must not also open the pause menu behind it
	_pause_menu.set_process_unhandled_input(false)
	_help.open(false)


func _on_help_finished(start_mode: bool) -> void:
	if start_mode:
		_begin_countdown()
		return
	_pause_menu.set_process_unhandled_input(phase != Phase.ENDED)
	if _pause_menu.visible:
		return
	_paused = false
	_actors.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_pause_opened() -> void:
	_paused = true
	_actors.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.show_pause_actions(true)


func _on_pause_closed() -> void:
	_paused = false
	_actors.process_mode = Node.PROCESS_MODE_INHERIT
	_hud.show_pause_actions(false)


func _update_debug(delta: float) -> void:
	if not _debug_view.visible:
		return
	_debug_timer += delta
	if graph.version != _debug_graph_version:
		_debug_graph_version = graph.version
		_debug_dirty = true
	if _debug_timer < 0.1:
		return
	_debug_timer = 0.0
	var all_bots := bots.duplicate()
	if _demo_bot != null:
		all_bots.append(_demo_bot)
	var typed: Array[ChaserBot] = []
	typed.assign(all_bots)
	_debug_view.redraw(typed)
	_hud.set_debug_text(_debug_text(typed))
	_debug_dirty = false


func _debug_text(all_bots: Array[ChaserBot]) -> String:
	var lines := PackedStringArray()
	lines.append("[b]Grafo[/b]  %d vértices · %d puentes" % [graph.vertices().size(), graph.undirected_edges().size()])
	var blocked := PackedStringArray()
	for edge in graph.undirected_edges():
		if not edge["enabled"]:
			blocked.append("%s-%s" % [edge["a"], edge["b"]])
	lines.append("Bloqueados: %s" % (", ".join(blocked) if not blocked.is_empty() else "ninguno"))
	lines.append("Tú: %s" % (("puente %s-%s" % [_locator.bridge_a, _locator.bridge_b]) if _locator.on_bridge else String(_locator.vertex)))
	for bot in all_bots:
		var info := bot.debug_info()
		var name_markup := "[color=#%s][b]%s[/b][/color]" % [(info["color"] as Color).to_html(false), info["name"]]
		if not info["found"] and info["target"] != &"":
			lines.append("%s: [color=#c0262d]SIN CAMINO[/color] hacia %s" % [name_markup, info["target"]])
			lines.append("   %s" % info["message"])
		elif info["target"] == &"":
			lines.append("%s: sin destino (%s)" % [name_markup, info["state"]])
		else:
			var path: Array = info["route"]
			lines.append("%s: %s → %s · costo %s · %s" % [
				name_markup, info["from"], info["target"], String.num(info["cost"], 0), " › ".join(PackedStringArray(path))])
	return "\n".join(lines)


#Demo: a bot goes from B to J, then E-H is blocked and the route cost goes from 6 to 11
func _start_demo() -> void:
	if phase == Phase.ENDED:
		return
	_debug_view.visible = true
	_hud.set_debug_visible(true)
	var appearance: BotAppearance = bot_appearances[0] if not bot_appearances.is_empty() else null
	if appearance == null:
		return
	_demo_bot = _make_bot(appearance, &"B")
	_demo_bot.push_enabled = false
	_demo_bot.manual_target = true
	_demo_bot.hold_movement = true
	_demo_bot.activate(&"J")
	_demo_time = 0.0
	_demo_blocked = false
	_hud.toast("Demostración: de B a J por el camino de menor costo")


func _update_demo(delta: float) -> void:
	if _demo_bot == null:
		return
	_demo_time += delta
	if _demo_time >= 3.0 and not _demo_blocked:
		_demo_blocked = true
		_set_block(true)
		_hud.toast("Se bloquea E-H: Dijkstra elige otro camino")
	if _demo_time >= 5.0:
		_demo_bot.hold_movement = false
	if _demo_blocked and _demo_time >= 3.0 + block_duration:
		_set_block(false)
	if _demo_bot.current_vertex == &"J" and not _demo_bot.is_crossing():
		_end_demo()


func _end_demo() -> void:
	if _demo_bot == null:
		return
	_demo_bot.queue_free()
	_demo_bot = null
	if _demo_blocked and _block_left <= 0.0:
		_set_block(false)
	_demo_blocked = false
	_debug_dirty = true


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
