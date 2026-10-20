extends MenuPage

const LEVELS: Array[int] = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]


func _ready() -> void:
	super()
	var current := LEVELS.find(get_viewport().msaa_3d)
	add_choice("Suavizado de bordes", ["Desactivado", "2x", "4x"] as Array[String], maxi(current, 0), _set_antialiasing)


func _set_antialiasing(index: int) -> void:
	get_viewport().msaa_3d = LEVELS[index] as Viewport.MSAA
