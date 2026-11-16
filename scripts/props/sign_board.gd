class_name SignBoard
extends RefCounted

#The signs of the game, the same in every map: a rounded board of a colour with its name in white letters and lights all around, alone or
#held up over a way by an arch of two candy pillars. The letters belong to the board, so they look like part of the place

const FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const FONT_SIZE := 128
#The letters take this share of the height and of the width of the board, at the most
const TEXT_HEIGHT := 0.56
const TEXT_WIDTH := 0.86
const DEPTH := 0.28
const BULB_SPACING := 0.62
const INK := Color("2a2145")


#A board "width" by "height" meters standing on its bottom edge, centred on x and facing +Z; with "two_faces" it has the name behind too
static func board(text: String, color: Color, width: float, height: float, two_faces := true) -> Node3D:
	var root := Node3D.new()
	var corner := minf(height * 0.42, width * 0.2)
	var outline := CandyTerrain.rounded_box(Vector2(0.0, height / 2.0), Vector2(width, height), corner, 0.0, 6)
	var panel := MeshInstance3D.new()
	panel.mesh = _prism(outline, DEPTH)
	panel.material_override = PartyKit.paint(color, 0.18, 0.4)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(panel)
	#A white band just inside the edge, a little in front of the face, frames the name
	var inner := CandyTerrain.rounded_box(Vector2(0.0, height / 2.0), Vector2(width - 0.34, height - 0.34), maxf(corner - 0.17, 0.05), 0.0, 6)
	for facing: float in ([1.0, -1.0] if two_faces else [1.0]):
		var frame := MeshInstance3D.new()
		frame.mesh = _ring(outline, inner, facing * (DEPTH / 2.0 + 0.012))
		frame.material_override = PartyKit.paint(PartyKit.WHITE, 0.25, 0.35)
		frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(frame)
		var label := Label3D.new()
		label.text = text
		label.font = FONT
		label.font_size = FONT_SIZE
		var natural := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		label.pixel_size = minf(height * TEXT_HEIGHT / FONT_SIZE, (width - 0.6) * TEXT_WIDTH / maxf(natural.x, 1.0))
		label.outline_size = 26
		label.modulate = PartyKit.WHITE
		label.outline_modulate = color.darkened(0.55)
		label.double_sided = false
		label.position = Vector3(0.0, height / 2.0, facing * (DEPTH / 2.0 + 0.02))
		label.rotation.y = 0.0 if facing > 0.0 else PI
		root.add_child(label)
	#Bulbs that chase each other along the edge, in the colours of the party
	var spots: Array[Transform3D] = []
	var colors: Array[Color] = []
	var phases: Array[float] = []
	var travelled := 0.0
	for index in outline.size():
		var from := outline[index]
		var to := outline[(index + 1) % outline.size()]
		var length := from.distance_to(to)
		var at := fmod(BULB_SPACING - fmod(travelled, BULB_SPACING), BULB_SPACING)
		while at < length:
			var point := from.lerp(to, at / length)
			spots.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.9), Vector3(point.x, point.y, 0.0)))
			colors.append(PartyKit.PALETTE[spots.size() % PartyKit.PALETTE.size()].lightened(0.3))
			phases.append(spots.size() * 0.7)
			at += BULB_SPACING
		travelled += length
	root.add_child(PartyKit.bulbs(spots, colors, phases))
	return root


#A board held up between two candy pillars "span" meters apart, its bottom "height" meters over the feet of the pillars (y = 0); the
#pillars go down "below" meters more, to stand on something lower
static func arch(text: String, color: Color, span: float, height: float, board_height := 1.5, below := 0.0) -> Node3D:
	var root := Node3D.new()
	for side: float in [-1.0, 1.0]:
		var pillar := PartyKit.pillar(height + board_height + below, 0.3, color, PartyKit.WHITE)
		pillar.position = Vector3(side * span / 2.0, -below, 0.0)
		root.add_child(pillar)
	var sign_board := board(text, color, span - 0.2, board_height)
	sign_board.position.y = height
	root.add_child(sign_board)
	return root


#A flat prism of a convex outline on the XY plane, "depth" thick along Z
static func _prism(outline: PackedVector2Array, depth: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var middle := Vector2.ZERO
	for point in outline:
		middle += point
	middle /= maxf(outline.size(), 1.0)
	for facing: float in [1.0, -1.0]:
		var z := facing * depth / 2.0
		for index in outline.size():
			var a := outline[index]
			var b := outline[(index + 1) % outline.size()]
			tool.set_normal(Vector3(0.0, 0.0, facing))
			if facing > 0.0:
				tool.add_vertex(Vector3(middle.x, middle.y, z))
				tool.add_vertex(Vector3(b.x, b.y, z))
				tool.add_vertex(Vector3(a.x, a.y, z))
			else:
				tool.add_vertex(Vector3(middle.x, middle.y, z))
				tool.add_vertex(Vector3(a.x, a.y, z))
				tool.add_vertex(Vector3(b.x, b.y, z))
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var out := Vector3(b.y - a.y, -(b.x - a.x), 0.0).normalized()
		tool.set_normal(out)
		tool.add_vertex(Vector3(a.x, a.y, depth / 2.0))
		tool.add_vertex(Vector3(b.x, b.y, depth / 2.0))
		tool.add_vertex(Vector3(b.x, b.y, -depth / 2.0))
		tool.add_vertex(Vector3(a.x, a.y, depth / 2.0))
		tool.add_vertex(Vector3(b.x, b.y, -depth / 2.0))
		tool.add_vertex(Vector3(a.x, a.y, -depth / 2.0))
	return tool.commit()


#The flat band between two outlines with as many corners, at "z", seen from the side its sign says
static func _ring(outer: PackedVector2Array, inner: PackedVector2Array, z: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facing := signf(z)
	var count := mini(outer.size(), inner.size())
	for index in count:
		var a := outer[index]
		var b := outer[(index + 1) % count]
		var c := inner[(index + 1) % count]
		var d := inner[index]
		tool.set_normal(Vector3(0.0, 0.0, facing))
		var quad: Array[Vector2] = [a, c, b, a, d, c]
		if facing < 0.0:
			quad = [a, b, c, a, c, d]
		for point in quad:
			tool.add_vertex(Vector3(point.x, point.y, z))
	return tool.commit()
