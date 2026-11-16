class_name Level01Help
extends RefCounted

#The pages of the help of the feed race; the numbers come from its settings and layout


static func pages(settings: Level01Settings) -> Array[Dictionary]:
	var key := InputHints.markup
	var minutes := "%d:%02d" % [floori(settings.time_limit / 60.0), int(settings.time_limit) % 60]
	var keys := InputHints.move_markup()
	return [
		{
			"title": "Tu misión",
			"body": "Cruza las plataformas flotantes hasta la %s, la isla del arco al final del recorrido. Si juegan varios, gana quien llega primero.

Cuando alguien llega, la meta se cierra en %d segundos. El tiempo máximo es %s. Si caes al vacío pierdes 1 de tus %d intentos y vuelves a la salida, o a la última plaza por la que pasaste." % [
				key.call("META"), int(settings.finish_window), minutes, settings.attempts],
		},
		{
			"title": "Seis caminos",
			"body": "De la salida parten tres caminos anchos: Likes, Comentarios y Scroll. Los tres llegan a la primera plaza.

De esa plaza bajan tres toboganes, Recarga, Cargando y Desliza, que solo se bajan. Cada uno lleva a otro camino, Algoritmo, Viral o Historias, y los tres llegan a la segunda plaza, frente a la meta. Cualquier camino de arriba sirve con cualquiera de abajo: elige el que mejor te salga.",
		},
		{
			"title": "Qué hay en cada camino",
			"body": "Likes: cajas que lanzan likes desde los lados y barras que giran.
Comentarios: el más corto, con hileras de comentarios que se balancean como hachas.
Scroll: ruedas que ruedan hacia ti, un puente que cae y la cinta del scroll infinito.
Algoritmo: bolas gigantes por carriles y una bola que cruza la salida.
Viral: ventiladores que empujan de lado, hashtags que barren y barras.
Historias: baldosas que se caen al pisarlas, barras, un comentario y un puente que cae.",
		},
		{
			"title": "Comentarios y likes",
			"body": "Los comentarios cuelgan de un pórtico y se balancean de lado a lado, uno detrás de otro. No se pueden saltar: espera entre dos y avanza cuando el siguiente se aleje.

Las cajas rosadas a los lados de los puentes de Likes tiemblan y brillan justo antes de lanzar un like a través del puente. Pasa cuando el like vuelva a su caja.",
		},
		{
			"title": "Ruedas y bolas",
			"body": "En Scroll salen ruedas del piso y ruedan hacia ti por una mitad del camino, a veces por las dos: sáltalas o pásate a la otra mitad.

En Algoritmo las bolas son demasiado altas para saltar. Un carril se enciende justo antes de que salga su bola: quédate en un carril apagado.",
		},
		{
			"title": "Viento e historias",
			"body": "Los ventiladores de Viral giran más rápido y su aro parpadea antes de soplar. Mientras soplan te arrastran hacia el otro lado del puente, también en el aire: camina contra el viento.

Las plataformas de Historias son baldosas: al pisar una, su anillo se vacía y se cae. Vuelve a los %d segundos. No te detengas encima." % int(Level01Layout.TILE_GONE),
		},
		{
			"title": "El feed cambia",
			"body": "Los puentes color coral son frágiles: cada cierto tiempo uno parpadea y %d segundos después cae por unos %d. Pasados %d segundos del inicio puede haber dos caídos a la vez. No elige un puente con alguien encima, pero si pisas uno marcado caes con él.

Antes de caer, al puente le sale un letrero que dice SATURADA. Siempre queda otro camino." % [
				int(settings.feed_warning), int(settings.feed_duration), int(settings.feed_first + settings.feed_extra_delay)],
		},
		{
			"title": "Barras, bloques y cintas",
			"body": "En las plataformas con el borde rosado gira una barra por todo el piso, o dos cruzadas: salta sobre ella cuando se acerque. Algunas aceleran y frenan.

Lo que barre un puente de lado a lado te lanza fuera: pasa cuando se aleje o salta sobre él. La cinta del final de Scroll te arrastra y cambia de sentido cada cierto tiempo; sus flechas parpadean antes.",
		},
		{
			"title": "Si te caes",
			"body": "Debajo de cada camino hay una cubierta. Si caes ahí no pierdes el intento: camina a la plataforma dorada que tiene una burbuja encima y una burbuja te sube al inicio del puente del que caíste, tomes la plataforma que tomes: por abajo no se avanza. El viaje toma unos segundos: ese es el precio de la caída.

Los toboganes tienen barandas y solo se bajan. De las plazas y de la salida sí se puede caer al vacío.",
		},
		{
			"title": "Cómo se maneja",
			"body": "Moverte: %s
Saltar: %s (dos veces en el aire barres: llegas más lejos y quedas tendido un momento)
Mirar: %s
Pausa: %s · Esta ayuda: %s

Cada camino tiene su nombre en un arco a la entrada. Al pasar por las dos plazas (%s) se guarda tu progreso. A la izquierda ves tu puesto." % [
				keys, InputHints.key_markup(&"jump"), key.call("MOUSE"), InputHints.key_markup(&"pause"), InputHints.key_markup(&"help"),
				key.call("CHECKPOINT")],
		},
	]
