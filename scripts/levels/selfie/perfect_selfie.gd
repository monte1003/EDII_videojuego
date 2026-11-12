class_name PerfectSelfie
extends ArenaRound

#"La Selfie Perfecta": a drone takes eight photos, one on each island of the studio. Whoever is inside the frame at the shot gets
#followers: more in the centre, more while posing (still and easy to shove) and more the fewer are in the photo

const MINIGAME_ID := &"perfect_selfie"
const SHELL: Shader = preload("res://assets/shaders/bubble.gdshader")
const BOOST_COLORS: Array[Color] = [Color("4fd38a"), Color("ffc928")]
#The arrow hides when the photo is closer than this, or when the camera looks at it within this cosine
const GUIDE_NEAR := 4.0
const GUIDE_VIEW := 0.8

@export var settings: SelfieSettings

var rules: SelfieRules

var _studio: SelfieLayout
var _selfie_hud: SelfieHud
var _drone: SelfieDrone
var _powers: SelfiePowers
var _base_speed := 5.0
var _base_jump := 4.5
#Per player: the shield bubble, the ring of a boost and the sparkles of a pose
var _shields: Dictionary = {}
var _rings: Dictionary = {}
var _glitter: Dictionary = {}
var _blinks := 0
#Per player: the arrow on the floor that points to the photo while its camera looks somewhere else
var _guides: Dictionary = {}


func _ready() -> void:
	super()
	if ScreenFlow.tree.has(MINIGAME_ID):
		ScreenFlow.mark_current(MINIGAME_ID)
	_selfie_hud = hud as SelfieHud
	_studio = SelfieLayout.new()
	setup_arena(_studio, 38.0, SelfieLayout.TOP_HEIGHT)
	var ids: Array[int] = []
	for id: int in players:
		ids.append(id)
		_dress_player(players[id])
	_base_speed = local_player().move_speed
	_base_jump = local_player().jump_velocity
	rules = SelfieRules.new(settings, GameSession.score_sheet, _studio, ids, rng.randi())
	rules.photo_announced.connect(_on_photo_announced)
	rules.frame_locked.connect(_on_frame_locked)
	rules.photo_taken.connect(_on_photo_taken)
	rules.pose_changed.connect(_on_pose_changed)
	rules.power_taken.connect(_on_power_taken)
	rules.power_returned.connect(_on_power_returned)
	rules.finished.connect(_on_finished)
	_drone = SelfieDrone.new()
	world.add_child(_drone)
	_drone.build(_studio.position_of(SelfieLayout.HUB) + Vector3(0.0, SelfieLayout.DRONE_HEIGHT, 0.0), settings.center_share)
	_powers = SelfiePowers.new()
	world.add_child(_powers)
	_powers.build(_studio.pedestals, rules.pedestal_kinds)
	keys.interact_pressed.connect(request_pose.bind(local_id, true))
	keys.interact_released.connect(request_pose.bind(local_id, false))
	_help.setup(HelpPages.perfect_selfie(settings, GameSession.score_sheet))
	_selfie_hud.set_photo(1, rules.photo_count())
	hud.show_mission("Entra al marco antes del disparo", [
		"%s|mover" % InputHints.move_label(), "%s|posar" % InputHints.key_label(&"interact"), "%s|empujar" % InputHints.key_label(&"shove")], 4.5)


#A player starts or stops its pose; the rules decide whether it can
func request_pose(player_id: int, on: bool) -> void:
	if phase == Phase.RUNNING and players.has(player_id) and not (players[player_id] as Player).is_down():
		rules.set_posing(player_id, on)


func _on_round_started() -> void:
	rules.start()


func _tick_round(delta: float) -> void:
	for id: int in players:
		var player: Player = players[id]
		rules.place(id, player.global_position, player.is_on_floor(), is_falling(id))
	rules.extras.clear()
	for bot in bots:
		rules.extras.append(bot.global_position)
	rules.tick(delta)
	if phase == Phase.ENDED:
		return
	if rules.frame_visible():
		_drone.show_frame(rules.frame_center(), rules.frame_size(), rules.lock_share())
		_tick_blinks()
	for id: int in players:
		var player: Player = players[id]
		player.move_speed = _base_speed * rules.speed_scale(id)
		player.jump_velocity = _base_jump * rules.jump_scale(id)
		_refresh_marks(id)
		_refresh_guide(id, player)
		if is_falling(id) or player.is_down():
			continue
		for index in _studio.pedestals.size():
			if rules.pedestal_kinds[index] >= 0 and player.global_position.distance_to(_studio.pedestals[index] + Vector3(0.0, 0.6, 0.0)) <= settings.power_radius:
				rules.take_power(id, index)


func _can_shove(player_id: int) -> bool:
	return not rules.is_posing(player_id)


func _shove_scale(victim_id: int) -> float:
	return settings.pose_shove_scale if rules.is_posing(victim_id) else 1.0


func _on_struck(player_id: int, _by_rival: bool, _push: Vector3) -> void:
	rules.strike(player_id)


func _on_bot_added(bot: ChaserBot) -> void:
	bot.role = PhotobombRole.new()


#The drone leaves for the next photo over the islands; its beam tells where from afar
func _on_photo_announced(index: int, spot: StringName) -> void:
	set_stage(index)
	context.goal = spot
	for missing in maxi(settings.bombers[mini(index, settings.bombers.size() - 1)] - bots.size(), 0):
		add_bot()
	_drone.hide_frame()
	_drone.fly(_studio.flight_path(_studio.nearest_island(_drone.global_position), spot), settings.travel_seconds * 0.9)
	_selfie_hud.set_photo(index + 1, rules.photo_count())
	SynthSound.play(self, SynthSound.tone(392.0, 0.3, 300.0, 0.35), -11.0)


func _on_frame_locked(_index: int, _seconds: float) -> void:
	_blinks = 0


#Three ticks, each one higher, while the fixed frame blinks
func _tick_blinks() -> void:
	if rules.phase != SelfieRules.Phase.LOCK:
		return
	var due := floori(rules.lock_share() * 3.0)
	if due >= _blinks and _blinks < 3:
		_blinks += 1
		SynthSound.play(self, SynthSound.tone(880.0, 0.08, 0.0, 0.4), -9.0, 1.0 + 0.2 * _blinks)


#The shot: shutter, a white flash, a breath of freeze, and the followers float over every head that came out
func _on_photo_taken(_index: int, shots: Dictionary) -> void:
	_drone.snap()
	SynthSound.play(self, SynthSound.thump(0.12), -5.0, 1.9)
	SynthSound.play(self, SynthSound.tone(1760.0, 0.1, -900.0, 0.4), -8.0)
	hud.flash(Color.WHITE, 0.9, 0.5)
	ImpactFx.hit_stop(get_tree(), 0.12)
	cheer(2.6)
	var faces: Array[Texture2D] = []
	var crowd := 0
	for id: int in shots:
		var shot: SelfieRules.Shot = shots[id]
		crowd = shot.crowd
		if not shot.inside:
			continue
		var player: Player = players[id]
		pop_text(player.global_position + Vector3(0.0, 1.7, 0.0), "+%d" % shot.followers, Palette.GOLD if shot.posing else Palette.PAPER)
		player.squash(4.0)
		for slot in participants:
			if slot.player_id == id and slot.character != null and slot.character.icon != null:
				faces.append(slot.character.icon)
	var mine: SelfieRules.Shot = shots[local_id]
	_selfie_hud.set_followers(rules.state_of(local_id).followers, mine.followers)
	var caption := "FUERA"
	if mine.inside:
		caption = "PERFECTA" if mine.centered and mine.posing else ("POSE" if mine.posing else ("CENTRO" if mine.centered else "SALISTE"))
	_selfie_hud.show_print(faces, maxi(crowd - faces.size(), 0), caption, settings.reveal_seconds)
	get_tree().create_timer(settings.reveal_seconds * 0.7).timeout.connect(_drone.hide_frame)


func _on_pose_changed(player_id: int, posing: bool) -> void:
	var player: Player = players[player_id]
	player.posing = posing
	(_glitter[player_id] as CPUParticles3D).emitting = posing
	if posing:
		player.squash(3.0)
		if player_id == local_id:
			SynthSound.play(self, SynthSound.tone(988.0, 0.18, 200.0, 0.35), -11.0)


func _on_power_taken(player_id: int, pedestal: int, kind: int, seconds: float) -> void:
	_powers.set_kind(pedestal, -1)
	var player: Player = players[player_id]
	if kind == SelfieRules.Power.SHIELD:
		brawl.give_shield(player_id, seconds)
	player.squash(5.0)
	ImpactFx.stars(self, player.global_position + Vector3(0.0, 1.0, 0.0), 6)
	SynthSound.play(self, SynthSound.tone(523.0, 0.3, 520.0, 0.4), -8.0, 1.0 + 0.15 * kind)


func _on_power_returned(pedestal: int, kind: int) -> void:
	_powers.set_kind(pedestal, kind)


func _on_finished() -> void:
	var state := rules.state_of(local_id)
	var count := rules.photo_count()
	var won := state.photos >= settings.win_photos
	var sheet := GameSession.score_sheet
	var lines: Array[Array] = [["Fotos", "%d de %d" % [state.photos, count]], ["Poses", str(state.poses)], ["Seguidores", str(state.followers)]]
	var score := RoundScore.make(sheet, rules.points_of(local_id), "Saliste en %d de %d fotos" % [state.photos, count], lines)
	var message := "Saliste bien sin vivir para la foto: posar es un rato, no todo el día." if won \
		else "No hay que salir en todas las fotos: llega con calma y elige cuándo posar."
	var result := RoundResult.make(MINIGAME_ID, won, "Foto perfecta" if won else "Fuera de cuadro", message, lines).with_score(score, rules.totals())
	_drone.hide_frame()
	end_round(result, "¡QUÉ FOTO!" if won else "FUERA DE CUADRO", "%d seguidores" % state.followers, won)


#What shows on a player: a bubble while the shield lasts, a ring under the feet while a boost does, and sparkles while it poses
func _dress_player(player: Player) -> void:
	var ball := SphereMesh.new()
	ball.radius = 0.78
	ball.height = 1.56
	ball.radial_segments = 20
	ball.rings = 10
	var shell := ShaderMaterial.new()
	shell.shader = SHELL
	shell.set_shader_parameter("tint", SelfiePowers.COLORS[SelfieRules.Power.SHIELD])
	shell.set_shader_parameter("glow", 1.6)
	var shield := MeshInstance3D.new()
	shield.mesh = ball
	shield.material_override = shell
	shield.position.y = 0.55
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.hide()
	player.add_child(shield)
	_shields[player.player_id] = shield
	var band := TorusMesh.new()
	band.outer_radius = 0.62
	band.inner_radius = 0.5
	band.rings = 24
	band.ring_segments = 6
	var ring := MeshInstance3D.new()
	ring.mesh = band
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.hide()
	player.add_child(ring)
	_rings[player.player_id] = ring
	var glitter := PartyKit.sparkles(Vector3(0.7, 0.9, 0.7), 14)
	glitter.position.y = 0.8
	glitter.emitting = false
	player.add_child(glitter)
	_glitter[player.player_id] = glitter
	_guides[player.player_id] = _make_guide()


#A flat gold arrow that lies on the floor and points along +Z
func _make_guide() -> Node3D:
	var guide := Node3D.new()
	guide.hide()
	add_child(guide)
	var gold := PartyKit.paint(Palette.GOLD, 1.6, 0.4)
	var head := PrismMesh.new()
	head.size = Vector3(0.9, 0.7, 0.1)
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.36, 0.1, 0.7)
	for part: Array in [[head, Vector3(0.0, 0.0, 0.35), true], [shaft, Vector3(0.0, 0.0, -0.3), false]]:
		var piece := MeshInstance3D.new()
		piece.mesh = part[0]
		piece.material_override = gold
		piece.position = part[1]
		if part[2]:
			piece.rotation.x = PI / 2.0
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		guide.add_child(piece)
	return guide


#The arrow of a player: it shows only while there is a photo to go to, the player is still far from it and its camera is not
#already looking that way. Each player has its own, and this screen only draws the one of its player
func _refresh_guide(player_id: int, player: Player) -> void:
	var guide: Node3D = _guides[player_id]
	var heading := rules.phase == SelfieRules.Phase.TRAVEL or rules.frame_visible()
	if player_id != local_id or not heading or is_falling(player_id):
		guide.hide()
		return
	var target := rules.frame_center() if rules.frame_visible() else _studio.position_of(rules.spot())
	var to := target - player.global_position
	to.y = 0.0
	var view := -player.view_camera().global_basis.z
	view.y = 0.0
	var looking := view.length() > 0.01 and to.length() > 0.01 and view.normalized().dot(to.normalized()) > GUIDE_VIEW
	guide.visible = to.length() > GUIDE_NEAR and not looking
	if not guide.visible:
		return
	var way := to.normalized()
	guide.global_position = player.global_position + way * (1.5 + 0.25 * sin(clock * 6.0)) + Vector3(0.0, 0.3, 0.0)
	guide.rotation.y = atan2(way.x, way.z)


func _refresh_marks(player_id: int) -> void:
	(_shields[player_id] as MeshInstance3D).visible = brawl.has_shield(player_id)
	var state := rules.state_of(player_id)
	var ring: MeshInstance3D = _rings[player_id]
	ring.visible = state.jump_left > 0.0 or state.speed_left > 0.0
	if ring.visible:
		ring.material_override = PartyKit.paint(BOOST_COLORS[1 if state.speed_left > 0.0 else 0], 2.0, 0.4)
		ring.scale = Vector3.ONE * (1.0 + 0.12 * sin(clock * 9.0))
