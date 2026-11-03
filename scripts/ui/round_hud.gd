class_name RoundHud
extends CanvasLayer

#Shared base of the in-round screens. The 3D stays in view: white text with a dark outline instead of cards, a small clock,
#a mission line that fades after a few seconds, one short notice at a time, an edge glow and a one-line end of the round

signal retry_requested
signal menu_requested

const GLOW_SHADER: Shader = preload("res://assets/ui/shaders/edge_glow.gdshader")
const OUTLINE := Color(Palette.NIGHT, 0.88)
const SHADOW := Color(Palette.NIGHT, 0.45)
const CLOCK_SIZE := 30
const LOW_CLOCK_SIZE := 44
#How far above the centre of the screen the countdown number sits
const COUNTDOWN_LIFT := 150.0

var toast_hold := 2.4
var toast_fade := 0.5
var warn_delay := 0.3
var warn_fade := 0.6
var low_time_seconds := 10
var low_time_color := Palette.CORAL
var retry_text := "REINTENTAR"

var _root: MarginContainer
var _top: VBoxContainer
var _bottom: VBoxContainer
var _timer_label: Label
var _toast_label: Label
var _toast_tween: Tween
var _mission: VBoxContainer
var _mission_text: Label
var _mission_keys: HBoxContainer
var _mission_tween: Tween
var _warning: Label
var _warn_tween: Tween
var _countdown: Label
var _glow: ColorRect
var _glow_material: ShaderMaterial
var _danger := 0.0
var _flash := 0.0
var _flash_tween: Tween
var _last_whole := -1
var _end: Control
var _end_title: Label
var _end_message: Label
var _end_buttons: VBoxContainer
var _end_first_button: TextButton


func _ready() -> void:
	layer = 5
	_build_glow()
	_root = _make_root(26)
	_top = VBoxContainer.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_top.add_theme_constant_override("separation", 6)
	_root.add_child(_top)
	_timer_label = _text("", UiKit.BUTTON_FONT, CLOCK_SIZE)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_timer_label)
	_toast_label = _text("", UiKit.BODY_FONT, 24)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0
	_top.add_child(_toast_label)

	_bottom = VBoxContainer.new()
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	_bottom.add_theme_constant_override("separation", 10)
	_root.add_child(_bottom)
	_build_mission()

	_build_notices()
	_build_end()


func _process(_delta: float) -> void:
	_glow_material.set_shader_parameter("amount", maxf(_danger, _flash))


#A number in the middle of the screen that pops in
func show_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.show()
	_countdown.pivot_offset = _countdown.size / 2.0
	_countdown.scale = Vector2.ONE * 1.35
	create_tween().tween_property(_countdown, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_countdown() -> void:
	_countdown.hide()


#The clock: small and quiet until the last seconds, then it grows, turns warm and beats once a second
func set_time(seconds: float) -> void:
	var whole := int(ceil(maxf(seconds, 0.0)))
	_timer_label.text = "%d:%02d" % [floori(whole / 60.0), whole % 60]
	var low := whole <= low_time_seconds
	_timer_label.add_theme_color_override("font_color", low_time_color if low else Palette.PAPER)
	_timer_label.add_theme_font_size_override("font_size", LOW_CLOCK_SIZE if low else CLOCK_SIZE)
	if low and whole != _last_whole:
		_pulse(_timer_label, 1.18)
	_last_whole = whole


func hide_timer() -> void:
	_timer_label.hide()


#What to do, in one line, and the keys for it; it fades by itself so the screen stays clear
func show_mission(text: String, keys: Array[String] = [], hold := 3.6) -> void:
	_mission_text.text = text
	for child in _mission_keys.get_children():
		child.queue_free()
	for entry in keys:
		var parts := entry.split("|")
		_mission_keys.add_child(UiKit.key_chip(parts[0], 16))
		if parts.size() > 1:
			var caption := _text(parts[1], UiKit.BODY_FONT, 18)
			_mission_keys.add_child(caption)
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(10, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_mission_keys.add_child(gap)
	if _mission_tween != null and _mission_tween.is_valid():
		_mission_tween.kill()
	_mission.modulate.a = 0.0
	_mission_tween = create_tween()
	_mission_tween.tween_property(_mission, "modulate:a", 1.0, 0.3)
	_mission_tween.tween_interval(hold)
	_mission_tween.tween_property(_mission, "modulate:a", 0.0, 0.7)


func hide_mission() -> void:
	if _mission_tween != null and _mission_tween.is_valid():
		_mission_tween.kill()
	_mission.modulate.a = 0.0


#An occasional line under the clock; use it sparingly
func toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(toast_hold)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, toast_fade)


#A flash of up to three words in the middle of the screen
func warn(text: String) -> void:
	_warning.text = text
	if _warn_tween != null and _warn_tween.is_valid():
		_warn_tween.kill()
	_warning.pivot_offset = _warning.size / 2.0
	_warning.scale = Vector2.ONE * 1.3
	_warning.modulate.a = 1.0
	_warn_tween = create_tween().set_parallel(true)
	_warn_tween.tween_property(_warning, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_warn_tween.tween_property(_warning, "modulate:a", 0.0, warn_fade).set_delay(warn_delay)


#The edge of the screen glows: a steady danger level (0 to 1) and a quick flash that fades
func set_danger(amount: float, color := Palette.CORAL) -> void:
	_danger = clampf(amount, 0.0, 1.0)
	_glow_material.set_shader_parameter("glow_color", color)


func flash(color: Color, amount := 0.8, seconds := 0.5) -> void:
	_glow_material.set_shader_parameter("glow_color", color)
	_flash = amount
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 0.0, seconds).set_ease(Tween.EASE_OUT)


#The end of the round in one line and one fact; inside a session the results screen follows by itself
func show_banner(title: String, detail: String, color := Palette.PAPER) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", color)
	_end_message.text = detail
	_end_buttons.hide()
	_end.modulate.a = 0.0
	_end.show()
	_end_title.pivot_offset = _end_title.size / 2.0
	_end_title.scale = Vector2.ONE * 1.25
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_end, "modulate:a", 1.0, 0.25)
	tween.tween_property(_end_title, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


#The same banner with its two choices, for a round that is played on its own
func show_end(title: String, message: String, victory: bool) -> void:
	show_banner(title, message, Palette.PAPER if victory else Palette.GOLD)
	_end_buttons.show()
	_end_first_button.grab_focus()


#Fades the play screen out, for a close-up
func hide_play_ui() -> void:
	create_tween().tween_property(_root, "modulate:a", 0.0, 0.3)


func _make_root(margin: int) -> MarginContainer:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_top", "margin_bottom", "margin_left", "margin_right"]:
		root.add_theme_constant_override(side, margin)
	add_child(root)
	return root


#Text that reads on any background: white with a thin dark outline and a soft shadow
func _text(text: String, font: Font, size: int, color := Palette.PAPER) -> Label:
	var label := UiKit.label(text, font, size, color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(roundi(size / 8.0), 3))
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_y", maxi(roundi(size / 14.0), 2))
	return label


func _pulse(node: Control, factor: float) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2.ONE * factor
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_glow() -> void:
	var holder := CanvasLayer.new()
	holder.layer = 4
	add_child(holder)
	_glow = ColorRect.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = GLOW_SHADER
	_glow.material = _glow_material
	holder.add_child(_glow)


func _build_mission() -> void:
	_mission = VBoxContainer.new()
	_mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission.add_theme_constant_override("separation", 8)
	_mission.modulate.a = 0.0
	_bottom.add_child(_mission)
	_mission_text = _text("", UiKit.BODY_FONT, 26)
	_mission_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission.add_child(_mission_text)
	_mission_keys = HBoxContainer.new()
	_mission_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission_keys.alignment = BoxContainer.ALIGNMENT_CENTER
	_mission_keys.add_theme_constant_override("separation", 8)
	_mission.add_child(_mission_keys)
	#Raised a little so it never sits on the very edge of the screen
	var lift := Control.new()
	lift.custom_minimum_size = Vector2(0, 34)
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(lift)


func _build_notices() -> void:
	_countdown = _text("", UiKit.BUTTON_FONT, 120)
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_countdown.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown.grow_vertical = Control.GROW_DIRECTION_BOTH
	_countdown.offset_top -= COUNTDOWN_LIFT
	_countdown.offset_bottom -= COUNTDOWN_LIFT
	_countdown.hide()
	add_child(_countdown)
	_warning = _text("", UiKit.BUTTON_FONT, 34, Palette.GOLD)
	_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning.grow_vertical = Control.GROW_DIRECTION_BOTH
	_warning.offset_top -= 70.0
	_warning.offset_bottom -= 70.0
	_warning.modulate.a = 0.0
	add_child(_warning)


func _build_end() -> void:
	var holder := CanvasLayer.new()
	holder.layer = 12
	add_child(holder)
	_end = Control.new()
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.hide()
	holder.add_child(_end)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(Palette.NIGHT, 0.4)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	_end_title = _text("", UiKit.BUTTON_FONT, 54)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_end_title)
	_end_message = _text("", UiKit.BODY_FONT, 26)
	_end_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_end_message)
	_end_buttons = VBoxContainer.new()
	_end_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_buttons.add_theme_constant_override("separation", 2)
	column.add_child(_end_buttons)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_buttons.add_child(gap)
	_end_first_button = UiKit.text_button(retry_text, Palette.PILL, 24)
	_end_first_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_end_first_button.pressed.connect(retry_requested.emit)
	_end_buttons.add_child(_end_first_button)
	var menu_button := UiKit.text_button("VOLVER AL MENÚ", Palette.PAPER, 18)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_button.pressed.connect(menu_requested.emit)
	_end_buttons.add_child(menu_button)
