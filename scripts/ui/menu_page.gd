class_name MenuPage
extends Screen

const FONT := preload("res://assets/ui/fonts/body_font.tres")
const KEY_FONT := preload("res://assets/ui/fonts/button_font.tres")

@onready var content: VBoxContainer = %Content

@onready var _trail_label: Label = %TrailLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	super()
	_trail_label.text = ScreenFlow.trail(screen_id)
	_back_button.pressed.connect(ScreenFlow.back)


#A setting: its name on the left and the choices on the right
func add_choice(title: String, options: Array[String], selected: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	content.add_child(row)

	var label := Label.new()
	label.text = title
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Palette.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var picker := OptionButton.new()
	picker.add_theme_font_override("font", FONT)
	picker.add_theme_font_size_override("font_size", 22)
	picker.add_theme_color_override("font_color", Palette.INK)
	picker.add_theme_color_override("font_hover_color", Palette.CORAL)
	picker.add_theme_color_override("font_focus_color", Palette.INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		picker.add_theme_stylebox_override(state, _picker_box())
	picker.get_popup().add_theme_font_override("font", FONT)
	picker.get_popup().add_theme_font_size_override("font_size", 22)
	for option in options:
		picker.add_item(option)
	picker.selected = clampi(selected, 0, options.size() - 1)
	picker.item_selected.connect(on_change)
	row.add_child(picker)


#La caja del desplegable va translucida y redonda como las pildoras de los botones
func _picker_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.PAPER, 0.7)
	style.set_corner_radius_all(120)
	style.corner_detail = 12
	style.set_border_width_all(2)
	style.border_color = Color(Palette.PAPER, 0.95)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
