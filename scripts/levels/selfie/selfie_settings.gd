class_name SelfieSettings
extends Resource

#Every number that tunes the perfect selfie

@export_group("Photos")
@export var photo_count := 8
#Seconds to fly, move the frame, hold it blinking and show the result
@export var travel_seconds := 4.2
@export var frame_seconds := 5.6
@export var lock_seconds := 1.4
@export var lock_end := 1.0
@export var reveal_seconds := 3.1
#Next photo at most this many seconds away on foot, so a fifth slower still arrives
@export var reach_seconds := 8.8
#Photos needed to win the round
@export var win_photos := 4

@export_group("Frame")
#Frame side from the first photo to the last
@export var frame_start := 5.0
@export var frame_end := 3.0
#Frame wander from the first photo to the last
@export var wander_start := 0.0
@export var wander_end := 1.2
#Centre circle share of the frame side
@export var center_share := 0.25
#From this photo the frame feints aside in the last second
@export var feint_from := 5
@export var feint_seconds := 1.0
@export var feint_shift := 1.5
#Height range inside the frame, under the floor and over a jump
@export var below_floor := 0.5
@export var air_room := 1.0
#Air photos add this share of a pose (at most a tenth)
@export_range(0.0, 0.1) var air_share := 0.1

@export_group("Pose")
#Pose time needed at the shot; none means instant poses count
@export var pose_hold := 0.0
#Shove strength against a poser
@export var pose_shove_scale := 1.5
#Pose count and input strength that ends a pose
@export var pose_styles := 6
@export var pose_break_input := 0.3

@export_group("Power-ups")
#Jump and run boost, and duration
@export var jump_scale := 1.6
@export var speed_scale := 1.35
@export var boost_seconds := 6.0
@export var shield_seconds := 8.0
@export var power_respawn := 12.0
#The last player keeps power-ups this much longer
@export var behind_bonus := 1.35
@export var power_radius := 1.1

@export_group("Trolls")
#Troll zone bots with one to four players
@export var trolls: Array[int] = [2, 3, 3, 4]
#Troll speed as a share of a player's
@export var troll_speed := 0.72
#Index of the troll zone photo
@export var troll_photo := 3

@export_group("Hazards")
#Studio props throw and daze harder than other rounds
@export var hazard_push := 13.0
@export var hazard_stun := 0.95
#Turning pieces hit like a car: throw, flip and time down
@export var roller_push := 14.0
@export var roller_stun := 0.6
