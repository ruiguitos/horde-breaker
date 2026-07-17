extends Node3D

@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.003
@export_range(-80.0, -5.0, 1.0) var minimum_pitch_degrees: float = -50.0
@export_range(5.0, 80.0, 1.0) var maximum_pitch_degrees: float = 30.0
@export_range(30.0, 90.0, 1.0) var aim_fov: float = 55.0
@export_range(1.0, 10.0, 0.1) var aim_spring_length: float = 3.2
@export_range(0.0, 2.0, 0.05) var aim_shoulder_offset: float = 0.75
@export_range(1.0, 30.0, 0.5) var aim_transition_speed: float = 10.0

@onready var spring_arm: SpringArm3D = %SpringArm3D
@onready var camera: Camera3D = %Camera3D
@onready var shoulder_offset: Node3D = $ShoulderOffset
@onready var visual_root: Node3D = get_parent().get_node("VisualRoot")

var _pitch: float
var _normal_fov: float
var _normal_spring_length: float
var _normal_shoulder_offset: float
var _front_view_active: bool = false
var _saved_yaw: float


func _ready() -> void:
	_pitch = spring_arm.rotation.x
	_normal_fov = camera.fov
	_normal_spring_length = spring_arm.spring_length
	_normal_shoulder_offset = shoulder_offset.position.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if _front_view_active and not Input.is_action_pressed("camera_front"):
		_exit_front_view()
	var is_aiming := (
		Input.is_action_pressed("aim")
		and not _front_view_active
	)
	var target_fov := aim_fov if is_aiming else _normal_fov
	var target_spring_length := (
		aim_spring_length if is_aiming else _normal_spring_length
	)
	var target_shoulder_offset := (
		aim_shoulder_offset if is_aiming else _normal_shoulder_offset
	)
	camera.fov = move_toward(
		camera.fov, target_fov, aim_transition_speed * 10.0 * delta
	)
	spring_arm.spring_length = move_toward(
		spring_arm.spring_length,
		target_spring_length,
		aim_transition_speed * delta
	)
	shoulder_offset.position.x = move_toward(
		shoulder_offset.position.x,
		target_shoulder_offset,
		aim_transition_speed * delta
	)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("camera_front") and not _front_view_active:
		_enter_front_view()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("camera_front") and _front_view_active:
		_exit_front_view()
		get_viewport().set_input_as_handled()
		return
	if _front_view_active:
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


func _enter_front_view() -> void:
	_front_view_active = true
	_saved_yaw = rotation.y
	rotation.y = wrapf(visual_root.rotation.y + PI, -PI, PI)


func _exit_front_view() -> void:
	_front_view_active = false
	rotation.y = _saved_yaw
