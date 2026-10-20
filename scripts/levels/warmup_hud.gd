class_name WarmupHud
extends RoundHud

#The warm-up screen: time left, the controls in small and the vote to start

var _vote_card: PanelContainer
var _vote_label: Label
var _count_label: Label


func _ready() -> void:
	super()
	toast_hold = 1.8
	toast_fade = 0.4
	low_time_seconds = 5
	var root := _make_root(26)
	var column := _vbox(10)
	root.add_child(column)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var timer_card := PanelContainer.new()
	timer_card.add_theme_stylebox_override("panel", _card_style())
	top.add_child(timer_card)
	var timer_row := _hbox(16)
	timer_card.add_child(timer_row)
	timer_row.add_child(_label("CALENTAMIENTO", HEADING_FONT, 22, Palette.INK_SOFT))
	_timer_label = _label("0:30", HEADING_FONT, 40, Palette.INK)
	_timer_label.custom_minimum_size = Vector2(80, 0)
	timer_row.add_child(_timer_label)
	column.add_child(_make_toast())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	var bottom := _hbox()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(bottom)
	bottom.add_child(_build_hints())
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(space)
	bottom.add_child(_build_vote_card())


#How many already said they are ready, and whether this player did
func set_votes(count: int, total: int, mine: bool) -> void:
	_count_label.text = "%d/%d" % [count, total]
	_vote_label.text = "LISTO" if mine else "ESTOY LISTO"
	_vote_label.add_theme_color_override("font_color", Palette.TEAL if mine else Palette.INK)


func _build_hints() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style(0.8, 24))
	var row := _hbox(14)
	card.add_child(row)
	var move_keys := " ".join([InputHints.key_label(&"move_forward"), InputHints.key_label(&"move_left"),
		InputHints.key_label(&"move_back"), InputHints.key_label(&"move_right")])
	for hint in [[move_keys, "Moverte"], ["MOUSE", "Cámara"], [InputHints.key_label(&"jump"), "Saltar"],
			[InputHints.key_label(&"interact"), "Usar"]]:
		row.add_child(UiKit.key_chip(hint[0], 18))
		row.add_child(_label(hint[1], BODY_FONT, 19, Palette.INK_SOFT))
	return card


func _build_vote_card() -> PanelContainer:
	_vote_card = PanelContainer.new()
	_vote_card.add_theme_stylebox_override("panel", UiKit.card_style(0.92, 26))
	var row := _hbox(12)
	_vote_card.add_child(row)
	row.add_child(UiKit.key_chip(InputHints.key_label(&"menu_confirm"), 20))
	_vote_label = _label("ESTOY LISTO", HEADING_FONT, 24, Palette.INK)
	row.add_child(_vote_label)
	_count_label = _label("0/1", HEADING_FONT, 24, Palette.INK_SOFT)
	row.add_child(_count_label)
	return _vote_card
