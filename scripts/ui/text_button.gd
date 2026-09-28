class_name TextButton
extends Button

@export var accent := Palette.CORAL

var _tween: Tween
var _pill := StyleBoxFlat.new()
var _dot: Panel


func _ready() -> void:
	#Una sola pildora para todos los estados: al apuntar el boton solo cambia su opacidad
	_pill.set_corner_radius_all(120)
	_pill.corner_detail = 12
	_pill.set_border_width_all(2)
	_pill.content_margin_left = 40
	_pill.content_margin_right = 40
	_pill.content_margin_top = 6
	_pill.content_margin_bottom = 6
	_set_pill(0.0)
	for box in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(box, _pill)
	add_theme_color_override("font_color", Color(Palette.INK, 0.72))
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, Palette.INK)
	pivot_offset = size / 2.0
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	focus_entered.connect(_on_enter)
	focus_exited.connect(_on_exit)
	pressed.connect(UiSound.play_click)
	resized.connect(_on_resized)
	_build_dot()


#Un punto del color de acento dentro de la pildora dice a donde lleva el boton sin pintarlo entero
func _build_dot() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(8)
	_dot = Panel.new()
	_dot.add_theme_stylebox_override("panel", style)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.size = Vector2(9, 9)
	_dot.modulate.a = 0.0
	add_child(_dot)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size / 2.0
	if _dot:
		_dot.position = Vector2(20, (size.y - _dot.size.y) / 2.0)


func _set_pill(amount: float) -> void:
	_pill.bg_color = Color(Palette.PAPER, 0.55 * amount)
	_pill.border_color = Color(Palette.PAPER, 0.95 * amount)


func _on_enter() -> void:
	UiSound.play_hover()
	_animate(1.0, 1.03)


func _on_exit() -> void:
	if has_focus() or is_hovered():
		return
	_animate(0.0, 1.0)


func _animate(amount: float, scale_to: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_pill, _pill.border_color.a / 0.95, amount, 0.2)
	_tween.tween_property(_dot, "modulate:a", amount, 0.2)
	_tween.tween_property(self, "scale", Vector2.ONE * scale_to, 0.2)
