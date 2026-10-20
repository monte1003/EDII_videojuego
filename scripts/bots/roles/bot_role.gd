class_name BotRole
extends RefCounted

#How a bot picks its target vertex on the graph. Like the ghosts of Pac-Man, every role is one way of
#hunting: they share the walking, the push and the perception of ChaserBot and only differ here.

enum Kind { CHASE, AMBUSH, GUARD, FLANK }


#Roles that already know where the players are (a guard knows its zone) do not need to see them
func needs_sight() -> bool:
	return true


#The vertex this bot should go to, given the player it is paying attention to
func pick_target(bot: ChaserBot, ctx: ChaseContext, target: ChaseTarget) -> StringName:
	return direct_target(bot, ctx, target)


#Seconds after the round starts at which this bot is released; "head_start" is the base of the level
func release_delay(head_start: float) -> float:
	return head_start


#Where this role starts a round; "free" are the spawn vertices nobody took yet, in the level's order
func spawn_vertex(free: Array[StringName], _ctx: ChaseContext) -> StringName:
	return free[0]


#The player's platform, or the end of its bridge that makes the bot cross it
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
