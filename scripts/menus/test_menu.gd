extends MenuPage

#Shortcut for testing from the main menu: every ready minigame of the catalog opens straight
#away, without the lobby, the draw or the results screen (no session is running)


func _ready() -> void:
	super()
	for info in MinigameCatalog.ready_entries():
		var button := UiKit.text_button(info.title.to_upper(), info.accent, 30)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(ScreenFlow.open.bind(info.id))
		content.add_child(button)
		var tagline := UiKit.body(info.tagline, 19)
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(tagline)
