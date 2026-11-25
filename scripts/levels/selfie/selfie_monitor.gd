class_name SelfieMonitor
extends Control

#Drone live picture in a corner with viewfinder corners, a beating dot and the set name

const SHOWN := Vector2(240.0, 135.0)
const CORNER := 18.0
const LINE := 3.0
const FADE := 0.2
const FLASH := 0.1
const TITLE_SIZE := 13

var _picture: TextureRect
var _white: ColorRect
var _live := false
var _clock := 0.0
var _title := ""
var _fade: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SHOWN
	size = SHOWN
	visible = false
	modulate.a = 0.0
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.size = SHOWN
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	_white = ColorRect.new()
	_white.color = Color(1.0, 1.0, 1.0, 0.0)
	_white.size = SHOWN
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_white)


func show_feed(feed: Texture2D) -> void:
	_picture.texture = feed


func set_title(text: String) -> void:
	_title = text
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	queue_redraw()


func _draw() -> void:
	#Viewfinder corners with a dark edge
	for pass_index in 2:
		var color := Color(Palette.NIGHT, 0.7) if pass_index == 0 else Palette.PAPER
		var width := LINE + 3.0 if pass_index == 0 else LINE
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var at := Vector2(corner.x * SHOWN.x, corner.y * SHOWN.y)
			var along := Vector2(-1.0 if corner.x == 1.0 else 1.0, 0.0) * CORNER
			var down := Vector2(0.0, -1.0 if corner.y == 1.0 else 1.0) * CORNER
			draw_polyline(PackedVector2Array([at + along, at, at + down]), color, width, true)
	if _live:
		var beat := 0.45 + 0.55 * absf(sin(_clock * 4.0))
		draw_circle(Vector2(CORNER + 8.0, CORNER + 8.0), 6.0, Color(Palette.NIGHT, 0.6))
		draw_circle(Vector2(CORNER + 8.0, CORNER + 8.0), 4.5, Color(Palette.CORAL, beat))
	if _title != "":
		#Set name on a dark band like a broadcast caption
		var width := UiKit.BUTTON_FONT.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
		var band := Rect2(Vector2(10.0, SHOWN.y - 30.0), Vector2(width + 20.0, 22.0))
		draw_rect(band, Color(Palette.NIGHT, 0.72), true)
		draw_rect(Rect2(band.position, Vector2(4.0, band.size.y)), Palette.CORAL, true)
		draw_string(UiKit.BUTTON_FONT, band.position + Vector2(12.0, 16.0), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Palette.PAPER)


#In while a photo comes, out at the shot
func set_live(on: bool) -> void:
	if on == _live:
		return
	_live = on
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	if on:
		visible = true
		_fade.tween_property(self, "modulate:a", 1.0, FADE)
	else:
		_fade.tween_property(self, "modulate:a", 0.0, FADE)
		_fade.tween_callback(hide)


#A tenth of a second of white
func flash() -> void:
	_white.color.a = 0.95
	create_tween().tween_property(_white, "color:a", 0.0, FLASH)
