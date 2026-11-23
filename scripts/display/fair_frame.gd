class_name FairFrame
extends CanvasLayer

#The frame of the fair screen over the full-screen picture, drawn like the screens of the game (light cards, ink, a coral line, the seals
#of the medals). Top left, the banner of who or what is in focus, as the header of the lobby, with the seal of its crown when it has
#one; on the right, the light that says whether a game is on and, under it, the ranking of the day as tall as the screen; at the bottom
#left, two short lines of the fair that take turns

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


func _ready() -> void:
	layer = 10
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
	left.add_child(_build_strips())
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	row.add_child(column)
	column.add_child(_build_live())
	ranking.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(ranking)
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


#Who or what is on screen: the coral line over it, its name and the seal of its crown (none for NONE); the banner slides into the new one
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


#The light of the game: coral and beating while a game is on, still and lilac while there is none
func set_live(text: String, live: bool) -> void:
	_live_text.text = text
	_live = live
	(_live_dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Palette.CORAL if live else Palette.LILAC
	if not live:
		_live_dot.modulate.a = 1.0


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


#The light card of the screens of the game, round and a little see-through, with its soft shadow
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
