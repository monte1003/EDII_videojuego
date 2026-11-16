class_name Word3D
extends RefCounted

#Words with volume for the comments of the maps: round chunky letters with a light face and deep coloured sides, cut from the font of
#the game, so a comment looks like a toy and not like text pasted on the screen. The letters keep the size and the curve step that cut
#every glyph of the words of the game cleanly (a coarser step breaks letters like the g)

const FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const SHADER: Shader = preload("res://assets/shaders/word_3d.gdshader")
const FONT_SIZE := 48
const FACE := Color("fdfbff")

static var _paints: Dictionary = {}


#A word whose letters are "height" meters tall, "depth" thick and no wider than "width" in all, centred on its origin and facing +Z
static func make(text: String, height: float, width: float, side: Color, depth := 0.16, face := FACE) -> MeshInstance3D:
	var word := MeshInstance3D.new()
	word.mesh = mesh_of(text, height, width, depth)
	word.material_override = paint(face, side)
	word.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return word


#The shape of a word: its size comes down when the whole word would be wider than "width"
static func mesh_of(text: String, height: float, width: float, depth: float) -> TextMesh:
	var mesh := TextMesh.new()
	mesh.text = text
	mesh.font = FONT
	mesh.font_size = FONT_SIZE
	var natural := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	mesh.pixel_size = minf(height / FONT_SIZE, width / maxf(natural, 1.0))
	mesh.depth = depth
	return mesh


#One material for each pair of colours, shared by every word that uses it
static func paint(face: Color, side: Color) -> ShaderMaterial:
	var key := face.to_html() + side.to_html()
	if not _paints.has(key):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("face", face)
		material.set_shader_parameter("side", side)
		_paints[key] = material
	return _paints[key]
