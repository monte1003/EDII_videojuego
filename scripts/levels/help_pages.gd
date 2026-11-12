class_name HelpPages
extends RefCounted

#The texts of each round's help; the numbers come from the round, so they always match its real rules


static func level_one(settings: Level01Settings, bots: Array[BotAppearance]) -> Array[Dictionary]:
	var key := InputHints.markup
	var interact := InputHints.key_label(&"interact")
	var stations: Dictionary = Level01Layout.STATIONS
	var minutes := "%d:%02d" % [floori(settings.time_limit / 60.0), int(settings.time_limit) % 60]
	var keys := InputHints.move_markup()
	var roster := PackedStringArray()
	for bot in bots:
		roster.append("%s: %s" % [key.call(bot.display_name), bot.behavior])
	return [
		{
			"title": "Tu misión",
			"body": "Sube por las islas flotantes y cruza todo el recorrido hasta la isla %s, la del arco. Si juegan varios, gana quien llega primero.

Cuando alguien llega, la meta se cierra en %d segundos. El tiempo máximo es %s. Si caes al vacío pierdes 1 de tus %d intentos y vuelves a la salida, o al checkpoint si ya pasaste por él." % [
				key.call(Level01Layout.GOAL), int(settings.finish_window), minutes, settings.attempts],
		},
		{
			"title": "El feed cambia",
			"body": "Los puentes color coral son frágiles: cada cierto tiempo uno parpadea y %d segundos después cae por unos %d. Pasados %d segundos del inicio puede haber dos caídos a la vez. Si estás encima, caes con él.

Casi siempre hay varios caminos parecidos: cuando uno se cierra, los bots calculan otro, y tú también." % [
				int(settings.feed_warning), int(settings.feed_duration), int(settings.feed_first + settings.feed_extra_delay)],
		},
		{
			"title": "Tres caminos",
			"body": "En cada parte del recorrido hay tres caminos. El del medio es el más recto, pero tiene puentes angostos y barras que giran.

Los de los lados dan más vueltas y lo compensan: un tobogán azul te baja rápido pero solo en ese sentido, y un cañón dorado en el borde de una isla (sigue las flechas del piso) te lanza por el aire, a través de los aros, hasta otra isla. Los tres tardan casi lo mismo: elige el que mejor te salga.",
		},
		{
			"title": "Cintas y barras",
			"body": "Las cintas de flechas te arrastran: a favor van rápido y en contra cuestan el doble. El costo de cada puente que ves en F3 lo cuenta.

En las islas con el borde rosado gira una barra por todo el piso. Salta sobre ella cuando se acerque o rodéala por el borde, sin caerte.",
		},
		{
			"title": "Atajos y bloques",
			"body": "Los puentes angostos son atajos: acortan mucho el camino, pero casi no dejan espacio para un empujón.

En algunos puentes anchos va y viene un bloque de rayas. Si te toca, te lanza al vacío: pasa cuando se aleje o salta sobre él.",
		},
		{
			"title": "Todo se mueve",
			"body": "Una cinta cambia de sentido cada cierto tiempo y sus flechas parpadean un instante antes: el costo de ese puente cambia con ella.

En algunas islas rueda una bola de caramelo por una franja rosada que se enciende antes de que salga; salta cuando llegue. Algunas barras aceleran y frenan.

Los trampolines de colores, en la parte quieta del borde de algunas islas, te lanzan al aire: sirven para ver el camino o para esquivar.",
		},
		{
			"title": "Los bots molestos",
			"body": "Son lo que molesta en internet y cada uno te busca a su manera:
%s

Salen en momentos distintos. Cuando uno se acerca, le sale un %s: ¡te va a empujar! Corre en sentido contrario y no pasa nada." % [
				"
".join(roster), key.call("❗")],
		},
		{
			"title": "Las estaciones",
			"body": "Bloquear (isla %s): %s junto al letrero y por %d segundos los bots no pueden usar el puente %s-%s. Recarga %d s.

Silenciar (isla %s): por %d segundos los bots solo te notan a menos de %d metros (normalmente te ven desde %d). El Bulo no se deja silenciar.

Pausa digital (isla %s): dentro de la burbuja nadie te empuja %d segundos." % [
				stations[&"block"], key.call(interact), int(settings.block_duration), Level01Layout.BLOCK_EDGE[0], Level01Layout.BLOCK_EDGE[1],
				int(settings.block_cooldown), stations[&"silence"], int(settings.silence_duration),
				int(settings.silenced_detection_radius), int(settings.detection_radius), stations[&"refuge"], int(settings.refuge_duration)],
		},
		{
			"title": "Cómo se maneja",
			"body": "Moverte: %s
Saltar: %s
Mirar: %s
Usar una estación: %s
Pausa: %s · Esta ayuda: %s

Sobre cada lugar importante flota su nombre. Al pasar por las islas %s (%s) se guarda tu progreso. A la derecha ves quién va primero." % [
				keys, InputHints.key_markup(&"jump"), key.call("MOUSE"), key.call(interact),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help"), " y ".join(Level01Layout.CHECKPOINTS), key.call("CHECKPOINT")],
		},
	]


static func street(config: Dictionary) -> Array[Dictionary]:
	var key := InputHints.markup
	return [
		{
			"title": "Tu misión",
			"body": "La calle es una cinta transportadora: te arrastra sin parar hacia la línea %s. Si te quedas quieto, o un golpe te lanza más allá de ella, la corriente te arrastró.

Corre contra la cinta y aguanta %d segundos para ganar. Cada tercio del tiempo todo va más rápido." % [
				key.call("FIN"), int(config["time_limit"])],
		},
		{
			"title": "Cómo esquivar",
			"body": "Mira cómo vienen los autos antes de moverte: nunca hay un muro completo, siempre queda un hueco por donde pasar. Los ciclistas se meten por el carril y se bambolean.

Los conos bajitos se saltan. Las aceras también están en la cinta y tienen peatones que caminan mirando el celular. Cada choque te lanza hacia atrás, te tumba un momento y te protege muy poco al levantarte: no te quedes cerca del siguiente.",
		},
		{
			"title": "Cómo se maneja",
			"body": "Moverte por la calle: %s
Mirar: %s
Saltar: %s (sale al instante; en el aire la cinta no te arrastra, pero al aterrizar descansa %s s)
Pausa: %s · Esta ayuda: %s" % [
				InputHints.move_markup(), key.call("MOUSE"),
				InputHints.key_markup(&"jump"), str(config["jump_cooldown"]), InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]


static func social_drop(config: Dictionary) -> Array[Dictionary]:
	var key := InputHints.markup
	return [
		{
			"title": "Tu misión",
			"body": "Estás sobre una plataforma de %dx%d cartas, cada una con el ícono de una app. A cada lado hay una pantalla gigante.

Aguanta %d segundos sin caerte para ganar." % [
				config["columns"], config["rows"], int(config["time_limit"])],
		},
		{
			"title": "Memoriza",
			"body": "Al empezar cada ronda las cartas muestran su ícono y las pantallas cuentan hacia atrás desde %d.

Cuando llegan a cero las cartas se voltean y quedan tapadas con un %s. La pantalla muestra el ícono que tienes que pisar: corre a la carta que lo tenía, %s." % [
				int(config["memorize_seconds"]), key.call("?"), key.call("las demás caen")],
		},
		{
			"title": "Cae el resto",
			"body": "Las cartas que van a caer parpadean en rojo justo antes. Las que tienen el ícono que sale se voltean y lo muestran: pisa cualquiera de ellas.

%d segundos después vuelven todas, con los íconos en otro lugar, y se repite. Cada vez tienes menos tiempo para memorizar y para correr." % int(config["rest_seconds"]),
		},
		{
			"title": "Cada ronda cuesta más",
			"body": "Al principio el tablero solo tiene dos o tres íconos distintos y casi la mitad de las cartas (%d de %d) llevan el que sale.

Con el tiempo aparecen más íconos distintos y menos cartas buenas, hasta que en la última ronda hay %d íconos y solo una carta se salva. Mira bien dónde está cada uno." % [
				config["first_copies"], config["columns"] * config["rows"], config["icons"]],
		},
		{
			"title": "Cómo se maneja",
			"body": "Moverte: %s
Mirar: %s
Saltar: %s
Pausa: %s · Esta ayuda: %s" % [
				InputHints.move_markup(), key.call("MOUSE"), InputHints.key_markup(&"jump"),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]


static func trend_war(settings: TrendSettings) -> Array[Dictionary]:
	var key := InputHints.markup
	var count := mini(settings.limits.size(), settings.lengths.size())
	return [
		{
			"title": "Tu misión",
			"body": "Por toda la plaza flotan burbujas con algo dentro. Cada tendencia es una fila de íconos: atrapa una burbuja de cada uno antes de que se acabe su reloj.

Son %d tendencias. Cuanto antes completes cada una, más puntos; si el reloj llega a cero sin completarla, esa no suma." % count,
		},
		{
			"title": "En orden",
			"body": "Las burbujas se atrapan en el orden de la fila, de izquierda a derecha. La que te toca brilla con su color sobre un aro y un haz de luz; las demás quedan apagadas.

Tocar una burbuja que no te toca no castiga: solo rebota. Cada tendencia trae más íconos y la plaza se mueve más: barras, trampolines, cintas y bloques.",
		},
		{
			"title": "Empujar",
			"body": "Con %s empujas a quien tengas delante. Quien recibe el golpe suelta lo último que atrapó: sale volando unos segundos y lo puede tomar quien lo necesite.

Después de un golpe hay un momento de gracia para que nadie quede encadenado." % InputHints.key_markup(&"shove"),
		},
		{
			"title": "Haters",
			"body": "Los haters te siguen por los puentes. Si te alcanzan, pasa lo mismo que con un empujón: pierdes lo último que atrapaste. No compiten ni suman puntos, solo estorban.

Moverte: %s · Saltar: %s · Mirar: %s
Pausa: %s · Esta ayuda: %s" % [
				InputHints.move_markup(), InputHints.key_markup(&"jump"), key.call("MOUSE"),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]


static func perfect_selfie(settings: SelfieSettings, sheet: ScoreSheet) -> Array[Dictionary]:
	var key := InputHints.markup
	return [
		{
			"title": "Tu misión",
			"body": "Un dron recorre el estudio y toma %d fotos, cada una en un lugar distinto. Sigue su haz de luz y métete en el marco que dibuja en el piso antes del disparo.

Cada foto en la que sales te da seguidores. Si estás en el aire o fuera del marco cuando dispara, no sales." % settings.photo_count,
		},
		{
			"title": "Marco y centro",
			"body": "El marco se mueve y cambia de tamaño; cuando queda fijo parpadea tres veces y dispara. Con cada foto es más pequeño y más inquieto.

Salir vale %d seguidores y estar en el círculo del centro suma %d. Una foto para ti solo vale más que una con mucha gente: los fotobombers también cuentan." % [
				sheet.selfie_inside, sheet.selfie_center],
		},
		{
			"title": "Pose y empujón",
			"body": "Mantén %s para posar: te quedas quieto y, si llevas un momento posando al disparo, sumas %d seguidores más. Centro y pose a la vez dan un extra.

Posando no te mueves ni saltas, y un empujón te lleva más lejos. Con %s empujas a quien tengas delante." % [
				InputHints.key_markup(&"interact"), sheet.selfie_pose, InputHints.key_markup(&"shove")],
		},
		{
			"title": "Potenciadores",
			"body": "En los pedestales aparecen cristales: la flecha te hace saltar más alto, el rayo te hace correr más rápido y el escudo bloquea el siguiente golpe.

Moverte: %s · Saltar: %s · Mirar: %s
Pausa: %s · Esta ayuda: %s" % [
				InputHints.move_markup(), InputHints.key_markup(&"jump"), key.call("MOUSE"),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]
