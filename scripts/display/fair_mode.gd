extends Node

#The fair screen is this same game opened with --feria (from a shortcut): it goes straight to its own scene, with no menu for players.
#Without the argument nothing changes

const ARGUMENT := "--feria"
const SCENE := "res://scenes/display/fair_screen.tscn"

var active := false


func _ready() -> void:
	active = OS.get_cmdline_args().has(ARGUMENT) or OS.get_cmdline_user_args().has(ARGUMENT)
	if active:
		get_tree().change_scene_to_file.call_deferred(SCENE)
