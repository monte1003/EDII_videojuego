extends Node

#The fair screen. With no game it plays the trailer (attract mode); when a game of the room starts it watches each round in the real
#scene of the round, built from the seed that came from the server, with every player as a puppet and a camera that cuts by itself
#(spectator); at the end it plays the podium ceremony with no way to skip it, celebrates the winner, puts the game in the ranking of the
#fair with its animations and goes back to the trailer. A new game takes it to the spectator from anywhere. It follows the messages of
#the room and changes nothing of the game. Players never touch it; the staff has hidden keys: M mutes, F2 shows the connection, F6 opens
#the full ranking and F8, pressed twice, empties it

signal mode_changed(mode: String)

enum Mode { ATTRACT, SPECTATOR, PODIUM, FINALE }

const STAGES := {"lobby": "SALA DE ESPERA", "warmup": "CALENTAMIENTO", "intro": "SORTEO Y CARGA", "playing": "EN JUEGO",
	"round_results": "RESULTADOS", "finished": "PARTIDA TERMINADA"}
const MODE_NAMES := {Mode.ATTRACT: "atraccion", Mode.SPECTATOR: "espectador", Mode.PODIUM: "podio", Mode.FINALE: "ranking"}
#Seconds the ranking of the end stays on screen before the trailer comes back
const RANKING_SECONDS := 14.0
#Seconds the second press of F8 has to confirm that the ranking is emptied
const RESET_WINDOW := 5.0
const PLACE_MEDALS: Array[ScoreSheet.Medal] = [ScoreSheet.Medal.DIAMOND, ScoreSheet.Medal.GOLD, ScoreSheet.Medal.SILVER,
	ScoreSheet.Medal.BRONZE]
#Our lines for the winner ("%s" is its name)
const CHEERS: Array[Array] = [["%s SE DESCONECTÓ", "Y SE LLEVÓ LA CORONA."], ["NINGUNA NOTIFICACIÓN", "PUDO CON %s."],
	["MÁS ALCANCE QUE CUALQUIER", "POST: %s."], ["SIN FILTRO Y SIN SCROLL:", "%s MANDA EN EL RING."]]

var watch := NetWatch.new()
var reel := AttractReel.new()
var frame := FairFrame.new()
var ranking := FairRanking.new()
var mode := Mode.ATTRACT

var _status_panel := PanelContainer.new()
var _status: Label
var _round: Node
var _director: SpectatorDirector
var _podium: FairPodium
#The key of the game being watched (its seeds), so the ranking never counts a game twice, and the entries it added
var _game := ""
var _fresh: Array[Dictionary] = []
var _record := false
var _finale_turn := 0
var _layers_left := 0.0
var _reset_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	#A screen that runs for hours: no more frames than a common monitor shows
	Engine.max_fps = 60
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_rng.randomize()
	reel.name = "Reel"
	add_child(reel)
	frame.name = "Frame"
	add_child(frame)
	reel.focus_changed.connect(frame.show_focus)
	watch.name = "Watch"
	add_child(watch)
	watch.changed.connect(_refresh)
	GameSession.net.watched.connect(_on_message)
	GameSession.net.left.connect(_on_room_lost)
	ranking.load_file()
	frame.ranking.show_rows(_ranking_rows())
	_build_status()
	_to_attract()


func _process(delta: float) -> void:
	_reset_left -= delta
	#The screens of a round watched here stay hidden (its HUD, help and pause are for a player); only its loading cover shows
	if _round != null:
		_layers_left -= delta
		if _layers_left <= 0.0:
			_layers_left = 0.5
			for layer in _round.find_children("*", "CanvasLayer", true, false):
				if not layer is LoadingCover:
					(layer as CanvasLayer).visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fair_mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	elif event.is_action_pressed("fair_status"):
		_status_panel.visible = not _status_panel.visible
	elif event.is_action_pressed("fair_ranking_all"):
		frame.toggle_full_list(_ranking_rows(-1))
	elif event.is_action_pressed("fair_ranking_reset"):
		if _reset_left > 0.0:
			_reset_left = 0.0
			ranking.reset()
			frame.ranking.show_rows(_ranking_rows())
			frame.notice("RANKING BORRADO")
		else:
			_reset_left = RESET_WINDOW
			frame.notice("¿BORRAR TODO EL RANKING? PULSA F8 OTRA VEZ", RESET_WINDOW)


#Every message about the game, after NetWatch has updated its picture of it
func _on_message(message: Dictionary) -> void:
	match String(message["t"]):
		"warmup":
			#Only a round left on screen goes away: the podium and the ranking end by themselves
			if mode == Mode.SPECTATOR:
				_to_attract()
		"start":
			_game = _game_key()
			_record = false
			_watch_round(0)
		"advance":
			if watch.stage == "finished":
				_start_podium()
			elif mode == Mode.SPECTATOR or mode == Mode.ATTRACT:
				_watch_round(watch.round_index)
		"scores":
			_refresh_board(int(message.get("round", -1)))
			if int(message.get("round", -1)) == watch.plan.size() - 1:
				_put_in_ranking()
		"final":
			_put_in_ranking()
		"struck":
			if _director != null:
				_director.on_struck(int(message.get("to", 0)))
		"done":
			if _director != null:
				_director.on_done(int(message.get("id", 0)))


#The connection to the room was lost: a round or a podium cannot go on without it
func _on_room_lost(_reason: String) -> void:
	if mode == Mode.SPECTATOR or mode == Mode.PODIUM:
		_to_attract()


#The real scene of a round, with the order and the seed of the room, every player a puppet and the camera of the director
func _watch_round(index: int) -> void:
	#A screen that came in with the game under way catches it at the next round
	if _game == "":
		_game = _game_key()
	if index < 0 or index >= watch.plan.size() or _game == "":
		return
	var info := MinigameCatalog.find(watch.plan[index])
	if info == null:
		return
	_clear_stage()
	GameSession.sync_lobby(watch.net.room)
	GameSession.follow_round(watch.plan, watch.seeds, index)
	_round = (load(info.scene_path) as PackedScene).instantiate()
	add_child(_round)
	move_child(_round, 0)
	_layers_left = 0.0
	_director = SpectatorDirector.new()
	_round.add_child(_director)
	_director.focus_changed.connect(_on_focus)
	frame.show_focus(info.title, "RONDA %d DE %d" % [index + 1, watch.plan.size()], ScoreSheet.Medal.NONE)
	_set_mode(Mode.SPECTATOR)


#Who the director is watching: the banner shows the player, why, and the crown of its place in the game so far
func _on_focus(player_id: int, reason: String) -> void:
	var info := MinigameCatalog.find(watch.plan[clampi(watch.round_index, 0, watch.plan.size() - 1)]) if not watch.plan.is_empty() else null
	if player_id < 0:
		frame.show_focus(info.title if info != null else "", "PLANO GENERAL · RONDA %d DE %d" % [watch.round_index + 1, watch.plan.size()],
			ScoreSheet.Medal.NONE)
		return
	var order := _standings()
	var place := -1
	for index in order.size():
		if int(order[index]["id"]) == player_id:
			place = index
	var player: Dictionary = order[place] if place >= 0 else {}
	frame.show_focus(str(player.get("name", "")), reason, PLACE_MEDALS[place] if place >= 0 and place < PLACE_MEDALS.size() else ScoreSheet.Medal.NONE)


#The ceremony of the game, as on the computers of the players but with no way to skip it
func _start_podium() -> void:
	_clear_stage()
	GameSession.sync_lobby(watch.net.room)
	_podium = FairPodium.new()
	_podium.players = _standings()
	_podium.done.connect(_start_finale)
	add_child(_podium)
	move_child(_podium, 0)
	frame.show_focus("Podio", "FIN DE LA PARTIDA", ScoreSheet.Medal.NONE)
	_set_mode(Mode.PODIUM)


#The winner celebrated on the stage of the trailer, then the ranking of the fair with the game in it, then back to the trailer
func _start_finale() -> void:
	var order := _standings()
	_clear_stage()
	_set_mode(Mode.FINALE)
	_finale_turn += 1
	var turn := _finale_turn
	if order.is_empty():
		_to_attract()
		return
	var winner := order[0]
	var shown := str(winner.get("name", "JUGADOR")).to_upper()
	var cheer: Array = CHEERS[_rng.randi() % CHEERS.size()]
	var lines: Array[String] = [str(cheer[0]).replace("%s", shown), str(cheer[1]).replace("%s", shown)]
	await reel.celebrate(StringName(str(winner.get("character", "fire"))), str(winner.get("name", "")), int(winner.get("total", 0)), lines)
	if turn != _finale_turn or mode != Mode.FINALE:
		return
	_put_in_ranking()
	var rows := _ranking_rows()
	var places: Array[int] = []
	var ordered := ranking.ordered()
	for entry in _fresh:
		places.append(ordered.find(entry))
	frame.show_finale(rows, places, _finale_lines(ordered))
	frame.ranking.show_rows(rows, places)
	if _record:
		reel.cheer()
	await get_tree().create_timer(RANKING_SECONDS).timeout
	if turn != _finale_turn or mode != Mode.FINALE:
		return
	_to_attract()


#What the end of the ranking says: a new record of the day, who got into the top ten and where, who was short and by how much
func _finale_lines(ordered: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for entry in _fresh:
		var place := ordered.find(entry)
		var shown := str(entry["name"]).to_upper()
		if place == 0 and _record:
			lines.push_front("¡NUEVO RÉCORD DEL DÍA: %s!" % shown)
		elif place >= 0 and place < FairRanking.TOP:
			lines.append("%s ENTRA AL TOP 10 · PUESTO %d" % [shown, place + 1])
		else:
			lines.append("A %s LE FALTARON %d PUNTOS PARA EL TOP 10" % [shown, ranking.short_of_top(entry)])
	return lines.slice(0, 4)


#The players of the game in the ranking of the fair, once: at the points of the last round and again, the same game, with the final totals
func _put_in_ranking() -> void:
	if _game == "":
		return
	var players := _standings()
	if players.is_empty():
		return
	var before := ranking.ordered()
	var best_before := int(before[0]["total"]) if not before.is_empty() and str(before[0]["game"]) != _game else -1
	_fresh = ranking.record(_game, players)
	var top := ranking.ordered()
	_record = not top.is_empty() and str(top[0]["game"]) == _game and int(top[0]["total"]) > best_before
	frame.ranking.show_rows(_ranking_rows())


#Everybody of the game from the best to the worst: the totals the server sent at the end, or the sum of the rounds known so far, with
#the best round to break a tie (the same AVL tree as the final count)
func _standings() -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for member in watch.net.room:
		var id := int(member.get("id", 0))
		var total := watch.total_of(id)
		var best := 0
		for points in watch.table:
			best = maxi(best, int(points.get(id, 0)))
		for entry in watch.finals:
			if int(entry.get("id", 0)) == id:
				total = int(entry.get("total", total))
				best = int(entry.get("best", best))
		players.append({"id": id, "name": str(member.get("name", "JUGADOR")), "character": str(member.get("character", "fire")),
			"total": total, "best": best, "gone": not bool(member.get("connected", true))})
	var tree := AVLTree.new()
	for player in players:
		tree.insert(int(player["total"]), int(player["id"]), int(player["best"]))
	var order: Array[Dictionary] = []
	for node in tree.standings():
		for player in players:
			if int(player["id"]) == node.player_id:
				order.append(player)
	return order


#Rows of [name, total] of the ranking, best first (all of them with -1)
func _ranking_rows(count := FairRanking.TOP) -> Array[Array]:
	var rows: Array[Array] = []
	for entry in ranking.ordered():
		if count >= 0 and rows.size() >= count:
			break
		rows.append([entry["name"], entry["total"]])
	return rows


#The live board: everybody of the game with its character colour and total, and what each won in round "scored" (-1: nothing yet)
func _refresh_board(scored := -1) -> void:
	var live := watch.connected and watch.stage != "lobby" and mode != Mode.FINALE
	var rows: Array[Dictionary] = []
	if live:
		for player in _standings():
			var gain := 0
			if scored >= 0 and scored < watch.table.size():
				gain = int(watch.table[scored].get(int(player["id"]), 0))
			rows.append({"name": player["name"], "total": player["total"], "gain": gain, "gone": player["gone"],
				"color": GameSession.character_by_id(StringName(str(player["character"]))).accent_color})
	frame.show_board(rows)


#A game is known by its seeds: the same game seen twice (the screen came back) is never two games in the ranking
func _game_key() -> String:
	var parts := PackedStringArray()
	for value in watch.seeds:
		parts.append(str(value))
	return ",".join(parts)


func _to_attract() -> void:
	_clear_stage()
	_set_mode(Mode.ATTRACT)
	#The music of a round watched here may still be playing: the trailer brings its own
	ScreenFlow.music.play_for(&"fair_screen")
	reel.play()


#Takes away the round, the podium or the ranking of the end on screen and stops the trailer
func _clear_stage() -> void:
	frame.hide_finale()
	if _round != null:
		_round.queue_free()
		_round = null
		_director = null
	if _podium != null:
		_podium.queue_free()
		_podium = null
	reel.stop()
	Engine.time_scale = 1.0


func _set_mode(next: Mode) -> void:
	mode = next
	_refresh()
	mode_changed.emit(MODE_NAMES[next])


func _refresh() -> void:
	frame.set_live(_live_line(), watch.connected and watch.stage != "lobby")
	_refresh_board()
	var lines: Array[String] = [watch.status, "Modo: " + str(MODE_NAMES[mode])]
	var config := "feria.cfg: " + (watch.config_address if watch.config_address != "" else "sin dirección, se usa el anuncio de la red")
	if watch.address != "":
		var origin := "de feria.cfg" if watch.address == watch.config_address else "del anuncio de la red"
		lines.append("Sala en %s, %s · %s" % [watch.address, origin, config])
	else:
		lines.append(config)
	if watch.connected:
		lines.append(_game_line())
		var kilobytes := ("%.1f" % (watch.bytes_per_second / 1024.0)).replace(".", ",")
		lines.append("Recibe %d mensajes/s · %s KB/s" % [watch.messages_per_second, kilobytes])
	lines.append("Ranking: %d entradas · %s" % [ranking.entries.size(), ProjectSettings.globalize_path(ranking.path)])
	lines.append("M: sonido · F2: ocultar · F6: ranking completo · F8 dos veces: borrar el ranking")
	_status.text = "\n".join(lines)


#The light of the frame: whether there is a room, and what the game under way is doing
func _live_line() -> String:
	if not watch.connected:
		return "BUSCANDO LA SALA"
	if watch.stage == "lobby":
		return "SALA ABIERTA · %d EN LA SALA" % watch.net.room.size()
	if watch.stage == "warmup":
		return "EN VIVO · CALENTAMIENTO"
	if watch.stage == "finished":
		return "EN VIVO · PODIO"
	return "EN VIVO · RONDA %d DE %d" % [watch.round_index + 1, maxi(watch.plan.size(), 1)]


func _game_line() -> String:
	var stage: String = STAGES.get(watch.stage, watch.stage.to_upper())
	if watch.stage == "lobby":
		return "%s · %d en la sala" % [stage, watch.net.room.size()]
	if watch.round_index < 0 or watch.plan.is_empty() or watch.stage == "finished":
		return stage
	var info := MinigameCatalog.find(watch.plan[mini(watch.round_index, watch.plan.size() - 1)])
	var title := info.title if info != null else ""
	return "Ronda %d de %d · %s · %s" % [watch.round_index + 1, watch.plan.size(), title, stage]


#The details of the connection for the staff, hidden until F2
func _build_status() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var card := UiKit.card_style(0.95, 22)
	card.content_margin_left = 20.0
	card.content_margin_right = 20.0
	card.content_margin_top = 14.0
	card.content_margin_bottom = 14.0
	_status_panel.add_theme_stylebox_override("panel", card)
	_status_panel.position = Vector2(26.0, 110.0)
	_status_panel.visible = false
	layer.add_child(_status_panel)
	_status = UiKit.label("", UiKit.BODY_FONT, 16, Palette.INK)
	_status_panel.add_child(_status)
