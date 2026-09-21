extends Screen

@onready var _play_button: Button = %PlayButton
@onready var _options_button: Button = %OptionsButton
@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	super()
	_play_button.pressed.connect(ScreenFlow.open.bind(&"character_select"))
	_options_button.pressed.connect(ScreenFlow.open.bind(&"options"))
	_exit_button.pressed.connect(get_tree().quit)
