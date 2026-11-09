extends Screen

#What happened in the round that just ended, and the way on to the next one

const BUTTON_WIDTH := 340.0
const ENTER_ICON := preload("res://assets/ui/icons/key_enter.svg")

var _column: VBoxContainer
var _button: GameButton


func _ready() -> void:
	super()
	if GameSession.results.is_empty():
		GameSession.abandon()
		return
	add_child(SocialBackground.new())
	_build()
	_animate_in()
	_button.grab_focus()


#Going back makes no sense here: Enter goes on
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_confirm"):
		get_viewport().set_input_as_handled()
		GameSession.advance()


func _build() -> void:
	var result: RoundResult = GameSession.results.back()
	var info := MinigameCatalog.find(result.minigame_id)
	var accent := Palette.TEAL if result.won else Palette.CORAL

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 14)
	center.add_child(_column)

	var where := "PRÁCTICA" if GameSession.practice else "RONDA %d DE %d" % [GameSession.round_index + 1, GameSession.plan.size()]
	var caption := UiKit.label("%s  ·  %s" % [where, info.title.to_upper() if info != null else ""], UiKit.BUTTON_FONT, 13, Palette.INK_SOFT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(caption)
	var headline := UiKit.label(result.headline.to_upper(), UiKit.BUTTON_FONT, 34, accent)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(headline)
	var detail := UiKit.body(result.detail, 21)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(640, 0)
	_column.add_child(detail)

	if not result.stats.is_empty():
		var gap_stats := Control.new()
		gap_stats.custom_minimum_size = Vector2(0, 8)
		_column.add_child(gap_stats)
		var stats := GridContainer.new()
		stats.columns = result.stats.size()
		stats.add_theme_constant_override("h_separation", 54)
		stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_column.add_child(stats)
		for line in result.stats:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			var value := UiKit.label(str(line[1]), UiKit.BUTTON_FONT, 26, Palette.INK)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(value)
			var name_label := UiKit.label(str(line[0]).to_upper(), UiKit.BUTTON_FONT, 10, Palette.INK_SOFT)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(name_label)
			stats.add_child(cell)

	if not GameSession.practice:
		var gap_pips := Control.new()
		gap_pips.custom_minimum_size = Vector2(0, 4)
		_column.add_child(gap_pips)
		_column.add_child(_build_progress())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	_column.add_child(gap)
	_button = UiKit.game_button(_next_text(), true, BUTTON_WIDTH, true)
	_button.icon = ENTER_ICON
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(GameSession.advance)
	_column.add_child(_button)
	if not GameSession.practice:
		var leave := UiKit.text_button("ABANDONAR PARTIDA", Palette.AMBER, 14)
		leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		leave.pressed.connect(GameSession.abandon)
		_column.add_child(leave)


func _next_text() -> String:
	if GameSession.practice:
		return "VOLVER A LA SALA"
	return "VER RESULTADOS" if GameSession.is_last_round() else "SIGUIENTE RONDA"


func _build_progress() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	for index in GameSession.plan.size():
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(22, 22)
		var style := UiKit.box(Color(Palette.INK, 0.18), 11)
		if index < GameSession.results.size():
			style.bg_color = Palette.TEAL if GameSession.results[index].won else Palette.CORAL
		pip.add_theme_stylebox_override("panel", style)
		row.add_child(pip)
	return row


func _animate_in() -> void:
	await get_tree().process_frame
	_column.pivot_offset = _column.size / 2.0
	_column.scale = Vector2.ONE * 0.94
	_column.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_column, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_column, "modulate:a", 1.0, 0.25)
