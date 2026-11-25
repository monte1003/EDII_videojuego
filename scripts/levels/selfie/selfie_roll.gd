class_name SelfieRoll
extends Control

#End of round roll: every photo with its followers in one row

const THUMB := Vector2(96.0, 54.0)
const EDGE := 4.0
const GAP := 10.0
const NUMBER_SIZE := 15
const LIFT := 30.0
const STAGGER := 0.06

var _row: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", int(GAP))
	add_child(_row)
	visible = false


#Photos and numbers in shot order; a negative number means the player was out
func show_roll(photos: Array[Texture2D], numbers: Array[int]) -> void:
	for child in _row.get_children():
		child.queue_free()
	for index in photos.size():
		var cell := _cell(photos[index], numbers[index] if index < numbers.size() else -1)
		cell.modulate.a = 0.0
		_row.add_child(cell)
		var tween := create_tween()
		tween.tween_interval(STAGGER * index)
		tween.tween_property(cell, "modulate:a", 1.0, 0.25)
	visible = true
	await get_tree().process_frame
	var screen := get_viewport_rect().size
	_row.position = Vector2((screen.x - _row.size.x) / 2.0, screen.y - _row.size.y - LIFT)


func _cell(photo: Texture2D, number: int) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", 4)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiKit.box(Palette.PAPER, 3)
	style.content_margin_left = EDGE
	style.content_margin_right = EDGE
	style.content_margin_top = EDGE
	style.content_margin_bottom = EDGE
	frame.add_theme_stylebox_override("panel", style)
	var picture := TextureRect.new()
	picture.texture = photo
	picture.custom_minimum_size = THUMB
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if number < 0:
		picture.modulate = Color(1.0, 1.0, 1.0, 0.55)
	frame.add_child(picture)
	cell.add_child(frame)
	var label := UiKit.label("+%d" % number if number >= 0 else "fuera", UiKit.BUTTON_FONT, NUMBER_SIZE, Palette.GOLD if number >= 0 else Palette.PAPER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", RoundHud.OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	cell.add_child(label)
	return cell
