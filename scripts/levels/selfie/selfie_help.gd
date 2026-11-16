class_name SelfieHelp
extends RefCounted

#The pages of the help of the perfect selfie; the numbers come from its settings and the score sheet


static func pages(settings: SelfieSettings, sheet: ScoreSheet) -> Array[Dictionary]:
	var key := InputHints.markup
	return [
		{
			"title": "Misión",
			"body": "Un dron recorre el estudio y toma %d fotos en sus once sets. Cuando la cámara se mueve, arriba sale el nombre del set; la insignia de la cámara marca dónde está y cuántos metros faltan, y la esquina muestra lo que ve.

Al disparo cuenta estar dentro del marco del piso, de pie o en pleno salto: el aro bajo tus pies se pone verde cuando estás dentro." % settings.photo_count,
		},
		{
			"title": "Marco y centro",
			"body": "El marco se mueve y se encoge con cada foto; quieto, parpadea tres veces y dispara.

Salir vale %d seguidores, el círculo del centro suma %d y una foto en el aire, %d. Con menos gente la foto vale más: los trols también cuentan." % [
				sheet.selfie_inside, sheet.selfie_center, roundi(sheet.selfie_pose * settings.air_share)],
		},
		{
			"title": "Pose y empujón",
			"body": "%s una vez: una pose o un baile, sin moverse. Tras un momento posando, la foto suma %d. Se quita con %s o al moverse.

%s empuja a quien esté delante: sale despedido y aturdido un momento, y más lejos si posaba." % [
				InputHints.key_markup(&"interact"), sheet.selfie_pose, InputHints.key_markup(&"interact"), InputHints.key_markup(&"shove")],
		},
		{
			"title": "Sets y potenciadores",
			"body": "Cada set tiene su reto: giratorio, baile con barra que gira, pasarela con cinta, podio con trampolín, alfombra que frena, piscina, directo que salta, cajas que explotan, gimnasio, palos selfie y la zona trol, donde los trols empujan a quien no está en lo alto. %s dos veces en el aire: barrido.

Pedestales: flecha, salto más alto; rayo, más velocidad; escudo, para un golpe.

Mover: %s · Saltar: %s · Mirar: %s
Pausa: %s · Ayuda: %s" % [
				InputHints.key_markup(&"jump"), InputHints.move_markup(), InputHints.key_markup(&"jump"), key.call("MOUSE"),
				InputHints.key_markup(&"pause"), InputHints.key_markup(&"help")],
		},
	]
