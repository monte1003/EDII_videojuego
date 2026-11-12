class_name InputHints
extends RefCounted

#Key names taken from the Input Map, so the texts follow any rebinding

const NAMES := {KEY_SPACE: "ESPACIO", KEY_SHIFT: "MAYÚS", KEY_ENTER: "ENTER", KEY_KP_ENTER: "ENTER"}


static func key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			code = key.physical_keycode
			#Headless mode cannot translate a physical key to the user's layout
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return NAMES.get(code, OS.get_keycode_string(code).to_upper())
	return "?"


#Colours a key name for RichTextLabel texts
static func markup(text: String) -> String:
	return "[color=#%s]%s[/color]" % [Palette.TEAL.to_html(false), text]


static func key_markup(action: StringName) -> String:
	return markup(key_label(action))


#The four movement keys in one word, as in "WASD"
static func move_label() -> String:
	return "".join([key_label(&"move_forward"), key_label(&"move_left"), key_label(&"move_back"), key_label(&"move_right")])


#The key of an entry like "jump|saltar"; "move" stands for the four movement keys
static func entry_label(action: String) -> String:
	return move_label() if action == "move" else key_label(StringName(action))


#The four movement keys together, as in "W A S D"
static func move_markup() -> String:
	return markup(" ".join([key_label(&"move_forward"), key_label(&"move_left"),
		key_label(&"move_back"), key_label(&"move_right")]))
