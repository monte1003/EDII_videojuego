extends Node

#Keyboard and mouse or DualSense: the last one used rules hints, cursor and focus

enum Kind { KEYS, PAD }

signal changed(kind: Kind)
signal pad_plugged(connected: bool)

#Stick press and release thresholds; the gap stops a shaky stick pressing twice
const STICK_PRESS := 0.5
const STICK_RELEASE := 0.3
#Milliseconds in which a push to the other side is the stick swinging back
const STICK_SETTLE := 90
#Mouse moves under this many pixels are bumps, not the player
const MOUSE_WAKE := 3.0
#Screens that move their own selection with the arrows
const SELF_NAVIGATED: Array[StringName] = [&"character_select"]

var kind := Kind.KEYS
#Pad in use, or -1
var pad := -1

var _tilt: Dictionary = {}
var _let_go: Dictionary = {}
var _hid_cursor := false
var _notice := PadNotice.new()
#Pause opened when the pad went away, closed when it is back
var _pause_opened: PauseMenu
var _notice_scene: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_notice)
	Input.joy_connection_changed.connect(_on_joy_connection)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		pad = pads[0]
		kind = Kind.PAD


func uses_pad() -> bool:
	return kind == Kind.PAD


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) >= STICK_PRESS:
			_use(Kind.PAD, motion.device)
		if not _crossed(motion):
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		if event.is_pressed():
			_use(Kind.PAD, event.device)
	elif event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_use(Kind.KEYS, -1)
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).screen_relative.length() >= MOUSE_WAKE:
			_use(Kind.KEYS, -1)


#A stick counts as one press when it crosses its threshold, never on release
func _crossed(motion: InputEventJoypadMotion) -> bool:
	var key := motion.device * 16 + motion.axis
	var before: int = _tilt.get(key, 0)
	var now := before
	if absf(motion.axis_value) >= STICK_PRESS:
		now = 1 if motion.axis_value > 0.0 else -1
	elif absf(motion.axis_value) < STICK_RELEASE:
		now = 0
	if now == before:
		return false
	_tilt[key] = now
	var clock := Time.get_ticks_msec()
	if before != 0:
		_let_go[key] = [clock, before]
		if now == 0:
			return false
	var last: Array = _let_go.get(key, [])
	return last.is_empty() or int(last[1]) != -now or clock - int(last[0]) >= STICK_SETTLE


func _use(next: Kind, device: int) -> void:
	if device >= 0:
		pad = device
	if next == kind:
		return
	kind = next
	changed.emit(kind)


func _process(_delta: float) -> void:
	if _notice.is_showing() and get_tree().current_scene != _notice_scene:
		_notice.lift()
	if kind == Kind.PAD:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			_hid_cursor = true
		_give_focus()
	elif _hid_cursor:
		_hid_cursor = false
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


#A menu with nothing selected gets its first button
func _give_focus() -> void:
	var screen := get_tree().current_scene as Screen
	if screen == null or SELF_NAVIGATED.has(ScreenFlow.current) or get_viewport().gui_get_focus_owner() != null:
		return
	for node in screen.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return


func _on_joy_connection(device: int, connected: bool) -> void:
	if connected:
		pad = device
		_use(Kind.PAD, device)
		_notice.lift()
		if _pause_opened != null and is_instance_valid(_pause_opened) and _pause_opened.visible:
			_pause_opened.close()
		_pause_opened = null
	elif device == pad:
		var others := Input.get_connected_joypads()
		others.erase(device)
		pad = others[0] if not others.is_empty() else -1
		if pad < 0:
			var was_pad := kind == Kind.PAD
			_use(Kind.KEYS, -1)
			if was_pad:
				_lost_pad()
	pad_plugged.emit(connected)


#Pad lost: opens the pause inside a round and asks to plug it back
func _lost_pad() -> void:
	Rumble.stop()
	_notice_scene = get_tree().current_scene
	var round_scene := _notice_scene as RoundScene
	if round_scene == null:
		_notice.show_for(PadNotice.Context.MENU)
		return
	var pause := round_scene.get_node_or_null("PauseMenu") as PauseMenu
	if pause != null and not pause.visible and not round_scene.filming and not round_scene.spectating:
		pause.open()
		_pause_opened = pause
		pause.closed.connect(_on_pause_closed, CONNECT_ONE_SHOT)
	var in_room := GameSession.is_networked() and not GameSession.practice
	_notice.show_for(PadNotice.Context.ROOM if in_room else PadNotice.Context.ROUND)


func _on_pause_closed() -> void:
	_pause_opened = null
	_notice.lift()
