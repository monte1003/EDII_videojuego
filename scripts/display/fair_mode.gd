extends Node

#The fair screen is this same game opened with --feria (from a shortcut): it goes straight to its own scene, with no menu for players.
#Without the argument nothing changes

const ARGUMENT := "--feria"
const SCENE := "res://scenes/display/fair_screen.tscn"

var active := false

#Godot creates the main menu before any autoload can stop it: this hides it until the fair screen is on
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
