class_name UiAnimations
extends RefCounted

## Small shared helpers for menu/HUD entrance animations.
## All tweens keep running while the tree is paused so overlay menus animate.


static func fade_in(control: Control, delay: float = 0.0, duration: float = 0.3) -> void:
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, duration)


static func slide_in_left(
	control: Control, distance: float = 36.0, duration: float = 0.25
) -> void:
	control.modulate.a = 0.0
	control.position.x -= distance
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.8)
	tween.tween_property(control, "position:x", control.position.x + distance, duration)


static func pop_in(control: Control, duration: float = 0.22) -> void:
	control.pivot_offset = control.size * 0.5
	control.modulate.a = 0.0
	control.scale = Vector2(0.94, 0.94)
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.8)
	tween.tween_property(control, "scale", Vector2.ONE, duration)
