class_name SelfieCamera
extends Node

#Drone camera: live picture while a photo comes and the photo drawn once, both isometric

signal developed(index: int, photo: Texture2D)

#Render layers the photo leaves out: frame, beam, guides and the live-only arrow
const FRAME_LAYER := 11
const GUIDE_LAYER := 12
const MONITOR_LAYER := 13
const PHOTO_PIXELS := Vector2i(960, 540)
const PREVIEW_PIXELS := Vector2i(480, 270)
const PREVIEW_RATE := 20.0
#Floor patch kept around the frame middle and the margin
const PATCH := 2.0
const MARGIN := 1.08

var _photo_view: SubViewport
var _photo_camera: Camera3D
var _preview_view: SubViewport
var _preview_camera: Camera3D
var _live := false
var _since := 0.0


func _ready() -> void:
	_photo_view = _make_view(PHOTO_PIXELS, Viewport.MSAA_2X)
	_photo_camera = _make_camera(_photo_view, ~(layer_bit(FRAME_LAYER) | layer_bit(GUIDE_LAYER) | layer_bit(MONITOR_LAYER)))
	_preview_view = _make_view(PREVIEW_PIXELS, Viewport.MSAA_DISABLED)
	_preview_camera = _make_camera(_preview_view, ~layer_bit(GUIDE_LAYER))


static func layer_bit(layer: int) -> int:
	return 1 << (layer - 1)


#Photo view: the empty frame, or everybody inside with floor around
static func compose(center: Vector3, feet: Array[Vector3], turn_degrees: float, frame_side: float, aspect := 16.0 / 9.0) -> IsoFrame:
	var patch := Vector2.ONE * (PATCH if not feet.is_empty() else frame_side)
	return IsoFrame.fit(center, patch, feet, aspect, 0.0, IsoFrame.DEFAULT_PITCH, turn_degrees, MARGIN)


func preview_texture() -> Texture2D:
	return _preview_view.get_texture()


#The live picture draws 20 times a second only while a photo comes
func set_live(on: bool) -> void:
	_live = on
	_since = 1.0
	if not on:
		_preview_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_live() -> bool:
	return _live


#Aims the live picture; "clip" leaves out what stands closer to the drone
func aim(center: Vector3, frame_side: float, turn_degrees: float, clip: float) -> void:
	var view := compose(center, [], turn_degrees, frame_side, float(PREVIEW_PIXELS.x) / PREVIEW_PIXELS.y)
	view.apply(_preview_camera)
	_preview_camera.near = clip_near(clip)


#Draws the photo once; headless it comes out at once
func take(index: int, view: IsoFrame, clip: float) -> void:
	view.apply(_photo_camera)
	_photo_camera.near = clip_near(clip)
	if DisplayServer.get_name() == "headless":
		developed.emit.call_deferred(index, _develop())
		return
	_photo_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	developed.emit(index, _develop())


#Near plane that draws only "clip" meters in front of the view middle
static func clip_near(clip: float) -> float:
	return clampf(IsoFrame.DISTANCE - clip, 0.5, IsoFrame.DISTANCE)


func photo_camera() -> Camera3D:
	return _photo_camera


func _process(delta: float) -> void:
	if not _live:
		return
	_since += delta
	if _since >= 1.0 / PREVIEW_RATE:
		_since = 0.0
		_preview_view.render_target_update_mode = SubViewport.UPDATE_ONCE


#Still copy with mipmaps so it shrinks without flicker
func _develop() -> Texture2D:
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		image = _photo_view.get_texture().get_image()
	if image == null or image.is_empty():
		image = Image.create(PHOTO_PIXELS.x, PHOTO_PIXELS.y, false, Image.FORMAT_RGBA8)
		image.fill(Palette.PAPER)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _make_view(pixels: Vector2i, msaa: Viewport.MSAA) -> SubViewport:
	var view := SubViewport.new()
	view.size = pixels
	view.msaa_3d = msaa
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.gui_disable_input = true
	add_child(view)
	return view


func _make_camera(view: SubViewport, mask: int) -> Camera3D:
	var camera := Camera3D.new()
	camera.cull_mask = mask & 0xFFFFF
	view.add_child(camera)
	camera.current = true
	return camera
