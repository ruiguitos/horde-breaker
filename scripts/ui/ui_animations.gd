class_name UiAnimations
extends RefCounted

## Small shared helpers for menu/HUD entrance animations.
## All tweens keep running while the tree is paused so overlay menus animate.

const BUTTON_HOVER_SCALE := Vector2(1.03, 1.03)
const BUTTON_PRESS_SCALE := Vector2(0.985, 0.985)
const BUTTON_HOVER_MODULATE := Color(1.08, 1.01, 0.88, 1.0)
const BUTTON_PRESS_MODULATE := Color(1.32, 0.88, 0.42, 1.0)
const BUTTON_TWEEN_META := &"ui_juice_tween"
const BUTTON_CONNECTED_META := &"ui_juice_connected"
const BUTTON_HOVERED_META := &"ui_juice_hovered"


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
	slide_fade_in(control, Vector2(-distance, 0.0), 0.0, duration)


static func slide_fade_in(
	control: Control,
	start_offset: Vector2,
	delay: float = 0.0,
	duration: float = 0.28
) -> void:
	control.modulate.a = 0.0
	control.position += start_offset
	var target_position := control.position - start_offset
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.8).set_delay(delay)
	tween.tween_property(control, "position", target_position, duration).set_delay(delay)


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


static func enhance_buttons(root: Node) -> void:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button.has_meta(BUTTON_CONNECTED_META):
			continue
		button.set_meta(BUTTON_CONNECTED_META, true)
		button.set_meta(BUTTON_HOVERED_META, false)
		button.pivot_offset = button.size * 0.5
		button.mouse_entered.connect(_on_button_hovered.bind(button, true))
		button.mouse_exited.connect(_on_button_hovered.bind(button, false))
		button.focus_entered.connect(_on_button_hovered.bind(button, true))
		button.focus_exited.connect(_on_button_hovered.bind(button, false))
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))


static func count_integer(
	label: Label,
	from_value: int,
	to_value: int,
	prefix: String,
	suffix: String = "",
	duration: float = 0.45
) -> void:
	var previous = (
		label.get_meta(&"ui_count_tween")
		if label.has_meta(&"ui_count_tween")
		else null
	)
	if previous is Tween:
		previous.kill()
	if from_value == to_value or duration <= 0.0:
		_set_integer_label(float(to_value), label, prefix, suffix)
		return
	var tween := label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	label.set_meta(&"ui_count_tween", tween)
	tween.tween_method(
		_set_integer_label.bind(label, prefix, suffix),
		float(from_value),
		float(to_value),
		duration
	)


static func _on_button_hovered(button: Button, is_hovered: bool) -> void:
	button.set_meta(BUTTON_HOVERED_META, is_hovered)
	if button.disabled and is_hovered:
		return
	_animate_button(
		button,
		BUTTON_HOVER_SCALE if is_hovered else Vector2.ONE,
		BUTTON_HOVER_MODULATE if is_hovered else Color.WHITE,
		0.11
	)


static func _on_button_down(button: Button) -> void:
	_animate_button(button, BUTTON_PRESS_SCALE, BUTTON_PRESS_MODULATE, 0.055)


static func _on_button_up(button: Button) -> void:
	var is_hovered := bool(button.get_meta(BUTTON_HOVERED_META, false))
	_animate_button(
		button,
		BUTTON_HOVER_SCALE if is_hovered else Vector2.ONE,
		BUTTON_HOVER_MODULATE if is_hovered else Color.WHITE,
		0.1
	)


static func _animate_button(
	button: Button, target_scale: Vector2, target_modulate: Color, duration: float
) -> void:
	var previous = (
		button.get_meta(BUTTON_TWEEN_META)
		if button.has_meta(BUTTON_TWEEN_META)
		else null
	)
	if previous is Tween:
		previous.kill()
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	button.set_meta(BUTTON_TWEEN_META, tween)
	tween.tween_property(button, "scale", target_scale, duration)
	tween.tween_property(button, "modulate", target_modulate, duration)


static func _set_integer_label(
	value: float, label: Label, prefix: String, suffix: String
) -> void:
	label.text = "%s%d%s" % [prefix, roundi(value), suffix]
