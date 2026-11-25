class_name MusicBox
extends Node

#Looping track per screen, with a crossfade when the track changes

const FOLDER := "res://assets/audio/music/%s.ogg"
#Tracks whose file is not "<name>.ogg"
const FILES := {
	&"menu": "res://assets/audio/music/music game menu.mp3",
	&"level_01": "res://assets/audio/music/music game partidas.mp3",
	&"street_game": "res://assets/audio/music/music game la calle.ogg",
}
#Below the interface sounds
const VOLUME := -12.0
const FADE := 0.8
const TRACKS := {
	&"main_menu": &"menu", &"character_select": &"menu", &"lobby": &"menu", &"practice": &"menu", &"options": &"menu",
	&"controls": &"menu", &"graphics": &"menu", &"accessibility": &"menu", &"test_games": &"menu",
	&"warmup": &"warmup", &"round_intro": &"results", &"round_results": &"results", &"session_results": &"results",
	&"level_01": &"level_01", &"street_game": &"street_game", &"social_drop": &"social_drop", &"trend_war": &"trend_war",
	&"perfect_selfie": &"perfect_selfie", &"podium": &"", &"rejoin": &"results", &"fair_screen": &"",
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
	var path: String = FILES.get(track, FOLDER % track)
	if track == &"" or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	else:
		return
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.volume_db = -40.0
	add_child(_player)
	_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", VOLUME, FADE)
