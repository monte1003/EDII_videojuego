extends SceneTree

#Checks the ranking of the fair screen (FairRanking) on a file of its own: a missing or broken file is an empty ranking, 0, 1, 10 and 11
#entries (the eleventh is out of the top ten and is told how many points it was short), the order with ties (total, then best round,
#then the older entry), the same game seen twice is never counted twice, the file is written whole (a temporary one moved over it,
#kept after closing and opening) and the reset empties it. The script loads FairRanking when it runs (it needs the game's autoloads).
#run: godot --headless --path . --script res://scripts/tests/fair_ranking_check.gd

const FILE := "user://fair_ranking_check.json"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	var book := _book()
	_expect(book.get("entries").is_empty() and book.call("ordered").is_empty(), "sin archivo, el ranking está vacío")
	_write_raw("{esto no es json")
	_expect(_book().get("entries").is_empty(), "un archivo dañado es un ranking vacío")
	_write_raw(JSON.stringify({"entries": [{"name": "BIEN", "total": 900, "best": 400, "game": "a"}, {"name": "SIN TOTAL"}, 42,
		{"name": "MUCHO", "total": 99999, "best": -5, "character": "dragon", "game": "a"}]}))
	var cleaned := _book()
	var kept: Array = cleaned.get("entries")
	_expect(kept.size() == 2 and int(kept[1]["total"]) == 5000 and int(kept[1]["best"]) == 0 and str(kept[1]["character"]) == "fire",
		"de un archivo con basura quedan solo las entradas válidas, con los números en su rango y un personaje que existe")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	book = _book()
	var first: Array = book.call("record", "g1", _players([["ANA", 2000, 600]]))
	_expect(first.size() == 1 and book.call("ordered").size() == 1 and book.call("place_of", first[0]) == 1 and book.call("short_of_top", first[0]) == 0,
		"una entrada: puesto 1, nada le falta")
	for game in range(2, 11):
		book.call("record", "g%d" % game, _players([["P%d" % game, 1000 + game * 50, 300]]))
	var ten: Array = book.call("ordered")
	_expect(ten.size() == 10 and str(ten[0]["name"]) == "ANA" and int(ten[9]["total"]) == 1100, "diez entradas, de la mejor a la peor")
	var eleventh: Array = book.call("record", "g11", _players([["ONCE", 1080, 900]]))
	_expect(book.call("place_of", eleventh[0]) == 11 and book.call("short_of_top", eleventh[0]) == 21,
		"la entrada once queda fuera del top 10 y le faltaron 21 puntos (%d)" % book.call("short_of_top", eleventh[0]))
	var tie: Array = book.call("record", "g12", _players([["EMPATE A", 1500, 500], ["EMPATE B", 1500, 700]]))
	var older: Array = book.call("record", "g13", _players([["MISMO", 1500, 700]]))
	var order: Array = book.call("ordered")
	var names: Array = order.map(func(entry: Dictionary) -> String: return str(entry["name"]))
	_expect(names.find("EMPATE B") < names.find("MISMO") and names.find("MISMO") < names.find("EMPATE A") and tie.size() == 2 and older.size() == 1,
		"con el mismo total gana la mejor ronda, y con todo igual la entrada más vieja")
	var count: int = book.get("entries").size()
	book.call("record", "g12", _players([["EMPATE A", 1600, 500], ["EMPATE B", 1500, 700]]))
	_expect(book.get("entries").size() == count, "la misma partida vista otra vez reemplaza sus entradas: no se cuenta dos veces")
	var again := _book()
	_expect(again.get("entries").size() == count and not FileAccess.file_exists(FILE + ".tmp"),
		"cerrar y abrir: el ranking sigue entero y no queda archivo temporal")
	again.call("reset")
	_expect(again.get("entries").is_empty() and _book().get("entries").is_empty(), "el reinicio deja el ranking vacío, también en el archivo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	print("fair_ranking_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _book() -> Object:
	var book: Object = (load("res://scripts/display/fair_ranking.gd") as GDScript).new()
	book.set("path", FILE)
	book.call("load_file")
	return book


func _players(rows: Array) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for row: Array in rows:
		players.append({"name": row[0], "character": "water", "total": row[1], "best": row[2]})
	return players


func _write_raw(text: String) -> void:
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1
