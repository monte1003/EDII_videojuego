extends Node

#A game of ROUND_COUNT rounds; every change of state goes through these methods and is announced with a signal

enum Phase { IDLE, LOBBY, WARMUP, INTRO, PLAYING, ROUND_RESULTS, FINISHED }

signal phase_changed(phase: Phase)
signal round_selected(index: int, info: MinigameInfo)
signal round_finished(result: RoundResult)
signal session_finished(results: Array[RoundResult])

const ROUND_COUNT := 4
#For a lobby opened on its own, without going through the character select
const DEFAULT_CHARACTER: CharacterData = preload("res://resources/characters/fire.tres")

var lobby := LobbyState.new()
var phase := Phase.IDLE
var plan: Array[StringName] = []
var round_index := -1
var results: Array[RoundResult] = []
#A practice is one minigame played on its own from the lobby
var practice := false

var _rng := RandomNumberGenerator.new()


#Fills the lobby with the players that picked a character; safe to call again
func prepare_lobby() -> void:
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
	if not lobby.all_ready():
		return
	_rng.randomize()
	plan = RoundPlanner.plan(MinigameCatalog.ready_entries(), ROUND_COUNT, _rng)
	if plan.is_empty():
		return
	results.clear()
	round_index = -1
	practice = false
	_set_phase(Phase.WARMUP)
	ScreenFlow.open(&"warmup")


func start_practice(id: StringName) -> void:
	if MinigameCatalog.find(id) == null:
		return
	plan = [id]
	results.clear()
	round_index = -1
	practice = true
	_select_next_round()


func finish_warmup() -> void:
	if phase == Phase.WARMUP:
		_select_next_round()


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
	results.append(result)
	_set_phase(Phase.ROUND_RESULTS)
	round_finished.emit(result)
	ScreenFlow.open(&"round_results")
	return true


#From the round results: the next round, or the end of the session
func advance() -> void:
	if phase != Phase.ROUND_RESULTS:
		return
	if practice:
		practice = false
		plan.clear()
		round_index = -1
		_set_phase(Phase.LOBBY)
		ScreenFlow.open(&"lobby")
	elif is_last_round():
		_set_phase(Phase.FINISHED)
		session_finished.emit(results)
		ScreenFlow.open(&"session_results")
	else:
		_select_next_round()


func restart_round() -> void:
	var info := current_info()
	if phase == Phase.PLAYING and info != null:
		ScreenFlow.open(info.id)


#New game from the end screen: back to the lobby with the same character
func play_again() -> void:
	reset()
	prepare_lobby()
	ScreenFlow.open(&"lobby")


func abandon() -> void:
	reset()
	ScreenFlow.go_to_root()


func reset() -> void:
	plan.clear()
	results.clear()
	round_index = -1
	practice = false
	lobby.clear()
	_set_phase(Phase.IDLE)


func _select_next_round() -> void:
	round_index += 1
	_set_phase(Phase.INTRO)
	round_selected.emit(round_index, current_info())
	ScreenFlow.open(&"round_intro")


func _set_phase(next: Phase) -> void:
	if phase != next:
		phase = next
		phase_changed.emit(next)
