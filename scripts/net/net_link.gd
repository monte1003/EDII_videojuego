class_name NetLink
extends RefCounted

#One TCP connection with its own thread: the thread is the only one that touches the socket; it reads whole messages into the inbox and
#writes what waits in the outbox. The main thread only puts messages in the outbox and takes them from the inbox, each behind the Mutex,
#so it never waits for the network

const CONNECT_TIMEOUT := 5000
#The thread itself says "still here" this often, so the other side hears it even while this game is busy loading a round
const PING_EVERY := 1000

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
#Last time any byte came from the other side, written by the thread
var _heard := 0


#A link over a socket the server already accepted
static func accepted(peer: StreamPeerTCP) -> NetLink:
	var link := NetLink.new()
	link._peer = peer
	link.address = peer.get_connected_host()
	link._open = true
	return link


#A link that connects to a room; the thread waits for the connection
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


#Milliseconds since anything came from the other side
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
			#Small messages go out at once instead of waiting to be joined with others: less delay on a busy Wi-Fi
			_peer.set_no_delay(true)
			tuned = true
		_mutex.lock()
		_open = true
		var outgoing := _outbox.duplicate()
		_outbox.clear()
		_mutex.unlock()
		if Time.get_ticks_msec() - pinged >= PING_EVERY:
			pinged = Time.get_ticks_msec()
			outgoing.append(NetProtocol.pack({"t": "ping"}))
		for bytes in outgoing:
			if _peer.put_data(bytes) != OK:
				_running = false
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
				_mutex.unlock()
		OS.delay_msec(2)
	_mutex.lock()
	_closed = true
	_mutex.unlock()
