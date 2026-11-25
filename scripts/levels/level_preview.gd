@tool
class_name LevelPreview
extends Node3D

#Editor only: builds the level map from the game data so it shows without playing; nothing is saved

enum Map { FEED_RACE, SOCIAL_DROP, STREET, TREND_WAR, SELFIE }

@export var map := Map.FEED_RACE


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	var level := get_parent()
	match map:
		Map.FEED_RACE:
			var course := Level01World.new()
			add_child(course)
			var settings: Level01Settings = level.get("settings")
			course.build([], settings.belt_speed if settings != null else Level01Settings.new().belt_speed, Level01Tiles.new())
		Map.SOCIAL_DROP:
			var board := SocialDropWorld.new()
			add_child(board)
			var icons: Array[Texture2D] = []
			icons.assign(level.get("icons"))
			board.build(icons, RandomNumberGenerator.new())
		Map.STREET:
			var street := StreetWorld.new()
			add_child(street)
			var lanes: int = level.get("lane_count")
			var lane_width: float = level.get("lane_width")
			var spawn_x: float = level.get("spawn_x")
			var despawn_x: float = level.get("despawn_x")
			street.build(lanes * lane_width / 2.0, level.get("sidewalk_width"), lanes, spawn_x - 10.0, despawn_x + 10.0, level.get("end_x"))
		Map.TREND_WAR:
			var plaza := TrendLayout.new()
			var ground := ArenaWorld.new()
			add_child(ground)
			ground.build(plaza)
			var stage := ArenaStage.new()
			ground.add_child(stage)
			stage.build(plaza.reach(), 47, plaza.top_height())
			var zones := TrendZones.new()
			ground.add_child(zones)
			zones.build(plaza, TrendObstacles.new(plaza))
		Map.SELFIE:
			var studio := SelfieStage.new()
			add_child(studio)
			studio.build(SelfieLayout.new())
