class_name FairFrame
extends CanvasLayer

#Fair screen frame: focus banner, live light, ranking of the day and staff hints

const COLUMN_WIDTH := 380.0
const STRIP_SECONDS := 7.0
const STRIPS: Array[Array] = [
	["JUEGAN 4 · 5 RONDAS · 1 CORONA", "LA SIGUIENTE PARTIDA PUEDE SER LA TUYA", "¿TU NOMBRE EN EL RANKING? ACÉRCATE"],
	["MODO AVIÓN: ACTIVADO", "EN ESTA RED SE JUEGA CARA A CARA", "LA MEJOR RACHA DE HOY NO ESTÁ EN UNA APP"],
]

var ranking := RankingPanel.new()

var _banner: PanelContainer
var _banner_detail: Label
var _banner_title: Label
var _seal: MedalBadge
var _live_dot := Panel.new()
var _live_text: Label
var _strip_labels: Array[Label] = []
var _strip_turn := 0
var _strip_left := STRIP_SECONDS
var _clock := 0.0
var _live := false
var _strips: Control
var _board := HBoxContainer.new()
var _finale := CenterContainer.new()
var _finale_ranking: RankingPanel
var _finale_lines := VBoxContainer.new()
var _full := CenterContainer.new()
var _full_text: Label
var _notice: PanelContainer
var _notice_text: Label


func _ready() -> void:
	#Above everything of the rounds, loading cover included
	layer = 40
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(_build_banner())
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(gap)
	_strips = _build_strips()
	left.add_child(_strips)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_theme_constant_override("separation", 10)
	_board.visible = false
	left.add_child(_board)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	row.add_child(column)
	column.add_child(_build_live())
	ranking.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(ranking)
	_build_finale()
	_build_full_list()
	_build_notice()
	show_focus("RumbleNet", "PANTALLA DE FERIA", ScoreSheet.Medal.NONE)
	set_live("BUSCANDO LA SALA", false)


func _process(delta: float) -> void:
	_clock += delta
	if _live:
		_live_dot.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_clock * 4.0))
	_strip_left -= delta
	if _strip_left <= 0.0:
		_strip_left = STRIP_SECONDS
		_strip_turn += 1
		for index in _strip_labels.size():
			_swap_text(_strip_labels[index], STRIPS[index][_strip_turn % STRIPS[index].size()])


#Who is on screen with its crown; the banner slides to the new one
func show_focus(title: String, detail: String, medal: int) -> void:
	if _banner_title.text == title and _banner_detail.text == detail:
		return
	_banner_title.text = title
	_banner_detail.text = detail
	_seal.medal = medal as ScoreSheet.Medal
	_seal.visible = medal != ScoreSheet.Medal.NONE
	_banner.reset_size()
	_banner.modulate.a = 0.0
	_banner.position.x = -24.0
	var slide := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(_banner, "modulate:a", 1.0, 0.35)
	slide.tween_property(_banner, "position:x", 0.0, 0.35)


#Coral and beating while a game is on, still and lilac otherwise
func set_live(text: String, live: bool) -> void:
	_live_text.text = text
	_live = live
	(_live_dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Palette.CORAL if live else Palette.LILAC
	if not live:
		_live_dot.modulate.a = 1.0


#Live board of the watched game, best first; empty rows restore the fair lines
func show_board(rows: Array[Dictionary]) -> void:
	_strips.visible = rows.is_empty()
	_board.visible = not rows.is_empty()
	for child in _board.get_children():
		child.queue_free()
	for index in rows.size():
		var row := rows[index]
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", _card(20, 8.0, 14.0))
		card.modulate.a = 0.55 if bool(row.get("gone", false)) else 1.0
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 9)
		card.add_child(line)
		line.add_child(UiKit.label("%d.º" % (index + 1), UiKit.BUTTON_FONT, 11, Palette.INK_SOFT))
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12.0, 12.0)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UiKit.box(row.get("color", Palette.LILAC), 6))
		line.add_child(dot)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -3)
		line.add_child(words)
		words.add_child(UiKit.label(str(row.get("name", "")), UiKit.HEADING_FONT, 18, Palette.INK))
		var points := "%d PTS" % int(row.get("total", 0))
		if int(row.get("gain", 0)) > 0:
			points += "  +%d" % int(row.get("gain", 0))
		words.add_child(UiKit.label(points, UiKit.BUTTON_FONT, 10, Palette.CORAL if int(row.get("gain", 0)) > 0 else Palette.INK_SOFT))
		_board.add_child(card)


#End of a game: big ranking with its rows and what happened
func show_finale(rows: Array[Array], fresh: Array[int], lines: Array[String]) -> void:
	_finale.visible = true
	_finale.modulate.a = 0.0
	create_tween().tween_property(_finale, "modulate:a", 1.0, 0.4)
	_finale_ranking.show_rows(rows, fresh, true)
	for child in _finale_lines.get_children():
		child.queue_free()
	for index in lines.size():
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", _card(20, 8.0, 18.0))
		var text := UiKit.label(lines[index], UiKit.BUTTON_FONT, 12 if index == 0 else 11, Palette.CORAL if index == 0 else Palette.INK)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.add_child(text)
		pill.modulate.a = 0.0
		_finale_lines.add_child(pill)
		create_tween().tween_property(pill, "modulate:a", 1.0, 0.4).set_delay(1.6 + 0.5 * index)


func hide_finale() -> void:
	if _finale.visible:
		var out := create_tween()
		out.tween_property(_finale, "modulate:a", 0.0, 0.4)
		out.tween_callback(_finale.hide)


#Staff view: every ranking entry in columns, or hidden
func toggle_full_list(rows: Array[Array]) -> void:
	_full.visible = not _full.visible
	if not _full.visible:
		return
	var lines: Array[String] = []
	for index in rows.size():
		lines.append("%d.º  %s  ·  %d" % [index + 1, str(rows[index][0]), int(rows[index][1])])
	_full_text.text = "\n".join(lines) if not lines.is_empty() else "Todavía no hay nadie en el ranking"


#Short staff notice at the top
func notice(text: String, seconds := 4.0) -> void:
	_notice_text.text = text
	_notice.visible = true
	_notice.modulate.a = 1.0
	var out := create_tween()
	out.tween_interval(seconds)
	out.tween_property(_notice, "modulate:a", 0.0, 0.4)
	out.tween_callback(_notice.hide)


func _build_finale() -> void:
	_finale.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale.visible = false
	add_child(_finale)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_finale.add_child(column)
	_finale_ranking = RankingPanel.new()
	_finale_ranking.custom_minimum_size = Vector2(460.0, 560.0)
	column.add_child(_finale_ranking)
	_finale_lines.add_theme_constant_override("separation", 8)
	column.add_child(_finale_lines)


func _build_full_list() -> void:
	_full.set_anchors_preset(Control.PRESET_FULL_RECT)
	_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.visible = false
	add_child(_full)
	var card := PanelContainer.new()
	var face := UiKit.card_style(0.97, 26)
	face.content_margin_left = 28.0
	face.content_margin_right = 28.0
	face.content_margin_top = 20.0
	face.content_margin_bottom = 20.0
	card.add_theme_stylebox_override("panel", face)
	_full.add_child(card)
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(UiKit.label("RANKING COMPLETO · F6 CIERRA", UiKit.BUTTON_FONT, 11, Palette.CORAL))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620.0, 520.0)
	column.add_child(scroll)
	_full_text = UiKit.label("", UiKit.BODY_FONT, 17, Palette.INK)
	scroll.add_child(_full_text)


func _build_notice() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 96.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_notice = PanelContainer.new()
	_notice.add_theme_stylebox_override("panel", _card(20, 10.0, 20.0))
	_notice.visible = false
	holder.add_child(_notice)
	_notice_text = UiKit.label("", UiKit.BUTTON_FONT, 12, Palette.INK)
	_notice.add_child(_notice_text)


func _build_banner() -> Control:
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override("panel", _card(26, 14.0, 22.0))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	_banner.add_child(line)
	var mark := TextureRect.new()
	mark.texture = AttractReel.MARK
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(50.0, 50.0)
	line.add_child(mark)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -4)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(words)
	_banner_detail = UiKit.label("", UiKit.BUTTON_FONT, 11, Palette.CORAL)
	words.add_child(_banner_detail)
	_banner_title = UiKit.label("", UiKit.HEADING_FONT, 34, Palette.INK)
	words.add_child(_banner_title)
	_seal = MedalBadge.make(ScoreSheet.Medal.NONE, 46.0)
	_seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_seal)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size.y = 80.0
	holder.add_child(_banner)
	return holder


func _build_live() -> Control:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _card(20, 9.0, 16.0))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	pill.add_child(line)
	_live_dot.custom_minimum_size = Vector2(12.0, 12.0)
	_live_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_live_dot.add_theme_stylebox_override("panel", UiKit.box(Palette.LILAC, 6))
	line.add_child(_live_dot)
	_live_text = UiKit.label("", UiKit.BUTTON_FONT, 11, Palette.INK)
	line.add_child(_live_text)
	return pill


func _build_strips() -> Control:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 12)
	for index in STRIPS.size():
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_theme_stylebox_override("panel", _card(20, 9.0, 18.0))
		var inside := HBoxContainer.new()
		inside.add_theme_constant_override("separation", 9)
		pill.add_child(inside)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(8.0, 8.0)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UiKit.box(Palette.CORAL if index == 0 else Palette.TEAL, 4))
		inside.add_child(dot)
		var text := UiKit.label(STRIPS[index][0], UiKit.BUTTON_FONT, 11, Palette.INK)
		inside.add_child(text)
		line.add_child(pill)
		_strip_labels.append(text)
	return line


func _swap_text(label: Label, text: String) -> void:
	var swap := create_tween()
	swap.tween_property(label, "modulate:a", 0.0, 0.25)
	swap.tween_callback(func() -> void: label.text = text)
	swap.tween_property(label, "modulate:a", 1.0, 0.25)


#Light rounded card with its soft shadow
func _card(radius: int, vertical: float, horizontal: float) -> StyleBoxFlat:
	var card := UiKit.box(Color(Palette.PAPER, 0.93), radius)
	card.content_margin_left = horizontal
	card.content_margin_right = horizontal + 4.0
	card.content_margin_top = vertical
	card.content_margin_bottom = vertical
	card.shadow_color = Color(Palette.INK, 0.18)
	card.shadow_size = 8
	card.shadow_offset = Vector2(0.0, 3.0)
	return card
