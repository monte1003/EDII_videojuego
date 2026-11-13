class_name SelfieViewfinder
extends Control

#The viewfinder of the drone: a small live picture of what its camera sees over the place of the photo, with the corners of a
#viewfinder and a red dot that beats. It only draws while there is a photo going on; at the shot the last picture stays and
#becomes the photo. Every screen has its own, over the same world

const PIXELS := Vector2i(320, 180)
const SHOWN := Vector2(236.0, 133.0)
const FRAME_RATE := 15.0
const CORNER := 20.0
const LINE := 3.0
const FADE := 0.25
#The camera looks from this far (a share of the side of the frame) and this high and back
const BACK := 1.5
const LIFT := 1.05
const MIN_BACK := 8.0

var _view: SubViewport
var _camera: Camera3D
var _picture: TextureRect
var _active := false
var _clock := 0.0
var _since := 0.0
var _fade: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SHOWN
	size = SHOWN
	visible = false
	modulate.a = 0.0
	_view = SubViewport.new()
	_view.size = PIXELS
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.gui_disable_input = true
	_view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_view)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	_view.add_child(_camera)
	_camera.make_current()
	_picture = TextureRect.new()
	_picture.texture = _view.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.size = SHOWN
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if _active:
		_since += delta
		if _since >= 1.0 / FRAME_RATE:
			_since = 0.0
			_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()


func _draw() -> void:
	#The corners of a viewfinder, with a dark edge so they read over any picture
	for pass_index in 2:
		var color := Color(Palette.NIGHT, 0.7) if pass_index == 0 else Palette.PAPER
		var width := LINE + 3.0 if pass_index == 0 else LINE
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var at := Vector2(corner.x * SHOWN.x, corner.y * SHOWN.y)
			var along := Vector2(-1.0 if corner.x == 1.0 else 1.0, 0.0) * CORNER
			var down := Vector2(0.0, -1.0 if corner.y == 1.0 else 1.0) * CORNER
			draw_polyline(PackedVector2Array([at + along, at, at + down]), color, width, true)
	#The red dot beats while it records
	if _active:
		var beat := 0.45 + 0.55 * absf(sin(_clock * 4.0))
		draw_circle(Vector2(CORNER + 8.0, CORNER + 8.0), 6.0, Color(Palette.NIGHT, 0.6))
		draw_circle(Vector2(CORNER + 8.0, CORNER + 8.0), 4.5, Color(0.96, 0.2, 0.28, beat))


#Looks at the place of the photo from above and behind, far enough for the whole frame to fit
func aim(center: Vector3, side: float) -> void:
	var back := maxf(side * BACK, MIN_BACK)
	_camera.global_position = center + Vector3(0.0, back * LIFT, back)
	_camera.look_at(center + Vector3(0.0, 0.3, 0.0), Vector3.UP)
	var half := side * 0.75
	_camera.fov = clampf(rad_to_deg(2.0 * atan2(half, back * 1.3)), 28.0, 62.0)


#Starts drawing (with a fade in) or stops (the last picture stays where it is)
func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if on:
		visible = true
		_since = 1.0
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 1.0, FADE)
	else:
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


#The last picture as a photo that stays the same from now on
func snapshot() -> Texture2D:
	#With no screen there is no picture to copy
	if DisplayServer.get_name() == "headless":
		return _view.get_texture()
	var image := _view.get_texture().get_image()
	if image == null or image.is_empty():
		return _view.get_texture()
	return ImageTexture.create_from_image(image)


#It goes away after the photo left it
func dismiss() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_active = false
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, FADE)
	_fade.tween_callback(hide)


func is_active() -> bool:
	return _active
