class_name MinigameInfo
extends Resource

#A minigame the sessions can pick: how it is shown and which scene runs it

@export var id: StringName
@export var title := ""
@export var tagline := ""
@export_file("*.tscn") var scene_path := ""
@export var accent := Palette.CORAL
@export var card_art: Texture2D
#What to do, in seven words at most; the draw shows it under the title
@export var brief := ""
#Up to three keys as "action|word" ("move" stands for the four movement keys), as in "jump|saltar"
@export var keys: PackedStringArray = []
#Only ready minigames can be drawn for a session
@export var ready := false
