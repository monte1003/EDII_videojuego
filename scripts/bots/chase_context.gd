class_name ChaseContext
extends RefCounted

#What a bot knows about the level, filled by the level

#Extra cost of a vertex another bot is on or heading to
const TRAFFIC_COST := 2.0

var graph: WeightedGraph
var positions: Dictionary = {}
var radii: Dictionary = {}
#Vertices the bots may never enter (the goal)
var forbidden: Array[StringName] = []
#Where the players want to go; ambusher and guard think around it
var goal: StringName = &""
var targets: Array[ChaseTarget] = []
var bots: Array[ChaserBot] = []


func leader() -> ChaseTarget:
	var best: ChaseTarget = null
	for target in targets:
		if best == null or target.progress < best.progress:
			best = target
	return best


func target_of(player_id: int) -> ChaseTarget:
	for target in targets:
		if target.player_id == player_id:
			return target
	return null


#Platform of the player, or the end of its bridge closer to the goal
func player_anchor(target: ChaseTarget) -> StringName:
	var candidates := target.locator.chase_candidates()
	if candidates.size() == 1:
		return candidates[0]
	var best := candidates[0]
	var best_cost := INF
	for candidate in candidates:
		var route := graph.shortest_path(candidate, goal)
		if route.found and route.cost < best_cost:
			best_cost = route.cost
			best = candidate
	return best


#Shortest route cost for the bots; INF when there is none
func cost(from: StringName, to: StringName) -> float:
	var route := graph.shortest_path(from, to, forbidden)
	return route.cost if route.found else INF


#Open neighbours of the goal: the doors the players must cross
func goal_doors() -> Array[StringName]:
	var doors: Array[StringName] = []
	for neighbor in graph.neighbors(goal, true):
		if not forbidden.has(neighbor):
			doors.append(neighbor)
	return doors


#First other bot with the given role, for partner roles
func partner_of(bot: ChaserBot, role_kind: int) -> ChaserBot:
	for other in bots:
		if other != bot and other.role_kind() == role_kind:
			return other
	return null


#Penalties for vertices other bots use; never the bot's own destination
func traffic_for(bot: ChaserBot) -> Dictionary:
	var penalties: Dictionary = {}
	for other in bots:
		if other == bot or other.state == ChaserBot.State.INACTIVE:
			continue
		var heading := other.planned_vertices()
		for index in mini(heading.size(), 2):
			var vertex := heading[index]
			if vertex != bot.target_vertex and vertex != bot.anchor_vertex():
				penalties[vertex] = penalties.get(vertex, 0.0) + TRAFFIC_COST
	return penalties
