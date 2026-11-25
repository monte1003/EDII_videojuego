class_name ArenaGround
extends Node3D

#What an arena round needs from its world: build, locate players, stage pieces and move them


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
