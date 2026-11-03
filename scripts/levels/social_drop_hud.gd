class_name SocialDropHud
extends RoundHud

#The SocialDrop screen: the clock and, when the screens stop, the icon to stand on

const ICON_SIZE := 68.0

var _target: VBoxContainer
var _target_icon: TextureRect
var _target_name: Label


func _ready() -> void:
	toast_hold = 2.0
	warn_delay = 0.4
	super()
	_target = VBoxContainer.new()
	_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target.add_theme_constant_override("separation", 2)
	_target.modulate.a = 0.0
	_top.add_child(_target)
	_top.move_child(_target, 1)
	_target_icon = TextureRect.new()
	_target_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_target_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_target_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target.add_child(_target_icon)
	_target_name = _text("", UiKit.BUTTON_FONT, 13)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target.add_child(_target_name)


#The icon that stays, shown from the moment the screens stop until the tiles fall
func show_target(texture: Texture2D, shown_name: String) -> void:
	_target_icon.texture = texture
	_target_name.text = shown_name.to_upper()
	_target_icon.pivot_offset = Vector2.ONE * ICON_SIZE / 2.0
	_target_icon.scale = Vector2.ONE * 1.35
	_target.modulate.a = 1.0
	create_tween().tween_property(_target_icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_target() -> void:
	create_tween().tween_property(_target, "modulate:a", 0.0, 0.25)
