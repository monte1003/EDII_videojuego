extends Node

#A game of ROUND_COUNT rounds in random order; every state change goes through here with a signal

enum Phase { IDLE, LOBBY, WARMUP, INTRO, PLAYING, ROUND_RESULTS, FINISHED }

signal phase_changed(phase: Phase)
signal round_selected(index: int, info: MinigameInfo)
signal round_finished(result: RoundResult)
signal session_finished(results: Array[RoundResult])

const ROUND_COUNT := 5
#For a lobby opened without the character select
const DEFAULT_CHARACTER: CharacterData = preload("res://resources/characters/fire.tres")
const CHARACTER_IDS: Array[StringName] = [&"fire", &"water", &"plant", &"lightning"]
#Seconds the round results stay on screen in a room
const NET_RESULTS_SECONDS := 8

var lobby := LobbyState.new()
var phase := Phase.IDLE
var plan: Array[StringName] = []
var round_index := -1
var results: Array[RoundResult] = []
#A practice is one minigame played alone from the lobby
var practice := false

var score_sheet: ScoreSheet = preload("res://resources/score_sheet.tres")
var score_book := ScoreBook.new()
#Whether the game that just ended beat the best total
var session_record := false

#The local network room this computer opened or joined
var net := NetRoom.new()
#Player 1 alone; in a room, the id the server gave
var local_id := GameState.PLAYER_ONE
#Seed of each round, the same on every computer of a room; empty alone
var seeds: Array[int] = []
var round_seed := 0

var _rng := RandomNumberGenerator.new()
#In a room, this computer's result while the server gathers everyone's points
var _waiting_result: RoundResult
#Came back to a game under way and waits for the next round
var _rejoined := false


func _ready() -> void:
	net.name = "Net"
	add_child(net)
	net.left.connect(_on_room_lost)


#The server left mid game: back to the main menu
func _on_room_lost(_reason: String) -> void:
	if phase != Phase.LOBBY and phase != Phase.IDLE:
		abandon()


func is_networked() -> bool:
	return net.is_active()


#Fills the lobby with the players that picked a character
func prepare_lobby() -> void:
	if is_networked():
		sync_lobby(net.room)
		_set_phase(Phase.LOBBY)
		return
	lobby.clear()
	for player_id in [GameState.PLAYER_ONE]:
		var character := GameState.get_character(player_id)
		if character == null:
			character = DEFAULT_CHARACTER
		lobby.join(PlayerSlot.new(player_id, GameState.get_player_name(player_id), character))
	_set_phase(Phase.LOBBY)


func participants(fallback: CharacterData = null) -> Array[PlayerSlot]:
	if not lobby.slots.is_empty():
		return lobby.slots
	var solo: Array[PlayerSlot] = []
	solo.append(PlayerSlot.new(GameState.PLAYER_ONE, GameState.get_player_name(GameState.PLAYER_ONE), fallback))
	return solo


func is_playing_round() -> bool:
	return phase == Phase.PLAYING


func current_info() -> MinigameInfo:
	if round_index < 0 or round_index >= plan.size():
		return null
	return MinigameCatalog.find(plan[round_index])


func is_last_round() -> bool:
	return round_index >= plan.size() - 1


#Starts the session with the warm-up
func start_session() -> void:
	if not lobby.all_ready() or (is_networked() and not net.is_host()):
		return
	_rng.randomize()
	plan = RoundPlanner.plan(MinigameCatalog.ready_entries(), ROUND_COUNT, _rng)
	if plan.is_empty():
		return
	seeds.clear()
	if is_networked():
		#The order and the seeds go out when the warm-up ends
		net.begin_warmup()
		enter_warmup()
		return
	results.clear()
	round_index = -1
	practice = false
	_set_phase(Phase.WARMUP)
	ScreenFlow.open(&"warmup")


#Round order and seeds from the server, or drawn here as the server
func begin_networked(order: Array[StringName], round_seeds: Array[int]) -> void:
	plan = order.duplicate()
	seeds = round_seeds.duplicate()
	results.clear()
	round_index = -1
	practice = false
	_waiting_result = null
	_select_next_round()


#Shows everybody in the room as the server says
func sync_lobby(members: Array[Dictionary]) -> void:
	lobby.slots.clear()
	for member in members:
		var character_path := "res://resources/characters/%s.tres" % str(member.get("character", "fire"))
		var character: CharacterData = load(character_path) if ResourceLoader.exists(character_path) else DEFAULT_CHARACTER
		var slot := PlayerSlot.new(int(member.get("id", 0)), str(member.get("name", "JUGADOR")), character)
		slot.ready = bool(member.get("ready", false))
		#Disconnected or rejoined players sit out the round under way
		slot.connected = bool(member.get("connected", true)) and not bool(member.get("waiting", false))
		lobby.slots.append(slot)
	lobby.changed.emit()


func start_practice(id: StringName) -> void:
	if MinigameCatalog.find(id) == null:
		return
	plan = [id]
	results.clear()
	round_index = -1
	practice = true
	_select_next_round()


func finish_warmup() -> void:
	if phase != Phase.WARMUP:
		return
	if not is_networked():
		_select_next_round()
		return
	#The server draws and sends the order and the seeds; the others wait
	if not net.is_host():
		return
	_rng.randomize()
	plan = RoundPlanner.plan(MinigameCatalog.ready_entries(), ROUND_COUNT, _rng)
	seeds.clear()
	for index in plan.size():
		seeds.append(_rng.randi_range(1, 2147483646))
	net.start_game(plan, seeds)
	begin_networked(plan, seeds)


#Rejoining a game under way: order, seeds and points come from the server
func rejoin(order: Array[StringName], round_seeds: Array[int], current: int, table: Array[Dictionary]) -> void:
	plan = order.duplicate()
	seeds = round_seeds.duplicate()
	practice = false
	_waiting_result = null
	results.clear()
	if plan.is_empty():
		enter_warmup()
		return
	for index in table.size():
		results.append(_kept_result(index, table[index]))
	round_index = maxi(current, 0)
	_rejoined = true
	_set_phase(Phase.ROUND_RESULTS)
	ScreenFlow.open(&"rejoin")


#A round this computer missed, with the points the server gave
func _kept_result(index: int, points: Dictionary) -> RoundResult:
	var result := RoundResult.make(plan[index] if index < plan.size() else &"", false, "", "")
	return result.with_score(RoundScore.make(score_sheet, int(points.get(local_id, 0)), ""), points)


#The fair screen follows a round without playing or reporting points
func follow_round(order: Array[StringName], round_seeds: Array[int], index: int) -> void:
	plan = order.duplicate()
	seeds = round_seeds.duplicate()
	round_index = index
	round_seed = seeds[index] if index >= 0 and index < seeds.size() else 0
	practice = false
	local_id = 0


func enter_warmup() -> void:
	results.clear()
	plan.clear()
	round_index = -1
	practice = false
	_set_phase(Phase.WARMUP)
	ScreenFlow.open(&"warmup")


#Colour variant of a player: repeats of the same character get another one
func variant_of(player_id: int) -> int:
	var slot := lobby.find(player_id)
	if slot == null or slot.character == null:
		return 0
	var before := 0
	for other in lobby.slots:
		if other == slot:
			break
		if other.character != null and other.character.id == slot.character.id:
			before += 1
	return before


static func character_by_id(id: StringName) -> CharacterData:
	var path := "res://resources/characters/%s.tres" % id
	return load(path) as CharacterData if ResourceLoader.exists(path) else DEFAULT_CHARACTER


#Called by the intro when its animation ends
func begin_round() -> void:
	var info := current_info()
	if phase != Phase.INTRO or info == null:
		return
	_set_phase(Phase.PLAYING)
	ScreenFlow.open(info.id)


#Called once by a minigame at the end; false without a session
func report_result(result: RoundResult) -> bool:
	if phase != Phase.PLAYING:
		return false
	if result.score == null:
		result.score = RoundScore.make(score_sheet, 0, "")
	if is_networked() and not practice:
		_waiting_result = result
		net.report_points(round_index, result.points_of(local_id))
		return true
	_store_result(result)
	return true


#Points of everybody for a round, from the server
func apply_round_points(index: int, points: Dictionary) -> void:
	if _rejoined and _waiting_result == null and index == round_index and results.size() == index:
		results.append(_kept_result(index, points))
		return
	if _waiting_result == null or index != round_index or phase != Phase.PLAYING:
		return
	var result := _waiting_result
	_waiting_result = null
	result.points_by_player = points
	_store_result(result)


func _store_result(result: RoundResult) -> void:
	result.score.record = score_book.submit_round(result.minigame_id, result.score.points)
	results.append(result)
	_set_phase(Phase.ROUND_RESULTS)
	round_finished.emit(result)
	ScreenFlow.open(&"round_results")


#Next round or end of the session
func advance() -> void:
	if phase != Phase.ROUND_RESULTS:
		return
	if is_networked() and not practice:
		#In a room only the server moves everybody on
		if not net.is_host():
			return
		net.advance_all()
	advance_now()


func advance_now() -> void:
	if phase != Phase.ROUND_RESULTS:
		return
	if practice:
		practice = false
		plan.clear()
		round_index = -1
		_set_phase(Phase.LOBBY)
		ScreenFlow.open(&"lobby")
	elif is_last_round():
		session_record = score_book.submit_session(total_of(local_id))
		_set_phase(Phase.FINISHED)
		session_finished.emit(results)
		ScreenFlow.open(&"podium")
	else:
		_select_next_round()


func total_of(player_id: int) -> int:
	var total := 0
	for result in results:
		total += result.points_of(player_id)
	return total


#Best single round of a player, the tie-break
func best_round_of(player_id: int) -> int:
	var best := 0
	for result in results:
		best = maxi(best, result.points_of(player_id))
	return best


#Players from first to last: AVL tree by total, best round and id
func standings() -> Array[AVLTree.AVLNode]:
	return _ranking().standings()


#Place of each player by id; equal total and best round share it
func places() -> Dictionary:
	return _ranking().places()


#Medal of a whole game: the average of its rounds
func session_medal(player_id: int) -> ScoreSheet.Medal:
	if results.is_empty():
		return ScoreSheet.Medal.NONE
	return score_sheet.medal_for(roundi(float(total_of(player_id)) / results.size()))


func ranking() -> AVLTree:
	return _ranking()


func _ranking() -> AVLTree:
	var tree := AVLTree.new()
	for slot in participants():
		tree.insert(total_of(slot.player_id), slot.player_id, best_round_of(slot.player_id))
	return tree


func restart_round() -> void:
	var info := current_info()
	if phase == Phase.PLAYING and info != null:
		ScreenFlow.open(info.id)


#New game from the end screen with the same character
func play_again() -> void:
	reset()
	net.reopen()
	prepare_lobby()
	ScreenFlow.open(&"lobby")


func abandon() -> void:
	net.close()
	reset()
	ScreenFlow.go_to_root()


func reset() -> void:
	plan.clear()
	results.clear()
	round_index = -1
	practice = false
	session_record = false
	lobby.clear()
	_set_phase(Phase.IDLE)


func _select_next_round() -> void:
	_rejoined = false
	round_index += 1
	round_seed = seeds[round_index] if round_index < seeds.size() else 0
	_set_phase(Phase.INTRO)
	round_selected.emit(round_index, current_info())
	ScreenFlow.open(&"round_intro")


func _set_phase(next: Phase) -> void:
	if phase != next:
		phase = next
		phase_changed.emit(next)
