class_name SocialDrop
extends RoundScene

#SocialDrop: a platform of social media tiles. The giant screen spins through the icons and
#stops on one; only the tiles with that icon stay, the rest drop. Near the end rockets cross
#the rows too. Survive the time

#FINAL: the last drop is over and there is no time for another round
enum Phase { READY, GO, SPIN, REACT, REST, FINAL, ENDED }

const MINIGAME_ID := &"social_drop"
const MIX_RATE := 22050

#One per kind of tile; the name shown to the player comes from the file (SM-<Name>_Box.png)
@export var icons: Array[Texture2D] = []

@export_group("Round")
@export var time_limit := 80.0
#"¿Listo?" and "¡Vamos!" on the screen before the first spin; the clock starts with "¡Vamos!"
@export var ready_seconds := 1.6
@export var go_seconds := 1.2
#Below this height the player has fallen off the platform
@export var fall_y := -2.5
#The character looks bigger than usual so it reads well from the high camera
@export var player_scale := 2.2
#Height of the gold triangle that marks the player, over its feet
@export var marker_height := 3.6

@export_group("Spin")
@export var spin_seconds := 2.6
#Time between two images on the screen, at the start of the spin and right before it stops
@export var spin_interval_start := 0.05
@export var spin_interval_end := 0.34
#Pitch of the tick at the start of the spin and right before it stops
@export var tick_pitch_start := 0.8
@export var tick_pitch_end := 2.4

@export_group("Drop")
#Time to reach a safe tile once the screen stops; it shrinks from start to end over the round,
#slowly at first and faster near the end (reaction_curve > 1)
@export var reaction_start := 3.0
@export var reaction_end := 0.9
@export var reaction_curve := 1.6
#The tiles that will drop blink for this long right before they do
@export var warning_seconds := 0.6
#Seconds from a drop to the next spin; the tiles come back drop_hold seconds after the drop
@export var rest_seconds := 3.0
@export var drop_hold := 1.6

@export_group("Rockets")
#Rockets start flying across random rows once this many seconds are left
@export var rocket_seconds_left := 40.0
@export var rocket_interval_min := 2.2
@export var rocket_interval_max := 4.0
#The row blinks this long before the rocket comes out (it still needs a moment to arrive)
@export var rocket_warning := 1.0
@export var rocket_speed := 18.0
#Shove of a rocket that hits: far enough to throw the player off the platform
@export var rocket_knockback := Vector3(30.0, 6.0, 0.0)

@export_group("Victory")
#Time between the end and the results, to see the jump or the fall
@export var end_delay := 1.2

var phase := Phase.READY
var elapsed := 0.0

var _player: Player
var _rng := RandomNumberGenerator.new()
var _phase_timer := 0.0
var _spin_time := 0.0
var _next_change := 0.0
var _shown_icon := -1
var _chosen := -1
var _warned := false
var _restored := false
var _drops_survived := 0
var _hud_timer := 0.0
var _rockets_on := false
var _rocket_timer := 0.5
var _last_rocket_row := -1
var _hit_by_rocket := false
var _tick_sound: AudioStreamPlayer
var _rocket_sound: AudioStreamPlayer
var _boom_sound: AudioStreamPlayer
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
	_spawn_player()
	_tick_sound = _make_sound(_tone(1046.0, 0.05), -8.0)
	_stop_sound = _make_sound(_tone(1568.0, 0.55), -4.0)
	_drop_sound = _make_sound(_tone(220.0, 0.7, -140.0), -2.0)
	_rocket_sound = _make_sound(_tone(330.0, 0.9, 500.0), -6.0)
	_boom_sound = _make_sound(_tone(130.0, 0.6, -90.0), 0.0)

	_help.setup(HelpPages.social_drop({
		"time_limit": time_limit, "rest_seconds": rest_seconds, "columns": SocialDropWorld.COLUMNS,
		"rows": SocialDropWorld.ROWS, "rocket_seconds_left": rocket_seconds_left,
	}))
	_hud.retry_requested.connect(_retry)
	_hud.menu_requested.connect(GameSession.abandon)
	var move_keys := " ".join([InputHints.key_markup(&"move_forward"), InputHints.key_markup(&"move_left"),
		InputHints.key_markup(&"move_back"), InputHints.key_markup(&"move_right")])
	_hud.set_hint("%s para moverte · %s salta · Quédate en el ícono que salga en la pantalla" % [
		move_keys, InputHints.key_markup(&"jump")])
	_hud.set_time(time_limit)
	_hud.set_round(0)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_phase_timer = ready_seconds
	_world.screen_text("¿Listo?", Palette.GOLD)


func _help_allowed() -> bool:
	return phase != Phase.ENDED


func _spawn_player() -> void:
	var slot := participants[0]
	_player = PLAYER_SCENE.instantiate() as Player
	_player.player_id = slot.player_id
	_actors.add_child(_player)
	_player.global_position = _world.spawn_point()
	if slot.character != null:
		_player.set_character(slot.character)
	_player.set_model_scale(player_scale)
	_player.lock_camera()
	_player.set_input_enabled(false)
	_world.camera.make_current()


func _physics_process(delta: float) -> void:
	#The tiles move with tweens of the world: they stop with the pause and the help too
	_world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	_world.follow_player(_player.global_position, marker_height)
	if paused or phase == Phase.ENDED:
		return
	_phase_timer -= delta
	if phase == Phase.READY:
		if _phase_timer <= 0.0:
			_go()
		return

	elapsed += delta
	if _player.global_position.y < fall_y:
		if _hit_by_rocket:
			_finish(false, "¡Te derribó un cohete!",
				"Aguantaste %d s. Cuando una fila parpadea en rojo, sal de ella o salta justo cuando pase el cohete." % floori(elapsed))
		else:
			_finish(false, "¡Te caíste!",
				"Aguantaste %d s. Mira bien la pantalla y busca la casilla más cercana antes de que se detenga." % floori(elapsed))
		return
	if elapsed >= time_limit:
		_hud.set_time(0.0)
		_finish(true, "¡Sobreviviste!",
			"%d segundos sin caerte. No todo lo que aparece en redes es terreno firme: elige con calma dónde pisas." % int(time_limit))
		return

	match phase:
		Phase.GO:
			if _phase_timer <= 0.0:
				_start_spin()
		Phase.SPIN:
			_update_spin(delta)
		Phase.REACT:
			_update_react()
		Phase.REST:
			_update_rest()
	_update_rockets(delta)

	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_hud.set_time(time_limit - elapsed)


func _go() -> void:
	phase = Phase.GO
	_phase_timer = go_seconds
	_world.screen_text("¡Vamos!", Palette.TEAL)
	_player.set_input_enabled(true)
	_hud.toast("¡Párate en el ícono que elija la pantalla!")


func _start_spin() -> void:
	phase = Phase.SPIN
	_spin_time = 0.0
	_next_change = 0.0
	_chosen = _other_icon(_chosen)
	_hud.set_round(_drops_survived + 1)
	_hud.set_status("¡Mira la pantalla!")


#The screen changes faster at the start and slower near the end, and every change ticks a
#little higher, so the sound tells the spin is about to stop
func _update_spin(delta: float) -> void:
	_spin_time += delta
	if _spin_time >= spin_seconds:
		_stop_spin()
		return
	_next_change -= delta
	if _next_change > 0.0:
		return
	var progress := _spin_time / spin_seconds
	_shown_icon = _other_icon(_shown_icon)
	_world.screen_icon(_shown_icon, false)
	_tick_sound.pitch_scale = lerpf(tick_pitch_start, tick_pitch_end, pow(progress, 1.5))
	_tick_sound.play()
	_next_change = lerpf(spin_interval_start, spin_interval_end, progress * progress)


func _stop_spin() -> void:
	phase = Phase.REACT
	_phase_timer = _reaction_time(elapsed)
	_warned = false
	_shown_icon = _chosen
	_world.screen_icon(_chosen, true)
	_stop_sound.play()
	_hud.warn("¡Muévete!")
	_hud.set_status("¡Ve a %s!" % _icon_name(_chosen))


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
		_hud.set_status("¡Aguanta!")


func _update_rest() -> void:
	if not _restored and _phase_timer <= rest_seconds - drop_hold:
		_restored = true
		_drops_survived += 1
		_world.restore(_rng)
		if _round_fits(elapsed + _phase_timer):
			_world.screen_text("¡Otra vez!", Palette.GOLD)
			_hud.set_status("Nuevo tablero")
		else:
			_world.screen_text("¡Casi!", Palette.TEAL)
			_hud.set_status("¡Ya casi terminas!")
	if _phase_timer <= 0.0:
		if _round_fits(elapsed):
			_start_spin()
		else:
			#No round starts that the clock would cut: the last seconds just run out
			phase = Phase.FINAL


#Whether a spin starting at "start" reaches its drop before the time runs out
func _round_fits(start: float) -> bool:
	return start + spin_seconds + _reaction_time(start + spin_seconds) <= time_limit


func _reaction_time(at: float) -> float:
	var progress := pow(clampf(at / time_limit, 0.0, 1.0), reaction_curve)
	return lerpf(reaction_start, reaction_end, progress)


#In the last rocket_seconds_left seconds a rocket crosses a random row every few seconds; one
#that runs into the player throws it off the platform
func _update_rockets(delta: float) -> void:
	if not _hit_by_rocket:
		var direction := _world.rocket_hit(_player.global_position, 0.35)
		if direction != 0.0:
			_hit_by_rocket = true
			_player.set_input_enabled(false)
			_player.apply_push(Vector3(rocket_knockback.x * direction, rocket_knockback.y, 0.0))
			_boom_sound.play()
			_hud.warn("¡Cohete!")
	if time_limit - elapsed > rocket_seconds_left:
		return
	if not _rockets_on:
		_rockets_on = true
		_hud.toast("¡Cuidado! Ahora pasan cohetes por las filas")
	_rocket_timer -= delta
	#The last rocket must cross before the time is up
	if _rocket_timer > 0.0 or time_limit - elapsed < rocket_warning + 1.0:
		return
	_rocket_timer = _rng.randf_range(rocket_interval_min, rocket_interval_max)
	var row := _rng.randi() % SocialDropWorld.ROWS
	if row == _last_rocket_row:
		row = (row + 1 + _rng.randi() % (SocialDropWorld.ROWS - 1)) % SocialDropWorld.ROWS
	_last_rocket_row = row
	_world.launch_rocket(row, 1.0 if _rng.randf() < 0.5 else -1.0, rocket_warning, rocket_speed)
	_rocket_sound.play()


func _finish(victory: bool, title: String, message: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	_player.set_input_enabled(false)
	#A late Esc press must not open the pause menu over the final panel
	_pause_menu.set_process_unhandled_input(false)
	_hud.set_status("")
	if victory:
		_world.screen_text("¡Ganaste!", Palette.TEAL)
		_player.jump_requested = true
	else:
		_world.screen_text("¡Te caíste!", Palette.CORAL)
	var tween := create_tween()
	tween.tween_interval(end_delay)
	tween.tween_callback(_end_round.bind(victory, title, message))


#Inside a session the results screen takes over; on its own the HUD shows the end panel
func _end_round(victory: bool, title: String, message: String) -> void:
	var lines: Array[Array] = [
		["Aguantaste", "%d s" % floori(minf(elapsed, time_limit))],
		["Caídas esquivadas", str(_drops_survived)],
	]
	if not finish_round(RoundResult.make(MINIGAME_ID, victory, title, message, lines)):
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


#"SM-Facebook_Box.png" -> "Facebook"
func _icon_name(index: int) -> String:
	return icons[index].resource_path.get_file().get_basename().trim_prefix("SM-").trim_suffix("_Box")


func _make_sound(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.volume_db = volume
	sound.max_polyphony = 4
	add_child(sound)
	return sound


#A short synthesized beep that fades out; "sweep" slides its frequency (in Hz) over its length
static func _tone(frequency: float, length: float, sweep := 0.0) -> AudioStreamWAV:
	var count := int(MIX_RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase_angle := 0.0
	for index in count:
		var progress := float(index) / count
		phase_angle += TAU * (frequency + sweep * progress) / MIX_RATE
		var attack := minf(index / (MIX_RATE * 0.004), 1.0)
		var envelope := attack * pow(1.0 - progress, 2.0)
		var sample := (sin(phase_angle) + 0.3 * sin(phase_angle * 2.0)) * envelope * 0.55
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
