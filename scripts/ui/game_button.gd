@tool
class_name GameButton
extends Button

const OUTLINE_COLOR := Color("2e1b2f")

@export var base_color := Color("ffc93c"):
	set(value):
		base_color = value
		_apply_style()
@export var label_color := Color("ff8a1a"):
	set(value):
		label_color = value
		_apply_style()


func _ready() -> void:
	_apply_style()


func _apply_style() -> void:
	if not is_node_ready():
		return
	add_theme_stylebox_override("normal", _make_style(base_color, 8))
	add_theme_stylebox_override("hover", _make_style(base_color.lightened(0.15), 8))
	add_theme_stylebox_override("pressed", _make_style(base_color.darkened(0.1), 3))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(color_name, label_color)
	add_theme_color_override("font_outline_color", OUTLINE_COLOR)


func _make_style(color: Color, depth: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(28)
	style.set_border_width_all(5)
	style.border_color = OUTLINE_COLOR
	style.shadow_color = color.darkened(0.5)
	style.shadow_size = 1
	style.shadow_offset = Vector2(0, depth)
	style.content_margin_left = 32
	style.content_margin_right = 32
	return style
