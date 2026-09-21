extends Node

signal screen_changed(id: StringName)

var tree := ScreenTree.new()

var current: StringName = &""


func _ready() -> void:
	tree.add_root(&"main_menu", "Menú principal", "res://scenes/menus/main_menu.tscn")
	tree.add_screen(&"main_menu", &"character_select", "Personajes", "res://scenes/menus/character_select.tscn")
	tree.add_screen(&"character_select", &"test_world", "Partida", "res://scenes/levels/test_world.tscn")
	tree.add_screen(&"main_menu", &"options", "Opciones", "res://scenes/menus/options_menu.tscn")
	tree.add_screen(&"options", &"controls", "Controles", "res://scenes/menus/controls_menu.tscn")
	tree.add_screen(&"options", &"graphics", "Gráficos", "res://scenes/menus/graphics_menu.tscn")
	tree.add_screen(&"options", &"accessibility", "Accesibilidad", "res://scenes/menus/accessibility_menu.tscn")
	current = tree.root.id


#Each screen says who it is when it loads, so running a scene on its own also works
func mark_current(id: StringName) -> void:
	if not tree.has(id):
		push_error("ScreenFlow: la pantalla %s no está en el árbol" % id)
		return
	current = id
	screen_changed.emit(id)


func open(id: StringName) -> void:
	var node := tree.find(id)
	if node == null:
		push_error("ScreenFlow: no se puede abrir la pantalla %s" % id)
		return
	_change_to(node)


#Going back is the parent link, so no screen needs to know where it came from
func back() -> void:
	var node := tree.find(current)
	if node == null or node.parent == null:
		return
	_change_to(node.parent)


func go_to_root() -> void:
	_change_to(tree.root)


func children_of(id: StringName) -> Array[ScreenTree.ScreenNode]:
	var node := tree.find(id)
	return node.children if node != null else [] as Array[ScreenTree.ScreenNode]


#Root to screen, the trail each screen shows at the top
func trail(id: StringName) -> String:
	var names := PackedStringArray()
	for node in tree.path_to(id):
		names.append(node.title)
	return " > ".join(names)


func title_of(id: StringName) -> String:
	var node := tree.find(id)
	return node.title if node != null else ""


func _change_to(node: ScreenTree.ScreenNode) -> void:
	current = node.id
	screen_changed.emit(node.id)
	get_tree().change_scene_to_file(node.scene_path)
