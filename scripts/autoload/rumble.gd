extends Node

#The vibration of the pad of this computer. Every effect lives in one table: the weak motor (a fast buzz), the strong one (a deep thump),
#both from 0 to 1, and how many seconds it lasts. A round hands over the player of its screen and the round itself; the effects follow
#signals that already exist, so the game logic never asks for a vibration. A weaker effect never cuts a stronger one short, and the pad
#stops while the pause is open, when it goes away and when the game closes

const EFFECTS := {
	&"hit": {"weak": 0.55, "strong": 0.9, "seconds": 0.34},
	&"daze": {"weak": 0.75, "strong": 0.25, "seconds": 0.45},
	&"landing": {"weak": 0.2, "strong": 0.6, "seconds": 0.16},
	&"bump": {"weak": 0.22, "strong": 0.0, "seconds": 0.07},
	&"dive": {"weak": 0.3, "strong": 0.15, "seconds": 0.1},
	&"shove": {"weak": 0.45, "strong": 0.2, "seconds": 0.12},
	&"shove_hit": {"weak": 0.4, "strong": 0.7, "seconds": 0.2},
	&"fall": {"weak": 0.35, "strong": 0.5, "seconds": 0.5},
	&"finish": {"weak": 0.65, "strong": 0.55, "seconds": 0.55},
	&"count": {"weak": 0.25, "strong": 0.0, "seconds": 0.08},
	&"go": {"weak": 0.6, "strong": 0.45, "seconds": 0.28},
}

var enabled := true

var _player: Player
#Strength and end time of the effect that is playing, so a weaker one does not replace it
var _strength := 0.0
var _until := 0
var _paused := false
#The pad that got the last effect, kept here so it can still be stopped while the game closes
var _device := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop()


func _exit_tree() -> void:
	stop()


#Plays an effect of the table on the pad in use; nothing happens on the keyboard or without a pad ("force" is for the test screen,
#which plays it even when the button was clicked with the mouse)
func play(effect: StringName, force := false) -> void:
	var numbers: Dictionary = EFFECTS.get(effect, {})
	if numbers.is_empty() or InputDevice.pad < 0:
		return
	if not force and (not enabled or _paused or not InputDevice.uses_pad()):
		return
	var strength := maxf(numbers["weak"], numbers["strong"])
	var now := Time.get_ticks_msec()
	if now < _until and strength < _strength:
		return
	_strength = strength
	_until = now + int(numbers["seconds"] * 1000.0)
	_device = InputDevice.pad
	Input.start_joy_vibration(_device, numbers["weak"], numbers["strong"], numbers["seconds"])


func stop() -> void:
	_strength = 0.0
	_until = 0
	if _device >= 0:
		Input.stop_joy_vibration(_device)


#The player of this screen: its blows, its daze and its landings shake the pad (never a puppet of another computer)
func follow(player: Player) -> void:
	_player = player
	player.hit_taken.connect(_on_hit_taken)
	player.dazed_changed.connect(_on_dazed_changed)
	player.landed.connect(_on_landed)
	player.bumped.connect(_on_bumped)
	player.dive_landed.connect(_on_dive_landed)


#The round of the screen: its countdown, the fall of its player, its shoves and its finish line, and its pause, which stops the pad
func follow_round(round_scene: RoundScene) -> void:
	_paused = false
	round_scene.iris.closing.connect(play.bind(&"fall"))
	_follow_parts.call_deferred(round_scene)


#What a round builds in its own _ready, connected once it is all there
func _follow_parts(round_scene: RoundScene) -> void:
	if not is_instance_valid(round_scene):
		return
	var mine := round_scene.screen_player()
	if mine != null:
		follow(mine)
	for node in round_scene.find_children("*", "RoundHud", true, false):
		(node as RoundHud).counted.connect(_on_counted)
	var pause := round_scene.get_node_or_null("PauseMenu") as PauseMenu
	if pause != null:
		pause.opened.connect(_set_paused.bind(true))
		pause.closed.connect(_set_paused.bind(false))
		pause.tree_exiting.connect(_set_paused.bind(false))
	if round_scene.has_signal(&"shove_thrown"):
		round_scene.connect(&"shove_thrown", _on_shove_thrown)
	var rules: Variant = round_scene.get(&"rules")
	if rules is Object and (rules as Object).has_signal(&"racer_finished"):
		(rules as Object).connect(&"racer_finished", _on_racer_finished)


func _set_paused(on: bool) -> void:
	_paused = on
	if on:
		stop()


func _on_hit_taken(_hit: Player.Hit) -> void:
	play(&"hit")


func _on_dazed_changed(dazed: bool) -> void:
	if dazed:
		play(&"daze")


func _on_landed(_at: Vector3, hard: bool) -> void:
	if hard:
		play(&"landing")


func _on_bumped(_other: Player, _push: float) -> void:
	play(&"bump")


func _on_dive_landed(_at: Vector3) -> void:
	play(&"dive")


func _on_counted(number: int) -> void:
	play(&"go" if number == 0 else &"count")


func _on_shove_thrown(player_id: int, landed: bool) -> void:
	if _is_mine(player_id):
		play(&"shove_hit" if landed else &"shove")


func _on_racer_finished(player_id: int, _place: int) -> void:
	if _is_mine(player_id):
		play(&"finish")


func _is_mine(player_id: int) -> bool:
	return _player != null and is_instance_valid(_player) and _player.player_id == player_id
