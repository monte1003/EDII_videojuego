class_name LevelHud
extends RoundHud

#The race screen: the clock, the attempts left as dots, your place when more than one race, a line for the doors of the goal
#and the key to press only while you stand at a station. The abilities show up only while they work or recharge

var _dots: HBoxContainer
var _dot_styles: Array[StyleBoxFlat] = []
var _place_label: Label
var _window_label: Label
var _protection_label: Label
var _abilities: VBoxContainer
var _ability_rows: Dictionary = {}
var _prompt: HBoxContainer
var _prompt_key: Control
var _prompt_text: Label
var _debug_panel: PanelContainer
var _debug_label: RichTextLabel


func _ready() -> void:
	retry_text = "REINTENTAR NIVEL"
	toast_hold = 2.2
	warn_delay = 0.35
	super()
	_build_status()
	_build_abilities()
	_build_prompt()
	_build_debug_panel()


#The attempts as dots under the clock
func set_attempts(left: int, total: int) -> void:
	for index in _dot_styles.size():
		_dot_styles[index].bg_color = Palette.PAPER if index < left else Color(Palette.PAPER, 0.28)
	_dots.tooltip_text = "%d de %d intentos" % [left, total]


#Your place in the race, as in "2/4"; it only shows when someone else races
func set_place(place: int, total: int) -> void:
	_place_label.text = "%d/%d" % [place, total]
	_place_label.visible = total > 1


func show_window(text: String) -> void:
	_window_label.text = text
	_window_label.show()


func hide_window() -> void:
	_window_label.hide()


func show_protection(text: String) -> void:
	_protection_label.text = text
	_protection_label.show()


func hide_protection() -> void:
	_protection_label.hide()


#An ability only shows while it works ("Activo 4 s") or recharges ("Recarga 12 s"); when it is ready the row hides
func set_ability(id: StringName, status: String, available: bool) -> void:
	var row: Label = _ability_rows[id]
	row.visible = not available
	row.text = "%s · %s" % [String(id).to_upper(), status]


#The key to press and what it does, only while the player stands at a station
func show_prompt(key_name: String, action: String) -> void:
	if _prompt_text.text == action and _prompt.visible:
		return
	_prompt_text.text = action
	for child in _prompt_key.get_children():
		child.queue_free()
	_prompt_key.add_child(UiKit.key_chip(key_name, 18))
	_prompt.show()


func hide_prompt() -> void:
	_prompt.hide()


func set_debug_visible(shown: bool) -> void:
	_debug_panel.visible = shown


func set_debug_text(markup: String) -> void:
	_debug_label.text = markup


func _build_status() -> void:
	_dots = HBoxContainer.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 7)
	_top.add_child(_dots)
	_top.move_child(_dots, 1)
	for index in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(11, 11)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := UiKit.box(Palette.PAPER, 6)
		style.set_border_width_all(1)
		style.border_color = OUTLINE
		dot.add_theme_stylebox_override("panel", style)
		_dots.add_child(dot)
		_dot_styles.append(style)

	_window_label = _text("", UiKit.BUTTON_FONT, 22, Palette.GOLD)
	_window_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_window_label.hide()
	_top.add_child(_window_label)
	_protection_label = _text("", UiKit.BODY_FONT, 20, Palette.GOLD)
	_protection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_protection_label.hide()
	_top.add_child(_protection_label)

	#The place sits alone in the top left corner
	var corner := Control.new()
	corner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(corner)
	_place_label = _text("1/1", UiKit.BUTTON_FONT, 30)
	_place_label.position = Vector2(30, 24)
	_place_label.visible = false
	corner.add_child(_place_label)


func _build_abilities() -> void:
	_abilities = VBoxContainer.new()
	_abilities.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_abilities.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_abilities.offset_left = 30.0
	_abilities.offset_top = -40.0
	_abilities.add_theme_constant_override("separation", 4)
	add_child(_abilities)
	for id in [&"block", &"silence", &"pause"]:
		var row := _text("", UiKit.BODY_FONT, 20)
		row.hide()
		_abilities.add_child(row)
		_ability_rows[id] = row


func _build_prompt() -> void:
	_prompt = HBoxContainer.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt.add_theme_constant_override("separation", 10)
	_prompt.hide()
	_prompt_key = HBoxContainer.new()
	_prompt_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(_prompt_key)
	_prompt_text = _text("", UiKit.BUTTON_FONT, 20)
	_prompt.add_child(_prompt_text)
	_bottom.add_child(_prompt)
	_bottom.move_child(_prompt, 0)


#The route debug panel (F3): a developer tool, it stays plain
func _build_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiKit.card_style(0.92)
	style.set_corner_radius_all(18)
	_debug_panel.add_theme_stylebox_override("panel", style)
	_debug_label = RichTextLabel.new()
	_debug_label.bbcode_enabled = true
	_debug_label.fit_content = true
	_debug_label.scroll_active = false
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.custom_minimum_size = Vector2(330, 0)
	_debug_label.add_theme_font_override("normal_font", UiKit.BODY_FONT)
	_debug_label.add_theme_font_size_override("normal_font_size", 18)
	_debug_label.add_theme_color_override("default_color", Palette.INK)
	_debug_panel.add_child(_debug_label)
	_debug_panel.hide()
	_debug_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_debug_panel.offset_left = -370.0
	_debug_panel.offset_right = -20.0
	_debug_panel.offset_top = 80.0
	add_child(_debug_panel)
