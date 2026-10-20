class_name BotAppearance
extends Resource

#Look and wording of a bot; set model_scene (a BotLook facing +Z, feet at y = 0) to replace the primitives

enum Detail { BROWS, NOTIFICATIONS, X_PLATE, MIRROR_PLATES }

@export var id: StringName
@export var display_name := ""
@export var body_color := Color.WHITE
@export var accent_color := Color.WHITE
@export var detail := Detail.BROWS
@export var model_scene: PackedScene
#Colour of this bot's route in the graph debug view
@export var debug_color := Color.WHITE
#Short healthy-use message shown the first time this bot tries to push the player
@export var tip := ""
