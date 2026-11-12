class_name SelfieHud
extends RoundHud

#The selfie screen: which photo it is, very small, and your followers. After each shot a little instant photo shows who came out

const PHOTO_SIZE := Vector2(132, 150)
const FACE := 34.0

var _photo_label: Label
var _followers_label: Label
var _gain_label: Label
var _print: Control
var _print_faces: HBoxContainer
var _print_caption: Label
var _print_tween: Tween
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
	_build_print()


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


#The instant photo: the faces of the players that came out, a dark dot for each bot, and whether you are in it
func show_print(faces: Array[Texture2D], bots: int, caption: String, seconds: float) -> void:
	for child in _print_faces.get_children():
		child.queue_free()
	for texture in faces:
		var face := TextureRect.new()
		face.texture = texture
		face.custom_minimum_size = Vector2.ONE * FACE
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_print_faces.add_child(face)
	for index in bots:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2.ONE * FACE * 0.7
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UiKit.box(Palette.INK, int(FACE)))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_print_faces.add_child(dot)
	_print_caption.text = caption
	if _print_tween != null and _print_tween.is_valid():
		_print_tween.kill()
	_print.show()
	_print.modulate.a = 1.0
	_print.scale = Vector2.ONE * 0.4
	_print.rotation = -0.3
	_print_tween = create_tween()
	_print_tween.tween_property(_print, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_print_tween.parallel().tween_property(_print, "rotation", -0.09, 0.25)
	_print_tween.tween_interval(maxf(seconds - 0.6, 0.2))
	_print_tween.tween_property(_print, "modulate:a", 0.0, 0.3)
	_print_tween.tween_callback(_print.hide)


func _show_followers(value: float) -> void:
	_followers_label.text = str(roundi(value))


#A white print with a dark picture, in the top right corner, away from the middle of the screen
func _build_print() -> void:
	_print = Control.new()
	_print.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_print.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_print.offset_left = -PHOTO_SIZE.x - 34.0
	_print.offset_right = -34.0
	_print.offset_top = 30.0
	_print.offset_bottom = 30.0 + PHOTO_SIZE.y
	_print.pivot_offset = PHOTO_SIZE / 2.0
	_print.hide()
	add_child(_print)
	var paper := Panel.new()
	paper.size = PHOTO_SIZE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_style := UiKit.box(Palette.PAPER, 8)
	paper_style.shadow_size = 8
	paper_style.shadow_color = Color(Palette.NIGHT, 0.35)
	paper.add_theme_stylebox_override("panel", paper_style)
	_print.add_child(paper)
	var picture := Panel.new()
	picture.position = Vector2(10, 10)
	picture.size = Vector2(PHOTO_SIZE.x - 20.0, PHOTO_SIZE.y - 52.0)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_theme_stylebox_override("panel", UiKit.box(Color("3a3160"), 4))
	_print.add_child(picture)
	var middle := CenterContainer.new()
	middle.position = picture.position
	middle.size = picture.size
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_print.add_child(middle)
	_print_faces = HBoxContainer.new()
	_print_faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_print_faces.add_theme_constant_override("separation", 4)
	middle.add_child(_print_faces)
	_print_caption = UiKit.label("", UiKit.BUTTON_FONT, 13, Palette.INK)
	_print_caption.position = Vector2(0.0, PHOTO_SIZE.y - 36.0)
	_print_caption.size = Vector2(PHOTO_SIZE.x, 28.0)
	_print_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_print_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_print.add_child(_print_caption)
