class_name SelfieHud
extends RoundHud

#The selfie screen: which photo it is, very small, and your followers. The rest is information that lives in the world and shows only
#when it matters: the viewfinder of the drone with its live picture, the message that tells the camera is moving, the photo that
#comes out of the viewfinder at the shot, and the chips of the two actions (pose and shove) near the player or over the rival

const CAMERA_HOLD := 2.4
const CAMERA_IN := 0.24
const CAMERA_OUT := 0.4
const VISOR_MARGIN := 28.0
const SHOVE_KEY_WORD := "empujar"

var viewfinder: SelfieViewfinder
var snapshot: SelfieSnapshot
var pose_chip: ActionChip
var shove_chip: ActionChip

var _photo_label: Label
var _followers_label: Label
var _gain_label: Label
var _camera_box: VBoxContainer
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
	_build_viewfinder()
	_chips = Control.new()
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_chips)
	pose_chip = ActionChip.new(InputHints.key_label(&"interact"), "posar")
	shove_chip = ActionChip.new(InputHints.key_label(&"shove"), SHOVE_KEY_WORD)
	_chips.add_child(pose_chip)
	_chips.add_child(shove_chip)
	snapshot = SelfieSnapshot.new()
	add_child(snapshot)


func set_photo(number: int, total: int) -> void:
	_photo_label.text = "FOTO %d/%d" % [number, total]


#Your followers, with what the last photo added next to them for a moment
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


#The drone sets off for the next place: two short lines at the top say the camera moves and to go toward it
func announce_camera() -> void:
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


#The shot: the last picture of the viewfinder comes out as a photo that gets close, stays and leaves
func reveal_photo(followers: int, inside: bool, posed: bool, hold := SelfieSnapshot.HOLD) -> void:
	var photo := viewfinder.snapshot()
	var from := viewfinder.get_global_rect()
	viewfinder.dismiss()
	snapshot.play(photo, from, followers, inside, posed, hold)


#The chip of the pose: near the player while the frame is there; lit while posing
func set_pose_chip(shown: bool, posing: bool, at: Vector2) -> void:
	pose_chip.set_word("soltar" if posing else "posar", posing)
	pose_chip.set_shown(shown)
	if shown:
		pose_chip.place(at)


#The chip of the shove: over the rival in reach or near the player, with its recharge
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
	var hint := _text("ve hacia ella", UiKit.BODY_FONT, 22, Palette.GOLD)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_box.add_child(hint)
	_top.add_child(_camera_box)
	_top.move_child(_camera_box, 2)


func _build_viewfinder() -> void:
	viewfinder = SelfieViewfinder.new()
	add_child(viewfinder)
	viewfinder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	viewfinder.offset_left = -SelfieViewfinder.SHOWN.x - VISOR_MARGIN
	viewfinder.offset_right = -VISOR_MARGIN
	viewfinder.offset_top = VISOR_MARGIN
	viewfinder.offset_bottom = VISOR_MARGIN + SelfieViewfinder.SHOWN.y
