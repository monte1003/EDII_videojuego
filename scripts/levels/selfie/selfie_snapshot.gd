class_name SelfieSnapshot
extends Control

#The photo that was just taken: the real picture of the viewfinder in an instant photo with a white edge. It comes out of the
#viewfinder, gets closer and bigger until it settles in front of the screen, stays about two seconds with the followers it gave
#as the only text and leaves with a movement of its own. One tween, one focus of movement; the number comes in a little later

const CARD := Vector2(430.0, 306.0)
const EDGE := 14.0
const PICTURE := Vector2(402.0, 226.0)
const SKEW := -0.06
const ANTICIPATE := 0.09
const TRAVEL := 0.5
const SETTLE := 0.14
const LEAVE := 0.4
const NUMBER_DELAY := 0.5
const COUNT_TIME := 0.55
const HOLD := 2.0
const SHADOW_FROM := 6
const SHADOW_TO := 26

var _holder: Control
var _card: Panel
var _style: StyleBoxFlat
var _picture: TextureRect
var _number: Label
var _tween: Tween
var _count: Tween
var _playing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_card = Panel.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size = CARD
	_card.position = -CARD / 2.0
	_style = UiKit.box(Palette.PAPER, 6)
	_style.shadow_color = Color(Palette.NIGHT, 0.4)
	_style.shadow_size = SHADOW_FROM
	_style.shadow_offset = Vector2(0.0, 6.0)
	_card.add_theme_stylebox_override("panel", _style)
	_holder.add_child(_card)
	_picture = TextureRect.new()
	_picture.position = Vector2(EDGE, EDGE)
	_picture.size = PICTURE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_picture)
	_number = UiKit.label("", UiKit.BUTTON_FONT, 56, Palette.INK)
	_number.position = Vector2(0.0, EDGE + PICTURE.y)
	_number.size = Vector2(CARD.x, CARD.y - EDGE - PICTURE.y)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.modulate.a = 0.0
	_card.add_child(_number)


func is_playing() -> bool:
	return _playing


#"from" is where the viewfinder is on the screen, "followers" what the photo gave (0 when the player did not come out)
func play(photo: Texture2D, from: Rect2, followers: int, inside: bool, posed: bool, hold := HOLD) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _count != null and _count.is_valid():
		_count.kill()
	_picture.texture = photo
	_number.text = ""
	_number.modulate.a = 0.0
	_number.add_theme_color_override("font_color", Palette.CORAL if posed else Palette.INK)
	_number.add_theme_font_size_override("font_size", 56 if inside else 30)
	visible = true
	_playing = true
	var screen := get_viewport_rect().size
	var target := Vector2(screen.x * 0.5, screen.y * 0.47)
	var start_scale := from.size.x / PICTURE.x
	#The picture of the card sits over the viewfinder at the start
	var picture_center := Vector2(0.0, EDGE + PICTURE.y / 2.0 - CARD.y / 2.0)
	_holder.position = from.get_center() - picture_center * start_scale
	_holder.scale = Vector2.ONE * start_scale
	_holder.rotation = 0.0
	_holder.modulate.a = 1.0
	_style.shadow_size = SHADOW_FROM
	SynthSound.play(self, SynthSound.tone(520.0, 0.12, 380.0, 0.35), -10.0)
	_tween = create_tween()
	#Anticipation: a small step back before it comes
	_tween.tween_property(_holder, "scale", Vector2.ONE * start_scale * 0.94, ANTICIPATE).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(true)
	_tween.tween_property(_holder, "position", target, TRAVEL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_holder, "scale", Vector2.ONE * 1.04, TRAVEL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_holder, "rotation", SKEW, TRAVEL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_shadow, float(SHADOW_FROM), float(SHADOW_TO), TRAVEL)
	_tween.chain().tween_callback(_land)
	_tween.tween_property(_holder, "scale", Vector2.ONE, SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(_show_number.bind(followers, inside))
	_tween.tween_interval(hold)
	#It leaves toward the corner it came from, tilting and fading
	_tween.chain().tween_property(_holder, "position", target + Vector2(screen.x * 0.4, -screen.y * 0.55), LEAVE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_holder, "rotation", 0.2, LEAVE).set_ease(Tween.EASE_IN)
	_tween.tween_property(_holder, "modulate:a", 0.0, LEAVE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_finish)


func _set_shadow(value: float) -> void:
	_style.shadow_size = roundi(value)


func _land() -> void:
	SynthSound.play(self, SynthSound.thump(0.1), -14.0, 1.7)
	SynthSound.play(self, SynthSound.tone(988.0, 0.16, 0.0, 0.3), -12.0)


#The number is the only text: it counts up from zero, and a photo without the player is just "fuera"
func _show_number(followers: int, inside: bool) -> void:
	if not inside:
		_number.text = "fuera"
		_number.modulate.a = 0.0
		create_tween().tween_property(_number, "modulate:a", 0.75, 0.25)
		return
	_number.text = "+0"
	_number.pivot_offset = _number.size / 2.0
	_number.modulate.a = 1.0
	_number.scale = Vector2.ONE * 0.7
	_count = create_tween().set_parallel(true)
	_count.tween_method(_count_to.bind(followers), 0.0, 1.0, COUNT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count.tween_property(_number, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SynthSound.play(self, SynthSound.tone(660.0, 0.3, 480.0, 0.35), -10.0)


func _count_to(share: float, followers: int) -> void:
	_number.text = "+%d" % roundi(followers * share)


func _finish() -> void:
	visible = false
	_playing = false
