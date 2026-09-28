extends MenuPage

const ROWS := [
	["Caminar", "WASD"],
	["Saltar", "ESPACIO"],
	["Mover la cámara", "MOUSE"],
]


func _ready() -> void:
	super()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for row in ROWS:
		grid.add_child(_make_label(row[0], FONT, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT))
		grid.add_child(_make_label(row[1], KEY_FONT, Palette.TEAL, HORIZONTAL_ALIGNMENT_RIGHT))


func _make_label(text: String, font: Font, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
