extends MenuPage

#Test shortcut: opens any ready minigame without lobby, draw or results

#Margin when the column shrinks to fit
const FIT_MARGIN := 14.0

@onready var _center: Control = $Center
@onready var _layout: Control = $Center/Layout


func _ready() -> void:
	super()
	#Shrinks a long list to fit the window, never stretches it
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
	#End ceremony with the demo players
	for count in [4, 1]:
		var podium := UiKit.text_button("PODIO · %d %s" % [count, "JUGADORES" if count > 1 else "JUGADOR"], Palette.GOLD, 30)
		podium.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		podium.pressed.connect(_open_podium.bind(count))
		content.add_child(podium)
	#Each pad vibration, to try with a real DualSense
	var rumble := UiKit.text_button("VIBRACIÓN DEL MANDO", Palette.TEAL, 30)
	rumble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rumble.pressed.connect(ScreenFlow.open.bind(&"rumble_lab"))
	content.add_child(rumble)
	_fit_layout.call_deferred()


#Scales the column down around the middle until it fits; the scale goes on the centring box
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
