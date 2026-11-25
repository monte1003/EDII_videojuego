class_name TrendPointer
extends Control

#Edge arrow toward the trend zone while it is out of view, per screen

const SIZE := 34.0
const MARGIN := 64.0

var color := Palette.GOLD
var _angle := 0.0
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()


#Aims at "target"; hidden when in view or not "wanted"
func aim(camera: Camera3D, target: Vector3, wanted: bool) -> void:
	if not wanted or camera == null:
		hide()
		return
	var area := get_viewport_rect().size
	var behind := camera.is_position_behind(target)
	var spot := camera.unproject_position(target)
	var inside := Rect2(Vector2.ZERO, area).grow(-MARGIN).has_point(spot)
	if inside and not behind:
		hide()
		return
	var centre := area / 2.0
	var way := spot - centre
	if behind:
		way = -way
	if way.length() < 1.0:
		way = Vector2.DOWN
	_angle = way.angle()
	show()
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	var area := get_viewport_rect().size
	var centre := area / 2.0
	var way := Vector2.from_angle(_angle)
	#Ray from the middle to the screen edge, inside the margin
	var half := centre - Vector2.ONE * MARGIN
	var reach := minf(half.x / maxf(absf(way.x), 0.001), half.y / maxf(absf(way.y), 0.001))
	var tip := centre + way * (reach + 6.0 * sin(_clock * 7.0))
	var side := way.orthogonal()
	var points := PackedVector2Array([tip + way * SIZE * 0.6, tip - way * SIZE * 0.5 + side * SIZE * 0.55, tip - way * SIZE * 0.2,
		tip - way * SIZE * 0.5 - side * SIZE * 0.55])
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(Palette.NIGHT, 0.88), 3.0, true)
