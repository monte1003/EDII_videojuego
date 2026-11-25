class_name NetProtocol
extends RefCounted

#Messages are JSON objects with their type in "t", prefixed by a 4-byte big-endian length

#2 since the fair screen, 3 since server-decided rounds
const VERSION := 3
const GAME := "rumblenet"
#TCP port of the room and UDP port of the announcements
const PORT := 47820
const DISCOVERY_PORT := 47821
const MAX_MESSAGE := 65536
const TYPES: Array[String] = ["hello", "welcome", "reject", "room", "ready", "profile", "start", "loaded", "go", "st", "hit", "points",
	"scores", "advance", "ping", "pong", "bye", "warmup", "vote", "warm", "left", "rejoin",
	"snapshot", "sts", "struck", "done", "final", "rnd"]


static func pack(message: Dictionary) -> PackedByteArray:
	var body := JSON.stringify(message).to_utf8_buffer()
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, body.size())
	#encode_u32 is little endian; the protocol is big endian
	bytes.reverse()
	bytes.append_array(body)
	return bytes


#JSON value, or null when broken (no console error: normal on a network)
static func parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


#Valid when it is an object with a known type
static func is_valid(message: Variant) -> bool:
	return message is Dictionary and (message as Dictionary).get("t") is String and TYPES.has((message as Dictionary)["t"])


#Joins incoming pieces into whole messages; "broken" marks garbage
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
