class_name NetPuppets
extends Node

#In a room, inside a round: sends where the player of this screen is 20 times a second and moves the puppets of the other computers with
#what comes from theirs. A shove made on another computer to the player of this one lands here

const SEND_EVERY := 0.05
#The strongest push a message may carry: anything bigger is a broken message, not a shove
const MAX_PUSH := 30.0

var _left := 0.0


func _ready() -> void:
	GameSession.net.state_received.connect(_on_state)
	GameSession.net.hit_received.connect(_on_hit)


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	#Added and not set: three physics frames of 1/60 leave a rest a hair above zero, and setting it sent only 15 times a second
	_left += SEND_EVERY
	var mine: Player = (get_parent() as RoundScene).everyone.get(GameSession.local_id)
	if mine != null and is_instance_valid(mine):
		GameSession.net.send_state(mine.remote_state())


func _on_state(player_id: int, state: Dictionary) -> void:
	var puppet: Player = (get_parent() as RoundScene).everyone.get(player_id)
	var at: Variant = state.get("p")
	if puppet == null or not is_instance_valid(puppet) or not puppet.remote or not (at is Array and (at as Array).size() == 3):
		return
	var place := Vector3(float(at[0]), float(at[1]), float(at[2]))
	if not place.is_finite():
		return
	puppet.set_remote_state(place, float(state.get("r", 0.0)), bool(state.get("m", false)), bool(state.get("a", false)),
		bool(state.get("po", false)), int(state.get("ps", 0)))


func _on_hit(state: Dictionary) -> void:
	var arena := get_parent() as ArenaRound
	var push: Variant = state.get("push")
	if arena == null or not (push is Array and (push as Array).size() == 3):
		return
	var shove := Vector3(float(push[0]), float(push[1]), float(push[2]))
	if not shove.is_finite():
		return
	arena.strike(GameSession.local_id, shove.limit_length(MAX_PUSH), clampf(float(state.get("strength", 0.35)), 0.0, 1.0))
