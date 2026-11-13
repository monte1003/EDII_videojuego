class_name ImpactFx
extends RefCounted

#Cheap one-shot effects for the hits of every round: a puff of dust, a few stars, the sound and the freeze of an impact

const STAR_SIZE := 64
const STAR_POINTS := 5
const DUST_COLOR := Color("f1e6ff")

static var _heart: ImageTexture
static var _star: ImageTexture
static var _fade: Curve


#The game stops for a moment when something hits hard; it comes back by itself
static func hit_stop(tree: SceneTree, seconds: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.06
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


#What a blow looks and sounds like on "player"; only the player of this screen freezes the game for a breath
static func blow(host: Node3D, player: Player, hit: Player.Hit, rng: RandomNumberGenerator, local: bool) -> void:
	stars(host, player.global_position + Vector3(0.0, 0.8, 0.0), 5 + roundi(hit.strength * 5.0))
	dust(host, player.global_position + Vector3(0.0, 0.1, 0.0), DUST_COLOR, 8 + roundi(hit.strength * 10.0))
	SynthSound.play(host, SynthSound.crash() if hit.strength > 0.5 else SynthSound.thump(),
		-4.0 + hit.strength * 3.0, rng.randf_range(0.92, 1.08))
	if local and hit.strength >= 0.5:
		hit_stop(host.get_tree(), 0.05 + 0.04 * hit.strength)


#Landing after a jump or a flight; a hard one (after a blow) also shakes the camera of that player
static func landing(host: Node3D, player: Player, hard: bool, rng: RandomNumberGenerator) -> void:
	dust(host, player.global_position + Vector3(0.0, 0.05, 0.0), DUST_COLOR, 12 if hard else 5)
	SynthSound.play(host, SynthSound.thump(0.2) if hard else SynthSound.land(), -6.0 if hard else -10.0,
		rng.randf_range(0.95, 1.1))
	if hard:
		player.shake_camera(0.25)


#A ring of light that opens and fades: flat on the floor when "facing" is up, or standing in the air and looking along "facing".
#"from" and "to" are its radius at the start and at the end
static func ring(parent: Node3D, at: Vector3, facing: Vector3, color: Color, from: float, to: float, seconds: float) -> void:
	var band := TorusMesh.new()
	band.inner_radius = 0.86
	band.outer_radius = 1.0
	band.rings = 28
	band.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var wave := MeshInstance3D.new()
	wave.mesh = band
	wave.material_override = material
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(wave)
	wave.global_position = at
	if absf(facing.normalized().dot(Vector3.UP)) < 0.9:
		wave.global_basis = Basis.looking_at(facing.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
	wave.scale = Vector3.ONE * from
	var tween := wave.create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector3.ONE * to, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(wave.queue_free)


#A round puff on the ground that grows and fades
static func dust(parent: Node3D, at: Vector3, color: Color, amount := 14) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = amount
	puff.lifetime = 0.55
	puff.explosiveness = 1.0
	puff.direction = Vector3.UP
	puff.spread = 75.0
	puff.initial_velocity_min = 1.2
	puff.initial_velocity_max = 3.2
	puff.gravity = Vector3(0.0, -1.2, 0.0)
	puff.damping_min = 1.5
	puff.damping_max = 3.0
	puff.scale_amount_min = 0.7
	puff.scale_amount_max = 1.3
	puff.scale_amount_curve = _fade_curve()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material = material
	puff.mesh = mesh
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_release(parent, puff, at, puff.lifetime)


#Gold stars that fly out and fall, always facing the camera
static func stars(parent: Node3D, at: Vector3, amount := 7) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.amount = amount
	burst.lifetime = 0.85
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 60.0
	burst.initial_velocity_min = 3.0
	burst.initial_velocity_max = 5.5
	burst.gravity = Vector3(0.0, -7.0, 0.0)
	burst.angle_min = -40.0
	burst.angle_max = 40.0
	burst.angular_velocity_min = -240.0
	burst.angular_velocity_max = 240.0
	burst.scale_amount_curve = _fade_curve()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * 0.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = star_texture()
	mesh.material = material
	burst.mesh = mesh
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_release(parent, burst, at, burst.lifetime)


#Paper confetti shot up from a cannon: it spins while it falls
static func confetti(parent: Node3D, at: Vector3, amount := 90, spread := 50.0, speed := 9.0) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.amount = amount
	burst.lifetime = 3.2
	burst.explosiveness = 0.95
	burst.direction = Vector3.UP
	burst.spread = spread
	burst.initial_velocity_min = speed * 0.55
	burst.initial_velocity_max = speed
	burst.gravity = Vector3(0.0, -5.5, 0.0)
	burst.damping_min = 0.8
	burst.damping_max = 1.8
	burst.angle_min = -180.0
	burst.angle_max = 180.0
	burst.angular_velocity_min = -360.0
	burst.angular_velocity_max = 360.0
	var tones := Gradient.new()
	var colors := PackedColorArray()
	var offsets := PackedFloat32Array()
	for index in PartyKit.PALETTE.size():
		colors.append(PartyKit.PALETTE[index])
		offsets.append(float(index) / (PartyKit.PALETTE.size() - 1))
	tones.offsets = offsets
	tones.colors = colors
	tones.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	burst.color_initial_ramp = tones
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.2, 0.32)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	burst.mesh = mesh
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_release(parent, burst, at, burst.lifetime)


#A plump heart with soft edges, white so a particle can tint it, drawn once
static func heart_texture() -> ImageTexture:
	if _heart != null:
		return _heart
	var image := Image.create(STAR_SIZE, STAR_SIZE, false, Image.FORMAT_RGBA8)
	var samples := 4
	for y in STAR_SIZE:
		for x in STAR_SIZE:
			var covered := 0
			for sy in samples:
				for sx in samples:
					#The implicit curve of a heart, in a square that goes from -1.3 to 1.3
					var px := ((x + (sx + 0.5) / samples) / STAR_SIZE - 0.5) * 2.6
					var py := (0.5 - (y + (sy + 0.5) / samples) / STAR_SIZE) * 2.6 + 0.1
					if pow(px * px + py * py - 1.0, 3.0) - px * px * py * py * py <= 0.0:
						covered += 1
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(covered) / (samples * samples)))
	_heart = ImageTexture.create_from_image(image)
	return _heart


#A five-pointed star with soft edges, drawn once
static func star_texture() -> ImageTexture:
	if _star != null:
		return _star
	var outer := STAR_SIZE * 0.47
	var inner := outer * 0.46
	var center := Vector2.ONE * STAR_SIZE / 2.0
	var polygon := PackedVector2Array()
	for index in STAR_POINTS * 2:
		var radius := outer if index % 2 == 0 else inner
		var angle := -PI / 2.0 + PI * index / STAR_POINTS
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var image := Image.create(STAR_SIZE, STAR_SIZE, false, Image.FORMAT_RGBA8)
	var samples := 4
	for y in STAR_SIZE:
		for x in STAR_SIZE:
			var covered := 0
			for sy in samples:
				for sx in samples:
					var point := Vector2(x + (sx + 0.5) / samples, y + (sy + 0.5) / samples)
					if Geometry2D.is_point_in_polygon(point, polygon):
						covered += 1
			var coverage := float(covered) / (samples * samples)
			#Warm gold with a lighter middle, so it reads on the pale street
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center) / outer
			var tone := Palette.GOLD.lerp(Color.WHITE, clampf(1.0 - distance * 1.4, 0.0, 0.55))
			image.set_pixel(x, y, Color(tone, coverage))
	_star = ImageTexture.create_from_image(image)
	return _star


static func _fade_curve() -> Curve:
	if _fade == null:
		_fade = Curve.new()
		_fade.add_point(Vector2(0.0, 1.0))
		_fade.add_point(Vector2(1.0, 0.0))
	return _fade


static func _release(parent: Node3D, effect: CPUParticles3D, at: Vector3, life: float) -> void:
	parent.add_child(effect)
	effect.global_position = at
	effect.emitting = true
	effect.get_tree().create_timer(life + 0.3).timeout.connect(effect.queue_free)
