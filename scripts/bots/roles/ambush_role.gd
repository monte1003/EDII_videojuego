class_name AmbushRole
extends BotRole

#The ambusher (Spam): waits where the player is going, a couple of platforms ahead on its way to the goal

const LOOKAHEAD := 2
#Within this cost of the player the ambush is over and it chases directly
const ENGAGE_COST := 2.0


func release_delay(_head_start: float) -> float:
	return 0.0


func pick_target(bot: ChaserBot, ctx: ChaseContext, target: ChaseTarget) -> StringName:
	var from := ctx.player_anchor(target)
	if ctx.cost(bot.anchor_vertex(), from) <= ENGAGE_COST:
		return direct_target(bot, ctx, target)
	var route := ctx.graph.shortest_path(from, ctx.goal)
	if not route.found or route.path.size() < 2:
		return direct_target(bot, ctx, target)
	var index := mini(LOOKAHEAD, route.path.size() - 1)
	#The goal is closed to the bots: wait at the last open platform before it
	while index > 0 and ctx.forbidden.has(route.path[index]):
		index -= 1
	if index == 0:
		return direct_target(bot, ctx, target)
	return route.path[index]
