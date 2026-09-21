extends MenuPage

const ROWS := [
	["Caminar", "W A S D"],
	["Saltar", "Espacio"],
	["Mover la cámara", "Mouse"],
]


func _ready() -> void:
	super()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for row in ROWS:
		grid.add_child(_make_label(row[0], Color("3c3f46"), HORIZONTAL_ALIGNMENT_LEFT))
		grid.add_child(_make_label(row[1], Color("ff8a1a"), HORIZONTAL_ALIGNMENT_RIGHT))


func _make_label(text: String, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
