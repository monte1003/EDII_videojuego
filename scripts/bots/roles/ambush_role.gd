class_name AmbushRole
extends BotRole

#Ambusher (Spam): waits a couple of platforms ahead of the player toward the goal

const LOOKAHEAD := 2
#Within this cost of the player it chases directly
const ENGAGE_COST := 2.5


func release_delay(_head_start: float) -> float:
	return 0.0


func pick_target(bot: ChaserBot, ctx: ChaseContext, seen: ChaseTarget) -> StringName:
	#Waits for the race leader
	var target := ctx.leader() if ctx.leader() != null else seen
	var from := ctx.player_anchor(target)
	if ctx.cost(bot.anchor_vertex(), from) <= ENGAGE_COST:
		return direct_target(bot, ctx, target)
	var route := ctx.graph.shortest_path(from, ctx.goal)
	if not route.found or route.path.size() < 2:
		return direct_target(bot, ctx, target)
	var index := mini(LOOKAHEAD, route.path.size() - 1)
	#The goal is closed to bots: wait at the last open platform
	while index > 0 and ctx.forbidden.has(route.path[index]):
		index -= 1
	if index == 0:
		return direct_target(bot, ctx, target)
	return route.path[index]
