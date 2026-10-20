class_name LobbyState
extends RefCounted

#The places of the lobby and who is ready; the screen only draws what is here

signal changed

const CAPACITY := 4

var slots: Array[PlayerSlot] = []


func join(slot: PlayerSlot) -> bool:
	if slots.size() >= CAPACITY or find(slot.player_id) != null:
		return false
	slots.append(slot)
	changed.emit()
	return true


func leave(player_id: int) -> void:
	var slot := find(player_id)
	if slot != null:
		slots.erase(slot)
		changed.emit()


func clear() -> void:
	slots.clear()
	changed.emit()


func find(player_id: int) -> PlayerSlot:
	for slot in slots:
		if slot.player_id == player_id:
			return slot
	return null


func set_ready(player_id: int, value: bool) -> void:
	var slot := find(player_id)
	if slot != null and slot.ready != value:
		slot.ready = value
		changed.emit()


func ready_count() -> int:
	var total := 0
	for slot in slots:
		total += int(slot.ready)
	return total


#The game starts when there is somebody and everybody is ready
func all_ready() -> bool:
	return not slots.is_empty() and ready_count() == slots.size()


func free_places() -> int:
	return CAPACITY - slots.size()
