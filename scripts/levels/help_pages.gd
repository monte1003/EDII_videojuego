class_name HelpPages
extends RefCounted

#Help texts of each round, numbers from its real rules


static func level_one(settings: Level01Settings) -> Array[Dictionary]:
	return Level01Help.pages(settings)


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
				InputHints.move_markup(), InputHints.look_markup(),
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
				InputHints.move_markup(), InputHints.look_markup(), InputHints.key_markup(&"jump"),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]


static func trend_war(settings: TrendSettings) -> Array[Dictionary]:
	return TrendHelp.pages(settings)


static func perfect_selfie(settings: SelfieSettings, sheet: ScoreSheet) -> Array[Dictionary]:
	return SelfieHelp.pages(settings, sheet)
