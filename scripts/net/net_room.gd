class_name NetRoom
extends Node

#Local network game, client-server over TCP; threads only move bytes, the main thread applies changes

enum Role { OFFLINE, HOST, CLIENT, WATCH }

signal room_changed
signal joined
signal left(reason: String)
signal rooms_found
signal state_received(player_id: int, state: Dictionary)
signal hit_received(state: Dictionary)
signal round_go
#A player lost its connection mid game: it hides on every screen
signal player_left(player_id: int)
#Server: a warm-up vote. Client: the warm-up clock and votes
signal vote_received(player_id: int)
signal warm_received(seconds_left: float, votes: int, total: int)
#Fair screen: every game message, to keep its own picture
signal watched(message: Dictionary)
#Round decisions: server to players ("from" 0), player to server (its id)
signal round_event(from: int, message: Dictionary)

const CAPACITY := 4
#Silence that means a computer is gone; tolerates a stuttering Wi-Fi
const SILENCE_LIMIT := 12000
const ANNOUNCE_EVERY := 1000
#Wait for everybody at round start and for points at the end
const GO_WAIT := 15.0
#Guards only against a computer that never sends its points
const POINTS_WAIT := 300.0
#How often the fair screen gets every position in one message
const WATCH_EVERY := 0.05
#A screen silent this long yields its place to a new one
const WATCH_STALE := 3000

var role := Role.OFFLINE
#{"id", "name", "character", "ready"} in arrival order
var room: Array[Dictionary] = []
#Announced rooms: address -> {"name", "players", "seen"}
var rooms: Dictionary = {}
var started := false
#Last round released and when (ms), so the fair screen catches up
var go_round := -1
var go_at := 0

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
#Server: who loaded the round, the wait left and the points received
var _loaded: Dictionary = {}
var _wait_round := -1
#Players of the round under way, kept per round so an early loader is not lost
var _round_members: Dictionary = {}
var _members_round := -1
var _go_left := -1.0
var _points: Dictionary = {}
var _points_left := -1.0
var _points_round := -1
#Server: the fair screen link, kept apart from the players' links
var _watch_link: NetLink
#Server: last state of each player and the time to the next screen message
var _watch_states: Dictionary = {}
var _watch_left := 0.0
#Server: a screen is watching, said in the announcement (read by its thread)
var _screen_on := false


func is_active() -> bool:
	return role != Role.OFFLINE


func is_host() -> bool:
	return role == Role.HOST


#Opens a room here; its creator is player 1
func host(shown_name: String, character: StringName) -> bool:
	close()
	_server = TCPServer.new()
	if _server.listen(NetProtocol.PORT) != OK:
		_server = null
		return false
	role = Role.HOST
	started = false
	_next_id = 2
	room = [{"id": 1, "name": shown_name, "character": String(character), "ready": false, "connected": true}]
	GameSession.local_id = 1
	_start_threads()
	_publish_room()
	return true


#Connects to the room at "address"; "joined" or "left" report the result
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


#Fair screen watches the room at "address"; "joined" or "left" report the result
func watch(address: String) -> bool:
	close()
	if not address.is_valid_ip_address():
		return false
	role = Role.WATCH
	_host_link = NetLink.connecting(address, NetProtocol.PORT)
	if _host_link.is_closed():
		role = Role.OFFLINE
		_host_link = null
		return false
	_host_link.start()
	_host_link.send({"t": "hello", "v": NetProtocol.VERSION, "role": "watch"})
	return true


#Messages and bytes exchanged with the server
func traffic() -> Dictionary:
	return _host_link.traffic() if _host_link != null else {}


#Leaves the room and waits for every thread to stop
func close() -> void:
	if (role == Role.CLIENT or role == Role.WATCH) and _host_link != null and _host_link.is_open():
		_host_link.send({"t": "bye"})
		OS.delay_msec(30)
	elif role == Role.HOST and (not _links.is_empty() or _watch_link != null):
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
	if _watch_link != null:
		_watch_link.stop()
		_watch_link = null
	_watch_states = {}
	_screen_on = false
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
	go_at = 0
	_wait_round = -1
	#Nothing of the last game reaches the next room
	_go_left = -1.0
	_loaded.clear()
	_round_members.clear()
	_members_round = -1
	_points.clear()
	_points_left = -1.0
	_points_round = -1
	GameSession.local_id = GameState.PLAYER_ONE
	room_changed.emit()


#New game in the same room: nobody ready, dropped places freed
func reopen() -> void:
	if role != Role.HOST:
		return
	started = false
	go_round = -1
	_wait_round = -1
	_mutex.lock()
	for member in room.duplicate():
		if not bool(member.get("connected", true)):
			room.erase(member)
	_mutex.unlock()
	for member in room:
		member["ready"] = false
	_publish_room()
	_tell_watcher(_snapshot())


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


#IPv4 addresses of this computer, to tell the others
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


#Server starts the game: round order and seeds, the same everywhere
func start_game(plan: Array[StringName], seeds: Array[int]) -> void:
	if role != Role.HOST:
		return
	started = true
	var ids: Array[String] = []
	for id in plan:
		ids.append(String(id))
	_send_all({"t": "start", "plan": ids, "seeds": seeds})


#Each computer reports its round loaded; the server releases all together or after GO_WAIT
func report_loaded(round_index: int) -> void:
	if role == Role.HOST:
		_wait_round = round_index
		_join_round(round_index, 1)
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
		_note_state(GameSession.local_id, state)
	elif role == Role.CLIENT:
		_host_link.send(state)


#A blow to a player of another computer, through the server
func send_hit(state: Dictionary) -> void:
	state["t"] = "hit"
	if role == Role.HOST:
		_show_hit(GameSession.local_id, state)
		_deliver_hit(state)
	elif role == Role.CLIENT:
		_host_link.send(state)


#This computer's round points; the server sends everybody's back
func report_points(round_index: int, points: int) -> void:
	if role == Role.HOST:
		_gather_points(round_index, 1, points)
	elif role == Role.CLIENT:
		_host_link.send({"t": "points", "round": round_index, "points": points})


#Server sends everybody to the warm-up once all are ready
func begin_warmup() -> void:
	if role == Role.HOST:
		started = true
		#A new game counts rounds from 0 again
		_round_members.clear()
		_members_round = -1
		_points.clear()
		_points_round = -1
		_points_left = -1.0
		_send_all({"t": "warmup"})


func vote() -> void:
	if role == Role.HOST:
		vote_received.emit(1)
	elif role == Role.CLIENT:
		_host_link.send({"t": "vote"})


#Server sends the warm-up time left and the votes
func send_warm(seconds_left: float, votes: int, total: int) -> void:
	_send_all({"t": "warm", "left": snappedf(seconds_left, 0.01), "votes": votes, "total": total})


#Round events: server to everybody, player to server; tagged with the round
func send_round_event(message: Dictionary) -> void:
	message["t"] = "rnd"
	message["r"] = GameSession.round_index
	if role == Role.HOST:
		_send_all(message)
	elif role == Role.CLIENT:
		_host_link.send(message)


#Returning player: same name, or the only one gone
func _returning_member(shown_name: String) -> Dictionary:
	if not started:
		return {}
	var gone: Array[Dictionary] = []
	for member in room:
		if not bool(member.get("connected", true)):
			gone.append(member)
			if str(member.get("name", "")).to_lower() == shown_name.strip_edges().to_lower():
				return member
	return gone[0] if gone.size() == 1 else {}


#The player takes its place back with the game as it is; plays from the next round
func _take_back(link: NetLink, member: Dictionary) -> void:
	link.id = int(member["id"])
	link.send({"t": "welcome", "id": link.id})
	var order: Array[String] = []
	for id in GameSession.plan:
		order.append(String(id))
	var table: Array[Dictionary] = []
	for result in GameSession.results:
		var shared: Dictionary = {}
		for id: int in result.points_by_player:
			shared[str(id)] = result.points_by_player[id]
		table.append(shared)
	link.send({"t": "rejoin", "plan": order, "seeds": GameSession.seeds, "round": GameSession.round_index, "table": table})
	#It sits out the round under way
	_round_members.erase(link.id)
	_change_member(link.id, {"connected": true, "waiting": true})
	_check_points()


#First free character, or the first one in another colour
func _free_character() -> StringName:
	for id in GameSession.CHARACTER_IDS:
		var taken := false
		for member in room:
			taken = taken or str(member.get("character", "")) == String(id)
		if not taken:
			return id
	return GameSession.CHARACTER_IDS[0]


func advance_all() -> void:
	if role != Role.HOST:
		return
	#Returning players play from this round on
	var changed := false
	for member in room:
		if bool(member.get("waiting", false)):
			member["waiting"] = false
			changed = true
	if changed:
		_publish_room()
	if GameSession.is_last_round():
		_tell_watcher(_final_message())
	_send_all({"t": "advance"})


func _process(delta: float) -> void:
	if role == Role.HOST:
		_adopt_connections()
		for link in _links.duplicate():
			for message in link.take():
				_apply_from_client(link, message)
			if link.is_closed() or link.heard_ago() > SILENCE_LIMIT:
				_drop(link)
		_tick_waits(delta)
		_tend_watcher(delta)
	elif role == Role.CLIENT and _host_link != null:
		for message in _host_link.take():
			_apply_from_host(message)
		if role == Role.CLIENT and (_host_link.is_closed() or _host_link.heard_ago() > SILENCE_LIMIT):
			_lose_host("Se perdió la conexión con la sala")
	elif role == Role.WATCH and _host_link != null:
		for message in _host_link.take():
			if role == Role.WATCH:
				_apply_watch(message)
		if role == Role.WATCH and (_host_link.is_closed() or _host_link.heard_ago() > SILENCE_LIMIT):
			_lose_host("No hay conexión con la sala")
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


#Server thread: queues every new connection for the main thread
func _accept_loop() -> void:
	while _threads_on:
		if _server.is_connection_available():
			var peer := _server.take_connection()
			_mutex.lock()
			_accepted.append(peer)
			_mutex.unlock()
		OS.delay_msec(20)


#Server thread: announces the room by UDP once a second
func _announce_loop() -> void:
	var udp := PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	udp.set_dest_address("255.255.255.255", NetProtocol.DISCOVERY_PORT)
	var last := 0
	while _threads_on:
		if Time.get_ticks_msec() - last >= ANNOUNCE_EVERY:
			last = Time.get_ticks_msec()
			_mutex.lock()
			#Places of dropped players, still theirs to take back
			var gone := 0
			for member in room:
				gone += 0 if bool(member.get("connected", true)) else 1
			var info := {"game": NetProtocol.GAME, "v": NetProtocol.VERSION, "name": String(room[0]["name"]) if not room.is_empty() else "", "players": room.size(), "open": not started,
				"screen": _screen_on, "gone": gone}
			_mutex.unlock()
			udp.put_packet(JSON.stringify(info).to_utf8_buffer())
		OS.delay_msec(50)
	udp.close()


#Browser thread: queues the room announcements
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


#Every client message on the main thread; anything out of place is ignored
func _apply_from_client(link: NetLink, message: Dictionary) -> void:
	var kind: String = message["t"]
	if link.id == 0:
		if kind != "hello":
			return
		if str(message.get("role", "")) == "watch":
			_take_watcher(link, message)
			return
		var reason := ""
		var returning := _returning_member(str(message.get("name", "")))
		if int(message.get("v", 0)) != NetProtocol.VERSION:
			reason = "La sala usa otra versión del juego"
		elif started and returning.is_empty():
			reason = "La partida ya empezó"
		elif returning.is_empty() and room.size() >= CAPACITY:
			reason = "La sala está llena"
		if reason != "":
			link.send({"t": "reject", "reason": reason})
			return
		if not returning.is_empty():
			_take_back(link, returning)
			return
		link.id = _next_id
		_next_id += 1
		_mutex.lock()
		room.append({"id": link.id, "name": _clean_name(message.get("name")), "character": String(_free_character()), "ready": false, "connected": true})
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
			_join_round(int(message.get("round", -1)), link.id)
			if int(message.get("round", -1)) <= go_round:
				link.send({"t": "go", "round": go_round})
			else:
				_loaded[link.id] = true
				_check_go()
		"st":
			message["id"] = link.id
			_send_all(message, link)
			state_received.emit(link.id, message)
			_note_state(link.id, message)
		"hit":
			_show_hit(link.id, message)
			_deliver_hit(message)
		"points":
			_gather_points(int(message.get("round", -1)), link.id, int(message.get("points", 0)))
		"vote":
			vote_received.emit(link.id)
		"rnd":
			round_event.emit(link.id, message)
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
			_take_go(int(message.get("round", -1)))
		"st":
			state_received.emit(int(message.get("id", 0)), message)
		"rnd":
			round_event.emit(0, message)
		"hit":
			hit_received.emit(message)
		"scores":
			GameSession.apply_round_points(int(message.get("round", -1)), _read_points(message.get("points", {})))
		"advance":
			GameSession.advance_now()
		"warmup":
			started = true
			#A new game: the last rounds no longer count as started
			go_round = -1
			GameSession.enter_warmup()
		"warm":
			warm_received.emit(float(message.get("left", 0.0)), int(message.get("votes", 0)), int(message.get("total", 1)))
		"left":
			player_left.emit(int(message.get("id", 0)))
		"rejoin":
			var order: Array[StringName] = []
			for id: Variant in message.get("plan", []):
				order.append(StringName(str(id)))
			var round_seeds: Array[int] = []
			for value: Variant in message.get("seeds", []):
				round_seeds.append(int(value))
			var table: Array[Dictionary] = []
			for points: Variant in message.get("table", []):
				table.append(_read_points(points))
			started = true
			GameSession.rejoin(order, round_seeds, int(message.get("round", -1)), table)
		"bye":
			_lose_host("La sala se cerró")


#Fair screen on the main thread: keeps the room, round starts and positions; never touches this game
func _apply_watch(message: Dictionary) -> void:
	match String(message["t"]):
		"snapshot":
			_read_room(message.get("room"))
			started = bool(message.get("started", false))
			go_round = int(message.get("go", -1))
			go_at = Time.get_ticks_msec() - int(_number(message.get("since")) * 1000.0)
			joined.emit()
		"welcome":
			#An old server took the screen for a player
			_lose_host("La sala es de una versión anterior y no acepta la pantalla de feria")
			return
		"reject":
			_lose_host(str(message.get("reason", "La sala no dejó entrar a la pantalla")))
			return
		"bye":
			_lose_host("La sala se cerró")
			return
		"room":
			_read_room(message.get("members"))
		"warmup":
			started = true
			go_round = -1
		"start":
			started = true
		"go":
			_take_go(int(message.get("round", -1)))
		"sts":
			var states: Variant = message.get("s")
			if states is Dictionary:
				for key: Variant in states:
					if states[key] is Dictionary:
						state_received.emit(int(str(key)), states[key])
		"left":
			player_left.emit(int(message.get("id", 0)))
		"warm":
			warm_received.emit(float(message.get("left", 0.0)), int(message.get("votes", 0)), int(message.get("total", 1)))
		"rnd":
			round_event.emit(0, message)
	watched.emit(message)


#A round released: keep the first moment
func _take_go(round_index: int) -> void:
	if round_index > go_round:
		go_at = Time.get_ticks_msec()
	go_round = maxi(go_round, round_index)
	round_go.emit()


func _read_room(raw: Variant) -> void:
	var members: Array[Dictionary] = []
	if raw is Array:
		for entry: Variant in raw:
			if entry is Dictionary:
				members.append(entry)
	room = members
	room_changed.emit()


func _change_member(player_id: int, changes: Dictionary) -> void:
	for member in room:
		if int(member["id"]) == player_id:
			_mutex.lock()
			member.merge(changes, true)
			_mutex.unlock()
	_publish_room()


#Server publishes the room and copies it into its own lobby
func _publish_room() -> void:
	_send_all({"t": "room", "members": room})
	GameSession.sync_lobby(room)
	room_changed.emit()


func _send_all(message: Dictionary, except: NetLink = null) -> void:
	for link in _links:
		if link.id != 0 and link != except:
			link.send(message)
	#The screen gets positions only in the combined "sts"
	if message["t"] != "st":
		_tell_watcher(message)


func _deliver_hit(message: Dictionary) -> void:
	var target := int(message.get("to", 0))
	if target == GameSession.local_id:
		hit_received.emit(message)
		return
	for link in _links:
		if link.id == target:
			link.send(message)


#A client left or went silent: out of the room before the game, frozen during it
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
		#During the game its place is kept for a return with the same name
		_change_member(link.id, {"connected": false})
		_send_all({"t": "left", "id": link.id})
		player_left.emit(link.id)
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
	go_at = Time.get_ticks_msec()
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
	_tell_watcher({"t": "done", "round": round_index, "id": player_id, "points": _points[player_id]})
	_check_points()


#Whoever loaded "round_index" plays it; a newer round restarts the list
func _join_round(round_index: int, player_id: int) -> void:
	if round_index > _members_round:
		_members_round = round_index
		_round_members.clear()
	if round_index == _members_round:
		_round_members[player_id] = true


func _check_points() -> void:
	if _points_round < 0 or _points_left < 0.0:
		return
	for member in room:
		var id := int(member["id"])
		var here := id == 1
		for link in _links:
			here = here or link.id == id
		var counted := _members_round == _points_round and not _round_members.is_empty()
		var playing := (not counted or _round_members.has(id)) and not bool(member.get("waiting", false))
		if here and playing and not _points.has(id):
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


#Server: a fair screen asks to watch; one at most, out of the players' links, with a snapshot
func _take_watcher(link: NetLink, message: Dictionary) -> void:
	if link == _watch_link:
		return
	var reason := ""
	if int(message.get("v", 0)) != NetProtocol.VERSION:
		reason = "La sala usa otra versión del juego"
	elif _watch_link != null and not _watch_link.is_closed() and _watch_link.heard_ago() <= WATCH_STALE:
		reason = "Ya hay una pantalla de feria mirando esta sala"
	if reason != "":
		link.send({"t": "reject", "reason": reason})
		return
	if _watch_link != null:
		_watch_link.stop()
	_links.erase(link)
	link.set_watcher()
	_watch_link = link
	_watch_states = {}
	_watch_left = 0.0
	_set_screen(true)
	link.send(_snapshot())


func _set_screen(value: bool) -> void:
	_mutex.lock()
	_screen_on = value
	_mutex.unlock()


#Everything a screen needs to join at any moment
func _snapshot() -> Dictionary:
	var order: Array[String] = []
	for id in GameSession.plan:
		order.append(String(id))
	var table: Array[Dictionary] = []
	for result in GameSession.results:
		var shared: Dictionary = {}
		for id: int in result.points_by_player:
			shared[str(id)] = result.points_by_player[id]
		table.append(shared)
	var phase := String(GameSession.Phase.keys()[GameSession.phase]).to_lower()
	return {"t": "snapshot", "room": room, "started": started, "phase": phase, "plan": order, "seeds": GameSession.seeds,
		"round": GameSession.round_index, "go": go_round, "since": (Time.get_ticks_msec() - go_at) / 1000.0 if go_round >= 0 else 0.0,
		"table": table}


#Server, every frame: sends the screen everybody's positions together
func _tend_watcher(delta: float) -> void:
	if _watch_link == null:
		return
	var leaving := false
	for message in _watch_link.take():
		leaving = leaving or message["t"] == "bye"
	if leaving or _watch_link.is_closed() or _watch_link.heard_ago() > SILENCE_LIMIT:
		_watch_link.stop()
		_watch_link = null
		_watch_states = {}
		_set_screen(false)
		return
	_watch_left -= delta
	if _watch_left <= 0.0 and not _watch_states.is_empty():
		_watch_left = WATCH_EVERY
		_watch_link.send({"t": "sts", "s": _watch_states})
		_watch_states = {}


#Server: rebuilds a player's state from known fields for the screen
func _note_state(player_id: int, state: Dictionary) -> void:
	var at: Variant = state.get("p")
	if _watch_link == null or not (at is Array and (at as Array).size() == 3):
		return
	_watch_states[str(player_id)] = {"p": [_number(at[0]), _number(at[1]), _number(at[2])], "r": _number(state.get("r")),
		"m": _flag(state.get("m")), "a": _flag(state.get("a")), "po": _flag(state.get("po")), "ps": int(_number(state.get("ps")))}


#Server: tells the screen about a shove (only the hit player applies it)
func _show_hit(by: int, message: Dictionary) -> void:
	_tell_watcher({"t": "struck", "by": by, "to": int(_number(message.get("to")))})


func _tell_watcher(message: Dictionary) -> void:
	if _watch_link != null:
		_watch_link.send(message)


#End of game for the screen: totals and best rounds as the server counted
func _final_message() -> Dictionary:
	var totals: Array[Dictionary] = []
	for member in room:
		var id := int(member["id"])
		totals.append({"id": id, "name": member.get("name", ""), "character": member.get("character", ""), "total": GameSession.total_of(id),
			"best": GameSession.best_round_of(id)})
	return {"t": "final", "totals": totals}


static func _number(value: Variant) -> float:
	return float(value) if value is float or value is int else 0.0


static func _flag(value: Variant) -> bool:
	return value is bool and value
