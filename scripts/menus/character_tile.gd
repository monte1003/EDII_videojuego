class_name CharacterTile
extends Button

const BORDER_COLOR := Color("2b2f3d")
const SELECTED_BORDER_COLOR := Color("ffd23f")
const LOCKED_TINT := Color(0.3, 0.3, 0.35)

var _style := StyleBoxFlat.new()

@onready var _portrait: TextureRect = $Portrait
@onready var _badge: Control = $PlayerBadge


func _ready() -> void:
	_style.set_corner_radius_all(12)
	_style.set_border_width_all(6)
	_style.shadow_color = Color(SELECTED_BORDER_COLOR, 0.7)
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, _style)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func setup(character: CharacterData) -> void:
	_portrait.texture = character.portrait
	_style.bg_color = character.accent_color
	if not character.is_available():
		_style.bg_color = character.accent_color.darkened(0.6)
		_portrait.modulate = LOCKED_TINT
		disabled = true
	set_selected(false)


func set_selected(selected: bool) -> void:
	_badge.visible = selected
	_style.border_color = SELECTED_BORDER_COLOR if selected else BORDER_COLOR
	_style.shadow_size = 16 if selected else 0
