class_name CharacterData
extends Resource

@export var id: StringName
@export var display_name: String
@export var accent_color := Color.WHITE
@export var portrait: Texture2D
@export var model_scene: PackedScene


#Characters without a 3D model stay locked
func is_available() -> bool:
	return model_scene != null
