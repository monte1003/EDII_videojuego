class_name LevelHelp
extends CanvasLayer

#Plain-language help: before the round (start mode), then from "?", F1 or the pause menu (review mode)

#Emitted when the player closes the help; start_mode tells if it was the one before the round
signal finished(start_mode: bool)

const TEXT_BUTTON := preload("res://scenes/ui/text_button.tscn")
const HEADING_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const BODY_FONT: Font = preload("res://assets/ui/fonts/body_font.tres")

var _pages: Array[Dictionary] = []
var _page := 0
var _start_mode := false

var _root: ColorRect
var _title: Label
var _body: RichTextLabel
var _counter: Label
var _previous: TextButton
var _next: TextButton
var _skip: TextButton


func _ready() -> void:
	layer = 13
	_build()
	_root.hide()


#The numbers in the texts come from the level, so they always match the real rules
func setup(config: Dictionary) -> void:
	_pages = _make_pages(config)


func is_open() -> bool:
	return _root.visible


func open(start_mode: bool) -> void:
	_start_mode = start_mode
	_page = 0
	_skip.visible = start_mode
	_show_page()
	_root.show()
	_next.grab_focus()


func close() -> void:
	_root.hide()
	finished.emit(_start_mode)


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("menu_right"):
		_go(1)
	elif event.is_action_pressed("menu_left"):
		_go(-1)
	elif not _start_mode and (event.is_action_pressed("pause") or event.is_action_pressed("help")):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _go(step: int) -> void:
	var target := _page + step
	if target >= _pages.size():
		close()
	elif target >= 0:
		_page = target
		_show_page()


func _show_page() -> void:
	var page := _pages[_page]
	_title.text = page["title"]
	_body.text = page["body"]
	_counter.text = "%d / %d" % [_page + 1, _pages.size()]
	_previous.visible = _page > 0
	var last := _page == _pages.size() - 1
	_next.text = ("¡EMPEZAR!" if _start_mode else "CERRAR") if last else "SIGUIENTE"


func _make_pages(config: Dictionary) -> Array[Dictionary]:
	var key := InputHints.markup
	var interact := InputHints.key_label(&"interact")
	var minutes := "%d:%02d" % [floori(config["time_limit"] / 60.0), int(config["time_limit"]) % 60]
	var keys := "%s %s %s %s" % [
		InputHints.key_label(&"move_forward"), InputHints.key_label(&"move_left"),
		InputHints.key_label(&"move_back"), InputHints.key_label(&"move_right")]
	return [
		{
			"title": "Tu misión",
			"body": "Corres por islas flotantes unidas por puentes. Tienes que llegar a la isla %s, la del arco dorado, antes de que se acabe el reloj (%s).\n\nSi te caes al vacío pierdes 1 de tus %d intentos y vuelves a la salida, o al checkpoint si ya pasaste por él. ¡El reloj no se detiene!\n\nEs un juego para usar las redes sociales con calma: unos bots molestos te persiguen y tú decides cómo cuidarte." % [
				key.call("M"), minutes, config["attempts"]],
		},
		{
			"title": "Los bots molestos",
			"body": "Son personajes oscuros que representan lo que puede molestar en internet:\n%s comentarios que hieren · %s notificaciones sin parar · %s noticias falsas · %s compararte con los demás.\n\nSalen %d segundos después de empezar y siempre buscan el camino más corto hasta ti.\n\nCuando uno se acerca, se queda quieto y le sale un %s: ¡te va a empujar! Corre en sentido contrario un momento y no te pasa nada. Si te alcanza cerca del borde, puedes caer." % [
				key.call("Trol"), key.call("Spam"), key.call("Bulo"), key.call("Espejo"),
				int(config["head_start"]), key.call("❗")],
		},
		{
			"title": "Bloquear (isla E)",
			"body": "En una red social, bloquear a alguien es poner un límite. Aquí funciona igual: %s un puente para los bots durante %d segundos. Ellos tienen que buscar otro camino, pero tú sí puedes cruzarlo.\n\nSe recarga en %d segundos.\n\nCómo se usa: ve a la isla %s, párate junto a la consola morada y pulsa %s." % [
				key.call("cierra"), int(config["block_duration"]), int(config["block_cooldown"]), key.call("E"), key.call(interact)],
		},
		{
			"title": "Silenciar (isla F)",
			"body": "Silenciar es apagar las notificaciones. Durante %d segundos los bots solo notan que estás cerca si están a menos de %d metros (normalmente te ven desde %d).\n\nNo los detiene ni te protege: sirve para que te pierdan de vista. Se recarga en %d segundos.\n\nCómo se usa: ve a la isla %s, junto a la consola cian, y pulsa %s." % [
				int(config["silence_duration"]), int(config["silenced_radius"]), int(config["detection_radius"]),
				int(config["silence_cooldown"]), key.call("F"), key.call(interact)],
		},
		{
			"title": "Pausa digital (isla D)",
			"body": "Es tomarte un descanso del celular. Dentro de la casita de la isla %s nadie puede empujarte hasta %d segundos (si sales de ella, termina antes). El reloj sigue corriendo.\n\nSe recarga en %d segundos.\n\nCómo se usa: entra a la casita y pulsa %s.\n\nTambién estás protegido %d segundos cuando reapareces tras una caída." % [
				key.call("D"), int(config["refuge_duration"]), int(config["refuge_cooldown"]),
				key.call(interact), int(config["respawn_protection"])],
		},
		{
			"title": "Cómo se maneja",
			"body": "Moverte: %s\nSaltar: %s\nMirar: %s\nUsar una estación: %s\nPausa y menú: %s · Esta ayuda: %s\n\nSobre cada lugar importante flota su nombre: SALIDA, BLOQUEAR, SILENCIAR, PAUSA DIGITAL, CHECKPOINT y META. Al pasar por el %s se guarda tu progreso.\n\nPara la clase: %s muestra el mapa del grafo de los bots y %s hace una demostración de Dijkstra." % [
				key.call(keys), InputHints.key_markup(&"jump"), key.call("MOUSE"), key.call(interact),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help"), key.call("CHECKPOINT"),
				InputHints.key_markup(&"toggle_debug"), InputHints.key_markup(&"demo_route")],
		},
	]


func _build() -> void:
	_root = ColorRect.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.color = Color(0.06, 0.05, 0.14, 0.55)
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.PAPER, 0.98)
	style.set_corner_radius_all(36)
	style.corner_detail = 12
	style.set_border_width_all(2)
	style.border_color = Color("cdbcf7")
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 18
	style.content_margin_bottom = 20
	style.shadow_size = 18
	style.shadow_color = Color(Palette.INK, 0.35)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	_title = Label.new()
	_title.add_theme_font_override("font", HEADING_FONT)
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Palette.INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(640, 280)
	_body.add_theme_font_override("normal_font", BODY_FONT)
	_body.add_theme_font_size_override("normal_font_size", 21)
	_body.add_theme_color_override("default_color", Palette.INK)
	_body.add_theme_constant_override("line_separation", 4)
	box.add_child(_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_previous = _make_button("ANTERIOR", -1)
	row.add_child(_previous)
	_counter = Label.new()
	_counter.custom_minimum_size = Vector2(80, 0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_font_override("font", HEADING_FONT)
	_counter.add_theme_font_size_override("font_size", 22)
	_counter.add_theme_color_override("font_color", Palette.INK_SOFT)
	row.add_child(_counter)
	_next = _make_button("SIGUIENTE", 1)
	row.add_child(_next)

	_skip = TEXT_BUTTON.instantiate() as TextButton
	_skip.text = "SALTAR AYUDA"
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip.add_theme_font_size_override("font_size", 20)
	_skip.pressed.connect(close)
	box.add_child(_skip)


func _make_button(text: String, step: int) -> TextButton:
	var button := TEXT_BUTTON.instantiate() as TextButton
	button.text = text
	button.custom_minimum_size = Vector2(210, 52)
	button.pressed.connect(_go.bind(step))
	return button
