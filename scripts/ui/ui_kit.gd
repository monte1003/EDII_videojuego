class_name UiKit
extends RefCounted

#The pieces every screen builds with, so spacing, shapes and fonts are the same everywhere

const HEADING_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const BODY_FONT: Font = preload("res://assets/ui/fonts/body_font.tres")
const BOLD_FONT: Font = preload("res://assets/ui/fonts/bold_font.tres")
const BUTTON_FONT: Font = preload("res://assets/ui/fonts/button_font.tres")
const GAME_BUTTON := preload("res://scenes/ui/game_button.tscn")
const TEXT_BUTTON := preload("res://scenes/ui/text_button.tscn")

const BUTTON_HEIGHT := 62.0
const BUTTON_WIDTH := 380.0
const STACK_GAP := 14


static func box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	return style


static func label(text: String, font: Font, size: int, color: Color) -> Label:
	var made := Label.new()
	made.text = text
	made.add_theme_font_override("font", font)
	made.add_theme_font_size_override("font_size", size)
	made.add_theme_color_override("font_color", color)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


static func heading(text: String, size: int, color := Palette.INK) -> Label:
	return label(text, HEADING_FONT, size, color)


static func body(text: String, size: int, color := Palette.INK_SOFT) -> Label:
	return label(text, BODY_FONT, size, color)


#The light card with a lilac border used by every panel of the game
static func card_style(alpha := 0.94, radius := 28) -> StyleBoxFlat:
	var style := box(Color(Palette.PAPER, alpha), radius)
	style.set_border_width_all(2)
	style.border_color = Palette.LILAC
	style.content_margin_left = 20
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_size = 12
	style.shadow_color = Color(Palette.INK, 0.25)
	return style


#The coral action button; secondary ones are white. All of one stack share width and height.
static func game_button(text: String, primary := true, width := BUTTON_WIDTH, pulse := false, font_size := 22) -> GameButton:
	var button := GAME_BUTTON.instantiate() as GameButton
	button.text = text
	button.custom_minimum_size = Vector2(width, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.add_theme_font_size_override("font_size", font_size)
	button.pulse = pulse
	if not primary:
		button.base_color = Palette.PAPER
		button.label_color = Palette.INK
	return button


static func text_button(text: String, accent := Palette.CORAL, size := 22) -> TextButton:
	var button := TEXT_BUTTON.instantiate() as TextButton
	button.text = text
	button.accent = accent
	button.add_theme_font_size_override("font_size", size)
	return button


#A key cap with its name, for the control hints
static func key_chip(key_name: String, size := 20) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := box(Color(Palette.PAPER, 0.92), 10)
	style.set_border_width_all(2)
	style.border_color = Palette.LILAC
	style.border_width_bottom = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(label(key_name, HEADING_FONT, size, Palette.INK))
	return chip
