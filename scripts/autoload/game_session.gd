extends Node

#A game of ROUND_COUNT rounds, one per minigame in a random order; every change of state goes through these methods and is announced with a signal

enum Phase { IDLE, LOBBY, WARMUP, INTRO, PLAYING, ROUND_RESULTS, FINISHED }

signal phase_changed(phase: Phase)
signal round_selected(index: int, info: MinigameInfo)
signal round_finished(result: RoundResult)
signal session_finished(results: Array[RoundResult])

const ROUND_COUNT := 5
#For a lobby opened on its own, without going through the character select
const DEFAULT_CHARACTER: CharacterData = preload("res://resources/characters/fire.tres")
#Every character that can be picked, in the order of the character select
const CHARACTER_IDS: Array[StringName] = [&"fire", &"water", &"plant", &"lightning"]
#Seconds the results of a round stay on screen in a room before the next round
const NET_RESULTS_SECONDS := 8

var lobby := LobbyState.new()
var phase := Phase.IDLE
var plan: Array[StringName] = []
var round_index := -1
var results: Array[RoundResult] = []
#A practice is one minigame played on its own from the lobby
var practice := false

#The numbers of the scoring and the best scores kept on this computer
var score_sheet: ScoreSheet = preload("res://resources/score_sheet.tres")
var score_book := ScoreBook.new()
#Whether the total of the game that just ended beat the best one kept
var session_record := false

#The game on the local network: a room this computer opened or joined (offline it plays alone)
var net := NetRoom.new()
#The player of this computer: player 1 alone; in a room, the id the server gave it
var local_id := GameState.PLAYER_ONE
#The seed of each round, the same on every computer of a room (empty alone, where each round draws its own), and the one being played
var seeds: Array[int] = []
var round_seed := 0

var _rng := RandomNumberGenerator.new()
#In a room, the result of this computer while the server gathers the points of everybody
var _waiting_result: RoundResult


func _ready() -> void:
	net.name = "Net"
	add_child(net)
	net.left.connect(_on_room_lost)


#The server went away in the middle of a game: back to the main menu (the lobby says it by itself)
func _on_room_lost(_reason: String) -> void:
	if phase != Phase.LOBBY and phase != Phase.IDLE:
		abandon()


func is_networked() -> bool:
	return net.is_active()


#Fills the lobby with the players that picked a character; safe to call again
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


#The lobby starts the session when everybody is ready: the warm-up comes first
func start_session() -> void:
	if not lobby.all_ready() or (is_networked() and not net.is_host()):
		return
	_rng.randomize()
	plan = RoundPlanner.plan(MinigameCatalog.ready_entries(), ROUND_COUNT, _rng)
	if plan.is_empty():
		return
	seeds.clear()
	if is_networked():
		#In a room everybody goes to the warm-up first; the order and the seeds go out when it ends
		net.begin_warmup()
		enter_warmup()
		return
	results.clear()
	round_index = -1
	practice = false
	_set_phase(Phase.WARMUP)
	ScreenFlow.open(&"warmup")


#The order of the rounds and their seeds came from the server (or this computer is the server)
func begin_networked(order: Array[StringName], round_seeds: Array[int]) -> void:
	plan = order.duplicate()
	seeds = round_seeds.duplicate()
	results.clear()
	round_index = -1
	practice = false
	_waiting_result = null
	_select_next_round()


#The lobby of a room shows everybody in it, as the server says
func sync_lobby(members: Array[Dictionary]) -> void:
	lobby.slots.clear()
	for member in members:
		var character_path := "res://resources/characters/%s.tres" % str(member.get("character", "fire"))
		var character: CharacterData = load(character_path) if ResourceLoader.exists(character_path) else DEFAULT_CHARACTER
		var slot := PlayerSlot.new(int(member.get("id", 0)), str(member.get("name", "JUGADOR")), character)
		slot.ready = bool(member.get("ready", false))
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
	#In a room the server draws the order of the rounds and their seeds and sends them; the others wait for them
	if not net.is_host():
		return
	_rng.randomize()
	plan = RoundPlanner.plan(MinigameCatalog.ready_entries(), ROUND_COUNT, _rng)
	seeds.clear()
	for index in plan.size():
		seeds.append(_rng.randi_range(1, 2147483646))
	net.start_game(plan, seeds)
	begin_networked(plan, seeds)


#Everybody of a room goes to the warm-up together
func enter_warmup() -> void:
	results.clear()
	plan.clear()
	round_index = -1
	practice = false
	_set_phase(Phase.WARMUP)
	ScreenFlow.open(&"warmup")


#Which colour of its character a player wears: the first one with a character wears it as it is, the next ones with the same, others
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


#The intro screen calls it when its animation ends: the round starts
func begin_round() -> void:
	var info := current_info()
	if phase != Phase.INTRO or info == null:
		return
	_set_phase(Phase.PLAYING)
	ScreenFlow.open(info.id)


#A minigame calls it once when its round is over; it returns false when no session is running
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


#The server sent the points of everybody for a round: the result of this computer takes them and the results show
func apply_round_points(index: int, points: Dictionary) -> void:
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


#From the round results: the next round, or the end of the session
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


#Points a player has added up over the rounds played so far
func total_of(player_id: int) -> int:
	var total := 0
	for result in results:
		total += result.points_of(player_id)
	return total


#The best single round of a player: what breaks a tie of totals
func best_round_of(player_id: int) -> int:
	var best := 0
	for result in results:
		best = maxi(best, result.points_of(player_id))
	return best


#The players from the first to the last: an AVL tree ordered by total, best round and player id, walked from its greatest key down
func standings() -> Array[AVLTree.AVLNode]:
	return _ranking().standings()


#Place of each player by id; players with the same total and the same best round share it
func places() -> Dictionary:
	return _ranking().places()


#The medal of a whole game: the average of its rounds against the same thresholds
func session_medal(player_id: int) -> ScoreSheet.Medal:
	if results.is_empty():
		return ScoreSheet.Medal.NONE
	return score_sheet.medal_for(roundi(float(total_of(player_id)) / results.size()))


#The tree of scores of everybody who played, for the podium
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


#New game from the end screen: back to the lobby with the same character
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
	round_index += 1
	round_seed = seeds[round_index] if round_index < seeds.size() else 0
	_set_phase(Phase.INTRO)
	round_selected.emit(round_index, current_info())
	ScreenFlow.open(&"round_intro")


func _set_phase(next: Phase) -> void:
	if phase != next:
		phase = next
		phase_changed.emit(next)
