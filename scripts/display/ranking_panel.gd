class_name RankingPanel
extends PanelContainer

#The ranking of the day on the fair screen, drawn like the screens of the game: the sky with its icons, a coral line over a title in ink,
#the first three on cards of their own with the seal of their crown (diamond, gold and silver, as on the podium) and the rest in a list
#like the positions of the final count. Until the real ranking exists (Phase 4) it shows SAMPLE, and says so on screen

const TOP := 3
const ROWS := 10
#Example rows, only for the look of the panel: Phase 4 deletes this list and show_sample
const SAMPLE: Array[Array] = [["VALENTINA", 4210], ["SANTI", 3985], ["MAJO", 3720], ["EL PROFE", 3410], ["CAMILA R.", 3122],
	["JUANPA", 2890], ["SOFÍA", 2655], ["NICO", 2410], ["ANDRÉS", 2190], ["LUCÍA", 1875]]
#The crown of each of the first three places, its name and the colour of its card's edge
const CROWNS: Array[ScoreSheet.Medal] = [ScoreSheet.Medal.DIAMOND, ScoreSheet.Medal.GOLD, ScoreSheet.Medal.SILVER]
const CROWN_NAMES: Array[String] = ["CORONA DE DIAMANTE", "CORONA DE ORO", "CORONA DE PLATA"]
const EDGES: Array[Color] = [Color("5fd4f4"), Color("ffc531"), Color("b7c3d9")]

var _top := VBoxContainer.new()
var _rest := VBoxContainer.new()
var _tag: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shape := UiKit.box(Palette.PAPER, 30)
	shape.border_color = Color(Palette.PAPER, 0.9)
	shape.set_border_width_all(3)
	add_theme_stylebox_override("panel", shape)
	#The sky of the menus, cut to the round corners of the card
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(SocialBackground.new())
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	var mark := TextureRect.new()
	mark.texture = AttractReel.MARK
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(44.0, 44.0)
	head.add_child(mark)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	words.add_child(UiKit.label("RANKING DEL DÍA", UiKit.BUTTON_FONT, 11, Palette.CORAL))
	words.add_child(UiKit.label("Los 10 mejores", UiKit.HEADING_FONT, 30, Palette.INK))
	_tag = UiKit.label("EJEMPLO", UiKit.BUTTON_FONT, 9, Palette.TEAL)
	_tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_tag)
	_top.add_theme_constant_override("separation", 8)
	column.add_child(_top)
	var positions := UiKit.label("POSICIONES", UiKit.BUTTON_FONT, 10, Palette.INK_SOFT)
	positions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(positions)
	_rest.add_theme_constant_override("separation", 2)
	_rest.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_rest)
	show_sample()


func show_sample() -> void:
	var rows: Array[Array] = []
	for row in SAMPLE:
		rows.append(row)
	show_rows(rows)
	_tag.visible = true


#Rows of [name, points], best first; only the first ten show
func show_rows(rows: Array[Array]) -> void:
	_tag.visible = false
	for child in _top.get_children() + _rest.get_children():
		child.queue_free()
	for index in mini(rows.size(), ROWS):
		var shown := str(rows[index][0])
		var points := int(rows[index][1])
		if index < TOP:
			_top.add_child(_crowned(index, shown, points))
		else:
			_rest.add_child(_row(index, shown, points))


#One of the first three: a white card edged in the colour of its crown, with its seal, its name and the name of its crown
func _crowned(index: int, shown_name: String, points: int) -> Control:
	var card := PanelContainer.new()
	var face := UiKit.box(Color(Palette.PAPER, 0.96), 22)
	face.border_color = EDGES[index]
	face.set_border_width_all(4 if index == 0 else 3)
	face.content_margin_left = 10.0
	face.content_margin_right = 16.0
	face.content_margin_top = 8.0 if index == 0 else 5.0
	face.content_margin_bottom = 8.0 if index == 0 else 5.0
	face.shadow_color = Color(EDGES[index], 0.45)
	face.shadow_size = 10 if index == 0 else 5
	card.add_theme_stylebox_override("panel", face)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	card.add_child(line)
	var seal := MedalBadge.make(CROWNS[index], 54.0 if index == 0 else 42.0)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(seal)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -3)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(words)
	words.add_child(UiKit.label(CROWN_NAMES[index], UiKit.BUTTON_FONT, 8, MedalBadge.RIM[CROWNS[index]]))
	var who := UiKit.label(shown_name, UiKit.HEADING_FONT, 26 if index == 0 else 21, Palette.INK)
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(who)
	var score := UiKit.label(str(points), UiKit.BUTTON_FONT, 20 if index == 0 else 16, Palette.INK)
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(score)
	return card


#From the fourth on: the place, the name and the points, as in the positions of the final count
func _row(index: int, shown_name: String, points: int) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var place := UiKit.label("%d.º" % (index + 1), UiKit.BUTTON_FONT, 13, Palette.INK_SOFT)
	place.custom_minimum_size.x = 44.0
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(place)
	var who := UiKit.label(shown_name, UiKit.BOLD_FONT, 18, Palette.INK)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(who)
	var score := UiKit.label(str(points), UiKit.BUTTON_FONT, 14, Palette.INK)
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(score)
	return line
