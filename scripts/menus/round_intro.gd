extends Screen

#Shows the draw of the next minigame as a feed that stops on the one GameSession already chose

const CARD_SIZE := Vector2(540, 206)
const CARD_GAP := 28.0
const WINDOW_SIZE := Vector2(640, 322)
const HEART := preload("res://assets/ui/icons/heart.svg")
const COMMENT := preload("res://assets/ui/icons/comment.svg")
const GLYPHS: Array[Texture2D] = [
	preload("res://assets/ui/icons/heart.svg"),
	preload("res://assets/ui/icons/bell.svg"),
	preload("res://assets/ui/icons/comment.svg"),
	preload("res://assets/ui/icons/thumb.svg"),
]

var _info: MinigameInfo
var _window: Control
var _reel: Control
var _cards: Array[Control] = []
var _target_card := 0
var _title_box: VBoxContainer
var _scroll: Tween
var _revealed := false
var _last_nearest := -1


func _ready() -> void:
	super()
	_info = GameSession.current_info()
	if _info == null:
		GameSession.abandon()
		return
	add_child(SocialBackground.new())
	_build_layout()
	_build_reel()
	_play()


#Enter or a click jumps to the end of the draw
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_confirm"):
		get_viewport().set_input_as_handled()
		_skip()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		_skip()


func _process(_delta: float) -> void:
	if _reel == null:
		return
	var nearest := 0
	var nearest_distance := INF
	for index in _cards.size():
		var card := _cards[index]
		var center := _reel.position.y + card.position.y + CARD_SIZE.y / 2.0 - WINDOW_SIZE.y / 2.0
		var distance := absf(center) / (CARD_SIZE.y + CARD_GAP)
		var focus := 1.0 - clampf(distance, 0.0, 1.0)
		if not _revealed:
			card.modulate.a = lerpf(0.35, 1.0, focus)
			card.scale = Vector2.ONE * lerpf(0.88, 1.0, focus)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	if nearest != _last_nearest and not _revealed:
		_last_nearest = nearest
		UiSound.play_hover()


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 44)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var heading := UiKit.heading(_round_text(), 30, Palette.CORAL)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var sub := UiKit.body(_round_subtitle(), 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)

	var middle := CenterContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 14)
	middle.add_child(stack)
	_window = Control.new()
	_window.custom_minimum_size = WINDOW_SIZE
	_window.clip_contents = true
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_window)
	_title_box = VBoxContainer.new()
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.modulate.a = 0.0
	_title_box.pivot_offset = Vector2(320, 40)
	stack.add_child(_title_box)
	var title := UiKit.heading(_info.title.to_upper(), 58, _info.accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(title)
	var tagline := UiKit.body(_info.tagline, 22)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(tagline)

	if not GameSession.practice:
		column.add_child(_build_progress())


func _round_text() -> String:
	if GameSession.practice:
		return "PRÁCTICA"
	return "RONDA %d DE %d" % [GameSession.round_index + 1, GameSession.plan.size()]


func _round_subtitle() -> String:
	if GameSession.practice:
		return "Una ronda suelta, sin partida"
	if GameSession.round_index == 0:
		return "¡Que empiece la partida!"
	if GameSession.is_last_round():
		return "La última: ya casi terminas"
	return "Sigue el feed"


func _build_progress() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	for index in GameSession.plan.size():
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(22, 22)
		var style := UiKit.box(Color(Palette.INK, 0.18), 11)
		if index < GameSession.round_index:
			style.bg_color = Palette.TEAL
		elif index == GameSession.round_index:
			style.bg_color = Palette.PILL
		pip.add_theme_stylebox_override("panel", style)
		row.add_child(pip)
	return row


#The feed: a few posts of the other candidates, then the chosen one, then two more
func _build_reel() -> void:
	_reel = Control.new()
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(_reel)
	var pool := MinigameCatalog.ready_entries()
	var chosen := maxi(pool.find(_info), 0)
	var length := (7 if GameSession.round_index <= 0 and not GameSession.practice else 5) if not GameSession.practice else 3
	_target_card = length
	var offset := posmod(chosen - _target_card, pool.size())
	for index in _target_card + 3:
		var info := pool[(offset + index) % pool.size()]
		var card := _make_card(info, index)
		card.position = Vector2((WINDOW_SIZE.x - CARD_SIZE.x) / 2.0, WINDOW_SIZE.y / 2.0 - CARD_SIZE.y / 2.0 + index * (CARD_SIZE.y + CARD_GAP))
		_reel.add_child(card)
		_cards.append(card)


func _make_card(info: MinigameInfo, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE / 2.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UiKit.card_style(0.97, 30))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(38, 38)
	avatar.add_theme_stylebox_override("panel", UiKit.box(info.accent, 19))
	header.add_child(avatar)
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_theme_constant_override("separation", -2)
	header.add_child(names)
	names.add_child(UiKit.heading("@rumblenet", 19))
	names.add_child(UiKit.body("hace un momento", 15))

	var art := PanelContainer.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_style := UiKit.box(info.accent, 20)
	art.add_theme_stylebox_override("panel", art_style)
	#The picture is cut to the rounded shape of the panel
	art.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	column.add_child(art)
	if info.card_art != null:
		var picture := TextureRect.new()
		picture.texture = info.card_art
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(picture)
	else:
		var over := HBoxContainer.new()
		over.alignment = BoxContainer.ALIGNMENT_CENTER
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		over.add_theme_constant_override("separation", 18)
		art.add_child(over)
		var glyph := TextureRect.new()
		glyph.texture = GLYPHS[index % GLYPHS.size()]
		glyph.custom_minimum_size = Vector2(70, 70)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.modulate = Color(Palette.PAPER, 0.95)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		over.add_child(glyph)
		var name_label := UiKit.heading(info.title.to_upper(), 38, Palette.PAPER)
		name_label.add_theme_color_override("font_outline_color", info.accent.darkened(0.3))
		name_label.add_theme_constant_override("outline_size", 8)
		over.add_child(name_label)

	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	var heart := _icon(HEART, Palette.PILL)
	heart.name = "Heart"
	footer.add_child(heart)
	footer.add_child(UiKit.heading("%d" % (400 + absi(hash(info.id)) % 600), 19))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	footer.add_child(gap)
	footer.add_child(_icon(COMMENT, Palette.INK_SOFT))
	footer.add_child(UiKit.heading("%d" % (30 + absi(hash(info.title)) % 90), 19))
	return card


func _icon(texture: Texture2D, color: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = color
	icon.pivot_offset = Vector2(13, 13)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _play() -> void:
	await get_tree().process_frame
	var seconds := 2.4 if GameSession.round_index <= 0 else 1.7
	if GameSession.practice:
		seconds = 1.0
	var target := -_target_card * (CARD_SIZE.y + CARD_GAP)
	_scroll = create_tween()
	_scroll.tween_property(_reel, "position:y", target + 18.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scroll.tween_property(_reel, "position:y", target, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_scroll.tween_callback(_reveal)


func _skip() -> void:
	if _reel == null:
		return
	if _revealed:
		_finish_soon(0.1)
		return
	if _scroll != null:
		_scroll.kill()
	_reel.position.y = -_target_card * (CARD_SIZE.y + CARD_GAP)
	_reveal(true)


#The chosen post gets its like, the rest fade and the name lands
func _reveal(fast := false) -> void:
	if _revealed:
		return
	_revealed = true
	var span := 0.15 if fast else 0.3
	for index in _cards.size():
		var card := _cards[index]
		if index == _target_card:
			create_tween().tween_property(card, "scale", Vector2.ONE * 1.07, span).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			card.modulate.a = 1.0
			_like(card)
		else:
			create_tween().tween_property(card, "modulate:a", 0.12, span)
	_title_box.scale = Vector2.ONE * 1.5
	var land := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	land.tween_property(_title_box, "modulate:a", 1.0, span)
	land.tween_property(_title_box, "scale", Vector2.ONE, span * 1.4)
	UiSound.play_click()
	_finish_soon(0.9 if not fast else 0.3)


func _like(card: Control) -> void:
	var heart := card.find_child("Heart", true, false) as TextureRect
	if heart == null:
		return
	var pop := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(heart, "scale", Vector2.ONE * 1.7, 0.18)
	pop.tween_property(heart, "scale", Vector2.ONE, 0.2)
	for index in 6:
		var spark := _icon(HEART, Palette.PILL)
		add_child(spark)
		spark.global_position = heart.global_position + Vector2(randf_range(-6.0, 6.0), 0.0)
		spark.scale = Vector2.ONE * randf_range(0.5, 0.9)
		var rise := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		rise.tween_property(spark, "global_position", spark.global_position + Vector2(randf_range(-40.0, 40.0), -randf_range(70.0, 130.0)), 0.8)
		rise.tween_property(spark, "modulate:a", 0.0, 0.8)
		rise.chain().tween_callback(spark.queue_free)


func _finish_soon(delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(GameSession.begin_round)
