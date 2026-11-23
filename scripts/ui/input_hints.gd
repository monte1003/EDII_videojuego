class_name InputHints
extends RefCounted

#Key names taken from the Input Map, so the texts follow any rebinding; with the pad in use, the DualSense buttons instead

const NAMES := {KEY_SPACE: "ESPACIO", KEY_SHIFT: "SHIFT", KEY_ENTER: "ENTER", KEY_KP_ENTER: "ENTER"}
#The pad button of each action: a drawn shape (with the side a stick or the d-pad points to) or the word printed on the pad
const PAD := {
	&"jump": {"shape": "cross"}, &"menu_confirm": {"shape": "cross"},
	&"interact": {"shape": "circle"}, &"menu_back": {"shape": "circle"},
	&"shove": {"shape": "square"}, &"help": {"shape": "triangle"},
	&"pause": {"text": "OPTIONS"}, &"ready": {"text": "R1"},
	&"move": {"shape": "stick_l"}, &"move_left": {"shape": "stick_l", "side": Vector2.LEFT},
	&"move_right": {"shape": "stick_l", "side": Vector2.RIGHT}, &"move_forward": {"shape": "stick_l"}, &"move_back": {"shape": "stick_l"},
	&"look": {"shape": "stick_r"},
	&"menu_left": {"shape": "dpad", "side": Vector2.LEFT}, &"menu_right": {"shape": "dpad", "side": Vector2.RIGHT},
	&"menu_up": {"shape": "dpad", "side": Vector2.UP}, &"menu_down": {"shape": "dpad", "side": Vector2.DOWN},
}
#How a pad button is said in a text
const PAD_NAMES := {"cross": "CRUZ", "circle": "CÍRCULO", "square": "CUADRADO", "triangle": "TRIÁNGULO", "stick_l": "STICK IZQUIERDO",
	"stick_r": "STICK DERECHO", "dpad": "CRUCETA"}
const CONFIRM_KEY: Texture2D = preload("res://assets/ui/icons/key_enter.svg")
const CONFIRM_PAD: Texture2D = preload("res://assets/ui/icons/pad_cross.svg")
const BACK_KEY: Texture2D = preload("res://assets/ui/icons/key_e.svg")
const BACK_PAD: Texture2D = preload("res://assets/ui/icons/pad_circle.svg")


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


#Whether the hints show the pad right now
static func uses_pad() -> bool:
	return InputDevice.uses_pad()


#The pad button of an action, or empty when the action has none (then the key shows even with the pad)
static func pad_of(action: StringName) -> Dictionary:
	return PAD.get(action, {})


#The name of an action's key or pad button, for a text
static func spoken(action: StringName) -> String:
	var button := pad_of(action)
	if uses_pad() and not button.is_empty():
		return button.get("text", PAD_NAMES.get(button.get("shape", ""), "?"))
	if action == &"move":
		return " ".join([key_label(&"move_forward"), key_label(&"move_left"), key_label(&"move_back"), key_label(&"move_right")])
	if action == &"look":
		return "MOUSE"
	return key_label(action)


#Colours a key name for RichTextLabel texts
static func markup(text: String) -> String:
	return "[color=#%s]%s[/color]" % [Palette.TEAL.to_html(false), text]


#Help texts keep a mark for each key ({key:jump}) and fill it in when they show, so they follow the device in use
static func key_markup(action: StringName) -> String:
	return markup("{key:%s}" % action)


#The four movement keys in one word, as in "WASD"
static func move_label() -> String:
	return "".join([key_label(&"move_forward"), key_label(&"move_left"), key_label(&"move_back"), key_label(&"move_right")])


#The key of an entry like "jump|saltar"; "move" stands for the four movement keys
static func entry_label(action: String) -> String:
	return move_label() if action == "move" else key_label(StringName(action))


#The four movement keys together, as in "W A S D"
static func move_markup() -> String:
	return markup("{key:move}")


#What turns the camera: the mouse, or the right stick
static func look_markup() -> String:
	return markup("{key:look}")


#A help text with its key marks filled in for the device in use
static func resolve(text: String) -> String:
	var marks := RegEx.create_from_string("\\{key:([a-z_]+)\\}")
	var done := text
	for found in marks.search_all(text):
		done = done.replace(found.get_string(), spoken(StringName(found.get_string(1))))
	return done


#The icon of the confirm key on a button: the Enter key, or the cross of the pad
static func confirm_icon() -> Texture2D:
	return CONFIRM_PAD if uses_pad() else CONFIRM_KEY


#The icon of the back key on a button: E, or the circle of the pad
static func back_icon() -> Texture2D:
	return BACK_PAD if uses_pad() else BACK_KEY
