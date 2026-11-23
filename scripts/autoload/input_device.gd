extends Node

#Which device the player of this computer is using: the keyboard and mouse or a game pad (a DualSense read straight through Godot's
#Input). The last one touched rules: it decides the hints on screen and whether the cursor shows. With the pad, menus get a focused
#button, a stick counts like a button (only when it crosses its threshold) and a pad that goes away in the middle of a round pauses it
#with a notice until it comes back

enum Kind { KEYS, PAD }

signal changed(kind: Kind)
#A pad was plugged in or pulled out
signal pad_plugged(connected: bool)

#How far a stick must tilt to count as a press, and how far back it must come to let go: the gap keeps a shaky stick from pressing twice
const STICK_PRESS := 0.5
const STICK_RELEASE := 0.3
#A mouse moved less than this (pixels in one event) is a bump of the desk, not a player taking the mouse
const MOUSE_WAKE := 3.0
#Screens that move their own selection with the arrows: no button gets the focus there
const SELF_NAVIGATED: Array[StringName] = [&"character_select"]

var kind := Kind.KEYS
#The pad in use, or -1 without one
var pad := -1

var _tilt: Dictionary = {}
var _hid_cursor := false
var _notice := PadNotice.new()
#The pause this computer opened when its pad went away, so it closes again when the pad is back
var _pause_opened: PauseMenu
#The screen where the notice showed: going to another screen takes it away
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


#Moving the stick is read every frame through the actions; as an event it only goes on when it crosses its threshold, like a button, so a
#menu or a list never jumps several places for one push
func _crossed(motion: InputEventJoypadMotion) -> bool:
	var key := motion.device * 16 + motion.axis
	var before: int = _tilt.get(key, 0)
	var now := before
	if absf(motion.axis_value) >= STICK_PRESS:
		now = 1 if motion.axis_value > 0.0 else -1
	elif absf(motion.axis_value) < STICK_RELEASE:
		now = 0
	_tilt[key] = now
	return now != before


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


#A menu with nothing selected gets its first button, so the d-pad always has something to move
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


#The pad of the player went away: inside a round its pause opens (in a room the others keep playing) and a notice asks to plug it back
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


#Closing the pause by hand (with the keyboard) also takes the notice away
func _on_pause_closed() -> void:
	_pause_opened = null
	_notice.lift()
