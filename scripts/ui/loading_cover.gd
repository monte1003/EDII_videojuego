class_name LoadingCover
extends CanvasLayer

#Cover while the others load a round: card art, round and minigame name; fades before the film

const FADE := 0.45

var _root: Control
var _dots: Label
var _clock := 0.0


func show_round(info: MinigameInfo, step: String) -> void:
	layer = 30
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var night := ColorRect.new()
	night.color = Palette.NIGHT
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(night)
	if info.card_art != null:
		var art := TextureRect.new()
		art.texture = info.card_art
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(1.0, 1.0, 1.0, 0.55)
		_root.add_child(art)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(Palette.NIGHT, 0.35)
	_root.add_child(shade)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -2)
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = 80.0
	column.offset_top = -250.0
	_root.add_child(column)
	if step != "":
		column.add_child(_outlined(step, UiKit.BUTTON_FONT, 16, Palette.LILAC))
	column.add_child(_outlined(info.title.to_upper(), UiKit.HEADING_FONT, 62, Palette.PAPER))
	_dots = _outlined("ESPERANDO A LOS DEMÁS JUGADORES", UiKit.BUTTON_FONT, 15, Color(Palette.PAPER, 0.8))
	column.add_child(_dots)


func _process(delta: float) -> void:
	_clock += delta
	if _dots != null:
		_dots.text = "ESPERANDO A LOS DEMÁS JUGADORES" + ".".repeat(int(_clock * 2.5) % 4)


func lift() -> void:
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(queue_free)


func _outlined(text: String, font: Font, size_points: int, color: Color) -> Label:
	var label := UiKit.label(text, font, size_points, color)
	label.add_theme_color_override("font_outline_color", Color(Palette.NIGHT, 0.9))
	label.add_theme_constant_override("outline_size", maxi(roundi(size_points / 5.0), 4))
	return label
