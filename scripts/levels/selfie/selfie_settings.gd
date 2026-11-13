class_name SelfieSettings
extends Resource

#Every number that tunes the perfect selfie; the rules, the drone, the power-ups and the help all read them from here

@export_group("Photos")
@export var photo_count := 8
#Seconds of each part of a photo: the drone flies there, the frame moves, the frame stays fixed and blinks, and the result shows
@export var travel_seconds := 4.2
@export var frame_seconds := 5.6
@export var lock_seconds := 1.4
#The last photos blink faster
@export var lock_end := 1.0
@export var reveal_seconds := 3.1
#The next photo is never farther than this many seconds on foot from the last one, when the bag allows it
@export var reach_seconds := 10.5
#Photos to be in for the round to count as won
@export var win_photos := 4

@export_group("Frame")
#Side of the frame in meters, from the first photo to the last
@export var frame_start := 6.5
@export var frame_end := 3.5
#How far the frame slides around while it moves, from the first photo to the last
@export var wander_start := 0.0
@export var wander_end := 1.6
#The centre circle is this share of the side of the frame
@export var center_share := 0.25
#From this photo on (counting from 0) the drone feints: the frame jumps aside in the last second before it stays fixed
@export var feint_from := 5
@export var feint_seconds := 1.0
@export var feint_shift := 2.2

@export_group("Pose")
#Seconds a pose must have lasted at the shot to count
@export var pose_hold := 0.8
#A shove pushes somebody who poses this much harder
@export var pose_shove_scale := 1.5
#How many poses and dances there are to pick from, and how hard the keys must be pressed for a move to end the pose
@export var pose_styles := 6
@export var pose_break_input := 0.3

@export_group("Power-ups")
#How much higher the jump goes and how much faster the run is, and for how long
@export var jump_scale := 1.6
@export var speed_scale := 1.35
@export var boost_seconds := 6.0
@export var shield_seconds := 8.0
@export var power_respawn := 12.0
#Whoever is last gets its power-ups for this much longer
@export var behind_bonus := 1.35
@export var power_radius := 1.1

@export_group("Photobombers")
#Bots on the map in each photo
@export var bombers: Array[int] = [1, 1, 1, 2, 2, 2, 3, 3]
