class_name Level01Settings
extends Resource

#Every number that tunes level 1; the rules, the bots and the help texts all read them from here

@export_group("Round")
@export var time_limit := 150.0
@export var attempts := 3
@export var countdown_seconds := 3.0
#Seconds the racers run before the bots are released
@export var bot_head_start := 2.0
#Seconds the rest have to arrive once somebody did; then the doors of the goal close
@export var finish_window := 20.0

@export_group("Bots")
#Bots of a round with one player; each extra player adds "bots_per_extra_player", up to "max_bots"
@export_range(1, 4) var base_bot_count := 4
@export_range(0, 2) var bots_per_extra_player := 0
@export_range(1, 4) var max_bots := 4
#Bot speed as a fraction of the player's speed (slightly below 1)
@export_range(0.3, 1.0) var bot_speed_ratio := 0.97
@export var bot_recalc_interval := 0.2
@export var bot_lose_time := 8.0
#0 picks a different random spawn each round; any other value repeats it
@export var random_seed := 0

@export_group("Detection")
@export var detection_radius := 30.0
@export var silenced_detection_radius := 8.0

@export_group("Abilities")
@export var block_duration := 6.0
@export var block_cooldown := 20.0
@export var silence_duration := 8.0
@export var silence_cooldown := 26.0
@export var refuge_duration := 2.5
@export var refuge_cooldown := 26.0
@export var respawn_protection := 2.0
@export var station_radius := 4.0
@export var refuge_radius := 3.6

@export_group("Push")
@export var push_speed := 12.0
#Seconds in which the same shove cannot hit a player again
@export var hit_immunity := 1.1

@export_group("Feed")
#The feed takes a fragile bridge down now and then: the first time, and the wait between two of them
@export var feed_first := 4.0
@export var feed_interval := Vector2(3.5, 6.5)
@export var feed_warning := 2.0
@export var feed_duration := 10.0
#A second feed starts this many seconds after the first one and works on its own, so two bridges can be down at once (0 turns it off)
@export var feed_extra_delay := 14.0
#Speed of the conveyor bridges in m/s (a player runs at 5)
@export var belt_speed := 3.4
#The push of a spinner, which is stronger than a bot's
@export var spinner_push := 13.0


func bot_count_for(player_count: int) -> int:
	return clampi(base_bot_count + bots_per_extra_player * (player_count - 1), 1, max_bots)
