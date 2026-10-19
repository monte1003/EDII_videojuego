class_name InputHints
extends RefCounted

#Key names taken from the Input Map, so the texts follow any rebinding


static func key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			code = key.physical_keycode
			#The headless display server cannot translate a physical key to the user's layout
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return "ESPACIO" if code == KEY_SPACE else OS.get_keycode_string(code).to_upper()
	return "?"


#Colours a key name for RichTextLabel texts
static func markup(text: String) -> String:
	return "[color=#%s]%s[/color]" % [Palette.TEAL.to_html(false), text]


static func key_markup(action: StringName) -> String:
	return markup(key_label(action))
