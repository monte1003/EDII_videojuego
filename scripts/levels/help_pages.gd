class_name HelpPages
extends RefCounted

#The texts of each round's help; the numbers come from the round, so they always match its real rules


static func level_one(settings: Level01Settings, bots: Array[BotAppearance]) -> Array[Dictionary]:
	var key := InputHints.markup
	var interact := InputHints.key_label(&"interact")
	var minutes := "%d:%02d" % [floori(settings.time_limit / 60.0), int(settings.time_limit) % 60]
	var keys := "%s %s %s %s" % [
		InputHints.key_label(&"move_forward"), InputHints.key_label(&"move_left"),
		InputHints.key_label(&"move_back"), InputHints.key_label(&"move_right")]
	var roster := PackedStringArray()
	for bot in bots:
		roster.append("%s: %s" % [key.call(bot.display_name), bot.behavior])
	return [
		{
			"title": "Tu misión",
			"body": "Cruza las islas flotantes y llega a la isla %s, la del arco dorado, antes de que el reloj se acabe (%s).\n\nSi caes al vacío pierdes 1 de tus %d intentos y vuelves a la salida, o al checkpoint si ya pasaste por él. El reloj no se detiene." % [
				key.call("M"), minutes, settings.attempts],
		},
		{
			"title": "Los bots molestos",
			"body": "Son lo que molesta en internet y cada uno te busca a su manera:\n%s\n\nSalen en momentos distintos. Cuando uno se acerca, le sale un %s: ¡te va a empujar! Corre en sentido contrario y no pasa nada." % [
				"\n".join(roster), key.call("❗")],
		},
		{
			"title": "Bloquear (isla E)",
			"body": "Bloquear es poner un límite: %s un puente para los bots durante %d segundos. Ellos buscan otro camino, pero tú sí puedes cruzarlo.\n\nSe recarga en %d segundos.\n\nVe a la isla %s, junto al letrero de prohibido, y pulsa %s." % [
				key.call("cierra"), int(settings.block_duration), int(settings.block_cooldown), key.call("E"), key.call(interact)],
		},
		{
			"title": "Silenciar (isla F)",
			"body": "Silenciar es apagar las notificaciones: durante %d segundos los bots solo te notan si están a menos de %d metros (normalmente te ven desde %d). El Bulo no se deja silenciar.\n\nNo los detiene, solo hace que te pierdan de vista. Se recarga en %d segundos.\n\nVe a la isla %s, junto a la campana con la raya, y pulsa %s." % [
				int(settings.silence_duration), int(settings.silenced_detection_radius), int(settings.detection_radius),
				int(settings.silence_cooldown), key.call("F"), key.call(interact)],
		},
		{
			"title": "Pausa digital (isla D)",
			"body": "Es tomarte un descanso del celular: dentro de la burbuja de la isla %s nadie puede empujarte durante %d segundos. El reloj sigue corriendo.\n\nSe recarga en %d segundos. También estás protegido %d segundos al reaparecer tras una caída.\n\nEntra a la burbuja y pulsa %s." % [
				key.call("D"), int(settings.refuge_duration), int(settings.refuge_cooldown),
				int(settings.respawn_protection), key.call(interact)],
		},
		{
			"title": "Cómo se maneja",
			"body": "Moverte: %s\nSaltar: %s\nMirar: %s\nUsar una estación: %s\nPausa: %s · Esta ayuda: %s\n\nSobre cada lugar importante flota su nombre. Al pasar por el %s se guarda tu progreso." % [
				key.call(keys), InputHints.key_markup(&"jump"), key.call("MOUSE"), key.call(interact),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help"), key.call("CHECKPOINT")],
		},
	]


static func street(config: Dictionary) -> Array[Dictionary]:
	var key := InputHints.markup
	return [
		{
			"title": "Tu misión",
			"body": "Estás en una calle muy transitada. Autos, peatones y bicis te empujan hacia la línea %s: si un golpe te lanza más allá de ella, la corriente te arrastró.\n\nAguanta %d segundos para ganar. Cada tercio del tiempo todo va más rápido." % [
				key.call("FIN"), int(config["time_limit"])],
		},
		{
			"title": "Cómo esquivar",
			"body": "Mira cómo vienen los autos antes de moverte: nunca hay un muro completo, siempre queda un hueco por donde pasar.\n\nLas aceras no son un refugio: también hay peatones, y los repartidores en bici van mucho más rápido. Cada choque te empuja hacia atrás, y los más grandes te empujan más lejos.",
		},
		{
			"title": "Cómo se maneja",
			"body": "Subir y bajar por la calle: %s / %s\nSaltar: %s\nPausa: %s · Esta ayuda: %s" % [
				InputHints.key_markup(&"move_forward"), InputHints.key_markup(&"move_back"),
				InputHints.key_markup(&"jump"), InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]


static func social_drop(config: Dictionary) -> Array[Dictionary]:
	var key := InputHints.markup
	var keys := "%s %s %s %s" % [
		InputHints.key_label(&"move_forward"), InputHints.key_label(&"move_left"),
		InputHints.key_label(&"move_back"), InputHints.key_label(&"move_right")]
	return [
		{
			"title": "Tu misión",
			"body": "Estás sobre una plataforma de %dx%d casillas, cada una con el ícono de una red social. Frente a ti hay una pantalla gigante.\n\nAguanta %d segundos sin caerte para ganar." % [
				config["columns"], config["rows"], int(config["time_limit"])],
		},
		{
			"title": "La pantalla",
			"body": "La pantalla cambia de ícono muy rápido. Cuando el sonido se vuelve más agudo está por detenerse.\n\nEl ícono en el que se detiene es el que se queda: corre a una casilla con ese ícono, %s. Las que van a caer parpadean en rojo justo antes.\n\n%d segundos después vuelven todas en otro orden y se repite. Cada vez tienes menos tiempo para moverte." % [
				key.call("las demás desaparecen"), int(config["rest_seconds"])],
		},
		{
			"title": "Cohetes",
			"body": "Cuando quedan %d segundos empiezan a pasar cohetes de lado a lado, cada uno por una de las %d filas.\n\nAntes de que salga, su fila %s. Si el cohete te alcanza, te derriba de la plataforma: cámbiate de fila o salta justo cuando pase." % [
				int(config["rocket_seconds_left"]), config["rows"], key.call("parpadea en rojo")],
		},
		{
			"title": "Cómo se maneja",
			"body": "Moverte: %s\nSaltar: %s\nPausa: %s · Esta ayuda: %s\n\nLa cámara está fija: ves todo el tablero desde arriba." % [
				key.call(keys), InputHints.key_markup(&"jump"),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]
