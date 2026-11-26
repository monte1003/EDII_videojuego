extends SceneTree

#Checks the scoring curves, medals, balance and score book; run headless with --script

const SHEET: ScoreSheet = preload("res://resources/score_sheet.tres")
const BOOK_PATH := "user://score_check_book.json"

var _failures := 0


func _initialize() -> void:
	_check_medals()
	_check_curves()
	_check_references()
	_check_idle()
	_check_trend_and_selfie()
	_check_book()
	print("score_check: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _check_medals() -> void:
	_expect(SHEET.medal_for(249) == ScoreSheet.Medal.NONE and SHEET.medal_for(250) == ScoreSheet.Medal.BRONZE, "el Bronce empieza en 250")
	_expect(SHEET.medal_for(499) == ScoreSheet.Medal.BRONZE and SHEET.medal_for(500) == ScoreSheet.Medal.SILVER, "la Plata empieza en 500")
	_expect(SHEET.medal_for(749) == ScoreSheet.Medal.SILVER and SHEET.medal_for(750) == ScoreSheet.Medal.GOLD, "el Oro empieza en 750")
	_expect(SHEET.medal_for(919) == ScoreSheet.Medal.GOLD and SHEET.medal_for(920) == ScoreSheet.Medal.DIAMOND, "el Diamante empieza en 920")
	_expect(SHEET.gap_to_next(688) == 62 and SHEET.gap_to_next(1000) == 0, "faltan 62 para el Oro con 688 y nada con 1000")
	var score := RoundScore.make(SHEET, 1400, "x", [["a", 1], ["b", 2], ["c", 3], ["d", 4]])
	_expect(score.points == 1000 and score.breakdown.size() == 3, "un puntaje se recorta a 1000 y a tres líneas")


#Curves never drop with a better result, stay in 0..1000 and never jump
func _check_curves() -> void:
	var race := _series(func(step: int) -> int: return SHEET.race_points(true, 150.0 - step, 3, 1.0), 110)
	_expect(_grows(race) and _bounded(race) and _max_jump(race) <= 12, "carrera: crece al bajar el tiempo, sin saltos (%d)" % _max_jump(race))
	var unfinished := _series(func(step: int) -> int: return SHEET.race_points(false, 150.0, 0, step / 100.0), 101)
	_expect(_grows(unfinished) and unfinished.back() == SHEET.race_unfinished, "carrera sin llegar: crece con el avance hasta %d" % SHEET.race_unfinished)
	_expect(SHEET.race_points(true, 150.0, 0, 1.0) > SHEET.race_points(false, 150.0, 0, 1.0), "llegar siempre vale más que no llegar")
	var street := _series(func(step: int) -> int: return SHEET.street_points(float(step), 99), 61)
	_expect(_grows(street) and _bounded(street) and _max_jump(street) <= 35, "calle: crece con los segundos, sin saltos (%d)" % _max_jump(street))
	var hits := _series(func(step: int) -> int: return SHEET.street_points(60.0, 10 - step), 11)
	_expect(_grows(hits) and hits.back() == 1000 and hits[0] == SHEET.street_survive, "calle: cada golpe resta y nunca baja de %d" % SHEET.street_survive)
	var drop := _series(func(step: int) -> int: return SHEET.drop_points(float(step)), 81)
	_expect(_grows(drop) and _bounded(drop) and drop.back() == 1000 and _max_jump(drop) <= 18, "SocialDrop: crece con los segundos, sin saltos (%d)" % _max_jump(drop))
	var trend := _series(func(step: int) -> int: return SHEET.trend_score(step, 30.0), 31)
	_expect(_grows(trend) and trend[0] == 0 and trend.back() == 1000 and _max_jump(trend) <= 34, "tendencias: de 0 a 1000 hasta el par, sin saltos")
	var selfie := _series(func(step: int) -> int: return SHEET.selfie_points(step * 10), 160)
	_expect(_grows(selfie) and _bounded(selfie) and _max_jump(selfie) <= 12, "selfie: crece con los seguidores, sin saltos (%d)" % _max_jump(selfie))
	_expect(SHEET.race_points(true, 10.0, 9, 1.0) == 1000 and SHEET.street_points(999.0, -3) == 1000 and SHEET.drop_points(500.0) == 1000,
		"valores fuera de las anclas se recortan a 1000")
	_expect(SHEET.race_points(false, 0.0, 0, -1.0) == 0 and SHEET.street_points(-5.0, 0) == 0 and SHEET.drop_points(-1.0) == 0 and SHEET.selfie_points(-20) == 0,
		"valores negativos se recortan a 0")


#The same kind of player gets the same medal in the five minigames
func _check_references() -> void:
	var table := {
		"novato": [
			SHEET.race_points(false, 150.0, 0, 0.6), SHEET.street_points(24.0, 5), SHEET.drop_points(22.0),
			_trend(0.3), SHEET.selfie_points(_selfie(4, 1, 0, 0, 4)),
		],
		"competente": [
			SHEET.race_points(true, 118.0, 2, 1.0), SHEET.street_points(60.0, 6), SHEET.drop_points(52.0),
			_trend(0.6), SHEET.selfie_points(_selfie(7, 4, 3, 2, 4)),
		],
		"experto": [
			SHEET.race_points(true, 98.0, 3, 1.0), SHEET.street_points(60.0, 3), SHEET.drop_points(68.0),
			_trend(0.82), SHEET.selfie_points(_selfie(8, 6, 5, 4, 4)),
		],
		"casi perfecto": [
			SHEET.race_points(true, 74.0, 3, 1.0), SHEET.street_points(60.0, 1), SHEET.drop_points(80.0),
			_trend(0.95), SHEET.selfie_points(_selfie(7, 6, 6, 6, 4)),
		],
	}
	var wanted := {"novato": ScoreSheet.Medal.BRONZE, "competente": ScoreSheet.Medal.SILVER, "experto": ScoreSheet.Medal.GOLD,
		"casi perfecto": ScoreSheet.Medal.DIAMOND}
	for kind: String in table:
		var points: Array = table[kind]
		var fits := true
		for value: int in points:
			var medal := SHEET.medal_for(value)
			fits = fits and (medal <= wanted[kind] if kind == "novato" else medal == wanted[kind])
		_expect(fits, "%s: %s en los cinco juegos %s" % [kind, ScoreSheet.MEDAL_NAMES[wanted[kind]] + (" o menos" if kind == "novato" else ""), points])


#Somebody who never touches a key gets at most Bronze anywhere
func _check_idle() -> void:
	var idle := [SHEET.race_points(false, 150.0, 0, 0.0), SHEET.street_points(8.0, 2), SHEET.drop_points(12.0),
		_trend(0.0), SHEET.selfie_points(0)]
	var worst := 0
	for value: int in idle:
		worst = maxi(worst, value)
	_expect(SHEET.medal_for(worst) <= ScoreSheet.Medal.BRONZE, "un jugador quieto no pasa de Bronce: %s" % [idle])


func _check_trend_and_selfie() -> void:
	_expect(SHEET.trend_score(30, 30.0) == 1000 and SHEET.trend_score(45, 30.0) == 1000, "llegar al par da 1000 y pasarlo no da más")
	_expect(SHEET.medal_for(_trend(0.4)) == ScoreSheet.Medal.BRONZE, "con el 40 %% del par: Bronce (%d)" % _trend(0.4))
	_expect(SHEET.selfie_followers(false, false, 1) == 39 and SHEET.selfie_followers(true, true, 1) == 169, "sola en la foto: 39, y 169 con centro y pose")
	_expect(SHEET.selfie_followers(true, true, 2) == 156 and SHEET.selfie_followers(true, true, 3) == 150 and SHEET.selfie_followers(true, true, 7) == 150,
		"la exclusividad baja con dos y con tres o más")
	_expect(SHEET.selfie_points(640) == 640 and SHEET.selfie_points(1300) == 1000, "un seguidor es un punto, hasta 1000")
	var full_room := 6 * SHEET.selfie_followers(true, true, 4) + SHEET.selfie_followers(false, false, 4)
	var short := 5 * SHEET.selfie_followers(true, true, 4) + 2 * SHEET.selfie_followers(false, false, 4)
	_expect(SHEET.medal_for(SHEET.selfie_points(full_room)) == ScoreSheet.Medal.DIAMOND and SHEET.medal_for(SHEET.selfie_points(short)) == ScoreSheet.Medal.GOLD,
		"sala llena: 6 fotos perfectas y 1 dentro dan Diamante (%d), con 5 perfectas Oro (%d)" % [full_room, short])


func _check_book() -> void:
	var absolute := ProjectSettings.globalize_path(BOOK_PATH)
	if FileAccess.file_exists(BOOK_PATH):
		DirAccess.remove_absolute(absolute)
	var book := ScoreBook.new(BOOK_PATH)
	_expect(book.best_round(&"level_01") == 0 and book.best_session() == 0, "sin archivo, el libro empieza en cero")
	_expect(book.submit_round(&"level_01", 640) and not book.submit_round(&"level_01", 640) and not book.submit_round(&"level_01", 300),
		"solo un puntaje mayor es récord")
	_expect(book.submit_session(2100) and not book.submit_session(1900), "solo una partida mejor es récord")
	var again := ScoreBook.new(BOOK_PATH)
	_expect(again.best_round(&"level_01") == 640 and again.best_session() == 2100, "lo guardado se lee igual al volver a abrir")
	for broken: String in ["", "{ esto no es json", "[1, 2, 3]", "{\"rounds\": 7, \"session\": \"mucho\"}",
			"{\"rounds\": {\"level_01\": \"alto\", \"street_game\": 99999, \"social_drop\": -4}, \"session\": -50}"]:
		var file := FileAccess.open(BOOK_PATH, FileAccess.WRITE)
		file.store_string(broken)
		file.close()
		var damaged := ScoreBook.new(BOOK_PATH)
		var sane := damaged.best_round(&"level_01") == 0 and damaged.best_session() == 0 and damaged.best_round(&"street_game") <= 1000 \
			and damaged.best_round(&"social_drop") == 0
		_expect(sane and damaged.submit_round(&"level_01", 10), "archivo dañado (%s): arranca en cero y vuelve a guardar" % broken.left(18))
	DirAccess.remove_absolute(absolute)


#Trend war points for a share of a 30-trend par
func _trend(share: float) -> int:
	return SHEET.trend_score(roundi(share * 30.0), 30.0)


#Followers of a round with "crowd" in every photo
func _selfie(inside: int, centered: int, posing: int, perfect: int, crowd: int) -> int:
	var factor := SHEET.selfie_crowd[crowd - 1]
	return roundi((inside * SHEET.selfie_inside + centered * SHEET.selfie_center + posing * SHEET.selfie_pose + perfect * SHEET.selfie_perfect) * factor)


func _series(sample: Callable, count: int) -> Array[int]:
	var values: Array[int] = []
	for step in count:
		values.append(sample.call(step))
	return values


func _grows(values: Array[int]) -> bool:
	for index in range(1, values.size()):
		if values[index] < values[index - 1]:
			return false
	return true


func _bounded(values: Array[int]) -> bool:
	for value in values:
		if value < 0 or value > ScoreSheet.MAX_POINTS:
			return false
	return true


func _max_jump(values: Array[int]) -> int:
	var jump := 0
	for index in range(1, values.size()):
		jump = maxi(jump, values[index] - values[index - 1])
	return jump
