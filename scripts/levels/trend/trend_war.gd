class_name TrendWar
extends ArenaRound

#"Guerra de Tendencias": bubbles with a toy inside float all over the map. Each of the five trends is a chain of kinds to fetch in
#order before its clock runs out; the sooner, the more points. Shoves and haters knock the last item out of you

const MINIGAME_ID := &"trend_war"
const SCREEN_LIFT := 11.0
const SCREEN_SIZE := Vector2(9.0, 3.25)
const SCREEN_PIXELS := Vector2i(432, 156)
const SCREEN_BACK := Color("1b1640")
#How far over or under a bubble a player can be and still touch it
const TOUCH_HEIGHT := 2.3

@export var settings: TrendSettings

var rules: TrendRules
var board: TrendBoard

var _plaza: TrendLayout
var _bubbles: TrendBubbles
var _trend_hud: TrendHud
var _bounce_rest: Dictionary = {}
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
	setup_arena(_plaza, 40.0, TrendLayout.TOP_HEIGHT)
	board = TrendBoard.new(_plaza, settings)
	board.deal(rng)
	_bubbles = TrendBubbles.new()
	world.add_child(_bubbles)
	_bubbles.build(board, settings)
	_build_screen()
	var ids: Array[int] = []
	for id: int in players:
		ids.append(id)
		_bounce_rest[id] = 0.0
	rules = TrendRules.new(settings, GameSession.score_sheet, ids, rng.randi())
	rules.trend_revealed.connect(_on_trend_revealed)
	rules.run_started.connect(_on_run_started)
	rules.item_collected.connect(_on_item_collected)
	rules.item_lost.connect(_on_item_lost)
	rules.trend_completed.connect(_on_trend_completed)
	rules.round_ended.connect(_on_trend_ended)
	rules.finished.connect(_on_finished)
	_help.setup(HelpPages.trend_war(settings))
	hud.set_time(rules.limit_of(0))
	hud.show_mission("Atrapa en orden lo que es tendencia", [
		"%s|mover" % InputHints.move_label(), "%s|saltar" % InputHints.key_label(&"jump"), "%s|empujar" % InputHints.key_label(&"shove")], 4.5)


func _on_round_started() -> void:
	rules.start()


func _tick_round(delta: float) -> void:
	rules.tick(delta)
	if phase == Phase.ENDED:
		return
	for point in board.tick(delta, rng):
		_bubbles.appear(point)
	for id: int in _bounce_rest:
		_bounce_rest[id] = maxf(float(_bounce_rest[id]) - delta, 0.0)
	var running := rules.phase == TrendRules.Phase.RUN
	if running:
		_check_touches()
		hud.set_time(rules.time_left)
	#While the trend is shown its first kind already shines, to plan the way
	var shown := rules.needed(local_id)
	if rules.phase == TrendRules.Phase.REVEAL and not rules.chain.is_empty():
		shown = rules.chain[0]
	var fade := clampf(rules.time_left / settings.fade_seconds, 0.0, 1.0) if running else 1.0
	_bubbles.refresh(clock, shown, fade, rules.round_index >= settings.drift_from)


#A blow from a rival or a hater knocks the last item out; it flies back toward whoever hit
func _on_struck(player_id: int, by_rival: bool, push: Vector3) -> void:
	if not by_rival:
		return
	var kind := rules.strike(player_id)
	if kind >= 0:
		board.drop(kind, (players[player_id] as Player).global_position, -push, player_id)


#Everybody that touches a bubble: the one it needs is fetched, any other just bounces it back
func _check_touches() -> void:
	for id: int in players:
		if is_falling(id):
			continue
		var player: Player = players[id]
		var need := rules.needed(id)
		if need < 0:
			continue
		var fetched := false
		for index in board.loose.size():
			var item := board.loose[index]
			if int(item["kind"]) == need and board.can_pick(item, id) and _touches(player, item["position"]):
				rules.collect(id, board.take_loose(index))
				fetched = true
				break
		if fetched:
			continue
		for point in board.kinds.size():
			var kind := board.kinds[point]
			if kind < 0 or not _touches(player, _bubbles.place_of(point)):
				continue
			if kind == need:
				board.take(point)
				_bubbles.pop(point)
				rules.collect(id, kind)
				break
			if float(_bounce_rest[id]) <= 0.0:
				_bounce(player, point)


func _touches(player: Player, bubble: Vector3) -> bool:
	var at := player.global_position
	return Vector2(at.x - bubble.x, at.z - bubble.z).length() <= settings.touch_radius and absf(bubble.y - at.y) <= TOUCH_HEIGHT


#A bubble that is not the one to fetch: a soft knock back and a wobble, no punishment
func _bounce(player: Player, point: int) -> void:
	_bounce_rest[player.player_id] = settings.bounce_rest
	var away := player.global_position - _bubbles.place_of(point)
	away.y = 0.0
	player.apply_push((away.normalized() if away.length() > 0.05 else Vector3.BACK) * 4.5)
	_bubbles.wobble(point)
	SynthSound.play(self, SynthSound.tone(330.0, 0.12, 120.0, 0.4), -12.0, rng.randf_range(0.95, 1.1))


func _on_trend_revealed(index: int, chain: Array[int], limit: float) -> void:
	set_stage(index)
	for missing in maxi(settings.haters[mini(index, settings.haters.size() - 1)] - bots.size(), 0):
		add_bot()
	hud.set_time(limit)
	_trend_hud.show_trend(chain, settings.reveal_seconds)
	_screen_label.text = "TENDENCIA %d/%d" % [index + 1, rules.round_count()]
	_screen_strip.set_chain(chain)
	_refresh_screen()
	for step in chain.size():
		var beep := create_tween()
		beep.tween_interval(0.18 * step)
		beep.tween_callback(SynthSound.play.bind(self, SynthSound.tone(523.0, 0.12, 0.0, 0.4), -10.0, 1.0 + 0.16 * step))


#The clock of the trend starts: the par of each player is the fastest way from where it stands
func _on_run_started(_index: int) -> void:
	var held := board.by_kind()
	for id: int in players:
		rules.set_par(id, _plaza.par_seconds((players[id] as Player).global_position, rules.chain, held))
	SynthSound.play(self, SynthSound.tone(880.0, 0.25, 0.0, 0.4), -9.0)


func _on_item_collected(player_id: int, slot: int, _kind: int) -> void:
	var player: Player = players[player_id]
	player.squash(5.0)
	ImpactFx.stars(self, player.global_position + Vector3(0.0, 1.0, 0.0), 5)
	if player_id == local_id:
		_trend_hud.set_done(slot + 1)
		_screen_strip.set_done(slot + 1)
		_refresh_screen()
		SynthSound.play(self, SynthSound.tone(660.0, 0.2, 240.0, 0.45), -7.0, 1.0 + 0.14 * slot)


func _on_item_lost(player_id: int, slot: int, _kind: int) -> void:
	if player_id == local_id:
		_trend_hud.set_done(slot)
		_screen_strip.set_done(slot)
		_refresh_screen()


func _on_trend_completed(player_id: int, _place: int, points: int) -> void:
	var player: Player = players[player_id]
	pop_text(player.global_position + Vector3(0.0, 2.0, 0.0), "VIRAL", Palette.GOLD, 110, 0.5)
	pop_text(player.global_position + Vector3(0.0, 1.45, 0.0), "+%d" % points, Palette.PAPER, 80, 1.3)
	ImpactFx.confetti(self, player.global_position + Vector3(0.0, 1.2, 0.0), 70, 60.0, 7.0)
	cheer(2.6)
	if player_id == local_id:
		for step in 3:
			var note := create_tween()
			note.tween_interval(0.09 * step)
			note.tween_callback(SynthSound.play.bind(self, SynthSound.tone(784.0, 0.3, 0.0, 0.4), -8.0, 1.0 + 0.25 * step))


func _on_trend_ended(_index: int) -> void:
	var state := rules.state_of(local_id)
	if not state.done:
		_trend_hud.miss()
		SynthSound.play(self, SynthSound.tone(220.0, 0.45, -90.0, 0.5), -8.0)


func _on_finished() -> void:
	var state := rules.state_of(local_id)
	var count := rules.round_count()
	var won := state.completed >= settings.win_trends
	var sheet := GameSession.score_sheet
	var lines: Array[Array] = [["Tendencias", "%d de %d" % [state.completed, count]], ["Mejor", "+%d" % state.best]]
	var score := RoundScore.make(sheet, state.total, "Completaste %d de %d tendencias" % [state.completed, count], lines)
	var message := "Una tendencia se disfruta más cuando eliges cuál seguir y a tu ritmo." if won \
		else "No hace falta subirse a todas las tendencias: elige una ruta y síguela con calma."
	var result := RoundResult.make(MINIGAME_ID, won, "Viral" if won else "Sin tendencia", message, lines).with_score(score, rules.totals())
	end_round(result, "¡VIRAL!" if won else "SE ACABÓ", "%d de %d" % [state.completed, count], won)


#The giant screen over the core: a box with the trend on its four faces, the same row of icons the players carry
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
	_screen_label = UiKit.label("TENDENCIA", UiKit.BUTTON_FONT, 20, Palette.GOLD)
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


func _refresh_screen() -> void:
	_screen_view.render_target_update_mode = SubViewport.UPDATE_ONCE
