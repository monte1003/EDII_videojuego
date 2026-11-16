class_name SelfieCamera
extends Node

#The camera of the drone, over the same world the players see: a small live picture of the set while a photo is coming, and the
#photo itself, drawn once at the shot in a bigger picture of its own. Both look with an isometric view (orthogonal, tilted and
#turned 45 degrees from the frame) into the back corner of the set, and leave out what only guides the players

signal developed(index: int, photo: Texture2D)

#Render layers of what the photo leaves out: the frame on the floor and the beam of the drone (the live picture keeps them), the
#guides of each player (nobody's camera of the drone shows them) and the arrow over each player that only the live picture shows
const FRAME_LAYER := 11
const GUIDE_LAYER := 12
const MONITOR_LAYER := 13
const PHOTO_PIXELS := Vector2i(960, 540)
const PREVIEW_PIXELS := Vector2i(480, 270)
const PREVIEW_RATE := 20.0
#The photo keeps at least this patch of floor around the middle of the frame, with this room around what it shows
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


#The view of a photo: the frame of "frame_side" meters around "center" when nobody is in it, or else everybody whose feet are in
#"feet" with a little floor around the middle. "turn_degrees" says from which corner it looks
static func compose(center: Vector3, feet: Array[Vector3], turn_degrees: float, frame_side: float, aspect := 16.0 / 9.0) -> IsoFrame:
	var patch := Vector2.ONE * (PATCH if not feet.is_empty() else frame_side)
	return IsoFrame.fit(center, patch, feet, aspect, 0.0, IsoFrame.DEFAULT_PITCH, turn_degrees, MARGIN)


func preview_texture() -> Texture2D:
	return _preview_view.get_texture()


#The live picture draws (20 times a second) only while a photo is coming
func set_live(on: bool) -> void:
	_live = on
	_since = 1.0
	if not on:
		_preview_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_live() -> bool:
	return _live


#Points the live picture at the frame as it is now, with the frame drawn on the floor. "clip" is how far in front of the middle of
#the frame it still draws things: what stands closer to the drone (a catwalk between it and the set) is left out
func aim(center: Vector3, frame_side: float, turn_degrees: float, clip: float) -> void:
	var view := compose(center, [], turn_degrees, frame_side, float(PREVIEW_PIXELS.x) / PREVIEW_PIXELS.y)
	view.apply(_preview_camera)
	_preview_camera.near = clip_near(clip)


#The shot: the photo is drawn once with this view and comes out as a picture of its own when the frame is done. With no screen
#nothing is drawn, and the photo comes out at once
func take(index: int, view: IsoFrame, clip: float) -> void:
	view.apply(_photo_camera)
	_photo_camera.near = clip_near(clip)
	if DisplayServer.get_name() == "headless":
		developed.emit.call_deferred(index, _develop())
		return
	_photo_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	developed.emit(index, _develop())


#The near plane of a camera of the drone that draws only what is less than "clip" meters in front of the middle of its view
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


#A still copy of the photo with its smaller sizes ready, so it shrinks on screen without flicker. With no screen nothing is drawn,
#and the photo is a plain picture of the same size
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
