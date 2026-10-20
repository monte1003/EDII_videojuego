class_name MinigameInfo
extends Resource

#A minigame the sessions can pick: how it is shown and which scene runs it

@export var id: StringName
@export var title := ""
@export var tagline := ""
@export_file("*.tscn") var scene_path := ""
@export var accent := Palette.CORAL
@export var card_art: Texture2D
#Only ready minigames can be drawn for a session
@export var ready := false
