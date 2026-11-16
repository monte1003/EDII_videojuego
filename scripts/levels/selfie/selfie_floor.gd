class_name SelfieFloor
extends RefCounted

#What the floor of each set does to whoever stands on it, with no nodes and by player id: the turntable drags along its turn,
#the dance floor lets the run slide on (a shove too), the carpet slows the run and the jump, the bouncy floor of the pool throws
#back up whoever falls on it, the stage of the live set thumps to the beat and lifts whoever stands on it, and a gift box of the
#unboxing throws up and away whoever stands on it when it pops. The belts and the trampolines are the ones the arena already knows.
#The round applies the answer and moves "clock"

#A waxed floor: how fast the run catches up with what the keys ask (m/s each second) and how slowly a shove fades on it
const WAX_GRIP := 11.0
const WAX_PUSH_DECAY := 11.0
#Off the wax the slide is gone almost at once
const DRY_GRIP := 60.0
const CARPET_SPEED := 0.55
const CARPET_JUMP := 0.75
#A fall onto the mattress faster than this bounces back up with this share of its speed, never faster than the last number
const BOUNCE_FROM := 3.0
const BOUNCE_SHARE := 0.55
const BOUNCE_MAX := 5.5
#The thump of the live stage: how fast it lifts
const BEAT_LIFT := 3.6

#What the floor does to one player in one step
class Effect:
	var drift := Vector3.ZERO
	var speed_scale := 1.0
	var jump_scale := 1.0
	#How fast a shove fades on this floor; negative keeps the usual one
	var push_decay := -1.0
	#Speed up of a bounce of the mattress, or 0
	var bounce := 0.0
	#The throw of a gift box that pops, or zero
	var throw := Vector3.ZERO
	var trick := SelfieLayout.Trick.NONE


var layout: SelfieLayout
#Seconds of the round, for the beat of the live stage
var clock := 0.0

#Player id -> the speed the slide carries; player id -> the fastest fall since it left the floor
var _slide: Dictionary = {}
var _fall: Dictionary = {}
var _beats: Dictionary = {}
#Player id -> the last pop of a box that threw it, so one pop throws once
var _popped: Dictionary = {}


func _init(map: SelfieLayout) -> void:
	layout = map


#One step of a player: where its feet are, whether it stands on the floor, the speed its keys ask on the ground and its speed up
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


#The player was put somewhere else: nothing of its slide or its fall is left
func forget(player_id: int) -> void:
	_slide.erase(player_id)
	_fall.erase(player_id)
	_beats.erase(player_id)
	_popped.erase(player_id)
