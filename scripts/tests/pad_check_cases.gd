extends RefCounted

#The cases of pad_check.gd. They live apart because the game's autoloads (InputDevice, Rumble, GameSession) only exist once the
#test is running: a script passed with --script is compiled before them

#The keys of every action before the pad, as physical key codes: they must not change
const KEYS := {
	&"move_forward": [87], &"move_back": [83], &"move_left": [65], &"move_right": [68], &"jump": [32], &"help": [4194332],
	&"interact": [69], &"toggle_debug": [4194334], &"demo_route": [4194335], &"pause": [4194305], &"menu_left": [4194319],
	&"menu_right": [4194321], &"menu_up": [4194320], &"menu_down": [4194322], &"menu_confirm": [4194309, 4194310, 32],
	&"menu_back": [4194308, 69], &"ready": [4194309, 4194310], &"shove": [4194325], &"pick_prev": [65], &"pick_next": [68],
}
#The button of each action on the pad (decided on 21/11/2026; R1 for "ready" on 22/11)
const BUTTONS := {
	&"jump": JOY_BUTTON_A, &"menu_confirm": JOY_BUTTON_A, &"shove": JOY_BUTTON_X, &"interact": JOY_BUTTON_B, &"menu_back": JOY_BUTTON_B,
	&"help": JOY_BUTTON_Y, &"pause": JOY_BUTTON_START, &"ready": JOY_BUTTON_RIGHT_SHOULDER, &"menu_left": JOY_BUTTON_DPAD_LEFT,
	&"menu_right": JOY_BUTTON_DPAD_RIGHT, &"menu_up": JOY_BUTTON_DPAD_UP, &"menu_down": JOY_BUTTON_DPAD_DOWN, &"ui_accept": JOY_BUTTON_A,
	&"pick_prev": JOY_BUTTON_LEFT_SHOULDER, &"pick_next": JOY_BUTTON_RIGHT_SHOULDER,
}
const STICKS := {
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0], &"move_back": [JOY_AXIS_LEFT_Y, 1.0], &"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0], &"look_left": [JOY_AXIS_RIGHT_X, -1.0], &"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	&"look_up": [JOY_AXIS_RIGHT_Y, -1.0], &"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
}
const PAD_ID := 0

var tree: SceneTree
var root: Window
var _failures := 0
var _device: Node
var _rumble: Node
var _changes := 0


func _check(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await tree.process_frame


func _button(index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = PAD_ID
	event.button_index = index
	event.pressed = pressed
	return event


func _stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = PAD_ID
	event.axis = axis
	event.axis_value = value
	return event


func _key(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


func _tap_key() -> void:
	await _send(_key(KEY_F12))
	await _send(_key(KEY_F12, false))


func _tap_pad() -> void:
	await _send(_button(JOY_BUTTON_LEFT_STICK, true))
	await _send(_button(JOY_BUTTON_LEFT_STICK, false))


func _uses_pad() -> bool:
	return bool(_device.call("uses_pad"))


func _strength() -> Vector2:
	return Input.get_joy_vibration_strength(PAD_ID)


#Runs every check over the tree of the test and gives back how many failed
func run(test_tree: SceneTree) -> int:
	tree = test_tree
	root = tree.root
	_device = root.get_node("InputDevice")
	_rumble = root.get_node("Rumble")
	_device.connect(&"changed", func(_kind: int) -> void: _changes += 1)
	_check_map()
	await _check_device()
	await _check_stick()
	_check_hints()
	await _check_rumble()
	await _check_focus()
	await _check_main_menu()
	await _check_lobby_ready()
	await _check_name_keyboard()
	await _check_round_unplug()
	await _check_arena_shove()
	return _failures


#Every action keeps exactly the keys it had and gains its pad button or stick; the debug keys stay keyboard only
func _check_map() -> void:
	for action: StringName in KEYS:
		var codes: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				codes.append((event as InputEventKey).physical_keycode)
		_check(codes == KEYS[action], "%s conserva sus teclas %s" % [action, KEYS[action]])
	for action: StringName in BUTTONS:
		var found := false
		for event in InputMap.action_get_events(action):
			found = found or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == BUTTONS[action])
		_check(found, "%s tiene el botón %d del mando" % [action, BUTTONS[action]])
	for action: StringName in STICKS:
		var found := false
		for event in InputMap.action_get_events(action):
			var motion := event as InputEventJoypadMotion
			found = found or (motion != null and motion.axis == STICKS[action][0] and signf(motion.axis_value) == STICKS[action][1])
		_check(found, "%s lee el eje %d hacia %+d" % [action, STICKS[action][0], int(STICKS[action][1])])
	for action: StringName in [&"toggle_debug", &"demo_route"]:
		var pad_events := InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool: return not event is InputEventKey)
		_check(pad_events.is_empty(), "%s sigue siendo solo de teclado" % action)
	for action: StringName in [&"ui_left", &"ui_right"]:
		var axes := InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion)
		_check(not axes.is_empty(), "%s mueve la selección también con el stick, como trae Godot" % action)


#The active device: keyboard without a pad, the pad once it is plugged or touched, back to the keyboard with a key or a real mouse move
func _check_device() -> void:
	_check(not _uses_pad() and int(_device.get("pad")) == -1, "sin mando, el dispositivo activo es el teclado")
	_changes = 0
	Input.joy_connection_changed.emit(PAD_ID, true)
	_check(_uses_pad() and int(_device.get("pad")) == PAD_ID and _changes == 1, "al conectar un mando pasa a mando, una sola vez")
	await _tap_key()
	_check(not _uses_pad(), "una tecla devuelve el teclado")
	await _tap_pad()
	_check(_uses_pad(), "un botón del mando lo vuelve a activar")
	var bump := InputEventMouseMotion.new()
	bump.relative = Vector2(1.0, 1.0)
	bump.screen_relative = Vector2(1.0, 1.0)
	await _send(bump)
	_check(_uses_pad(), "un roce del mouse (1 px) no le quita el mando")
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(14.0, 6.0)
	move.screen_relative = Vector2(14.0, 6.0)
	await _send(move)
	_check(not _uses_pad(), "mover de verdad el mouse devuelve el teclado")
	await _send(_stick(JOY_AXIS_LEFT_X, 0.2))
	_check(not _uses_pad(), "un stick apenas tocado (0,2) no cambia nada")
	await _send(_stick(JOY_AXIS_LEFT_X, 0.8))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.0))
	_check(_uses_pad(), "inclinar el stick activa el mando")


class Counter:
	extends Node
	var presses := 0
	var back_presses := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("move_right"):
			presses += 1
		if event.is_action_pressed("move_left"):
			back_presses += 1


#A stick held to one side is one press for the menus, while the movement still reads its tilt every frame
func _check_stick() -> void:
	var counter := Counter.new()
	root.add_child(counter)
	for value in [0.6, 0.7, 0.85, 0.95, 1.0, 0.9]:
		await _send(_stick(JOY_AXIS_LEFT_X, value))
	_check(counter.presses == 1, "seis movimientos del stick inclinado cuentan una sola pulsación (contó %d)" % counter.presses)
	_check(Input.get_action_strength("move_right") > 0.8, "el movimiento sigue leyendo el stick inclinado (%.2f)" % Input.get_action_strength("move_right"))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.4))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.7))
	_check(counter.presses == 1, "volver a 0,4 no suelta el stick (no cuenta dos veces por temblor)")
	await _send(_stick(JOY_AXIS_LEFT_X, 0.1))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.8))
	_check(counter.presses == 2, "soltarlo y volver a empujarlo es otra pulsación")
	for value in [0.6, 0.28, 0.24, 0.0]:
		await _send(_stick(JOY_AXIS_LEFT_X, value))
	_check(counter.presses == 2, "al soltarlo pasa por 0,28 y 0,24 (sobre la zona muerta) y no cuenta como otro empujón")
	await _send(_stick(JOY_AXIS_LEFT_X, 0.9))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.0))
	await _send(_stick(JOY_AXIS_LEFT_X, -0.6))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.0))
	_check(counter.presses == 3 and counter.back_presses == 0, "el rebote al otro lado justo al soltarlo no cuenta (%d a la izquierda)" % counter.back_presses)
	OS.delay_msec(120)
	await _send(_stick(JOY_AXIS_LEFT_X, -0.8))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.0))
	_check(counter.back_presses == 1, "un empujón de verdad a la izquierda sí cuenta")
	counter.queue_free()
	var column := VBoxContainer.new()
	root.add_child(column)
	var buttons: Array[Button] = []
	for index in 4:
		var button := Button.new()
		button.text = str(index)
		column.add_child(button)
		buttons.append(button)
	await tree.process_frame
	buttons[0].grab_focus()
	for value in [0.6, 0.75, 0.9, 1.0]:
		await _send(_stick(JOY_AXIS_LEFT_Y, value))
	_check(root.gui_get_focus_owner() == buttons[1], "en un menú, el stick abajo baja un solo botón")
	await _send(_stick(JOY_AXIS_LEFT_Y, 0.0))
	await _send(_button(JOY_BUTTON_DPAD_DOWN, true))
	await _send(_button(JOY_BUTTON_DPAD_DOWN, false))
	_check(root.gui_get_focus_owner() == buttons[2], "la cruceta también baja de a uno")
	var pressed := [false]
	buttons[2].pressed.connect(func() -> void: pressed[0] = true)
	await _send(_button(JOY_BUTTON_A, true))
	await _send(_button(JOY_BUTTON_A, false))
	_check(pressed[0], "Cruz pulsa el botón con foco")
	column.queue_free()
	await tree.process_frame


#The hints: the same key caps on the keyboard, the DualSense buttons with the pad, the debug keys always as keys
func _check_hints() -> void:
	_device.call("_use", 0, -1)
	var old := UiKit.key_chip(InputHints.key_label(&"jump"), 16)
	var chip := UiKit.action_chip(&"jump", 16)
	var old_label := old.get_child(0) as Label
	var new_label := chip.get_child(0) as Label
	_check(new_label != null and new_label.text == old_label.text and new_label.get_theme_font_size("font_size") == 16,
		"con teclado la pista es la misma tecla de antes (%s)" % old_label.text)
	var old_style := old.get_theme_stylebox("panel") as StyleBoxFlat
	var new_style := chip.get_theme_stylebox("panel") as StyleBoxFlat
	_check(old_style.bg_color == new_style.bg_color and old_style.border_color == new_style.border_color and old_style.border_width_bottom == new_style.border_width_bottom,
		"y con la misma tapa")
	var double := UiKit.entry_chip("jump=ESPACIO ×2", 16)
	var plain := UiKit.entry_chip("ESPACIO", 16)
	_check(((double.get_child(0) as Label).text == "ESPACIO ×2") and plain is PanelContainer and not plain is HintChip, "una línea de misión con acción y una tecla suelta")
	_check(InputHints.resolve(InputHints.key_markup(&"jump")).contains("ESPACIO") and InputHints.resolve(InputHints.look_markup()).contains("MOUSE"),
		"la ayuda dice ESPACIO y MOUSE con teclado")
	_check(InputHints.confirm_icon() == InputHints.CONFIRM_KEY and InputHints.back_icon() == InputHints.BACK_KEY, "los botones llevan Enter y E con teclado")
	_device.call("_use", 1, PAD_ID)
	var glyph := chip.get_child(0).get_child(0) as PadGlyph
	_check(glyph != null and glyph.shape == "cross", "con el mando la misma pista cambia sola a la Cruz")
	_check(chip.get_theme_stylebox("panel") is StyleBoxEmpty, "y deja la tapa de tecla: el botón se dibuja como en el mando")
	_check((double.get_child(0).get_child(1) as Label).text == "×2", "el barrido muestra la Cruz y ×2")
	var ready := UiKit.action_chip(&"ready", 16)
	_check((ready.get_child(0).get_child(0).get_child(0) as Label).text == "R1", "listo es R1, en una píldora oscura")
	var options := UiKit.action_chip(&"pause", 16)
	_check((options.get_child(0).get_child(0).get_child(0) as Label).text == "OPTIONS", "la pausa es Options")
	var debug := UiKit.action_chip(&"toggle_debug", 16)
	_check((debug.get_child(0) as Label).text == "F3", "F3 sigue siendo F3 con el mando")
	var picker := UiKit.action_chip(&"move_left", 14)
	var side := picker.get_child(0).get_child(0) as PadGlyph
	_check(side.shape == "stick_l" and side.side == Vector2.LEFT, "en la sala, el stick izquierdo con su flecha")
	_check(InputHints.resolve(InputHints.key_markup(&"shove")).contains("CUADRADO") and InputHints.resolve(InputHints.look_markup()).contains("STICK DERECHO"),
		"la ayuda dice CUADRADO y STICK DERECHO con el mando")
	_check(InputHints.confirm_icon() == InputHints.CONFIRM_PAD and InputHints.back_icon() == InputHints.BACK_PAD, "los botones llevan la Cruz y el Círculo con el mando")
	for node: Node in [old, chip, double, plain, ready, options, debug, picker]:
		node.free()


#The table plays on the pad in use, a weaker effect does not cut a stronger one, stop clears it, and nothing plays on the keyboard
func _check_rumble() -> void:
	_rumble.call("stop")
	_rumble.call("play", &"hit")
	var hit: Dictionary = _rumble.get("EFFECTS")[&"hit"]
	_check(_strength().is_equal_approx(Vector2(hit["weak"], hit["strong"])), "el golpe pide %.2f y %.2f a los motores" % [hit["weak"], hit["strong"]])
	_rumble.call("play", &"bump")
	_check(_strength().is_equal_approx(Vector2(hit["weak"], hit["strong"])), "un choque suave no corta un golpe que sigue")
	_rumble.call("stop")
	_check(_strength() == Vector2.ZERO, "detener apaga los motores")
	await _tap_key()
	_rumble.call("play", &"hit")
	_check(_strength() == Vector2.ZERO, "con el teclado en uso el mando no vibra")
	_rumble.call("play", &"hit", true)
	_check(_strength() != Vector2.ZERO, "la pantalla de prueba sí lo hace vibrar")
	_rumble.call("stop")
	await _tap_pad()


#With the pad, a menu that selects nothing gets its first button; the character select moves its own selection
func _check_focus() -> void:
	var options := (load("res://scenes/menus/options_menu.tscn") as PackedScene).instantiate()
	root.add_child(options)
	tree.current_scene = options
	for frame in 3:
		await tree.process_frame
	_check(root.gui_get_focus_owner() is BaseButton, "Opciones con el mando: un botón queda seleccionado")
	await _tap_key()
	root.gui_release_focus()
	for frame in 3:
		await tree.process_frame
	_check(root.gui_get_focus_owner() == null, "con el teclado no se elige nada solo (como antes)")
	options.queue_free()
	await _tap_pad()
	var select := (load("res://scenes/menus/character_select.tscn") as PackedScene).instantiate()
	root.add_child(select)
	tree.current_scene = select
	root.get_node("ScreenFlow").set("current", &"character_select")
	for frame in 3:
		await tree.process_frame
	_check(root.gui_get_focus_owner() == null, "la selección de personaje no recibe foco (mueve su propia selección)")
	select.queue_free()
	await tree.process_frame


#The main menu: the stick reaches every button, SALIR included (it is to the right of OPCIONES)
func _check_main_menu() -> void:
	var menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	tree.current_scene = menu
	for frame in 5:
		await tree.process_frame
	(menu.get_node("%OptionsButton") as Control).grab_focus()
	await _send(_stick(JOY_AXIS_LEFT_X, 0.9))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.0))
	var owner := root.gui_get_focus_owner()
	_check(owner == menu.get_node("%ExitButton"), "en el menú principal el stick a la derecha llega a SALIR (%s)" % (owner.name if owner != null else "nada"))
	#A person takes longer than the swing of a stick let go; with --fixed-fps a timer of the game would not wait real time
	OS.delay_msec(120)
	await _send(_stick(JOY_AXIS_LEFT_X, -0.9))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.0))
	owner = root.gui_get_focus_owner()
	_check(owner == menu.get_node("%OptionsButton"), "y a la izquierda vuelve a OPCIONES (%s)" % (owner.name if owner != null else "nada"))
	menu.queue_free()
	await tree.process_frame


#"Listo" selected in the lobby: one press of Enter or of the cross marks it once (it used to mark on the press and unmark on the release)
func _check_lobby_ready() -> void:
	var session := root.get_node("GameSession")
	root.get_node("GameState").call("select_character", 1, load("res://resources/characters/fire.tres"))
	var lobby := (load("res://scenes/menus/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	tree.current_scene = lobby
	await tree.create_timer(0.8).timeout
	var events: Array[InputEvent] = []
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	events.append(enter)
	events.append(_button(JOY_BUTTON_A, true))
	for event in events:
		session.get("lobby").call("set_ready", 1, false)
		event.set("pressed", true)
		await _send(event)
		var release: InputEvent = event.duplicate()
		release.set("pressed", false)
		await _send(release)
		_check(bool(session.get("lobby").call("all_ready")), "en la sala, %s sobre Listo lo marca una sola vez" % ("Enter" if event is InputEventKey else "la Cruz"))
	session.get("lobby").call("set_ready", 1, false)
	var back := lobby.find_children("*", "TextButton", true, false).filter(func(node: Node) -> bool: return str(node.get("text")) == "Atrás")
	(back[0] as Control).grab_focus()
	await _send(_button(JOY_BUTTON_A, true))
	_check(not bool(session.get("lobby").call("all_ready")), "la Cruz sobre ATRÁS no marca Listo antes de volver (pasaba al pulsarla)")
	root.gui_release_focus()
	await _send(_button(JOY_BUTTON_A, false))
	var picked := func() -> StringName: return (session.get("lobby").call("find", 1) as PlayerSlot).character.id
	var first: StringName = picked.call()
	(lobby.get("_ready_button") as Control).grab_focus()
	await _send(_stick(JOY_AXIS_LEFT_X, 0.9))
	await _send(_stick(JOY_AXIS_LEFT_X, 0.0))
	_check(picked.call() == first, "en la sala el stick ya no cambia de personaje (mueve la selección de botones)")
	await _send(_button(JOY_BUTTON_RIGHT_SHOULDER, true))
	await _send(_button(JOY_BUTTON_RIGHT_SHOULDER, false))
	var second: StringName = picked.call()
	await _send(_button(JOY_BUTTON_RIGHT_SHOULDER, true))
	await _send(_button(JOY_BUTTON_RIGHT_SHOULDER, false))
	var ids: Array[StringName] = [&"fire", &"water", &"plant", &"lightning"]
	_check(ids.find(second) == posmod(ids.find(first) + 1, 4) and ids.find(picked.call()) == posmod(ids.find(first) + 2, 4),
		"R1 pasa al siguiente personaje de a uno: %s, %s, %s" % [first, second, picked.call()])
	await _send(_button(JOY_BUTTON_LEFT_SHOULDER, true))
	await _send(_button(JOY_BUTTON_LEFT_SHOULDER, false))
	_check(picked.call() == second, "L1 vuelve al anterior")
	(lobby.get("_name_field") as Control).grab_focus()
	await _send(_button(JOY_BUTTON_LEFT_SHOULDER, true))
	await _send(_button(JOY_BUTTON_LEFT_SHOULDER, false))
	_check(picked.call() == first, "L1 y R1 también funcionan con el nombre seleccionado")
	lobby.queue_free()
	await tree.process_frame


#The keyboard on screen: the cross on the name field opens it, the cross writes the selected key, square deletes, triangle adds a space,
#Options accepts and circle goes back; a real keyboard also types in it and the selection never leaves its keys
func _check_name_keyboard() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("set_player_name", 1, "ANA")
	var lobby := (load("res://scenes/menus/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	tree.current_scene = lobby
	await tree.create_timer(0.8).timeout
	var field := lobby.get("_name_field") as LineEdit
	var keyboard := lobby.get("_keyboard") as NameKeyboard
	field.grab_focus()
	await _send(_button(JOY_BUTTON_A, true))
	await _send(_button(JOY_BUTTON_A, false))
	_check(keyboard.is_open(), "la Cruz sobre el nombre abre el teclado en pantalla")
	var owner := root.gui_get_focus_owner() as Button
	_check(owner != null and owner.text == "Q", "empieza en la Q")
	await _send(_button(JOY_BUTTON_A, true))
	await _send(_button(JOY_BUTTON_A, false))
	await _send(_button(JOY_BUTTON_Y, true))
	await _send(_button(JOY_BUTTON_Y, false))
	var shown := keyboard.get("_text") as String
	_check(shown == "ANAQ ", "la Cruz escribe la Q y Triángulo pone un espacio (%s)" % shown)
	await _send(_button(JOY_BUTTON_X, true))
	await _send(_button(JOY_BUTTON_X, false))
	await _send(_button(JOY_BUTTON_DPAD_LEFT, true))
	await _send(_button(JOY_BUTTON_DPAD_LEFT, false))
	owner = root.gui_get_focus_owner() as Button
	_check(keyboard.get("_text") == "ANAQ" and owner != null and owner.text == "P", "Cuadrado borra y la cruceta da la vuelta en la fila (de la Q a la P)")
	for letter in "ñ1":
		var key := InputEventKey.new()
		key.unicode = letter.unicode_at(0)
		key.keycode = KEY_A
		key.pressed = true
		await _send(key)
	_check(keyboard.get("_text") == "ANAQÑ1", "un teclado de verdad también escribe (%s)" % keyboard.get("_text"))
	await _send(_button(JOY_BUTTON_START, true))
	await _send(_button(JOY_BUTTON_START, false))
	_check(not keyboard.is_open() and field.text == "ANAQÑ1" and str(game_state.call("get_player_name", 1)) == "ANAQÑ1",
		"Options acepta: el nombre queda en el campo y en la sala")
	_check(root.gui_get_focus_owner() == field, "y la selección vuelve al nombre")
	await _send(_button(JOY_BUTTON_A, true))
	await _send(_button(JOY_BUTTON_A, false))
	for step in 3:
		await _send(_button(JOY_BUTTON_X, true))
		await _send(_button(JOY_BUTTON_X, false))
	await _send(_button(JOY_BUTTON_B, true))
	await _send(_button(JOY_BUTTON_B, false))
	_check(not keyboard.is_open() and field.text == "ANAQÑ1", "Círculo cierra sin cambiar el nombre")
	_check(lobby.is_inside_tree() and tree.current_scene == lobby, "y no saca de la sala")
	game_state.call("set_player_name", 1, "")
	lobby.queue_free()
	await tree.process_frame


#A pad pulled out in the middle of a round: the pause opens with the notice, the round waits, and both go away when it comes back
func _check_round_unplug() -> void:
	var round_scene := (load("res://scenes/levels/warmup.tscn") as PackedScene).instantiate() as RoundScene
	root.add_child(round_scene)
	tree.current_scene = round_scene
	for frame in 10:
		await tree.process_frame
	var pause := round_scene.get_node("PauseMenu") as PauseMenu
	var mine := round_scene.screen_player()
	_check(mine != null, "la ronda entrega su jugador de pantalla")
	var hit := Player.Hit.new()
	hit.push = Vector3(3.0, 1.0, 0.0)
	hit.stun = 0.3
	hit.strength = 0.5
	mine.take_hit(hit)
	_check(_strength() != Vector2.ZERO, "un golpe al jugador de la pantalla hace vibrar")
	_rumble.call("stop")
	round_scene.iris.close()
	var fall: Dictionary = _rumble.get("EFFECTS")[&"fall"]
	_check(_strength().is_equal_approx(Vector2(fall["weak"], fall["strong"])), "caerse (el iris que se cierra) hace vibrar")
	round_scene.iris.open(0.01, 0.0)
	_rumble.call("stop")
	var huds := round_scene.find_children("*", "RoundHud", true, false)
	if not huds.is_empty():
		(huds[0] as RoundHud).show_go()
		var go: Dictionary = _rumble.get("EFFECTS")[&"go"]
		_check(_strength().is_equal_approx(Vector2(go["weak"], go["strong"])), "el YA de la cuenta atrás hace vibrar")
	_rumble.call("play", &"hit")
	Input.joy_connection_changed.emit(PAD_ID, false)
	await tree.process_frame
	var notice := _device.get("_notice") as PadNotice
	_check(pause.visible and round_scene.paused, "al desconectar el mando a mitad de ronda se abre la pausa y la ronda espera")
	_check(notice.is_showing(), "y sale el aviso de mando desconectado")
	_check(_strength() == Vector2.ZERO and not _uses_pad(), "la vibración se detiene y las pistas pasan al teclado")
	_rumble.call("play", &"hit", true)
	_check(_strength() == Vector2.ZERO, "sin mando no hay a quién hacer vibrar, ni siquiera desde la prueba")
	Input.joy_connection_changed.emit(PAD_ID, true)
	for frame in 20:
		await tree.process_frame
	_check(not pause.visible and not round_scene.paused, "al volver el mando la pausa se cierra y la ronda sigue")
	_check(not notice.is_showing() and _uses_pad(), "el aviso se va y vuelve el mando")
	_rumble.call("play", &"hit")
	_check(_strength() != Vector2.ZERO, "y vuelve a vibrar")
	_rumble.call("stop")
	pause.open()
	_rumble.call("play", &"hit")
	_check(_strength() == Vector2.ZERO, "con la pausa abierta no vibra")
	pause.close()
	Input.joy_connection_changed.emit(PAD_ID, false)
	await tree.process_frame
	pause.close()
	for frame in 20:
		await tree.process_frame
	_check(not notice.is_showing(), "cerrar la pausa con el teclado también quita el aviso")
	Input.joy_connection_changed.emit(PAD_ID, true)
	round_scene.queue_free()
	await tree.process_frame


#The shoves of the arenas: the player of the screen feels its own, not the others'
func _check_arena_shove() -> void:
	var arena := (load("res://scenes/levels/trend_war.tscn") as PackedScene).instantiate() as ArenaRound
	root.add_child(arena)
	tree.current_scene = arena
	for frame in 10:
		await tree.process_frame
	var mine := arena.screen_player()
	_rumble.call("stop")
	arena.shove_thrown.emit(mine.player_id + 7, true)
	_check(_strength() == Vector2.ZERO, "el empujón de otro jugador no hace vibrar este mando")
	arena.shove_thrown.emit(mine.player_id, true)
	var shove: Dictionary = _rumble.get("EFFECTS")[&"shove_hit"]
	_check(_strength().is_equal_approx(Vector2(shove["weak"], shove["strong"])), "el empujón propio que acierta hace vibrar")
	_rumble.call("stop")
	arena.queue_free()
	await tree.process_frame
