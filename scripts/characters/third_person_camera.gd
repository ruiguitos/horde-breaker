extends Node3D

@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.003
@export_range(-80.0, -5.0, 1.0) var minimum_pitch_degrees: float = -50.0
@export_range(5.0, 80.0, 1.0) var maximum_pitch_degrees: float = 30.0

@onready var spring_arm: SpringArm3D = %SpringArm3D

var _pitch: float


func _ready() -> void:
	_pitch = spring_arm.rotation.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_mouse_capture()
		get_viewport().set_input_as_handled()
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion == null:
		return

	rotation.y = wrapf(
		rotation.y - mouse_motion.relative.x * mouse_sensitivity, -PI, PI
	)
	_pitch = clampf(
		_pitch - mouse_motion.relative.y * mouse_sensitivity,
		deg_to_rad(minimum_pitch_degrees),
		deg_to_rad(maximum_pitch_degrees)
	)
	spring_arm.rotation.x = _pitch
	get_viewport().set_input_as_handled()


func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
