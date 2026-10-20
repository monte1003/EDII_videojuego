extends MenuPage

#One minigame on its own, from the lobby: every ready minigame of the catalog is a button

const ACCENTS: Array[Color] = [Palette.CORAL, Palette.TEAL, Palette.AMBER]


func _ready() -> void:
	super()
	var entries := MinigameCatalog.ready_entries()
	for index in entries.size():
		var button := UiKit.text_button(entries[index].title.to_upper(), entries[index].accent, 30)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(GameSession.start_practice.bind(entries[index].id))
		content.add_child(button)
		var tagline := UiKit.body(entries[index].tagline, 19)
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(tagline)
