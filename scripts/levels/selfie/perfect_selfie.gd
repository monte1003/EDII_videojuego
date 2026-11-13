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
#The first photo teaches the shove once; the chips are drawn from these
var _shove_taught := false
#Per player: the arrow on the floor that points to the photo while its camera looks somewhere else
var _guides: Dictionary = {}


func _ready() -> void:
	super()
	if ScreenFlow.tree.has(MINIGAME_ID):
		ScreenFlow.mark_current(MINIGAME_ID)
	_selfie_hud = hud as SelfieHud
	_studio = SelfieLayout.new()
	setup_arena(_studio)
	var ids: Array[int] = []
	for id: int in players:
		ids.append(id)
		_dress_player(players[id])
	_base_speed = local_player().move_speed
	_base_jump = local_player().jump_velocity
	rules = SelfieRules.new(settings, GameSession.score_sheet, _studio, ids, rng.randi())
	rules.photo_announced.connect(_on_photo_announced)
	rules.frame_locked.connect(_on_frame_locked)
	rules.frame_shown.connect(_on_frame_shown)
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
	keys.interact_pressed.connect(toggle_pose.bind(local_id))
	_help.setup(HelpPages.perfect_selfie(settings, GameSession.score_sheet))
	_selfie_hud.set_photo(1, rules.photo_count())
	hud.show_mission("Entra al marco", [
		"%s|mover" % InputHints.move_label(), "%s|posar" % InputHints.key_label(&"interact"), "%s|empujar" % InputHints.key_label(&"shove")], 4.5)


#A player starts or stops its pose; the rules decide whether it can
func request_pose(player_id: int, on: bool) -> void:
	if phase != Phase.RUNNING or not players.has(player_id):
		return
	var player: Player = players[player_id]
	if on and (player.is_down() or player.is_diving()):
		return
	rules.set_posing(player_id, on)


#The chips of the two actions: the pose near the player while the frame is there and the shove over the rival in reach, or near
#the player while there are rivals in the frame, with its recharge. They hide when the local player cannot act
func _tick_chips() -> void:
	var player := local_player()
	var camera := player.view_camera()
	var acting := phase == Phase.RUNNING and not is_falling(local_id) and not player.is_down()
	var head := player.global_position + Vector3(0.0, 1.9, 0.0)
	var visible_head := acting and not camera.is_position_behind(head)
	var here := camera.unproject_position(head) if visible_head else Vector2.ZERO
	var in_frame := rules.frame_visible() and (rules.is_inside(player.global_position) \
		or Vector2(player.global_position.x - rules.frame_center().x, player.global_position.z - rules.frame_center().z).length() < rules.frame_size() * 0.5 + 4.0)
	_selfie_hud.set_pose_chip(visible_head and in_frame, rules.is_posing(local_id), here + Vector2(96.0, -6.0))
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


#Whether somebody else (a player or a bot) is inside the frame
func _rival_in_frame() -> bool:
	for id: int in players:
		if id != local_id and rules.is_inside((players[id] as Player).global_position):
			return true
	for bot in bots:
		if rules.is_inside(bot.global_position):
			return true
	return false


#One press of the key strikes the pose and the next one drops it
func toggle_pose(player_id: int) -> void:
	request_pose(player_id, not rules.is_posing(player_id))


#Shoving drops the pose first: nobody shoves from a pose
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
	for id: int in players:
		var player: Player = players[id]
		#Trying to move or to jump drops the pose
		if rules.is_posing(id) and (player.move_input.length() > settings.pose_break_input or player.jump_requested):
			rules.set_posing(id, false)
		rules.place(id, player.global_position, player.is_on_floor(), is_falling(id))
	rules.extras.clear()
	for bot in bots:
		rules.extras.append(bot.global_position)
	rules.tick(delta)
	if phase == Phase.ENDED:
		return
	if rules.frame_visible():
		_drone.show_frame(rules.frame_center(), rules.frame_size(), rules.lock_share())
		_selfie_hud.viewfinder.aim(rules.frame_center(), rules.frame_size())
		_tick_blinks()
	_tick_chips()
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
	_selfie_hud.announce_camera()
	_drone.fly(_studio.flight_path(_studio.nearest_place(_drone.global_position - Vector3(0.0, SelfieLayout.DRONE_HEIGHT, 0.0)), spot), settings.travel_seconds * 0.9)
	_selfie_hud.set_photo(index + 1, rules.photo_count())
	SynthSound.play(self, SynthSound.tone(392.0, 0.3, 300.0, 0.35), -11.0)


#The viewfinder starts to draw the place of the photo
func _on_frame_shown(_index: int) -> void:
	_selfie_hud.viewfinder.aim(rules.frame_center(), rules.frame_size())
	_selfie_hud.viewfinder.set_active(true)


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
	for id: int in shots:
		var shot: SelfieRules.Shot = shots[id]
		if not shot.inside:
			continue
		var player: Player = players[id]
		pop_text(player.global_position + Vector3(0.0, 1.7, 0.0), "+%d" % shot.followers, Palette.GOLD if shot.posing else Palette.PAPER)
		player.squash(4.0)
	var mine: SelfieRules.Shot = shots[local_id]
	_selfie_hud.set_followers(rules.state_of(local_id).followers, mine.followers)
	_selfie_hud.reveal_photo(mine.followers if mine.inside else 0, mine.inside, mine.posing, settings.reveal_seconds - 1.13)
	get_tree().create_timer(settings.reveal_seconds * 0.7).timeout.connect(_drone.hide_frame)


func _on_pose_changed(player_id: int, posing: bool, style: int) -> void:
	var player: Player = players[player_id]
	player.pose_style = style
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
	var score := RoundScore.make(sheet, rules.points_of(local_id), "%d de %d fotos" % [state.photos, count], lines)
	var result := RoundResult.make(MINIGAME_ID, won, "En cuadro" if won else "Fuera de cuadro", "", lines).with_score(score, rules.totals())
	_drone.hide_frame()
	end_round(result, "%d SEGUIDORES" % state.followers, "%d de %d fotos" % [state.photos, count], won)


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
