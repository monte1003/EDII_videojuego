class_name TrendStrip
extends Control

#The trend as a row of slots, one per kind and in order. Each slot is a chip in the main colour of its kind with the picture of
#the very toy that floats in its bubble. The one to fetch now beats, the ones already fetched are stuck on like stickers with a
#check, and the ones still to come wait smaller and dimmer. No box behind it

const GAP := 0.24

var slot := 52.0
var chain: Array[int] = []
var done := 0
#Whether the slot to fetch now beats (the copy on the giant screen stays still)
var beats := true

var _clock := 0.0
var _stamped := -1
var _stamp_age := 1.0


func set_chain(kinds: Array[int]) -> void:
	chain = kinds
	done = 0
	_stamped = -1
	custom_minimum_size = Vector2(slot * (chain.size() + GAP * maxf(chain.size() - 1, 0.0)), slot)
	size = custom_minimum_size
	queue_redraw()


#How many slots are already fetched; a new one lands with a little stamp
func set_done(count: int) -> void:
	if count > done:
		_stamped = count - 1
		_stamp_age = 0.0
	done = clampi(count, 0, chain.size())
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	_stamp_age = minf(_stamp_age + delta * 3.5, 1.0)
	if beats and not chain.is_empty():
		queue_redraw()


func _draw() -> void:
	for index in chain.size():
		var kind := chain[index]
		var center := Vector2(slot / 2.0 + index * slot * (1.0 + GAP), slot / 2.0)
		var color := TrendCatalog.COLORS[kind]
		var half := slot / 2.0
		var scale_now := 1.0
		var turn := 0.0
		if index < done:
			turn = (-0.12 if index % 2 == 0 else 0.1)
			if index == _stamped and beats:
				scale_now = 1.0 + 0.5 * (1.0 - _stamp_age) * (1.0 - _stamp_age)
		elif index == done:
			scale_now = 1.0 + (0.09 * (0.5 + 0.5 * sin(_clock * 7.0)) if beats else 0.0)
		else:
			scale_now = 0.82
		draw_set_transform(center, turn, Vector2.ONE * scale_now)
		var waiting := index > done
		#A white edge like a sticker, the chip in the colour of the kind and a light disc so the toy reads on it
		draw_colored_polygon(_rounded(half * 1.05, half * 0.4), Color(Palette.NIGHT, 0.75) if index == done else Palette.PAPER)
		draw_colored_polygon(_rounded(half * 0.93, half * 0.34), color.lerp(Palette.NIGHT, 0.4) if waiting else color)
		draw_circle(Vector2.ZERO, half * 0.72, Palette.PAPER.lerp(color, 0.35) if waiting else Palette.PAPER)
		_draw_toy(kind, half * 0.8, Color(1.0, 1.0, 1.0, 0.8 if waiting else 1.0))
		if index < done:
			var mark := PackedVector2Array([Vector2(0.1, 0.5) * half, Vector2(0.36, 0.76) * half, Vector2(0.86, 0.2) * half])
			draw_polyline(mark, Palette.EDGE, half * 0.34, true)
			draw_polyline(mark, Palette.PAPER, half * 0.2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


#The picture of the toy of a kind; while there are no pictures (no drawing device) the plain icon stands in
func _draw_toy(kind: int, reach: float, tone: Color) -> void:
	if kind < TrendIcons.textures.size() and TrendIcons.textures[kind] != null:
		draw_texture_rect(TrendIcons.textures[kind], Rect2(-Vector2.ONE * reach, Vector2.ONE * reach * 2.0), false, tone)
	else:
		TrendCatalog.draw_icon(self, kind, Vector2.ZERO, reach * 0.62, TrendCatalog.COLORS[kind].darkened(0.25))


#A square with round corners around the origin
func _rounded(half: float, corner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for quarter in 4:
		var middle := Vector2(half - corner, half - corner).rotated(PI / 2.0 * quarter)
		for step in 7:
			var angle := PI / 2.0 * quarter + PI / 2.0 * step / 6.0
			points.append(middle + Vector2(cos(angle), sin(angle)) * corner)
	return points
