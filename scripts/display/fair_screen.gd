extends Node

#The fair screen: the trailer of the game while there is no game (attract mode), inside the frame of the fair with the ranking of the
#day, and its link to the room, whose state only changes the light of the frame for now (the spectator, the podium and the real ranking
#come later). Players never touch it; the staff has two hidden keys: M mutes the sound and F2 shows the details of the connection

const STAGES := {"lobby": "SALA DE ESPERA", "warmup": "CALENTAMIENTO", "intro": "SORTEO Y CARGA", "playing": "EN JUEGO",
	"round_results": "RESULTADOS", "finished": "PARTIDA TERMINADA"}

var watch := NetWatch.new()
var reel := AttractReel.new()
var frame := FairFrame.new()

var _status_panel := PanelContainer.new()
var _status: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	#The main menu started its music for an instant before this screen: the trailer brings its own
	ScreenFlow.music.play_for(&"fair_screen")
	#A screen that runs for hours: no more frames than a common monitor shows
	Engine.max_fps = 60
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	reel.name = "Reel"
	add_child(reel)
	frame.name = "Frame"
	add_child(frame)
	reel.focus_changed.connect(frame.show_focus)
	watch.name = "Watch"
	add_child(watch)
	watch.changed.connect(_refresh)
	_build_status()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fair_mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	elif event.is_action_pressed("fair_status"):
		_status_panel.visible = not _status_panel.visible


func _refresh() -> void:
	frame.set_live(_live_line(), watch.connected and watch.stage != "lobby")
	var lines: Array[String] = [watch.status]
	var config := "feria.cfg: " + (watch.config_address if watch.config_address != "" else "sin dirección, se usa el anuncio de la red")
	if watch.address != "":
		var origin := "de feria.cfg" if watch.address == watch.config_address else "del anuncio de la red"
		lines.append("Sala en %s, %s · %s" % [watch.address, origin, config])
	else:
		lines.append(config)
	if watch.connected:
		lines.append(_game_line())
		lines.append(_player_lines())
		var kilobytes := ("%.1f" % (watch.bytes_per_second / 1024.0)).replace(".", ",")
		lines.append("Recibe %d mensajes/s · %s KB/s" % [watch.messages_per_second, kilobytes])
	lines.append("M: sonido · F2: ocultar")
	_status.text = "\n".join(lines)


#The light of the frame: whether there is a room, and what the game under way is doing
func _live_line() -> String:
	if not watch.connected:
		return "BUSCANDO LA SALA"
	if watch.stage == "lobby":
		return "SALA ABIERTA · %d EN LA SALA" % watch.net.room.size()
	if watch.stage == "warmup":
		return "EN VIVO · CALENTAMIENTO"
	if watch.stage == "finished":
		return "EN VIVO · PODIO"
	return "EN VIVO · RONDA %d DE %d" % [watch.round_index + 1, maxi(watch.plan.size(), 1)]


func _game_line() -> String:
	var stage: String = STAGES.get(watch.stage, watch.stage.to_upper())
	if watch.stage == "lobby":
		return "%s · %d en la sala" % [stage, watch.net.room.size()]
	if watch.round_index < 0 or watch.plan.is_empty() or watch.stage == "finished":
		return stage
	var info := MinigameCatalog.find(watch.plan[mini(watch.round_index, watch.plan.size() - 1)])
	var title := info.title if info != null else ""
	return "Ronda %d de %d · %s · %s" % [watch.round_index + 1, watch.plan.size(), title, stage]


#Everybody in the room with its character and its points: the totals the server sent at the end, or the sum of the rounds so far
func _player_lines() -> String:
	var lines: Array[String] = []
	for member in watch.net.room:
		var id := int(member.get("id", 0))
		var total := watch.total_of(id)
		for entry in watch.finals:
			if int(entry.get("id", 0)) == id:
				total = int(entry.get("total", total))
		var character := GameSession.character_by_id(StringName(str(member.get("character", "fire"))))
		var line := "%s · %s · %d pts" % [str(member.get("name", "")), character.display_name, total]
		if not bool(member.get("connected", true)):
			line += " · desconectado"
		lines.append(line)
	return "\n".join(lines)


#The details of the connection for the staff, hidden until F2
func _build_status() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var card := UiKit.card_style(0.95, 22)
	card.content_margin_left = 20.0
	card.content_margin_right = 20.0
	card.content_margin_top = 14.0
	card.content_margin_bottom = 14.0
	_status_panel.add_theme_stylebox_override("panel", card)
	_status_panel.position = Vector2(26.0, 110.0)
	_status_panel.visible = false
	layer.add_child(_status_panel)
	_status = UiKit.label("", UiKit.BODY_FONT, 16, Palette.INK)
	_status_panel.add_child(_status)
