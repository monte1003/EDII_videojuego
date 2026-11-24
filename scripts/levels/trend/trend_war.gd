class_name TrendWar
extends ArenaRound

#"Guerra de Tendencias": five rounds, one in each zone of La Plaza, in an order drawn with the seed. The zone is announced and lit, and its
#bubbles are born only there, more and more as its round goes on. Every player follows one trend at a time, drawn at random: touching a
#bubble of that kind completes it and draws the next one; a bubble of another kind lets the player through and wobbles. Once per zone the
#viral bubble comes, the trend of everybody, worth more. The next zone is announced before the round of this one ends, so everybody runs
#there through the plaza; nobody is moved by hand. Each zone has its own obstacle and shoves daze

const MINIGAME_ID := &"trend_war"
const SCREEN_LIFT := 11.0
const SCREEN_SIZE := Vector2(9.0, 3.25)
const SCREEN_PIXELS := Vector2i(432, 156)
const SCREEN_BACK := Color("1b1640")
const POLE_RADIUS := 0.45
#A giant toy on a pillar behind each zone, to tell them apart from anywhere
const LANDMARKS: Array[StringName] = [&"trophy", &"heart", &"like_hand", &"phone", &"bell"]
const LANDMARK_HEIGHT := 10.0
#Seconds a pad of airplane mode ignores the player it just threw
const GLASS_PAD_REST := 0.35
#Where the arrow of each screen points: this high over the middle of the zone
const POINTER_LIFT := 3.0

@export var settings: TrendSettings

var rules: TrendRules
var board: TrendBoard
var obstacles: TrendObstacles
#The zones in the order the rounds use them, the zone being played (-1 before the first one) and the one announced next
var zone_order: Array[int] = []
var active_zone := -1
var next_zone := -1

var _plaza: TrendLayout
var _zones: TrendZones
var _bubbles: TrendBubbles
var _trend_hud: TrendHud
var _glass_rest: Dictionary = {}
#Player id -> bubble id -> second until which that bubble does not wobble again for that player
var _passing: Dictionary = {}
#In a room every computer but the server shows the bubbles the server makes and takes; the bubbles this one already claimed
var _mirror := false
var _claimed: Dictionary = {}
var _screen_view: SubViewport
var _screen_strip: TrendStrip
var _screen_label: Label


func _ready() -> void:
	super()
	if ScreenFlow.tree.has(MINIGAME_ID):
		ScreenFlow.mark_current(MINIGAME_ID)
	_trend_hud = hud as TrendHud
	add_child(TrendIcons.new())
	_plaza = TrendLayout.new()
	bots_enabled = false
	setup_arena(_plaza)
	if settings.random_seed != 0:
		rng.seed = settings.random_seed
	obstacles = TrendObstacles.new(_plaza)
	_zones = TrendZones.new()
	world.add_child(_zones)
	_zones.build(_plaza, obstacles)
	board = TrendBoard.new(_plaza, settings, rng.randi())
	zone_order = TrendLayout.draw_zones(rng.randi())
	_bubbles = TrendBubbles.new()
	world.add_child(_bubbles)
	_bubbles.build(board, _plaza)
	_build_screen()
	_build_landmarks()
	var ids: Array[int] = []
	for id: int in players:
		ids.append(id)
		_glass_rest[id] = 0.0
		_passing[id] = {}
		#Players stand on the glass of airplane mode, which the arm of their camera goes through
		var body: Player = players[id]
		body.collision_mask |= TrendLayout.GLASS_BIT
	rules = TrendRules.new(settings, GameSession.score_sheet, ids, rng.randi())
	rules.par = settings.par_for(ids.size())
	rules.zone_announced.connect(_on_zone_announced)
	rules.zone_started.connect(_on_zone_started)
	rules.trend_drawn.connect(_on_trend_drawn)
	rules.trend_completed.connect(_on_trend_completed)
	rules.finished.connect(_on_finished)
	#In a room the server makes and takes every bubble and tells the others: each computer sees the other players a little late
	_mirror = _networked_round() and not GameSession.net.is_host()
	board.mirror = _mirror
	if _networked_round():
		GameSession.net.round_event.connect(_on_round_event)
		if not _mirror:
			board.bubble_announced.connect(func(id: int) -> void: GameSession.net.send_round_event({"k": "bub", "id": id,
				"slot": board.slot_of(id), "kind": board.kind_of(id), "ph": snappedf(board.bob_of(id), 0.001)}))
			board.bubble_gone.connect(func(id: int, taken: bool) -> void: GameSession.net.send_round_event({"k": "gone", "id": id, "tk": taken}))
	_help.setup(HelpPages.trend_war(settings))
	hud.set_time(settings.zone_seconds)
	hud.show_mission("Atrapa tu tendencia", [
		"move=%s|mover" % InputHints.move_label(), "jump=%s|saltar" % InputHints.key_label(&"jump"), "shove=%s|empujar" % InputHints.key_label(&"shove")], 4.5)


func _on_round_started() -> void:
	rules.start()


func _tick_round(delta: float) -> void:
	rules.tick(delta)
	if phase == Phase.ENDED:
		return
	_tick_zones(delta)
	var wanted: Dictionary = {}
	for id: int in players:
		wanted[id] = rules.needed(id)
	board.tick(delta, rules.zone_share(), _positions(), wanted)
	if rules.phase == TrendRules.Phase.RUN:
		_check_touches()
		hud.set_time(rules.time_left)
	_bubbles.refresh(clock, _wanted_here)


#Whether the player of this screen is after a kind of bubble: its bubbles shine and the others are see-through
func _wanted_here(kind: int) -> bool:
	return rules.wants(local_id, kind)


#The arrow of this screen toward the zone to go to, while its player is out of it: the one being played, or the next one once it is announced
func _process(_delta: float) -> void:
	var target_zone := next_zone if next_zone >= 0 else active_zone
	if phase != Phase.RUNNING or target_zone < 0 or not players.has(local_id):
		_trend_hud.point_zone(null, Vector3.ZERO, false)
		return
	var player := local_player()
	var target := _plaza.zone_center(target_zone) + Vector3(0.0, POINTER_LIFT, 0.0)
	_trend_hud.point_zone(player.view_camera(), target, not _plaza.in_zone(target_zone, player.global_position, 2.0))


#What every zone does to the players: the moving pieces, the pull of airplane mode, the pond, the screens and the likes
func _tick_zones(delta: float) -> void:
	var feet: Array[Vector3] = []
	for id: int in players:
		var player: Player = players[id]
		if player.is_on_floor():
			feet.append(player.global_position)
	obstacles.tick(delta, clock, feet)
	var notice := 0.0
	if next_zone >= 0:
		notice = clampf(rules.time_left / settings.next_notice, 0.0, 1.0)
	elif rules.phase == TrendRules.Phase.REVEAL:
		notice = clampf(rules.time_left / settings.reveal_seconds, 0.0, 1.0)
	_zones.update(clock, active_zone, next_zone, notice)
	for id: int in players:
		if is_falling(id):
			continue
		var player: Player = players[id]
		_glass_rest[id] = maxf(float(_glass_rest[id]) - delta, 0.0)
		_apply_gravity(player)
		var at := player.global_position
		if obstacles.in_pond(at):
			_splash(player)
			continue
		#A screen that rises puts out whoever stands on it at once, so nobody rides it up. Before it rises nobody is pushed: the way is
		#open until then, and a push as strong as the walk (5 m/s) held back whoever was crossing a screen that was already down
		var nudge := obstacles.screen_nudge(at, clock)
		if nudge != Vector3.ZERO:
			player.global_position += nudge
		var like := obstacles.like_push(at, clock)
		if like != Vector3.ZERO and hazards_enabled and player.can_be_dazed():
			_soft_hit(id, like)


#Inside the glass the pull is weak; a pad turns it over and throws the player toward the other side; out of the glass it is the normal
#one again and the player lands softly
func _apply_gravity(player: Player) -> void:
	var at := player.global_position
	if not obstacles.in_glass(at):
		if not player.is_gravity_normal():
			player.set_gravity_state(1.0, 1.0)
		return
	if player.gravity_scale >= 1.0:
		player.set_gravity_state(player.gravity_sign, TrendLayout.GRAVITY_SCALE)
	if float(_glass_rest[player.player_id]) > 0.0:
		return
	if player.gravity_sign > 0.0 and player.velocity.y <= 0.5 and obstacles.floor_pad_at(at) >= 0:
		_turn_over(player, -1.0)
	elif player.gravity_sign < 0.0 and player.velocity.y >= -0.5 and obstacles.ceiling_pad_at(at) >= 0:
		_turn_over(player, 1.0)


#A pad turns the pull over and throws the player toward the other side of the glass
func _turn_over(player: Player, pull_sign: float) -> void:
	_glass_rest[player.player_id] = GLASS_PAD_REST
	player.set_gravity_state(pull_sign, TrendLayout.GRAVITY_SCALE)
	player.velocity.y = -pull_sign * settings.pad_kick
	player.squash(5.0)
	SynthSound.play(self, SynthSound.tone(300.0 if pull_sign < 0.0 else 520.0, 0.25, 260.0 * -pull_sign, 0.5), -10.0, rng.randf_range(0.95, 1.05))


#Whoever falls in the pond is back on the dock at once, a little dazed, and loses nothing else
func _splash(player: Player) -> void:
	ImpactFx.ring(self, player.global_position + Vector3(0.0, 0.2, 0.0), Vector3.UP, TrendZones.WATER_COLOR, 0.5, 2.2, 0.4)
	player.global_position = obstacles.pond_exit(player.global_position) + Vector3(0.0, 0.1, 0.0)
	player.clear_motion()
	(locators[player.player_id] as PlayerLocator).force_vertex(_plaza.nearest_place(player.global_position))
	_daze(player, Vector3.ZERO, 0.3, settings.pond_stun)
	ImpactFx.dust(self, player.global_position, ImpactFx.DUST_COLOR, 8)


#A like lands on a player: a shield takes it, otherwise it throws the player out a little and dazes it for a moment
func _soft_hit(player_id: int, direction: Vector3) -> void:
	var player: Player = players[player_id]
	if brawl.has_shield(player_id):
		brawl.give_shield(player_id, 0.0)
		_on_shield_broken(player_id)
		return
	_on_struck(player_id, false, direction * settings.like_push)
	_daze(player, direction * settings.like_push, 0.4, settings.like_stun)


#Where every player is, for the board to be fair with the bubbles it makes
func _positions() -> Dictionary:
	var found: Dictionary = {}
	for id: int in players:
		found[id] = (players[id] as Player).global_position
	return found


#Everybody that touches a bubble: a trend of its own is taken; any other lets it through and wobbles. In a room a computer only takes for
#its own player: the server takes what the others claim
func _check_touches() -> void:
	for id: int in players:
		if is_falling(id):
			continue
		var player: Player = players[id]
		var passing: Dictionary = _passing[id]
		for bubble_id: int in board.bubbles.keys():
			if not board.is_live(bubble_id):
				continue
			var at := board.position_of(bubble_id)
			if not touches(player, at):
				continue
			var kind := board.kind_of(bubble_id)
			if rules.wants(id, kind):
				if id == local_id or not _networked_round():
					_take(id, bubble_id)
				break
			if clock >= float(passing.get(bubble_id, -1.0)):
				_pass_through(player, bubble_id)
			passing[bubble_id] = clock + settings.wobble_rest


#A player takes a bubble of its trend: here when this computer decides (alone or the server), otherwise asked of the server once
func _take(player_id: int, bubble_id: int) -> void:
	if _mirror:
		if not _claimed.has(bubble_id):
			_claimed[bubble_id] = true
			GameSession.net.send_round_event({"k": "claim", "id": bubble_id})
		return
	var kind := board.kind_of(bubble_id)
	if not board.is_live(bubble_id) or not rules.wants(player_id, kind) or is_falling(player_id):
		return
	board.take(bubble_id)
	rules.collect(player_id, kind)
	if _networked_round():
		GameSession.net.send_round_event({"k": "take", "p": player_id, "kind": kind, "next": rules.state_of(player_id).trend})


#What the server tells of the bubbles, or what a player claims of it (only the server listens to claims)
func _on_round_event(from: int, message: Dictionary) -> void:
	if int(_whole(message.get("r"))) != GameSession.round_index:
		return
	var bubble_id := _whole(message.get("id"))
	match str(message.get("k", "")):
		"claim":
			if not _mirror and players.has(from):
				_take(from, bubble_id)
		"bub":
			if _mirror:
				var bob: Variant = message.get("ph", 0.0)
				board.mirror_add(bubble_id, _whole(message.get("slot")), _whole(message.get("kind")), float(bob) if bob is float or bob is int else 0.0)
		"gone":
			if _mirror:
				_claimed.erase(bubble_id)
				board.mirror_gone(bubble_id, message.get("tk") is bool and bool(message.get("tk")))
		"take":
			if _mirror and players.has(_whole(message.get("p"))):
				rules.apply_collect(_whole(message.get("p")), _whole(message.get("kind")), _whole(message.get("next")))


#A whole number that came in a message, or -1 when it is not a number
static func _whole(value: Variant) -> int:
	return int(value) if value is float or value is int else -1


#Whether a player touches a bubble: around it, and over or under the middle of its body (the same with the gravity turned over)
func touches(player: Player, bubble: Vector3) -> bool:
	var at := player.global_position
	var middle := at.y + Player.TUMBLE_CENTER
	return Vector2(at.x - bubble.x, at.z - bubble.z).length() <= settings.touch_radius and absf(bubble.y - middle) <= settings.touch_height


#A bubble that is not the trend of the player: it lets it through, wobbles like jelly and goes bloop
func _pass_through(player: Player, bubble_id: int) -> void:
	_bubbles.wobble(bubble_id)
	if player.player_id == local_id:
		SynthSound.play(self, SynthSound.tone(240.0, 0.16, 160.0, 0.45), -14.0, rng.randf_range(0.9, 1.15))


#The next zone is announced: its beam lights up, the arrow points to it and its name shows; the first one also starts the clock of its notice
func _on_zone_announced(index: int, seconds: float) -> void:
	next_zone = zone_order[index % zone_order.size()]
	var title := TrendLayout.LABELS[next_zone]
	_trend_hud.show_zone(("AHORA: %s" if index == 0 else "SIGUE: %s") % title, _plaza.color_of_zone(next_zone).lightened(0.25), seconds)
	if index == 0:
		hud.set_time(seconds)
	for step in 3:
		var beep := create_tween()
		beep.tween_interval(0.16 * step)
		beep.tween_callback(SynthSound.play.bind(self, SynthSound.tone(523.0, 0.12, 0.0, 0.4), -11.0, 1.0 + 0.16 * step))


#The round of a zone starts: the bubbles of the last zone go and the first ones of this one are announced on its floor
func _on_zone_started(index: int) -> void:
	set_stage(index)
	active_zone = zone_order[index % zone_order.size()]
	next_zone = -1
	var wanted: Dictionary = {}
	for id: int in players:
		wanted[id] = rules.needed(id)
	board.open_zone(active_zone, _positions(), wanted)
	_screen_label.text = "%s · %d/%d" % [TrendLayout.LABELS[active_zone], index + 1, rules.round_count()]
	_refresh_screen()
	cheer(1.8)
	SynthSound.play(self, SynthSound.tone(880.0, 0.25, 0.0, 0.4), -9.0)


func _on_trend_drawn(player_id: int, kind: int) -> void:
	if player_id != local_id:
		return
	_trend_hud.set_trend(kind)
	var chain: Array[int] = [kind]
	_screen_strip.set_chain(chain)
	_refresh_screen()


func _on_trend_completed(player_id: int, kind: int, value: int, total: int) -> void:
	var player: Player = players[player_id]
	player.squash(5.0)
	var viral := kind == TrendRules.VIRAL
	ImpactFx.stars(self, player.global_position + Vector3(0.0, 1.0, 0.0), 5)
	pop_text(player.global_position + Vector3(0.0, 1.7, 0.0), ("VIRAL +%d" if viral else "+%d") % value, Palette.GOLD if viral else Palette.PAPER, 96 if viral else 80, 1.1)
	if viral:
		ImpactFx.confetti(self, player.global_position + Vector3(0.0, 1.2, 0.0), 70, 60.0, 7.0)
		cheer(2.6)
	if player_id == local_id:
		_trend_hud.set_count(total)
		var steps := 3 if viral else 1
		for step in steps:
			var note := create_tween()
			note.tween_interval(0.09 * step)
			note.tween_callback(SynthSound.play.bind(self, SynthSound.tone(660.0 if not viral else 784.0, 0.22, 240.0, 0.45), -7.0, 1.0 + 0.2 * step))


func _on_finished() -> void:
	var state := rules.state_of(local_id)
	var won := state.completed >= settings.win_trends
	var sheet := GameSession.score_sheet
	var lines: Array[Array] = [["Tendencias", str(state.completed)], ["Virales", str(state.virals)]]
	var score := RoundScore.make(sheet, rules.points_of(local_id), "%d tendencias" % state.completed, lines)
	var result := RoundResult.make(MINIGAME_ID, won, "Viral" if won else "Sin tendencia", "", lines).with_score(score, rules.totals())
	end_round(result, "VIRAL" if won else "%d TENDENCIAS" % state.completed, ("%d tendencias" % state.completed) if won else "", won)


#The giant screen over the plaza: a box with the zone being played and the trend of this screen on its four faces
func _build_screen() -> void:
	_screen_view = SubViewport.new()
	_screen_view.size = SCREEN_PIXELS
	_screen_view.disable_3d = true
	_screen_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_screen_view)
	var back := ColorRect.new()
	back.color = SCREEN_BACK
	back.size = SCREEN_PIXELS
	_screen_view.add_child(back)
	var column := VBoxContainer.new()
	column.size = SCREEN_PIXELS
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	_screen_view.add_child(column)
	_screen_label = UiKit.label("TENDENCIAS", UiKit.BUTTON_FONT, 20, Palette.GOLD)
	_screen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_screen_label)
	var middle := CenterContainer.new()
	column.add_child(middle)
	_screen_strip = TrendStrip.new()
	_screen_strip.slot = 96.0
	_screen_strip.beats = false
	middle.add_child(_screen_strip)

	var holder := Node3D.new()
	holder.position = _plaza.position_of(TrendLayout.CORE) + Vector3(0.0, SCREEN_LIFT, 0.0)
	world.add_child(holder)
	#The pole that holds it up, in the very middle of the plaza
	var pole_height := SCREEN_LIFT - SCREEN_SIZE.y / 2.0
	var pole := PartyKit.pillar(pole_height, POLE_RADIUS, PartyKit.PINK, PartyKit.WHITE)
	pole.position = _plaza.position_of(TrendLayout.CORE)
	world.add_child(pole)
	var trunk := CylinderShape3D.new()
	trunk.radius = POLE_RADIUS
	trunk.height = pole_height
	var collider := CollisionShape3D.new()
	collider.shape = trunk
	var post := StaticBody3D.new()
	post.position = pole.position + Vector3(0.0, pole_height / 2.0, 0.0)
	post.add_child(collider)
	world.add_child(post)
	var depth := SCREEN_SIZE.x + 0.5
	var box := BoxMesh.new()
	box.size = Vector3(depth, SCREEN_SIZE.y + 0.5, depth)
	var body := MeshInstance3D.new()
	body.mesh = box
	body.material_override = PartyKit.paint(PartyKit.INK, 0.0, 0.5)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(body)
	var picture := StandardMaterial3D.new()
	picture.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	picture.albedo_texture = _screen_view.get_texture()
	var face := QuadMesh.new()
	face.size = SCREEN_SIZE
	for index in 4:
		var side := MeshInstance3D.new()
		side.mesh = face
		side.material_override = picture
		side.rotation.y = PI / 2.0 * index
		side.position = Basis(Vector3.UP, side.rotation.y) * Vector3(0.0, 0.0, depth / 2.0 + 0.02)
		side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(side)
	for way: float in [-1.0, 1.0]:
		var trim := TorusMesh.new()
		trim.outer_radius = depth * 0.76
		trim.inner_radius = depth * 0.76 - 0.45
		trim.rings = 4
		trim.ring_segments = 8
		var ring := MeshInstance3D.new()
		ring.mesh = trim
		ring.rotation.y = PI / 4.0
		ring.position.y = way * (SCREEN_SIZE.y / 2.0 + 0.3)
		ring.material_override = PartyKit.candy(PartyKit.WHITE, PartyKit.PINK, 16.0, 0.0, 0.25)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(ring)


#Behind each zone, inside the rim of the island, a candy pillar in its colour holds a giant toy: the landmark that tells the zones apart
func _build_landmarks() -> void:
	for zone in TrendLayout.ZONE_COUNT:
		var out := minf(TrendLayout.SPANS[zone] + 3.0, TrendLayout.BASE_RADIUS - 3.0 - TrendLayout.DISTANCES[zone])
		var at := _plaza.zone_spot(zone, out, 0.0)
		var pillar := PartyKit.pillar(LANDMARK_HEIGHT, 0.9, _plaza.color_of_zone(zone), PartyKit.WHITE)
		pillar.position = at
		world.add_child(pillar)
		var toy := PropKit.make_tall(LANDMARKS[zone], 5.0, Color.WHITE, false)
		toy.position = at + Vector3(0.0, LANDMARK_HEIGHT + 0.6, 0.0)
		toy.rotation.y = atan2(-at.x, -at.z)
		world.add_child(toy)


func _refresh_screen() -> void:
	_screen_view.render_target_update_mode = SubViewport.UPDATE_ONCE
