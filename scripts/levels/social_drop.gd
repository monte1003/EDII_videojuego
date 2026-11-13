class_name SocialDrop
extends RoundScene

#SocialDrop, a memory game: nine cards show their app icons while the giant screens count down; then the cards turn into "?" and
#the screens show the icon to find. Only the cards that had it stay, the rest drop. Round after round the board shows more
#different icons and fewer cards with the one to find, until only a single card keeps it

#FINAL: the last drop is over and there is no time for another round
enum Phase { READY, GO, MEMORIZE, REACT, REST, FINAL, ENDED }

const MINIGAME_ID := &"social_drop"
#Each stage of the round: how many different icons the board shows (x) and on how many of the nine cards the icon to find is (y)
const STAGES: Array[Vector2i] = [
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 1),
]

#One per kind of card; the name shown to the player comes from the file (assets/social_icons/<name>.png)
@export var icons: Array[Texture2D] = []

@export_group("Round")
@export var time_limit := 80.0
#the screens say "YA" before the first memory, and the clock starts with it
@export var ready_seconds := 3.0
@export var go_seconds := 1.2
#Below this height the player has fallen off the platform
@export var fall_y := -2.5
#The camera of each player sits this far behind and this steeply above: a bit farther than in the other rounds, to see the cards ahead
@export var camera_distance := 4.6
@export var camera_pitch := -26.0

@export_group("Memory")
#Seconds the icons stay face up while the screens count down; it shrinks from start to end over the round
@export var memorize_start := 4.0
@export var memorize_end := 3.0
#Pitch of the tick of the countdown, from the first number to the last
@export var tick_pitch_start := 0.9
@export var tick_pitch_end := 1.8

@export_group("Drop")
#Time to reach the card once the screens show the icon; it shrinks from start to end over the round,
#slowly at first and faster near the end (reaction_curve > 1)
@export var reaction_start := 3.6
@export var reaction_end := 2.3
@export var reaction_curve := 1.6
#The cards that will drop blink for this long right before they do
@export var warning_seconds := 0.6
#Seconds from a drop to the next round; the cards come back drop_hold seconds after the drop
@export var rest_seconds := 3.0
@export var drop_hold := 1.6

@export_group("Victory")
#Time between the end and the results, to see the jump or the fall
@export var end_delay := 1.5

var phase := Phase.READY
var elapsed := 0.0

var _players: Array[Player] = []
var _local: Player
#Each player that fell, with the second of the round at which it did
var _fallen: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _phase_timer := 0.0
var _memory_total := 1.0
var _countdown_shown := 0
var _chosen := -1
var _warned := false
var _restored := false
var _drops_survived := 0
var _hud_timer := 0.0
var _tick_sound: AudioStreamPlayer
var _stop_sound: AudioStreamPlayer
var _drop_sound: AudioStreamPlayer

@onready var _world: SocialDropWorld = $World
@onready var _hud: SocialDropHud = $Hud


func _ready() -> void:
	super()
	if ScreenFlow.tree.has(MINIGAME_ID):
		ScreenFlow.mark_current(MINIGAME_ID)
	_rng.randomize()
	_world.build(icons, _rng)
	_spawn_players()
	_tick_sound = _make_sound(SynthSound.tone(1046.0, 0.08), -8.0)
	_stop_sound = _make_sound(SynthSound.tone(1568.0, 0.55), -4.0)
	_drop_sound = _make_sound(SynthSound.tone(220.0, 0.7, -140.0), -2.0)

	_help.setup(HelpPages.social_drop({
		"time_limit": time_limit, "rest_seconds": rest_seconds, "columns": SocialDropWorld.COLUMNS,
		"rows": SocialDropWorld.ROWS, "memorize_seconds": memorize_start,
		"first_copies": STAGES[0].y, "icons": icons.size(),
	}))
	_hud.retry_requested.connect(_retry)
	_hud.menu_requested.connect(GameSession.abandon)
	var move_keys := " ".join([InputHints.key_label(&"move_forward"), InputHints.key_label(&"move_left"),
		InputHints.key_label(&"move_back"), InputHints.key_label(&"move_right")])
	_hud.show_mission("Memoriza los íconos y pisa el que aparezca", [
		"%s|mover" % move_keys, "%s|saltar" % InputHints.key_label(&"jump")], 4.0)
	_hud.set_time(time_limit)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_phase_timer = ready_seconds
	_world.screen_text("¿Listo?", Palette.GOLD)


func _help_allowed() -> bool:
	return phase != Phase.ENDED


#Everybody stands on the platform at once, each with its own id and camera; this screen controls the first one
func _spawn_players() -> void:
	_players = spawn_players(_actors, _world.spawn_points())
	_local = _players[0]
	for player in _players:
		player.set_input_enabled(false)
		player.frame_camera(camera_distance, camera_pitch)
		player.landed.connect(_on_player_landed.bind(player))
	_local.view_camera().make_current()


func _physics_process(delta: float) -> void:
	#The cards move with tweens of the world: they stop with the pause and the help too
	_world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if paused or phase == Phase.ENDED:
		return
	_phase_timer -= delta
	if phase == Phase.READY:
		if _phase_timer <= 0.0:
			_go()
		else:
			_hud.tick_countdown(_phase_timer)
		return

	elapsed += delta
	_check_falls()
	if phase == Phase.ENDED:
		return
	if elapsed >= time_limit:
		_hud.set_time(0.0)
		_finish(true, "En pie", "")
		return

	match phase:
		Phase.GO:
			if _phase_timer <= 0.0:
				_start_memorize()
		Phase.MEMORIZE:
			_update_memorize()
		Phase.REACT:
			_update_react()
		Phase.REST:
			_update_rest()

	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_hud.set_time(time_limit - elapsed)


#A player that goes under the platform is out of the round; when it is the one at this screen, the round is over
func _check_falls() -> void:
	for player in _players:
		if _fallen.has(player.player_id) or player.global_position.y >= fall_y:
			continue
		_fallen[player.player_id] = elapsed
		if player == _local:
			_finish(false, "Caída", "")
			return
		player.set_physics_process(false)
		player.hide()


func _go() -> void:
	phase = Phase.GO
	_phase_timer = go_seconds
	_world.screen_text("YA", Palette.TEAL)
	_hud.show_go()
	_local.set_input_enabled(true)


#The board is dealt for the stage of the round, the cards turn face up and the screens count down while everybody looks for a good place
func _start_memorize() -> void:
	phase = Phase.MEMORIZE
	_memory_total = _memorize_time(elapsed)
	_phase_timer = _memory_total
	_countdown_shown = 0
	_chosen = _other_icon(_chosen)
	var stage := _stage_at(elapsed)
	_world.deal(_rng, _chosen, stage.x, stage.y)
	_world.set_stage(STAGES.find(stage))
	_hud.show_stage(STAGES.find(stage) + 1, STAGES.size())
	_hud.hide_target()
	_world.show_icons(true)


#The stage of the round that starts at "start": it moves on with the clock, and the very last round is always the hardest
func _stage_at(start: float) -> Vector2i:
	if _is_last_round(start):
		return STAGES[STAGES.size() - 1]
	var progress := clampf(start / time_limit, 0.0, 1.0)
	return STAGES[mini(int(progress * STAGES.size()), STAGES.size() - 1)]


#Whether no other round fits after the one that starts at "start"
func _is_last_round(start: float) -> bool:
	var memorize := _memorize_time(start)
	return not _round_fits(start + memorize + _reaction_time(start + memorize) + rest_seconds)


#One number per second on the screens, each tick a little higher; at zero the cards hide their icons
func _update_memorize() -> void:
	if _phase_timer <= 0.0:
		_reveal_target()
		return
	var shown := ceili(_phase_timer)
	if shown == _countdown_shown:
		return
	_countdown_shown = shown
	_world.screen_text(str(shown), Palette.PAPER)
	_tick_sound.pitch_scale = lerpf(tick_pitch_end, tick_pitch_start, clampf(float(shown) / _memory_total, 0.0, 1.0))
	_tick_sound.play()


#The cards turn into "?" and the screens show the icon that has to be stepped on
func _reveal_target() -> void:
	phase = Phase.REACT
	_phase_timer = _reaction_time(elapsed)
	_warned = false
	_world.show_icons(false)
	_world.screen_icon(_chosen, true)
	_stop_sound.play()
	_hud.show_target(icons[_chosen], _icon_name(_chosen))


func _update_react() -> void:
	if not _warned and _phase_timer <= warning_seconds:
		_warned = true
		_world.warn(_chosen, warning_seconds)
	if _phase_timer <= 0.0:
		phase = Phase.REST
		_phase_timer = rest_seconds
		_restored = false
		_world.drop(_chosen)
		_drop_sound.play()
		_hud.hide_target()


func _update_rest() -> void:
	if not _restored and _phase_timer <= rest_seconds - drop_hold:
		_restored = true
		_drops_survived += 1
		_world.restore()
		if _round_fits(elapsed + _phase_timer):
			_world.screen_text("Otra", Palette.GOLD)
		else:
			_world.screen_text("Casi", Palette.TEAL)
	if _phase_timer <= 0.0:
		if _round_fits(elapsed):
			_start_memorize()
		else:
			#No round starts that the clock would cut: the last seconds just run out
			phase = Phase.FINAL


#Whether a round starting at "start" reaches its drop before the time runs out
func _round_fits(start: float) -> bool:
	var memorize := _memorize_time(start)
	return start + memorize + _reaction_time(start + memorize) <= time_limit


func _memorize_time(at: float) -> float:
	return lerpf(memorize_start, memorize_end, clampf(at / time_limit, 0.0, 1.0))


func _reaction_time(at: float) -> float:
	var progress := pow(clampf(at / time_limit, 0.0, 1.0), reaction_curve)
	return lerpf(reaction_start, reaction_end, progress)


#Every landing of the player of this screen and the hard ones of the rest
func _on_player_landed(at: Vector3, hard: bool, player: Player) -> void:
	_world.press_tile(at)
	if hard or player == _local:
		ImpactFx.landing(self, player, hard, _rng)


func _finish(victory: bool, title: String, message: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	_local.set_input_enabled(false)
	#A late Esc press must not open the pause menu over the final panel
	_pause_menu.set_process_unhandled_input(false)
	_hud.hide_target()
	_hud.hide_mission()
	if victory:
		_world.screen_text("Fin", Palette.TEAL)
		_world.celebrate()
		_local.victory_hop()
		_hud.show_banner("%d S" % int(time_limit), "")
	else:
		_world.screen_text("Caída", Palette.CORAL)
		_hud.show_banner("CAÍDA", "%d s" % floori(elapsed), Palette.GOLD)
	get_tree().create_timer(end_delay).timeout.connect(_end_round.bind(victory, title, message))


#Inside a session the results screen takes over; on its own the HUD shows the end panel
func _end_round(victory: bool, title: String, message: String) -> void:
	var lines: Array[Array] = [
		["Segundos", "%d s" % floori(minf(elapsed, time_limit))],
		["Caídas esquivadas", str(_drops_survived)],
	]
	var sheet := GameSession.score_sheet
	var points: Dictionary = {}
	for player in _players:
		var held: float = _fallen.get(player.player_id, minf(elapsed, time_limit))
		points[player.player_id] = sheet.drop_points(held / time_limit * sheet.drop_seconds)
	var score := RoundScore.make(sheet, points[_local.player_id], "%d de %d s" % [floori(minf(elapsed, time_limit)), int(time_limit)])
	if not finish_round(RoundResult.make(MINIGAME_ID, victory, title, message, lines).with_score(score, points)):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_hud.show_end(title, message, victory)


func _retry() -> void:
	if GameSession.is_playing_round():
		GameSession.restart_round()
	else:
		ScreenFlow.reload_current()


#A random icon different from "current" (-1 for any)
func _other_icon(current: int) -> int:
	if icons.size() < 2:
		return 0
	var index := _rng.randi() % (icons.size() - 1) if current >= 0 else _rng.randi() % icons.size()
	if current >= 0 and index >= current:
		index += 1
	return index


#"me_gusta.png" -> "Me gusta"
func _icon_name(index: int) -> String:
	var words := icons[index].resource_path.get_file().get_basename().replace("_", " ")
	return words.substr(0, 1).to_upper() + words.substr(1)


func _make_sound(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.volume_db = volume
	sound.max_polyphony = 4
	add_child(sound)
	return sound
