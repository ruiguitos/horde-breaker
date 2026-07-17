extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal died

@export_range(1.0, 1000.0, 1.0) var maximum_health: float = 100.0
@export var move_speed: float = 6.0
@export var rotation_speed: float = 10.0

@onready var camera: Camera3D = %Camera3D
@onready var visual_root: Node3D = %VisualRoot

var current_health: float
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _is_dead: bool = false


func _ready() -> void:
	current_health = maximum_health


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)
	var movement_direction := _get_camera_relative_direction(input_direction)

	velocity.x = movement_direction.x * move_speed
	velocity.z = movement_direction.z * move_speed

	var facing_direction := movement_direction
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		facing_direction = _get_horizontal_camera_forward()
	if facing_direction != Vector3.ZERO:
		var target_rotation := atan2(-facing_direction.x, -facing_direction.z)
		visual_root.rotation.y = rotate_toward(
			visual_root.rotation.y, target_rotation, rotation_speed * delta
		)

	move_and_slide()


func take_damage(amount: float) -> void:
	if amount <= 0.0 or _is_dead:
		return

	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, maximum_health)
	if is_zero_approx(current_health):
		_is_dead = true
		velocity = Vector3.ZERO
		set_physics_process(false)
		died.emit()


func _get_camera_relative_direction(input_direction: Vector2) -> Vector3:
	var camera_forward := _get_horizontal_camera_forward()

	var camera_right := camera.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()

	return camera_right * input_direction.x - camera_forward * input_direction.y


func _get_horizontal_camera_forward() -> Vector3:
	var camera_forward := -camera.global_basis.z
	camera_forward.y = 0.0
	return camera_forward.normalized()
