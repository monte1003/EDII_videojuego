class_name TrendSettings
extends Resource

#Every number that tunes the trend war; the rules, the bubbles, the bots and the help all read them from here

@export_group("Rounds")
#Seconds to complete each trend and how many kinds each one has
@export var limits: Array[float] = [18.0, 21.0, 23.0, 26.0, 28.0]
@export var lengths: Array[int] = [2, 3, 3, 4, 4]
#Seconds the trend is shown before its clock starts, and the pause after it
@export var reveal_seconds := 2.5
@export var rest_seconds := 1.2
#From this trend on (counting from 0) a kind can come twice in the chain
@export var repeat_from := 2
#Trends to complete for the round to count as won
@export var win_trends := 3
#The par of a trend is this share of the walk to each of its bubbles: the average walk between two bubbles of a kind on the
#graph of the map, or the reach within which the one that is needed is always kept, whichever is shorter
@export var par_share := 0.5

@export_group("Bubbles")
#Bubbles alive on the map at any moment, and how many of one kind there can be
@export var bubble_target := 22
@export var min_per_kind := 3
@export var max_per_kind := 5
#Seconds a bubble lives, between these two, and the last seconds of it in which it blinks
@export var life_seconds := Vector2(9.0, 13.0)
@export var aging_seconds := 3.0
#A bubble never appears closer than this many seconds on foot to a player, and a point rests this long after losing its bubble
@export var spawn_clear_seconds := 1.2
@export var point_rest := 2.0
#The kind a player has to fetch always has a bubble closer than this many seconds on foot
@export var reach_seconds := 6.0
#How close a player must be to a bubble to touch it
@export var touch_radius := 1.45
#Seconds a wrong bubble ignores the player it just bounced
@export var bounce_rest := 0.7
#The bubbles fade during the last seconds of a trend
@export var fade_seconds := 3.0
#From this trend on the bubbles drift in a slow circle of this radius
@export var drift_from := 4
@export var drift_radius := 1.1
@export var drift_speed := 0.55

@export_group("Shoves")
#Seconds a dropped item stays loose and can be picked up, and how long its owner cannot pick it back
@export var loose_seconds := 3.0
@export var loose_owner_rest := 1.0

@export_group("Haters")
#Bots in the maze in each trend, and how far from them a player has to be for them to notice it
@export var haters: Array[int] = [1, 1, 2, 2, 3]
@export var hater_sight := 13.0
