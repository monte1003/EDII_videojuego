class_name NetLink
extends RefCounted

#One TCP connection with its own thread: only it touches the socket; inbox and outbox behind a Mutex

const CONNECT_TIMEOUT := 5000
#The thread pings this often so the other side hears it while a round loads
const PING_EVERY := 1000
#Bytes a fair screen link may keep waiting before it is dropped
const MAX_BACKLOG := 262144

var id := 0
var address := ""

var _peer: StreamPeerTCP
var _thread := Thread.new()
var _mutex := Mutex.new()
var _inbox: Array[Dictionary] = []
var _outbox: Array[PackedByteArray] = []
var _running := false
var _open := false
var _closed := false
var _reader := NetProtocol.Reader.new()
#Last time a byte arrived, written by the thread
var _heard := 0
#A fair screen link never blocks: unsent bytes wait in the backlog
var _watcher := false
var _backlog := PackedByteArray()
#Traffic counted by the thread: messages and bytes each way, and types received
var _messages_in := 0
var _bytes_in := 0
var _messages_out := 0
var _bytes_out := 0
var _kinds_in: Dictionary = {}


#Link over a socket the server accepted
static func accepted(peer: StreamPeerTCP) -> NetLink:
	var link := NetLink.new()
	link._peer = peer
	link.address = peer.get_connected_host()
	link._open = true
	return link


#Link that connects to a room; the thread waits for the connection
static func connecting(host: String, port: int) -> NetLink:
	var link := NetLink.new()
	link._peer = StreamPeerTCP.new()
	link.address = host
	if link._peer.connect_to_host(host, port) != OK:
		link._closed = true
	return link


func start() -> void:
	if _closed:
		return
	_running = true
	_heard = Time.get_ticks_msec()
	_thread.start(_loop)


func send(message: Dictionary) -> void:
	_mutex.lock()
	_outbox.append(NetProtocol.pack(message))
	_mutex.unlock()


func take() -> Array[Dictionary]:
	_mutex.lock()
	var messages := _inbox.duplicate()
	_inbox.clear()
	_mutex.unlock()
	return messages


func heard_ago() -> int:
	_mutex.lock()
	var heard := _heard
	_mutex.unlock()
	return Time.get_ticks_msec() - heard


func is_open() -> bool:
	_mutex.lock()
	var open := _open and not _closed
	_mutex.unlock()
	return open


func is_closed() -> bool:
	_mutex.lock()
	var closed := _closed
	_mutex.unlock()
	return closed


#Server marks the fair screen link: send without waiting, cut it if it stops reading
func set_watcher() -> void:
	_mutex.lock()
	_watcher = true
	_mutex.unlock()


#Messages and bytes each way, and received messages per type
func traffic() -> Dictionary:
	_mutex.lock()
	var counted := {"messages_in": _messages_in, "bytes_in": _bytes_in, "messages_out": _messages_out, "bytes_out": _bytes_out,
		"kinds_in": _kinds_in.duplicate()}
	_mutex.unlock()
	return counted


#Asks the thread to finish, waits for it and closes the socket
func stop() -> void:
	_running = false
	if _thread.is_started():
		_thread.wait_to_finish()
	if _peer != null:
		_peer.disconnect_from_host()
	_mutex.lock()
	_closed = true
	_mutex.unlock()


func _loop() -> void:
	var since := Time.get_ticks_msec()
	var pinged := 0
	var tuned := false
	while _running:
		_peer.poll()
		var status := _peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTING:
			if Time.get_ticks_msec() - since > CONNECT_TIMEOUT:
				break
			OS.delay_msec(10)
			continue
		if status != StreamPeerTCP.STATUS_CONNECTED:
			break
		if not tuned:
			#Send small messages at once: less delay on a busy Wi-Fi
			_peer.set_no_delay(true)
			tuned = true
		_mutex.lock()
		_open = true
		var outgoing := _outbox.duplicate()
		_outbox.clear()
		var watcher := _watcher
		_mutex.unlock()
		if Time.get_ticks_msec() - pinged >= PING_EVERY:
			pinged = Time.get_ticks_msec()
			outgoing.append(NetProtocol.pack({"t": "ping"}))
		if watcher:
			_send_without_waiting(outgoing)
		else:
			for bytes in outgoing:
				if _peer.put_data(bytes) != OK:
					_running = false
		if not outgoing.is_empty():
			var size := 0
			for bytes in outgoing:
				size += bytes.size()
			_mutex.lock()
			_messages_out += outgoing.size()
			_bytes_out += size
			_mutex.unlock()
		var available := _peer.get_available_bytes()
		if available > 0:
			var answer := _peer.get_partial_data(available)
			if answer[0] == OK:
				var messages := _reader.feed(answer[1] as PackedByteArray)
				if _reader.broken:
					break
				_mutex.lock()
				_inbox.append_array(messages)
				_heard = Time.get_ticks_msec()
				_messages_in += messages.size()
				_bytes_in += (answer[1] as PackedByteArray).size()
				for message in messages:
					_kinds_in[message["t"]] = int(_kinds_in.get(message["t"], 0)) + 1
				_mutex.unlock()
		OS.delay_msec(2)
	_mutex.lock()
	_closed = true
	_mutex.unlock()


#Thread: writes what the socket takes now; a screen that stops reading is cut
func _send_without_waiting(outgoing: Array[PackedByteArray]) -> void:
	for bytes in outgoing:
		_backlog.append_array(bytes)
	if _backlog.size() > MAX_BACKLOG:
		_running = false
		return
	if _backlog.is_empty():
		return
	var answer := _peer.put_partial_data(_backlog)
	if answer[0] != OK:
		_running = false
	else:
		_backlog = _backlog.slice(int(answer[1]))
