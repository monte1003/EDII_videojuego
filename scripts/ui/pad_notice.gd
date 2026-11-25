class_name PadNotice
extends CanvasLayer

#Notice of a lost pad; in a round it stays until the pad is back or the pause closes

enum Context { MENU, ROUND, ROOM }

const LINES := {
	Context.MENU: "Se puede seguir con el teclado",
	Context.ROUND: "La ronda queda en pausa hasta que vuelva",
	Context.ROOM: "La partida sigue para los demás mientras vuelve",
}
const TOP := 84.0
const FADE := 0.25
const MENU_HOLD := 4.0

var _holder: VBoxContainer
var _line: Label
var _tween: Tween


func _init() -> void:
	layer = 40
	_holder = VBoxContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_theme_constant_override("separation", 6)
	_holder.anchor_left = 0.5
	_holder.anchor_right = 0.5
	_holder.offset_left = -360.0
	_holder.offset_right = 360.0
	_holder.offset_top = TOP
	_holder.modulate.a = 0.0
	_holder.visible = false
	add_child(_holder)
	var title := _outlined("MANDO DESCONECTADO", UiKit.BUTTON_FONT, 24, Palette.GOLD)
	_holder.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(Palette.GOLD, 0.9)
	rule.custom_minimum_size = Vector2(150, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(rule)
	_line = _outlined("", UiKit.BODY_FONT, 21, Palette.PAPER)
	_holder.add_child(_line)


func is_showing() -> bool:
	return _holder.visible


func show_for(context: Context) -> void:
	_line.text = LINES[context]
	_holder.visible = true
	_fade_to(1.0)
	if context == Context.MENU:
		_tween.tween_interval(MENU_HOLD)
		_tween.tween_property(_holder, "modulate:a", 0.0, FADE)
		_tween.tween_callback(_holder.hide)


func lift() -> void:
	if not _holder.visible:
		return
	_fade_to(0.0)
	_tween.tween_callback(_holder.hide)


func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_holder, "modulate:a", alpha, FADE)


func _outlined(text: String, font: Font, size_points: int, color: Color) -> Label:
	var label := UiKit.label(text, font, size_points, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color(Palette.NIGHT, 0.9))
	label.add_theme_constant_override("outline_size", maxi(roundi(size_points / 5.0), 4))
	return label
