class_name TrendIcons
extends Node

#The icon of each kind is a picture of the very toy that floats in its bubble: each toy is drawn once into a small image
#with its own camera and light, so what the row of the trend shows is exactly what there is to fetch

const SIZE := 192

#One picture per kind, shared by every row on the screen
static var textures: Array[Texture2D] = []


func _ready() -> void:
	textures.clear()
	for kind in TrendCatalog.COUNT:
		var view := SubViewport.new()
		view.size = Vector2i(SIZE, SIZE)
		view.own_world_3d = true
		view.transparent_bg = true
		view.msaa_3d = Viewport.MSAA_4X
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(view)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color.WHITE
		environment.ambient_light_energy = 0.85
		var world := WorldEnvironment.new()
		world.environment = environment
		view.add_child(world)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
		sun.light_energy = 0.9
		view.add_child(sun)
		var toy := TrendCatalog.make_toy(kind, 1.0)
		var box := PropKit.measure(toy)
		var widest := maxf(maxf(box.size.x, box.size.y), box.size.z)
		toy.scale = Vector3.ONE / maxf(widest, 0.01)
		toy.position = -box.get_center() * toy.scale
		var turned := Node3D.new()
		turned.rotation.y = 0.45
		turned.add_child(toy)
		view.add_child(turned)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.25
		camera.position = Vector3(0.0, 0.35, 3.0)
		view.add_child(camera)
		camera.look_at(Vector3.ZERO)
		textures.append(view.get_texture())


func _exit_tree() -> void:
	textures.clear()
