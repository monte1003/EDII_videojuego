class_name PodiumCeremony
extends Node3D

#The end of the game as a ceremony on a stage at night. A crane shot opens on the stage while PODIO drops letter by letter; then each player,
#from the last place up, drops onto its block with a jolt of the camera, its spotlight comes on and its crown comes down onto its head. For
#the first place the stage goes dark under a drum roll, the victory theme starts, the winner lands with a big shake, a flash, confetti and
#fireworks, ¡VICTORIA! bursts in, its crown comes down shining and the camera circles it while it dances; then everybody poses together.
#Alone, the player gets its crown of the whole game the same way. Enter skips to the end and then goes on to the numbers of the game

const MUSIC: AudioStream = preload("res://assets/audio/music/victory_theme.ogg")
#The victory theme swells for this long before its first big hit
const MUSIC_LEAD := 1.0
const FIGURE_SCALE := 1.6
const HEAD_BONE := &"mixamorig_HeadTop_End"
#Width of a crown in meters and how far it sits down into the head
const CROWN_WIDTH := 0.62
const CROWN_SINK := 0.1
const DROP_HEIGHT := 7.0
const WORD_KEYS: Array[StringName] = [&"", &"bronce", &"plata", &"oro", &"diamante"]
const CROWN_NAMES: Array[String] = ["SIN CORONA", "CORONA DE BRONCE", "CORONA DE PLATA", "CORONA DE ORO", "CORONA DE DIAMANTE"]
const CHIMES: Array[float] = [0.0, 659.0, 784.0, 988.0, 1319.0]
#Players of the demo, when the stage is opened on its own from the test menu
const DEMO_CHARACTERS: Array[StringName] = [&"fire", &"water", &"plant", &"lightning"]
const DEMO_POINTS: Array[int] = [3920, 3310, 2740, 2105]
const DANCES: Array[int] = [2, 3, 4, 5]

#How many players the demo shows (1 to 4)
static var demo_players := 4

class Figure:
	var entry: PodiumPlan.Entry
	var shown_name: String
	var root: Node3D
	var model: CharacterModel
	var skeleton: Skeleton3D
	var bone := -1
	var crown: Node3D
	var seated := false
	var tween: Tween


var _entries: Array[PodiumPlan.Entry] = []
var _order: Array[PodiumPlan.Entry] = []
var _figures: Dictionary = {}
var _stage: PodiumStage
var _camera: CinemaCamera
var _music: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _demo := false
var _skipped := false
var _done := false
var _leaving := false
#Seconds since the stage opened: a key still held from the screen before does nothing in the first ones
var _age := 0.0
var _firework_left := 0.0
var _fireworks_on := false

var _overlay: CanvasLayer
var _fade: ColorRect
var _flash: ColorRect
var _bars: Array[ColorRect] = []
var _lower: VBoxContainer
var _place_label: Label
var _name_label: Label
var _points_label: Label
var _skip_hint: Control
var _prompt: Control
var _headline: Node3D


func _ready() -> void:
	if ScreenFlow.tree.has(&"podium"):
		ScreenFlow.mark_current(&"podium")
	_rng.randomize()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var tree := _gather()
	var standings := tree.standings()
	var solo_medal := ScoreSheet.Medal.DIAMOND
	if not _demo and standings.size() == 1:
		solo_medal = GameSession.session_medal(standings[0].player_id)
	_entries = PodiumPlan.build(tree, solo_medal)
	_order = PodiumPlan.reveal_order(tree, _entries)
	_stage = PodiumStage.new()
	add_child(_stage)
	_stage.build(_entries)
	_camera = CinemaCamera.new()
	_camera.fov = 58.0
	add_child(_camera)
	_camera.make_current()
	for entry in _entries:
		_spawn_figure(entry)
	_music = AudioStreamPlayer.new()
	_music.stream = MUSIC
	_music.volume_db = -3.0
	add_child(_music)
	_build_overlay()
	_run()


func _process(delta: float) -> void:
	_age += delta
	for figure: Figure in _figures.values():
		if figure.seated:
			_seat_crown(figure)
	if _fireworks_on:
		_firework_left -= delta
		if _firework_left <= 0.0:
			_firework_left = _rng.randf_range(0.35, 0.9) if not _done else _rng.randf_range(1.2, 2.2)
			_stage.firework()


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("menu_confirm") or event.is_action_pressed("ready")) and _age > 0.6:
		get_viewport().set_input_as_handled()
		if not _done:
			_finish_now()
		else:
			_leave()


#The players from the session, or four players of the demo when the stage opens on its own
func _gather() -> AVLTree:
	if not GameSession.results.is_empty():
		return GameSession.ranking()
	_demo = true
	var tree := AVLTree.new()
	for index in clampi(demo_players, 1, 4):
		tree.insert(DEMO_POINTS[index], index + 1, DEMO_POINTS[index])
	return tree


func _character_of(player_id: int) -> CharacterData:
	if _demo:
		return load("res://resources/characters/%s.tres" % DEMO_CHARACTERS[(player_id - 1) % DEMO_CHARACTERS.size()]) as CharacterData
	var slot := GameSession.lobby.find(player_id)
	if slot != null and slot.character != null:
		return slot.character
	return GameSession.DEFAULT_CHARACTER


func _name_of(player_id: int) -> String:
	if _demo:
		return _character_of(player_id).display_name
	var slot := GameSession.lobby.find(player_id)
	return slot.display_name if slot != null else GameState.get_player_name(player_id)


func _spawn_figure(entry: PodiumPlan.Entry) -> void:
	var figure := Figure.new()
	figure.entry = entry
	figure.shown_name = _name_of(entry.player_id)
	figure.root = Node3D.new()
	figure.root.position = _stage.top_of(entry) + Vector3(0.0, DROP_HEIGHT + 40.0, 0.0)
	figure.root.scale = Vector3.ONE * FIGURE_SCALE
	add_child(figure.root)
	figure.model = _character_of(entry.player_id).model_scene.instantiate() as CharacterModel
	figure.root.add_child(figure.model)
	if not _demo:
		SkinVariant.apply(figure.model, GameSession.variant_of(entry.player_id))
	var skeletons := figure.model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		figure.skeleton = skeletons[0] as Skeleton3D
		figure.bone = figure.skeleton.find_bone(HEAD_BONE)
	_figures[entry.player_id] = figure


func _run() -> void:
	await _opening()
	if _skipped:
		return
	for index in _order.size() - 1:
		await _present(_order[index])
		if _skipped:
			return
	await _crown_winner(_order.back())
	if _skipped:
		return
	_finale()


#A crane shot from high over the crowd down to the stage while PODIO drops letter by letter
func _opening() -> void:
	var fade := create_tween()
	fade.tween_property(_fade, "color:a", 0.0, 1.0)
	_letterbox(true, 0.8)
	_camera.place(Vector3(0.0, 15.0, 32.0), Vector3(0.0, 4.0, 0.0))
	_camera.glide(Vector3(0.0, 4.6, 15.0), Vector3(0.0, 3.6, 0.0), 4.2, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	SynthSound.play(self, SynthSound.cheer(4.0), -15.0)
	_headline = PuffyWord.make(&"podio", 1.9, &"title", 0.15)
	_headline.position = Vector3(0.0, 10.6, PodiumStage.BACK + 0.6)
	add_child(_headline)
	_drop_letters(_headline, 7.0, 0.11)
	await _hold(3.9)


#One player drops onto its block, its light comes on and its crown comes down
func _present(entry: PodiumPlan.Entry) -> void:
	var figure: Figure = _figures[entry.player_id]
	var top := _stage.top_of(entry)
	var side := signf(top.x) if absf(top.x) > 0.1 else 1.0
	_camera.place(top + Vector3(side * 1.9, 0.5, 6.4), top + Vector3(0.0, 1.3, 0.0))
	_camera.glide(top + Vector3(side * 1.0, 1.2, 4.7), top + Vector3(0.0, 1.35, 0.0), 3.6)
	await _hold(0.35)
	if _skipped:
		return
	await _drop(figure, 0.45, 0.32)
	if _skipped:
		return
	_show_lower(entry)
	if await _hold(0.45):
		return
	_lower_crown(figure, 0.75)
	if await _hold(0.85):
		return
	_pose(figure, _rng.randi() % CharacterModel.POSES.size())
	if await _hold(1.35):
		return
	_hide_lower()


#The big reveal: dark stage and a drum roll, then the theme, the landing, the flash, the confetti, the word and the shining crown
func _crown_winner(entry: PodiumPlan.Entry) -> void:
	var figure: Figure = _figures[entry.player_id]
	var top := _stage.top_of(entry)
	_stage.dim(1.0, 0.9)
	_camera.place(top + Vector3(0.0, 0.2, 9.0), top + Vector3(0.0, 2.0, 0.0))
	_camera.glide(top + Vector3(0.0, 0.6, 6.6), top + Vector3(0.0, 1.9, 0.0), 2.6)
	_camera.zoom_to(50.0, 2.6)
	_stage.light_block(entry, 1.4, 1.2)
	SynthSound.play(self, SynthSound.roll(2.3), -5.0)
	if await _hold(2.3 - MUSIC_LEAD):
		return
	_music.play()
	if await _hold(MUSIC_LEAD):
		return
	_stage.dim(0.0, 0.25)
	_stage.light_block(entry, 14.0, 0.2)
	_flash_screen()
	await _drop(figure, 0.3, 0.9)
	if _skipped:
		return
	_stage.confetti()
	_stage.crowd.set_excitement(2.6)
	SynthSound.play(self, SynthSound.cheer(5.0), -8.0)
	_fireworks_on = true
	_firework_left = 0.2
	_show_headline(entry)
	_show_lower(entry)
	if await _hold(0.7):
		return
	_lower_crown(figure, 1.2)
	_camera.zoom_to(56.0, 1.0)
	_camera.orbit(top, 4.5, 1.9, -40.0, 38.0, 6.0, top + Vector3(0.0, 1.2, 0.0))
	if await _hold(1.3):
		return
	_pose(figure, DANCES[_rng.randi() % DANCES.size()])
	if await _hold(4.6):
		return


#Everybody together: a wide shot of the stage, every player posing, and the key to go on
func _finale() -> void:
	_done = true
	_hide_lower()
	if _entries.size() == 1:
		_camera.glide(Vector3(0.0, 3.8, 8.6), Vector3(0.0, 2.7, 0.0), 2.8)
	else:
		_camera.glide(Vector3(0.0, 3.9, 12.6), Vector3(0.0, 2.5, 0.0), 2.8)
	_camera.zoom_to(52.0, 2.8)
	for figure: Figure in _figures.values():
		if figure.entry != _order.back():
			_pose(figure, DANCES[_rng.randi() % DANCES.size()])
	_letterbox(false, 0.8)
	var show := create_tween()
	show.tween_property(_skip_hint, "modulate:a", 0.0, 0.3)
	show.tween_interval(0.8)
	show.tween_property(_prompt, "modulate:a", 1.0, 0.5)


#Enter before the end: everybody goes straight to its block with its crown and the last shot
func _finish_now() -> void:
	if _done:
		return
	_skipped = true
	for figure: Figure in _figures.values():
		if figure.tween != null and figure.tween.is_valid():
			figure.tween.kill()
		figure.root.position = _stage.top_of(figure.entry)
		figure.root.scale = Vector3.ONE * FIGURE_SCALE
		figure.model.set_state(false, false)
		_stage.light_block(figure.entry, 14.0 if figure.entry == _order.back() else 7.0, 0.2)
		if figure.crown == null:
			_lower_crown(figure, 0.0)
	if _headline != null and _headline.name == "podio":
		_headline.queue_free()
		_headline = null
	if _headline == null:
		_show_headline(_order.back())
	_stage.dim(0.0, 0.2)
	_stage.crowd.set_excitement(2.0)
	_fireworks_on = true
	if not _music.playing:
		_music.play(MUSIC_LEAD)
	var fade := create_tween()
	fade.tween_property(_fade, "color:a", 0.0, 0.25)
	_pose(_figures[_order.back().player_id], DANCES[0])
	_finale()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var out := create_tween()
	out.tween_property(_music, "volume_db", -40.0, 0.7)
	if _demo:
		GameSession.abandon()
	else:
		ScreenFlow.open(&"session_results")


#Falls from above onto its block in "seconds" and lands with a squash, dust and a jolt of the camera of "weight" (0 to 1)
func _drop(figure: Figure, seconds: float, weight: float) -> void:
	var top := _stage.top_of(figure.entry)
	figure.root.position = top + Vector3(0.0, DROP_HEIGHT * (1.0 + weight), 0.0)
	figure.model.set_state(false, true)
	SynthSound.play(self, SynthSound.whoosh(seconds + 0.15), -9.0, 1.0 + 0.4 * (1.0 - weight))
	figure.tween = create_tween()
	figure.tween.tween_property(figure.root, "position", top, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await figure.tween.finished
	if _skipped:
		return
	figure.model.set_state(false, false)
	_camera.shake(0.3 + 0.6 * weight)
	_camera.punch(3.0 + 8.0 * weight, 0.45)
	ImpactFx.dust(self, top, PodiumStage.CROWN_COLORS[figure.entry.crown].lightened(0.3), 14 + int(20 * weight))
	ImpactFx.ring(self, top + Vector3(0.0, 0.05, 0.0), Vector3.UP, PodiumStage.CROWN_COLORS[figure.entry.crown], 0.4, 2.2 + 2.0 * weight, 0.45)
	SynthSound.play(self, SynthSound.thump(0.3), -4.0 + 4.0 * weight, 1.0 - 0.2 * weight)
	if weight > 0.5:
		SynthSound.play(self, SynthSound.crash(0.7), -8.0, 0.8)
	_stage.light_block(figure.entry)
	figure.tween = create_tween()
	figure.tween.tween_property(figure.root, "scale", Vector3(1.22, 0.74, 1.22) * FIGURE_SCALE, 0.08)
	figure.tween.tween_property(figure.root, "scale", Vector3.ONE * FIGURE_SCALE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


#The crown comes down from over the head, turning, and sits; a chime in the note of its metal and a burst of sparkles
func _lower_crown(figure: Figure, seconds: float) -> void:
	if figure.entry.crown == ScoreSheet.Medal.NONE:
		return
	var crown := PropKit.make(StringName("crown_" + ["", "bronze", "silver", "gold", "diamond"][figure.entry.crown]), Vector3(CROWN_WIDTH, 0.0, 0.0))
	add_child(crown)
	figure.crown = crown
	var glow := OmniLight3D.new()
	glow.light_color = PodiumStage.CROWN_COLORS[figure.entry.crown]
	glow.omni_range = 2.2
	glow.light_energy = 1.6 if figure.entry.crown == ScoreSheet.Medal.DIAMOND else 0.9
	glow.position = Vector3(0.0, 0.3, 0.6)
	crown.add_child(glow)
	if seconds <= 0.0:
		figure.seated = true
		return
	var head := _head_point(figure)
	crown.global_position = head + Vector3(0.0, 2.2, 0.0)
	var land := create_tween().set_parallel()
	land.tween_method(func(share: float) -> void:
		var at := _head_point(figure)
		crown.global_position = at + Vector3(0.0, 2.2 * (1.0 - share), 0.0)
		crown.rotation.y = (1.0 - share) * TAU * 1.5, 0.0, 1.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await land.finished
	if not is_instance_valid(crown) or figure.crown != crown:
		return
	figure.seated = true
	SynthSound.play(self, SynthSound.chime(CHIMES[figure.entry.crown]), -6.0)
	ImpactFx.stars(self, _head_point(figure) + Vector3(0.0, 0.25, 0.0), 10)
	var pop := create_tween()
	pop.tween_property(crown, "scale", Vector3.ONE * 1.25, 0.1)
	pop.tween_property(crown, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	#The winner has its own big word over the stage
	if figure.entry != _order.back():
		_show_tier_word(figure)


#Top of the head right now, following the dance
func _head_point(figure: Figure) -> Vector3:
	if figure.skeleton == null or figure.bone < 0:
		return figure.root.global_position + Vector3(0.0, FIGURE_SCALE, 0.0)
	return (figure.skeleton.global_transform * figure.skeleton.get_bone_global_pose(figure.bone)).origin


#The crown follows the head: its place and how the head leans against its rest
func _seat_crown(figure: Figure) -> void:
	if figure.crown == null:
		return
	var tilt := Basis.IDENTITY
	if figure.skeleton != null and figure.bone >= 0:
		var now := (figure.skeleton.global_transform * figure.skeleton.get_bone_global_pose(figure.bone)).basis.orthonormalized()
		var rest := (figure.skeleton.global_transform * figure.skeleton.get_bone_global_rest(figure.bone)).basis.orthonormalized()
		tilt = now * rest.inverse()
	var spin := figure.crown.global_transform.basis.get_scale()
	figure.crown.global_transform = Transform3D(tilt.scaled(spin), _head_point(figure) - tilt * Vector3.UP * CROWN_SINK)


func _pose(figure: Figure, style: int) -> void:
	figure.model.play_move(CharacterModel.POSES[posmod(style, CharacterModel.POSES.size())], true, 0.25)


#The name of the crown pops over the player, letter by letter, and goes away
func _show_tier_word(figure: Figure) -> void:
	if figure.entry.crown == ScoreSheet.Medal.NONE:
		return
	var word := PuffyWord.make(WORD_KEYS[figure.entry.crown], 0.4, PodiumStage.WORD_COLOURS[figure.entry.crown], 0.2)
	word.position = _stage.top_of(figure.entry) + Vector3(0.0, FIGURE_SCALE + 0.95, -0.3)
	add_child(word)
	_pop_letters(word, 0.05)
	var away := create_tween()
	away.tween_interval(1.7)
	away.tween_property(word, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	away.tween_callback(word.queue_free)


#The word of the winner: ¡VICTORIA! with several players; alone, ¡GRAN PARTIDA! with a crown or ¡BUEN INTENTO! without one
func _show_headline(entry: PodiumPlan.Entry) -> void:
	if _headline != null:
		_headline.queue_free()
	var key := &"victoria"
	if _entries.size() == 1:
		key = &"gran_partida" if entry.crown != ScoreSheet.Medal.NONE else &"buen_intento"
	_headline = PuffyWord.make(key, 1.5, &"gold" if entry.crown != ScoreSheet.Medal.NONE else &"party", 0.25)
	_headline.position = Vector3(0.0, 9.0, PodiumStage.BACK + 0.6)
	add_child(_headline)
	_pop_letters(_headline, 0.06)


#The letters fall from "height" meters over their place one after the other and bounce on landing
func _drop_letters(word: Node3D, height: float, step: float) -> void:
	var letters := PuffyWord.letters(word)
	for index in letters.size():
		var letter := letters[index]
		var rest := letter.position
		letter.position = rest + Vector3(0.0, height / word.scale.y, 0.0)
		var fall := create_tween()
		fall.tween_interval(0.5 + step * index)
		fall.tween_property(letter, "position", rest, 0.42).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		fall.tween_callback(SynthSound.play.bind(self, SynthSound.land(0.12), -14.0, 1.0 + 0.06 * index))


#The letters burst from nothing one after the other, overshoot and settle
func _pop_letters(word: Node3D, step: float) -> void:
	var letters := PuffyWord.letters(word)
	for index in letters.size():
		var letter := letters[index]
		letter.scale = Vector3.ZERO
		letter.rotation.z = _rng.randf_range(-0.5, 0.5)
		var pop := create_tween().set_parallel()
		pop.tween_property(letter, "scale", Vector3.ONE, 0.55).set_delay(step * index).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		pop.tween_property(letter, "rotation:z", _rng.randf_range(-0.08, 0.08), 0.5).set_delay(step * index).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


#Waits on a timer of the stage, so a wait still running when the stage closes just never ends
func _hold(seconds: float) -> bool:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.01)
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()
	return _skipped


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 8
	add_child(_overlay)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top:
			bar.anchor_bottom = 0.0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
		_overlay.add_child(bar)
		_bars.append(bar)
	_lower = VBoxContainer.new()
	_lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lower.add_theme_constant_override("separation", -4)
	_lower.anchor_top = 1.0
	_lower.anchor_bottom = 1.0
	_lower.offset_left = 72.0
	_lower.offset_top = -250.0
	_lower.modulate.a = 0.0
	_overlay.add_child(_lower)
	_place_label = _outlined("", UiKit.BUTTON_FONT, 58, Palette.GOLD)
	_name_label = _outlined("", UiKit.HEADING_FONT, 40, Palette.PAPER)
	_points_label = _outlined("", UiKit.BUTTON_FONT, 18, Palette.LILAC)
	_lower.add_child(_place_label)
	_lower.add_child(_name_label)
	_lower.add_child(_points_label)
	_skip_hint = _key_hint(&"menu_confirm", "SALTAR", 13)
	_skip_hint.anchor_left = 1.0
	_skip_hint.anchor_right = 1.0
	_skip_hint.anchor_top = 1.0
	_skip_hint.anchor_bottom = 1.0
	_skip_hint.offset_left = -190.0
	_skip_hint.offset_top = -46.0
	_skip_hint.modulate.a = 0.55
	_overlay.add_child(_skip_hint)
	_prompt = _key_hint(&"menu_confirm", "CONTINUAR", 16)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -110.0
	_prompt.offset_top = -64.0
	_prompt.modulate.a = 0.0
	_overlay.add_child(_prompt)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_flash)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_fade)


#Black bars over and under the picture, like a film, or away
func _letterbox(on: bool, seconds: float) -> void:
	var height := get_viewport().get_visible_rect().size.y * (0.1 if on else 0.0)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bars[0], "offset_bottom", height, seconds)
	tween.tween_property(_bars[1], "offset_top", -height, seconds)


func _flash_screen() -> void:
	_flash.color.a = 0.85
	create_tween().tween_property(_flash, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


#The place, the name and the points of a player slide in at the bottom left
func _show_lower(entry: PodiumPlan.Entry) -> void:
	var figure: Figure = _figures[entry.player_id]
	var color := PodiumStage.CROWN_COLORS[entry.crown].lightened(0.15)
	if _entries.size() == 1:
		_place_label.text = CROWN_NAMES[entry.crown]
		_place_label.add_theme_font_size_override("font_size", 34)
	else:
		_place_label.text = "%d.º LUGAR" % entry.place
	_place_label.add_theme_color_override("font_color", color)
	_name_label.text = figure.shown_name.to_upper()
	_points_label.text = "%d PUNTOS" % entry.points
	_lower.position.x = 72.0 - 60.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lower, "modulate:a", 1.0, 0.3)
	tween.tween_property(_lower, "position:x", 72.0, 0.45)


func _hide_lower() -> void:
	create_tween().tween_property(_lower, "modulate:a", 0.0, 0.25)


func _outlined(text: String, font: Font, size_points: int, color: Color) -> Label:
	var label := UiKit.label(text, font, size_points, color)
	label.add_theme_color_override("font_outline_color", Color(Palette.NIGHT, 0.9))
	label.add_theme_constant_override("outline_size", maxi(roundi(size_points / 5.0), 4))
	return label


func _key_hint(action: StringName, word: String, size_points: int) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.action_chip(action, size_points, "ENTER"))
	var label := _outlined(word, UiKit.BUTTON_FONT, size_points, Palette.PAPER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row
