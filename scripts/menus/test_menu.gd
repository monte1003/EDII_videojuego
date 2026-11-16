extends MenuPage

#Shortcut for testing from the main menu: every ready minigame of the catalog opens straight
#away, without the lobby, the draw or the results screen (no session is running)

#Space kept free around the column when it has to shrink to fit the window
const FIT_MARGIN := 14.0

@onready var _center: Control = $Center
@onready var _layout: Control = $Center/Layout


func _ready() -> void:
	super()
	#The window is never taller than the base screen, so a long list is shrunk (never stretched) to fit; it runs again whenever the
	#window or the list changes size
	resized.connect(_fit_layout)
	_center.resized.connect(_fit_layout)
	_layout.minimum_size_changed.connect(_fit_layout)
	for info in MinigameCatalog.ready_entries():
		var button := UiKit.text_button(info.title.to_upper(), info.accent, 30)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(ScreenFlow.open.bind(info.id))
		content.add_child(button)
		var tagline := UiKit.body(info.tagline, 19)
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(tagline)
	#The ceremony of the end of the game with the players of the demo
	for count in [4, 1]:
		var podium := UiKit.text_button("PODIO · %d %s" % [count, "JUGADORES" if count > 1 else "JUGADOR"], Palette.GOLD, 30)
		podium.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		podium.pressed.connect(_open_podium.bind(count))
		content.add_child(podium)
	_fit_layout.call_deferred()


#Scales the whole column down, around the middle of the window, until it fits with a margin; never above its normal size. The scale goes
#on the box that centres it, since a container resets the scale of what it holds
func _fit_layout() -> void:
	var need := _layout.get_combined_minimum_size()
	if need.x <= 0.0 or need.y <= 0.0:
		return
	var share := minf(1.0, minf((size.x - FIT_MARGIN * 2.0) / need.x, (size.y - FIT_MARGIN * 2.0) / need.y))
	_center.pivot_offset = _center.size / 2.0
	_center.scale = Vector2.ONE * maxf(share, 0.3)


func _open_podium(count: int) -> void:
	GameSession.reset()
	PodiumCeremony.demo_players = count
	ScreenFlow.open(&"podium")
