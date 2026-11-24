extends Screen

#Back in a game under way after losing the connection: the round the others are playing and that this computer joins in the next one.
#The server moves it on by itself

func _ready() -> void:
	super()
	add_child(SocialBackground.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	column.add_child(_centered(UiKit.label("DE VUELTA EN LA PARTIDA", UiKit.BUTTON_FONT, 13, Palette.INK_SOFT)))
	column.add_child(_centered(UiKit.label("Entras en la siguiente ronda", UiKit.BOLD_FONT, 44, Palette.INK)))
	var info := GameSession.current_info()
	var playing := "RONDA %d DE %d" % [GameSession.round_index + 1, GameSession.plan.size()]
	if info != null:
		playing += "  ·  " + info.title.to_upper()
	column.add_child(_centered(UiKit.label(playing, UiKit.BUTTON_FONT, 14, Palette.CORAL)))


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
