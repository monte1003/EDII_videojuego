class_name BotAppearance
extends Resource

#Look and wording of a bot; model_scene (a BotLook facing +Z) replaces the primitives

enum Detail { BROWS, NOTIFICATIONS, X_PLATE, MIRROR_PLATES }

@export var id: StringName
@export var display_name := ""
@export var body_color := Color.WHITE
@export var accent_color := Color.WHITE
@export var detail := Detail.BROWS
@export var model_scene: PackedScene
#Colour of this bot's route in the graph debug view
@export var debug_color := Color.WHITE
#Healthy-use tip shown the first time this bot pushes the player
@export var tip := ""
#How this bot hunts on the graph
@export var role := BotRole.Kind.CHASE
#One help line: what this bot does differently
@export var behavior := ""
