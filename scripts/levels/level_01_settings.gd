class_name Level01Settings
extends Resource

#Every number that tunes level 1

@export_group("Round")
@export var time_limit := 150.0
@export var attempts := 3
@export var countdown_seconds := 3.0
#Seconds for the rest after the first arrival (0 waits for everybody)
@export var finish_window := 20.0
#0 picks a new feed each round; any other value repeats it
@export var random_seed := 0
#Protection after returning from a fall
@export var respawn_protection := 2.0

@export_group("Push")
#Comment push speed (m/s)
@export var push_speed := 8.0
#Seconds the same blow cannot hit again
@export var hit_immunity := 1.1

@export_group("Traps")
#Throw speed per obstacle: bar, axe, like, wheel and giant ball
@export var spinner_push := 13.0
@export var axe_push := 15.0
@export var punch_push := 13.5
@export var roller_push := 9.0
@export var boulder_push := 12.0

@export_group("Feed")
#First feed change and the wait between changes
@export var feed_first := 10.0
@export var feed_interval := Vector2(7.0, 11.0)
@export var feed_warning := 3.0
@export var feed_duration := 8.0
#Second feed delay, so two bridges can be down (0 turns it off)
@export var feed_extra_delay := 26.0
#Belt speed in m/s (a player runs at 5)
@export var belt_speed := 3.4
