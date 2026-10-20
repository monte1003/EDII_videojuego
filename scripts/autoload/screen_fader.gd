extends CanvasLayer

#The wipe that covers every change of screen, so all the transitions look the same

const WIPE_SHADER := preload("res://assets/ui/shaders/screen_wipe.gdshader")
const MARK := preload("res://assets/ui/textures/mark.png")
signal finished

const COVER_TIME := 0.36
const REVEAL_TIME := 0.36

var busy := false

var _wipe: ColorRect
var _mark: TextureRect
var _material := ShaderMaterial.new()


func _ready() -> void:
	layer = 100
	_material.shader = WIPE_SHADER
	_wipe = ColorRect.new()
	_wipe.material = _material
	_wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wipe)
	_mark = TextureRect.new()
	_mark.texture = MARK
	_mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mark.custom_minimum_size = MARK.get_size() * 1.5
	_mark.size = _mark.custom_minimum_size
	_mark.position = -_mark.size / 2.0
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.modulate.a = 0.0
	add_child(_mark)
	_material.set_shader_parameter("progress", 2.0)


#Covers the screen, loads the scene and uncovers the new one
func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	_wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	await _sweep(0.0, 1.0, COVER_TIME)
	_mark.modulate.a = 1.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _sweep(1.0, 2.0, REVEAL_TIME)
	_mark.modulate.a = 0.0
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	finished.emit()


func _sweep(from: float, to: float, seconds: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("progress", value), from, to, seconds)
	if to > 1.0:
		tween.parallel().tween_property(_mark, "modulate:a", 0.0, seconds * 0.6)
	await tween.finished
