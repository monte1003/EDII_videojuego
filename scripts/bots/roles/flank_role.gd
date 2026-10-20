class_name FlankRole
extends BotRole

#The flanker (Mirror): works with the direct hunter. It goes to the platform next to the player that is
#farthest from the hunter, so the player is caught between the two.

#Within this cost of the player the pincer is closed and it chases directly
const ENGAGE_COST := 2.0


func release_delay(head_start: float) -> float:
	return head_start * 1.5


func pick_target(bot: ChaserBot, ctx: ChaseContext, target: ChaseTarget) -> StringName:
	var from := ctx.player_anchor(target)
	if ctx.cost(bot.anchor_vertex(), from) <= ENGAGE_COST:
		return direct_target(bot, ctx, target)
	var partner := ctx.partner_of(bot, Kind.CHASE)
	var origin := partner.anchor_vertex() if partner != null else bot.anchor_vertex()
	var best := from
	var best_cost := ctx.cost(origin, from)
	for neighbor in ctx.graph.neighbors(from):
		if ctx.forbidden.has(neighbor):
			continue
		var distance := ctx.cost(origin, neighbor)
		if distance != INF and distance > best_cost and ctx.cost(bot.anchor_vertex(), neighbor) != INF:
			best_cost = distance
			best = neighbor
	return best
