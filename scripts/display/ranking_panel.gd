class_name RankingPanel
extends PanelContainer

#The ranking of the day on the fair screen, drawn like the screens of the game: the sky with its icons, a coral line over a title in ink,
#the first three on cards of their own with the seal of their crown (diamond, gold and silver, as on the podium) and the rest in a list
#like the positions of the final count. It shows the ranking of the fair (FairRanking); at the end of a game the rows come in one after the
#other and the new ones of that game light up in coral while their points count up

const TOP := 3
const ROWS := 10
#The crown of each of the first three places, its name and the colour of its card's edge
const CROWNS: Array[ScoreSheet.Medal] = [ScoreSheet.Medal.DIAMOND, ScoreSheet.Medal.GOLD, ScoreSheet.Medal.SILVER]
const CROWN_NAMES: Array[String] = ["CORONA DE DIAMANTE", "CORONA DE ORO", "CORONA DE PLATA"]
const EDGES: Array[Color] = [MedalBadge.FILL[ScoreSheet.Medal.DIAMOND], MedalBadge.FILL[ScoreSheet.Medal.GOLD], MedalBadge.FILL[ScoreSheet.Medal.SILVER]]

var _top := VBoxContainer.new()
var _rest := VBoxContainer.new()
var _tag: Label
var _empty: Label
var _heading: Label
var _subtitle := "Los 10 mejores"


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
	_heading = UiKit.label(_subtitle, UiKit.HEADING_FONT, 30, Palette.INK)
	words.add_child(_heading)
	_tag = UiKit.label("NUEVO", UiKit.BUTTON_FONT, 9, Palette.CORAL)
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
	_empty = UiKit.label("Todavía no juega nadie.\n¿Quién estrena la corona?", UiKit.BOLD_FONT, 18, Palette.INK_SOFT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD
	_rest.add_child(_empty)
	_tag.visible = false


#The line under the title (the full list says how many there are)
func set_subtitle(text: String) -> void:
	_subtitle = text
	if _heading != null:
		_heading.text = text


#Rows of [name, points], best first; only the first ten show. "fresh" are the places (from 0) of the entries of the game that just ended:
#with "animate" the rows come in one after the other and those light up while their points count up
func show_rows(rows: Array[Array], fresh: Array[int] = [], animate := false) -> void:
	_tag.visible = not fresh.is_empty()
	for child in _top.get_children() + _rest.get_children():
		if child != _empty:
			child.queue_free()
	_empty.visible = rows.is_empty()
	for index in mini(rows.size(), ROWS):
		var shown := str(rows[index][0])
		var points := int(rows[index][1])
		var line := _crowned(index, shown, points, fresh.has(index)) if index < TOP else _row(index, shown, points, fresh.has(index))
		(_top if index < TOP else _rest).add_child(line)
		if animate:
			_enter(line, index, points, fresh.has(index))


#A row slides in from the right after the ones above it; a new one counts its points up from zero
func _enter(line: Control, index: int, points: int, fresh: bool) -> void:
	line.modulate.a = 0.0
	var arrive := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	arrive.tween_interval(0.12 * index)
	arrive.tween_property(line, "modulate:a", 1.0, 0.3)
	if not fresh:
		return
	var score := line.get_meta("score") as Label
	var count := create_tween()
	count.tween_interval(0.12 * index)
	count.tween_method(func(value: float) -> void: score.text = str(roundi(value)), 0.0, float(points), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var pulse := create_tween().set_loops(3)
	pulse.tween_property(line, "scale", Vector2(1.04, 1.04), 0.25).set_delay(0.12 * index)
	pulse.tween_property(line, "scale", Vector2.ONE, 0.25)


#One of the first three: a white card edged in the colour of its crown, with its seal, its name and the name of its crown
func _crowned(index: int, shown_name: String, points: int, fresh := false) -> Control:
	var card := PanelContainer.new()
	var face := UiKit.box(Color(Palette.PAPER, 0.96) if not fresh else Palette.PAPER.lerp(Palette.CORAL, 0.14), 22)
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
	var score := UiKit.label(str(points), UiKit.BUTTON_FONT, 20 if index == 0 else 16, Palette.CORAL if fresh else Palette.INK)
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(score)
	card.set_meta("score", score)
	card.pivot_offset = Vector2(150.0, 30.0)
	return card


#From the fourth on: the place, the name and the points, as in the positions of the final count
func _row(index: int, shown_name: String, points: int, fresh := false) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var place := UiKit.label("%d.º" % (index + 1), UiKit.BUTTON_FONT, 13, Palette.INK_SOFT)
	place.custom_minimum_size.x = 44.0
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(place)
	var who := UiKit.label(shown_name, UiKit.BOLD_FONT, 18, Palette.CORAL if fresh else Palette.INK)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(who)
	var score := UiKit.label(str(points), UiKit.BUTTON_FONT, 14, Palette.CORAL if fresh else Palette.INK)
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(score)
	line.set_meta("score", score)
	line.pivot_offset = Vector2(150.0, 12.0)
	return line
