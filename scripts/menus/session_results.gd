extends Screen

#The end of the game: how each of the rounds went

const BUTTON_WIDTH := 300.0
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_confirm"):
		get_viewport().set_input_as_handled()
		GameSession.play_again()


func _build() -> void:
	var cleared := 0
	for result in GameSession.results:
		cleared += int(result.won)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	var style := UiKit.card_style(0.96, 36)
	style.content_margin_left = 54
	style.content_margin_right = 54
	style.content_margin_top = 28
	style.content_margin_bottom = 32
	style.shadow_size = 22
	_card.add_theme_stylebox_override("panel", style)
	center.add_child(_card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)

	var title := UiKit.heading("FIN DE LA PARTIDA", 54, Palette.CORAL)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var summary := UiKit.heading("Rondas superadas: %d de %d" % [cleared, GameSession.results.size()], 30)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(summary)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.custom_minimum_size = Vector2(620, 0)
	column.add_child(rows)
	for index in GameSession.results.size():
		rows.add_child(_build_row(index, GameSession.results[index]))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var menu := UiKit.game_button("MENÚ PRINCIPAL", false, BUTTON_WIDTH)
	menu.pressed.connect(GameSession.abandon)
	buttons.add_child(menu)
	_button = UiKit.game_button("JUGAR DE NUEVO", true, BUTTON_WIDTH, true)
	_button.icon = ENTER_ICON
	_button.pressed.connect(GameSession.play_again)
	buttons.add_child(_button)


func _build_row(index: int, result: RoundResult) -> Control:
	var info := MinigameCatalog.find(result.minigame_id)
	var accent := Palette.TEAL if result.won else Palette.CORAL
	var row := PanelContainer.new()
	var row_style := UiKit.box(Color(Palette.INK, 0.05), 22)
	row_style.content_margin_left = 16
	row_style.content_margin_right = 20
	row_style.content_margin_top = 8
	row_style.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", row_style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	row.add_child(line)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(44, 44)
	badge.add_theme_stylebox_override("panel", UiKit.box(accent, 22))
	var number := UiKit.heading(str(index + 1), 26, Palette.PAPER)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(number)
	line.add_child(badge)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -2)
	line.add_child(texts)
	texts.add_child(UiKit.heading(info.title.to_upper() if info != null else str(result.minigame_id), 24))
	texts.add_child(UiKit.body(result.headline, 19))
	line.add_child(UiKit.heading("SUPERADA" if result.won else "NO SUPERADA", 20, accent))
	return row


func _animate_in() -> void:
	await get_tree().process_frame
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2.ONE * 0.9
	_card.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_card, "modulate:a", 1.0, 0.25)
