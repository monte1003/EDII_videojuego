class_name NetProtocol
extends RefCounted

#The language the computers of a game speak over their sockets: every message is a JSON object with its type in "t", sent with its length
#in 4 bytes in front (big endian) so the other side knows where it ends. Anything too long, broken or unknown is thrown away.
#The last five types only go to the fair screen, which says hello with "role": "watch"

#2 since the fair screen (23/11/2026): a room of version 1 would take the screen for a player
const VERSION := 2
const GAME := "rumblenet"
#TCP port of the room and UDP port where rooms announce themselves on the local network
const PORT := 47820
const DISCOVERY_PORT := 47821
const MAX_MESSAGE := 65536
const TYPES: Array[String] = ["hello", "welcome", "reject", "room", "ready", "profile", "start", "loaded", "go", "st", "hit", "points",
	"scores", "advance", "ping", "pong", "bye", "warmup", "vote", "warm", "left", "rejoin",
	"snapshot", "sts", "struck", "done", "final"]


static func pack(message: Dictionary) -> PackedByteArray:
	var body := JSON.stringify(message).to_utf8_buffer()
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, body.size())
	#encode_u32 writes little endian: the protocol says big endian
	bytes.reverse()
	bytes.append_array(body)
	return bytes


#The value of a JSON text, or null when it is broken (without an error on the console: a broken message is normal on a network)
static func parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


#A message is good when it is an object with a known type
static func is_valid(message: Variant) -> bool:
	return message is Dictionary and (message as Dictionary).get("t") is String and TYPES.has((message as Dictionary)["t"])


#Joins the bytes that arrive in pieces and gives back the whole messages; "broken" goes true when the other side sends garbage
class Reader:
	var broken := false
	var _buffer := PackedByteArray()

	func feed(data: PackedByteArray) -> Array[Dictionary]:
		var messages: Array[Dictionary] = []
		_buffer.append_array(data)
		while _buffer.size() >= 4 and not broken:
			var head := _buffer.slice(0, 4)
			head.reverse()
			var length := head.decode_u32(0)
			if length <= 0 or length > MAX_MESSAGE:
				broken = true
				break
			if _buffer.size() < 4 + length:
				break
			var parsed: Variant = NetProtocol.parse(_buffer.slice(4, 4 + length).get_string_from_utf8())
			_buffer = _buffer.slice(4 + length)
			if NetProtocol.is_valid(parsed):
				messages.append(parsed)
		return messages
