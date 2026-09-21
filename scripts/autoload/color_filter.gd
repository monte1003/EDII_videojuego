extends CanvasLayer

const MODE_NAMES: Array[String] = ["Ninguno", "Protanopía", "Deuteranopía", "Tritanopía"]
const FILTER_SHADER := preload("res://assets/ui/shaders/color_blind.gdshader")

var mode := 0

var _overlay: ColorRect


func _ready() -> void:
	layer = 128
	var material := ShaderMaterial.new()
	material.shader = FILTER_SHADER
	_overlay = ColorRect.new()
	_overlay.material = material
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.hide()
	add_child(_overlay)


#The overlay only draws while a filter is on, so it costs nothing when nobody needs it
func set_mode(new_mode: int) -> void:
	mode = clampi(new_mode, 0, MODE_NAMES.size() - 1)
	_overlay.visible = mode > 0
	if mode > 0:
		(_overlay.material as ShaderMaterial).set_shader_parameter("mode", mode)
