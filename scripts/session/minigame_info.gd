class_name MinigameInfo
extends Resource

#How a minigame is shown and which scene runs it

@export var id: StringName
@export var title := ""
@export var tagline := ""
@export_file("*.tscn") var scene_path := ""
@export var accent := Palette.CORAL
@export var card_art: Texture2D
#Goal in seven words at most, shown in the draw
@export var brief := ""
#Up to three "action|word" keys ("move" is the four movement keys)
@export var keys: PackedStringArray = []
#Only ready minigames can be drawn for a session
@export var ready := false
