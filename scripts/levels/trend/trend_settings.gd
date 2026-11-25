class_name TrendSettings
extends Resource

#Every number that tunes the trend war

@export_group("Rounds")
#Seconds per zone; each zone once in a seed order
@export var zone_seconds := 24.0
#First zone notice, and how early the next zone is announced
@export var reveal_seconds := 3.5
@export var next_notice := 4.0
#Trends needed to win the round
@export var win_trends := 10
#Game seed; 0 draws a new one
@export var random_seed := 0
#Trends per second of a good player per zone, measured by the test pilot; the par adds them
@export var zone_rates: Array[float] = [0.55, 0.34, 0.27, 0.33, 0.16]
#Par drop per extra player
@export var crowd_share := 0.1

@export_group("Bubbles")
#Bubbles at the start and end of a zone, plus per extra player
@export var bubbles_start := 4
@export var bubbles_end := 9
@export var bubbles_per_player := 2
#Ring time, point rest, minimum distance to players and bubble age before moving
@export var spawn_notice := 0.8
@export var point_rest := 1.5
@export var spawn_clear := 4.0
@export var bubble_life := 12.0
#Touch reach around the bubble and over or under the body middle
@export var touch_radius := 1.45
@export var touch_height := 1.4
#Wobble rest after passing through
@export var wobble_rest := 0.6
#Viral bubble: once per zone in this time window, worth this many trends
@export var viral_window := Vector2(0.35, 0.7)
@export var viral_value := 3

@export_group("Zones")
#Gravity pad throw speed
@export var pad_kick := 5.0
#Daze seconds after falling in the meme sea
@export var pond_stun := 1.0
#Like throw speed and daze
@export var like_push := 7.5
@export var like_stun := 0.45


#Round par: each zone at its rate, a little less with more players
func par_for(player_count: int) -> float:
	var total := 0.0
	for rate in zone_rates:
		total += rate * zone_seconds
	return total * (1.0 - crowd_share * maxi(player_count - 1, 0))
