extends Screen

#The waiting room: your character, the open places and the "Listo" button; when everybody is ready it starts

const START_DELAY := 1.3
const BUTTON_WIDTH := 232.0
const ENTER_ICON := preload("res://assets/ui/icons/key_enter.svg")
const BACK_ICON := preload("res://assets/ui/icons/key_e.svg")

var _stage: LobbyStage
var _ready_button: GameButton
var _count_label: Label
var _places_label: Label
var _dots: HBoxContainer
var _banner: PanelContainer
var _name_field: LineEdit
var _countdown: Tween
var _local_id := GameState.PLAYER_ONE


func _ready() -> void:
	super()
	GameSession.prepare_lobby()
	add_child(SocialBackground.new())
	_build_stage()
	_build_interface()
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
		margin.add_theme_constant_override(side, 36)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 26)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var titles := VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_theme_constant_override("separation", 2)
	top.add_child(titles)
	titles.add_child(UiKit.body(ScreenFlow.trail(screen_id), 19))
	titles.add_child(UiKit.heading("SALA DE ESPERA", 54, Palette.CORAL))
	var gap := CenterContainer.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	_banner = _build_banner()
	gap.add_child(_banner)
	var status := VBoxContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_constant_override("separation", 8)
	top.add_child(status)
	status.add_child(_build_status_chip())
	_places_label = UiKit.body("", 22)
	_places_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_places_label)

	var middle := Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 18)
	column.add_child(bottom)
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 6)
	bottom.add_child(left)
	left.add_child(_build_name_card())
	var practice_card := PanelContainer.new()
	practice_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	practice_card.add_theme_stylebox_override("panel", UiKit.card_style(0.92, 22))
	var practice := UiKit.text_button("PRACTICAR UN MINIJUEGO", Palette.TEAL, 18)
	practice.pressed.connect(ScreenFlow.open.bind(&"practice"))
	practice_card.add_child(practice)
	left.add_child(practice_card)
	var bottom_gap := Control.new()
	bottom_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bottom_gap)
	var back := UiKit.game_button("ATRÁS", false, BUTTON_WIDTH, false, 20)
	back.size_flags_vertical = Control.SIZE_SHRINK_END
	back.icon = BACK_ICON
	back.pressed.connect(ScreenFlow.back)
	bottom.add_child(back)
	_ready_button = UiKit.game_button("LISTO", true, BUTTON_WIDTH, true, 20)
	_ready_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_ready_button.icon = ENTER_ICON
	_ready_button.pressed.connect(_toggle_ready)
	bottom.add_child(_ready_button)


func _build_status_chip() -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chip.add_theme_stylebox_override("panel", UiKit.card_style(0.7, 26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	chip.add_child(row)
	row.add_child(UiKit.heading("LISTOS", 22, Palette.INK_SOFT))
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_dots)
	for index in LobbyState.CAPACITY:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(20, 20)
		dot.add_theme_stylebox_override("panel", UiKit.box(Color(Palette.INK, 0.15), 10))
		_dots.add_child(dot)
	_count_label = UiKit.heading("0/0", 26)
	row.add_child(_count_label)
	return chip


func _build_banner() -> PanelContainer:
	var banner := PanelContainer.new()
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := UiKit.box(Palette.PILL, 100)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", style)
	banner.add_child(UiKit.heading("¡TODOS LISTOS!", 28, Palette.PAPER))
	banner.visible = false
	return banner


func _build_name_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style(0.7, 26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var caption := UiKit.heading("TU NOMBRE", 20, Palette.INK_SOFT)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	_name_field = LineEdit.new()
	_name_field.custom_minimum_size = Vector2(190, 44)
	_name_field.max_length = GameState.MAX_NAME_LENGTH
	_name_field.text = GameState.get_player_name(_local_id)
	_name_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_field.add_theme_font_override("font", UiKit.HEADING_FONT)
	_name_field.add_theme_font_size_override("font_size", 24)
	_name_field.add_theme_color_override("font_color", Palette.INK)
	_name_field.add_theme_color_override("caret_color", Palette.CORAL)
	var field_style := UiKit.box(Color(Palette.INK, 0.08), 22)
	field_style.content_margin_left = 16
	field_style.content_margin_right = 16
	_name_field.add_theme_stylebox_override("normal", field_style)
	var focus_style := field_style.duplicate() as StyleBoxFlat
	focus_style.set_border_width_all(2)
	focus_style.border_color = Palette.CORAL
	_name_field.add_theme_stylebox_override("focus", focus_style)
	_name_field.text_changed.connect(_on_name_changed)
	_name_field.text_submitted.connect(func(_text: String) -> void: _name_field.release_focus())
	row.add_child(_name_field)
	return card


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
	_places_label.text = "%d de %d plazas ocupadas" % [lobby.slots.size(), LobbyState.CAPACITY]
	_count_label.text = "%d/%d" % [lobby.ready_count(), lobby.slots.size()]
	for index in _dots.get_child_count():
		var dot := _dots.get_child(index) as Panel
		var color := Color(Palette.INK, 0.08)
		if index < lobby.slots.size():
			color = Palette.TEAL if lobby.slots[index].ready else Color(Palette.INK, 0.25)
		dot.add_theme_stylebox_override("panel", UiKit.box(color, 10))
	var mine := lobby.find(_local_id)
	_ready_button.set_caption("CANCELAR" if mine != null and mine.ready else "LISTO")
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
