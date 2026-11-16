class_name Level01Settings
extends Resource

#Every number that tunes level 1; the rules, the obstacles and the help texts all read them from here

@export_group("Round")
@export var time_limit := 150.0
@export var attempts := 3
@export var countdown_seconds := 3.0
#Seconds the rest have to arrive once somebody did; then the doors of the goal close
@export var finish_window := 20.0
#0 picks a different random feed each round; any other value repeats it
@export var random_seed := 0
#After coming back from a fall nothing hits the racer for this long
@export var respawn_protection := 2.0

@export_group("Push")
#How hard a comment pushes (m/s)
@export var push_speed := 8.0
#Seconds in which the same blow cannot hit a racer again
@export var hit_immunity := 1.1

@export_group("Traps")
#How fast each obstacle throws whoever it hits (m/s): a bar, an axe of comments, a like, a scroll wheel and a giant ball
@export var spinner_push := 13.0
@export var axe_push := 15.0
@export var punch_push := 13.5
@export var roller_push := 9.0
@export var boulder_push := 12.0

@export_group("Feed")
#The feed takes a fragile bridge down now and then: the first time, and the wait between two of them
@export var feed_first := 10.0
@export var feed_interval := Vector2(7.0, 11.0)
@export var feed_warning := 3.0
@export var feed_duration := 8.0
#A second feed starts this many seconds after the first one and works on its own, so two bridges can be down at once (0 turns it off)
@export var feed_extra_delay := 26.0
#Speed of the conveyor bridges in m/s (a player runs at 5)
@export var belt_speed := 3.4
