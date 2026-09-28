extends Node

const HOVER := preload("res://assets/ui/sounds/hover.wav")
const CLICK := preload("res://assets/ui/sounds/click.wav")

var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer


func _ready() -> void:
	_hover_player = _make_player(HOVER, -12.0)
	_click_player = _make_player(CLICK, -6.0)


func play_hover() -> void:
	_hover_player.play()


func play_click() -> void:
	_click_player.play()


func _make_player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	player.bus = "Master"
	add_child(player)
	return player
