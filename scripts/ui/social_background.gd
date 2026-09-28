class_name SocialBackground
extends Control

const PATTERN := preload("res://assets/ui/textures/social_pattern.png")
const PATTERN_SHADER := preload("res://assets/ui/shaders/social_pattern.gdshader")

#Lado de la baldosa en unidades de lienzo y avance del patron por segundo: a la derecha y arriba
@export var tile_size := 540.0
@export var drift := Vector2(9.0, -13.0)
@export var strength := 0.2
#Se dibuja un poco mas grande que la pantalla para que al moverse no asome el borde
@export var overscan := 26.0

var _pattern: ShaderMaterial
var _offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = -overscan
	offset_top = -overscan
	offset_right = overscan
	offset_bottom = overscan
	_add_layer(_make_sky())
	_add_layer(_make_glow())
	_add_layer(_make_pattern())
	resized.connect(_on_resized)
	_on_resized()


#El avance se acumula aqui y no con TIME en el shader: da la vuelta justo en una baldosa y nunca salta
func _process(delta: float) -> void:
	_offset = (_offset + drift * delta).posmod(tile_size)
	_pattern.set_shader_parameter("offset", _offset)


func _on_resized() -> void:
	_pattern.set_shader_parameter("area", size)


func _add_layer(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)


#En diagonal, como la referencia: lavanda azulada arriba a la izquierda y melocoton abajo a la derecha
func _make_sky() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Palette.SKY_TOP)
	gradient.set_color(1, Palette.SKY_BOTTOM)
	gradient.add_point(0.5, Palette.SKY_MID)
	gradient.add_point(0.75, Palette.SKY_WARM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 128
	texture.height = 128
	return _make_rect(texture)


#Un halo claro a la izquierda, donde la referencia tiene la luz
func _make_glow() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.18))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.2, 0.55)
	texture.fill_to = Vector2(0.65, 0.55)
	texture.width = 256
	texture.height = 256
	return _make_rect(texture)


func _make_pattern() -> ColorRect:
	_pattern = ShaderMaterial.new()
	_pattern.shader = PATTERN_SHADER
	_pattern.set_shader_parameter("pattern", PATTERN)
	_pattern.set_shader_parameter("tint", Palette.PAPER)
	_pattern.set_shader_parameter("tile_size", tile_size)
	_pattern.set_shader_parameter("strength", strength)
	var rect := ColorRect.new()
	rect.material = _pattern
	rect.color = Color(1, 1, 1, 1)
	return rect



func _make_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	return rect
