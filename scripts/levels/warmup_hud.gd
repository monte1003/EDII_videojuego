class_name WarmupHud
extends RoundHud

#The warm-up screen: the clock, the keys for a few seconds and one line at the bottom to say you are ready

var _vote_row: HBoxContainer
var _vote_text: Label
var _count_label: Label


func _ready() -> void:
	toast_hold = 1.6
	toast_fade = 0.4
	low_time_seconds = 5
	super()
	_vote_row = HBoxContainer.new()
	_vote_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_vote_row.add_theme_constant_override("separation", 10)
	_vote_row.add_child(UiKit.key_chip(InputHints.key_label(&"ready"), 18))
	_vote_text = _text("ESTOY LISTO", UiKit.BUTTON_FONT, 18)
	_vote_row.add_child(_vote_text)
	_count_label = _text("0/1", UiKit.BODY_FONT, 20)
	_vote_row.add_child(_count_label)
	_bottom.add_child(_vote_row)
	_bottom.move_child(_vote_row, 0)
	var move_keys := " ".join([InputHints.key_label(&"move_forward"), InputHints.key_label(&"move_left"),
		InputHints.key_label(&"move_back"), InputHints.key_label(&"move_right")])
	show_mission("Prueba los controles", [
		"%s|mover" % move_keys, "%s|saltar" % InputHints.key_label(&"jump"),
		"%s ×2|barrer" % InputHints.key_label(&"jump"), "%s|usar" % InputHints.key_label(&"interact")], 6.0)


#How many already said they are ready, and whether this player did
func set_votes(count: int, total: int, mine: bool) -> void:
	_count_label.text = "%d/%d" % [count, total]
	_vote_text.text = "LISTO" if mine else "ESTOY LISTO"
	_vote_text.add_theme_color_override("font_color", Palette.GOLD if mine else Palette.PAPER)
