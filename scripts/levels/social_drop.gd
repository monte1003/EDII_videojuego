class_name SocialDrop
extends RoundScene

#SocialDrop memory game: memorize the card icons, then stand on the one the screens show

#FINAL: no time for another round
enum Phase { READY, GO, MEMORIZE, REACT, REST, FINAL, ENDED }

const MINIGAME_ID := &"social_drop"
#Per stage: distinct icons on the board (x) and cards with the target (y)
const STAGES: Array[Vector2i] = [
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 1),
]

#One per card kind; the name comes from assets/social_icons/<name>.png
@export var icons: Array[Texture2D] = []

@export_group("Round")
@export var time_limit := 80.0
#Screens say "YA" before the first memory; the clock starts then
@export var ready_seconds := 3.0
@export var go_seconds := 1.2
#Below this height the player fell
@export var fall_y := -2.5
#Camera a bit farther than other rounds to see the cards ahead
@export var camera_distance := 4.6
@export var camera_pitch := -26.0

@export_group("Memory")
#Seconds icons stay face up, shrinking over the round
@export var memorize_start := 4.0
@export var memorize_end := 3.0
#Countdown tick pitch from first to last
@export var tick_pitch_start := 0.9
@export var tick_pitch_end := 1.8

@export_group("Drop")
#Time to reach the card, shrinking faster near the end (reaction_curve > 1)
@export var reaction_start := 3.6
@export var reaction_end := 2.3
@export var reaction_curve := 1.6
#Doomed cards blink this long before dropping
@export var warning_seconds := 0.6
#Seconds to the next round; cards return drop_hold after the drop
@export var rest_seconds := 3.0
@export var drop_hold := 1.6

@export_group("Victory")
#Delay before the results to see the jump or fall
@export var end_delay := 1.5

var phase := Phase.READY
var elapsed := 0.0

var _players: Array[Player] = []
var _local: Player
#Each fallen player with the second it fell
var _fallen: Dictionary = {}
#Board from the room seed; effects from their own dice so they never change the board
var _rng := RandomNumberGenerator.new()
var _fx_rng := RandomNumberGenerator.new()
var _phase_timer := 0.0
var _memory_total := 1.0
var _countdown_shown := 0
var _chosen := -1
var _warned := false
var _restored := false
var _drops_survived := 0
#One spare life: the first fall returns to a safe card at a time cost
const SPARE_LIVES := 1
const REVIVE_COST := 10.0
var _spares_left := SPARE_LIVES
var _penalty := 0.0
var _missed_drop := false
var _reviving := false
#In a room this player is out: the board goes on for the others
var _out := false
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
	seed_rng(_rng)
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
		"move=%s|mover" % move_keys, "jump=%s|saltar" % InputHints.key_label(&"jump")], 4.0)
	_hud.set_time(time_limit)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_phase_timer = ready_seconds
	_world.screen_text("¿Listo?", Palette.GOLD)


func _help_allowed() -> bool:
	return phase != Phase.ENDED and not _out


#Everybody on the platform with its own id and camera
func _spawn_players() -> void:
	_players = spawn_players(_actors, _world.spawn_points())
	_local = RoundScene.local_of(_players)
	for player in _players:
		player.set_input_enabled(false)
		player.frame_camera(camera_distance, camera_pitch)
		player.landed.connect(_on_player_landed.bind(player))
	_local.view_camera().make_current()


func _physics_process(delta: float) -> void:
	#Card tweens stop with the pause and help
	_world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if paused or filming or phase == Phase.ENDED:
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


#Under the platform means out; this screen's player out ends the round here
func _check_falls() -> void:
	for player in _players:
		#A remote puppet only hides while under the board
		if player.remote:
			player.visible = player.global_position.y >= fall_y
			continue
		if _fallen.has(player.player_id) or player.global_position.y >= fall_y:
			continue
		if player == _local and (_reviving or _spares_left > 0):
			if not _reviving:
				_revive(player)
			continue
		_fallen[player.player_id] = elapsed
		if player == _local:
			#Out for good: the body stops and this computer watches the others
			player.set_physics_process(false)
			player.hide()
			_finish(false, "Caída", "")
			return
		player.set_physics_process(false)
		player.hide()


#Spare life: iris, back on a target card or the start, iris opens
func _revive(player: Player) -> void:
	_spares_left -= 1
	_reviving = true
	_penalty += REVIVE_COST
	_missed_drop = true
	iris.close(0.22)
	var back := create_tween()
	back.tween_interval(0.24)
	back.tween_callback(func() -> void:
		var spots := _world.spawn_points()
		var at: Vector3 = _world.cell_position(_chosen, player.global_position) if _chosen >= 0 else spots[0]
		player.global_position = at + Vector3(0.0, 0.6, 0.0)
		player.clear_motion()
		_reviving = false
		iris.open(0.45, 0.1)
		_world.screen_text("Última vida", Palette.CORAL))


func _go() -> void:
	phase = Phase.GO
	_phase_timer = go_seconds
	_world.screen_text("YA", Palette.TEAL)
	_hud.show_go()
	_local.set_input_enabled(true)


#Deal the stage, show the icons and count down
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


#Stage by the clock; the very last round is the hardest
func _stage_at(start: float) -> Vector2i:
	if _is_last_round(start):
		return STAGES[STAGES.size() - 1]
	var progress := clampf(start / time_limit, 0.0, 1.0)
	return STAGES[mini(int(progress * STAGES.size()), STAGES.size() - 1)]


#Whether no other round fits after this one
func _is_last_round(start: float) -> bool:
	var memorize := _memorize_time(start)
	return not _round_fits(start + memorize + _reaction_time(start + memorize) + rest_seconds)


#One rising tick per second; at zero the icons hide
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


#Cards turn to "?" and the screens show the target icon
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
		_drops_survived += 0 if _missed_drop else 1
		_missed_drop = false
		_world.restore()
		if _round_fits(elapsed + _phase_timer):
			_world.screen_text("Otra", Palette.GOLD)
		else:
			_world.screen_text("Casi", Palette.TEAL)
	if _phase_timer <= 0.0:
		if _round_fits(elapsed):
			_start_memorize()
		else:
			#No round starts that the clock would cut
			phase = Phase.FINAL


#Whether a round starting at "start" reaches its drop in time
func _round_fits(start: float) -> bool:
	var memorize := _memorize_time(start)
	return start + memorize + _reaction_time(start + memorize) <= time_limit


func _memorize_time(at: float) -> float:
	return lerpf(memorize_start, memorize_end, clampf(at / time_limit, 0.0, 1.0))


func _reaction_time(at: float) -> float:
	var progress := pow(clampf(at / time_limit, 0.0, 1.0), reaction_curve)
	return lerpf(reaction_start, reaction_end, progress)


#Landings of this screen's player and hard ones of the rest
func _on_player_landed(at: Vector3, hard: bool, player: Player) -> void:
	_world.press_tile(at)
	if hard or player == _local:
		ImpactFx.landing(self, player, hard, _fx_rng)


#Opening film from high over the board, then behind the player
func _film_shots() -> Array[RoundFilm.Shot]:
	var shots := super()
	if shots.is_empty():
		return shots
	var centre := playing_area().get_center()
	var facing := _pose_player.look_direction()
	var aside := Vector3(-facing.z, 0.0, facing.x)
	shots[0] = RoundFilm.Shot.new(centre - facing * 6.0 + aside * 8.0 + Vector3(0.0, 24.0, 0.0), centre, centre - facing * 12.0 - aside * 4.0 + Vector3(0.0, 15.0, 0.0), centre, 3.6)
	return shots


func _pose_allowed(_player_id: int) -> bool:
	return not paused and phase != Phase.ENDED and not _out


func _pose_shown() -> bool:
	return not paused and phase != Phase.ENDED and not _out


func _finish(victory: bool, title: String, message: String) -> void:
	if phase == Phase.ENDED or (_out and not victory):
		return
	#Time ran out after this player fell: nothing is told twice
	if _out:
		phase = Phase.ENDED
		_world.screen_text("Fin", Palette.TEAL)
		return
	if _networked_round() and not victory:
		_out = true
	else:
		phase = Phase.ENDED
	_local.set_input_enabled(false)
	#A late Esc must not open the pause over the final panel
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


#In a session the results take over; alone the HUD shows the end panel
func _end_round(victory: bool, title: String, message: String) -> void:
	#Seconds held; in a room the clock goes on after a fall
	var held_here: float = _fallen.get(_local.player_id, minf(elapsed, time_limit))
	var lines: Array[Array] = [
		["Segundos", "%d s" % floori(held_here)],
		["Caídas esquivadas", str(_drops_survived)],
	]
	var sheet := GameSession.score_sheet
	var points: Dictionary = {}
	for player in _players:
		var held: float = _fallen.get(player.player_id, minf(elapsed, time_limit))
		if player == _local:
			held = maxf(held - _penalty, 0.0)
		points[player.player_id] = sheet.drop_points(held / time_limit * sheet.drop_seconds)
	var score := RoundScore.make(sheet, points[_local.player_id], "%d de %d s" % [floori(held_here), int(time_limit)])
	if not finish_round(RoundResult.make(MINIGAME_ID, victory, title, message, lines).with_score(score, points)):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_hud.show_end(title, message, victory)


func _retry() -> void:
	if GameSession.is_playing_round():
		GameSession.restart_round()
	else:
		ScreenFlow.reload_current()


#Random icon other than "current" (-1 for any)
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
