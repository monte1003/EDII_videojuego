class_name PerfectSelfie
extends ArenaRound

#"La Selfie Perfecta": a drone takes eight photos; whoever is in the frame at the shot gets followers

const MINIGAME_ID := &"perfect_selfie"
const SHELL: Shader = preload("res://assets/shaders/bubble.gdshader")
const BOOST_COLORS: Array[Color] = [Color("4fd38a"), Color("ffc928")]
#The arrow hides near the photo or when the camera already looks at it
const GUIDE_NEAR := 4.0
const GUIDE_VIEW := 0.8
#Badge height over the set and colour of the in-frame ring
const MARKER_LIFT := 3.0
const INSIDE_COLOR := Color("4fd38a")

@export var settings: SelfieSettings

var rules: SelfieRules

var _studio: SelfieLayout
var _selfie_hud: SelfieHud
var _drone: SelfieDrone
var _powers: SelfiePowers
var _camera: SelfieCamera
var _floor: SelfieFloor
var _base_speed := 5.0
var _base_jump := 4.5
var _base_decay := 18.0
#Per player: shield bubble, boost ring and pose sparkles
var _shields: Dictionary = {}
var _rings: Dictionary = {}
var _glitter: Dictionary = {}
var _blinks := 0
#The first photo teaches the shove once
var _shove_taught := false
#Per player: floor arrow to the photo, ring under the feet and arrow over the head
var _guides: Dictionary = {}
var _spots: Dictionary = {}
var _pointers: Dictionary = {}
var _spot_paints: Array[StandardMaterial3D] = []
#Photos of the round, what each gave this player (-1 if out) and shots waiting to develop
var _photos: Array[Texture2D] = []
var _numbers: Array[int] = []
var _waiting: Dictionary = {}
#Per player: move keys held at pose start, air press timer and air time
var _pose_held: Dictionary = {}
var _pose_wanted: Dictionary = {}
var _air: Dictionary = {}


func _ready() -> void:
	super()
	if ScreenFlow.tree.has(MINIGAME_ID):
		ScreenFlow.mark_current(MINIGAME_ID)
	_selfie_hud = hud as SelfieHud
	_studio = SelfieLayout.new()
	bot_places = _studio.bot_places()
	hazard_push = settings.hazard_push
	hazard_stun = settings.hazard_stun
	roller_push = settings.roller_push
	roller_stun = settings.roller_stun
	setup_arena(_studio)
	_floor = SelfieFloor.new(_studio)
	var ids: Array[int] = []
	_spot_paints = [_glow_paint(Palette.PAPER), _glow_paint(INSIDE_COLOR)]
	for id: int in players:
		ids.append(id)
		_dress_player(players[id])
		var view := (players[id] as Player).view_camera()
		view.cull_mask &= ~SelfieCamera.layer_bit(SelfieCamera.MONITOR_LAYER)
	_base_speed = local_player().move_speed
	_base_jump = local_player().jump_velocity
	_base_decay = local_player().push_decay
	rules = SelfieRules.new(settings, GameSession.score_sheet, _studio, ids, rng.randi())
	rules.jump_height = SelfieRules.jump_height_of(local_player().jump_velocity)
	rules.photo_announced.connect(_on_photo_announced)
	rules.frame_locked.connect(_on_frame_locked)
	rules.photo_taken.connect(_on_photo_taken)
	rules.pose_changed.connect(_on_pose_changed)
	rules.power_taken.connect(_on_power_taken)
	rules.power_returned.connect(_on_power_returned)
	rules.finished.connect(_on_finished)
	_camera = SelfieCamera.new()
	add_child(_camera)
	_camera.developed.connect(_on_developed)
	_selfie_hud.monitor.show_feed(_camera.preview_texture())
	_drone = SelfieDrone.new()
	world.add_child(_drone)
	_drone.build(_studio.position_of(SelfieLayout.HUB) + Vector3(0.0, SelfieLayout.DRONE_HEIGHT, 0.0), settings.center_share)
	_powers = SelfiePowers.new()
	world.add_child(_powers)
	_powers.build(_studio.pedestals, rules.pedestal_kinds)
	_help.setup(SelfieHelp.pages(settings, GameSession.score_sheet))
	_spawn_trolls()
	_selfie_hud.set_photo(1, rules.photo_count())
	hud.show_mission("Entra al marco", [
		"move=%s|mover" % InputHints.move_label(), "interact=%s|posar" % InputHints.key_label(&"interact"), "shove=%s|empujar" % InputHints.key_label(&"shove")], 4.5)


#The studio brings its own sky, light and audience
func _make_set() -> ArenaStage:
	return null


func cheer(power: float) -> void:
	(world as SelfieStage).cheer(power)


#The rules decide whether a pose can start
func request_pose(player_id: int, on: bool) -> void:
	if phase != Phase.RUNNING or not players.has(player_id):
		return
	var player: Player = players[player_id]
	if on and (player.is_down() or player.is_diving()):
		return
	_pose_wanted.erase(player_id)
	if not rules.set_posing(player_id, on) and on and not player.is_on_floor():
		#Pressed in the air: the pose waits for the landing
		_pose_wanted[player_id] = PoseKeeper.PRESS_BUFFER


#The rules keep the photo pose, so the key and the dock go to them
func add_poser(player: Player, local: bool) -> void:
	everyone[player.player_id] = player
	if local:
		_pose_local = player.player_id
		_pose_player = player


func press_pose() -> void:
	toggle_pose(local_id)


func pose_state() -> int:
	if rules == null or not _pose_shown():
		return PoseDock.State.HIDDEN
	if rules.is_posing(local_id):
		return PoseDock.State.POSING
	var player := local_player()
	var free := PoseKeeper.is_free(player, float(_air.get(local_id, 0.0))) and not is_falling(local_id)
	return PoseDock.State.READY if free and rules.phase != SelfieRules.Phase.WAITING else PoseDock.State.BLOCKED


#Shove chip over the rival in reach or near the player; hidden when it cannot act
func _tick_chips() -> void:
	var player := local_player()
	var camera := player.view_camera()
	var acting := phase == Phase.RUNNING and not is_falling(local_id) and not player.is_down()
	var head := player.global_position + Vector3(0.0, 1.9, 0.0)
	var visible_head := acting and not camera.is_position_behind(head)
	var here := camera.unproject_position(head) if visible_head else Vector2.ZERO
	var in_frame := rules.frame_visible() and (rules.is_inside(player.global_position) \
		or Vector2(player.global_position.x - rules.frame_center().x, player.global_position.z - rules.frame_center().z).length() < rules.frame_size() * 0.5 + 4.0)
	var target := shove_target(local_id)
	var reach := target != NOBODY
	var crowded := in_frame and _rival_in_frame()
	var teaching := not _shove_taught and rules.frame_visible() and rules.photo_index == 0 and in_frame
	var anchor := here + Vector2(-96.0, -6.0)
	if reach:
		var over := shove_target_position(target)
		if not camera.is_position_behind(over):
			anchor = camera.unproject_position(over) + Vector2(0.0, -34.0)
	var charge := 1.0 - brawl.rest_left(local_id) / brawl.shove_rest
	var show_shove := visible_head and (reach or crowded or teaching)
	if show_shove and teaching and not _shove_taught:
		_shove_taught = true
		_selfie_hud.shove_chip.teach("saca a otros")
	_selfie_hud.set_shove_chip(show_shove, charge, anchor)


#Whether a player or bot is in the frame
func _rival_in_frame() -> bool:
	for id: int in players:
		if id != local_id and rules.is_inside((players[id] as Player).global_position):
			return true
	for bot in bots:
		if rules.is_inside(bot.global_position):
			return true
	return false


func toggle_pose(player_id: int) -> void:
	request_pose(player_id, not rules.is_posing(player_id))


#Shoving drops the pose first
func request_shove(player_id: int) -> bool:
	if rules != null and rules.is_posing(player_id):
		rules.set_posing(player_id, false)
	var thrown := super(player_id)
	if thrown and player_id == local_id:
		_selfie_hud.press_shove()
	return thrown


func _on_round_started() -> void:
	rules.start()


func _tick_round(delta: float) -> void:
	_floor.clock = clock
	for id: int in players:
		var player: Player = players[id]
		if player.remote:
			#A remote player's position, flight and pose come from its computer
			rules.place(id, player.global_position, not player.remote_airborne(), false)
			rules.set_remote_pose(id, player.posing)
			continue
		_air[id] = 0.0 if player.is_on_floor() else float(_air.get(id, 0.0)) + delta
		#A new move press or jump drops the pose; keys held since its start do not
		if rules.is_posing(id) and (PoseKeeper.moves(_pose_held, id, player.move_input, settings.pose_break_input) or player.jump_requested):
			rules.set_posing(id, false)
		if _pose_wanted.has(id):
			_pose_wanted[id] = float(_pose_wanted[id]) - delta
			if player.is_on_floor():
				request_pose(id, true)
			if float(_pose_wanted.get(id, 0.0)) <= 0.0:
				_pose_wanted.erase(id)
		_apply_floor(id, player, delta)
		#A one-frame bump does not count as leaving the floor
		rules.place(id, player.global_position, float(_air[id]) < PoseKeeper.AIR_GRACE, is_falling(id))
	rules.extras.clear()
	#Bots move on their own on each computer, so in a room they do not count in the photo
	if not _networked_round():
		for bot in bots:
			rules.extras.append(bot.global_position)
	rules.tick(delta)
	if phase == Phase.ENDED:
		return
	_tick_trolls()
	if rules.frame_visible():
		_drone.show_frame(rules.frame_center(), rules.frame_size(), rules.lock_share())
		_tick_blinks()
	if _camera.is_live():
		_aim_camera()
	_tick_chips()
	_tick_marker()
	for id: int in players:
		var player: Player = players[id]
		_refresh_marks(id)
		_refresh_guide(id, player)
		_refresh_spot(id, player)
		if is_falling(id) or player.is_down():
			continue
		for index in _studio.pedestals.size():
			if rules.pedestal_kinds[index] >= 0 and player.global_position.distance_to(_studio.pedestals[index] + Vector3(0.0, 0.6, 0.0)) <= settings.power_radius:
				rules.take_power(id, index)


#Floor effect this step plus power-up scales
func _apply_floor(player_id: int, player: Player, delta: float) -> void:
	var grounded := player.is_on_floor() and not is_falling(player_id)
	var effect := _floor.step(player_id, player.global_position, grounded, _wanted_run(player), player.velocity.y, delta)
	player.external_velocity += effect.drift
	player.push_decay = effect.push_decay if effect.push_decay > 0.0 else _base_decay
	player.move_speed = _base_speed * rules.speed_scale(player_id) * effect.speed_scale
	player.jump_velocity = _base_jump * rules.jump_scale(player_id) * effect.jump_scale
	if effect.bounce > 0.0:
		player.apply_push(Vector3(player.push_velocity.x, effect.bounce, player.push_velocity.z))
		player.squash(3.0)
	if effect.throw != Vector3.ZERO:
		player.apply_push(effect.throw)
		player.squash(5.0)
		SynthSound.play(self, SynthSound.tone(180.0, 0.3, 520.0, 0.5), -8.0, rng.randf_range(0.9, 1.1))


#Ground speed the keys ask; none while it cannot run
func _wanted_run(player: Player) -> Vector3:
	if player.posing or player.is_dazed() or player.is_down() or player.is_diving():
		return Vector3.ZERO
	var rig := player.get_node("CameraRig") as PlayerCamera
	return rig.get_yaw_basis() * Vector3(player.move_input.x, 0.0, player.move_input.y) * player.move_speed


#The live picture aims at the frame, or the set before it lands
func _aim_camera() -> void:
	var spot := rules.spot()
	if rules.frame_visible():
		_camera.aim(rules.frame_center(), rules.frame_size(), _studio.camera_turn(spot), _studio.camera_clip(spot))
	else:
		_camera.aim(_studio.position_of(spot), rules.final_size(rules.photo_index), _studio.camera_turn(spot), _studio.camera_clip(spot))


func _on_respawned(player_id: int) -> void:
	_floor.forget(player_id)


func _shove_scale(victim_id: int) -> float:
	return settings.pose_shove_scale if rules.is_posing(victim_id) else 1.0


func _on_struck(player_id: int, _by_rival: bool, _push: Vector3) -> void:
	rules.strike(player_id)


#Troll zone bots, more with more players, never leaving it
func _spawn_trolls() -> void:
	if not bots_enabled or bot_looks.is_empty():
		return
	var count: int = settings.trolls[clampi(players.size() - 1, 0, settings.trolls.size() - 1)]
	var zone := SelfieLayout.TROLL.grow(-SelfieLayout.CURB_THICKNESS)
	for index in count:
		var bot := ZoneBot.make()
		_actors.add_child(bot)
		bot.setup(context, bot_looks[index % bot_looks.size()], &"Z")
		bot.bounds = zone
		bot.move_speed = local_player().move_speed * settings.troll_speed
		bot.push_windup = bot_windup
		bot.push_cooldown = bot_cooldown
		bot.push_landed.connect(_on_bot_push)
		bot.push_announced.connect(_on_bot_warning)
		var share := (index + 0.5) / count
		bot.place(Vector3(lerpf(zone.position.x + 1.0, zone.end.x - 1.0, share), 0.2, zone.get_center().y + (1.5 if index % 2 == 0 else -1.5)), rng.randi())
		bots.append(bot)


#During a troll zone photo the trolls run into the frame
func _tick_trolls() -> void:
	var here := rules.frame_visible() and rules.spot() == &"Z"
	for index in bots.size():
		var bot := bots[index] as ZoneBot
		if bot == null:
			continue
		if here:
			var spread := Vector3(cos(index * 2.4), 0.0, sin(index * 2.4)) * rules.frame_size() * 0.25
			bot.frame_point = rules.frame_center() + spread
		else:
			bot.frame_point = Vector3.ZERO


#The drone leaves for the next set; its beam marks where
func _on_photo_announced(index: int, spot: StringName) -> void:
	set_stage(index)
	context.goal = spot
	_drone.hide_frame()
	_selfie_hud.announce_camera(SelfieStage.SET_NAMES.get(spot, ""))
	_drone.fly(_studio.flight_path(_studio.nearest_place(_drone.global_position - Vector3(0.0, SelfieLayout.DRONE_HEIGHT, 0.0)), spot), settings.travel_seconds * 0.9)
	_selfie_hud.set_photo(index + 1, rules.photo_count())
	_camera.set_live(true)
	_aim_camera()
	_selfie_hud.monitor.set_live(true)
	SynthSound.play(self, SynthSound.tone(392.0, 0.3, 300.0, 0.35), -11.0)


func _on_frame_locked(_index: int, _seconds: float) -> void:
	_blinks = 0


#Three rising ticks while the frame blinks
func _tick_blinks() -> void:
	if rules.phase != SelfieRules.Phase.LOCK:
		return
	var due := floori(rules.lock_share() * 3.0)
	if due >= _blinks and _blinks < 3:
		_blinks += 1
		SynthSound.play(self, SynthSound.tone(880.0, 0.08, 0.0, 0.4), -9.0, 1.0 + 0.2 * _blinks)


#Shot: shutter, white blink and a brief freeze; the photo is drawn once
func _on_photo_taken(index: int, shots: Dictionary) -> void:
	_camera.set_live(false)
	_waiting[index] = shots
	var spot := rules.spot()
	_camera.take(index, SelfieCamera.compose(rules.frame_center(), rules.photo_feet, _studio.camera_turn(spot), rules.final_size(index)), _studio.camera_clip(spot))
	_drone.snap()
	SynthSound.play(self, SynthSound.thump(0.12), -5.0, 1.9)
	SynthSound.play(self, SynthSound.tone(1760.0, 0.1, -900.0, 0.4), -8.0)
	hud.flash(Color.WHITE, 0.7, 0.1)
	_selfie_hud.monitor.flash()
	ImpactFx.hit_stop(get_tree(), 0.12)
	cheer(2.6)
	var mine: SelfieRules.Shot = shots[local_id]
	_selfie_hud.set_followers(rules.state_of(local_id).followers, mine.followers)
	get_tree().create_timer(settings.reveal_seconds * 0.7).timeout.connect(_drone.hide_frame)


#Photo out: shown, added to the roll, numbers over the heads
func _on_developed(index: int, photo: Texture2D) -> void:
	var shots: Dictionary = _waiting.get(index, {})
	_waiting.erase(index)
	if shots.is_empty():
		return
	for id: int in shots:
		var shot: SelfieRules.Shot = shots[id]
		if not shot.inside or not players.has(id):
			continue
		var player: Player = players[id]
		pop_text(player.global_position + Vector3(0.0, 1.7, 0.0), "+%d" % shot.followers, Palette.GOLD if shot.posing else Palette.PAPER)
		player.squash(4.0)
	var mine: SelfieRules.Shot = shots[local_id]
	_selfie_hud.monitor.set_live(false)
	_selfie_hud.show_photo(photo, mine.followers, mine.inside, mine.posing)
	_photos.append(photo)
	_numbers.append(mine.followers if mine.inside else -1)


func _on_pose_changed(player_id: int, posing: bool, style: int) -> void:
	var player: Player = players[player_id]
	player.pose_style = style
	player.posing = posing
	(_glitter[player_id] as CPUParticles3D).emitting = posing
	if posing:
		_pose_held[player_id] = player.move_input.length() > settings.pose_break_input
		player.squash(3.0)
		_face_camera(player)
		if player_id == local_id:
			SynthSound.play(self, SynthSound.tone(988.0, 0.18, 200.0, 0.35), -11.0)


#Posers turn to the camera so the photo shows their face
func _face_camera(player: Player) -> void:
	var pivot := player.get_node("ModelPivot") as Node3D
	var from := pivot.rotation.y
	var turn := deg_to_rad(_studio.camera_turn(rules.spot()))
	var spin := func(share: float) -> void:
		if player.posing:
			pivot.rotation.y = lerp_angle(from, turn, share)
	create_tween().tween_method(spin, 0.0, 1.0, 0.25)


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
	var score := RoundScore.make(sheet, rules.points_of(local_id), "%d de %d fotos" % [state.photos, count], lines)
	var result := RoundResult.make(MINIGAME_ID, won, "En cuadro" if won else "Fuera de cuadro", "", lines).with_score(score, rules.totals())
	_drone.hide_frame()
	_selfie_hud.marker.set_shown(false)
	for id: int in players:
		(_spots[id] as Node3D).hide()
		(_pointers[id] as Node3D).hide()
	_selfie_hud.show_roll(_photos, _numbers)
	end_round(result, "%d SEGUIDORES" % state.followers, "%d de %d fotos" % [state.photos, count], won)


#Shield bubble, boost ring and pose sparkles on a player
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
	ring.layers = SelfieCamera.layer_bit(SelfieCamera.GUIDE_LAYER)
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
	var circle := TorusMesh.new()
	circle.inner_radius = 0.56
	circle.outer_radius = 0.7
	circle.rings = 32
	circle.ring_segments = 4
	var spot := MeshInstance3D.new()
	spot.mesh = circle
	spot.scale = Vector3(1.0, 0.25, 1.0)
	spot.position.y = 0.05
	spot.layers = SelfieCamera.layer_bit(SelfieCamera.FRAME_LAYER)
	spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spot.hide()
	player.add_child(spot)
	_spots[player.player_id] = spot
	var cone := CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 0.0
	cone.height = 0.8
	cone.radial_segments = 4
	cone.rings = 1
	var pointer := MeshInstance3D.new()
	pointer.mesh = cone
	pointer.material_override = _glow_paint(Palette.GOLD)
	pointer.layers = SelfieCamera.layer_bit(SelfieCamera.MONITOR_LAYER)
	pointer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pointer.hide()
	player.add_child(pointer)
	_pointers[player.player_id] = pointer


#Unshaded colour so a mark reads on any floor
func _glow_paint(color: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = color
	return paint


#Flat gold floor arrow along +Z
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
		piece.layers = SelfieCamera.layer_bit(SelfieCamera.GUIDE_LAYER)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		guide.add_child(piece)
	return guide


#Per player arrow shown only while far from the photo and not looking at it
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


#Next photo badge: over the set, then the frame; gold while blinking, faded when inside
func _tick_marker() -> void:
	var player := local_player()
	var heading := rules.phase == SelfieRules.Phase.TRAVEL or rules.frame_visible()
	var inside := rules.frame_visible() and rules.is_inside(player.global_position)
	_selfie_hud.marker.set_shown(heading and not inside)
	if not heading:
		return
	var target := (rules.frame_center() if rules.frame_visible() else _studio.position_of(rules.spot())) + Vector3(0.0, MARKER_LIFT, 0.0)
	var camera := player.view_camera()
	var meters := Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length()
	_selfie_hud.marker.point_at(camera.unproject_position(target), camera.is_position_behind(target), meters, rules.phase == SelfieRules.Phase.LOCK)


#Per player ring under the feet (green inside) and arrow over the head
func _refresh_spot(player_id: int, player: Player) -> void:
	var spot: MeshInstance3D = _spots[player_id]
	var pointer: MeshInstance3D = _pointers[player_id]
	var mine := player_id == local_id and not is_falling(player_id)
	spot.visible = mine and rules.frame_visible()
	if spot.visible:
		spot.material_override = _spot_paints[1 if rules.is_inside(player.global_position) else 0]
	pointer.visible = mine and _camera.is_live()
	if pointer.visible:
		pointer.position.y = 2.5 + 0.2 * sin(clock * 5.0)
		pointer.rotation.y = clock * 2.0


func _refresh_marks(player_id: int) -> void:
	(_shields[player_id] as MeshInstance3D).visible = brawl.has_shield(player_id)
	var state := rules.state_of(player_id)
	var ring: MeshInstance3D = _rings[player_id]
	ring.visible = state.jump_left > 0.0 or state.speed_left > 0.0
	if ring.visible:
		ring.material_override = PartyKit.paint(BOOST_COLORS[1 if state.speed_left > 0.0 else 0], 2.0, 0.4)
		ring.scale = Vector3.ONE * (1.0 + 0.12 * sin(clock * 9.0))
