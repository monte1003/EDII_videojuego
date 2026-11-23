class_name FairRanking
extends RefCounted

#The ranking of the fair screen, its own and apart from the records of the game (ScoreBook): every player of every game seen here, with
#name, character, total, best round, date and time and the game it came from. It lives in a file of the screen that survives closing
#it; a missing or broken file is an empty ranking, and it is written to a temporary file that then replaces the real one, so a cut in
#the middle never leaves it half written. The order is an AVL tree like the one of the final count: total, then best round, then the
#oldest entry first

const PATH := "user://feria_ranking.json"
const TOP := 10
const MAX_TOTAL := 5000

var path := PATH
#Every entry, in the order they came in: {"name", "character", "total", "best", "at", "game"}
var entries: Array[Dictionary] = []


func load_file() -> void:
	entries.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = NetProtocol.parse(file.get_as_text())
	if not parsed is Dictionary or not (parsed as Dictionary).get("entries") is Array:
		return
	for raw: Variant in (parsed as Dictionary)["entries"]:
		var entry := _clean(raw)
		if not entry.is_empty():
			entries.append(entry)


#Writes the whole ranking to a temporary file and moves it over the real one
func save() -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "entries": entries}, "\t"))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK


#The players of one game ({"name", "character", "total", "best"}), under the key of the game: seen again (the screen came back, or the
#final totals arrived after the points of the last round) it replaces them instead of adding them twice. Returns the new entries
func record(game: String, players: Array[Dictionary]) -> Array[Dictionary]:
	for index in range(entries.size() - 1, -1, -1):
		if entries[index]["game"] == game:
			entries.remove_at(index)
	var fresh: Array[Dictionary] = []
	var now := Time.get_datetime_string_from_system(false, true)
	for player in players:
		var entry := _clean({"name": player.get("name"), "character": player.get("character"), "total": player.get("total"),
			"best": player.get("best"), "at": now, "game": game})
		if not entry.is_empty():
			entries.append(entry)
			fresh.append(entry)
	save()
	return fresh


#Every entry from the best to the worst: the AVL tree keyed by total, best round and the place in the list (the older wins a full tie)
func ordered() -> Array[Dictionary]:
	var tree := AVLTree.new()
	for index in entries.size():
		tree.insert(int(entries[index]["total"]), index, int(entries[index]["best"]))
	var order: Array[Dictionary] = []
	for node in tree.standings():
		order.append(entries[node.player_id])
	return order


#Place of an entry in the ranking, from 1
func place_of(entry: Dictionary) -> int:
	return ordered().find(entry) + 1


#Points an entry was short of the top ten (0 when it is in)
func short_of_top(entry: Dictionary) -> int:
	var order := ordered()
	if order.find(entry) < TOP or order.size() <= TOP:
		return 0
	return maxi(int(order[TOP - 1]["total"]) - int(entry["total"]) + 1, 1)


func reset() -> void:
	entries.clear()
	save()


#An entry as it may be kept: a name, a known character and numbers in range; anything else in the file is left out
static func _clean(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var source: Dictionary = raw
	var total: Variant = source.get("total")
	if not (total is float or total is int):
		return {}
	var best: Variant = source.get("best", 0)
	var shown := str(source.get("name", "")).strip_edges().left(GameState.MAX_NAME_LENGTH)
	var character := str(source.get("character", "fire"))
	if not ResourceLoader.exists("res://resources/characters/%s.tres" % character):
		character = "fire"
	return {"name": shown if shown != "" else "JUGADOR", "character": character, "total": clampi(int(total), 0, MAX_TOTAL),
		"best": clampi(int(best) if best is float or best is int else 0, 0, ScoreSheet.MAX_POINTS), "at": str(source.get("at", "")),
		"game": str(source.get("game", ""))}
