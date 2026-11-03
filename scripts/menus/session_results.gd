extends Screen

#The end of the game: how each of the rounds went

const BUTTON_WIDTH := 300.0
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
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 14)
	center.add_child(_column)

	var title := UiKit.label("FIN DE LA PARTIDA", UiKit.BUTTON_FONT, 13, Palette.INK_SOFT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var summary := UiKit.label("%d DE %d SUPERADAS" % [cleared, GameSession.results.size()], UiKit.BUTTON_FONT, 34, Palette.INK)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(summary)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.custom_minimum_size = Vector2(560, 0)
	var gap_rows := Control.new()
	gap_rows.custom_minimum_size = Vector2(0, 6)
	_column.add_child(gap_rows)
	_column.add_child(rows)
	for index in GameSession.results.size():
		rows.add_child(_build_row(index, GameSession.results[index]))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	_column.add_child(gap)
	_button = UiKit.game_button("JUGAR DE NUEVO", true, BUTTON_WIDTH, true)
	_button.icon = ENTER_ICON
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(GameSession.play_again)
	_column.add_child(_button)
	var menu := UiKit.text_button("MENÚ PRINCIPAL", Palette.AMBER, 14)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(GameSession.abandon)
	_column.add_child(menu)


#One line per round: a dot that says how it went, the game and how it ended
func _build_row(_index: int, result: RoundResult) -> Control:
	var info := MinigameCatalog.find(result.minigame_id)
	var accent := Palette.TEAL if result.won else Palette.CORAL
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", UiKit.box(accent, 7))
	line.add_child(dot)
	var name_label := UiKit.label(info.title.to_upper() if info != null else str(result.minigame_id), UiKit.BUTTON_FONT, 15, Palette.INK)
	name_label.custom_minimum_size = Vector2(190, 0)
	line.add_child(name_label)
	var outcome := UiKit.body(result.headline, 19)
	outcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(outcome)
	return line


func _animate_in() -> void:
	await get_tree().process_frame
	_column.pivot_offset = _column.size / 2.0
	_column.scale = Vector2.ONE * 0.94
	_column.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_column, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_column, "modulate:a", 1.0, 0.25)
