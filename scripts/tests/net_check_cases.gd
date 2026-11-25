extends RefCounted

#Fair screen cases of net_check, apart because autoloads only exist at run time

const SETTLE_MS := 250
const FRAME_MS := 4
#Real-time limits; a try at a closed port takes Windows a couple of seconds
const FIND_MS := 30000
const WAITS_MS := 60000
const PLAN: Array[StringName] = [&"trend_war", &"perfect_selfie", &"social_drop", &"street_game", &"level_01"]
const SEEDS: Array[int] = [11, 22, 33, 44, 55]
const SHOVE_PUSH: Array[float] = [3.0, 2.0, 0.0]

var tree: SceneTree
var _failures := 0
var _session: Node
var _host: NetRoom
var _players: Array[NetLink] = []
#What each player got, as JSON text, without the heartbeat
var _heard: Array[Array] = []
var _screen: NetRoom
#What the screen got, and the players whose places reached it
var _seen: Array[Dictionary] = []
var _placed: Dictionary = {}
var _votes := 0


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	_session = tree.root.get_node("GameSession")
	var plain := await _play(false)
	var watched := await _play(true)
	var sizes: Array[int] = []
	for heard in watched:
		sizes.append(heard.size())
	_expect(not plain.is_empty() and plain == watched, "los 3 jugadores reciben exactamente los mismos mensajes, en el mismo orden, con la pantalla y sin ella (%s)" % str(sizes))
	await _check_room_again()
	await _check_full_room()
	await _check_round_events()
	await _check_early_server()
	await _check_finder()
	return _failures


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


#Waits in real time while messages arrive
func _settle(ms := SETTLE_MS) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		_listen()
		OS.delay_msec(FRAME_MS)
		await tree.process_frame
	_listen()


func _listen() -> void:
	for index in _players.size():
		for message in _players[index].take():
			if message["t"] != "ping":
				_heard[index].append(JSON.stringify(message))


func _kinds_seen(kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for message in _seen:
		if message["t"] == kind:
			found.append(message)
	return found


#A fresh host room each time
func _open_room() -> bool:
	if _host != null:
		_host.queue_free()
	_host = NetRoom.new()
	tree.root.add_child(_host)
	_host.vote_received.connect(func(_id: int) -> void: _votes += 1)
	for attempt in 10:
		if _host.host("ANFITRION", &"fire"):
			return true
		await _settle(300)
	return false


#One room game step by step, with the screen when asked
func _play(with_screen: bool) -> Array[Array]:
	var label := "con pantalla" if with_screen else "sin pantalla"
	_players.clear()
	_heard = [[], [], []]
	_seen.clear()
	_placed.clear()
	_votes = 0
	_expect(await _open_room(), "%s: el anfitrión abre la sala" % label)
	for index in 3:
		var link := NetLink.connecting("127.0.0.1", NetProtocol.PORT)
		link.start()
		_players.append(link)
		link.send({"t": "hello", "v": NetProtocol.VERSION, "name": "J%d" % (index + 2), "character": "water"})
		await _settle()
	_expect(_host.room.size() == 4, "%s: 4 jugadores en la sala" % label)
	if with_screen:
		await _screen_comes_in()
	for index in 3:
		_players[index].send({"t": "ready", "value": true})
		await _settle()
	_host.set_ready(true)
	await _settle()
	if with_screen:
		await _screen_tries_to_play()
	_host.begin_warmup()
	await _settle()
	_host.send_warm(20.0, 0, 4)
	await _settle()
	for index in 3:
		_players[index].send({"t": "vote"})
		await _settle()
	_expect(_votes == 3, "%s: el anfitrión cuenta los 3 votos de los jugadores y ninguno más" % label)
	_host.start_game(PLAN, SEEDS)
	await _settle()
	for index in 3:
		_players[index].send({"t": "loaded", "round": 0})
		await _settle()
	_host.report_loaded(0)
	_expect(_host.go_round == 0, "%s: la ronda sale en cuanto cargaron los 4 jugadores, sin esperar a nadie más" % label)
	await _settle()
	for index in 3:
		_players[index].send({"t": "st", "p": [float(index), 0.5, 2.0], "r": 0.5, "m": true, "a": false, "po": false, "ps": 0})
		await _settle()
	_host.send_state({"p": [9.0, 0.5, 9.0], "r": 1.0, "m": false, "a": true, "po": true, "ps": 2})
	await _settle()
	_players[0].send({"t": "hit", "to": 4, "push": SHOVE_PUSH, "strength": 0.35})
	await _settle()
	_host.send_hit({"to": 3, "push": SHOVE_PUSH, "strength": 0.35})
	await _settle()
	if with_screen:
		await _screen_drops_in_round()
	for index in 3:
		_players[index].send({"t": "points", "round": 0, "points": 500 + 100 * index})
		await _settle()
	_host.report_points(0, 800)
	_expect(_host._points_left < 0.0, "%s: el marcador de la ronda sale en cuanto llegan los puntos de los 4, sin esperar a nadie más" % label)
	await _settle()
	#The host's game says it is in the last round, so the end of the game goes out
	_session.set("plan", PLAN)
	_session.set("round_index", PLAN.size() - 1)
	_host.advance_all()
	await _settle()
	var none: Array[StringName] = []
	_session.set("plan", none)
	_session.set("round_index", -1)
	_players[2].stop()
	await _settle(600)
	if with_screen:
		_check_screen_saw_the_game()
		_screen.queue_free()
		await _settle()
		_expect(_host._watch_link == null, "con pantalla: al cerrarse la pantalla, el anfitrión suelta su conexión")
	_host.close()
	await _settle()
	for link in _players:
		link.stop()
	return _heard.duplicate(true)


func _screen_comes_in() -> void:
	_screen = NetRoom.new()
	tree.root.add_child(_screen)
	_screen.watched.connect(func(message: Dictionary) -> void: _seen.append(message))
	_screen.state_received.connect(func(player_id: int, _state: Dictionary) -> void: _placed[player_id] = true)
	_expect(_screen.watch("127.0.0.1"), "con pantalla: la pantalla se conecta")
	await _settle()
	var pictures := _kinds_seen("snapshot")
	_expect(pictures.size() == 1 and (pictures[0]["room"] as Array).size() == 4 and _screen.room.size() == 4 and _host.room.size() == 4,
		"la pantalla entra y recibe la foto de la sala con los 4 jugadores, sin ocupar un puesto (sala de %d)" % _host.room.size())
	var second := NetLink.connecting("127.0.0.1", NetProtocol.PORT)
	second.start()
	second.send({"t": "hello", "v": NetProtocol.VERSION, "role": "watch"})
	var other := NetLink.connecting("127.0.0.1", NetProtocol.PORT)
	other.start()
	other.send({"t": "hello", "v": NetProtocol.VERSION + 98, "role": "watch"})
	await _settle()
	var answer := second.take().filter(func(message: Dictionary) -> bool: return message["t"] != "ping")
	var old := other.take().filter(func(message: Dictionary) -> bool: return message["t"] != "ping")
	second.stop()
	other.stop()
	_expect(answer.size() == 1 and answer[0]["t"] == "reject" and str(answer[0]["reason"]) == "Ya hay una pantalla de feria mirando esta sala",
		"una segunda pantalla recibe «%s»" % (str(answer[0].get("reason", "")) if not answer.is_empty() else "nada"))
	_expect(old.size() == 1 and old[0]["t"] == "reject" and str(old[0]["reason"]) == "La sala usa otra versión del juego",
		"una pantalla de otra versión se rechaza por la versión")
	await _settle()
	_expect(_screen.role == NetRoom.Role.WATCH and _host._watch_link != null and _host.room.size() == 4,
		"la primera pantalla sigue conectada después de los rechazos y la sala sigue con 4")


#A second screen that acts like a player counts for nothing; the first one comes back
func _screen_tries_to_play() -> void:
	_screen.set_ready(false)
	_screen.vote()
	_screen.report_points(0, 999)
	_screen.close()
	await _settle()
	_expect(_host._watch_link == null, "la pantalla se va con «bye» y el anfitrión suelta su conexión")
	var rogue := NetLink.connecting("127.0.0.1", NetProtocol.PORT)
	rogue.start()
	rogue.send({"t": "hello", "v": NetProtocol.VERSION, "role": "watch"})
	await _settle()
	for message: Dictionary in [{"t": "ready", "value": false}, {"t": "profile", "name": "PANTALLA", "character": "fire"}, {"t": "vote"},
			{"t": "loaded", "round": 0}, {"t": "points", "round": 0, "points": 900}, {"t": "st", "p": [1, 1, 1]}, {"t": "hit", "to": 2,
			"push": SHOVE_PUSH}, {"t": "hello", "v": NetProtocol.VERSION, "name": "INTRUSO"}]:
		rogue.send(message)
	await _settle()
	var everyone_ready := _host.room.all(func(member: Dictionary) -> bool: return bool(member["ready"]))
	var names := _host.room.map(func(member: Dictionary) -> String: return str(member["name"]))
	_expect(_host._watch_link != null and _host.room.size() == 4 and everyone_ready and not names.has("PANTALLA") and not names.has("INTRUSO")
		and _votes == 0 and _host._points.is_empty() and _host._loaded.is_empty(),
		"nada de lo que manda una pantalla cuenta: ni listo, ni nombre, ni voto, ni carga, ni puntos, ni posición, ni golpe, ni otro saludo")
	rogue.stop()
	await _settle()
	_expect(_host._watch_link == null, "una pantalla que se cae sin despedirse sale sin que nadie se entere")
	_expect(_screen.watch("127.0.0.1"), "la primera pantalla vuelve a conectarse")
	await _settle()
	_expect(_kinds_seen("snapshot").size() == 2 and _screen.room.size() == 4, "al volver recibe otra foto de la sala")


#The screen link dies mid round, returns and catches up
func _screen_drops_in_round() -> void:
	_screen._host_link.stop()
	await _settle()
	_expect(_host._watch_link == null and _screen.role == NetRoom.Role.OFFLINE, "la pantalla se cae a mitad de la ronda y el anfitrión la suelta")
	_expect(_screen.watch("127.0.0.1"), "la pantalla vuelve a mitad de la ronda")
	await _settle()
	var pictures := _kinds_seen("snapshot")
	var last: Dictionary = pictures[-1] if not pictures.is_empty() else {}
	_expect(pictures.size() == 3 and int(last.get("go", -1)) == 0 and bool(last.get("started", false)) and _screen.go_round == 0,
		"al volver sabe que la partida empezó y que la ronda 1 está en juego")


func _check_screen_saw_the_game() -> void:
	var kinds: Dictionary = {}
	for message in _seen:
		kinds[message["t"]] = int(kinds.get(message["t"], 0)) + 1
	print("      la pantalla recibió: ", kinds)
	for kind in ["snapshot", "room", "warmup", "warm", "start", "go", "sts", "struck", "done", "scores", "final", "advance", "left"]:
		if not kinds.has(kind):
			_expect(false, "la pantalla recibe «%s»" % kind)
	_expect(not kinds.has("st") and not kinds.has("hit") and not kinds.has("welcome"),
		"la pantalla no recibe las posiciones una a una, ni golpes para aplicar, ni bienvenida de jugador")
	_expect(_placed.has(1) and _placed.has(2) and _placed.has(3) and _placed.has(4), "las posiciones de los 4 jugadores llegan a la pantalla (%s)" % str(_placed.keys()))
	var struck := _kinds_seen("struck").map(func(message: Dictionary) -> String: return "%d>%d" % [int(message["by"]), int(message["to"])])
	_expect(struck == ["2>4", "1>3"], "la pantalla ve los dos empujones con quién empuja a quién (%s)" % str(struck))
	var done := _kinds_seen("done").map(func(message: Dictionary) -> int: return int(message["id"]))
	_expect(done == [2, 3, 4, 1], "la pantalla ve terminar a cada jugador en su orden (%s)" % str(done))
	var scores := _kinds_seen("scores")
	var points: Dictionary = scores[0]["points"] if not scores.is_empty() else {}
	_expect(points.size() == 4 and int(points.get("1", 0)) == 800 and int(points.get("4", 0)) == 700, "la pantalla recibe el marcador de la ronda")
	var finals := _kinds_seen("final")
	var totals: Array = finals[0]["totals"] if not finals.is_empty() else []
	_expect(totals.size() == 4 and str((totals[0] as Dictionary).get("name", "")) == "ANFITRION", "la pantalla recibe el fin de la partida con los totales de los 4")
	#What the places cost: one message with all four against the four messages a player gets
	var together := NetProtocol.pack({"t": "sts", "s": {"1": {"p": [9.0, 0.5, 9.0], "r": 1.0, "m": false, "a": true, "po": true, "ps": 2},
		"2": {"p": [0.0, 0.5, 2.0], "r": 0.5, "m": true, "a": false, "po": false, "ps": 0}, "3": {"p": [1.0, 0.5, 2.0], "r": 0.5, "m": true,
		"a": false, "po": false, "ps": 0}, "4": {"p": [2.0, 0.5, 2.0], "r": 0.5, "m": true, "a": false, "po": false, "ps": 0}}}).size()
	var apart := 0
	for id in 4:
		apart += NetProtocol.pack({"p": [9.0, 0.5, 9.0], "r": 1.0, "m": false, "a": true, "po": true, "ps": 2, "t": "st", "id": id + 1}).size()
	print("      4 posiciones juntas: %d bytes en 1 mensaje; una a una: %d bytes en 4 mensajes" % [together, apart])


#A room closed mid game and reopened starts from nothing
func _check_room_again() -> void:
	var room := NetRoom.new()
	tree.root.add_child(room)
	var got: Array[Array] = []
	for game in 2:
		var opened := false
		for attempt in 10:
			opened = opened or room.host("ANFITRION", &"fire")
			if not opened:
				await _settle(300)
		var link := NetLink.connecting("127.0.0.1", NetProtocol.PORT)
		link.start()
		link.send({"t": "hello", "v": NetProtocol.VERSION, "name": "J2", "character": "water"})
		var heard: Array[String] = []
		await _settle()
		if game == 1:
			#Long enough for any old clock to run out
			for frame in 600:
				await tree.process_frame
			await _settle()
		room.begin_warmup()
		room.start_game(PLAN, SEEDS)
		link.send({"t": "loaded", "round": 0})
		await _settle()
		room.report_loaded(0)
		link.send({"t": "points", "round": 0, "points": 300})
		await _settle()
		room.report_points(0, 400)
		await _settle()
		#The game is left with the next round loading and its start waiting for the player
		room.report_loaded(1)
		for message in link.take():
			if message["t"] in ["go", "scores"]:
				heard.append("%s %s" % [message["t"], str(int(message.get("round", -9)))])
		got.append(heard)
		room.close()
		link.stop()
		await _settle()
	room.queue_free()
	_expect(got.size() == 2 and got[0] == ["go 0", "scores 0"] and got[1] == got[0],
		"una sala cerrada a mitad de partida y abierta otra vez empieza de cero: salida y marcador de la ronda 1, nada viejo (%s)" % str(got))


#Full room: one drops and returns, the next game without the one gone, screen announced
func _check_full_room() -> void:
	var room := NetRoom.new()
	tree.root.add_child(room)
	var opened := false
	for attempt in 10:
		opened = opened or room.host("ANFITRION", &"fire")
		if not opened:
			await _settle(300)
	var finder := NetRoom.new()
	tree.root.add_child(finder)
	finder.browse()
	var links: Array[NetLink] = []
	for shown_name in ["J2", "J3", "J4"]:
		links.append(_greet(shown_name))
	var screen := NetRoom.new()
	tree.root.add_child(screen)
	screen.watch("127.0.0.1")
	_expect(await _announced(finder, "screen", true), "el anuncio de la sala dice que ya tiene pantalla de feria")
	room.begin_warmup()
	room.start_game(PLAN, SEEDS)
	await _settle()
	links[2].stop()
	await _settle(1500)
	_expect(await _announced(finder, "gone", 1.0), "durante la partida el anuncio dice que hay un puesto para volver")
	var back := _greet("J4")
	await _settle()
	var answer := _answers(back)
	_expect(answer == ["welcome"] and room.room.size() == 4, "con la sala llena, el que se cayó vuelve a la partida con su nombre (%s)" % str(answer))
	back.stop()
	await _settle(1500)
	room.reopen()
	await _settle()
	var gone := room.room.filter(func(member: Dictionary) -> bool: return not bool(member.get("connected", true)))
	_expect(room.room.size() == 3 and gone.is_empty(), "jugar de nuevo deja fuera al que se fue y no volvió (sala de %d)" % room.room.size())
	room.set_ready(true)
	for index in 2:
		links[index].send({"t": "ready", "value": true})
	await _settle()
	_expect(bool(_session.get("lobby").call("all_ready")), "los tres que siguen marcan Listo y la partida nueva puede empezar")
	var newcomer := _greet("J5")
	await _settle()
	var extra := _greet("J6")
	await _settle(800)
	var newcomer_answer := _answers(newcomer)
	var extra_answer := _answers(extra)
	_expect(newcomer_answer == ["welcome"] and extra_answer == ["reject La sala está llena"] and room.room.size() == 4,
		"en la sala nueva entra un cuarto jugador y un quinto no (%s, %s)" % [str(newcomer_answer), str(extra_answer)])
	screen.close()
	_expect(await _announced(finder, "screen", false), "cuando la pantalla se va, el anuncio deja libre el puesto de la feria")
	for link: NetLink in [links[0], links[1], newcomer, extra]:
		link.stop()
	screen.queue_free()
	finder.stop_browsing()
	finder.queue_free()
	room.close()
	room.queue_free()
	await _settle()


#Server decisions reach players and screen; player requests reach only the server
func _check_round_events() -> void:
	var room := NetRoom.new()
	tree.root.add_child(room)
	var opened := false
	for attempt in 10:
		opened = opened or room.host("ANFITRION", &"fire")
		if not opened:
			await _settle(300)
	var player := _greet("J2")
	await _settle()
	room.begin_warmup()
	room.start_game(PLAN, SEEDS)
	player.send({"t": "loaded", "round": 0})
	await _settle()
	room.report_loaded(0)
	await _settle(1200)
	var screen := NetRoom.new()
	tree.root.add_child(screen)
	var heard_on_screen: Array[Dictionary] = []
	var heard_on_server: Array[Array] = []
	screen.round_event.connect(func(from: int, message: Dictionary) -> void: heard_on_screen.append({"from": from, "k": message.get("k")}))
	room.round_event.connect(func(from: int, message: Dictionary) -> void: heard_on_server.append([from, str(message.get("k", ""))]))
	screen.watch("127.0.0.1")
	await _settle()
	var since := (Time.get_ticks_msec() - screen.go_at) / 1000.0
	_expect(screen.go_round == 0 and since >= 1.2 and since < 3.0, "la pantalla que entra con la ronda en juego sabe hace cuánto salió (%.1f s)" % since)
	player.take()
	room.send_round_event({"k": "feed", "e": "warn"})
	player.send({"t": "rnd", "k": "claim", "id": 7, "r": 0})
	screen.send_round_event({"k": "claim", "id": 8})
	await _settle()
	var to_player := player.take().filter(func(message: Dictionary) -> bool: return message["t"] == "rnd")
	_expect(to_player.size() == 1 and str(to_player[0].get("k")) == "feed" and int(to_player[0].get("r", -1)) == GameSession.round_index,
		"lo que decide el servidor en la ronda llega al jugador con el número de la ronda")
	_expect(heard_on_screen.size() == 1 and int(heard_on_screen[0]["from"]) == 0, "y llega a la pantalla de feria")
	_expect(heard_on_server == [[2, "claim"]], "lo que pide un jugador llega solo al servidor, con su id; la pantalla no manda nada (%s)" % str(heard_on_server))
	player.stop()
	screen.queue_free()
	room.close()
	room.queue_free()
	await _settle()


#The server player is out first: results still wait for the players in the round
func _check_early_server() -> void:
	var room := NetRoom.new()
	tree.root.add_child(room)
	var opened := false
	for attempt in 10:
		opened = opened or room.host("ANFITRION", &"fire")
		if not opened:
			await _settle(300)
	var links: Array[NetLink] = [_greet("J2"), _greet("J3")]
	await _settle()
	var verdicts: Array[String] = []
	for game in 2:
		room.begin_warmup()
		room.start_game(PLAN, SEEDS)
		for link in links:
			link.send({"t": "loaded", "round": 0})
		await _settle()
		room.report_loaded(0)
		await _settle()
		for link in links:
			link.take()
		room.report_points(0, 120)
		await _settle()
		var early := false
		for link in links:
			for message in link.take():
				early = early or message["t"] == "scores"
		links[0].send({"t": "points", "round": 0, "points": 400})
		await _settle()
		var still_waiting := room._points_left >= 0.0
		links[1].send({"t": "points", "round": 0, "points": 500})
		await _settle()
		var published := false
		for message in links[0].take():
			published = published or (message["t"] == "scores" and (message.get("points") as Dictionary).size() == 3)
		verdicts.append("%s/%s/%s" % ["pronto" if early else "espera", "espera" if still_waiting else "pronto", "sale" if published else "no sale"])
		room.reopen()
		await _settle()
	_expect(verdicts == ["espera/espera/sale", "espera/espera/sale"],
		"los jugadores cargan antes que el servidor y el servidor pierde primero: el resultado espera a los que siguen jugando (%s)" % str(verdicts))
	for link in links:
		link.stop()
	room.close()
	room.queue_free()
	await _settle()


func _greet(shown_name: String) -> NetLink:
	var link := NetLink.connecting("127.0.0.1", NetProtocol.PORT)
	link.start()
	link.send({"t": "hello", "v": NetProtocol.VERSION, "name": shown_name, "character": "water"})
	return link


#What the room answered to a hello: "welcome" or "reject" with its reason
func _answers(link: NetLink) -> Array[String]:
	var seen: Array[String] = []
	for message in link.take():
		if message["t"] == "welcome":
			seen.append("welcome")
		elif message["t"] == "reject":
			seen.append("reject %s" % str(message.get("reason", "")))
	return seen


#Waits until the announcement of the room has that value in "key"
func _announced(finder: NetRoom, key: String, value: Variant) -> bool:
	var until := Time.get_ticks_msec() + FIND_MS
	while Time.get_ticks_msec() < until:
		await tree.process_frame
		for heard: String in finder.rooms:
			if (finder.rooms[heard] as Dictionary).get(key) == value:
				return true
	return false


#How the screen finds the room
func _check_finder() -> void:
	var path := "user://net_check_feria.cfg"
	var cases := {"192.168.1.10": "192.168.1.10", "[feria]\nip_anfitrion=\"10.0.0.5\"\n": "10.0.0.5",
		"# la ip del anfitrion\r\nip_anfitrion = 172.16.0.9 \r\n": "172.16.0.9", "ip_anfitrion=hola\n": "", "ÿ\u0001 {[ basura": "",
		"# ejemplo: ip_anfitrion = 10.1.1.1\nip_anfitrion = 10.0.0.7\n": "10.0.0.7", "; ip_anfitrion = 10.1.1.2\n": ""}
	var read: Array[String] = []
	for text: String in cases:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		read.append(NetWatch.read_config(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	read.append(NetWatch.read_config(path))
	_expect(read == ["192.168.1.10", "10.0.0.5", "172.16.0.9", "", "", "10.0.0.7", "", ""],
		"feria.cfg: la dirección sola o con «ip_anfitrion», con o sin comillas; los comentarios no cuentan; una dirección mala, basura o ningún archivo = ninguna (%s)" % str(read))
	var room := NetRoom.new()
	var finder := NetWatch.new()
	finder.net = room
	finder.config_address = "127.0.0.1"
	tree.root.add_child(room)
	tree.root.add_child(finder)
	var waits: Array[int] = []
	var pattern := RegEx.create_from_string("otro intento en (\\d+) s")
	var last := [""]
	finder.changed.connect(func() -> void:
		if finder.status != last[0]:
			last[0] = finder.status
			var found := pattern.search(finder.status)
			if found != null:
				waits.append(int(found.get_string(1))))
	var until := Time.get_ticks_msec() + WAITS_MS
	while waits.size() < 6 and Time.get_ticks_msec() < until:
		await tree.process_frame
	_expect(waits == [1, 2, 4, 8, 10, 10] and not finder.connected,
		"la pantalla arranca antes que el anfitrión y lo intenta sin parar, cada vez con más espera (%s s)" % str(waits))
	_expect(await _open_room(), "el anfitrión abre la sala después")
	until = Time.get_ticks_msec() + FIND_MS
	while not finder.connected and Time.get_ticks_msec() < until:
		await tree.process_frame
	_expect(finder.connected and finder.address == "127.0.0.1" and _host._watch_link != null and _host.room.size() == 1,
		"y la encuentra sola por feria.cfg en cuanto abre («%s»)" % finder.status)
	#Without feria.cfg: the announcement of the room on the network
	finder.config_address = ""
	room._host_link.stop()
	until = Time.get_ticks_msec() + FIND_MS
	await _settle()
	while not finder.connected and Time.get_ticks_msec() < until:
		await tree.process_frame
	var announced := finder.address
	_expect(finder.connected and announced != "127.0.0.1" and room.rooms.has(announced),
		"sin dirección en feria.cfg la encuentra por el anuncio de la red (%s)" % announced)
	#A wrong address in feria.cfg: the announcement covers for it
	finder.config_address = "10.255.255.1"
	room._host_link.stop()
	await _settle()
	until = Time.get_ticks_msec() + FIND_MS
	while not finder.connected and Time.get_ticks_msec() < until:
		await tree.process_frame
	_expect(finder.connected and finder.address == announced, "con una dirección equivocada en feria.cfg el anuncio la cubre («%s»)" % finder.status)
	finder.queue_free()
	room.queue_free()
	await _settle()
	_host.queue_free()
	await _settle()
