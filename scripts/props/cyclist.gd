class_name Cyclist
extends Node3D

#A rider of the street: a Citizen pedaling a Bicycle while it looks at the phone; the pedals and the wheels follow its speed

#Where the rider sits on the bike (the rider is lowered by its animation, so it is lifted back here)
const RIDER_OFFSET := Vector3(0.0, 0.3, -0.12)
const FRAME_COLORS: Array[Color] = [Color("ff6f91"), Color("4fd6e8"), Color("ffd23f"), Color("6a52e0"), Color("ff9a3c")]
#Pedal turns per second at most, so the legs never blur into nothing
const MAX_PEDAL_SPEED := 2.2

var rider: Citizen
var _bike: Bicycle


func build(rng: RandomNumberGenerator) -> void:
	_bike = Bicycle.new()
	add_child(_bike)
	_bike.build(FRAME_COLORS[rng.randi() % FRAME_COLORS.size()])
	rider = Citizen.new()
	rider.build(Citizen.Pose.RIDE, rng, rng.randf())
	rider.position = RIDER_OFFSET
	add_child(rider)
	rider.add_pedals()


#Moves the wheels and the legs as if the bike covered "distance" meters in "delta" seconds
func roll(distance: float, delta: float) -> void:
	_bike.roll(distance)
	rider.set_speed(minf(distance / maxf(delta, 0.0001) / 5.0, MAX_PEDAL_SPEED))
