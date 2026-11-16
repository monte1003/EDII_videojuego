class_name RoundScene
extends Node3D

#What every round scene shares: who plays, how it ends, pause and help; it runs in a session or on its own

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

@export var default_character: CharacterData

var participants: Array[PlayerSlot] = []
var paused := false
#Anyone can strike a pose or a dance with the pose key in every round; the dock at the bottom of the screen shows the key
var poses := PoseKeeper.new()
#Hides the jump of the camera when the player of this screen falls off the map and comes back
var iris := IrisFade.new()

#The opening film plays at the start of every minigame unless a test turns it off; it never plays without a screen
static var films_enabled := true
#True while the opening film plays: the round waits as in the pause, but its world keeps moving
var filming := false
#In a room, after its own player is done, this computer watches the others until the round is over
var spectating := false

#Every player of the round by id, the one of this screen and the puppets of the other computers
var everyone: Dictionary = {}

var _pose_dock := PoseDock.new()
var _pose_local := -1
var _pose_player: Player
var _hidden_layers: Array[CanvasLayer] = []

@onready var _pause_menu: PauseMenu = get_node_or_null("PauseMenu")
@onready var _actors: Node3D = get_node_or_null("Actors")
@onready var _help: LevelHelp = get_node_or_null("Help")


func _ready() -> void:
	participants = GameSession.participants(default_character)
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


#Reports the result: inside a session the results screen takes over, on its own it returns false. In a room the results come once
#everybody is done, and meanwhile this computer watches the others
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


#One Player per participant, each at its own point; the first one is the one this screen controls
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


#The player of this screen among the spawned ones: the one with the local id, or the first one alone
static func local_of(spawned: Array[Player]) -> Player:
	for player in spawned:
		if player.player_id == GameSession.local_id:
			return player
	return spawned[0] if not spawned.is_empty() else null


#A round draws its random things from here: the seed of the room (the same on every computer), a fixed one of its settings, or any
func seed_rng(generator: RandomNumberGenerator, fixed := 0) -> void:
	if fixed != 0:
		generator.seed = fixed
	elif GameSession.round_seed != 0:
		generator.seed = GameSession.round_seed
	else:
		generator.randomize()


#A player that can pose; "local" is the one of this screen, whose key and dock these are
func add_poser(player: Player, local: bool) -> void:
	everyone[player.player_id] = player
	poses.add(player)
	if local:
		_pose_local = player.player_id
		_pose_player = player


#The pose key of the player of this screen; a round may give the key another use first (the stations of the warm-up)
func press_pose() -> void:
	poses.toggle(_pose_local)


#Whether a player may pose right now: rounds say no before the start, after the end or while it falls
func _pose_allowed(_player_id: int) -> bool:
	return not paused


#Whether the dock shows at all: it hides while the round is paused or over
func _pose_shown() -> bool:
	return not paused and not filming and not spectating


func pose_state() -> int:
	if _pose_local < 0 or not _pose_shown():
		return PoseDock.State.HIDDEN
	if poses.is_posing(_pose_local):
		return PoseDock.State.POSING
	return PoseDock.State.READY if poses.can_pose(_pose_local) else PoseDock.State.BLOCKED


#The opening film of a minigame of the catalog: the round waits, its screens hide and Esc and F1 do nothing until the film lands on the
#camera of the player
func _open_film() -> void:
	var info := MinigameCatalog.find(ScreenFlow.current) if ScreenFlow.current != &"" else null
	var networked := GameSession.is_networked() and not GameSession.practice
	if networked:
		add_child(NetPuppets.new())
	if networked and info != null:
		#The art of the round covers the screen until every computer has loaded it; then the film starts on all of them at once
		filming = true
		var cover := LoadingCover.new()
		add_child(cover)
		cover.show_round(info, _step_text())
		await _wait_for_everybody()
		cover.lift()
	if not films_enabled or info == null or _pose_player == null or DisplayServer.get_name() == "headless":
		filming = false
		return
	var shots := _film_shots()
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


#In a room every computer waits here until the server lets all of them start the round together
func _wait_for_everybody() -> void:
	if not GameSession.is_networked() or GameSession.practice:
		return
	var net := GameSession.net
	var round_index := GameSession.round_index
	net.report_loaded(round_index)
	while net.is_active() and net.go_round < round_index:
		await get_tree().process_frame


#The shots of the opening film: by default the camera circles the whole playing field from high up and then comes down closer behind the
#player; a round may give its own
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


#The box around every floor and wall the players can touch
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


#The round freezes like in the pause menu while its help is open
func open_help() -> void:
	if filming or _help == null or _help.is_open() or not _help_allowed():
		return
	paused = true
	if _actors != null:
		_actors.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#Esc closes the help, it must not also open the pause menu behind it
	if _pause_menu != null:
		_pause_menu.set_process_unhandled_input(false)
	_help.open()


#Rounds that have a help say when it cannot be opened (before they start, after they end)
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


func _on_pause_opened() -> void:
	paused = true
	if _actors != null:
		_actors.process_mode = Node.PROCESS_MODE_DISABLED
	_paused_changed(true)


func _on_pause_closed() -> void:
	paused = false
	if _actors != null:
		_actors.process_mode = Node.PROCESS_MODE_INHERIT
	_paused_changed(false)
