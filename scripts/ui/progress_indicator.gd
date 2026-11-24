class_name ProgressIndicator
extends Control

#A small vertical street on the side of the HUD: the head of the chosen character walks along it, up
#when the runner is far from the end line and down onto the "Lose" sign when it is about to be dragged

#Head of each character, by CharacterData.id; a new character only needs its line here
const ICONS: Dictionary[StringName, Texture2D] = {
	&"fire": preload("res://assets/ui/hud/FireIcon.png"),
	&"water": preload("res://assets/ui/hud/WaterIcon.png"),
	&"plant": preload("res://assets/ui/hud/PlantIcon.png"),
	&"lightning": preload("res://assets/ui/hud/BoltIcon.png"),
}
#Width over height of StreetIcon.png (255 x 1200)
const STREET_ASPECT := 255.0 / 1200.0

#Where the centre of the head goes, as a share of the street's height: at progress 1 (safe, top) and at
#progress 0 (resting right on top of the "Lose" sign, which stays readable)
@export_range(0.0, 1.0) var safe_spot := 0.09
@export_range(0.0, 1.0) var lose_spot := 0.74
#Width of the head against the width of the street picture
@export var icon_scale := 1.0
#How fast the head catches up with the real progress (higher is snappier)
@export var follow_speed := 8.0
#Under this progress the head beats to warn that the end line is near
@export_range(0.0, 1.0) var danger_below := 0.2

var _target := 1.0
var _shown := 1.0
var _beat := 0.0

@onready var _street: TextureRect = $Street
@onready var _icon: TextureRect = $Street/Icon


func _ready() -> void:
	resized.connect(_fit)
	_fit()


func _process(delta: float) -> void:
	_shown = lerpf(_shown, _target, 1.0 - exp(-follow_speed * delta))
	if _shown < danger_below:
		_beat += delta
		_icon.scale = Vector2.ONE * (1.0 + 0.12 * absf(sin(_beat * 9.0)))
	else:
		_beat = 0.0
		_icon.scale = Vector2.ONE
	_place_icon()


#Shows the head of the character with this id; an unknown id keeps the current head
func set_character(id: StringName) -> void:
	if ICONS.has(id):
		_icon.texture = ICONS[id]


#0 is on the end line, 1 as far from it as the runner can be; "instant" skips the glide
func set_progress(value: float, instant := false) -> void:
	_target = clampf(value, 0.0, 1.0)
	if instant:
		_shown = _target


#The height comes from the anchors; the width follows it so the street never stretches
func _fit() -> void:
	var width := size.y * STREET_ASPECT
	if not is_equal_approx(size.x, width):
		offset_right = offset_left + width
	var side := size.x * icon_scale
	_icon.size = Vector2(side, side)
	_icon.pivot_offset = _icon.size / 2.0
	_place_icon()


func _place_icon() -> void:
	var center_y := lerpf(lose_spot, safe_spot, _shown) * size.y
	#Never past the ends of the street, whatever the spots and the icon size are
	var top := clampf(center_y - _icon.size.y / 2.0, 0.0, maxf(size.y - _icon.size.y, 0.0))
	_icon.position = Vector2((size.x - _icon.size.x) / 2.0, top)
