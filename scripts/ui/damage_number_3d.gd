extends Label3D

const NORMAL_DAMAGE_COLOR := Color(0.92, 0.94, 0.95, 1.0)
const HEADSHOT_DAMAGE_COLOR := Color(1.0, 0.67, 0.18, 1.0)
const FADE_START := 0.35

@export_range(0.1, 2.0, 0.05) var lifetime: float = 0.65
@export_range(0.05, 2.0, 0.05) var rise_distance: float = 0.45
@export_range(0.0, 0.5, 0.01) var horizontal_jitter: float = 0.08

var _elapsed_time: float = 0.0


func _ready() -> void:
	set_process(false)


func configure(damage_amount: float, is_headshot: bool) -> void:
	if damage_amount <= 0.0:
		queue_free()
		return
	text = str(roundi(damage_amount))
	modulate = HEADSHOT_DAMAGE_COLOR if is_headshot else NORMAL_DAMAGE_COLOR
	_play_impact_sound(is_headshot)
	global_position += Vector3(
		randf_range(-horizontal_jitter, horizontal_jitter),
		0.0,
		randf_range(-horizontal_jitter, horizontal_jitter)
	)
	_elapsed_time = 0.0
	set_process(true)


func _play_impact_sound(is_headshot: bool) -> void:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = (
		HitSoundLibrary.get_headshot_stream()
		if is_headshot
		else HitSoundLibrary.get_body_hit_stream()
	)
	audio.volume_db = -4.0 if is_headshot else -8.0
	audio.max_distance = 40.0
	add_child(audio)
	audio.play()


func _process(delta: float) -> void:
	_elapsed_time += delta
	global_position.y += rise_distance * delta / lifetime
	var progress := clampf(_elapsed_time / lifetime, 0.0, 1.0)
	if progress > FADE_START:
		var fade_progress := (progress - FADE_START) / (1.0 - FADE_START)
		modulate.a = 1.0 - fade_progress
	if _elapsed_time >= lifetime:
		queue_free()
