extends Screen

#Waiting room: your character, the open places and "Listo"; starts when everybody is ready

const START_DELAY := 1.3
const ACTION_WIDTH := 300.0
const MARK: Texture2D = preload("res://assets/ui/textures/mark.png")
#Halo behind each place: size, and strength while waiting and once ready
const HALO_SIZE := Vector2(330, 400)
const HALO_ALPHA := 0.34
const HALO_READY_ALPHA := 0.55

var _stage: LobbyStage
var _ready_button: GameButton
var _count_label: Label
var _dots: HBoxContainer
var _banner: PanelContainer
var _name_field: LineEdit
var _countdown: Tween
var _local_id := GameState.PLAYER_ONE
var _links: Array[TextButton] = []
var _practice: TextButton
var _net_panel: NetPanel
var _character_label: Label
var _character_dot: Panel
#On-screen keyboard for the name with the pad
var _keyboard := NameKeyboard.new()
var _write_hint: Control
var _halos: Array[TextureRect] = []
var _clock := 0.0


func _ready() -> void:
	super()
	GameSession.prepare_lobby()
	add_child(SocialBackground.new())
	_build_stage()
	_build_interface()
	_restyle_texts()
	GameSession.lobby.changed.connect(_refresh)
	GameSession.net.left.connect(_on_room_left)
	_refresh()
	_ready_button.grab_focus()
	add_child(_keyboard)
	_keyboard.accepted.connect(_on_name_written)
	_keyboard.cancelled.connect(_name_field.grab_focus)
	InputDevice.changed.connect(_on_device_changed)
	_on_device_changed(0)


#Confirm marks "Listo" when nothing is selected; the pad opens the keyboard on the name field
func _unhandled_input(event: InputEvent) -> void:
	var idle := not _name_field.has_focus() and not _net_panel.is_picking()
	if event.is_action_pressed("menu_confirm") and _name_field.has_focus() and not _net_panel.is_picking():
		get_viewport().set_input_as_handled()
		_keyboard.open(_name_field.text, GameState.MAX_NAME_LENGTH)
	elif event.is_action_pressed("menu_confirm") and idle and confirm_is_free():
		get_viewport().set_input_as_handled()
		_toggle_ready()
	elif (event.is_action_pressed("pick_prev") or event.is_action_pressed("pick_next")) and not _net_panel.is_picking():
		get_viewport().set_input_as_handled()
		_cycle_character(-1 if event.is_action_pressed("pick_prev") else 1)
	else:
		super(event)


func _on_name_written(text: String) -> void:
	_name_field.text = text
	_on_name_changed(text)
	_name_field.grab_focus()


#Key hints follow the device in use
func _on_device_changed(_kind: int) -> void:
	_ready_button.set_icon(InputHints.confirm_icon())
	_update_write_hint()


func _update_write_hint() -> void:
	_write_hint.visible = _name_field.has_focus() and InputHints.uses_pad()


#Player colour glow behind each place, breathing once ready
func _process(delta: float) -> void:
	_clock += delta
	var beat := 0.5 + 0.5 * sin(_clock * 3.6)
	for index in _halos.size():
		var halo := _halos[index]
		halo.visible = _stage.place_taken(index)
		if not halo.visible:
			continue
		halo.position = _stage.place_point(index) - HALO_SIZE / 2.0
		var strength := HALO_READY_ALPHA + 0.1 * beat if _stage.place_ready(index) else HALO_ALPHA
		halo.modulate = Color(_stage.place_color(index), strength)


func _build_halos() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.62))
	gradient.add_point(0.7, Color(1.0, 1.0, 1.0, 0.16))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 256
	texture.height = 256
	for index in LobbyState.CAPACITY:
		var halo := TextureRect.new()
		halo.texture = texture
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.stretch_mode = TextureRect.STRETCH_SCALE
		halo.size = HALO_SIZE
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.visible = false
		add_child(halo)
		_halos.append(halo)


func _build_stage() -> void:
	_build_halos()
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_stage = LobbyStage.new()
	viewport.add_child(_stage)


func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 64)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 44)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	top.add_child(_build_title())
	var gap := CenterContainer.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	_banner = _build_banner()
	gap.add_child(_banner)
	top.add_child(_build_status())

	var middle := Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)

	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 24)
	column.add_child(bottom)
	bottom.add_child(_build_name_row())
	var bottom_gap := Control.new()
	bottom_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bottom_gap)

	var actions := VBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 10)
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(actions)
	_ready_button = UiKit.game_button("Listo", true, ACTION_WIDTH, true, 28)
	_ready_button.icon = InputHints.confirm_icon()
	_ready_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ready_button.pressed.connect(_toggle_ready)
	actions.add_child(_ready_button)
	var links := HBoxContainer.new()
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(links)
	_practice = UiKit.text_button("Practicar", Palette.TEAL, 22)
	_practice.pressed.connect(ScreenFlow.open.bind(&"practice"))
	links.add_child(_practice)
	_links.append(_practice)
	var back := UiKit.text_button("Atrás", Palette.INK_SOFT, 22)
	back.pressed.connect(_back)
	links.add_child(back)
	_links.append(back)


#Every text of this screen in Outfit
func _restyle_texts() -> void:
	var caption := _ready_button.find_child("Caption", true, false) as Label
	if caption != null:
		caption.add_theme_font_override("font", UiKit.BOLD_FONT)
	for link: TextButton in _links:
		link.add_theme_font_override("font", UiKit.BOLD_FONT)


#Secondary text like the main menu hint
func _caption(text: String, size: int, alpha: float) -> Label:
	return UiKit.label(text, UiKit.BODY_FONT, size, Color(Palette.INK_SOFT, alpha))


#Game emblem beside the title with a short line over it
func _build_title() -> HBoxContainer:
	var lockup := HBoxContainer.new()
	lockup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lockup.add_theme_constant_override("separation", 16)
	var mark := TextureRect.new()
	mark.texture = MARK
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(62, 59)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lockup.add_child(mark)
	var titles := VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_theme_constant_override("separation", 0)
	lockup.add_child(titles)
	titles.add_child(UiKit.label("DEL FEED AL RING", UiKit.BUTTON_FONT, 12, Palette.CORAL))
	titles.add_child(UiKit.label("Sala de espera", UiKit.BOLD_FONT, 44, Palette.INK))
	return lockup


func _build_status() -> VBoxContainer:
	var status := VBoxContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_constant_override("separation", 12)
	status.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	status.add_child(row)
	var ready_word := UiKit.label("LISTOS", UiKit.BUTTON_FONT, 12, Palette.INK_SOFT)
	ready_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(ready_word)
	_dots = HBoxContainer.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.add_theme_constant_override("separation", 7)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_dots)
	for index in LobbyState.CAPACITY:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.add_theme_stylebox_override("panel", UiKit.box(Color(Palette.INK, 0.12), 6))
		_dots.add_child(dot)
	_count_label = UiKit.label("0/0", UiKit.BOLD_FONT, 24, Palette.INK)
	row.add_child(_count_label)
	return status


func _build_banner() -> PanelContainer:
	var banner := PanelContainer.new()
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := UiKit.box(Color(Palette.PAPER, 0.88), 100)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	banner.add_theme_stylebox_override("panel", style)
	banner.add_child(UiKit.label("Todos listos  ·  al ring", UiKit.BOLD_FONT, 20, Palette.TEAL))
	banner.visible = false
	return banner


func _build_name_row() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_theme_constant_override("separation", 6)
	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Tu nombre"
	_name_field.custom_minimum_size = Vector2(260, 42)
	_name_field.max_length = GameState.MAX_NAME_LENGTH
	_name_field.text = GameState.get_player_name(GameState.PLAYER_ONE)
	_name_field.add_theme_font_override("font", UiKit.BOLD_FONT)
	_name_field.add_theme_font_size_override("font_size", 28)
	_name_field.add_theme_color_override("font_color", Palette.INK)
	_name_field.add_theme_color_override("caret_color", Palette.CORAL)
	_name_field.add_theme_stylebox_override("normal", _underline(Color(Palette.INK, 0.3)))
	_name_field.add_theme_stylebox_override("focus", _underline(Palette.CORAL))
	_name_field.text_changed.connect(_on_name_changed)
	_name_field.text_submitted.connect(func(_text: String) -> void: _name_field.release_focus())
	_name_field.focus_entered.connect(_update_write_hint)
	_name_field.focus_exited.connect(_update_write_hint)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 14)
	name_row.add_child(_name_field)
	_write_hint = HBoxContainer.new()
	_write_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_write_hint.add_theme_constant_override("separation", 8)
	_write_hint.add_child(UiKit.action_chip(&"menu_confirm", 14))
	var write_word := UiKit.label("ESCRIBIR", UiKit.BUTTON_FONT, 12, Palette.INK_SOFT)
	write_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_write_hint.add_child(write_word)
	_write_hint.visible = false
	name_row.add_child(_write_hint)
	box.add_child(name_row)
	#Character picker: A/D or L1/R1 around its name; the room sees the change at once
	var picker := HBoxContainer.new()
	picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_theme_constant_override("separation", 10)
	picker.add_child(UiKit.action_chip(&"pick_prev", 14))
	var named := HBoxContainer.new()
	named.mouse_filter = Control.MOUSE_FILTER_IGNORE
	named.alignment = BoxContainer.ALIGNMENT_CENTER
	named.add_theme_constant_override("separation", 8)
	named.custom_minimum_size = Vector2(132, 0)
	_character_dot = Panel.new()
	_character_dot.custom_minimum_size = Vector2(12, 12)
	_character_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_character_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	named.add_child(_character_dot)
	_character_label = UiKit.label("", UiKit.BOLD_FONT, 22, Palette.INK)
	named.add_child(_character_label)
	picker.add_child(named)
	picker.add_child(UiKit.action_chip(&"pick_next", 14))
	box.add_child(picker)
	_net_panel = NetPanel.new()
	box.add_child(_net_panel)
	box.move_child(_net_panel, 0)
	return box


#Underline-only field so it reads as a form
func _underline(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.PAPER, 0.0)
	style.border_width_bottom = 2
	style.border_color = color
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _on_name_changed(new_text: String) -> void:
	GameState.set_player_name(GameState.PLAYER_ONE, new_text)
	if GameSession.is_networked():
		GameSession.net.set_profile(GameState.get_player_name(GameState.PLAYER_ONE), NetPanel.local_character())
		return
	var slot := GameSession.lobby.find(_local_id)
	if slot != null:
		slot.display_name = GameState.get_player_name(_local_id)
		GameSession.lobby.changed.emit()


func _toggle_ready() -> void:
	var slot := GameSession.lobby.find(_local_id)
	if slot == null or not accepts_confirm():
		return
	if GameSession.is_networked():
		#In a room the server keeps who is ready
		GameSession.net.set_ready(not slot.ready)
		if not slot.ready:
			_stage.cheer(_local_id)
		return
	GameSession.lobby.set_ready(_local_id, not slot.ready)
	if slot.ready:
		_stage.cheer(_local_id)


func _refresh() -> void:
	_local_id = GameSession.local_id
	_practice.visible = not GameSession.is_networked()
	var lobby := GameSession.lobby
	_stage.show_slots(lobby.slots, _local_id)
	_count_label.text = "%d/%d" % [lobby.ready_count(), lobby.slots.size()]
	for index in _dots.get_child_count():
		var dot := _dots.get_child(index) as Panel
		var color := Color(Palette.INK, 0.12)
		if index < lobby.slots.size():
			color = Palette.TEAL if lobby.slots[index].ready else Color(Palette.INK, 0.35)
		dot.add_theme_stylebox_override("panel", UiKit.box(color, 6))
	var mine := lobby.find(_local_id)
	if mine != null and mine.character != null:
		_character_label.text = mine.character.display_name.to_upper()
		_character_dot.add_theme_stylebox_override("panel", UiKit.box(mine.character.accent_color, 6))
	_ready_button.set_caption("Cancelar" if mine != null and mine.ready else "Listo")
	if lobby.all_ready() and (not GameSession.is_networked() or GameSession.net.is_host()):
		_begin_countdown()
	else:
		_cancel_countdown()


#Next or previous character; repeats wear another colour
func _cycle_character(step: int) -> void:
	var slot := GameSession.lobby.find(_local_id)
	if slot == null or not accepts_confirm():
		return
	var ids := GameSession.CHARACTER_IDS
	var at := ids.find(slot.character.id if slot.character != null else ids[0])
	var next := GameSession.character_by_id(ids[posmod(at + step, ids.size())])
	GameState.select_character(GameState.PLAYER_ONE, next)
	SynthSound.play(self, SynthSound.tone(660.0 if step > 0 else 587.0, 0.08, 0.0, 0.3), -12.0)
	if GameSession.is_networked():
		GameSession.net.set_profile(GameState.get_player_name(GameState.PLAYER_ONE), next.id)
		return
	slot.character = next
	GameSession.lobby.changed.emit()


func _back() -> void:
	if GameSession.is_networked():
		GameSession.net.close()
	ScreenFlow.back()


func _on_room_left(reason: String) -> void:
	GameSession.prepare_lobby()
	_net_panel.say(reason)


func _begin_countdown() -> void:
	if _countdown != null and _countdown.is_valid():
		return
	_banner.visible = true
	_countdown = create_tween()
	_countdown.tween_interval(START_DELAY)
	_countdown.tween_callback(GameSession.start_session)


func _cancel_countdown() -> void:
	_banner.visible = false
	if _countdown != null and _countdown.is_valid():
		_countdown.kill()
	_countdown = null
