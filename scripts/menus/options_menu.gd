extends MenuPage

const BUTTON_SCENE := preload("res://scenes/ui/text_button.tscn")
const ACCENTS: Array[Color] = [Palette.TEAL, Palette.AMBER, Palette.CORAL]


func _ready() -> void:
	super()
	#The buttons are the children of this screen in the tree, so the tree decides what shows up here
	var children := ScreenFlow.children_of(screen_id)
	for index in children.size():
		var button := BUTTON_SCENE.instantiate() as TextButton
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 30)
		button.text = children[index].title.to_upper()
		button.accent = ACCENTS[index % ACCENTS.size()]
		button.pressed.connect(ScreenFlow.open.bind(children[index].id))
		content.add_child(button)
