extends Node

const CURSOR_PATH := "res://assets/ui/cursor/cursor.svg"
const HOTSPOT := Vector2(6, 5)


func _ready() -> void:
	#An Image so the texture is not kept alive at exit
	var image := (load(CURSOR_PATH) as Texture2D).get_image()
	Input.set_custom_mouse_cursor(image, Input.CURSOR_ARROW, HOTSPOT)
