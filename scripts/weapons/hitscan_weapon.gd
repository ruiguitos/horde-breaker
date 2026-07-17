extends Node3D

signal shot_fired(hit_position: Vector3, hit_collider: Object)
signal ammunition_changed(current_ammunition: int, magazine_size: int)
signal reload_started(duration: float)

const HIT_COLLISION_MASK: int = (1 << 0) | (1 << 2)
const MUZZLE_FLASH_DURATION := 0.05
const TRACER_DURATION := 0.06
const TRACER_THICKNESS := 0.025
const AIM_RAY_EXTENSION := 0.1

@export_range(0.1, 1000.0, 0.1) var damage: float = 25.0
@export_range(0.1, 30.0, 0.1) var fire_rate: float = 6.0
@export_range(1.0, 500.0, 1.0) var maximum_range: float = 100.0
@export_range(1, 200, 1) var magazine_size: int = 30
@export_range(0.1, 10.0, 0.1) var reload_duration: float = 1.5
@export_range(1, 20, 1) var pellet_count: int = 1
@export_range(0.0, 20.0, 0.5) var spread_degrees: float = 0.0
@export var automatic_fire: bool = true
@export var weapon_id: StringName = &"assault_rifle"
@export var display_name: String = "Assault Rifle"

@onready var muzzle: Marker3D = %Muzzle
@onready var muzzle_flash: MeshInstance3D = %MuzzleFlash
@onready var muzzle_flash_timer: Timer = %MuzzleFlashTimer
@onready var reload_timer: Timer = %ReloadTimer

var current_ammunition: int
var _cooldown_remaining: float = 0.0
var _reload_duration_multiplier: float = 1.0
var _tracer_material: StandardMaterial3D


func _ready() -> void:
	muzzle_flash_timer.timeout.connect(_hide_muzzle_flash)
	reload_timer.timeout.connect(_finish_reload)
	reload_timer.wait_time = _get_effective_reload_duration()
	current_ammunition = magazine_size
	_tracer_material = StandardMaterial3D.new()
	_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_material.albedo_color = Color(1.0, 0.75, 0.15, 1.0)
	_tracer_material.emission_enabled = true
	_tracer_material.emission = Color(1.0, 0.55, 0.05, 1.0)
	_tracer_material.emission_energy_multiplier = 2.0


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_update_weapon_aim()
	if Input.is_action_pressed("reload"):
		_start_reload()
	var attack_requested := (
		Input.is_action_pressed("attack")
		if automatic_fire
		else Input.is_action_just_pressed("attack")
	)
	if (
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and attack_requested
		and _cooldown_remaining <= 0.0
		and reload_timer.is_stopped()
	):
		if current_ammunition <= 0:
			_start_reload()
			return
		_fire()
		current_ammunition -= 1
		ammunition_changed.emit(current_ammunition, magazine_size)
		_cooldown_remaining = 1.0 / fire_rate


func _start_reload() -> void:
	if current_ammunition >= magazine_size or not reload_timer.is_stopped():
		return
	var effective_duration := _get_effective_reload_duration()
	reload_timer.start(effective_duration)
	reload_started.emit(effective_duration)


func _finish_reload() -> void:
	current_ammunition = magazine_size
	ammunition_changed.emit(current_ammunition, magazine_size)


func _fire() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("HitscanWeapon requires an active Camera3D.")
		return

	var aim_position := _get_camera_aim_position(camera)
	_aim_weapon_at(aim_position)
	var ray_origin := muzzle.global_position
	var base_direction := ray_origin.direction_to(aim_position)
	if base_direction == Vector3.ZERO:
		return
	var reported_hit_position := aim_position
	var reported_hit_collider: Object = null
	for pellet_index in range(pellet_count):
		var pellet_direction := _get_pellet_direction(base_direction, pellet_index)
		var pellet_end := ray_origin + pellet_direction * (
			maximum_range + AIM_RAY_EXTENSION
		)
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin, pellet_end, HIT_COLLISION_MASK
		)
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		var hit_position := pellet_end
		var hit_collider: Object = null
		if not result.is_empty():
			hit_position = result["position"]
			hit_collider = result["collider"]
			if hit_collider != null and hit_collider.has_method("take_damage"):
				hit_collider.call("take_damage", damage)
		if pellet_index == 0:
			reported_hit_position = hit_position
			reported_hit_collider = hit_collider
		_show_tracer(muzzle.global_position, hit_position)

	muzzle_flash.visible = true
	muzzle_flash_timer.start(MUZZLE_FLASH_DURATION)
	shot_fired.emit(reported_hit_position, reported_hit_collider)


func set_reload_duration_multiplier(multiplier: float) -> void:
	_reload_duration_multiplier = maxf(multiplier, 0.1)
	reload_timer.wait_time = _get_effective_reload_duration()


func cancel_reload() -> void:
	reload_timer.stop()


func _get_effective_reload_duration() -> float:
	return reload_duration * _reload_duration_multiplier


func _get_pellet_direction(base_direction: Vector3, pellet_index: int) -> Vector3:
	if pellet_count <= 1 or pellet_index == 0 or is_zero_approx(spread_degrees):
		return base_direction
	var spread_basis := Basis.looking_at(base_direction, Vector3.UP)
	var normalized_radius := sqrt(
		float(pellet_index) / float(maxi(pellet_count - 1, 1))
	)
	var angle := float(pellet_index) * 2.399963
	var spread_radius := tan(deg_to_rad(spread_degrees)) * normalized_radius
	return (
		-spread_basis.z
		+ spread_basis.x * cos(angle) * spread_radius
		+ spread_basis.y * sin(angle) * spread_radius
	).normalized()


func _update_weapon_aim() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_aim_weapon_at(_get_camera_aim_position(camera))


func _get_camera_aim_position(camera: Camera3D) -> Vector3:
	var ray_origin := camera.global_position
	var ray_end := ray_origin - camera.global_basis.z * maximum_range
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin, ray_end, HIT_COLLISION_MASK
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return ray_end
	return result["position"]


func _aim_weapon_at(aim_position: Vector3) -> void:
	if global_position.distance_squared_to(aim_position) <= 0.0001:
		return
	look_at(aim_position, Vector3.UP)


func _show_tracer(start_position: Vector3, end_position: Vector3) -> void:
	var tracer_length := start_position.distance_to(end_position)
	if is_zero_approx(tracer_length):
		return

	var tracer_mesh := BoxMesh.new()
	tracer_mesh.material = _tracer_material
	tracer_mesh.size = Vector3(TRACER_THICKNESS, TRACER_THICKNESS, tracer_length)

	var tracer := MeshInstance3D.new()
	tracer.name = "ShotTracer"
	tracer.mesh = tracer_mesh

	var effect_parent: Node = get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_tree().root
	effect_parent.add_child(tracer)
	tracer.global_position = (start_position + end_position) * 0.5
	tracer.look_at(end_position, Vector3.UP)
	get_tree().create_timer(TRACER_DURATION).timeout.connect(tracer.queue_free)


func _hide_muzzle_flash() -> void:
	muzzle_flash.visible = false
