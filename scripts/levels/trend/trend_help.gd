class_name TrendHelp
extends RefCounted

#Help pages of the trend war, numbers from its settings


static func pages(settings: TrendSettings) -> Array[Dictionary]:
	return [
		{
			"title": "La misión",
			"body": "Arriba ves tu tendencia: un ícono que cambia cada vez que la cumples. Toca una burbuja de ese ícono para cumplirla y sumar.

Cada cumplida vale un punto. Cuantas más cumplas en toda la ronda, más puntos.",
		},
		{
			"title": "Una zona cada vez",
			"body": "La ronda pasa por las cinco zonas de la plaza, %d segundos en cada una. Las burbujas solo nacen en la zona que se juega, y cada vez salen más.

Un haz de luz, una flecha en el borde y su nombre marcan la zona. Antes de que termine, se anuncia la siguiente: corre hacia ella. Un anillo en el piso avisa dónde va a nacer una burbuja." % roundi(settings.zone_seconds),
		},
		{
			"title": "Tu burbuja y las demás",
			"body": "Las burbujas de tu tendencia brillan sobre un aro y un haz de luz. Las demás se ven apagadas: puedes atravesarlas, solo tiemblan.

Una vez por zona sale la burbuja viral, dorada: es la tendencia de todos y vale %d. Una burbuja vieja parpadea y se va a otro lado." % settings.viral_value,
		},
		{
			"title": "Las cinco zonas",
			"body": "Reto del salto: una barra barre el piso; sáltala cuando pase.
Modo avión: cada almohadilla da vuelta la gravedad; flotas entre piso y techo.
Mar de memes: plataformas que se mueven, giran o se hunden; caer al agua te devuelve al muelle.
Pantalla bloqueada: las pantallas suben y bajan por turnos; verde es paso libre.
Lluvia de likes: los trampolines suben de piso en piso y los likes que caen empujan.",
		},
		{
			"title": "Empujar y barrer",
			"body": "Con %s empujas a quien está delante y queda aturdido un momento, sin poder atrapar nada.

Con %s dos veces en el aire barres: llegas más lejos, pero quedas tendido un momento." % [InputHints.key_markup(&"shove"), InputHints.key_markup(&"jump")],
		},
		{
			"title": "Controles",
			"body": "Mover: %s · Saltar: %s · Mirar: %s
Empujar: %s
Pausa: %s · Esta ayuda: %s" % [
				InputHints.move_markup(), InputHints.key_markup(&"jump"), InputHints.look_markup(), InputHints.key_markup(&"shove"),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]
