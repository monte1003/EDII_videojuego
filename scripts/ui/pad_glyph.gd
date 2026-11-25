class_name PadGlyph
extends Control

#DualSense button drawn by code as PlayStation games show it

#Button body and the four symbol colours
const BODY := Palette.EDGE
const RIM := Color(1.0, 1.0, 1.0, 0.16)
const SYMBOLS := {"cross": Color("7ea8ff"), "circle": Color("ff5a6e"), "square": Color("f48bd6"), "triangle": Color("40cfa0")}
const LIGHT := Palette.PAPER

var shape := "cross"
var side := Vector2.ZERO


func _init(button: Dictionary, size_points: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape = button.get("shape", "cross")
	side = button.get("side", Vector2.ZERO)
	var height := ceilf(UiKit.HEADING_FONT.get_height(size_points)) + 8.0
	var wide := height * (1.42 if shape.begins_with("stick") and side.x != 0.0 else 1.0)
	custom_minimum_size = Vector2(wide, height)


#Drawn at its own size and centred, so it never spills over its neighbours
func _draw() -> void:
	var height := minf(size.y, custom_minimum_size.y)
	var radius := height / 2.0
	var left := (size.x - custom_minimum_size.x) / 2.0 if size.x > custom_minimum_size.x else 0.0
	var centre := Vector2(left + radius, size.y / 2.0)
	if shape.begins_with("stick") and side.x < 0.0:
		centre.x = left + custom_minimum_size.x - radius
	draw_circle(centre, radius, BODY, true, -1.0, true)
	draw_arc(centre, radius - maxf(1.5, height * 0.06), PI * 1.1, PI * 1.9, 24, RIM, maxf(1.5, height * 0.06), true)
	var width := maxf(2.0, height * 0.1)
	var mark := radius * 0.46
	match shape:
		"cross":
			var color: Color = SYMBOLS["cross"]
			draw_line(centre + Vector2(-mark, -mark), centre + Vector2(mark, mark), color, width, true)
			draw_line(centre + Vector2(mark, -mark), centre + Vector2(-mark, mark), color, width, true)
		"circle":
			draw_arc(centre, mark * 1.05, 0.0, TAU, 32, SYMBOLS["circle"], width, true)
		"square":
			var half := mark * 0.92
			_outline([centre + Vector2(-half, -half), centre + Vector2(half, -half), centre + Vector2(half, half), centre + Vector2(-half, half)],
				SYMBOLS["square"], width)
		"triangle":
			var top := mark * 1.12
			_outline([centre + Vector2(0.0, -top), centre + Vector2(top * 0.98, top * 0.66), centre + Vector2(-top * 0.98, top * 0.66)],
				SYMBOLS["triangle"], width)
		"stick_l", "stick_r":
			_stick(centre, radius, width, "L" if shape == "stick_l" else "R")
		"dpad":
			_dpad(centre, radius)


func _outline(points: Array[Vector2], color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


#Stick cap with its letter and an arrow for the push direction
func _stick(centre: Vector2, radius: float, width: float, letter: String) -> void:
	draw_arc(centre, radius * 0.62, 0.0, TAU, 40, Color(LIGHT, 0.35), width * 0.6, true)
	var font := UiKit.HEADING_FONT
	var font_size := maxi(roundi(radius * 0.95), 8)
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, centre + Vector2(-text_size.x / 2.0, font_size * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LIGHT)
	if side == Vector2.ZERO:
		return
	var tip := centre + side * radius * 1.42
	var back := centre + side * radius * 1.08
	var across := Vector2(-side.y, side.x) * radius * 0.36
	draw_colored_polygon(PackedVector2Array([tip, back + across, back - across]), BODY)


#D-pad with the pointed arm lit
func _dpad(centre: Vector2, radius: float) -> void:
	var arm := radius * 0.7
	var half := radius * 0.2
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var across := Vector2(-direction.y, direction.x) * half
		var inner := centre + direction * half * 1.3
		var outer := centre + direction * arm
		var color := LIGHT if direction == side else Color(LIGHT, 0.32)
		draw_colored_polygon(PackedVector2Array([inner + across, outer + across, outer - across, inner - across]), color)
