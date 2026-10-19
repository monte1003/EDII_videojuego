class_name BotAppearance
extends Resource

#Looks and wording of a bot. The AI never reads the colours or the model: it only needs
#the debug colour and the tip. To use a final model, set "model_scene" (a scene whose root
#is a Node3D facing +Z, with its feet at y = 0); the provisional primitives are skipped.

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
