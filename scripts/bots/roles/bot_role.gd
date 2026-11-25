class_name BotRole
extends RefCounted

#How a bot picks its target vertex; like Pac-Man ghosts, each role is one way of hunting

enum Kind { CHASE, AMBUSH, GUARD, FLANK }


#Roles that already know where the players are need no sight
func needs_sight() -> bool:
	return true


#Target vertex for the watched player
func pick_target(bot: ChaserBot, ctx: ChaseContext, target: ChaseTarget) -> StringName:
	return direct_target(bot, ctx, target)


#Release delay after the round starts; "head_start" is the level base
func release_delay(head_start: float) -> float:
	return head_start


#Start vertex; "free" are the spawn vertices still free
func spawn_vertex(free: Array[StringName], _ctx: ChaseContext) -> StringName:
	return free[0]


#Player platform, or the end of its bridge that makes the bot cross
func direct_target(bot: ChaserBot, ctx: ChaseContext, target: ChaseTarget) -> StringName:
	var candidates := target.locator.chase_candidates()
	if candidates.size() == 1:
		return candidates[0]
	var bridge_open := ctx.graph.is_edge_enabled(candidates[0], candidates[1])
	var anchor := bot.anchor_vertex()
	var best: StringName = &""
	var best_cost := INF if not bridge_open else -1.0
	for candidate in candidates:
		var result := ctx.graph.shortest_path(anchor, candidate, ctx.forbidden)
		if not result.found:
			continue
		if bridge_open and result.cost > best_cost or not bridge_open and result.cost < best_cost:
			best_cost = result.cost
			best = candidate
	return best if best != &"" else bot.target_vertex
