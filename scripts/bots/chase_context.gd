class_name ChaseContext
extends RefCounted

#What a bot knows about the level, filled by the level and only read by the bots

var graph: WeightedGraph
#Vertex id -> centre of its platform
var positions: Dictionary = {}
#Vertex id -> radius of its platform
var radii: Dictionary = {}
#Vertices the bots may never enter (the goal)
var forbidden: Array[StringName] = []
var player: Node3D
var locator: PlayerLocator
#Distance at which a bot notices the player; Silenciar lowers it
var detection_radius := 18.0
var player_protected := false
