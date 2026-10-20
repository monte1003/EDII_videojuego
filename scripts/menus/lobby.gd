extends Screen

#The waiting room: your character, the open places and the "Listo" button; when everybody is ready it starts

const START_DELAY := 1.3
const ACTION_WIDTH := 300.0

var _stage: LobbyStage
var _ready_button: GameButton
var _count_label: Label
var _places_label: Label
var _dots: HBoxContainer
var _banner: PanelContainer
var _name_field: LineEdit
var _countdown: Tween
var _local_id := GameState.PLAYER_ONE
var _links: Array[TextButton] = []


func _ready() -> void:
	super()
	GameSession.prepare_lobby()
	add_child(SocialBackground.new())
	_build_stage()
	_build_interface()
	_restyle_texts()
	GameSession.lobby.changed.connect(_refresh)
	_refresh()
	_ready_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_confirm") and not _name_field.has_focus():
		get_viewport().set_input_as_handled()
		_toggle_ready()
	else:
		super(event)


func _build_stage() -> void:
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
	var titles := VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_theme_constant_override("separation", 10)
	top.add_child(titles)
	titles.add_child(_caption(ScreenFlow.trail(screen_id), 18, 0.85))
	titles.add_child(UiKit.label("Sala de espera", UiKit.BOLD_FONT, 44, Palette.INK))
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
	_ready_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ready_button.pressed.connect(_toggle_ready)
	actions.add_child(_ready_button)
	var hint := _caption("Enter para confirmar  ·  E para volver", 17, 0.9)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions.add_child(hint)
	var links := HBoxContainer.new()
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(links)
	var practice := UiKit.text_button("Practicar", Palette.TEAL, 22)
	practice.pressed.connect(ScreenFlow.open.bind(&"practice"))
	links.add_child(practice)
	_links.append(practice)
	var back := UiKit.text_button("Atrás", Palette.INK_SOFT, 22)
	back.pressed.connect(ScreenFlow.back)
	links.add_child(back)
	_links.append(back)


#The buttons of the kit use the wide menu font; here every text of the screen is Outfit
func _restyle_texts() -> void:
	var caption := _ready_button.find_child("Caption", true, false) as Label
	if caption != null:
		caption.add_theme_font_override("font", UiKit.BOLD_FONT)
	for link: TextButton in _links:
		link.add_theme_font_override("font", UiKit.BOLD_FONT)


#Secondary text of the screen, as the hint under the main menu
func _caption(text: String, size: int, alpha: float) -> Label:
	return UiKit.label(text, UiKit.BODY_FONT, size, Color(Palette.INK_SOFT, alpha))


func _build_status() -> VBoxContainer:
	var status := VBoxContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_constant_override("separation", 12)
	status.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_places_label = _caption("", 20, 1.0)
	_places_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_places_label)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	status.add_child(row)
	row.add_child(_caption("Listos", 20, 1.0))
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
	banner.add_child(UiKit.label("Todos listos  ·  empezando", UiKit.BOLD_FONT, 20, Palette.TEAL))
	banner.visible = false
	return banner


func _build_name_row() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_theme_constant_override("separation", 6)
	box.add_child(_caption("Tu nombre", 18, 0.9))
	_name_field = LineEdit.new()
	_name_field.custom_minimum_size = Vector2(260, 42)
	_name_field.max_length = GameState.MAX_NAME_LENGTH
	_name_field.text = GameState.get_player_name(_local_id)
	_name_field.add_theme_font_override("font", UiKit.BOLD_FONT)
	_name_field.add_theme_font_size_override("font_size", 28)
	_name_field.add_theme_color_override("font_color", Palette.INK)
	_name_field.add_theme_color_override("caret_color", Palette.CORAL)
	_name_field.add_theme_stylebox_override("normal", _underline(Color(Palette.INK, 0.3)))
	_name_field.add_theme_stylebox_override("focus", _underline(Palette.CORAL))
	_name_field.text_changed.connect(_on_name_changed)
	_name_field.text_submitted.connect(func(_text: String) -> void: _name_field.release_focus())
	box.add_child(_name_field)
	return box


#A field with only a line under it, so it reads as a form and not as one more card
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
	GameState.set_player_name(_local_id, new_text)
	var slot := GameSession.lobby.find(_local_id)
	if slot != null:
		slot.display_name = GameState.get_player_name(_local_id)
		GameSession.lobby.changed.emit()


func _toggle_ready() -> void:
	var slot := GameSession.lobby.find(_local_id)
	if slot == null:
		return
	GameSession.lobby.set_ready(_local_id, not slot.ready)
	if slot.ready:
		_stage.cheer(_local_id)


func _refresh() -> void:
	var lobby := GameSession.lobby
	_stage.show_slots(lobby.slots, _local_id)
	_places_label.text = "%d de %d jugadores" % [lobby.slots.size(), LobbyState.CAPACITY]
	_count_label.text = "%d/%d" % [lobby.ready_count(), lobby.slots.size()]
	for index in _dots.get_child_count():
		var dot := _dots.get_child(index) as Panel
		var color := Color(Palette.INK, 0.12)
		if index < lobby.slots.size():
			color = Palette.TEAL if lobby.slots[index].ready else Color(Palette.INK, 0.35)
		dot.add_theme_stylebox_override("panel", UiKit.box(color, 6))
	var mine := lobby.find(_local_id)
	_ready_button.set_caption("Cancelar" if mine != null and mine.ready else "Listo")
	if lobby.all_ready():
		_begin_countdown()
	else:
		_cancel_countdown()


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
