class_name TrendCatalog
extends RefCounted

#The six kinds of thing a trend is made of. Each one has its own colour, its own toy inside the bubble and its own drawing,
#so they are told apart by colour, by shape and by icon

enum Kind { AUDIO, FILTER, STICKER, HASHTAG, GOSSIP, PET }

const COUNT := 6
const NAMES: Array[String] = ["Audio", "Filtro", "Sticker", "Hashtag", "Chisme", "Mascota"]
#One main colour each, spread around the colour wheel: cyan, violet, yellow, red, magenta and green
const COLORS: Array[Color] = [Color("2fc4ee"), Color("5b3fe6"), Color("ffc928"), Color("f2483e"), Color("ea4fc2"), Color("3fcf86")]
const PROPS: Array[StringName] = [&"speaker", &"camera", &"sticker", &"hashtag", &"gossip_cup", &"cat_head"]
#Turns of the colour wheel that bring each toy to the colour of its kind, and how much more colour it gets
const HUES: Array[float] = [0.0, -0.31, 0.0, 0.0, -0.14, 0.0]
const TONE: Shader = preload("res://assets/shaders/citizen_tone.gdshader")

static var _tones: Dictionary = {}


#The toy of a kind, "height" meters tall and in the main colour of its kind; the bubbles and the icons use the very same one
static func make_toy(kind: int, height: float) -> Node3D:
	var toy := PropKit.make_tall(PROPS[kind], height, Color.WHITE, false)
	for node in toy.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var base := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if base == null or base.albedo_texture == null:
				continue
			var key := "%d_%d" % [kind, base.albedo_texture.get_instance_id()]
			if not _tones.has(key):
				var tone := ShaderMaterial.new()
				tone.shader = TONE
				tone.set_shader_parameter("albedo_tex", base.albedo_texture)
				tone.set_shader_parameter("hue_shift", HUES[kind])
				tone.set_shader_parameter("saturation", 1.2)
				_tones[key] = tone
			mesh.set_surface_override_material(surface, _tones[key])
	return toy


#Draws the icon of a kind in "color", centred and fitted in a circle of "radius"
static func draw_icon(canvas: CanvasItem, kind: int, center: Vector2, radius: float, color: Color) -> void:
	var line := maxf(radius * 0.16, 1.5)
	match kind:
		Kind.AUDIO:
			#A speaker box with its two cones
			canvas.draw_rect(Rect2(center + Vector2(-0.5, -0.82) * radius, Vector2(1.0, 1.64) * radius), color, false, line)
			canvas.draw_circle(center + Vector2(0.0, -0.38) * radius, radius * 0.2, color)
			canvas.draw_arc(center + Vector2(0.0, 0.3) * radius, radius * 0.3, 0.0, TAU, 20, color, line, true)
		Kind.FILTER:
			#A lens: a ring, the glass and its shine
			canvas.draw_arc(center, radius * 0.78, 0.0, TAU, 32, color, line, true)
			canvas.draw_circle(center, radius * 0.4, color)
			canvas.draw_arc(center, radius * 0.56, PI * 1.1, PI * 1.5, 10, color, line * 0.7, true)
		Kind.STICKER:
			var star := PackedVector2Array()
			for step in 10:
				var angle := -PI / 2.0 + PI * step / 5.0
				star.append(center + Vector2(cos(angle), sin(angle)) * radius * (0.95 if step % 2 == 0 else 0.44))
			canvas.draw_colored_polygon(star, color)
		Kind.HASHTAG:
			for offset: float in [-0.32, 0.32]:
				canvas.draw_line(center + Vector2(offset + 0.12, -0.85) * radius, center + Vector2(offset - 0.12, 0.85) * radius, color, line * 1.2, true)
				canvas.draw_line(center + Vector2(-0.85, offset) * radius, center + Vector2(0.85, offset) * radius, color, line * 1.2, true)
		Kind.GOSSIP:
			#A cup with its handle and two wisps of steam
			var cup := PackedVector2Array([center + Vector2(-0.62, -0.05) * radius, center + Vector2(0.42, -0.05) * radius,
				center + Vector2(0.3, 0.8) * radius, center + Vector2(-0.5, 0.8) * radius])
			canvas.draw_colored_polygon(cup, color)
			canvas.draw_arc(center + Vector2(0.48, 0.3) * radius, radius * 0.26, -PI / 2.0, PI / 2.0, 12, color, line, true)
			for offset: float in [-0.32, 0.12]:
				canvas.draw_polyline(PackedVector2Array([center + Vector2(offset, -0.25) * radius, center + Vector2(offset + 0.16, -0.5) * radius,
					center + Vector2(offset - 0.04, -0.72) * radius, center + Vector2(offset + 0.12, -0.95) * radius]), color, line * 0.8, true)
		Kind.PET:
			#A cat: the head and two pointed ears
			canvas.draw_circle(center + Vector2(0.0, 0.16) * radius, radius * 0.68, color)
			for side: float in [-1.0, 1.0]:
				canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(side * 0.72, -0.9) * radius,
					center + Vector2(side * 0.12, -0.36) * radius, center + Vector2(side * 0.68, -0.08) * radius]), color)
