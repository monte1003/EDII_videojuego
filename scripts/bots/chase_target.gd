class_name ChaseTarget
extends RefCounted

#A player as the bots see it: where it is on the graph and how easy it is to notice

var player_id := 0
var node: Node3D
var locator: PlayerLocator
#While protected the bots neither push nor start a windup against it
var protected := false
#How far this racer is from the goal (lower is closer), kept up to date by the level
var progress := INF
#Distance at which a bot notices this player; Silenciar lowers it
var detection_radius := 18.0
