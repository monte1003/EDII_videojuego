class_name MusicBox
extends Node

#The music of every screen: each screen has its track, played in a loop; going to a screen with another track fades one out while the
#other comes in, and a screen with the same track keeps it going. A track whose file is not in the game yet is just silence

const FOLDER := "res://assets/audio/music/%s.ogg"
const VOLUME := -9.0
const FADE := 0.8
#Track of each screen; the podium plays its own victory theme
const TRACKS := {
	&"main_menu": &"menu", &"character_select": &"menu", &"lobby": &"menu", &"practice": &"menu", &"options": &"menu",
	&"controls": &"menu", &"graphics": &"menu", &"accessibility": &"menu", &"test_games": &"menu",
	&"warmup": &"warmup", &"round_intro": &"results", &"round_results": &"results", &"session_results": &"results",
	&"level_01": &"level_01", &"street_game": &"street_game", &"social_drop": &"social_drop", &"trend_war": &"trend_war",
	&"perfect_selfie": &"perfect_selfie", &"podium": &"",
}

var _player: AudioStreamPlayer
var _track := &""
var _tween: Tween


func play_for(screen: StringName) -> void:
	var track: StringName = TRACKS.get(screen, _track)
	if track == _track:
		return
	_track = track
	var old := _player
	if old != null:
		var out := create_tween()
		out.tween_property(old, "volume_db", -40.0, FADE)
		out.tween_callback(old.queue_free)
	_player = null
	var path := FOLDER % track
	if track == &"" or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		return
	stream.loop = true
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.volume_db = -40.0
	add_child(_player)
	_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", VOLUME, FADE)
