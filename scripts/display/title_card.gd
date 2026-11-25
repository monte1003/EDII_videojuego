class_name TitleCard
extends Control

#Trailer words set like a film: flat over the picture on a pool of night, in the button type

const LOGO: Texture2D = preload("res://assets/ui/textures/title.png")
const SHINE: Shader = preload("res://assets/shaders/title_shine.gdshader")
const WIDE: FontFile = preload("res://assets/ui/fonts/Unbounded.ttf")
#OpenType tag of the weight axis ("wght")
const WEIGHT := 2003265652
#The ranking column and its margin on the right
const COLUMN := FairFrame.COLUMN_WIDTH + 46.0
const OUT_SECONDS := 0.25
#Slow push while the words stay
const DRIFT := 1.04
const DRIFT_SECONDS := 7.0

var _card: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


#Trailer line: small part closing up, big punch opening from the middle
func say(lines: Array[String]) -> void:
	var card := _new_card()
	var free := size.x - COLUMN
	var block := _column(0)
	var setup_font := _type(500, 6)
	if lines.size() > 1:
		block.add_child(_words(lines[0], setup_font, _fit(lines[0], setup_font, 26, free * 0.8), Color(Palette.PAPER, 0.92)))
	var punch := lines[-1]
	var punch_font := _type(800, 0)
	var window := _window(punch, punch_font, _fit(punch, punch_font, 64, free * 0.84))
	block.add_child(window)
	var rig := _rig(card, block, Vector2(free * 0.5, size.y * 0.3), Vector2(0.5, 0.5), 0.62)
	var motion := _motion(card)
	motion.tween_property(card, "modulate:a", 1.0, 0.25).from(0.0)
	motion.tween_property(setup_font, "spacing_glyph", 6, 0.7).from(26).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	motion.tween_property(window, "custom_minimum_size:x", window.get_meta("full"), 0.5).set_delay(0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	motion.tween_property(rig, "scale", Vector2.ONE * DRIFT, DRIFT_SECONDS).from(Vector2.ONE * 0.97).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


#Logo slammed in on the beat with its line; "call" comes in gold and beats
func title(tagline: String, call := "", call_after := 0.0, beat := 0.5) -> void:
	var card := _new_card()
	var free := size.x - COLUMN
	var block := _column(4)
	var width := minf(free * 0.66, size.y * 0.95)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(width, width * LOGO.get_height() / LOGO.get_width())
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shine := ShaderMaterial.new()
	shine.shader = SHINE
	shine.set_shader_parameter("sweep", -1.0)
	logo.material = shine
	block.add_child(logo)
	var tag_font := _type(600, 12)
	block.add_child(_words(tagline, tag_font, 22, Palette.PAPER))
	var call_words: Label
	if call != "":
		var call_font := _type(800, 2)
		call_words = _words(call, call_font, _fit(call, call_font, 40, free * 0.7), Palette.GOLD)
		call_words.modulate.a = 0.0
		call_words.resized.connect(func() -> void: call_words.pivot_offset = call_words.size / 2.0)
		block.add_child(call_words)
	var glow := _light()
	var rig := _rig(card, block, Vector2(free * 0.5, size.y * 0.46), Vector2(0.5, 0.5), 0.7, glow)
	var motion := _motion(card)
	motion.tween_property(card, "modulate:a", 1.0, 0.08).from(0.0)
	var slam := card.create_tween().set_ignore_time_scale(true)
	slam.tween_property(rig, "scale", Vector2.ONE, 0.55).from(Vector2.ONE * 1.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	slam.tween_property(rig, "scale", Vector2.ONE * DRIFT, DRIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var light := card.create_tween().set_ignore_time_scale(true)
	light.tween_property(glow, "modulate:a", 1.0, 0.3).from(0.0)
	light.tween_property(glow, "modulate:a", 0.65, 1.6).set_trans(Tween.TRANS_SINE)
	motion.tween_property(tag_font, "spacing_glyph", 12, 1.0).from(34).set_delay(0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var glint := card.create_tween().set_ignore_time_scale(true).set_loops()
	glint.tween_interval(0.45)
	glint.tween_property(shine, "shader_parameter/sweep", 1.4, 0.85).from(-0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glint.tween_interval(2.6)
	if call_words != null:
		motion.tween_property(call_words, "modulate:a", 1.0, 0.2).set_delay(call_after)
		var pulse := card.create_tween().set_ignore_time_scale(true)
		pulse.tween_interval(call_after)
		pulse.tween_property(call_words, "scale", Vector2.ONE, 0.45).from(Vector2.ONE * 1.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse.tween_callback(_keep_beating.bind(call_words, beat))


#Character name at the bottom left like a fighting game
func name_card(shown_name: String, tag: String, colour: Color) -> void:
	var card := _new_card()
	var free := size.x - COLUMN
	var block := _column(6)
	var tag_font := _type(600, 8)
	var tag_words := _words(tag, tag_font, 18, Color(Palette.PAPER, 0.9))
	tag_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	block.add_child(tag_words)
	var rule := ColorRect.new()
	rule.color = colour.lightened(0.2)
	rule.custom_minimum_size = Vector2(0.0, 6.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(rule)
	var name_font := _type(900, 2)
	var name_words := _words(shown_name, name_font, _fit(shown_name, name_font, 76, free * 0.6), Palette.PAPER)
	name_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	block.add_child(name_words)
	var corner := Vector2(free * 0.06, size.y * 0.84)
	var rig := _rig(card, block, corner, Vector2(0.0, 1.0), 0.6)
	var motion := _motion(card)
	motion.tween_property(card, "modulate:a", 1.0, 0.2).from(0.0)
	motion.tween_property(rig, "position:x", corner.x, 0.5).from(corner.x - 70.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	motion.tween_property(rule, "custom_minimum_size:x", 150.0, 0.45).set_delay(0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	motion.tween_property(tag_font, "spacing_glyph", 8, 0.7).from(26).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


#The call grows on every beat
func _keep_beating(words: Label, beat: float) -> void:
	var beating := words.create_tween().set_ignore_time_scale(true).set_loops()
	beating.tween_property(words, "scale", Vector2.ONE * 1.06, 0.07)
	beating.tween_property(words, "scale", Vector2.ONE, maxf(beat - 0.07, 0.1)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func clear() -> void:
	if _card == null:
		return
	var card := _card
	_card = null
	var out := card.create_tween().set_ignore_time_scale(true)
	out.tween_property(card, "modulate:a", 0.0, OUT_SECONDS)
	out.tween_callback(card.queue_free)


func _new_card() -> Control:
	clear()
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	add_child(card)
	_card = card
	return card


func _motion(card: Control) -> Tween:
	return card.create_tween().set_parallel().set_ignore_time_scale(true)


func _column(gap: int) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_theme_constant_override("separation", gap)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return block


#Game type at a weight and letter spacing
func _type(weight: int, spacing: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = WIDE
	font.variation_opentype = {WEIGHT: weight}
	font.spacing_glyph = spacing
	return font


func _words(text: String, font: Font, font_size: int, colour: Color) -> Label:
	var label := UiKit.label(text, font, font_size, colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Color(Palette.NIGHT, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 8)
	return label


#Biggest size up to "font_size" that fits in "width"
static func _fit(text: String, font: Font, font_size: int, width: float) -> int:
	var fitted := font_size
	while fitted > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		fitted -= 2
	return fitted


#Punch in a window that opens from its middle; full width in meta "full"
func _window(text: String, font: Font, font_size: int) -> Control:
	var words := _words(text, font, font_size, Palette.PAPER)
	var full := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) + Vector2(24.0, 16.0)
	var window := Control.new()
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	window.custom_minimum_size = Vector2(0.0, full.y)
	window.set_meta("full", full.x)
	window.add_child(words)
	words.position = Vector2(12.0 - full.x / 2.0, 6.0)
	window.resized.connect(func() -> void: words.position.x = (window.size.x - full.x) / 2.0 + 12.0)
	return window


#Block anchored at "at" in a drifting rig over a pool of night
func _rig(card: Control, block: Control, at: Vector2, anchor: Vector2, shade: float, light: Control = null) -> Control:
	var pool := TextureRect.new()
	pool.texture = _pool(shade)
	pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pool)
	if light != null:
		card.add_child(light)
	var rig := Control.new()
	rig.position = at
	rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rig)
	rig.add_child(block)
	var fit_in := func() -> void:
		block.position = -block.size * anchor
		var middle := at + block.size * (Vector2(0.5, 0.5) - anchor)
		pool.size = block.size * Vector2(1.6, 2.4)
		pool.position = middle - pool.size / 2.0
		if light != null:
			light.size = block.size * Vector2(1.3, 1.5)
			light.position = middle - light.size / 2.0
	block.resized.connect(fit_in)
	fit_in.call()
	return rig


#Soft oval of night
static func _pool(strength: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Palette.NIGHT, strength))
	gradient.set_color(1, Color(Palette.NIGHT, 0.0))
	gradient.add_point(0.5, Color(Palette.NIGHT, strength * 0.6))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


#Warm light behind the logo
func _light() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Palette.PILL, 0.45))
	gradient.set_color(1, Color(Palette.LILAC, 0.0))
	gradient.add_point(0.45, Color(Palette.LILAC, 0.16))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var light := TextureRect.new()
	light.texture = texture
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var adding := CanvasItemMaterial.new()
	adding.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = adding
	return light
