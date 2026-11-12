class_name PhotobombRole
extends BotRole

#The photobomber: it heads for wherever the next photo is taken (the goal of the level) to be in it, and once there it bothers
#whoever shares the island. It needs to see nobody: it follows the drone like everybody else


func needs_sight() -> bool:
	return false


func pick_target(bot: ChaserBot, ctx: ChaseContext, target: ChaseTarget) -> StringName:
	if ctx.goal != &"" and ctx.graph.has_vertex(ctx.goal):
		return ctx.goal
	return direct_target(bot, ctx, target)
