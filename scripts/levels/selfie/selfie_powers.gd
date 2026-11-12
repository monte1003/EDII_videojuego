class_name SelfiePowers
extends Node3D

#The power-ups on their pedestals: a plump candy gem that floats and turns, with the sign of what it gives on both faces.
#An arrow up in green is the jump, a bolt in yellow is the speed and a shield in blue is the shield

const COLORS: Array[Color] = [Color("4fd38a"), Color("ffc928"), Color("35c3f2")]
const GEM_HEIGHT := 1.25
const SIGN_DEPTH := 0.07

var _gems: Array[Node3D] = []
var _signs: Array[Array] = []
var _shells: Array[MeshInstance3D] = []
var _clock := 0.0


func build(spots: Array[Vector3], kinds: Array[int]) -> void:
	for index in spots.size():
		var base := Node3D.new()
		base.position = spots[index]
		add_child(base)
		var foot := CylinderMesh.new()
		foot.top_radius = 0.62
		foot.bottom_radius = 0.8
		foot.height = 0.3
		foot.radial_segments = 20
		foot.rings = 1
		_piece(base, foot, PartyKit.candy(PartyKit.WHITE, PartyKit.VIOLET, 10.0, 0.0, 0.1), Vector3(0.0, 0.15, 0.0))
		var gem := Node3D.new()
		gem.position.y = GEM_HEIGHT
		base.add_child(gem)
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.12
		ball.radial_segments = 20
		ball.rings = 10
		_shells.append(_piece(gem, ball, null, Vector3.ZERO))
		var options: Array = []
		for kind in SelfieRules.POWER_COUNT:
			var mark := _make_sign(kind)
			gem.add_child(mark)
			options.append(mark)
		_gems.append(gem)
		_signs.append(options)
		set_kind(index, kinds[index], false)


#Shows the power-up of a pedestal, or hides it when "kind" is -1
func set_kind(pedestal: int, kind: int, pop := true) -> void:
	var gem := _gems[pedestal]
	gem.visible = kind >= 0
	if kind < 0:
		return
	_shells[pedestal].material_override = PartyKit.candy(COLORS[kind], COLORS[kind].lightened(0.35), 6.0, 1.2, 0.35)
	for option in SelfieRules.POWER_COUNT:
		(_signs[pedestal][option] as Node3D).visible = option == kind
	if pop:
		gem.scale = Vector3.ONE * 0.01
		create_tween().tween_property(gem, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_clock += delta
	for index in _gems.size():
		_gems[index].rotation.y = _clock * 1.4 + index
		_gems[index].position.y = GEM_HEIGHT + sin(_clock * 2.2 + index * 1.3) * 0.12


#The sign of a power-up as flat white shapes, once on each face of the gem
func _make_sign(kind: int) -> Node3D:
	var holder := Node3D.new()
	var white := PartyKit.paint(PartyKit.WHITE, 0.9, 0.3)
	for face: float in [-1.0, 1.0]:
		var side := Node3D.new()
		side.position.z = 0.47 * face
		holder.add_child(side)
		match kind:
			SelfieRules.Power.JUMP:
				var head := PrismMesh.new()
				head.size = Vector3(0.46, 0.3, SIGN_DEPTH)
				_piece(side, head, white, Vector3(0.0, 0.14, 0.0))
				var shaft := BoxMesh.new()
				shaft.size = Vector3(0.17, 0.3, SIGN_DEPTH)
				_piece(side, shaft, white, Vector3(0.0, -0.15, 0.0))
			SelfieRules.Power.SPEED:
				#A bolt: two slanted wedges that meet in the middle
				var wedge := PrismMesh.new()
				wedge.size = Vector3(0.26, 0.44, SIGN_DEPTH)
				wedge.left_to_right = 1.0
				_piece(side, wedge, white, Vector3(0.05, 0.17, 0.0)).rotation.z = PI
				wedge = PrismMesh.new()
				wedge.size = Vector3(0.26, 0.44, SIGN_DEPTH)
				wedge.left_to_right = 0.0
				_piece(side, wedge, white, Vector3(-0.05, -0.17, 0.0))
			SelfieRules.Power.SHIELD:
				var top := BoxMesh.new()
				top.size = Vector3(0.44, 0.24, SIGN_DEPTH)
				_piece(side, top, white, Vector3(0.0, 0.13, 0.0))
				var tip := PrismMesh.new()
				tip.size = Vector3(0.44, 0.3, SIGN_DEPTH)
				_piece(side, tip, white, Vector3(0.0, -0.14, 0.0)).rotation.z = PI
	return holder


func _piece(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
