class_name SelfieCard
extends Control

#The photo that was just taken, as an instant photo with a white edge and the followers it gave as its only text. It shows where the
#live picture was for a moment, then shrinks into a small copy in the corner that stays until the next photo

const EDGE := 8.0
const PICTURE := Vector2(224.0, 126.0)
const CAPTION := 34.0
const CARD := Vector2(PICTURE.x + EDGE * 2.0, PICTURE.y + EDGE + CAPTION)
const IN_TIME := 0.15
const HOLD := 1.2
const SHRINK_TIME := 0.35
#The small copy: its width on screen, and how far it stays from the corner
const SMALL := 120.0
const CORNER_ROOM := 26.0

var _card: Panel
var _picture: TextureRect
var _number: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	size = CARD
	_card = Panel.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size = CARD
	var style := UiKit.box(Palette.PAPER, 6)
	style.shadow_color = Color(Palette.NIGHT, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)
	_picture = TextureRect.new()
	_picture.position = Vector2(EDGE, EDGE)
	_picture.size = PICTURE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_picture)
	_number = UiKit.label("", UiKit.BUTTON_FONT, 22, Palette.INK)
	_number.position = Vector2(0.0, EDGE + PICTURE.y)
	_number.size = Vector2(CARD.x, CAPTION)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_child(_number)


#"at" is the top left corner where the card shows first; "followers" is what the photo gave (0 when the player did not come out)
func play(photo: Texture2D, at: Vector2, followers: int, inside: bool, posed: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_picture.texture = photo
	_number.text = "+%d" % followers if inside else "fuera"
	_number.add_theme_color_override("font_color", Palette.CORAL if posed else (Palette.INK if inside else Palette.INK_SOFT))
	visible = true
	position = at
	scale = Vector2.ONE * 0.92
	modulate.a = 0.0
	var screen := get_viewport_rect().size
	var corner := Vector2(screen.x - SMALL - CORNER_ROOM, screen.y - CARD.y * SMALL / CARD.x - CORNER_ROOM)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, IN_TIME)
	_tween.tween_property(self, "scale", Vector2.ONE, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(self, "position", corner, SHRINK_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * SMALL / CARD.x, SHRINK_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	SynthSound.play(self, SynthSound.tone(660.0, 0.2, 380.0, 0.35), -11.0)


#The small copy goes away (the end of the round shows them all)
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(hide)


#Where the card is on the screen now, in pixels of the canvas
func shown_rect() -> Rect2:
	return Rect2(position, CARD * scale)
