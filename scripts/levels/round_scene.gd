class_name RoundScene
extends Node3D

#Shared base of every round scene: players, ending, pause and help, in a session or alone

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

@export var default_character: CharacterData

var participants: Array[PlayerSlot] = []
var paused := false
#Pose key in every round; the dock shows the key
var poses := PoseKeeper.new()
#Hides the camera jump when this screen's player falls and returns
var iris := IrisFade.new()

#Opening film on unless a test turns it off; never without a screen
static var films_enabled := true
#While the film plays the round waits but the world moves
var filming := false
#In a room, after its player is done this computer watches the others
var spectating := false

#Every player by id: this screen's and the remote puppets
var everyone: Dictionary = {}

var _pose_dock := PoseDock.new()
var _pose_local := -1
var _pose_player: Player
var _hidden_layers: Array[CanvasLayer] = []

@onready var _pause_menu: PauseMenu = get_node_or_null("PauseMenu")
@onready var _actors: Node3D = get_node_or_null("Actors")
@onready var _help: LevelHelp = get_node_or_null("Help")


func _ready() -> void:
	#Disconnected players sit out until they return
	for slot in GameSession.participants(default_character):
		if slot.connected or slot.player_id == GameSession.local_id:
			participants.append(slot)
	GameSession.net.player_left.connect(_on_net_player_left)
	if _pause_menu != null:
		_pause_menu.opened.connect(_on_pause_opened)
		_pause_menu.closed.connect(_on_pause_closed)
		_pause_menu.help_requested.connect(open_help)
		_pause_menu.allow_help = _help != null
	if _help != null:
		_help.finished.connect(_on_help_finished)
	poses.name = "Poses"
	poses.allowed = _pose_allowed
	add_child(poses)
	_pose_dock.source = pose_state
	add_child(_pose_dock)
	add_child(iris)
	Rumble.follow_round(self)
	_open_film.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if filming:
		return
	if event.is_action_pressed("help") and _help != null and not _help.is_open():
		open_help()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not paused and _pose_local >= 0:
		press_pose()
		_pose_dock.press()


#Reports the result; alone returns false; in a room waits for everybody while spectating
func finish_round(result: RoundResult) -> bool:
	var reported := GameSession.report_result(result)
	if reported and GameSession.is_networked() and not GameSession.practice:
		start_spectating()
	return reported


func start_spectating() -> void:
	if spectating or not GameSession.is_networked():
		return
	spectating = true
	poses.stop_all()
	var view := SpectatorView.new()
	add_child(view)
	view.begin(self)


#One Player per participant; the first is this screen's
func spawn_players(parent: Node3D, points: Array[Vector3]) -> Array[Player]:
	var spawned: Array[Player] = []
	for index in participants.size():
		var slot := participants[index]
		var player := PLAYER_SCENE.instantiate() as Player
		player.player_id = slot.player_id
		parent.add_child(player)
		player.global_position = points[mini(index, points.size() - 1)]
		if slot.character != null:
			player.set_character(slot.character, GameSession.variant_of(slot.player_id))
		var local := slot.player_id == GameSession.local_id or (index == 0 and not GameSession.is_networked())
		player.set_input_enabled(local)
		if GameSession.is_networked() and not local:
			player.make_remote()
		add_poser(player, local)
		spawned.append(player)
	return spawned


func screen_player() -> Player:
	return _pose_player


#The one with the local id, or the first alone
static func local_of(spawned: Array[Player]) -> Player:
	for player in spawned:
		if player.player_id == GameSession.local_id:
			return player
	return spawned[0] if not spawned.is_empty() else null


#Round randomness: the room seed, a fixed settings seed, or any
func seed_rng(generator: RandomNumberGenerator, fixed := 0) -> void:
	if fixed != 0:
		generator.seed = fixed
	elif GameSession.round_seed != 0:
		generator.seed = GameSession.round_seed
	else:
		generator.randomize()


#A player that can pose; "local" owns the key and dock
func add_poser(player: Player, local: bool) -> void:
	everyone[player.player_id] = player
	poses.add(player)
	if local:
		_pose_local = player.player_id
		_pose_player = player


#This screen's pose key; a round may use it first for something else
func press_pose() -> void:
	poses.toggle(_pose_local)


#Rounds forbid poses before the start, after the end or while falling
func _pose_allowed(_player_id: int) -> bool:
	return not paused


#Dock hidden while paused or over
func _pose_shown() -> bool:
	return not paused and not filming and not spectating


func pose_state() -> int:
	if _pose_local < 0 or not _pose_shown():
		return PoseDock.State.HIDDEN
	if poses.is_posing(_pose_local):
		return PoseDock.State.POSING
	return PoseDock.State.READY if poses.can_pose(_pose_local) else PoseDock.State.BLOCKED


#Opening film: the round waits and Esc and F1 do nothing until it lands
func _open_film() -> void:
	var info := MinigameCatalog.find(ScreenFlow.current) if ScreenFlow.current != &"" else null
	var networked := GameSession.is_networked() and not GameSession.practice
	ImpactFx.freeze_allowed = not networked
	if networked:
		add_child(NetPuppets.new())
	var cover: LoadingCover = null
	if networked and info != null:
		#Round art covers the screen until every computer loaded; then the film starts everywhere
		filming = true
		cover = LoadingCover.new()
		add_child(cover)
		cover.show_round(info, _step_text())
		await _wait_for_everybody()
	#The fair screen has no film: it starts with the players and catches up if late
	if GameSession.net.role == NetRoom.Role.WATCH:
		var film_left := _players_film_length(info) - _seconds_behind()
		if film_left > 0.0:
			await get_tree().create_timer(film_left).timeout
		filming = false
		catch_up(maxf(-film_left, 0.0))
		if cover != null:
			cover.lift()
		return
	var films := films_enabled and info != null and _pose_player != null and DisplayServer.get_name() != "headless"
	var shots: Array[RoundFilm.Shot] = []
	if films:
		shots = _film_shots()
	if cover != null:
		cover.lift()
	if not films:
		filming = false
		return
	if shots.is_empty():
		return
	filming = true
	for layer in find_children("*", "CanvasLayer", true, false):
		var canvas := layer as CanvasLayer
		if canvas.visible and canvas != _pose_dock:
			canvas.visible = false
			_hidden_layers.append(canvas)
	if _pause_menu != null:
		_pause_menu.set_process_unhandled_input(false)
	var film := RoundFilm.new()
	film.skippable = not networked
	add_child(film)
	film.play(shots, info.title, info.tagline, _step_text(), _pose_player.view_camera())
	await film.finished
	filming = false
	for canvas in _hidden_layers:
		if is_instance_valid(canvas):
			canvas.visible = true
	_hidden_layers.clear()
	if _pause_menu != null:
		_pause_menu.set_process_unhandled_input(true)


func _step_text() -> String:
	if GameSession.practice or GameSession.round_index < 0 or GameSession.plan.is_empty():
		return ""
	return "RONDA %d DE %d" % [GameSession.round_index + 1, GameSession.plan.size()]


#Players' film length, measured around the first player on the fair screen; 0 headless
func _players_film_length(info: MinigameInfo) -> float:
	if not films_enabled or info == null or everyone.is_empty() or DisplayServer.get_name() == "headless":
		return 0.0
	var keep := _pose_player
	if _pose_player == null:
		var first: int = everyone.keys().min()
		_pose_player = everyone[first]
	var seconds := RoundFilm.length_of(_film_shots())
	_pose_player = keep
	return seconds


#Seconds since the room released this round, for the fair screen only
func _seconds_behind() -> float:
	var net := GameSession.net
	if net.role != NetRoom.Role.WATCH or net.go_round < GameSession.round_index or net.go_at <= 0:
		return 0.0
	return (Time.get_ticks_msec() - net.go_at) / 1000.0


#A late fair screen runs the missed seconds at once in silent physics steps
func catch_up(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var muted := AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	var step := 1.0 / Engine.physics_ticks_per_second
	for index in floori(seconds / step):
		call("_physics_process", step)
	AudioServer.set_bus_mute(0, muted)


#In a room everybody waits here for the server's start
func _wait_for_everybody() -> void:
	if not GameSession.is_networked() or GameSession.practice:
		return
	var net := GameSession.net
	var round_index := GameSession.round_index
	net.report_loaded(round_index)
	while net.is_active() and net.go_round < round_index:
		await get_tree().process_frame


#Opening film shots: circle the field from high up, then come down behind the player
func _film_shots() -> Array[RoundFilm.Shot]:
	var area := playing_area()
	var shots: Array[RoundFilm.Shot] = []
	if area.size == Vector3.ZERO:
		return shots
	var centre := area.get_center()
	var reach := maxf(area.size.x, area.size.z) * 0.62 + 6.0
	var facing := _pose_player.look_direction()
	var behind := atan2(-facing.x, -facing.z)
	var orbit := func(angle: float, distance: float, height: float) -> Vector3:
		return centre + Vector3(sin(angle) * distance, height, cos(angle) * distance)
	shots.append(RoundFilm.Shot.new(orbit.call(behind + 2.2, reach, reach * 0.55), centre, orbit.call(behind + 1.65, reach * 0.97, reach * 0.45), centre, 3.6))
	var player_at := _pose_player.global_position
	var aside := Vector3(-facing.z, 0.0, facing.x)
	shots.append(RoundFilm.Shot.new(player_at - facing * 15.0 + aside * 6.0 + Vector3(0.0, 9.0, 0.0), player_at + Vector3(0.0, 1.0, 0.0),
		player_at - facing * 8.0 + aside * 1.5 + Vector3(0.0, 4.5, 0.0), player_at + Vector3(0.0, 1.0, 0.0), 2.6))
	return shots


#Box around every floor and wall players can touch
func playing_area() -> AABB:
	var area := AABB()
	var first := true
	for node in find_children("*", "CollisionShape3D", true, false):
		var holder := node as CollisionShape3D
		if holder.shape == null or holder.disabled or holder.get_parent() is CharacterBody3D or holder.get_parent() is Area3D:
			continue
		var box := holder.global_transform * holder.shape.get_debug_mesh().get_aabb()
		if box.size.length() > 400.0:
			continue
		area = box if first else area.merge(box)
		first = false
	return area


#A departed computer's player hides and is no longer waited for
func _on_net_player_left(player_id: int) -> void:
	var player: Player = everyone.get(player_id)
	if player != null and is_instance_valid(player) and player.remote:
		player.vanish()
	_on_player_left(player_id)


func _on_player_left(_player_id: int) -> void:
	pass


func _networked_round() -> bool:
	return GameSession.is_networked() and not GameSession.practice


#The round freezes while the help is open (no help in a room)
func open_help() -> void:
	if filming or _networked_round() or _help == null or _help.is_open() or not _help_allowed():
		return
	paused = true
	if _actors != null:
		_actors.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#Esc closing the help must not open the pause
	if _pause_menu != null:
		_pause_menu.set_process_unhandled_input(false)
	_help.open()


#When the help cannot open
func _help_allowed() -> bool:
	return true


func _on_help_finished() -> void:
	if _pause_menu != null:
		_pause_menu.set_process_unhandled_input(_help_allowed())
		if _pause_menu.visible:
			return
	paused = false
	if _actors != null:
		_actors.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _paused_changed(_is_paused: bool) -> void:
	pass


#In a room the pause only rests this player's keys
func _on_pause_opened() -> void:
	if _networked_round():
		if _pose_player != null:
			_pose_player.menu_open = true
		return
	paused = true
	if _actors != null:
		_actors.process_mode = Node.PROCESS_MODE_DISABLED
	_paused_changed(true)


func _on_pause_closed() -> void:
	if _networked_round():
		if _pose_player != null:
			_pose_player.menu_open = false
		return
	paused = false
	if _actors != null:
		_actors.process_mode = Node.PROCESS_MODE_INHERIT
	_paused_changed(false)
