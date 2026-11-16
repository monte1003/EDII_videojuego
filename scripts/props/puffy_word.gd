class_name PuffyWord
extends RefCounted

#Fixed words of the big moments in chunky round letters, like the title of the game, made in Blender from its font: one node per letter
#with its origin at its middle, so each letter can drop and bounce on its own. Each word comes in the colours of what it names

const FOLDER := "res://assets/words/%s.glb"
const SHADER: Shader = preload("res://assets/shaders/puffy_word.gdshader")
#Height of a capital letter of the files, in their own meters
const CAP := 0.72

#Light top, deep bottom and darker sides of each set of colours
const COLOURS := {
	&"bronze": [Color("ffd2a8"), Color("d9772e"), Color("8a4a1c")],
	&"silver": [Color("ffffff"), Color("b9c6dc"), Color("66748f")],
	&"gold": [Color("fff4a8"), Color("ffb21f"), Color("c0620e")],
	&"diamond": [Color("f0feff"), Color("6fd8ff"), Color("3a86e0")],
	&"title": [Color("a6ecff"), Color("3aa6f0"), Color("2f72d8")],
	&"party": [Color("ffc0a8"), Color("f0509e"), Color("9a3cc0")],
}

static var _paints: Dictionary = {}


#A word "height" meters tall in one set of colours; the letters are the children of the node it returns
static func make(word: StringName, height: float, colours: StringName, glow := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = String(word)
	var source := load(FOLDER % word) as PackedScene
	if source == null:
		push_error("PuffyWord: falta la palabra %s" % word)
		return root
	var scene := source.instantiate()
	var paint := paint_of(colours, glow)
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		var letter := mesh as MeshInstance3D
		var holder := Node3D.new()
		holder.name = letter.name
		holder.position = letter.position
		root.add_child(holder)
		var copy := MeshInstance3D.new()
		copy.mesh = letter.mesh
		copy.material_override = paint
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(copy)
	scene.free()
	root.scale = Vector3.ONE * height / CAP
	return root


static func letters(word: Node3D) -> Array[Node3D]:
	var list: Array[Node3D] = []
	for child in word.get_children():
		list.append(child as Node3D)
	return list


static func paint_of(colours: StringName, glow: float) -> ShaderMaterial:
	var key := "%s_%s" % [colours, glow]
	if not _paints.has(key):
		var trio: Array = COLOURS.get(colours, COLOURS[&"title"])
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("top", trio[0])
		material.set_shader_parameter("bottom", trio[1])
		material.set_shader_parameter("side", trio[2])
		material.set_shader_parameter("span", CAP * 1.1)
		material.set_shader_parameter("glow", glow)
		_paints[key] = material
	return _paints[key]
