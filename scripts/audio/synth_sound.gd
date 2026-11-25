class_name SynthSound
extends RefCounted

#Sound effects made from math, each built once and cached

const MIX_RATE := 22050

static var _cache: Dictionary = {}


#Fading beep; "sweep" slides its frequency in Hz
static func tone(frequency: float, length: float, sweep := 0.0, volume := 0.55) -> AudioStreamWAV:
	var key := "tone_%s_%s_%s_%s" % [frequency, length, sweep, volume]
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * length)
	var data := _buffer(count)
	var angle := 0.0
	for index in count:
		var progress := float(index) / count
		angle += TAU * (frequency + sweep * progress) / MIX_RATE
		var attack := minf(index / (MIX_RATE * 0.004), 1.0)
		var envelope := attack * pow(1.0 - progress, 2.0)
		_write(data, index, (sin(angle) + 0.3 * sin(angle * 2.0)) * envelope * volume)
	return _store(key, data)


#Body blow: a low falling note with a crack
static func thump(length := 0.32) -> AudioStreamWAV:
	var key := "thump_%s" % length
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * length)
	var data := _buffer(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var angle := 0.0
	for index in count:
		var progress := float(index) / count
		angle += TAU * lerpf(175.0, 40.0, sqrt(progress)) / MIX_RATE
		var body := sin(angle) * pow(1.0 - progress, 2.2)
		var crack := rng.randf_range(-1.0, 1.0) * pow(1.0 - progress, 14.0) * 0.7
		_write(data, index, (body + crack) * 0.9)
	return _store(key, data)


#Car crash: a thump plus dull noise
static func crash(length := 0.5) -> AudioStreamWAV:
	var key := "crash_%s" % length
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * length)
	var data := _buffer(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var angle := 0.0
	var dull := 0.0
	for index in count:
		var progress := float(index) / count
		angle += TAU * lerpf(150.0, 36.0, sqrt(progress)) / MIX_RATE
		dull = lerpf(dull, rng.randf_range(-1.0, 1.0), 0.22)
		var body := sin(angle) * pow(1.0 - progress, 1.8)
		var rattle := dull * pow(1.0 - progress, 3.5) * 1.1
		_write(data, index, clampf((body * 0.8 + rattle) * 0.95, -1.0, 1.0))
	return _store(key, data)


#Short car horn
static func honk(length := 0.26) -> AudioStreamWAV:
	var key := "honk_%s" % length
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * length)
	var data := _buffer(count)
	var low := 0.0
	var high := 0.0
	for index in count:
		var progress := float(index) / count
		low += TAU * 349.0 / MIX_RATE
		high += TAU * 440.0 / MIX_RATE
		var envelope := minf(progress * 40.0, 1.0) * minf((1.0 - progress) * 14.0, 1.0)
		var wave := sin(low) + 0.5 * sin(low * 3.0) + sin(high) + 0.5 * sin(high * 3.0)
		_write(data, index, wave * envelope * 0.2)
	return _store(key, data)


#Soft landing puff
static func land(length := 0.16) -> AudioStreamWAV:
	var key := "land_%s" % length
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * length)
	var data := _buffer(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var dull := 0.0
	for index in count:
		var progress := float(index) / count
		dull = lerpf(dull, rng.randf_range(-1.0, 1.0), 0.12)
		_write(data, index, dull * pow(1.0 - progress, 2.5) * 0.9)
	return _store(key, data)


#Snare roll that grows, for the moment before a reveal
static func roll(length := 2.0) -> AudioStreamWAV:
	var key := "roll_%s" % length
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * length)
	var data := _buffer(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var next_stroke := 0
	var since := 0
	var bright := 0.0
	for index in count:
		var progress := float(index) / count
		if index >= next_stroke:
			since = 0
			next_stroke = index + int(MIX_RATE / lerpf(14.0, 26.0, progress))
		since += 1
		var stroke := exp(-float(since) / (MIX_RATE * 0.018))
		bright = lerpf(bright, rng.randf_range(-1.0, 1.0), 0.6)
		var body := sin(TAU * 190.0 * since / MIX_RATE) * 0.3
		_write(data, index, (bright + body) * stroke * lerpf(0.25, 0.85, progress * progress))
	return _store(key, data)


#Whoosh of air
static func whoosh(length := 0.6) -> AudioStreamWAV:
	var key := "whoosh_%s" % length
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * length)
	var data := _buffer(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var soft := 0.0
	for index in count:
		var progress := float(index) / count
		var swell := sin(PI * progress)
		soft = lerpf(soft, rng.randf_range(-1.0, 1.0), lerpf(0.05, 0.35, swell))
		_write(data, index, soft * swell * swell * 0.9)
	return _store(key, data)


#Bell whose higher partials fade faster
static func chime(frequency: float, length := 1.4) -> AudioStreamWAV:
	var key := "chime_%s_%s" % [frequency, length]
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * length)
	var data := _buffer(count)
	var partials := [[1.0, 1.0, 1.0], [2.0, 0.5, 1.8], [2.76, 0.35, 2.6], [5.4, 0.18, 4.0]]
	for index in count:
		var time := float(index) / MIX_RATE
		var attack := minf(index / (MIX_RATE * 0.003), 1.0)
		var sample := 0.0
		for partial: Array in partials:
			sample += sin(TAU * frequency * float(partial[0]) * time) * float(partial[1]) * exp(-time * float(partial[2]) * 2.2 / length)
		_write(data, index, sample * attack * 0.32)
	return _store(key, data)


#Cheering crowd with claps
static func cheer(length := 3.0) -> AudioStreamWAV:
	var key := "cheer_%s" % length
	if _cache.has(key):
		return _cache[key]
	var count := int(MIX_RATE * length)
	var data := _buffer(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var voice := 0.0
	var low := 0.0
	var clap := 0.0
	for index in count:
		var progress := float(index) / count
		var swell := minf(progress * 6.0, 1.0) * pow(1.0 - progress, 0.7)
		voice = lerpf(voice, rng.randf_range(-1.0, 1.0), 0.18)
		low = lerpf(low, voice, 0.08)
		var murmur := (voice - low) * (0.75 + 0.25 * sin(progress * 40.0 + sin(progress * 13.0) * 3.0))
		if rng.randf() < 0.0016:
			clap = 1.0
		clap *= 0.993
		_write(data, index, (murmur * 1.3 + rng.randf_range(-1.0, 1.0) * clap * 0.35) * swell * 0.8)
	return _store(key, data)


static func play(parent: Node, stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _buffer(count: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(count * 2)
	return data


static func _write(data: PackedByteArray, index: int, sample: float) -> void:
	data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))


static func _store(key: String, data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	_cache[key] = wav
	return wav
