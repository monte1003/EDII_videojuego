class_name BotRoles
extends RefCounted

#Builds the role of a bot; each bot gets its own instance because a role may remember things


static func make(kind: int) -> BotRole:
	match kind:
		BotRole.Kind.AMBUSH:
			return AmbushRole.new()
		BotRole.Kind.GUARD:
			return GuardRole.new()
		BotRole.Kind.FLANK:
			return FlankRole.new()
	return ChaseRole.new()
