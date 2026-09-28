extends Screen

const AIM_LAG := 5.0
const FRONT_SHIFT := 13.0
const BACK_SHIFT := 5.0

var _aim := Vector2.ZERO
var _front_base := Vector2.ZERO
var _back_base := Vector2.ZERO

@onready var _play_button: Button = %PlayButton
@onready var _options_button: Button = %OptionsButton
@onready var _exit_button: Button = %ExitButton
@onready var _foreground: Control = %Foreground
@onready var _background: Control = %Background


func _ready() -> void:
	super()
	_play_button.pressed.connect(ScreenFlow.open.bind(&"character_select"))
	_options_button.pressed.connect(ScreenFlow.open.bind(&"options"))
	_exit_button.pressed.connect(get_tree().quit)
	_play_button.grab_focus()
	_front_base = _foreground.position
	_back_base = _background.position


#La pantalla se desplaza un poco contra el mouse, como una camara que mira alrededor.
#El fondo se mueve menos que el frente, y eso es lo que da la sensacion de profundidad
func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	var target := Vector2(
		clampf(mouse.x / view.x * 2.0 - 1.0, -1.0, 1.0),
		clampf(mouse.y / view.y * 2.0 - 1.0, -1.0, 1.0))
	_aim = _aim.lerp(target, 1.0 - exp(-AIM_LAG * delta))
	_foreground.position = _front_base - _aim * FRONT_SHIFT
	_background.position = _back_base - _aim * BACK_SHIFT
