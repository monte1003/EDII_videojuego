extends MenuPage

#Vibration test with a real pad: one button per effect; plays even with a mouse click

const NAMES := {
	&"hit": "Golpe", &"daze": "Aturdido", &"landing": "Aterrizaje", &"bump": "Choque suave", &"dive": "Barrido",
	&"shove": "Empujón al aire", &"shove_hit": "Empujón que acierta", &"fall": "Caída", &"finish": "Meta",
	&"count": "Cuenta 3, 2, 1", &"go": "YA",
}

var _status: Label
var _motors: Label


func _ready() -> void:
	super()
	_status = UiKit.body("", 22, Palette.INK)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(grid)
	for effect: StringName in Rumble.EFFECTS:
		var button := UiKit.text_button(NAMES.get(effect, String(effect)).to_upper(), Palette.TEAL, 20)
		button.pressed.connect(Rumble.play.bind(effect, true))
		grid.add_child(button)
	_motors = UiKit.body("", 19)
	_motors.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_motors)
	var note := UiKit.body("Si no vibra: cable USB-C directo al PC y Steam cerrado.", 18)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)


func _process(_delta: float) -> void:
	var pad := InputDevice.pad
	if pad < 0:
		_status.text = "No hay ningún mando conectado"
		_motors.text = ""
		return
	_status.text = "Mando %d: %s" % [pad, Input.get_joy_name(pad)]
	var strength := Input.get_joy_vibration_strength(pad)
	_motors.text = "Motor suave %.2f · Motor fuerte %.2f" % [strength.x, strength.y]
