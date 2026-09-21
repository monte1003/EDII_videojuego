class_name MenuPage
extends Screen

const FONT := preload("res://assets/ui/fonts/LilitaOne-Regular.ttf")

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
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("3c3f46"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var picker := OptionButton.new()
	picker.add_theme_font_override("font", FONT)
	picker.add_theme_font_size_override("font_size", 28)
	for option in options:
		picker.add_item(option)
	picker.selected = clampi(selected, 0, options.size() - 1)
	picker.item_selected.connect(on_change)
	row.add_child(picker)
