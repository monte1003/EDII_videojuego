extends Screen

#What happened in the round that just ended, and the way on to the next one

const BUTTON_WIDTH := 340.0
const ENTER_ICON := preload("res://assets/ui/icons/key_enter.svg")

var _card: PanelContainer
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
	_card = PanelContainer.new()
	var style := UiKit.card_style(0.96, 36)
	style.content_margin_left = 54
	style.content_margin_right = 54
	style.content_margin_top = 30
	style.content_margin_bottom = 34
	style.shadow_size = 22
	_card.add_theme_stylebox_override("panel", style)
	center.add_child(_card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)

	var where := "PRÁCTICA" if GameSession.practice else "RONDA %d DE %d" % [GameSession.round_index + 1, GameSession.plan.size()]
	var caption := UiKit.heading("%s  ·  %s" % [where, info.title.to_upper() if info != null else ""], 22, Palette.INK_SOFT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var headline := UiKit.heading(result.headline, 56, accent)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(headline)
	var detail := UiKit.body(result.detail, 23)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(560, 0)
	column.add_child(detail)

	if not result.stats.is_empty():
		var stats := GridContainer.new()
		stats.columns = result.stats.size()
		stats.add_theme_constant_override("h_separation", 46)
		stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(stats)
		for line in result.stats:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", -2)
			var value := UiKit.heading(str(line[1]), 40)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(value)
			var name_label := UiKit.body(str(line[0]).to_upper(), 16)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(name_label)
			stats.add_child(cell)

	if not GameSession.practice:
		column.add_child(_build_progress())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)
	_button = UiKit.game_button(_next_text(), true, BUTTON_WIDTH, true)
	_button.icon = ENTER_ICON
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(GameSession.advance)
	column.add_child(_button)
	if not GameSession.practice:
		var leave := UiKit.text_button("ABANDONAR PARTIDA", Palette.AMBER, 18)
		leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		leave.pressed.connect(GameSession.abandon)
		column.add_child(leave)


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
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2.ONE * 0.9
	_card.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_card, "modulate:a", 1.0, 0.25)
