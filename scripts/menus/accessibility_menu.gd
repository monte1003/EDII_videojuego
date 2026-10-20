extends MenuPage


func _ready() -> void:
	super()
	add_choice("Filtro de daltonismo", ColorFilter.MODE_NAMES, ColorFilter.mode, ColorFilter.set_mode)
