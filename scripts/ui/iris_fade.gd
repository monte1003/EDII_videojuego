class_name IrisFade
extends CanvasLayer

#Hides a jump of the camera, as when a player falls off the map and comes back: the picture closes into a circle toward the middle of the
#screen, stays dark a moment and opens again where the player is now

#The picture starts closing: the player of this screen fell
signal closing

const SHADER: Shader = preload("res://assets/ui/shaders/iris.gdshader")
const OPEN := 1.3

var _cover: ColorRect
var _paint: ShaderMaterial
var _tween: Tween
var _closed := false


func _init() -> void:
	layer = 7
	_cover = ColorRect.new()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paint = ShaderMaterial.new()
	_paint.shader = SHADER
	_paint.set_shader_parameter("radius", OPEN)
	_cover.material = _paint
	_cover.visible = false
	add_child(_cover)


func close(seconds := 0.32) -> void:
	if _closed:
		return
	_closed = true
	closing.emit()
	_animate(0.0, seconds, Tween.EASE_IN, 0.0)
	SynthSound.play(self, SynthSound.whoosh(seconds + 0.1), -14.0, 0.8)


func open(seconds := 0.5, delay := 0.15) -> void:
	if not _closed:
		return
	_closed = false
	_animate(OPEN, seconds, Tween.EASE_OUT, delay)


func is_closed() -> bool:
	return _closed


func _animate(target: float, seconds: float, ease_type: Tween.EaseType, delay: float) -> void:
	var view := _cover.get_viewport_rect().size
	_paint.set_shader_parameter("aspect", view.x / maxf(view.y, 1.0))
	_cover.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_method(func(value: float) -> void: _paint.set_shader_parameter("radius", value),
		float(_paint.get_shader_parameter("radius")), target, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	if target >= OPEN:
		_tween.tween_callback(func() -> void: _cover.visible = false)
