class_name MedalBadge
extends Control

#The medal of a round, drawn here: a wavy seal with a check mark, like the badge of a verified account.
#Each medal has its colour and its number of waves; gold and diamond shine, and no medal is an empty outline

const SHINE: Shader = preload("res://assets/ui/shaders/medal_shine.gdshader")
const FILL: Array[Color] = [Color("8f86ad"), Color("cf7f4c"), Color("b7c3d9"), Color("ffc531"), Color("5fd4f4")]
const RIM: Array[Color] = [Color("6d5f97"), Color("8a4a26"), Color("76839e"), Color("c98a06"), Color("7a5cf0")]
const WAVES: Array[int] = [10, 8, 10, 12, 14]
const STEPS := 120

var medal := ScoreSheet.Medal.NONE: set = set_medal


static func make(shown: ScoreSheet.Medal, side: float) -> MedalBadge:
	var badge := MedalBadge.new()
	badge.custom_minimum_size = Vector2.ONE * side
	badge.size = Vector2.ONE * side
	badge.pivot_offset = Vector2.ONE * side / 2.0
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.medal = shown
	return badge


func set_medal(value: ScoreSheet.Medal) -> void:
	medal = value
	if medal >= ScoreSheet.Medal.GOLD:
		var shine := ShaderMaterial.new()
		shine.shader = SHINE
		shine.set_shader_parameter("span", maxf(custom_minimum_size.x, 1.0))
		shine.set_shader_parameter("strength", 0.6 if medal == ScoreSheet.Medal.DIAMOND else 0.4)
		material = shine
	else:
		material = null
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 * 0.9
	var outer := _seal(center, radius, WAVES[medal])
	if medal == ScoreSheet.Medal.NONE:
		outer.append(outer[0])
		draw_polyline(outer, Color(RIM[0], 0.55), maxf(radius * 0.07, 2.0), true)
		draw_line(center - Vector2(radius * 0.26, 0.0), center + Vector2(radius * 0.26, 0.0), Color(RIM[0], 0.55), maxf(radius * 0.1, 2.0), true)
		return
	draw_colored_polygon(_seal(center + Vector2(0.0, radius * 0.07), radius, WAVES[medal]), Color(Palette.INK, 0.22))
	draw_colored_polygon(outer, RIM[medal])
	draw_colored_polygon(_seal(center, radius * 0.86, WAVES[medal]), FILL[medal])
	draw_arc(center, radius * 0.6, PI * 1.05, PI * 1.6, 20, Color(1.0, 1.0, 1.0, 0.45), radius * 0.08, true)
	var mark := PackedVector2Array([center + Vector2(-0.34, 0.02) * radius, center + Vector2(-0.1, 0.27) * radius, center + Vector2(0.36, -0.24) * radius])
	var width := radius * 0.17
	draw_polyline(mark, Color(Palette.INK, 0.28), width * 1.5, true)
	draw_polyline(mark, Palette.PAPER, width, true)
	for point in mark:
		draw_circle(point, width / 2.0, Palette.PAPER)
	if medal == ScoreSheet.Medal.DIAMOND:
		_sparkle(center + Vector2(0.52, -0.5) * radius, radius * 0.2)
		_sparkle(center + Vector2(-0.56, 0.44) * radius, radius * 0.12)


#The outline of the seal: a circle whose radius goes in and out "waves" times
func _seal(center: Vector2, radius: float, waves: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in STEPS:
		var angle := TAU * step / STEPS
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * (0.94 + 0.06 * cos(angle * waves)))
	return points


func _sparkle(at: Vector2, reach: float) -> void:
	var points := PackedVector2Array()
	for step in 8:
		var angle := TAU * step / 8.0
		points.append(at + Vector2(cos(angle), sin(angle)) * reach * (1.0 if step % 2 == 0 else 0.32))
	draw_colored_polygon(points, Palette.PAPER)
