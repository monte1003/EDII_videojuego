class_name ArenaGround
extends Node3D

#What an arena round asks of the world it plays on: build it from the layout, tell each locator where its player stands, show the
#pieces of each stage, move what moves and bounce a pad. ArenaWorld builds a map out of its layout; a round with a stage of its own
#builds it in another one


func build(_arena: ArenaLayout) -> void:
	pass


func watch(_locator: PlayerLocator) -> void:
	pass


func set_stage(_stage: int, _pop := true) -> void:
	pass


func update(_time: float) -> void:
	pass


func bounce_pad(_index: int) -> void:
	pass
