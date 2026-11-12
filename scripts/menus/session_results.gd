extends Screen

#The end of the game: a line per round with its medal and points, the total with the medal of the whole game,
#and the standings when more than one played

const BUTTON_WIDTH := 300.0
const ENTER_ICON := preload("res://assets/ui/icons/key_enter.svg")
const ROW_WIDTH := 520.0
const ROW_STEP := 0.22
const COUNT_TIME := 0.9

var _column: VBoxContainer
var _button: GameButton
var _rows: Array[Control] = []
var _total_label: Label
var _total_badge: MedalBadge
var _record_label: Label
var _total := 0
var _local_id := GameState.PLAYER_ONE


func _ready() -> void:
	super()
	if GameSession.results.is_empty():
		GameSession.abandon()
		return
	add_child(SocialBackground.new())
	_build()
	_animate_in()
	_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_confirm"):
		get_viewport().set_input_as_handled()
		_confirm()


func _confirm() -> void:
	if accepts_confirm():
		GameSession.play_again()


func _build() -> void:
	_total = GameSession.total_of(_local_id)
	var best := 0
	for index in GameSession.results.size():
		if GameSession.results[index].points_of(_local_id) > GameSession.results[best].points_of(_local_id):
			best = index

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 10)
	center.add_child(_column)

	_column.add_child(_centered(UiKit.label("FIN DE LA PARTIDA", UiKit.BUTTON_FONT, 13, Palette.INK_SOFT)))
	_column.add_child(_build_total())
	_record_label = _centered(UiKit.label("NUEVO RÉCORD", UiKit.BUTTON_FONT, 14, Palette.PILL))
	_record_label.modulate.a = 0.0
	_column.add_child(_record_label)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(rows)
	for index in GameSession.results.size():
		var row := _build_row(GameSession.results[index], index == best and GameSession.results.size() > 1)
		row.modulate.a = 0.0
		rows.add_child(row)
		_rows.append(row)

	if GameSession.participants().size() > 1:
		_column.add_child(_build_standings())

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_column.add_child(gap)
	_button = UiKit.game_button("JUGAR DE NUEVO", true, BUTTON_WIDTH, true)
	_button.icon = ENTER_ICON
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_confirm)
	_column.add_child(_button)
	var menu := UiKit.text_button("MENÚ PRINCIPAL", Palette.AMBER, 14)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(GameSession.abandon)
	_column.add_child(menu)


#The medal of the whole game and the sum of its rounds, out of the most they can give
func _build_total() -> Control:
	var medal := GameSession.session_medal(_local_id)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	_total_badge = MedalBadge.make(medal, 104.0)
	_total_badge.modulate.a = 0.0
	row.add_child(_total_badge)
	var numbers := VBoxContainer.new()
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	numbers.alignment = BoxContainer.ALIGNMENT_CENTER
	numbers.add_theme_constant_override("separation", -6)
	row.add_child(numbers)
	_total_label = UiKit.label("0", UiKit.BUTTON_FONT, 60, Palette.INK)
	_total_label.custom_minimum_size = Vector2(250, 0)
	numbers.add_child(_total_label)
	var most := ScoreSheet.MAX_POINTS * GameSession.results.size()
	numbers.add_child(UiKit.label("%s  ·  DE %d" % [ScoreSheet.MEDAL_NAMES[medal].to_upper(), most], UiKit.BUTTON_FONT, 13, MedalBadge.RIM[medal]))
	return row


#One line per round: its medal, the game and the points; the best one carries a mark
func _build_row(result: RoundResult, is_best: bool) -> Control:
	var info := MinigameCatalog.find(result.minigame_id)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 14)
	line.add_child(MedalBadge.make(result.score.medal, 36.0))
	var name_label := UiKit.label(info.title.to_upper() if info != null else str(result.minigame_id), UiKit.BUTTON_FONT, 15, Palette.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	if is_best:
		line.add_child(UiKit.label("MEJOR RONDA", UiKit.BUTTON_FONT, 10, Palette.TEAL))
	if result.score.record:
		line.add_child(UiKit.label("RÉCORD", UiKit.BUTTON_FONT, 10, Palette.PILL))
	var points := UiKit.label(str(result.points_of(_local_id)), UiKit.BUTTON_FONT, 22, Palette.INK)
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points.custom_minimum_size = Vector2(84, 0)
	line.add_child(points)
	return line


#With several players: everybody from the first to the last, in the order the tree of scores gives
func _build_standings() -> Control:
	var places := GameSession.places()
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 4)
	table.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	table.add_child(_centered(UiKit.label("POSICIONES", UiKit.BUTTON_FONT, 12, Palette.INK_SOFT)))
	for entry in GameSession.standings():
		var slot := GameSession.lobby.find(entry.player_id)
		var mine := entry.player_id == _local_id
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var place := UiKit.label("%d.º" % places[entry.player_id], UiKit.BUTTON_FONT, 16, Palette.PILL if mine else Palette.INK_SOFT)
		place.custom_minimum_size = Vector2(44, 0)
		line.add_child(place)
		var shown := UiKit.body(slot.display_name if slot != null else "Jugador %d" % entry.player_id, 19, Palette.INK)
		shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(shown)
		line.add_child(UiKit.label(str(entry.points), UiKit.BUTTON_FONT, 18, Palette.INK))
		table.add_child(line)
	return table


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


#The column comes in, the rounds drop in one after the other and then the total counts up and its medal lands
func _animate_in() -> void:
	await get_tree().process_frame
	_column.pivot_offset = _column.size / 2.0
	_column.scale = Vector2.ONE * 0.94
	_column.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_column, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_column, "modulate:a", 1.0, 0.25)
	for index in _rows.size():
		var enter := create_tween()
		enter.tween_interval(0.3 + ROW_STEP * index)
		enter.tween_callback(_tick.bind(index))
		enter.tween_property(_rows[index], "modulate:a", 1.0, 0.18)
	var count := create_tween()
	count.tween_interval(0.3 + ROW_STEP * _rows.size())
	count.tween_method(_show_total, 0.0, 1.0, COUNT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	count.tween_callback(_land_medal)


func _tick(index: int) -> void:
	SynthSound.play(self, SynthSound.tone(587.0, 0.09, 0.0, 0.35), -13.0, 1.0 + 0.12 * index)


func _show_total(progress: float) -> void:
	_total_label.text = str(roundi(_total * progress))


func _land_medal() -> void:
	_total_label.text = str(_total)
	_total_badge.modulate.a = 1.0
	_total_badge.scale = Vector2.ONE * 2.2
	var land := create_tween()
	land.tween_property(_total_badge, "scale", Vector2(1.16, 0.86), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	land.tween_callback(SynthSound.play.bind(self, SynthSound.thump(0.2), -7.0, 1.15))
	land.tween_property(_total_badge, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if GameSession.session_record and _total > 0:
		land.tween_property(_record_label, "modulate:a", 1.0, 0.2)
