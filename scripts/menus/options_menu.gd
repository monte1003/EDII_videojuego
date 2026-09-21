extends MenuPage

const BUTTON_SCENE := preload("res://scenes/ui/game_button.tscn")
const BUTTON_COLORS: Array[Color] = [Color("3db8f5"), Color("ffc93c"), Color("7ed957")]


func _ready() -> void:
	super()
	#The buttons are the children of this screen in the tree, so the tree decides what shows up here
	var children := ScreenFlow.children_of(screen_id)
	for index in children.size():
		var button := BUTTON_SCENE.instantiate() as GameButton
		button.custom_minimum_size = Vector2(440, 96)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 42)
		button.text = children[index].title.to_upper()
		button.base_color = BUTTON_COLORS[index % BUTTON_COLORS.size()]
		button.label_color = button.base_color.lightened(0.55)
		button.pressed.connect(ScreenFlow.open.bind(children[index].id))
		content.add_child(button)
