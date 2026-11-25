extends SceneTree

#Checks the fair ranking file: broken files, top ten, ties, names, records and removal

const FILE := "user://fair_ranking_check.json"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_wipe()
	var book := _book()
	_expect(book.get("entries").is_empty() and book.call("ordered").is_empty(), "sin archivo, el ranking está vacío")
	_write_raw("{esto no es json")
	_expect(_book().get("entries").is_empty(), "un archivo dañado y sin copia es un ranking vacío")
	_write_raw(JSON.stringify({"entries": [{"name": "BIEN", "total": 900, "best": 400, "game": "a"}, {"name": "SIN TOTAL"}, 42,
		{"name": "MUCHO", "total": 99999, "best": -5, "character": "dragon", "game": "a"}, {"name": "bien ", "total": 950, "best": 10, "game": "b"}]}))
	var cleaned := _book()
	var kept: Array = cleaned.get("entries")
	_expect(kept.size() == 2 and int(kept[1]["total"]) == 5000 and int(kept[1]["best"]) == 0 and str(kept[1]["character"]) == "fire",
		"de un archivo con basura quedan solo las entradas válidas, con los números en su rango y un personaje que existe")
	_expect(int(kept[0]["total"]) == 950, "un archivo viejo con un nombre dos veces («BIEN» y «bien ») deja la mejor de las dos")
	_wipe()
	book = _book()
	var first: Array = book.call("record", "g1", _players([["ANA", 2000, 600]]))
	var ana: Dictionary = first[0]["entry"]
	_expect(first.size() == 1 and str(first[0]["status"]) == "new" and book.call("place_of", ana) == 1 and book.call("short_of_top", ana) == 0,
		"una entrada nueva: puesto 1, nada le falta")
	for game in range(2, 11):
		book.call("record", "g%d" % game, _players([["P%d" % game, 1000 + game * 50, 300]]))
	var ten: Array = book.call("ordered")
	_expect(ten.size() == 10 and str(ten[0]["name"]) == "ANA" and int(ten[9]["total"]) == 1100, "diez entradas, de la mejor a la peor")
	var eleventh: Array = book.call("record", "g11", _players([["ONCE", 1080, 900]]))
	_expect(book.call("place_of", eleventh[0]["entry"]) == 11 and book.call("short_of_top", eleventh[0]["entry"]) == 21,
		"la entrada once queda fuera del top 10 y le faltaron 21 puntos (%d)" % book.call("short_of_top", eleventh[0]["entry"]))
	book.call("record", "g12", _players([["EMPATE A", 1500, 500], ["EMPATE B", 1500, 700]]))
	book.call("record", "g13", _players([["MISMO", 1500, 700]]))
	var names: Array = (book.call("ordered") as Array).map(func(entry: Dictionary) -> String: return str(entry["name"]))
	_expect(names.find("EMPATE B") < names.find("MISMO") and names.find("MISMO") < names.find("EMPATE A"),
		"con el mismo total gana la mejor ronda, y con todo igual la entrada más vieja")
	var count: int = book.get("entries").size()
	var lower: Array = book.call("record", "g14", _players([["ana ", 1200, 300]]))
	_expect(book.get("entries").size() == count and str(lower[0]["status"]) == "kept" and int(lower[0]["before"]) == 2000
		and int((lower[0]["entry"] as Dictionary)["total"]) == 2000,
		"«ana » vuelve a jugar con menos: se queda su marca de 2000 y se avisa que no la superó")
	var higher: Array = book.call("record", "g15", _players([["Ana", 2300, 700]]))
	_expect(book.get("entries").size() == count and str(higher[0]["status"]) == "better" and int(higher[0]["before"]) == 2000
		and int((higher[0]["entry"] as Dictionary)["total"]) == 2300, "«Ana» supera su marca: la reemplaza (de 2000 a 2300) y sigue siendo una sola")
	book.call("record", "g16", _players([["LUIS", 1700, 400]]))
	book.call("record", "g17", _players([["LUIS", 1900, 400]]))
	var final: Array = book.call("record", "g17", _players([["LUIS", 1600, 400]]))
	_expect(int((final[0]["entry"] as Dictionary)["total"]) == 1700 and str(final[0]["status"]) == "kept" and int(final[0]["before"]) == 1700,
		"la misma partida vista dos veces se juzga contra la misma marca: 1900 y luego 1600 en el conteo final deja la de 1700")
	var twins: Array = book.call("record", "g18", _players([["DOBLE", 900, 100], ["doble", 1300, 200]]))
	var doubles := (book.get("entries") as Array).filter(func(entry: Dictionary) -> bool: return str(entry["name"]).to_upper() == "DOBLE")
	_expect(twins.size() == 2 and doubles.size() == 1 and int(doubles[0]["total"]) == 1300, "dos jugadores de una partida con el mismo nombre cuentan una vez, el mejor")
	_expect(book.call("remove", " luis") and not book.call("remove", "NADIE"), "se puede quitar un nombre del ranking; uno que no está no se quita")
	var again := _book()
	var left: Array = (again.get("entries") as Array).map(func(entry: Dictionary) -> String: return str(entry["name"]).to_upper())
	_expect(not left.has("LUIS") and left.has("ANA") and not FileAccess.file_exists(FILE + ".tmp"),
		"cerrar y abrir: el ranking sigue entero, sin el nombre quitado y sin archivo temporal")
	var whole: int = again.get("entries").size()
	_write_raw("{se cortó la luz")
	_expect(_book().get("entries").size() == whole, "si el archivo se daña, se lee su copia y no se pierde nada (%d)" % _book().get("entries").size())
	again.call("reset")
	_expect(again.get("entries").is_empty() and _book().get("entries").is_empty(), "el reinicio deja el ranking vacío, también en el archivo")
	_wipe()
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


func _wipe() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE + suffix))


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1
