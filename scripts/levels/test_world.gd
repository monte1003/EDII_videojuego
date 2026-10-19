extends Node3D

enum Step { MOVE, CAMERA, JUMP, FINAL }

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

const MARK_RADIUS := 1.1
const EXIT_RADIUS := 1.3
const FALL_Y := -10.0
#About 40 degrees of accumulated camera turn before looking at the beacon counts
const MIN_CAMERA_TURN := 0.7
#About 14 degrees of tolerance, held for half a second
const LOOK_TOLERANCE := 0.25
const LOOK_HOLD := 0.5

#Used when the scene runs without going through character select
@export var default_character: CharacterData
#Screen opened by "Ir al nivel 1" and by "Omitir tutorial"; empty goes back to the menu
@export var next_screen: StringName = &""

var _player: Player
var _camera_rig: PlayerCamera
var _model_pivot: Node3D
var _step := Step.MOVE
var _step_started := true
var _finished := false
var _checkpoints: Array[Vector3] = []
var _camera_turn := 0.0
var _last_yaw := 0.0
var _look_time := 0.0
var _beacon_aligned := false

@onready var _spawn_point: Marker3D = $SpawnPoint
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _course: TutorialCourse = $Course
@onready var _hud: TutorialHud = $Hud


func _ready() -> void:
	var character := GameState.get_character(GameState.PLAYER_ONE)
	if character == null:
		character = default_character

	_player = PLAYER_SCENE.instantiate() as Player
	_player.player_id = GameState.PLAYER_ONE
	add_child(_player)
	_player.global_transform = _spawn_point.global_transform
	_player.set_character(character)
	_camera_rig = _player.get_node("CameraRig") as PlayerCamera
	_model_pivot = _player.get_node("ModelPivot") as Node3D

	#The course is sized from the controller's own numbers, never the other way around
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var air_time := 2.0 * _player.jump_velocity / gravity
	var jump_height := _player.jump_velocity * _player.jump_velocity / (2.0 * gravity)
	_course.build(jump_height, _player.move_speed * air_time)
	_checkpoints.append(_spawn_point.global_position)
	_checkpoints.append_array(_course.checkpoints)

	_pause_menu.opened.connect(_on_pause_opened)
	_pause_menu.closed.connect(_on_pause_closed)
	_hud.retry_requested.connect(_retry)
	_hud.skip_requested.connect(_leave)
	_hud.continue_requested.connect(_leave)
	_hud.menu_requested.connect(ScreenFlow.go_to_root)
	_hud.setup(Step.size())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_step(Step.MOVE)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	var feet := _player.global_position
	if feet.y < FALL_Y:
		_respawn()
		return
	if not _step_started:
		if feet.z <= _course.zone_enter_z[_step - 1]:
			_begin_step()
		return

	match _step:
		Step.MOVE:
			if _flat_distance(feet, _course.move_mark) < MARK_RADIUS:
				_complete_step("¡Bien! Ya sabes caminar")
		Step.CAMERA:
			_update_camera(delta)
		Step.JUMP:
			if _flat_distance(feet, _course.jump_mark) < MARK_RADIUS:
				_complete_step("¡Genial! Saltas muy bien")
		Step.FINAL:
			if _flat_distance(feet, _course.exit_mark) < EXIT_RADIUS:
				_finish()


func _start_step(step: Step) -> void:
	_step = step
	_step_started = step == Step.MOVE
	if _step_started:
		_begin_step()
	else:
		_hud.show_step(_step, "Sigue las flechas", "Cruza el camino hasta la siguiente zona.")


func _begin_step() -> void:
	_step_started = true
	_camera_turn = 0.0
	_last_yaw = _camera_rig.rotation.y
	_look_time = 0.0
	var text := _step_text(_step)
	_hud.show_step(_step, text[0], text[1])


func _step_text(step: Step) -> Array[String]:
	match step:
		Step.MOVE:
			var keys := " ".join([
				_key_label(&"move_forward"), _key_label(&"move_left"),
				_key_label(&"move_back"), _key_label(&"move_right")])
			return ["Muévete", "Camina hasta la marca cian con %s." % TutorialHud.key_markup(keys)]
		Step.CAMERA:
			return ["Mira a tu alrededor",
				"Mueve el %s hasta mirar la baliza magenta." % TutorialHud.key_markup("MOUSE")]
		Step.JUMP:
			return ["Salta",
				"Pulsa %s para pasar las barras y los huecos hasta la marca." % TutorialHud.key_markup(_key_label(&"jump"))]
		_:
			return ["Práctica final", "Combina todo y cruza el portal de salida."]


#Shows the key bound to an action in the Input Map, so it follows any rebinding
func _key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			code = key.physical_keycode
			#Shows the label of the player's own layout; the headless server cannot translate it
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
		var label := OS.get_keycode_string(code)
		return "ESPACIO" if code == KEY_SPACE else label.to_upper()
	return "?"


func _update_camera(delta: float) -> void:
	var yaw := _camera_rig.rotation.y
	_camera_turn += absf(angle_difference(_last_yaw, yaw))
	_last_yaw = yaw

	var to_beacon := _course.beacon_position - _player.global_position
	to_beacon.y = 0.0
	var forward := -_camera_rig.global_transform.basis.z
	forward.y = 0.0
	var aligned := _camera_turn >= MIN_CAMERA_TURN and forward.angle_to(to_beacon) <= LOOK_TOLERANCE
	if aligned != _beacon_aligned:
		_beacon_aligned = aligned
		_course.set_beacon_aligned(aligned)
	_look_time = _look_time + delta if aligned else 0.0
	if _look_time >= LOOK_HOLD:
		_complete_step("¡Perfecto! Ya controlas la cámara")


func _complete_step(message: String) -> void:
	_hud.toast(message)
	_course.open_gate(_step)
	_start_step((_step + 1) as Step)


func _finish() -> void:
	_finished = true
	_player.set_input_enabled(false)
	#A late Esc press must not open the pause menu over the final panel
	_pause_menu.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.show_finish(next_screen != &"" and ScreenFlow.tree.has(next_screen), "IR AL NIVEL 1")


#Moves the same player back: no new bodies, cameras or signal connections
func _respawn() -> void:
	_player.global_position = _checkpoints[_step]
	_player.velocity = Vector3.ZERO
	_player.move_input = Vector2.ZERO
	_player.jump_requested = false
	_camera_rig.rotation.y = 0.0
	_model_pivot.rotation.y = PI
	_camera_turn = 0.0
	_last_yaw = 0.0
	_look_time = 0.0
	_hud.toast("Sin problema, ¡inténtalo otra vez!")


func _retry() -> void:
	get_tree().reload_current_scene()


func _leave() -> void:
	if next_screen != &"" and ScreenFlow.tree.has(next_screen):
		ScreenFlow.open(next_screen)
	else:
		ScreenFlow.go_to_root()


func _on_pause_opened() -> void:
	_player.set_input_enabled(false)
	_hud.show_pause_actions(true)


func _on_pause_closed() -> void:
	_player.set_input_enabled(true)
	_hud.show_pause_actions(false)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
