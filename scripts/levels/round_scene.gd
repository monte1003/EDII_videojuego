class_name RoundScene
extends Node3D

#What every round scene shares: who plays, how it ends, pause and help; it runs in a session or on its own

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

@export var default_character: CharacterData

var participants: Array[PlayerSlot] = []
var paused := false

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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help") and _help != null and not _help.is_open():
		open_help()
		get_viewport().set_input_as_handled()


#Reports the result: inside a session the results screen takes over, on its own it returns false
func finish_round(result: RoundResult) -> bool:
	return GameSession.report_result(result)


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
			player.set_character(slot.character)
		player.set_input_enabled(index == 0)
		spawned.append(player)
	return spawned


#The round freezes like in the pause menu while its help is open
func open_help() -> void:
	if _help == null or _help.is_open() or not _help_allowed():
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
