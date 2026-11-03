extends Node

signal screen_changed(id: StringName)

var tree := ScreenTree.new()

var current: StringName = &""

#The screen being loaded and the last one asked for meanwhile; it opens when the wipe ends
var _heading: StringName = &""
var _pending: ScreenTree.ScreenNode


func _ready() -> void:
	tree.add_root(&"main_menu", "Menú principal", "res://scenes/menus/main_menu.tscn")
	tree.add_screen(&"main_menu", &"character_select", "Personajes", "res://scenes/menus/character_select.tscn")
	tree.add_screen(&"character_select", &"lobby", "Sala", "res://scenes/menus/lobby.tscn")
	tree.add_screen(&"lobby", &"practice", "Práctica", "res://scenes/menus/practice_menu.tscn")
	tree.add_screen(&"lobby", &"warmup", "Calentamiento", "res://scenes/levels/warmup.tscn")
	tree.add_screen(&"lobby", &"round_intro", "Sorteo", "res://scenes/menus/round_intro.tscn")
	for info in MinigameCatalog.ENTRIES:
		tree.add_screen(&"lobby", info.id, info.title, info.scene_path)
	tree.add_screen(&"lobby", &"round_results", "Resultados de la ronda", "res://scenes/menus/round_results.tscn")
	tree.add_screen(&"lobby", &"session_results", "Fin de la partida", "res://scenes/menus/session_results.tscn")
	#Test menu of the main menu: opens any minigame straight away, outside a session
	tree.add_screen(&"main_menu", &"test_games", "Test", "res://scenes/menus/test_menu.tscn")
	tree.add_screen(&"main_menu", &"options", "Opciones", "res://scenes/menus/options_menu.tscn")
	tree.add_screen(&"options", &"controls", "Controles", "res://scenes/menus/controls_menu.tscn")
	tree.add_screen(&"options", &"graphics", "Gráficos", "res://scenes/menus/graphics_menu.tscn")
	tree.add_screen(&"options", &"accessibility", "Accesibilidad", "res://scenes/menus/accessibility_menu.tscn")
	current = tree.root.id
	#ScreenFader is the last autoload: connect once all of them exist
	_connect_fader.call_deferred()


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


#Loads the current screen again, for the restart of a minigame that runs on its own
func reload_current() -> void:
	var node := tree.find(current)
	if node != null:
		_change_to(node)


func children_of(id: StringName) -> Array[ScreenTree.ScreenNode]:
	var node := tree.find(id)
	return node.children if node != null else [] as Array[ScreenTree.ScreenNode]


#Root to screen, the trail each screen shows at the top
func trail(id: StringName) -> String:
	var names := PackedStringArray()
	for node in tree.path_to(id):
		names.append(node.title)
	return "  ›  ".join(names)


func title_of(id: StringName) -> String:
	var node := tree.find(id)
	return node.title if node != null else ""


#During a wipe the last request is kept, except a repeat of the screen being loaded (a double click)
func _change_to(node: ScreenTree.ScreenNode) -> void:
	if ScreenFader.busy:
		if node.id != _heading:
			_pending = node
		return
	_go(node)


func _go(node: ScreenTree.ScreenNode) -> void:
	current = node.id
	_heading = node.id
	screen_changed.emit(node.id)
	ScreenFader.change_scene(node.scene_path)


func _connect_fader() -> void:
	ScreenFader.finished.connect(_on_fader_finished)


func _on_fader_finished() -> void:
	_heading = &""
	var node := _pending
	_pending = null
	if node != null and node.id != current:
		_go(node)
