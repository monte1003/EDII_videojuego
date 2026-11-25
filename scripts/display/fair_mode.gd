extends Node

#Fair screen: the same game opened with --feria, or "Unirse como feria" from the menu

const ARGUMENT := "--feria"
const SCENE := "res://scenes/display/fair_screen.tscn"

var active := false
#Room picked from the menu; with --feria the screen reads feria.cfg
var address := ""

#Hides the main menu Godot creates before the fair screen is on
var _cover: CanvasLayer


func _ready() -> void:
	active = OS.get_cmdline_args().has(ARGUMENT) or OS.get_cmdline_user_args().has(ARGUMENT)
	if not active:
		return
	_cover = CanvasLayer.new()
	_cover.layer = 128
	var shade := ColorRect.new()
	shade.color = Palette.SKY_TOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(shade)
	add_child(_cover)
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().change_scene_to_file.call_deferred(SCENE)


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if _cover != null and scene != null and scene.scene_file_path == SCENE:
		_cover.queue_free()
		_cover = null
		get_tree().scene_changed.disconnect(_on_scene_changed)


#This computer becomes the fair screen of the picked room
func open(room_address: String) -> void:
	active = true
	address = room_address
	get_tree().change_scene_to_file(SCENE)
