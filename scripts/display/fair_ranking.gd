class_name FairRanking
extends RefCounted

#The ranking of the fair screen, its own and apart from the records of the game (ScoreBook): one entry per name (capitals and spaces
#around it do not count), with its best total, character, best round, date and time and the game it came from. A name that plays again
#only replaces its entry when it beats it. It lives in a file of the screen that survives closing it, written to a temporary file that
#then replaces the real one (a cut in the middle never leaves it half written), with a copy beside it that is read when the file is
#missing or broken. The order is an AVL tree like the one of the final count: total, then best round, then the oldest entry first

const PATH := "user://feria_ranking.json"
const TOP := 10
const MAX_TOTAL := 5000

var path := PATH
#Every entry, in the order they came in: {"name", "character", "total", "best", "at", "game"}
var entries: Array[Dictionary] = []
#For each game recorded since the screen opened: the entry each name had before it ({} for none), so seeing the same game again (the
#points of the last round, then the final totals) judges it against the same mark
var _before: Dictionary = {}


#The key of a name: the same person written in capitals or with spaces around is one name
static func key_of(shown: String) -> String:
	return shown.strip_edges().to_upper()


#Reads the file, or its copy when the file is missing or broken; two entries of one name (an older file) keep the better one
func load_file() -> void:
	entries.clear()
	var raw := _read(path)
	if raw.is_empty():
		raw = _read(path + ".bak")
	for item: Variant in raw:
		var entry := _clean(item)
		if entry.is_empty():
			continue
		var index := _index_of(str(entry["name"]))
		if index < 0:
			entries.append(entry)
		elif int(entry["total"]) > int(entries[index]["total"]):
			entries[index] = entry


#Writes the whole ranking to a temporary file, moves it over the real one and keeps a copy of it
func save() -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 2, "entries": entries}, "\t"))
	file.close()
	var real := ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), real) != OK:
		return false
	DirAccess.copy_absolute(real, real + ".bak")
	return true


#The players of one game ({"name", "character", "total", "best"}). Each name keeps its entry unless this game beats it; two players of the
#game with one name count once, the better. Returns one result per player: {"entry" (the one in the ranking now), "status" ("new",
#"better" or "kept"), "total" (of this game), "before" (the mark it had to beat, -1 for none)}
func record(game: String, players: Array[Dictionary]) -> Array[Dictionary]:
	if not _before.has(game):
		_before[game] = {}
	var memo: Dictionary = _before[game]
	var now := Time.get_datetime_string_from_system(false, true)
	var judged: Dictionary = {}
	var results: Array[Dictionary] = []
	for player in players:
		var made := _clean({"name": player.get("name"), "character": player.get("character"), "total": player.get("total"),
			"best": player.get("best"), "at": now, "game": game})
		if made.is_empty():
			continue
		var key := key_of(str(made["name"]))
		if not memo.has(key):
			var found := _index_of(key)
			memo[key] = entries[found].duplicate() if found >= 0 else {}
		var before: Dictionary = memo[key]
		var index := _index_of(key)
		var mark: Dictionary = entries[index] if judged.has(key) and index >= 0 else before
		var result := {"total": int(made["total"]), "before": int(mark.get("total", -1))}
		if mark.is_empty() or int(made["total"]) > int(mark["total"]):
			_put(key, made)
			result["status"] = "new" if before.is_empty() else "better"
		else:
			#Not better: the mark stays (and comes back, if this same game had put a total that the final count lowered)
			if not judged.has(key):
				_put(key, before)
			result["status"] = "kept"
		result["entry"] = entries[_index_of(key)]
		judged[key] = true
		results.append(result)
	save()
	return results


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


#Takes a name out of the ranking (the staff, for a name that should not be there); false when it was not in it
func remove(shown: String) -> bool:
	var index := _index_of(key_of(shown))
	if index < 0:
		return false
	entries.remove_at(index)
	for memo: Dictionary in _before.values():
		memo.erase(key_of(shown))
	save()
	return true


func reset() -> void:
	entries.clear()
	_before.clear()
	save()


func _index_of(shown: String) -> int:
	var key := key_of(shown)
	for index in entries.size():
		if key_of(str(entries[index]["name"])) == key:
			return index
	return -1


#Puts the entry of a name in place of the one it had (at the end, as the newest), or takes it out when "entry" is empty
func _put(key: String, entry: Dictionary) -> void:
	var index := _index_of(key)
	if index >= 0:
		entries.remove_at(index)
	if not entry.is_empty():
		entries.append(entry)


#The entries of a file, or nothing when it is missing or broken
func _read(file_path: String) -> Array:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = NetProtocol.parse(file.get_as_text())
	if not parsed is Dictionary or not (parsed as Dictionary).get("entries") is Array:
		return []
	return (parsed as Dictionary)["entries"]


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
