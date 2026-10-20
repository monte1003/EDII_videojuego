class_name LobbyStage
extends Node3D

#The 3D waiting room: a podium for every place of the lobby, with the character of whoever sits there

const SLOT_X: Array[float] = [-1.1, 1.1, -3.2, 3.2]
const SLOT_Z: Array[float] = [0.0, 0.0, -0.45, -0.45]
const PODIUM_RADIUS := 0.86
const PODIUM_HEIGHT := 0.22
const MODEL_SCALE := 1.6
const DOT_COUNT := 18
const FLOOR_COLOR := Color("e7dcfb")
const PODIUM_COLOR := Color("cdbcf7")
const SKIRT_COLOR := Color("8e78d6")

var _places: Array[Dictionary] = []
var _clock := 0.0


func _ready() -> void:
	_build_environment()
	_build_floor()
	for index in SLOT_X.size():
		_places.append(_build_place(index))


#Waiting places keep their ring of dots breathing so they read as open
func _process(delta: float) -> void:
	_clock += delta
	for place in _places:
		var ghost: Node3D = place["ghost"]
		if not ghost.visible:
			continue
		var dots: Array = place["dots"]
		for index in dots.size():
			var wave := 0.55 + 0.45 * sin(_clock * 3.0 - index * 0.55)
			(dots[index] as MeshInstance3D).scale = Vector3.ONE * wave
		ghost.position.y = PODIUM_HEIGHT + 0.05 + 0.04 * sin(_clock * 1.8 + (place["root"] as Node3D).position.x)


func show_slots(slots: Array[PlayerSlot], local_id: int) -> void:
	for index in _places.size():
		var slot: PlayerSlot = slots[index] if index < slots.size() else null
		_fill(_places[index], slot, slot != null and slot.player_id == local_id)


#The character of that player jumps: the answer to pressing "Listo"
func cheer(player_id: int) -> void:
	for place in _places:
		if place["player_id"] == player_id and place["model"] != null:
			var model: CharacterModel = place["model"]
			model.set_state(false, true)
			#The timer belongs to the model, so it disappears with it
			model.create_tween().tween_callback(model.set_state.bind(false, false)).set_delay(0.55)


func _build_environment() -> void:
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 0.75
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 28, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 34.0
	camera.position = Vector3(0.0, 2.1, 7.8)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.02, 0.0))
	camera.current = true


#A wide slab under the podiums, like the card of a post
func _build_floor() -> void:
	var slab := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 5.6
	mesh.bottom_radius = 5.6
	mesh.height = 0.14
	mesh.radial_segments = 64
	slab.mesh = mesh
	slab.material_override = _solid(FLOOR_COLOR)
	slab.scale = Vector3(1.0, 1.0, 0.42)
	slab.position.y = -0.07
	add_child(slab)
	var edge := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 5.5
	torus.outer_radius = 5.62
	torus.rings = 64
	torus.ring_segments = 8
	edge.mesh = torus
	edge.material_override = _glow(Palette.PILL, 0.9)
	edge.scale = Vector3(1.0, 1.0, 0.42)
	add_child(edge)


func _build_place(index: int) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(SLOT_X[index], 0.0, SLOT_Z[index])
	add_child(root)

	var skirt := _cylinder(PODIUM_RADIUS + 0.1, 0.1, _solid(SKIRT_COLOR))
	skirt.position.y = 0.05
	root.add_child(skirt)
	var top := _cylinder(PODIUM_RADIUS, PODIUM_HEIGHT, _solid(PODIUM_COLOR))
	top.position.y = PODIUM_HEIGHT / 2.0 + 0.05
	root.add_child(top)
	var ring_material := _glow(Palette.LILAC, 0.6)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = PODIUM_RADIUS - 0.05
	torus.outer_radius = PODIUM_RADIUS + 0.03
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = ring_material
	ring.position.y = PODIUM_HEIGHT + 0.05
	root.add_child(ring)

	var holder := Node3D.new()
	holder.position.y = PODIUM_HEIGHT + 0.05
	root.add_child(holder)

	var ghost := Node3D.new()
	ghost.position.y = PODIUM_HEIGHT + 0.05
	root.add_child(ghost)
	var silhouette := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.36
	capsule.height = 1.45
	silhouette.mesh = capsule
	silhouette.material_override = _glass(Color(Palette.PAPER, 0.22))
	silhouette.position.y = 0.75
	ghost.add_child(silhouette)
	var mark := _label3d("?", 110, Color(Palette.INK_SOFT, 0.55))
	mark.position.y = 0.78
	ghost.add_child(mark)
	var dots: Array[MeshInstance3D] = []
	var dot_material := _glow(Palette.LILAC, 0.5)
	for dot_index in DOT_COUNT:
		var angle := TAU * dot_index / DOT_COUNT
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.045
		sphere.height = 0.09
		dot.mesh = sphere
		dot.material_override = dot_material
		dot.position = Vector3(cos(angle) * (PODIUM_RADIUS - 0.02), PODIUM_HEIGHT + 0.07, sin(angle) * (PODIUM_RADIUS - 0.02))
		root.add_child(dot)
		dots.append(dot)

	var name_label := _label3d("", 46, Palette.INK)
	name_label.position = Vector3(0.0, PODIUM_HEIGHT + 0.05 + 2.02, 0.0)
	root.add_child(name_label)
	var status_label := _label3d("", 30, Palette.INK_SOFT)
	status_label.position = Vector3(0.0, PODIUM_HEIGHT + 0.05 + 1.78, 0.0)
	root.add_child(status_label)

	return {"root": root, "holder": holder, "ghost": ghost, "dots": dots, "ring": ring_material,
		"name": name_label, "status": status_label, "model": null, "character": null, "player_id": -1}


func _fill(place: Dictionary, slot: PlayerSlot, is_local: bool) -> void:
	var occupied := slot != null
	(place["ghost"] as Node3D).visible = not occupied
	for dot in place["dots"]:
		(dot as MeshInstance3D).visible = not occupied
	if not occupied:
		_set_model(place, null)
		place["player_id"] = -1
		_tint(place["ring"], Palette.LILAC, 0.6)
		_text(place["name"], "LIBRE", Color(Palette.INK_SOFT, 0.85))
		_text(place["status"], "Esperando jugador", Color(Palette.INK_SOFT, 0.85))
		return
	place["player_id"] = slot.player_id
	_set_model(place, slot.character)
	_tint(place["ring"], slot.character.accent_color, 1.6 if slot.ready else 0.9)
	_text(place["name"], slot.display_name + ("  ·  TÚ" if is_local else ""), Palette.INK)
	if slot.ready:
		_text(place["status"], "¡LISTO!", Palette.TEAL)
	else:
		_text(place["status"], "Sin confirmar", Palette.INK_SOFT)


func _set_model(place: Dictionary, character: CharacterData) -> void:
	if place["character"] == character:
		return
	if place["model"] != null:
		(place["model"] as Node).queue_free()
		place["model"] = null
	place["character"] = character
	if character == null or character.model_scene == null:
		return
	var model := character.model_scene.instantiate() as CharacterModel
	var holder: Node3D = place["holder"]
	holder.add_child(model)
	place["model"] = model
	holder.scale = Vector3.ONE * MODEL_SCALE * 0.6
	create_tween().tween_property(holder, "scale", Vector3.ONE * MODEL_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tint(material: StandardMaterial3D, color: Color, energy: float) -> void:
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = energy


func _text(label: Label3D, text: String, color: Color) -> void:
	label.text = text
	label.modulate = color


func _label3d(text: String, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UiKit.HEADING_FONT
	label.font_size = size
	label.pixel_size = 0.0052
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	label.outline_modulate = Color(Palette.PAPER, 0.95)
	label.modulate = color
	label.no_depth_test = true
	return label


func _cylinder(radius: float, height: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	instance.mesh = mesh
	instance.material_override = material
	return instance


func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	return material


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _glass(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Palette.PAPER
	material.emission_energy_multiplier = 0.35
	return material
