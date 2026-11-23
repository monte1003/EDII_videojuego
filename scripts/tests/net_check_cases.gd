extends RefCounted

#The cases of net_check.gd about the fair screen. They live apart because the game's autoloads (GameSession and its room) only exist
#once the test is running: a script passed with --script is compiled before them.
#A room with the host and three players is played twice with the same steps: without the screen, and with a screen that comes in, sees a
#second one turned away, leaves, is replaced by one that sends what it must not, comes back and drops in the middle of a round. Both
#times the players must get exactly the same messages in the same order, and the start of the round and the points must not wait for the
#screen, which must get the whole picture of the game. Then how the screen finds the room: feria.cfg, a wait that grows while there is
#no room, the room it finds when the host opens after it, the network announcement and one source covering for the other

const SETTLE_MS := 250
#Real-time limits: with --fixed-fps the frames go much faster than the sockets. Each try at a closed port takes Windows a couple of seconds
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
	await _check_finder()
	return _failures


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


#Waits in real time while the players' messages come in
func _settle(ms := SETTLE_MS) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		_listen()
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


#A fresh room for the host each time, as in a game just opened (a room closed and opened again keeps the points of its last round)
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


#One game of the room, step by step (one sender per step, so the order of everything is fixed); with the screen in between when asked
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


#The screen leaves cleanly; another one comes in and sends everything a player would send: none of it counts. It drops without a word
#and the first one comes back
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


#In the middle of the round the screen's link dies without a goodbye; it comes back and catches up with the round under way
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


#How the screen finds the room
func _check_finder() -> void:
	var path := "user://net_check_feria.cfg"
	var cases := {"192.168.1.10": "192.168.1.10", "[feria]\nip_anfitrion=\"10.0.0.5\"\n": "10.0.0.5",
		"# la ip del anfitrion\r\nip_anfitrion = 172.16.0.9 \r\n": "172.16.0.9", "ip_anfitrion=hola\n": "", "ÿ\u0001 {[ basura": ""}
	var read: Array[String] = []
	for text: String in cases:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		read.append(NetWatch.read_config(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	read.append(NetWatch.read_config(path))
	_expect(read == ["192.168.1.10", "10.0.0.5", "172.16.0.9", "", "", ""],
		"feria.cfg: la dirección sola o con «ip_anfitrion», con o sin comillas; una dirección mala, basura o ningún archivo = ninguna (%s)" % str(read))
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
