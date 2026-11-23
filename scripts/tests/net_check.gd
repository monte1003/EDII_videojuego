extends SceneTree

#Checks the sockets and threads of the game on the local network in one process: the framing of the messages (whole, cut in pieces and
#several together), what is thrown away (unknown types, broken JSON, a message too long), a server with three clients that talk both ways
#through their threads, and that every thread finishes. run: godot --headless --path . --script res://scripts/tests/net_check.gd

const TEST_PORT := 47830
#Every wait for the threads is in real time: with --fixed-fps the frames can go by much faster than the sockets
const WAIT_MS := 5000

var _failures := 0


func _initialize() -> void:
	_check_framing()
	await _check_links()
	print("net_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _check_framing() -> void:
	var bytes := NetProtocol.pack({"t": "ping"})
	_expect(bytes.size() == 4 + JSON.stringify({"t": "ping"}).length() and bytes[0] == 0 and bytes[3] == bytes.size() - 4, "el largo va en 4 bytes delante, de mayor a menor")
	var reader := NetProtocol.Reader.new()
	var whole := reader.feed(bytes)
	_expect(whole.size() == 1 and whole[0]["t"] == "ping", "un mensaje entero se lee")
	var two := NetProtocol.pack({"t": "ready", "value": true})
	two.append_array(NetProtocol.pack({"t": "pong"}))
	var pieces := NetProtocol.Reader.new()
	var read: Array[Dictionary] = []
	for index in two.size():
		read.append_array(pieces.feed(two.slice(index, index + 1)))
	_expect(read.size() == 2 and read[0]["t"] == "ready" and read[1]["t"] == "pong", "dos mensajes que llegan byte a byte se leen enteros y en orden")
	var junk := NetProtocol.Reader.new()
	var bad := NetProtocol.pack({"t": "borrar_todo"})
	var broken_json := "{no es json".to_utf8_buffer()
	var framed := PackedByteArray([0, 0, 0, broken_json.size()])
	framed.append_array(broken_json)
	bad.append_array(framed)
	bad.append_array(NetProtocol.pack({"t": "pong"}))
	var kept := junk.feed(bad)
	_expect(kept.size() == 1 and kept[0]["t"] == "pong" and not junk.broken, "un tipo desconocido y un JSON roto se descartan sin cortar la conexión")
	var huge := NetProtocol.Reader.new()
	huge.feed(PackedByteArray([0, 16, 0, 0, 1, 2]))
	_expect(huge.broken, "un largo de más de %d bytes marca la conexión como rota" % NetProtocol.MAX_MESSAGE)
	_expect(not NetProtocol.is_valid([1, 2]) and not NetProtocol.is_valid({"t": 3}) and NetProtocol.is_valid({"t": "st"}), "solo un objeto con un tipo conocido es un mensaje")


func _check_links() -> void:
	var server := TCPServer.new()
	_expect(server.listen(TEST_PORT, "127.0.0.1") == OK, "el servidor escucha en el puerto %d" % TEST_PORT)
	var clients: Array[NetLink] = []
	for index in 3:
		var client := NetLink.connecting("127.0.0.1", TEST_PORT)
		client.start()
		clients.append(client)
	var accepted: Array[NetLink] = []
	var limit := Time.get_ticks_msec() + WAIT_MS
	while Time.get_ticks_msec() < limit:
		while server.is_connection_available():
			var link := NetLink.accepted(server.take_connection())
			link.id = accepted.size() + 2
			link.start()
			accepted.append(link)
		if accepted.size() == 3:
			break
		await process_frame
	_expect(accepted.size() == 3, "el servidor acepta a tres clientes (%d)" % accepted.size())
	for index in clients.size():
		clients[index].send({"t": "hello", "name": "J%d" % index, "v": NetProtocol.VERSION})
		clients[index].send({"t": "st", "p": [index, 0, 0]})
	var heard: Array[Dictionary] = []
	limit = Time.get_ticks_msec() + WAIT_MS
	while Time.get_ticks_msec() < limit:
		#Each thread also says "ping" once a second (as soon as it starts, if the game took over a second to open): that is the heartbeat
		for link in accepted:
			heard.append_array(link.take().filter(func(message: Dictionary) -> bool: return message["t"] != "ping"))
		if heard.size() >= 6:
			break
		await process_frame
	_expect(heard.size() == 6, "el servidor recibe los seis mensajes de los clientes por sus hilos (%d)" % heard.size())
	for link in accepted:
		link.send({"t": "welcome", "id": link.id})
	var welcomed := 0
	limit = Time.get_ticks_msec() + WAIT_MS
	while Time.get_ticks_msec() < limit:
		for client in clients:
			for message in client.take():
				welcomed += int(message["t"] == "welcome")
		if welcomed == 3:
			break
		await process_frame
	_expect(welcomed == 3, "cada cliente recibe su bienvenida del servidor (%d)" % welcomed)
	clients[0].stop()
	var noticed := false
	limit = Time.get_ticks_msec() + WAIT_MS
	while Time.get_ticks_msec() < limit:
		if accepted[0].is_closed() or accepted.any(func(link: NetLink) -> bool: return link.is_closed()):
			noticed = true
			break
		await process_frame
	_expect(noticed, "el servidor nota que un cliente se fue")
	for link in accepted:
		link.stop()
	for client in clients:
		client.stop()
	server.stop()
	_expect(clients.all(func(link: NetLink) -> bool: return link.is_closed()) and accepted.all(func(link: NetLink) -> bool: return link.is_closed()), "todos los hilos terminan y cada conexión queda cerrada")
