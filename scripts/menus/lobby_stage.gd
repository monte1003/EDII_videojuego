class_name LobbyStage
extends Node3D

#The 3D waiting room: a podium for every place of the lobby, with the character of whoever sits there

const SLOT_X: Array[float] = [-1.15, 1.15, -3.45, 3.45]
const SLOT_Z: Array[float] = [0.0, 0.0, -0.4, -0.4]
const PODIUM_RADIUS := 0.8
const PODIUM_HEIGHT := 0.16
const MODEL_SCALE := 1.6
const PODIUM_COLOR := Color("f5f1fd")
const SKIRT_COLOR := Color("d3c8f0")
const EMPTY_RING := Color("b9aee6")

var _places: Array[Dictionary] = []


func _ready() -> void:
	_build_environment()
	for index in SLOT_X.size():
		_places.append(_build_place(index))


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
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 28, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0.0, 1.6, 9.6)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.85, 0.0))
	camera.current = true


func _build_place(index: int) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(SLOT_X[index], 0.0, SLOT_Z[index])
	add_child(root)

	var shadow := _cylinder(PODIUM_RADIUS + 0.22, 0.01, _shadow())
	shadow.position.y = 0.005
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	var skirt := _cylinder(PODIUM_RADIUS + 0.06, 0.08, _solid(SKIRT_COLOR))
	skirt.position.y = 0.05
	root.add_child(skirt)
	var top := _cylinder(PODIUM_RADIUS, PODIUM_HEIGHT, _solid(PODIUM_COLOR))
	top.position.y = PODIUM_HEIGHT / 2.0 + 0.05
	root.add_child(top)
	var ring_material := _glow(EMPTY_RING, 0.25)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = PODIUM_RADIUS - 0.07
	torus.outer_radius = PODIUM_RADIUS - 0.03
	torus.rings = 56
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = ring_material
	ring.position.y = PODIUM_HEIGHT + 0.052
	root.add_child(ring)

	var holder := Node3D.new()
	holder.position.y = PODIUM_HEIGHT + 0.05
	root.add_child(holder)

	var name_label := _label3d("", UiKit.BOLD_FONT, 46, Palette.INK)
	name_label.position = Vector3(0.0, PODIUM_HEIGHT + 0.05 + 2.04, 0.0)
	root.add_child(name_label)
	var status_label := _label3d("", UiKit.BODY_FONT, 36, Palette.INK_SOFT)
	status_label.position = Vector3(0.0, PODIUM_HEIGHT + 0.05 + 1.8, 0.0)
	root.add_child(status_label)

	return {"root": root, "holder": holder, "ring": ring_material, "name": name_label,
		"status": status_label, "model": null, "character": null, "player_id": -1}


func _fill(place: Dictionary, slot: PlayerSlot, is_local: bool) -> void:
	if slot == null:
		_set_model(place, null)
		place["player_id"] = -1
		_tint(place["ring"], EMPTY_RING, 0.25)
		_text(place["name"], "Libre", Color(Palette.INK_SOFT, 0.55))
		_text(place["status"], "", Palette.INK_SOFT)
		return
	place["player_id"] = slot.player_id
	_set_model(place, slot.character)
	_tint(place["ring"], slot.character.accent_color, 1.4 if slot.ready else 0.7)
	_text(place["name"], slot.display_name + ("  ·  Tú" if is_local else ""), Palette.INK)
	if slot.ready:
		_text(place["status"], "Listo", Palette.TEAL)
	else:
		_text(place["status"], "Sin confirmar", Color(Palette.INK_SOFT, 0.8))


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


func _label3d(text: String, font: Font, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = size
	label.pixel_size = 0.0052
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 0
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
	material.roughness = 0.8
	return material


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


#Soft contact shadow that keeps the podiums from floating on the flat background
func _shadow() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(Palette.INK, 0.09)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
