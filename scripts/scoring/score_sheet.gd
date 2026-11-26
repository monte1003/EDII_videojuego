class_name ScoreSheet
extends Resource

#Every scoring number in one place: tuning means changing these, never the rounds

enum Medal { NONE, BRONZE, SILVER, GOLD, DIAMOND }

const MAX_POINTS := 1000
const MEDAL_NAMES: Array[String] = ["Sin medalla", "Bronce", "Plata", "Oro", "Diamante"]

@export_group("Medals")
@export var bronze := 250
@export var silver := 500
@export var gold := 750
@export var diamond := 920

@export_group("Feed race")
#Goal reached, most the time adds, and each unused attempt
@export var race_finish := 300
@export var race_time_points := 550
@export var race_attempt_points := 50
@export var race_attempts := 3
#Best and worst arrival seconds that still add points
@export var race_best := 70.0
@export var race_worst := 150.0
@export var race_gamma := 1.15
#Goal not reached: up to this much by the share covered
@export var race_unfinished := 200

@export_group("Street")
@export var street_seconds := 60.0
#Whole round survived, most a clean run adds, and the cost of each hit
@export var street_survive := 600
@export var street_clean := 400
@export var street_hit_cost := 60
#Not survived: up to this much by the share of time held
@export var street_partial := 580
@export var street_gamma := 1.2

@export_group("SocialDrop")
@export var drop_seconds := 80.0
@export var drop_gamma := 1.25

@export_group("Trend war")
#Trends completed against the round par; reaching par gives all the points
@export var trend_gamma := 1.0

@export_group("Perfect selfie")
#Followers of each thing in a photo
@export var selfie_inside := 30
@export var selfie_center := 20
@export var selfie_pose := 60
@export var selfie_perfect := 20
#Photo value by how many are in it (1, 2, 3, 4+): 6 perfect and 1 inside give Diamond
@export var selfie_crowd: Array[float] = [1.3, 1.2, 1.15, 1.15]
@export var selfie_photos := 8
#Followers worth 1000 points and the curve up to them: one follower is one point
@export var selfie_best := 1000.0
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


#Starting points of a medal; 0 for none
func threshold_of(medal: Medal) -> int:
	return [0, bronze, silver, gold, diamond][medal]


#Points missing for the next medal; 0 at the best
func gap_to_next(points: int) -> int:
	var medal := medal_for(points)
	if medal == Medal.DIAMOND:
		return 0
	return threshold_of((medal + 1) as Medal) - points


#Shared curve: 1 at "best", 0 at "worst", clipped and bent by "gamma"
static func share(value: float, best: float, worst: float, gamma := 1.0) -> float:
	if is_equal_approx(best, worst):
		return 0.0
	return pow(clampf((worst - value) / (worst - best), 0.0, 1.0), gamma)


#"progress" is the share covered, used only without the goal
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


#"count" trends completed (viral counts more) against "par"
func trend_score(count: int, par: float) -> int:
	return roundi(MAX_POINTS * pow(clampf(count / maxf(par, 1.0), 0.0, 1.0), trend_gamma))


#Followers of a photo for someone in the frame; "crowd" counts bots too
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


#Most followers a round can give
func selfie_max_followers() -> int:
	return selfie_followers(true, true, 1) * selfie_photos


func _whole(value: float) -> int:
	return clampi(roundi(value), 0, MAX_POINTS)
