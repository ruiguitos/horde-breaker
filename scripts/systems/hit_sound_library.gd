class_name HitSoundLibrary
extends RefCounted

## Synthesizes the two impact sounds at runtime so the prototype needs no
## external audio assets. Streams are built once and shared.

const MIX_RATE := 22050

static var _body_hit_stream: AudioStreamWAV
static var _headshot_stream: AudioStreamWAV


static func get_body_hit_stream() -> AudioStreamWAV:
	if _body_hit_stream == null:
		_body_hit_stream = _synthesize_tone(0.09, 165.0, 85.0, 0.5, 26.0)
	return _body_hit_stream


static func get_headshot_stream() -> AudioStreamWAV:
	if _headshot_stream == null:
		_headshot_stream = _synthesize_tone(0.14, 920.0, 660.0, 0.45, 20.0)
	return _headshot_stream


static func _synthesize_tone(
	duration: float,
	start_frequency: float,
	end_frequency: float,
	amplitude: float,
	decay_rate: float
) -> AudioStreamWAV:
	var frame_count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var phase := 0.0
	for frame_index in frame_count:
		var progress := float(frame_index) / float(frame_count)
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / MIX_RATE
		var envelope := exp(-decay_rate * progress)
		var sample := sin(phase) * amplitude * envelope
		sample += sin(phase * 2.0) * amplitude * 0.35 * envelope
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(frame_index * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
