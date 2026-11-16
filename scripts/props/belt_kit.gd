class_name BeltKit
extends RefCounted

#The look of a conveyor belt, the same in every map: the moving surface sits a little sunken between two soft candy rails with round
#ends, and a striped drum turns under each end, so a belt reads as a machine with relief and not as a painted strip. Only the look:
#what the belt does is the business of its map

const RAIL_RADIUS := 0.17
const DRUM_RADIUS := 0.22


#Dresses "parent", whose origin is the middle of the top of the belt and whose -Z runs along it, with its rails and its drums
static func dress(parent: Node3D, length: float, width: float, color: Color) -> void:
	var rail_paint := PartyKit.candy(PartyKit.WHITE, color, 2.0, length * 1.2)
	for side: float in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var tube := CapsuleMesh.new()
		tube.radius = RAIL_RADIUS
		tube.height = length + RAIL_RADIUS * 2.0
		tube.radial_segments = 12
		tube.rings = 2
		rail.mesh = tube
		rail.material_override = rail_paint
		rail.rotation.x = PI / 2.0
		rail.position = Vector3(side * (width / 2.0 - RAIL_RADIUS * 0.6), RAIL_RADIUS * 0.45, 0.0)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(rail)
	var drum_paint := PartyKit.candy(Color("4a4060"), color.lightened(0.2), 10.0)
	for end: float in [-1.0, 1.0]:
		var drum := MeshInstance3D.new()
		var roller := CylinderMesh.new()
		roller.top_radius = DRUM_RADIUS
		roller.bottom_radius = DRUM_RADIUS
		roller.height = width - RAIL_RADIUS * 2.4
		roller.radial_segments = 16
		roller.rings = 1
		drum.mesh = roller
		drum.material_override = drum_paint
		drum.rotation.z = PI / 2.0
		drum.position = Vector3(0.0, -DRUM_RADIUS * 0.35, end * length / 2.0)
		drum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(drum)
