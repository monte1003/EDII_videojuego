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

@export_group("Bubbles")
@export var copies_per_kind := 4
#Seconds a fetched bubble takes to come back somewhere else
@export var respawn_seconds := 4.0
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
#Bots on the map in each trend
@export var haters: Array[int] = [1, 1, 2, 2, 3]
