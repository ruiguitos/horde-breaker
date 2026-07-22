extends Node3D

@export_range(0.0, 20.0, 0.1) var orbit_speed_degrees: float = 5.0
@export var orbit_radius: float = 17.0
@export var orbit_height: float = 7.0
@export var look_target := Vector3(0.0, 1.25, 0.0)

@onready var camera: Camera3D = %Camera3D

var _orbit_angle := deg_to_rad(38.0)


func _ready() -> void:
	_update_camera()


func _process(delta: float) -> void:
	_orbit_angle += deg_to_rad(orbit_speed_degrees) * delta
	_update_camera()


func _update_camera() -> void:
	camera.position = look_target + Vector3(
		sin(_orbit_angle) * orbit_radius,
		orbit_height,
		cos(_orbit_angle) * orbit_radius
	)
	camera.look_at(look_target, Vector3.UP)
