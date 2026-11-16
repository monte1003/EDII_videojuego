class_name NetRoom
extends Node

#The game on the local network, client-server over sockets. One computer opens a room (the server, which also plays) and up to three more
#join it. Threads: the server has one that accepts connections and one that announces the room by UDP; every connection has its own
#thread (NetLink). Those threads only move bytes into queues behind a Mutex; this node, on the main thread, is the only one that reads the
#queues and changes the game, in one place (_apply), and it tells the rest with signals. The server decides the room, the order of the
#rounds, their seeds, when each round starts and the points of everybody; each computer moves its own player and sends where it is

enum Role { OFFLINE, HOST, CLIENT }

signal room_changed
signal joined
signal left(reason: String)
signal rooms_found
signal state_received(player_id: int, state: Dictionary)
signal hit_received(state: Dictionary)
signal round_go
#The server: somebody voted to start in the warm-up. A client: the clock and the votes of the warm-up as the server has them
signal vote_received(player_id: int)
signal warm_received(seconds_left: float, votes: int, total: int)

const CAPACITY := 4
#A computer that says nothing for this long is gone
const SILENCE_LIMIT := 3000
const PING_EVERY := 1.0
const ANNOUNCE_EVERY := 1000
#How long the server waits for everybody at the start of a round and for the points at its end
const GO_WAIT := 6.0
#Players finish a round at different times (the others watch meanwhile); this only guards against a computer that never answers
const POINTS_WAIT := 300.0

var role := Role.OFFLINE
#Everybody in the room: {"id", "name", "character", "ready"}, in the order they came in
var room: Array[Dictionary] = []
#Rooms announced on the network: address -> {"name", "players", "seen"}
var rooms: Dictionary = {}
var started := false
#The last round every computer was let go in
var go_round := -1

var _server: TCPServer
var _links: Array[NetLink] = []
var _host_link: NetLink
var _next_id := 2
var _accept_thread: Thread
var _announce_thread: Thread
var _listen_thread: Thread
var _threads_on := false
var _listening := false
var _mutex := Mutex.new()
var _accepted: Array[StreamPeerTCP] = []
var _heard_rooms: Array[Dictionary] = []
var _ping_left := PING_EVERY
#Server: who has loaded the round, the seconds left to wait for them and the points of the round that came in
var _loaded: Dictionary = {}
var _wait_round := -1
var _go_left := -1.0
var _points: Dictionary = {}
var _points_left := -1.0
var _points_round := -1


func is_active() -> bool:
	return role != Role.OFFLINE


func is_host() -> bool:
	return role == Role.HOST


#Opens a room on this computer; the one who opens it is player 1
func host(shown_name: String, character: StringName) -> bool:
	close()
	_server = TCPServer.new()
	if _server.listen(NetProtocol.PORT) != OK:
		_server = null
		return false
	role = Role.HOST
	started = false
	_next_id = 2
	room = [{"id": 1, "name": shown_name, "character": String(character), "ready": false}]
	GameSession.local_id = 1
	_start_threads()
	_publish_room()
	return true


#Connects to the room at "address"; "joined" or "left" say how it went
func join(address: String, shown_name: String, character: StringName) -> bool:
	close()
	if not address.is_valid_ip_address():
		return false
	role = Role.CLIENT
	started = false
	_host_link = NetLink.connecting(address, NetProtocol.PORT)
	if _host_link.is_closed():
		role = Role.OFFLINE
		_host_link = null
		return false
	_host_link.start()
	_host_link.send({"t": "hello", "v": NetProtocol.VERSION, "name": shown_name, "character": String(character)})
	return true


#Leaves the room, stops every thread and waits for each one before going on
func close() -> void:
	if role == Role.CLIENT and _host_link != null and _host_link.is_open():
		_host_link.send({"t": "bye"})
		OS.delay_msec(30)
	elif role == Role.HOST and not _links.is_empty():
		_send_all({"t": "bye"})
		OS.delay_msec(30)
	_threads_on = false
	for thread: Thread in [_accept_thread, _announce_thread]:
		if thread != null and thread.is_started():
			thread.wait_to_finish()
	_accept_thread = null
	_announce_thread = null
	for link in _links:
		link.stop()
	_links.clear()
	if _host_link != null:
		_host_link.stop()
		_host_link = null
	if _server != null:
		_server.stop()
		_server = null
	role = Role.OFFLINE
	room.clear()
	started = false
	go_round = -1
	_wait_round = -1
	GameSession.local_id = GameState.PLAYER_ONE
	room_changed.emit()


#A new game in the same room: nobody is ready and anybody can still come in
func reopen() -> void:
	if role != Role.HOST:
		return
	started = false
	go_round = -1
	_wait_round = -1
	for member in room:
		member["ready"] = false
	_publish_room()


#Starts listening for rooms announced on the network
func browse() -> void:
	stop_browsing()
	rooms.clear()
	_listen_thread = Thread.new()
	_listening = true
	_listen_thread.start(_listen_loop)


func stop_browsing() -> void:
	_listening = false
	if _listen_thread != null and _listen_thread.is_started():
		_listen_thread.wait_to_finish()
	_listen_thread = null


#The IPv4 addresses of this computer on a local network, to tell the others where the room is
func local_addresses() -> Array[String]:
	var found: Array[String] = []
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or (address.begins_with("172.") and int(address.split(".")[1]) in range(16, 32)):
			found.append(address)
	return found


func set_ready(value: bool) -> void:
	if role == Role.HOST:
		_change_member(1, {"ready": value})
	elif role == Role.CLIENT:
		_host_link.send({"t": "ready", "value": value})


func set_profile(shown_name: String, character: StringName) -> void:
	if role == Role.HOST:
		_change_member(1, {"name": shown_name, "character": String(character)})
	elif role == Role.CLIENT and _host_link != null:
		_host_link.send({"t": "profile", "name": shown_name, "character": String(character)})


#The server starts the game: the order of the rounds and a seed for each, the same on every computer
func start_game(plan: Array[StringName], seeds: Array[int]) -> void:
	if role != Role.HOST:
		return
	started = true
	var ids: Array[String] = []
	for id in plan:
		ids.append(String(id))
	_send_all({"t": "start", "plan": ids, "seeds": seeds})


#Every computer says when its round is loaded and its opening film is over; the server lets all of them go together (or after GO_WAIT
#seconds without the late ones, who then go as soon as they arrive)
func report_loaded(round_index: int) -> void:
	if role == Role.HOST:
		_wait_round = round_index
		_loaded[1] = true
		_go_left = GO_WAIT
		_check_go()
	elif role == Role.CLIENT:
		_host_link.send({"t": "loaded", "round": round_index})


func send_state(state: Dictionary) -> void:
	state["t"] = "st"
	state["id"] = GameSession.local_id
	if role == Role.HOST:
		_send_all(state)
	elif role == Role.CLIENT:
		_host_link.send(state)


#A blow to a player of another computer; the server takes it there
func send_hit(state: Dictionary) -> void:
	state["t"] = "hit"
	if role == Role.HOST:
		_deliver_hit(state)
	elif role == Role.CLIENT:
		_host_link.send(state)


#The points of this computer for a round; the server gathers everybody's and sends them back to all
func report_points(round_index: int, points: int) -> void:
	if role == Role.HOST:
		_gather_points(round_index, 1, points)
	elif role == Role.CLIENT:
		_host_link.send({"t": "points", "round": round_index, "points": points})


#The server sends everybody to the warm-up once they are all ready in the lobby
func begin_warmup() -> void:
	if role == Role.HOST:
		started = true
		_send_all({"t": "warmup"})


#A vote to start from the warm-up: the server counts it there
func vote() -> void:
	if role == Role.HOST:
		vote_received.emit(1)
	elif role == Role.CLIENT:
		_host_link.send({"t": "vote"})


#The server tells everybody how long the warm-up has left and how many voted
func send_warm(seconds_left: float, votes: int, total: int) -> void:
	_send_all({"t": "warm", "left": snappedf(seconds_left, 0.01), "votes": votes, "total": total})


#Whoever comes in wears the first character nobody is wearing (with all of them taken, the first one in another colour)
func _free_character() -> StringName:
	for id in GameSession.CHARACTER_IDS:
		var taken := false
		for member in room:
			taken = taken or str(member.get("character", "")) == String(id)
		if not taken:
			return id
	return GameSession.CHARACTER_IDS[0]


#The server moves everybody on from the results of a round
func advance_all() -> void:
	if role == Role.HOST:
		_send_all({"t": "advance"})


func _process(delta: float) -> void:
	if role == Role.HOST:
		_adopt_connections()
		for link in _links.duplicate():
			for message in link.take():
				_apply_from_client(link, message)
			if link.is_closed() or Time.get_ticks_msec() - link.last_heard > SILENCE_LIMIT:
				_drop(link)
		_tick_waits(delta)
	elif role == Role.CLIENT and _host_link != null:
		for message in _host_link.take():
			_apply_from_host(message)
		if role == Role.CLIENT and (_host_link.is_closed() or Time.get_ticks_msec() - _host_link.last_heard > SILENCE_LIMIT):
			_lose_host("Se perdió la conexión con la sala")
	_ping_left -= delta
	if _ping_left <= 0.0 and role != Role.OFFLINE:
		_ping_left = PING_EVERY
		if role == Role.HOST:
			_send_all({"t": "ping"})
		elif _host_link != null:
			_host_link.send({"t": "ping"})
	_collect_rooms()


func _exit_tree() -> void:
	stop_browsing()
	close()


func _start_threads() -> void:
	_threads_on = true
	_accept_thread = Thread.new()
	_accept_thread.start(_accept_loop)
	_announce_thread = Thread.new()
	_announce_thread.start(_announce_loop)


#Thread of the server: takes every new connection and leaves it in a queue for the main thread
func _accept_loop() -> void:
	while _threads_on:
		if _server.is_connection_available():
			var peer := _server.take_connection()
			_mutex.lock()
			_accepted.append(peer)
			_mutex.unlock()
		OS.delay_msec(20)


#Thread of the server: says once a second on the local network that the room is open
func _announce_loop() -> void:
	var udp := PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	udp.set_dest_address("255.255.255.255", NetProtocol.DISCOVERY_PORT)
	var last := 0
	while _threads_on:
		if Time.get_ticks_msec() - last >= ANNOUNCE_EVERY:
			last = Time.get_ticks_msec()
			_mutex.lock()
			var info := {"game": NetProtocol.GAME, "v": NetProtocol.VERSION, "name": String(room[0]["name"]) if not room.is_empty() else "", "players": room.size(), "open": not started}
			_mutex.unlock()
			udp.put_packet(JSON.stringify(info).to_utf8_buffer())
		OS.delay_msec(50)
	udp.close()


#Thread of who looks for rooms: listens to the announcements and leaves them in a queue
func _listen_loop() -> void:
	var udp := PacketPeerUDP.new()
	if udp.bind(NetProtocol.DISCOVERY_PORT) != OK:
		return
	while _listening:
		while udp.get_available_packet_count() > 0:
			var bytes := udp.get_packet()
			var address := udp.get_packet_ip()
			var parsed: Variant = NetProtocol.parse(bytes.get_string_from_utf8())
			if parsed is Dictionary and (parsed as Dictionary).get("game") == NetProtocol.GAME:
				var info: Dictionary = parsed
				info["address"] = address
				_mutex.lock()
				_heard_rooms.append(info)
				_mutex.unlock()
		OS.delay_msec(50)
	udp.close()


func _collect_rooms() -> void:
	_mutex.lock()
	var heard := _heard_rooms.duplicate()
	_heard_rooms.clear()
	_mutex.unlock()
	var now := Time.get_ticks_msec()
	var changed := not heard.is_empty()
	for info: Dictionary in heard:
		info["seen"] = now
		rooms[info["address"]] = info
	for address: String in rooms.keys():
		if now - int(rooms[address]["seen"]) > 3500:
			rooms.erase(address)
			changed = true
	if changed:
		rooms_found.emit()


func _adopt_connections() -> void:
	_mutex.lock()
	var fresh := _accepted.duplicate()
	_accepted.clear()
	_mutex.unlock()
	for peer: StreamPeerTCP in fresh:
		var link := NetLink.accepted(peer)
		_links.append(link)
		link.start()


#Every message from a client goes through here, on the main thread; anything out of place is ignored
func _apply_from_client(link: NetLink, message: Dictionary) -> void:
	var kind: String = message["t"]
	if link.id == 0:
		if kind != "hello":
			return
		var reason := ""
		if int(message.get("v", 0)) != NetProtocol.VERSION:
			reason = "La sala usa otra versión del juego"
		elif started:
			reason = "La partida ya empezó"
		elif room.size() >= CAPACITY:
			reason = "La sala está llena"
		if reason != "":
			link.send({"t": "reject", "reason": reason})
			return
		link.id = _next_id
		_next_id += 1
		_mutex.lock()
		room.append({"id": link.id, "name": _clean_name(message.get("name")), "character": String(_free_character()), "ready": false})
		_mutex.unlock()
		link.send({"t": "welcome", "id": link.id})
		_publish_room()
		return
	match kind:
		"ready":
			_change_member(link.id, {"ready": bool(message.get("value", false))})
		"profile":
			_change_member(link.id, {"name": _clean_name(message.get("name")), "character": _clean_character(message.get("character"))})
		"loaded":
			if int(message.get("round", -1)) <= go_round:
				link.send({"t": "go", "round": go_round})
			else:
				_loaded[link.id] = true
				_check_go()
		"st":
			message["id"] = link.id
			_send_all(message, link)
			state_received.emit(link.id, message)
		"hit":
			_deliver_hit(message)
		"points":
			_gather_points(int(message.get("round", -1)), link.id, int(message.get("points", 0)))
		"vote":
			vote_received.emit(link.id)
		"ping":
			link.send({"t": "pong"})
		"bye":
			_drop(link)


func _apply_from_host(message: Dictionary) -> void:
	match String(message["t"]):
		"welcome":
			GameSession.local_id = int(message.get("id", 0))
			joined.emit()
		"reject":
			_lose_host(String(message.get("reason", "La sala no te dejó entrar")))
		"room":
			var members: Array[Dictionary] = []
			for entry: Variant in message.get("members", []):
				if entry is Dictionary:
					members.append(entry)
			room = members
			GameSession.sync_lobby(room)
			room_changed.emit()
		"start":
			var plan: Array[StringName] = []
			for id: Variant in message.get("plan", []):
				plan.append(StringName(str(id)))
			var seeds: Array[int] = []
			for value: Variant in message.get("seeds", []):
				seeds.append(int(value))
			started = true
			GameSession.begin_networked(plan, seeds)
		"go":
			go_round = maxi(go_round, int(message.get("round", -1)))
			round_go.emit()
		"st":
			state_received.emit(int(message.get("id", 0)), message)
		"hit":
			hit_received.emit(message)
		"scores":
			GameSession.apply_round_points(int(message.get("round", -1)), _read_points(message.get("points", {})))
		"advance":
			GameSession.advance_now()
		"warmup":
			started = true
			GameSession.enter_warmup()
		"warm":
			warm_received.emit(float(message.get("left", 0.0)), int(message.get("votes", 0)), int(message.get("total", 1)))
		"ping":
			_host_link.send({"t": "pong"})
		"bye":
			_lose_host("La sala se cerró")


func _change_member(player_id: int, changes: Dictionary) -> void:
	for member in room:
		if int(member["id"]) == player_id:
			_mutex.lock()
			member.merge(changes, true)
			_mutex.unlock()
	_publish_room()


#The server tells everybody who is in the room and copies it into the lobby of its own game
func _publish_room() -> void:
	_send_all({"t": "room", "members": room})
	GameSession.sync_lobby(room)
	room_changed.emit()


func _send_all(message: Dictionary, except: NetLink = null) -> void:
	for link in _links:
		if link.id != 0 and link != except:
			link.send(message)


func _deliver_hit(message: Dictionary) -> void:
	var target := int(message.get("to", 0))
	if target == GameSession.local_id:
		hit_received.emit(message)
		return
	for link in _links:
		if link.id == target:
			link.send(message)


#A client that left or went silent: out of the room before the game, frozen and with no points during it
func _drop(link: NetLink) -> void:
	link.stop()
	_links.erase(link)
	if link.id == 0:
		return
	_loaded.erase(link.id)
	if not started:
		_mutex.lock()
		for member in room.duplicate():
			if int(member["id"]) == link.id:
				room.erase(member)
		_mutex.unlock()
		_publish_room()
	else:
		_check_go()
		_check_points()


func _lose_host(reason: String) -> void:
	close()
	left.emit(reason)


func _tick_waits(delta: float) -> void:
	if _go_left >= 0.0:
		_go_left -= delta
		if _go_left <= 0.0:
			_release_go()
	if _points_left >= 0.0:
		_points_left -= delta
		if _points_left <= 0.0:
			_publish_points()


func _check_go() -> void:
	if _wait_round <= go_round:
		return
	for link in _links:
		if link.id != 0 and not _loaded.has(link.id):
			return
	if _loaded.has(1):
		_release_go()


func _release_go() -> void:
	_go_left = -1.0
	_loaded.clear()
	go_round = _wait_round
	_send_all({"t": "go", "round": go_round})
	round_go.emit()


func _gather_points(round_index: int, player_id: int, points: int) -> void:
	if round_index < 0:
		return
	if round_index != _points_round:
		_points_round = round_index
		_points.clear()
		_points_left = POINTS_WAIT
	_points[player_id] = clampi(points, 0, ScoreSheet.MAX_POINTS)
	_check_points()


func _check_points() -> void:
	if _points_round < 0 or _points_left < 0.0:
		return
	for member in room:
		var id := int(member["id"])
		var here := id == 1
		for link in _links:
			here = here or link.id == id
		if here and not _points.has(id):
			return
	_publish_points()


func _publish_points() -> void:
	_points_left = -1.0
	for member in room:
		if not _points.has(int(member["id"])):
			_points[int(member["id"])] = 0
	var shared: Dictionary = {}
	for id: int in _points:
		shared[str(id)] = _points[id]
	_send_all({"t": "scores", "round": _points_round, "points": shared})
	GameSession.apply_round_points(_points_round, _points.duplicate())


func _read_points(raw: Variant) -> Dictionary:
	var points: Dictionary = {}
	if raw is Dictionary:
		for key: Variant in raw:
			points[int(str(key))] = clampi(int(raw[key]), 0, ScoreSheet.MAX_POINTS)
	return points


func _clean_name(value: Variant) -> String:
	var text := str(value).strip_edges().left(GameState.MAX_NAME_LENGTH) if value != null else ""
	return text if text != "" else "JUGADOR"


func _clean_character(value: Variant) -> String:
	var id := str(value) if value != null else ""
	return id if ResourceLoader.exists("res://resources/characters/%s.tres" % id) else "fire"
