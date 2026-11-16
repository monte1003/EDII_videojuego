class_name NetPanel
extends VBoxContainer

#The room on the local network, at the bottom left of the lobby: one line that says how this computer plays (alone, with its room open
#and the address the others must use, or inside the room of another) and the links to open a room, join one or leave it. Joining opens a
#list of the rooms found on the network and a field for the address of the server, checked before trying

var _status: Label
var _open_link: TextButton
var _join_link: TextButton
var _leave_link: TextButton
var _picker: CanvasLayer
var _list: VBoxContainer
var _address: LineEdit
var _note: Label


#The character this computer picked, as the room names it
static func local_character() -> StringName:
	var character := GameState.get_character(GameState.PLAYER_ONE)
	return character.id if character != null else &"fire"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	_status = UiKit.label("", UiKit.BODY_FONT, 17, Palette.INK_SOFT)
	add_child(_status)
	var links := HBoxContainer.new()
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.add_theme_constant_override("separation", 18)
	add_child(links)
	_open_link = _link(links, "Crear sala", Palette.TEAL, _open_room)
	_join_link = _link(links, "Unirse a una sala", Palette.CORAL, _show_picker)
	_leave_link = _link(links, "Salir de la sala", Palette.INK_SOFT, _leave)
	_build_picker()
	var net := GameSession.net
	net.room_changed.connect(_refresh)
	net.joined.connect(_refresh)
	net.left.connect(func(_reason: String) -> void: _refresh())
	net.rooms_found.connect(_fill_rooms)
	_refresh()


func is_picking() -> bool:
	return _picker.visible


#A short message in the line of the room
func say(text: String) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Palette.CORAL)


func _refresh() -> void:
	var net := GameSession.net
	_status.add_theme_color_override("font_color", Palette.INK_SOFT)
	_open_link.visible = not net.is_active()
	_join_link.visible = not net.is_active()
	_leave_link.visible = net.is_active()
	if net.is_host():
		var addresses := net.local_addresses()
		_status.text = "Sala abierta · IP %s · %d/%d" % [" · ".join(addresses) if not addresses.is_empty() else "sin red", net.room.size(), NetRoom.CAPACITY]
	elif net.is_active():
		_status.text = "En la sala de %s" % (str(net.room[0]["name"]) if not net.room.is_empty() else "...")
	else:
		_status.text = "Jugando en este equipo"


func _open_room() -> void:
	if not GameSession.net.host(GameState.get_player_name(GameState.PLAYER_ONE), local_character()):
		say("No se pudo abrir la sala: el puerto %d está ocupado" % NetProtocol.PORT)


func _leave() -> void:
	GameSession.net.close()
	GameSession.prepare_lobby()
	_refresh()


func _show_picker() -> void:
	_picker.visible = true
	_note.text = "Buscando salas en la red..."
	GameSession.net.browse()
	_fill_rooms()
	_address.grab_focus()


func _hide_picker() -> void:
	_picker.visible = false
	GameSession.net.stop_browsing()


func _connect_to(address: String) -> void:
	var clean := address.strip_edges()
	if not clean.is_valid_ip_address():
		_note.text = "Esa no es una dirección IP (ejemplo: 192.168.0.10)"
		return
	_hide_picker()
	if GameSession.net.join(clean, GameState.get_player_name(GameState.PLAYER_ONE), local_character()):
		say("Conectando con %s..." % clean)
	else:
		say("No se pudo conectar con %s" % clean)


func _fill_rooms() -> void:
	if _list == null or not _picker.visible:
		return
	for child in _list.get_children():
		child.queue_free()
	var rooms := GameSession.net.rooms
	if not rooms.is_empty():
		_note.text = "Salas encontradas:"
	for address: String in rooms:
		var info: Dictionary = rooms[address]
		var open := bool(info.get("open", true)) and int(info.get("players", 0)) < NetRoom.CAPACITY
		var text := "%s  ·  %d/%d  ·  %s" % [str(info.get("name", "Sala")), int(info.get("players", 0)), NetRoom.CAPACITY, address]
		var entry := UiKit.text_button(text if open else text + "  (llena o en juego)", Palette.TEAL if open else Palette.INK_SOFT, 20)
		entry.disabled = not open
		entry.pressed.connect(_connect_to.bind(address))
		_list.add_child(entry)


func _build_picker() -> void:
	_picker = CanvasLayer.new()
	_picker.layer = 20
	_picker.visible = false
	add_child(_picker)
	var shade := ColorRect.new()
	shade.color = Color(Palette.NIGHT, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style())
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	column.add_child(UiKit.label("Unirse a una sala", UiKit.BOLD_FONT, 34, Palette.INK))
	_note = UiKit.label("", UiKit.BODY_FONT, 18, Palette.INK_SOFT)
	column.add_child(_note)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	column.add_child(_list)
	column.add_child(UiKit.label("O escribe la IP del anfitrión:", UiKit.BODY_FONT, 18, Palette.INK_SOFT))
	_address = LineEdit.new()
	_address.placeholder_text = "192.168.0.10"
	_address.max_length = 15
	_address.custom_minimum_size = Vector2(0, 44)
	_address.add_theme_font_override("font", UiKit.BOLD_FONT)
	_address.add_theme_font_size_override("font_size", 26)
	_address.add_theme_color_override("font_color", Palette.INK)
	_address.add_theme_color_override("caret_color", Palette.CORAL)
	for state in ["normal", "focus"]:
		var line := StyleBoxFlat.new()
		line.bg_color = Color(Palette.PAPER, 0.0)
		line.border_width_bottom = 2
		line.border_color = Palette.CORAL if state == "focus" else Color(Palette.INK, 0.3)
		line.content_margin_top = 6
		line.content_margin_bottom = 6
		_address.add_theme_stylebox_override(state, line)
	_address.text_submitted.connect(_connect_to)
	column.add_child(_address)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 24)
	column.add_child(actions)
	_link(actions, "Conectar", Palette.TEAL, func() -> void: _connect_to(_address.text))
	_link(actions, "Cancelar", Palette.INK_SOFT, _hide_picker)


func _link(parent: Control, text: String, color: Color, action: Callable) -> TextButton:
	var link := UiKit.text_button(text, color, 20)
	link.add_theme_font_override("font", UiKit.BOLD_FONT)
	link.pressed.connect(action)
	parent.add_child(link)
	return link
