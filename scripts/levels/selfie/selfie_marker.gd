class_name SelfieMarker
extends Control

#Next photo badge with the meters left; waits at the screen edge pointing when out of sight

const RADIUS := 25.0
const OUTLINE := 3.0
#Edge margin and tip length
const EDGE := 70.0
const TIP := 14.0
const FADE := 0.18
const FONT_SIZE := 15

var _at := Vector2.ZERO
var _way := Vector2.DOWN
var _in_sight := true
var _meters := 0.0
var _hot := false
var _shown := false
var _clock := 0.0
var _body := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0
	visible = false
	_body.set_corner_radius_all(4)


#Over "screen" when in sight, else at the edge toward it; "behind" mirrors the point
func point_at(screen: Vector2, behind: bool, meters: float, hot: bool) -> void:
	var screen_size := get_viewport_rect().size
	if screen_size.x <= EDGE * 2.0 or screen_size.y <= EDGE * 2.0:
		return
	var area := Rect2(Vector2.ZERO, screen_size).grow(-EDGE)
	var middle := screen_size / 2.0
	var way := screen - middle
	if behind:
		way = -way
	if way.length() < 1.0:
		way = Vector2.DOWN
	_in_sight = not behind and area.has_point(screen)
	if _in_sight:
		_at = screen
	else:
		var half := area.size / 2.0
		_at = middle + way * minf(half.x / maxf(absf(way.x), 0.001), half.y / maxf(absf(way.y), 0.001))
	_way = way.normalized()
	_meters = meters
	_hot = hot


func set_shown(on: bool) -> void:
	_shown = on


func _process(delta: float) -> void:
	_clock += delta
	modulate.a = move_toward(modulate.a, 1.0 if _shown else 0.0, delta / FADE)
	visible = modulate.a > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	var radius := RADIUS * (1.0 + (0.12 * absf(sin(_clock * 9.0)) if _hot else 0.0))
	var fill := Palette.GOLD if _hot else Palette.PAPER
	var ink := Palette.EDGE
	if not _in_sight:
		var side := Vector2(-_way.y, _way.x)
		var base := _at + _way * (radius - 4.0)
		var tip := _at + _way * (radius + TIP)
		draw_colored_polygon(PackedVector2Array([tip + _way * 4.0, base + side * 13.0, base - side * 13.0]), ink)
		draw_colored_polygon(PackedVector2Array([tip, base + side * 9.0, base - side * 9.0]), fill)
	draw_circle(_at, radius + OUTLINE, ink)
	draw_circle(_at, radius, fill)
	_draw_camera(_at, radius * 0.56, ink, fill)
	var text := "%d m" % roundi(_meters)
	var width := UiKit.BUTTON_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var spot := _at + Vector2(-width / 2.0, radius + OUTLINE + 19.0)
	draw_string_outline(UiKit.BUTTON_FONT, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 7, ink)
	draw_string(UiKit.BUTTON_FONT, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.PAPER)


#Little photo camera icon
func _draw_camera(centre: Vector2, half: float, ink: Color, fill: Color) -> void:
	_body.bg_color = ink
	draw_style_box(_body, Rect2(centre + Vector2(-half * 0.45, -half * 0.95), Vector2(half * 0.7, half * 0.5)))
	draw_style_box(_body, Rect2(centre + Vector2(-half, -half * 0.62), Vector2(half * 2.0, half * 1.42)))
	draw_circle(centre + Vector2(0.0, 0.1 * half), half * 0.5, fill)
	draw_circle(centre + Vector2(0.0, 0.1 * half), half * 0.3, ink)
