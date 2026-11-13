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
			"body": "Los puentes color coral son frágiles: cada cierto tiempo uno parpadea y %d segundos después cae por unos %d. Pasados %d segundos del inicio puede haber dos caídos a la vez. No elige un puente con alguien encima, pero si pisas uno marcado caes con él: abajo hay una cubierta y no pierdes el intento.

Antes de caer, al puente le sale un letrero que dice SATURADA. Casi siempre hay varios caminos parecidos: cuando uno se cierra, los bots calculan otro, y tú también." % [
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
			"title": "Atajos, bloques y comentarios",
			"body": "Los puentes angostos son atajos: acortan mucho el camino, pero casi no dejan espacio para un empujón.

En algunos puentes anchos va y viene un bloque de rayas. Si te toca, te lanza al vacío: pasa cuando se aleje o salta sobre él.

Otros puentes anchos tienen un comentario: una burbuja que se escribe en una orilla, parpadea y cruza de lado a lado empujando a quien encuentre. Salta sobre ella o cruza por el otro lado.",
		},
		{
			"title": "Todo se mueve",
			"body": "Una cinta cambia de sentido cada cierto tiempo y sus flechas parpadean un instante antes: el costo de ese puente cambia con ella.

En algunas islas rueda una bola de caramelo por una franja rosada que se enciende antes de que salga; salta cuando llegue. Algunas barras aceleran y frenan.

Los trampolines de colores, en la parte quieta del borde de algunas islas, te lanzan al aire: sirven para ver el camino o para esquivar.

Debajo de los puentes que caen y de los que tienen comentario hay una cubierta con borde bajo. Si caes ahí no pierdes el intento: solo el camino, porque una plataforma dorada del piso te devuelve a la isla donde empieza el puente.",
		},
		{
			"title": "Los bots molestos",
			"body": "Son lo que molesta en internet y cada uno te busca a su manera:
%s

Salen en momentos distintos. Cuando uno se acerca, le sale un %s: va a empujar. Corre en sentido contrario y no pasa nada." % [
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
Saltar: %s (dos veces en el aire barres: llegas más lejos y quedas tendido un momento)
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
			"body": "En la plaza nacen burbujas con algo dentro y se van solas a los %d a %d segundos. Cada tendencia es una fila de íconos: atrapa una burbuja de cada uno, en orden, antes de que se acabe su reloj.

Son %d tendencias. Cuanto antes completes cada una, más puntos; si el reloj llega a cero sin completarla, esa no suma." % [
				int(settings.life_seconds.x), int(settings.life_seconds.y), count],
		},
		{
			"title": "En orden",
			"body": "La burbuja que te toca brilla con su color sobre un aro y un haz de luz; las demás quedan apagadas. Cuando una burbuja envejece, su aro se encoge y late más rápido: va a irse.

Siempre hay unas %d vivas y de cada categoría hay al menos %d, en más de una zona. Tocar una que no te toca no castiga: solo rebota." % [
				settings.bubble_target, settings.min_per_kind],
		},
		{
			"title": "Cinco zonas",
			"body": "Cada zona tiene su color, su forma y su manera de hacerlo difícil. La torre morada es de tarimas que se suben en espiral. La rampa menta tiene cintas: una sube, una baja y una cambia de sentido. El campo ámbar son trampolines y cañones hacia dos pilares. El laberinto rosa tiene muros que no se saltan. El escenario azul gira dos barras.

Todas salen de la plaza del centro, bajo la pantalla gigante.",
		},
		{
			"title": "Empujar y barrer",
			"body": "Con %s empujas a quien tengas delante: quien recibe el golpe suelta lo último que atrapó y sale volando unos segundos. Después hay un momento de gracia.

Con %s dos veces en el aire barres: llegas más lejos, pero quedas tendido un momento." % [InputHints.key_markup(&"shove"), InputHints.key_markup(&"jump")],
		},
		{
			"title": "Haters",
			"body": "Los haters viven en el laberinto: fuera de él nadie te quita nada. Si te alcanzan, pierdes lo último que atrapaste. A ellos también los puedes empujar.

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
			"body": "Un dron recorre el estudio y toma %d fotos, cada una en un set distinto. Un mensaje avisa cada vez que la cámara se mueve: ve hacia su luz y métete en el marco que dibuja en el piso antes del disparo.

En el visor de arriba ves lo que ve la cámara. Si estás en el aire o fuera del marco cuando dispara, no sales." % settings.photo_count,
		},
		{
			"title": "Marco y centro",
			"body": "El marco se mueve y cambia de tamaño; cuando queda fijo parpadea tres veces y dispara. Con cada foto es más pequeño y más inquieto.

Salir vale %d seguidores y estar en el círculo del centro suma %d. Una foto para ti solo vale más que una con mucha gente: los fotobombers también cuentan." % [
				sheet.selfie_inside, sheet.selfie_center],
		},
		{
			"title": "Pose y empujón",
			"body": "Pulsa %s una vez para posar: tu personaje hace una pose o un baile distinto cada vez y no se mueve. Si llevas un momento posando al disparo, sumas %d seguidores más. Se quita con %s otra vez o al intentar moverte.

Posando, un empujón te lleva más lejos. Con %s empujas a quien tengas delante, y su tecla aparece sobre quien alcances." % [
				InputHints.key_markup(&"interact"), sheet.selfie_pose, InputHints.key_markup(&"interact"), InputHints.key_markup(&"shove")],
		},
		{
			"title": "Subir y potenciadores",
			"body": "Las azoteas se alcanzan por la rampa larga, por las pasarelas o con los cañones. Con %s dos veces en el aire barres: llegas más lejos y quedas tendido un momento.

En los pedestales aparecen cristales: la flecha te hace saltar más alto, el rayo te hace correr más rápido y el escudo bloquea el siguiente golpe.

Moverte: %s · Saltar: %s · Mirar: %s
Pausa: %s · Esta ayuda: %s" % [
				InputHints.key_markup(&"jump"), InputHints.move_markup(), InputHints.key_markup(&"jump"), key.call("MOUSE"),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]
