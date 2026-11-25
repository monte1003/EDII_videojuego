class_name SelfieFloor
extends RefCounted

#Floor tricks per player with no nodes: turntable, wax, carpet, mattress, boxes and live stage

#Wax grip and slow shove fade
const WAX_GRIP := 11.0
const WAX_PUSH_DECAY := 11.0
#Off the wax the slide ends almost at once
const DRY_GRIP := 60.0
const CARPET_SPEED := 0.55
const CARPET_JUMP := 0.75
#Mattress bounce threshold, share and cap
const BOUNCE_FROM := 3.0
const BOUNCE_SHARE := 0.55
const BOUNCE_MAX := 5.5
#Live stage lift speed
const BEAT_LIFT := 3.6

#What the floor does to one player in one step
class Effect:
	var drift := Vector3.ZERO
	var speed_scale := 1.0
	var jump_scale := 1.0
	#Shove fade on this floor; negative keeps the usual one
	var push_decay := -1.0
	#Mattress bounce speed, or 0
	var bounce := 0.0
	#Gift box throw, or zero
	var throw := Vector3.ZERO
	var trick := SelfieLayout.Trick.NONE


var layout: SelfieLayout
#Round seconds for the live stage beat
var clock := 0.0

#Per player slide speed and fastest fall since leaving the floor
var _slide: Dictionary = {}
var _fall: Dictionary = {}
var _beats: Dictionary = {}
#Last box pop that threw each player, so one pop throws once
var _popped: Dictionary = {}


func _init(map: SelfieLayout) -> void:
	layout = map


#One player step: feet, grounded, wanted ground speed and vertical speed
func step(player_id: int, at: Vector3, grounded: bool, wanted: Vector3, vertical: float, delta: float) -> Effect:
	var effect := Effect.new()
	var trick := layout.trick_at(at) if grounded else SelfieLayout.Trick.NONE
	effect.trick = trick
	var slide: Vector3 = _slide.get(player_id, wanted)
	if trick == SelfieLayout.Trick.WAX:
		slide = slide.move_toward(wanted, WAX_GRIP * delta)
		effect.drift = slide - wanted
		effect.push_decay = WAX_PUSH_DECAY
	else:
		slide = slide.move_toward(wanted, DRY_GRIP * delta)
	_slide[player_id] = slide
	match trick:
		SelfieLayout.Trick.SPIN:
			effect.drift = layout.spin_drift(at)
		SelfieLayout.Trick.CARPET:
			effect.speed_scale = CARPET_SPEED
			effect.jump_scale = CARPET_JUMP
		SelfieLayout.Trick.BEAT:
			var beat := floori(clock / SelfieLayout.BEAT_PERIOD)
			if beat != int(_beats.get(player_id, beat)):
				effect.bounce = BEAT_LIFT
			_beats[player_id] = beat
	if trick != SelfieLayout.Trick.BEAT:
		_beats.erase(player_id)
	if trick == SelfieLayout.Trick.UNBOX:
		var cell := layout.unbox_cell(at)
		var pop := cell * 100000 + floori((clock + float(cell * 7 % 9) * SelfieLayout.UNBOX_PERIOD / 9.0) / SelfieLayout.UNBOX_PERIOD)
		if SelfieLayout.unbox_popping(cell, clock) and int(_popped.get(player_id, -1)) != pop:
			_popped[player_id] = pop
			var away := at - layout.unbox_center(cell)
			away.y = 0.0
			if away.length() < 0.2:
				away = Vector3(cos(clock * 3.0), 0.0, sin(clock * 3.0))
			effect.throw = away.normalized() * SelfieLayout.UNBOX_THROW + Vector3(0.0, SelfieLayout.UNBOX_LIFT, 0.0)
	var fall: float = _fall.get(player_id, 0.0)
	if not grounded:
		_fall[player_id] = maxf(fall, -vertical)
	else:
		_fall[player_id] = 0.0
		if trick == SelfieLayout.Trick.PIT and fall > BOUNCE_FROM:
			effect.bounce = minf(fall * BOUNCE_SHARE, BOUNCE_MAX)
	return effect


#Player moved elsewhere: forget its slide and fall
func forget(player_id: int) -> void:
	_slide.erase(player_id)
	_fall.erase(player_id)
	_beats.erase(player_id)
	_popped.erase(player_id)
