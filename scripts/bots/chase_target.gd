class_name ChaseTarget
extends RefCounted

#A player as the bots see it

var player_id := 0
var node: Node3D
var locator: PlayerLocator
#While protected the bots neither push nor wind up against it
var protected := false
#Distance to the goal, kept up to date by the level
var progress := INF
#Distance at which a bot notices this player; Silenciar lowers it
var detection_radius := 18.0
