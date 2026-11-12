class_name ScoreSheet
extends Resource

#Every number of the scoring in one place: the medals, and what each minigame needs to turn what it measures into 0 to 1000 points.
#Tuning the balance is changing these numbers, never the code of a round

enum Medal { NONE, BRONZE, SILVER, GOLD, DIAMOND }

const MAX_POINTS := 1000
const MEDAL_NAMES: Array[String] = ["Sin medalla", "Bronce", "Plata", "Oro", "Diamante"]

@export_group("Medals")
@export var bronze := 250
@export var silver := 500
@export var gold := 750
@export var diamond := 920

@export_group("Feed race")
#Reaching the goal, the most the time adds, and each attempt that was not spent
@export var race_finish := 300
@export var race_time_points := 550
@export var race_attempt_points := 50
@export var race_attempts := 3
#Seconds of the best and of the worst arrival that still adds something
@export var race_best := 70.0
@export var race_worst := 150.0
@export var race_gamma := 1.15
#Without reaching the goal: up to this much for the share of the course that was covered
@export var race_unfinished := 200

@export_group("Street")
@export var street_seconds := 60.0
#Lasting the whole round, the most a clean run adds on top, and what each hit takes from it
@export var street_survive := 600
@export var street_clean := 400
@export var street_hit_cost := 60
#Without lasting: up to this much, by the share of the time held
@export var street_partial := 580
@export var street_gamma := 1.2

@export_group("SocialDrop")
@export var drop_seconds := 80.0
@export var drop_gamma := 1.25

@export_group("Trend war")
@export var trend_rounds := 5
@export var trend_round_points := 200
#Share of a round that completing the trend gives whatever the time left
@export var trend_base := 0.3
#What the 1st, 2nd, 3rd and 4th to complete a trend get of it; alone it is always the first
@export var trend_places: Array[float] = [1.0, 0.7, 0.5, 0.35]

@export_group("Perfect selfie")
#Followers of each thing in a photo
@export var selfie_inside := 30
@export var selfie_center := 20
@export var selfie_pose := 60
@export var selfie_perfect := 20
#How much a photo is worth by how many are in it (1, 2, 3, 4 or more)
@export var selfie_crowd: Array[float] = [1.5, 1.0, 0.8, 0.7]
@export var selfie_photos := 8
#Followers that are worth the 1000 points, and the curve up to them
@export var selfie_best := 1440.0
@export var selfie_gamma := 1.0


func medal_for(points: int) -> Medal:
	if points >= diamond:
		return Medal.DIAMOND
	if points >= gold:
		return Medal.GOLD
	if points >= silver:
		return Medal.SILVER
	if points >= bronze:
		return Medal.BRONZE
	return Medal.NONE


#Points a medal starts at; 0 for none
func threshold_of(medal: Medal) -> int:
	return [0, bronze, silver, gold, diamond][medal]


#How many points are missing for the next medal; 0 when it is already the best
func gap_to_next(points: int) -> int:
	var medal := medal_for(points)
	if medal == Medal.DIAMOND:
		return 0
	return threshold_of((medal + 1) as Medal) - points


#The shared curve: 1 at "best", 0 at "worst", clipped at both ends and bent by "gamma"
static func share(value: float, best: float, worst: float, gamma := 1.0) -> float:
	if is_equal_approx(best, worst):
		return 0.0
	return pow(clampf((worst - value) / (worst - best), 0.0, 1.0), gamma)


#The race: "progress" is the share of the course covered (0 to 1), used only when the goal was not reached
func race_points(finished: bool, seconds: float, attempts_left: int, progress: float) -> int:
	if not finished:
		return roundi(race_unfinished * clampf(progress, 0.0, 1.0))
	var total := race_finish + race_time_points * share(seconds, race_best, race_worst, race_gamma) \
		+ race_attempt_points * clampi(attempts_left, 0, race_attempts)
	return _whole(total)


func street_points(seconds: float, hits: int) -> int:
	if seconds >= street_seconds:
		return _whole(street_survive + maxi(street_clean - street_hit_cost * maxi(hits, 0), 0))
	return _whole(street_partial * pow(clampf(seconds / street_seconds, 0.0, 1.0), street_gamma))


func drop_points(seconds: float) -> int:
	return _whole(MAX_POINTS * pow(clampf(seconds / drop_seconds, 0.0, 1.0), drop_gamma))


#One trend: "left" is the share of the time between the par and the limit that was still left (0 to 1), "place" starts at 1
func trend_points(left: float, place: int) -> int:
	var factor := trend_places[clampi(place - 1, 0, trend_places.size() - 1)]
	return roundi(trend_round_points * (trend_base + (1.0 - trend_base) * clampf(left, 0.0, 1.0)) * factor)


#Followers of one photo for somebody inside the frame; "crowd" counts everybody inside, bots too
func selfie_followers(centered: bool, posing: bool, crowd: int) -> int:
	var base := selfie_inside
	if centered:
		base += selfie_center
	if posing:
		base += selfie_pose
	if centered and posing:
		base += selfie_perfect
	return roundi(base * selfie_crowd[clampi(crowd - 1, 0, selfie_crowd.size() - 1)])


func selfie_points(followers: int) -> int:
	return _whole(MAX_POINTS * pow(clampf(followers / selfie_best, 0.0, 1.0), selfie_gamma))


#The most followers a round can give: every photo alone, in the centre and posing
func selfie_max_followers() -> int:
	return selfie_followers(true, true, 1) * selfie_photos


func _whole(value: float) -> int:
	return clampi(roundi(value), 0, MAX_POINTS)
