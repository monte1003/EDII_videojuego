class_name Level01Settings
extends Resource

#Every number that tunes level 1; the rules, the bots and the help texts all read them from here

@export_group("Round")
@export var time_limit := 120.0
@export var attempts := 3
@export var countdown_seconds := 3.0
#Seconds the players run before the bots are released
@export var bot_head_start := 5.0

@export_group("Bots")
#Bots of a round with one player; each extra player adds "bots_per_extra_player", up to "max_bots"
@export_range(1, 4) var base_bot_count := 3
@export_range(0, 2) var bots_per_extra_player := 1
@export_range(1, 4) var max_bots := 4
#Bot speed as a fraction of the player's speed (slightly below 1)
@export_range(0.3, 1.0) var bot_speed_ratio := 0.86
@export var bot_recalc_interval := 0.4
@export var bot_lose_time := 5.0
#0 picks a different random spawn each round; any other value repeats it
@export var random_seed := 0

@export_group("Detection")
@export var detection_radius := 18.0
@export var silenced_detection_radius := 6.0

@export_group("Abilities")
@export var block_duration := 6.0
@export var block_cooldown := 15.0
@export var silence_duration := 8.0
@export var silence_cooldown := 20.0
@export var refuge_duration := 3.0
@export var refuge_cooldown := 20.0
@export var respawn_protection := 2.0
@export var station_radius := 4.0
@export var refuge_radius := 3.6

@export_group("Push")
@export var push_speed := 9.0
@export var push_lift := 3.0
#Seconds in which the same shove cannot hit a player again
@export var hit_immunity := 1.5


func bot_count_for(player_count: int) -> int:
	return clampi(base_bot_count + bots_per_extra_player * (player_count - 1), 1, max_bots)
