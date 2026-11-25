class_name SelfieHud
extends RoundHud

#Selfie screen: photo number and followers, plus badge, live picture and messages when needed

const CAMERA_HOLD := 2.4
const CAMERA_IN := 0.24
const CAMERA_OUT := 0.4
const MONITOR_MARGIN := 26.0
const SHOVE_KEY_WORD := "empujar"

var monitor: SelfieMonitor
var marker: SelfieMarker
var card: SelfieCard
var roll: SelfieRoll
var shove_chip: ActionChip

var _photo_label: Label
var _followers_label: Label
var _gain_label: Label
var _camera_box: VBoxContainer
var _camera_hint: Label
var _camera_tween: Tween
var _chips: Control
var _shown := 0


func _ready() -> void:
	low_time_beat = false
	super()
	hide_timer()
	_photo_label = _text("", UiKit.BUTTON_FONT, 12)
	_photo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_photo_label)
	_top.move_child(_photo_label, 0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_top.add_child(row)
	_top.move_child(row, 1)
	_followers_label = _text("0", UiKit.BUTTON_FONT, 28)
	row.add_child(_followers_label)
	_gain_label = _text("", UiKit.BUTTON_FONT, 20, Palette.GOLD)
	_gain_label.modulate.a = 0.0
	row.add_child(_gain_label)
	_build_camera_message()
	marker = SelfieMarker.new()
	add_child(marker)
	_build_monitor()
	_chips = Control.new()
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_chips)
	shove_chip = ActionChip.new(&"shove", SHOVE_KEY_WORD)
	_chips.add_child(shove_chip)
	card = SelfieCard.new()
	add_child(card)
	roll = SelfieRoll.new()
	add_child(roll)


func set_photo(number: int, total: int) -> void:
	_photo_label.text = "FOTO %d/%d" % [number, total]


#Followers with the last gain next to them for a moment
func set_followers(total: int, gained: int) -> void:
	var from := _shown
	_shown = total
	create_tween().tween_method(_show_followers, float(from), float(total), 0.5)
	if gained <= 0:
		return
	_gain_label.text = "+%d" % gained
	_gain_label.modulate.a = 1.0
	_pulse(_followers_label, 1.25)
	var fade := create_tween()
	fade.tween_interval(1.1)
	fade.tween_property(_gain_label, "modulate:a", 0.0, 0.4)


#Two short lines when the drone moves to the next set
func announce_camera(set_name: String) -> void:
	_camera_hint.text = "ve a %s" % set_name
	monitor.set_title(set_name)
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_box.show()
	_camera_box.modulate.a = 0.0
	_camera_box.pivot_offset = _camera_box.size / 2.0
	_camera_box.scale = Vector2.ONE * 1.2
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.tween_property(_camera_box, "modulate:a", 1.0, CAMERA_IN).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera_box, "scale", Vector2.ONE, CAMERA_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.chain().tween_interval(CAMERA_HOLD)
	_camera_tween.chain().tween_property(_camera_box, "modulate:a", 0.0, CAMERA_OUT)
	_camera_tween.chain().tween_callback(_camera_box.hide)


#The photo comes out where the live picture was
func show_photo(photo: Texture2D, followers: int, inside: bool, posed: bool) -> void:
	card.play(photo, monitor.get_global_rect().position + Vector2(monitor.size.x - SelfieCard.CARD.x, 0.0), followers, inside, posed)


#End of round: the roll of every photo
func show_roll(photos: Array[Texture2D], numbers: Array[int]) -> void:
	card.clear()
	monitor.set_live(false)
	roll.show_roll(photos, numbers)


#Shove chip with its recharge
func set_shove_chip(shown: bool, charge: float, at: Vector2) -> void:
	shove_chip.set_charge(charge)
	shove_chip.set_shown(shown)
	if shown:
		shove_chip.place(at)


func press_shove() -> void:
	shove_chip.press()


func _show_followers(value: float) -> void:
	_followers_label.text = str(roundi(value))


func _build_camera_message() -> void:
	_camera_box = VBoxContainer.new()
	_camera_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera_box.add_theme_constant_override("separation", 2)
	_camera_box.hide()
	var title := _text("CÁMARA EN MOVIMIENTO", UiKit.BUTTON_FONT, 20, Palette.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_box.add_child(title)
	_camera_hint = _text("", UiKit.BODY_FONT, 22, Palette.GOLD)
	_camera_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_box.add_child(_camera_hint)
	_top.add_child(_camera_box)
	_top.move_child(_camera_box, 2)


func _build_monitor() -> void:
	monitor = SelfieMonitor.new()
	add_child(monitor)
	monitor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	monitor.offset_left = -SelfieMonitor.SHOWN.x - MONITOR_MARGIN
	monitor.offset_right = -MONITOR_MARGIN
	monitor.offset_top = MONITOR_MARGIN
	monitor.offset_bottom = MONITOR_MARGIN + SelfieMonitor.SHOWN.y
