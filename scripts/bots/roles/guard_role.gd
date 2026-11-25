class_name GuardRole
extends BotRole

#Guard (Hoax): holds the goal door the player heads for; Silenciar does not hide you

#Seconds at a door before it may change
const POST_HOLD := 3.0

var _post: StringName = &""
var _post_since := -100.0


func needs_sight() -> bool:
	return false


func release_delay(_head_start: float) -> float:
	return 0.0


func spawn_vertex(free: Array[StringName], ctx: ChaseContext) -> StringName:
	var doors := ctx.goal_doors()
	return doors[0] if not doors.is_empty() else free[0]


func pick_target(bot: ChaserBot, ctx: ChaseContext, target: ChaseTarget) -> StringName:
	var doors := ctx.goal_doors()
	if doors.is_empty():
		return direct_target(bot, ctx, target)
	var from := ctx.player_anchor(target)
	if doors.has(from):
		return direct_target(bot, ctx, target)
	if _post == &"" or bot.clock() - _post_since >= POST_HOLD:
		var wanted := _door_of_route(ctx, from, doors)
		if wanted != _post:
			_post = wanted
			_post_since = bot.clock()
	return _post


#Door on the player's shortest route to the goal
func _door_of_route(ctx: ChaseContext, from: StringName, doors: Array[StringName]) -> StringName:
	var route := ctx.graph.shortest_path(from, ctx.goal)
	if route.found and route.path.size() >= 2 and doors.has(route.path[route.path.size() - 2]):
		return route.path[route.path.size() - 2]
	return doors[0]
