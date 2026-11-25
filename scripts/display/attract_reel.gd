class_name AttractReel
extends Node3D

#Fair screen trailer built in the engine with the real game pieces, cut to the music in three acts

#Banner of the frame: who is on screen, the line over it and its crown
signal focus_changed(title: String, detail: String, medal: int)
signal started

#Seconds the winner is celebrated before the ranking takes over
const CELEBRATION := 7.0

const VICTORY: AudioStream = preload("res://assets/audio/music/victory_theme.ogg")
const PLAZA_THEME: AudioStream = preload("res://assets/audio/music/trend_war.ogg")
const MARK: Texture2D = preload("res://assets/ui/textures/mark.png")
#Bars of the two tracks and the first beat of the victory theme
const VICTORY_BAR := 2.043
const VICTORY_BEAT := 0.84
const PLAZA_BAR := 1.951
#Break of the trend war theme and the climb of the victory theme
const PLAZA_END := 40.5
const CLOSING_FROM := 22.0
const CLOSING_END := 36.2
const MUSIC_DB := -8.0
const STAGE_SCALE := 1.6
#Fast and slow motion and their ramp time in real seconds
const FAST_MOTION := 1.6
const SLOW_MOTION := 0.2
const RAMP := 0.35
#Game run speed and jump, so the legs match the run
const RUN_SPEED := 5.0
const HOP_SECONDS := 0.55
const HOP_HEIGHT := 0.9
#Cinema bars, a little closer at the big moments
const BARS := 0.075
const BARS_CLOSE := 0.1
#The ranking covers the right quarter: shift the subject to the middle of the rest
const FRAME_SHIFT := 0.23
const PLACES: Array[StringName] = [AttractSets.STAGE, AttractSets.PLAZA, AttractSets.PLATO, AttractSets.DROP]
#Crown of each character block on the stage, as on the podium
const CROWNS: Array[ScoreSheet.Medal] = [ScoreSheet.Medal.DIAMOND, ScoreSheet.Medal.GOLD, ScoreSheet.Medal.SILVER, ScoreSheet.Medal.BRONZE]
#Landing pose and closing dance of each character
const HERO_POSES: Array[int] = [0, 1, 2, 4]
const DANCES: Array[int] = [3, 5, 2, 4]
#SocialDrop card that stays when the others fall
const DROP_CARD := 3

var places: Dictionary = {}
var active: AttractSets.Place

var _camera := CinemaCamera.new()
var _board_middle := Vector3.ZERO
var _figures: Array[Figure] = []
var _track: AudioStreamPlayer
#Real-time clock of the track; cuts follow it, slow motion does not
var _track_from := 0.0
var _track_at := 0
var _players: Array[AudioStreamPlayer] = []
var _clock := 0.0
var _titles := TitleCard.new()
var _rng := RandomNumberGenerator.new()
var _veil := ColorRect.new()
var _flash := ColorRect.new()
var _bars: Array[ColorRect] = []
var _fireworks := false
var _firework_left := 0.0
#Runners the camera follows during the race
var _pack: Array[Figure] = []
var _pack_side := Vector3.ZERO
var _pack_ahead := Vector3.ZERO
var _pack_center := Vector3.ZERO
#stop() ends it at once; a new run waits two frames so runs never overlap
var _running := false
var _generation := 0
var _layer: CanvasLayer


class Figure:
	var root := Node3D.new()
	var model: CharacterModel
	var data: CharacterData


func _ready() -> void:
	_rng.seed = 2611
	_camera.fov = 55.0
	add_child(_camera)
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -40.0
		add_child(player)
		_players.append(player)
	for id in AttractSets.CHARACTERS:
		var figure := Figure.new()
		figure.data = load("res://resources/characters/%s.tres" % id) as CharacterData
		figure.model = figure.data.model_scene.instantiate() as CharacterModel
		figure.root.add_child(figure.model)
		figure.root.visible = false
		add_child(figure.root)
		_figures.append(figure)
	_build_overlay()
	_run.call_deferred()


func _process(delta: float) -> void:
	_clock += delta
	if active != null and active.ground != null:
		active.ground.update(_clock)
	if not _pack.is_empty():
		_follow_pack(delta)
	if _fireworks and active != null and active.podium != null:
		_firework_left -= delta
		if _firework_left <= 0.0:
			_firework_left = _rng.randf_range(0.45, 1.0)
			active.podium.firework()


func _exit_tree() -> void:
	_running = false
	Engine.time_scale = 1.0
	#Places waiting out of the tree go with the trailer
	for place: AttractSets.Place in places.values():
		if place != active and is_instance_valid(place.root):
			place.root.queue_free()


#Builds the places one per frame behind a night veil
func _run() -> void:
	_veil.color.a = 1.0
	for id in PLACES:
		places[id] = AttractSets.build(id, self)
		await get_tree().process_frame
	started.emit()


#Plays the three acts in a loop until stop()
func play() -> void:
	if not await _begin():
		return
	while _running:
		await _act_stage()
		if not _running:
			return
		await _act_maps()
		if not _running:
			return
		await _act_closing()


#Stops at once: music, motion, places and picture
func stop() -> void:
	_running = false
	_generation += 1
	Engine.time_scale = 1.0
	_pack.clear()
	_fireworks = false
	for player in _players:
		player.stop()
	_track = null
	_clear_words()
	_hide_figures()
	if active != null:
		remove_child(active.root)
		active = null
	visible = false
	_layer.visible = false


#Winner dancing on the stage; after CELEBRATION the stage stays with the camera circling
func celebrate(character: StringName, shown_name: String, points: int, lines: Array[String]) -> void:
	if not await _begin():
		return
	_show(AttractSets.STAGE)
	_hide_figures()
	_play(VICTORY, CLOSING_FROM)
	_fade(false, 0.6)
	_letterbox(BARS_CLOSE, 0.01)
	_camera.make_current()
	var top := active.podium.top_of(AttractSets.entry_of(active, 0))
	var winner := _figures[maxi(AttractSets.CHARACTERS.find(character), 0)]
	_stand(winner, top + Vector3(0.0, 7.0, 0.0), top + Vector3(0.0, 0.0, 6.0), STAGE_SCALE)
	winner.model.set_state(false, true)
	focus_changed.emit(shown_name, "GANADOR · %d PUNTOS" % points, ScoreSheet.Medal.DIAMOND)
	_shift(6.0)
	_camera.zoom_to(55.0, 0.01)
	_camera.place(top + Vector3(1.4, 0.6, 7.4), top + Vector3(0.0, 1.8, 0.0))
	_camera.glide(top + Vector3(0.8, 1.2, 5.6), top + Vector3(0.0, 2.0, 0.0), 2.0, Tween.TRANS_QUAD, Tween.EASE_OUT)
	var fall := create_tween()
	fall.tween_property(winner.root, "position", top, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	if not _running:
		return
	winner.model.set_state(false, false)
	_squash(winner)
	_camera.shake(0.5)
	_flash_screen(0.7)
	active.podium.light_block(AttractSets.entry_of(active, 0), 14.0, 0.2)
	active.podium.crowd.set_excitement(2.6)
	_fireworks = true
	SynthSound.play(self, SynthSound.cheer(5.0), -8.0)
	_say(lines)
	if not await _wait_real(0.6):
		return
	_pose(winner, DANCES[maxi(AttractSets.CHARACTERS.find(character), 0)])
	if not await _wait_real(CELEBRATION - 0.6):
		return
	_clear_words()
	_shift(12.0)
	_camera.orbit(Vector3(0.0, 0.0, 1.0), 12.0, 4.0, -35.0, 35.0, 24.0, Vector3(0.0, 3.0, 0.0))
	_running = false


#The winner jumps for joy at a new record
func cheer() -> void:
	for figure in _figures:
		if figure.root.visible:
			_hop(figure)


#Waits two frames so the previous run has seen stop()
func _begin() -> bool:
	_running = false
	_generation += 1
	var mine := _generation
	await get_tree().process_frame
	await get_tree().process_frame
	while places.size() < PLACES.size():
		await get_tree().process_frame
	if mine != _generation:
		return false
	_running = true
	visible = true
	_layer.visible = true
	return true


#Act one: night stage, logo on the first beat, one character landing per bar
func _act_stage() -> void:
	_show(AttractSets.STAGE)
	_hide_figures()
	_play(VICTORY, 0.0)
	_fade(false, 1.4)
	_letterbox(BARS_CLOSE, 0.01)
	_camera.make_current()
	_camera.zoom_to(55.0, 0.01)
	_shift(10.5)
	_camera.place(Vector3(0.0, 16.0, 34.0), Vector3(0.0, 6.0, 0.0))
	_camera.glide(Vector3(0.0, 8.6, 4.6), Vector3(0.0, 8.9, -5.9), 4.4, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	active.podium.crowd.set_excitement(1.2)
	focus_changed.emit("RumbleNet", "DEL FEED AL RING", ScoreSheet.Medal.NONE)
	SynthSound.play(self, SynthSound.cheer(4.0), -17.0)
	if not await _until(VICTORY_BEAT):
		return
	_flash_screen(0.45)
	_camera.shake(0.3)
	_titles.title("DEL FEED AL RING")
	if not await _until(VICTORY_BEAT + 2.0 * VICTORY_BAR):
		return
	_clear_words()
	for index in _figures.size():
		await _hero(index, VICTORY_BEAT + (3.0 + index) * VICTORY_BAR)
		if not _running:
			return
	focus_changed.emit("Los cuatro", "EN ESCENA", ScoreSheet.Medal.NONE)
	_shift(13.0)
	_camera.place(Vector3(0.0, 2.6, 11.5), Vector3(0.0, 2.4, 0.0))
	_camera.glide(Vector3(0.0, 3.6, 14.5), Vector3(0.0, 2.8, 0.0), VICTORY_BAR * 1.2)
	_say(["AQUÍ NADIE TE", "DEJA EN VISTO."])
	if not await _until(VICTORY_BEAT + 7.0 * VICTORY_BAR):
		return
	_clear_words()
	_flash_screen(0.8)


#A character lands on its block, lights up, shows its name and poses
func _hero(index: int, until: float) -> void:
	var figure := _figures[index]
	var entry := AttractSets.entry_of(active, index)
	var top := active.podium.top_of(entry)
	var side := signf(top.x) if absf(top.x) > 0.1 else 1.0
	_shift(5.4)
	_camera.place(top + Vector3(side * 2.2, 0.5, 7.0), top + Vector3(0.0, 1.7, 0.0))
	_camera.glide(top + Vector3(side * 1.1, 1.0, 4.9), top + Vector3(0.0, 1.8, 0.0), until - _now(), Tween.TRANS_QUAD, Tween.EASE_OUT)
	_stand(figure, top + Vector3(0.0, 7.0, 0.0), top + Vector3(side * 1.5, 0.0, 6.0), STAGE_SCALE)
	figure.model.set_state(false, true)
	focus_changed.emit(figure.data.display_name, "PERSONAJE", CROWNS[index])
	var fall := create_tween()
	fall.tween_property(figure.root, "position", top, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	if not _running:
		return
	figure.model.set_state(false, false)
	_squash(figure)
	_camera.shake(0.4)
	active.podium.light_block(entry, 6.0, 0.3)
	SynthSound.play(self, SynthSound.thump(0.3), -9.0)
	_titles.name_card(figure.data.display_name, "PERSONAJE %d DE %d" % [index + 1, _figures.size()], figure.data.accent_color)
	if not await _wait(0.4):
		return
	_pose(figure, HERO_POSES[index])
	if not await _until(until):
		return
	_clear_words()


#Act two: La Plaza, race, slow-motion shove, El Plató, SocialDrop and map passes
func _act_maps() -> void:
	_show(AttractSets.PLAZA)
	_play(PLAZA_THEME, 0.0)
	_letterbox(BARS, 0.6)
	var middle := active.layout.position_of(TrendLayout.CORE)
	_gather(AttractSets.PLAZA, false)
	focus_changed.emit(_title_of(&"trend_war"), "LA PLAZA", ScoreSheet.Medal.NONE)
	_camera.zoom_to(58.0, 0.01)
	_shift(20.0)
	_camera.place(middle + Vector3(-30.0, 62.0, 78.0), middle)
	_camera.glide(middle + Vector3(6.0, 9.0, 17.0), middle + Vector3(0.0, 1.0, 0.0), 3.0 * PLAZA_BAR, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	if not await _until(PLAZA_BAR):
		return
	_say(["ATRAPA LA TENDENCIA ANTES", "DE QUE PASE DE MODA."])
	if not await _until(2.0 * PLAZA_BAR):
		return
	_pose(_figures[3], 5)
	_hop(_figures[1])
	if not await _until(3.0 * PLAZA_BAR):
		return
	_clear_words()
	await _race(6.0 * PLAZA_BAR)
	if not _running:
		return
	await _shove(middle, 9.0 * PLAZA_BAR)
	if not _running:
		return
	_dip(Palette.LILAC)
	await _plato(13.0 * PLAZA_BAR)
	if not _running:
		return
	_dip(Palette.LILAC)
	await _board(17.0 * PLAZA_BAR)
	if not _running:
		return
	var span := (PLAZA_END - 17.0 * PLAZA_BAR) / 3.0
	for index in 3:
		_flyover(PLACES[index + 1], span)
		if not await _until(17.0 * PLAZA_BAR + span * (index + 1)):
			return
	_flash_screen(0.8)


#Fast-motion race across La Plaza with the camera alongside
func _race(until: float) -> void:
	var path := AttractSets.plaza_run(active.layout)
	focus_changed.emit("A toda velocidad", "CÁMARA RÁPIDA", ScoreSheet.Medal.NONE)
	var start := path[0]
	var finish := path[-1]
	var across := Vector3(finish.z - start.z, 0.0, start.x - finish.x).normalized()
	var paces: Array[float] = [1.0, 1.06, 0.97, 1.03]
	for index in _figures.size():
		var lane: Array[Vector3] = []
		var phase := _rng.randf_range(0.0, TAU)
		for step in path.size():
			var weave := sin(step * 0.35 + phase) * 0.35
			lane.append(_on_ground(path[step] + across * ((index - 1.5) * 1.1 + weave)))
		_stand(_figures[index], lane[0], lane[1], 1.0)
		var hops: Array[float] = [_rng.randf_range(0.2, 0.4), _rng.randf_range(0.55, 0.8)]
		_run_along(_figures[index], lane, RUN_SPEED * paces[index], 0.05 * index, hops)
	_ramp(FAST_MOTION)
	_shift(6.5)
	_pack = _figures.duplicate()
	_pack_side = across
	_pack_ahead = (finish - start).normalized()
	_pack_center = start
	_say(["EL FEED NO SE ACABA.", "ESTA CARRERA, SÍ."])
	if not await _until(until - RAMP):
		return
	_ramp(1.0)
	if not await _until(until):
		return
	_pack.clear()
	_clear_words()


#Camera beside the middle of the runners at head height
func _follow_pack(delta: float) -> void:
	var center := Vector3.ZERO
	for figure in _pack:
		center += figure.root.position / _pack.size()
	_pack_center = _pack_center.lerp(center, 1.0 - exp(-5.0 * delta))
	_camera.place(_pack_center + _pack_side * 6.5 - _pack_ahead * 1.2 + Vector3(0.0, 1.5, 0.0), _pack_center + _pack_ahead * 1.5 + Vector3(0.0, 0.7, 0.0))


#Slow-motion shove: one flies back in a somersault, lands and staggers
func _shove(middle: Vector3, until: float) -> void:
	_hide_figures()
	var pusher := _figures[0]
	var target := _figures[1]
	var run_from := _on_ground(middle + Vector3(-3.2, 0.0, 0.0))
	var contact := _on_ground(middle + Vector3(-0.9, 0.0, 0.0))
	var victim := _on_ground(middle + Vector3(0.0, 0.0, 0.0))
	var landing := _on_ground(middle + Vector3(3.4, 0.0, 0.0))
	_stand(pusher, run_from, victim, 1.0)
	_stand(target, victim, run_from, 1.0)
	_stand(_figures[2], _on_ground(middle + Vector3(-1.0, 0.0, -3.0)), victim, 1.0)
	_stand(_figures[3], _on_ground(middle + Vector3(1.4, 0.0, -3.2)), victim, 1.0)
	focus_changed.emit("El empujón", "CÁMARA LENTA", ScoreSheet.Medal.NONE)
	_shift(4.6)
	_camera.place(middle + Vector3(-1.6, 0.55, 4.8), middle + Vector3(-0.6, 0.95, 0.0))
	_camera.glide(middle + Vector3(-0.4, 0.75, 4.2), middle + Vector3(0.0, 0.95, 0.0), PLAZA_BAR * 1.2)
	if not await _until(_now() + PLAZA_BAR * 0.45):
		return
	var steps: Array[Vector3] = [run_from, contact]
	_run_along(pusher, steps, RUN_SPEED * 1.1, 0.0, [])
	if not await _wait(run_from.distance_to(contact) / (RUN_SPEED * 1.1)):
		return
	pusher.model.play_move(CharacterModel.SHOVE)
	SynthSound.play(self, SynthSound.whoosh(0.4), -10.0)
	if not await _wait(0.16):
		return
	_ramp(SLOW_MOTION, 0.15)
	target.model.play_move(CharacterModel.STAGGER)
	SynthSound.play(self, SynthSound.thump(0.4), -6.0, 0.7)
	_camera.punch(9.0, 2.2)
	_camera.orbit(middle, 4.4, 0.9, 0.0, 38.0, 1.1, middle + Vector3(1.0, 1.0, 0.0))
	_say(["LAS PELEAS, AQUÍ.", "NO EN LOS COMENTARIOS."])
	var flight := create_tween()
	flight.tween_method(_somersault.bind(target, victim, landing), 0.0, 1.0, 0.8)
	flight.tween_callback(_landed.bind(target))
	if not await _wait_real(1.2):
		return
	_ramp(1.0, 0.5)
	pusher.model.stop_move()
	_pose(pusher, 0)
	if not await _until(until):
		return
	_clear_words()


#Arc thrown back with one turn around the waist
func _somersault(share: float, figure: Figure, from: Vector3, to: Vector3) -> void:
	figure.root.position = from.lerp(to, share) + Vector3(0.0, sin(share * PI) * 1.3, 0.0)
	var turn := Basis(Vector3.RIGHT, share * TAU)
	var waist := Vector3(0.0, 0.5, 0.0)
	figure.model.transform = Transform3D(turn, waist - turn * waist)


func _landed(figure: Figure) -> void:
	figure.model.transform = Transform3D.IDENTITY
	_squash(figure)
	figure.model.play_move(CharacterModel.STAGGER)
	SynthSound.play(self, SynthSound.land(0.16), -8.0)


#El Plató: one on the turntable, the others join and all pose on the beat
func _plato(until: float) -> void:
	_show(AttractSets.PLATO)
	_hide_figures()
	var hub := active.layout.position_of(SelfieLayout.HUB)
	hub.y = active.layout.height_at(hub.x, hub.z)
	var lens := hub + Vector3(0.0, 0.0, 8.0)
	_stand(_figures[2], hub, lens, 1.0)
	var spots: Array[Vector3] = [hub + Vector3(-1.5, 0.0, 0.6), hub + Vector3(1.5, 0.0, 0.6), hub + Vector3(0.0, 0.0, 1.6)]
	var runners: Array[int] = [0, 1, 3]
	for index in runners.size():
		var figure := _figures[runners[index]]
		var spot := _on_ground(spots[index])
		var from := _on_ground(spot + Vector3(-6.0 + index * 6.0, 0.0, -5.0 + index * 2.0))
		_stand(figure, from, spot, 1.0)
		var path: Array[Vector3] = [from, spot]
		_run_along(figure, path, RUN_SPEED, 0.15 + 0.2 * index, [], lens)
	focus_changed.emit(_title_of(&"perfect_selfie"), "EL PLATÓ", ScoreSheet.Medal.NONE)
	_camera.zoom_to(50.0, 0.01)
	_shift(8.0)
	_camera.orbit(hub, 8.5, 2.6, -28.0, 28.0, until - _now(), hub + Vector3(0.0, 1.0, 0.0))
	_say(["LA SELFIE PERFECTA", "SALE SIN FILTRO."])
	_pose(_figures[2], 3)
	if not await _until(_now() + 2.5 * PLAZA_BAR):
		return
	_flash_screen(0.7)
	SynthSound.play(self, SynthSound.chime(1568.0, 0.35), -12.0)
	_camera.punch(5.0, 0.6)
	for index in runners.size():
		_pose(_figures[runners[index]], [0, 4, 1][index])
	if not await _until(until):
		return
	_clear_words()


#SocialDrop board from above: every card but one falls
func _board(until: float) -> void:
	_show(AttractSets.DROP)
	_hide_figures()
	var board := active.board
	var target := DROP_CARD
	var deal_rng := RandomNumberGenerator.new()
	deal_rng.seed = 7
	board.restore()
	board.deal(deal_rng, target, 4, 4)
	board.show_icons(true)
	var spots := board.spawn_points()
	var middle := Vector3.ZERO
	for spot in spots:
		middle += spot / spots.size()
	_board_middle = middle
	_stand_on_card()
	focus_changed.emit(_title_of(&"social_drop"), "MEMORIA", ScoreSheet.Medal.NONE)
	_camera.zoom_to(56.0, 0.01)
	_shift(14.0)
	_camera.place(middle + Vector3(0.0, 34.0, 4.0), middle)
	_camera.glide(middle + Vector3(0.0, 10.5, 10.5), middle + Vector3(0.0, 0.5, 0.0), 2.0 * PLAZA_BAR, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_say(["NO TODAS LAS APPS", "TE SOSTIENEN."])
	if not await _until(_now() + 2.0 * PLAZA_BAR):
		return
	board.show_icons(false)
	board.warn(target, PLAZA_BAR * 0.9)
	if not await _until(_now() + PLAZA_BAR):
		return
	board.drop(target)
	board.celebrate()
	_camera.shake(0.3)
	for index in _figures.size():
		_hop(_figures[index], 0.08 * index)
	if not await _until(until):
		return
	_clear_words()


#The four on the card that never falls
func _stand_on_card() -> void:
	var board := active.board
	var spots := board.spawn_points()
	for index in _figures.size():
		var spot := board.cell_position(DROP_CARD, spots[index % spots.size()] * 3.0)
		_stand(_figures[index], spot + Vector3((index % 2) * 0.5 - 0.25, 0.0, 0.0), _board_middle + Vector3(0.0, 0.0, 8.0), 1.0)


#Pass over a whole map from high up
func _flyover(id: StringName, seconds: float) -> void:
	_show(id)
	_dip(Palette.LILAC)
	var center := _board_middle
	var radius := 11.0
	if active.layout != null:
		_gather(id, true)
		center = active.layout.position_of(TrendLayout.CORE if id == AttractSets.PLAZA else SelfieLayout.HUB)
		radius = 17.0
	elif active.board != null:
		#Fallen cards come back and the four stand on the one that held
		active.board.restore()
		_stand_on_card()
	var titles := {AttractSets.PLAZA: &"trend_war", AttractSets.PLATO: &"perfect_selfie", AttractSets.DROP: &"social_drop"}
	focus_changed.emit(_title_of(titles.get(id, &"")), "DESDE ARRIBA", ScoreSheet.Medal.NONE)
	_shift(radius * 1.2)
	var from := _rng.randf_range(-60.0, 60.0)
	_camera.zoom_to(55.0, 0.01)
	_camera.orbit(center, radius, radius * 0.7, from, from + 45.0, seconds, center + Vector3(0.0, 0.8, 0.0))


func _title_of(minigame: StringName) -> String:
	var info := MinigameCatalog.find(minigame)
	return info.title if info != null else ""


#The four gathered in the middle, each turned its own way; "posing" makes them pose
func _gather(id: StringName, posing: bool) -> void:
	if active.layout == null:
		return
	var middle := active.layout.position_of(TrendLayout.CORE if id == AttractSets.PLAZA else SelfieLayout.HUB)
	for index in _figures.size():
		var angle := index * TAU / _figures.size() + 0.4
		var at := _on_ground(middle + Vector3(cos(angle) * 1.7, 0.0, sin(angle) * 1.7))
		_stand(_figures[index], at, middle + Vector3(cos(angle) * 6.0 + 3.0, 0.0, sin(angle) * 6.0 + 5.0), 1.0)
		if posing:
			_pose_later(_figures[index], index + 1, 0.15 * index)


#Act three: dance under fireworks, last line, title and call to play
func _act_closing() -> void:
	_show(AttractSets.STAGE)
	_play(VICTORY, CLOSING_FROM)
	_letterbox(BARS_CLOSE, 0.6)
	_hide_figures()
	for index in _figures.size():
		var top := active.podium.top_of(AttractSets.entry_of(active, index))
		_stand(_figures[index], top, top + Vector3(0.0, 0.0, 6.0), STAGE_SCALE)
		_pose_later(_figures[index], DANCES[index], 0.12 * index)
	active.podium.confetti()
	active.podium.crowd.set_excitement(2.6)
	_fireworks = true
	focus_changed.emit("RumbleNet", "DEL FEED AL RING", ScoreSheet.Medal.NONE)
	_camera.zoom_to(56.0, 0.01)
	_shift(11.0)
	_camera.orbit(Vector3(0.0, 0.0, 1.0), 11.0, 3.6, -30.0, 25.0, 3.0 * VICTORY_BAR, Vector3(0.0, 2.2, 0.0))
	_say(["CUATRO JUGADORES.", "CERO NOTIFICACIONES."])
	if not await _until(CLOSING_FROM + 3.0 * VICTORY_BAR):
		return
	_clear_words()
	_flash_screen(0.7)
	_shift(13.0)
	_camera.place(Vector3(0.0, 8.0, 8.6), Vector3(0.0, 8.0, -5.9))
	_camera.glide(Vector3(0.0, 7.9, 7.0), Vector3(0.0, 7.9, -5.9), CLOSING_END - _now())
	_titles.title("DEL FEED AL RING", "¡ACÉRCATE Y JUEGA!", VICTORY_BAR, VICTORY_BAR / 4.0)
	if not await _until(_now() + VICTORY_BAR):
		return
	SynthSound.play(self, SynthSound.cheer(3.0), -10.0)
	if not await _until(CLOSING_END):
		return
	_fade(true, 1.3)
	if not await _wait(1.4):
		return
	_fireworks = false
	_clear_words()
	active.podium.crowd.set_excitement(1.0)


#Our own line set like a film title
func _say(lines: Array[String]) -> void:
	_titles.say(lines)


#Moves the subject to the middle of the free part of the screen
func _shift(distance: float) -> void:
	_camera.h_offset = FRAME_SHIFT * distance


func _clear_words() -> void:
	_titles.clear()


#Puts one place in the scene and takes the previous one out
func _show(id: StringName) -> void:
	var next: AttractSets.Place = places[id]
	if next == active:
		return
	if active != null:
		remove_child(active.root)
	active = next
	add_child(active.root)
	move_child(active.root, 0)


func _hide_figures() -> void:
	for figure in _figures:
		figure.root.visible = false
		figure.model.stop_move()
		figure.model.transform = Transform3D.IDENTITY


func _stand(figure: Figure, at: Vector3, facing: Vector3, size: float) -> void:
	figure.root.visible = true
	figure.root.scale = Vector3.ONE * size
	figure.root.position = at
	figure.root.rotation.y = atan2(facing.x - at.x, facing.z - at.z)
	figure.model.stop_move()
	figure.model.transform = Transform3D.IDENTITY
	figure.model.set_state(false, false)


func _pose(figure: Figure, index: int) -> void:
	figure.model.play_move(CharacterModel.POSES[index % CharacterModel.POSES.size()], true, 0.25)


func _pose_later(figure: Figure, index: int, delay: float) -> void:
	var later := create_tween()
	later.tween_interval(delay)
	later.tween_callback(_pose.bind(figure, index))


#Landing squash
func _squash(figure: Figure) -> void:
	var size := figure.root.scale.y
	figure.root.scale = Vector3(1.14, 0.84, 1.14) * size
	create_tween().tween_property(figure.root, "scale", Vector3.ONE * size, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


#Hop on the spot with a landing bounce
func _hop(figure: Figure, delay := 0.0) -> void:
	var base := figure.root.position
	var jump := create_tween()
	jump.tween_interval(delay)
	jump.tween_callback(figure.model.stop_move)
	jump.tween_callback(figure.model.set_state.bind(false, true))
	jump.tween_property(figure.root, "position", base + Vector3(0.0, HOP_HEIGHT, 0.0), HOP_SECONDS / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump.tween_property(figure.root, "position", base, HOP_SECONDS / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	jump.tween_callback(figure.model.set_state.bind(false, false))
	jump.tween_callback(_squash.bind(figure))


#Runs a figure along the points, turning and hopping at "hops"; ends facing "facing"
func _run_along(figure: Figure, path: Array[Vector3], speed: float, delay: float, hops: Array[float], facing := Vector3.INF) -> void:
	var length := 0.0
	for step in path.size() - 1:
		length += path[step].distance_to(path[step + 1])
	var seconds := maxf(length / speed, 0.05)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(figure.model.set_state.bind(true, false))
	tween.tween_method(_step_runner.bind(figure, path, hops, seconds), 0.0, 1.0, seconds)
	tween.tween_callback(figure.model.set_state.bind(false, false))
	if facing != Vector3.INF:
		tween.tween_method(func(share: float) -> void:
			var aim := atan2(facing.x - figure.root.position.x, facing.z - figure.root.position.z)
			figure.root.rotation.y = lerp_angle(figure.root.rotation.y, aim, share), 0.0, 1.0, 0.3)


func _step_runner(share: float, figure: Figure, path: Array[Vector3], hops: Array[float], seconds: float) -> void:
	var spot := share * (path.size() - 1)
	var index := mini(floori(spot), path.size() - 2)
	var at := path[index].lerp(path[index + 1], spot - index)
	var lift := 0.0
	for hop in hops:
		var into := (share - hop) * seconds / HOP_SECONDS
		if into >= 0.0 and into <= 1.0:
			lift = sin(into * PI) * HOP_HEIGHT
	figure.root.position = at + Vector3(0.0, lift, 0.0)
	var ahead := path[index + 1] - path[index]
	if ahead.length() > 0.01:
		figure.root.rotation.y = lerp_angle(figure.root.rotation.y, atan2(ahead.x, ahead.z), 0.2)
	figure.model.set_state(true, lift > 0.0)


func _on_ground(at: Vector3) -> Vector3:
	if active.layout != null:
		return Vector3(at.x, active.layout.height_at(at.x, at.z), at.z)
	return at


#Ramps time to "amount" in "seconds" of real time
func _ramp(amount: float, seconds := RAMP) -> void:
	var tween := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(Engine, "time_scale", amount, seconds)


#Starts a track at "from" and fades out the previous one
func _play(stream: AudioStream, from: float) -> void:
	var next := _players[0] if _track != _players[0] else _players[1]
	if _track != null:
		var out := create_tween()
		out.tween_property(_track, "volume_db", -40.0, 0.5)
		out.tween_callback(_track.stop)
	next.stream = stream
	next.volume_db = -30.0
	next.play(from)
	create_tween().tween_property(next, "volume_db", MUSIC_DB, 0.25)
	_track = next
	_track_from = from
	_track_at = Time.get_ticks_msec()


#Seconds into the track by the real clock
func _now() -> float:
	return _track_from + (Time.get_ticks_msec() - _track_at) / 1000.0


#Waits until the track reaches "seconds"; false if stopped
func _until(seconds: float) -> bool:
	while _running and is_inside_tree() and _now() < seconds:
		await get_tree().process_frame
	return _running


#Waits in game time
func _wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	return _running


func _wait_real(seconds: float) -> bool:
	await get_tree().create_timer(seconds, true, false, true).timeout
	return _running


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_layer = layer
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Palette.NIGHT
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		layer.add_child(bar)
		_bars.append(bar)
	#Words go under the beat flashes and fades
	layer.add_child(_titles)
	for shade: ColorRect in [_flash, _veil]:
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(shade)
	_flash.color = Color(Palette.PAPER, 0.0)
	_veil.color = Color(Palette.NIGHT, 1.0)


#Cinema bars to "share" of the height
func _letterbox(share: float, seconds: float) -> void:
	var height := get_viewport().get_visible_rect().size.y * share
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bars[0], "offset_bottom", height, seconds)
	tween.tween_property(_bars[1], "offset_top", -height, seconds)


func _flash_screen(strength: float) -> void:
	_flash.color = Color(Palette.PAPER, strength)
	create_tween().set_ignore_time_scale(true).tween_property(_flash, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	SynthSound.play(self, SynthSound.whoosh(0.35), -16.0)


#Quick dip through a game colour between places
func _dip(colour: Color) -> void:
	_flash.color = Color(colour, 0.85)
	create_tween().set_ignore_time_scale(true).tween_property(_flash, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _fade(to_night: bool, seconds: float) -> void:
	create_tween().tween_property(_veil, "color:a", 1.0 if to_night else 0.0, seconds)
