class_name StreetWorld
extends Node3D

#Static scenery of the street minigame; the street runs along X and the end line is at +X

const SIDEWALK_HEIGHT := 0.12
const HEADING_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const BUILDING_COLORS: Array[Color] = [
	Color("cdbcf7"), Color("f8a4b3"), Color("bcc8fa"), Color("f6d29a"), Color("a9dcc8"),
]


func build(street_half_width: float, sidewalk_width: float, lane_count: int,
		from_x: float, to_x: float, end_x: float) -> void:
	var length := to_x - from_x
	var center_x := (from_x + to_x) / 2.0
	var outer := street_half_width + sidewalk_width

	_box(Vector3(center_x, -0.06, 0.0), Vector3(length, 0.1, outer * 2.0 + 40.0), Color("9fd3a8"))
	_box(Vector3(center_x, -0.03, 0.0), Vector3(length, 0.06, street_half_width * 2.0), Color("4b4e63"))
	for side in [-1.0, 1.0]:
		_box(Vector3(center_x, SIDEWALK_HEIGHT / 2.0, side * (street_half_width + sidewalk_width / 2.0)),
			Vector3(length, SIDEWALK_HEIGHT, sidewalk_width), Color("ddd6ea"))
		_box(Vector3(center_x, (SIDEWALK_HEIGHT + 0.02) / 2.0, side * (street_half_width + 0.12)),
			Vector3(length, SIDEWALK_HEIGHT + 0.02, 0.24), Color("f5f1fb"))

	var lane_width := street_half_width * 2.0 / lane_count
	for lane in range(1, lane_count):
		var z := -street_half_width + lane * lane_width
		var x := from_x
		while x < to_x:
			_box(Vector3(x + 1.0, 0.005, z), Vector3(2.0, 0.01, 0.15), Color("f5f1fb"))
			x += 4.0

	_build_end_line(end_x, outer)
	_build_buildings(from_x, to_x, outer)


func _build_end_line(end_x: float, outer: float) -> void:
	_box(Vector3(end_x, SIDEWALK_HEIGHT + 0.02, 0.0), Vector3(0.6, 0.04, outer * 2.0), Palette.CORAL)
	for side in [-1.0, 1.0]:
		_box(Vector3(end_x, 1.2, side * (outer + 0.4)), Vector3(0.4, 2.4, 0.4), Palette.CORAL)
	var label := Label3D.new()
	label.text = "FIN"
	label.font = HEADING_FONT
	label.font_size = 160
	label.pixel_size = 0.01
	label.modulate = Palette.PAPER
	label.outline_modulate = Palette.CORAL
	label.outline_size = 36
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(end_x, 3.2, -outer - 0.4)
	add_child(label)


#Simple blocks on the far side only, so they never hide the street from the camera
func _build_buildings(from_x: float, to_x: float, outer: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := from_x
	while x < to_x:
		var width := rng.randf_range(4.0, 7.0)
		var height := rng.randf_range(3.5, 9.0)
		var color := BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()]
		_box(Vector3(x + width / 2.0, height / 2.0, -outer - 4.5), Vector3(width - 0.4, height, 6.0), color)
		x += width


func _box(center: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	add_child(instance)
