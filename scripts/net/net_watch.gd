class_name NetWatch
extends Node

#Fair screen connection: tries feria.cfg and the announced address in turns, forever

signal changed

const CONFIG_FILE := "feria.cfg"
const FIRST_WAIT := 1.0
const LONGEST_WAIT := 10.0

#The room it watches through; tests may give their own
var net: NetRoom
var status := ""
var connected := false
#Address being tried and the one from feria.cfg
var address := ""
var config_address := ""
#Picture of the game; stage: lobby, warmup, intro, playing, round_results or finished
var stage := "lobby"
var plan: Array[StringName] = []
var seeds: Array[int] = []
var round_index := -1
var table: Array[Dictionary] = []
#Final totals from the server: {"id", "name", "character", "total", "best"}
var finals: Array[Dictionary] = []
#Messages and bytes per second from the server
var messages_per_second := 0
var bytes_per_second := 0

var _wait := FIRST_WAIT
var _retry_left := 0.0
var _turn := 0
var _rate_clock := 0.0
var _counted := {}


func _ready() -> void:
	if net == null:
		net = GameSession.net
	net.joined.connect(_on_joined)
	net.left.connect(_on_left)
	net.watched.connect(_on_watched)
	net.room_changed.connect(changed.emit)
	if config_address == "":
		config_address = read_config()
	net.browse()
	status = "Buscando la sala"


func _exit_tree() -> void:
	net.stop_browsing()
	if net.role == NetRoom.Role.WATCH:
		net.close()


func _process(delta: float) -> void:
	_measure(delta)
	if net.role == NetRoom.Role.WATCH:
		return
	_retry_left -= delta
	if _retry_left <= 0.0:
		_try()


#feria.cfg sits next to the executable, or the project in the editor
static func config_path() -> String:
	var folder := OS.get_executable_path().get_base_dir() if OS.has_feature("template") else ProjectSettings.globalize_path("res://")
	return folder.path_join(CONFIG_FILE)


#First address in feria.cfg, plain or "ip_anfitrion = ..."; # and ; start comments
static func read_config(path := "") -> String:
	var file := FileAccess.open(path if path != "" else config_path(), FileAccess.READ)
	if file == null:
		return ""
	for line in file.get_as_text().split("\n"):
		if line.strip_edges().begins_with("#") or line.strip_edges().begins_with(";"):
			continue
		var value := line.get_slice("=", line.count("=")).strip_edges().trim_prefix("\"").trim_suffix("\"")
		if value.is_valid_ip_address():
			return value
	return ""


#Points of a player over the rounds this screen knows
func total_of(player_id: int) -> int:
	var total := 0
	for points in table:
		total += int(points.get(player_id, 0))
	return total


#Addresses to try in turns: feria.cfg and announced rooms of this version
func candidates() -> Array[String]:
	var found: Array[String] = []
	if config_address.is_valid_ip_address():
		found.append(config_address)
	for heard: String in net.rooms:
		if int((net.rooms[heard] as Dictionary).get("v", 0)) == NetProtocol.VERSION and not found.has(heard):
			found.append(heard)
	return found


func _try() -> void:
	var choices := candidates()
	if choices.is_empty():
		_wait_again("Buscando la sala en la red")
		return
	address = choices[_turn % choices.size()]
	if net.watch(address):
		status = "Conectando con %s" % address
		changed.emit()
	else:
		_turn += 1
		_wait_again("No se pudo conectar con %s" % address)


func _wait_again(reason: String) -> void:
	_retry_left = _wait
	status = "%s · otro intento en %d s" % [reason, ceili(_wait)]
	_wait = minf(_wait * 2.0, LONGEST_WAIT)
	changed.emit()


func _on_joined() -> void:
	connected = true
	_wait = FIRST_WAIT
	status = "Mirando la sala"
	changed.emit()


func _on_left(reason: String) -> void:
	#An address that never answered yields its turn
	if not connected:
		_turn += 1
	connected = false
	_wait_again("%s (%s)" % [reason, address])


#The game picture follows the server; positions, shoves and warm-up clock do not change it
func _on_watched(message: Dictionary) -> void:
	match String(message["t"]):
		"snapshot":
			stage = str(message.get("phase", "lobby")).replace("idle", "lobby")
			plan = _ids(message.get("plan"))
			seeds = _numbers(message.get("seeds"))
			round_index = int(message.get("round", -1))
			table.clear()
			var rounds: Variant = message.get("table")
			if rounds is Array:
				for points: Variant in rounds:
					table.append(_points(points))
			finals.clear()
		"room":
			if not net.started:
				stage = "lobby"
		"warmup":
			stage = "warmup"
			plan.clear()
			seeds.clear()
			table.clear()
			finals.clear()
			round_index = -1
		"start":
			plan = _ids(message.get("plan"))
			seeds = _numbers(message.get("seeds"))
			round_index = 0
			stage = "intro"
		"go":
			round_index = int(message.get("round", round_index))
			stage = "playing"
		"scores":
			var index := int(message.get("round", -1))
			if index < 0:
				return
			while table.size() <= index:
				table.append({})
			table[index] = _points(message.get("points"))
			stage = "round_results"
		"advance":
			if round_index < plan.size() - 1:
				round_index += 1
				stage = "intro"
			else:
				stage = "finished"
		"final":
			finals.clear()
			var totals: Variant = message.get("totals")
			if totals is Array:
				for entry: Variant in totals:
					if entry is Dictionary:
						finals.append(entry)
			stage = "finished"
		_:
			return
	changed.emit()


func _measure(delta: float) -> void:
	_rate_clock += delta
	if _rate_clock < 1.0:
		return
	var now := net.traffic() if net.role == NetRoom.Role.WATCH else {}
	var messages := int(now.get("messages_in", 0))
	var bytes := int(now.get("bytes_in", 0))
	#A new connection counts from zero
	if messages < int(_counted.get("messages_in", 0)):
		_counted = {}
	messages_per_second = roundi((messages - int(_counted.get("messages_in", 0))) / _rate_clock)
	bytes_per_second = roundi((bytes - int(_counted.get("bytes_in", 0))) / _rate_clock)
	_counted = now
	_rate_clock = 0.0
	changed.emit()


static func _ids(raw: Variant) -> Array[StringName]:
	var ids: Array[StringName] = []
	if raw is Array:
		for id: Variant in raw:
			ids.append(StringName(str(id)))
	return ids


static func _numbers(raw: Variant) -> Array[int]:
	var numbers: Array[int] = []
	if raw is Array:
		for value: Variant in raw:
			numbers.append(int(value) if value is float or value is int else 0)
	return numbers


static func _points(raw: Variant) -> Dictionary:
	var points: Dictionary = {}
	if raw is Dictionary:
		for key: Variant in raw:
			var value: Variant = raw[key]
			points[int(str(key))] = int(value) if value is float or value is int else 0
	return points
