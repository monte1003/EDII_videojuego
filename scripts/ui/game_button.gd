class_name GameButton
extends Button

@export var base_color := Palette.PILL
@export var label_color := Palette.PAPER
#Late despacio para llamar la atencion; se usa en la accion principal de la pantalla
@export var pulse := false

var _tween: Tween
var _beat: Tween

@onready var _ring: Panel = %Ring
@onready var _shadow: Panel = %Shadow
@onready var _body: Panel = %Body
@onready var _shade: TextureRect = %Shade
@onready var _icon: TextureRect = %Icon
@onready var _caption: Label = %Caption


func _ready() -> void:
	#El Button solo recibe el clic: la pildora y el texto son sus hijos, que se dibujan encima
	for box in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(box, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)

	_caption.text = text
	_caption.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	_caption.add_theme_color_override("font_color", label_color)
	_icon.texture = icon
	_icon.visible = icon != null
	_ring.add_theme_stylebox_override("panel", _outline(base_color))
	_ring.modulate.a = 0.0
	_shadow.add_theme_stylebox_override("panel", _drop_shadow())
	_paint(base_color)

	resized.connect(_on_resized)
	_on_resized()
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	focus_entered.connect(_paint.bind(base_color.lightened(0.1)))
	focus_exited.connect(_paint.bind(base_color))
	pressed.connect(UiSound.play_click)
	if pulse:
		_start_beat()


func _on_resized() -> void:
	pivot_offset = size / 2.0
	_ring.pivot_offset = _ring.size / 2.0


#La pildora recorta un degradado vertical: filo claro arriba y canto oscuro al pie
func _paint(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(120)
	style.corner_detail = 12
	_body.add_theme_stylebox_override("panel", style)

	#Hacia abajo gana saturacion y pierde brillo, como el JUGAR de la referencia
	var gradient := Gradient.new()
	gradient.set_color(0, color.lightened(0.45))
	gradient.set_color(1, Color.from_hsv(color.h, minf(color.s * 1.25, 1.0), color.v * 0.86))
	gradient.add_point(0.06, color.lightened(0.18))
	gradient.add_point(0.5, color)
	gradient.add_point(0.93, Color.from_hsv(color.h, minf(color.s * 1.2, 1.0), color.v * 0.94))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 64
	_shade.texture = texture


#La sombra va aparte: dentro de la pildora el recorte la taparia
func _drop_shadow() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_corner_radius_all(120)
	style.corner_detail = 12
	style.shadow_color = Color(Palette.INK, 0.25)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 7)
	return style


func _outline(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(2)
	style.border_color = color
	style.set_corner_radius_all(120)
	style.corner_detail = 12
	return style


#Un latido: la pildora crece un poco y vuelve, y un anillo sale de ella y se desvanece
func _start_beat() -> void:
	_beat = create_tween().set_loops()
	_beat.tween_property(self, "scale", Vector2.ONE * 1.035, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_beat.parallel().tween_callback(_ping)
	_beat.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_beat.tween_interval(0.9)


func _ping() -> void:
	_ring.scale = Vector2.ONE
	_ring.modulate.a = 0.5
	var ring := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring.tween_property(_ring, "scale", Vector2(1.08, 1.25), 1.1)
	ring.tween_property(_ring, "modulate:a", 0.0, 1.1)


#Con el mouse encima deja de latir y se queda un poco mas grande
func _on_enter() -> void:
	UiSound.play_hover()
	if _beat:
		_beat.kill()
	_animate(1.05)


func _on_exit() -> void:
	_animate(1.0)
	if pulse:
		_tween.tween_callback(_start_beat)


func _animate(scale_to: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * scale_to, 0.18)
