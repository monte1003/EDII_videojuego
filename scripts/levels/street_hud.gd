class_name StreetHud
extends RoundHud

#The street screen: the clock, the mission at the start, a small ring while the jump rests and the glow near the end line


#A ring that fills while the jump rests and hides itself when it is ready
class JumpRing extends Control:
	const RADIUS := 17.0
	const WIDTH := 4.0

	var fill := 1.0

	func _draw() -> void:
		var center := size / 2.0
		draw_arc(center, RADIUS, 0.0, TAU, 40, Color(Palette.NIGHT, 0.45), WIDTH + 3.0, true)
		draw_arc(center, RADIUS, 0.0, TAU, 40, Color(Palette.PAPER, 0.22), WIDTH, true)
		if fill > 0.0:
			draw_arc(center, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * fill, 40, Palette.PAPER, WIDTH, true)


var _ring: JumpRing


func _ready() -> void:
	toast_hold = 1.8
	warn_delay = 0.25
	warn_fade = 0.5
	super()
	_ring = JumpRing.new()
	_ring.custom_minimum_size = Vector2(52, 52)
	_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.modulate.a = 0.0
	_bottom.add_child(_ring)
	_bottom.move_child(_ring, 0)


#The jump rests for "total" seconds after landing; the ring only shows while it does
func set_jump_cooldown(left: float, total: float) -> void:
	_ring.fill = 1.0 - left / maxf(total, 0.01)
	_ring.modulate.a = 1.0 if left > 0.0 else 0.0
	_ring.queue_redraw()
