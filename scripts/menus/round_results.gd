extends Screen

#What happened in the round that just ended: the medal, the points, what is missing for the next one, and the way on

const BUTTON_WIDTH := 340.0
const ENTER_ICON := preload("res://assets/ui/icons/key_enter.svg")
const BADGE_SIZE := 118.0
const COUNT_TIME := 0.8
const COUNT_TICKS := 12

var _column: VBoxContainer
var _button: GameButton
var _badge: MedalBadge
var _points_label: Label
var _record_label: Label
var _score: RoundScore
var _ticks_played := 0


func _ready() -> void:
	super()
	if GameSession.results.is_empty():
		GameSession.abandon()
		return
	add_child(SocialBackground.new())
	_build()
	_animate_in()
	_button.grab_focus()


#Going back makes no sense here: Enter goes on
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_confirm"):
		get_viewport().set_input_as_handled()
		_confirm()


func _confirm() -> void:
	if accepts_confirm():
		GameSession.advance()


func _build() -> void:
	var result: RoundResult = GameSession.results.back()
	var info := MinigameCatalog.find(result.minigame_id)
	_score = result.score
	var sheet := GameSession.score_sheet

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 10)
	center.add_child(_column)

	var where := "PRÁCTICA" if GameSession.practice else "RONDA %d DE %d" % [GameSession.round_index + 1, GameSession.plan.size()]
	_column.add_child(_centered(UiKit.label("%s  ·  %s" % [where, info.title.to_upper() if info != null else ""], UiKit.BUTTON_FONT, 13, Palette.INK_SOFT)))
	_column.add_child(_centered(UiKit.label(result.headline.to_upper(), UiKit.BUTTON_FONT, 26, Palette.TEAL if result.won else Palette.CORAL)))

	if result.detail != "":
		var detail := _centered(UiKit.body(result.detail, 16))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(600, 0)
		_column.add_child(detail)

	_column.add_child(_build_score_row())
	_record_label = _centered(UiKit.label("NUEVO RÉCORD", UiKit.BUTTON_FONT, 14, Palette.PILL))
	_record_label.modulate.a = 0.0
	_column.add_child(_record_label)

	_column.add_child(_centered(UiKit.body(_score.metric, 21, Palette.INK)))
	var gap := sheet.gap_to_next(_score.points)
	if gap > 0:
		var next_medal := sheet.medal_for(_score.points) + 1
		_column.add_child(_centered(UiKit.body("%d para %s" % [gap, _with_article(next_medal)], 19)))

	if not _score.breakdown.is_empty():
		_column.add_child(_build_lines(_score.breakdown))
	elif not result.stats.is_empty():
		_column.add_child(_build_lines(result.stats))

	if not GameSession.practice:
		_column.add_child(_build_progress())
	var gap_button := Control.new()
	gap_button.custom_minimum_size = Vector2(0, 8)
	_column.add_child(gap_button)
	_button = UiKit.game_button(_next_text(), true, BUTTON_WIDTH, true)
	_button.icon = ENTER_ICON
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_confirm)
	_column.add_child(_button)
	if not GameSession.practice:
		var leave := UiKit.text_button("ABANDONAR PARTIDA", Palette.AMBER, 14)
		leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		leave.pressed.connect(GameSession.abandon)
		_column.add_child(leave)


#The medal on the left and, next to it, the points with the name of the medal under them
func _build_score_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
	_badge = MedalBadge.make(_score.medal, BADGE_SIZE)
	_badge.modulate.a = 0.0
	row.add_child(_badge)
	var numbers := VBoxContainer.new()
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	numbers.alignment = BoxContainer.ALIGNMENT_CENTER
	numbers.add_theme_constant_override("separation", -6)
	row.add_child(numbers)
	_points_label = UiKit.label("0", UiKit.BUTTON_FONT, 62, Palette.INK)
	_points_label.custom_minimum_size = Vector2(230, 0)
	numbers.add_child(_points_label)
	numbers.add_child(UiKit.label(_score.medal_name().to_upper(), UiKit.BUTTON_FONT, 15, MedalBadge.RIM[_score.medal]))
	return row


func _build_lines(lines: Array[Array]) -> Control:
	var grid := GridContainer.new()
	grid.columns = lines.size()
	grid.add_theme_constant_override("h_separation", 46)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for line in lines:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(_centered(UiKit.label(str(line[1]), UiKit.BUTTON_FONT, 19, Palette.INK)))
		cell.add_child(_centered(UiKit.label(str(line[0]).to_upper(), UiKit.BUTTON_FONT, 10, Palette.INK_SOFT)))
		grid.add_child(cell)
	return grid


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _with_article(medal: int) -> String:
	return ("la %s" if medal == ScoreSheet.Medal.SILVER else "el %s") % ScoreSheet.MEDAL_NAMES[medal]


func _next_text() -> String:
	if GameSession.practice:
		return "VOLVER A LA SALA"
	return "VER RESULTADOS" if GameSession.is_last_round() else "SIGUIENTE RONDA"


#One dot per round with the colour of the medal it gave
func _build_progress() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	for index in GameSession.plan.size():
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(18, 18)
		var style := UiKit.box(Color(Palette.INK, 0.18), 9)
		if index < GameSession.results.size():
			style.bg_color = MedalBadge.FILL[GameSession.results[index].score.medal]
			style.set_border_width_all(2)
			style.border_color = MedalBadge.RIM[GameSession.results[index].score.medal]
		pip.add_theme_stylebox_override("panel", style)
		row.add_child(pip)
	return row


func _animate_in() -> void:
	await get_tree().process_frame
	_column.pivot_offset = _column.size / 2.0
	_column.scale = Vector2.ONE * 0.94
	_column.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_column, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_column, "modulate:a", 1.0, 0.25)
	tween.chain().tween_callback(_land_medal)


#The medal drops on its place: it squashes, a ring of light opens around it and the screen shakes a little; then the points count up
func _land_medal() -> void:
	_badge.modulate.a = 1.0
	_badge.scale = Vector2.ONE * 2.4
	var land := create_tween()
	land.tween_property(_badge, "scale", Vector2(1.18, 0.84), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	land.tween_callback(_on_medal_landed)
	land.tween_property(_badge, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_medal_landed() -> void:
	var with_medal := _score.medal != ScoreSheet.Medal.NONE
	SynthSound.play(self, SynthSound.thump(0.2), -7.0, 1.2 if with_medal else 0.8)
	if with_medal:
		SynthSound.play(self, SynthSound.tone(880.0 + 110.0 * _score.medal, 0.5, 0.0, 0.4), -8.0)
		_burst()
	var home := _column.position
	var shake := create_tween()
	for offset: Vector2 in [Vector2(0, 5), Vector2(-3, -3), Vector2(2, 2), Vector2.ZERO]:
		shake.tween_property(_column, "position", home + offset, 0.04)
	var count := create_tween()
	count.tween_method(_show_points, 0.0, 1.0, COUNT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	count.tween_callback(_after_count)


#A ring that opens from the medal and fades
func _burst() -> void:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiKit.box(Color.TRANSPARENT, int(BADGE_SIZE))
	style.set_border_width_all(6)
	style.border_color = MedalBadge.FILL[_score.medal]
	ring.add_theme_stylebox_override("panel", style)
	ring.size = Vector2.ONE * BADGE_SIZE
	ring.pivot_offset = ring.size / 2.0
	_badge.add_child(ring)
	var open := create_tween().set_parallel()
	open.tween_property(ring, "scale", Vector2.ONE * 2.1, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	open.tween_property(ring, "modulate:a", 0.0, 0.45)
	open.chain().tween_callback(ring.queue_free)


func _show_points(progress: float) -> void:
	_points_label.text = str(roundi(_score.points * progress))
	var tick := floori(progress * COUNT_TICKS)
	if tick > _ticks_played and _score.points > 0:
		_ticks_played = tick
		SynthSound.play(self, SynthSound.tone(660.0, 0.07, 0.0, 0.35), -14.0, 1.0 + 0.07 * tick)


func _after_count() -> void:
	_points_label.text = str(_score.points)
	if not _score.record or _score.points <= 0:
		return
	_record_label.pivot_offset = _record_label.size / 2.0
	_record_label.scale = Vector2.ONE * 1.5
	var pop := create_tween().set_parallel()
	pop.tween_property(_record_label, "modulate:a", 1.0, 0.15)
	pop.tween_property(_record_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SynthSound.play(self, SynthSound.tone(1318.0, 0.4, 0.0, 0.4), -9.0)
