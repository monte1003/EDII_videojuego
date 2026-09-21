extends Screen

const TILE_SCENE := preload("res://scenes/menus/character_tile.tscn")
const COLUMNS := 2

@export var characters: Array[CharacterData] = []
@export var rotate_sensitivity := 0.01

var _tiles: Array[CharacterTile] = []
var _selected_index := -1
var _preview_model: Node3D

@onready var _grid: GridContainer = %Grid
@onready var _name_label: Label = %NameLabel
@onready var _preview: SubViewportContainer = %Preview
@onready var _model_pivot: Node3D = %ModelPivot
@onready var _play_button: Button = %PlayButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	super()
	_grid.columns = COLUMNS
	for index in characters.size():
		var tile := TILE_SCENE.instantiate() as CharacterTile
		_grid.add_child(tile)
		tile.setup(characters[index])
		tile.pressed.connect(_select.bind(index))
		_tiles.append(tile)

	_preview.gui_input.connect(_on_preview_gui_input)
	_play_button.pressed.connect(_play)
	_back_button.pressed.connect(ScreenFlow.back)
	_select(0)


func _unhandled_input(event: InputEvent) -> void:
	var column_step := int(event.is_action_pressed("menu_right")) - int(event.is_action_pressed("menu_left"))
	var row_step := int(event.is_action_pressed("menu_down")) - int(event.is_action_pressed("menu_up"))
	if column_step != 0 or row_step != 0:
		get_viewport().set_input_as_handled()
		_move_selection(column_step, row_step)
	elif event.is_action_pressed("menu_confirm"):
		get_viewport().set_input_as_handled()
		_play()
	else:
		super(event)


#Skips locked characters in the pressed direction
func _move_selection(column_step: int, row_step: int) -> void:
	var column := _selected_index % COLUMNS
	var row := floori(_selected_index / float(COLUMNS))
	while true:
		column += column_step
		row += row_step
		var index := row * COLUMNS + column
		if column < 0 or column >= COLUMNS or index < 0 or index >= characters.size():
			return
		if characters[index].is_available():
			_select(index)
			return


func _select(index: int) -> void:
	if index == _selected_index or not characters[index].is_available():
		return
	_selected_index = index
	for i in _tiles.size():
		_tiles[i].set_selected(i == index)

	var character := characters[index]
	_name_label.text = character.display_name
	_name_label.add_theme_color_override("font_color", character.accent_color)
	if _preview_model:
		_preview_model.queue_free()
	_preview_model = character.model_scene.instantiate() as Node3D
	_model_pivot.add_child(_preview_model)
	_model_pivot.rotation.y = 0.0


func _on_preview_gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_model_pivot.rotate_y(motion.relative.x * rotate_sensitivity)


func _play() -> void:
	GameState.select_character(GameState.PLAYER_ONE, characters[_selected_index])
	ScreenFlow.open(&"test_world")
