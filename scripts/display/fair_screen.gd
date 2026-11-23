extends Control

#The fair screen. For now it only shows its link to the room as text: how the connection goes, the address and where it came from, what it
#sees of the game (room, round, points) and how much comes from the server. It takes no keys: it only watches

const STAGES := {"lobby": "SALA DE ESPERA", "warmup": "CALENTAMIENTO", "intro": "SORTEO Y CARGA", "playing": "EN JUEGO",
	"round_results": "RESULTADOS", "finished": "PARTIDA TERMINADA"}

var watch := NetWatch.new()

var _status: Label
var _source: Label
var _game: Label
var _players: Label
var _traffic: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	add_child(SocialBackground.new())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(UiKit.label("PANTALLA DE FERIA", UiKit.BUTTON_FONT, 13, Palette.INK_SOFT))
	_status = UiKit.label("", UiKit.BOLD_FONT, 40, Palette.INK)
	_source = UiKit.label("", UiKit.BUTTON_FONT, 13, Palette.CORAL)
	_game = UiKit.label("", UiKit.BUTTON_FONT, 18, Palette.INK)
	_players = UiKit.label("", UiKit.BODY_FONT, 22, Palette.INK)
	_traffic = UiKit.label("", UiKit.BODY_FONT, 15, Palette.INK_SOFT)
	for label: Label in [_status, _source, _game, _players, _traffic]:
		column.add_child(label)
	watch.name = "Watch"
	add_child(watch)
	watch.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_status.text = watch.status
	var config := "feria.cfg: " + (watch.config_address if watch.config_address != "" else "sin dirección, se usa el anuncio de la red")
	if watch.address != "":
		var origin := "de feria.cfg" if watch.address == watch.config_address else "del anuncio de la red"
		_source.text = "SALA EN %s, %s   ·   %s" % [watch.address, origin, config]
	else:
		_source.text = config
	_game.text = _game_line() if watch.connected else ""
	_players.text = _player_lines() if watch.connected else ""
	var kilobytes := ("%.1f" % (watch.bytes_per_second / 1024.0)).replace(".", ",")
	_traffic.text = "Recibe %d mensajes/s · %s KB/s" % [watch.messages_per_second, kilobytes] if watch.connected else ""


func _game_line() -> String:
	var stage: String = STAGES.get(watch.stage, watch.stage.to_upper())
	if watch.stage == "lobby":
		return "%s · %d EN LA SALA" % [stage, watch.net.room.size()]
	if watch.round_index < 0 or watch.plan.is_empty() or watch.stage == "finished":
		return stage
	var info := MinigameCatalog.find(watch.plan[mini(watch.round_index, watch.plan.size() - 1)])
	var title := info.title.to_upper() if info != null else ""
	return "RONDA %d DE %d · %s · %s" % [watch.round_index + 1, watch.plan.size(), title, stage]


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
		var line := "%s  ·  %s  ·  %d pts" % [str(member.get("name", "")), character.display_name.to_upper(), total]
		if not bool(member.get("connected", true)):
			line += "  ·  desconectado"
		elif watch.stage == "lobby" and bool(member.get("ready", false)):
			line += "  ·  listo"
		lines.append(line)
	return "\n".join(lines)
