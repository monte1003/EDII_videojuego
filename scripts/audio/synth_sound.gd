class_name SynthSound
extends RefCounted

#Small sound effects made from math, so the game needs no audio files for them; each one is made once and kept

const MIX_RATE := 22050

static var _cache: Dictionary = {}


#A beep that fades out; "sweep" slides its frequency (in Hz) over its length
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


#A body blow: a low note that drops fast and a short crack at the start
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


#A crash: the thump plus a burst of dull noise, for a car that hits
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


#A short car horn: two close notes held and cut
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


#A soft landing: a quick low puff
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


#A player that plays one of these sounds; the node frees itself when it ends
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
