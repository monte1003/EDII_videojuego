class_name TrendSettings
extends Resource

#Every number that tunes the trend war; the rules, the bubbles and the help all read them from here

@export_group("Rounds")
#Seconds each zone is played; the five zones come one after the other, each once, in an order drawn with the seed
@export var zone_seconds := 24.0
#Seconds the first zone is announced before its bubbles are born, and how long before the end of a zone the next one is announced (the
#players may already run there)
@export var reveal_seconds := 3.5
@export var next_notice := 4.0
#Trends to complete for the round to count as won
@export var win_trends := 10
#The seed of the game (the order of the zones, the trends and the bubbles); 0 draws a new one every time
@export var random_seed := 0
#Trends per second a good player completes in each zone (jump challenge, airplane mode, sea of memes, locked screen and rain of likes),
#measured with the test pilot that makes no mistakes; the par of the round adds them up
@export var zone_rates: Array[float] = [0.55, 0.34, 0.27, 0.33, 0.16]
#With more players the bubbles are shared and the shoves cost time: the par drops by this share for each player after the first
@export var crowd_share := 0.1

@export_group("Bubbles")
#Bubbles in the zone at the start of its round and at its end, and this many more for each player after the first
@export var bubbles_start := 4
@export var bubbles_end := 9
@export var bubbles_per_player := 2
#Seconds a ring on the floor shows where a bubble is about to be born, how long a point rests after its bubble goes, how close to a player
#(meters) a new one is never born, and how old a bubble gets before it moves somewhere else
@export var spawn_notice := 0.8
@export var point_rest := 1.5
@export var spawn_clear := 4.0
@export var bubble_life := 12.0
#How close a player must be to a bubble to touch it: around it, and over or under the middle of the body
@export var touch_radius := 1.45
@export var touch_height := 1.4
#Seconds a bubble that is not the one of a player keeps trembling after it went through it
@export var wobble_rest := 0.6
#The viral bubble: once per zone, between these shares of its time, worth this many trends; it is the trend of everybody
@export var viral_window := Vector2(0.35, 0.7)
@export var viral_value := 3

@export_group("Zones")
#A pad of airplane mode throws the player toward the other side this fast
@export var pad_kick := 5.0
#A fall in the sea of memes: seconds dazed back on the dock
@export var pond_stun := 1.0
#A like that lands on somebody: how fast it throws it out and how long it dazes
@export var like_push := 7.5
@export var like_stun := 0.45


#The trends a good player completes in the whole round: each zone at its rate, a little less with more players to share the bubbles
func par_for(player_count: int) -> float:
	var total := 0.0
	for rate in zone_rates:
		total += rate * zone_seconds
	return total * (1.0 - crowd_share * maxi(player_count - 1, 0))
