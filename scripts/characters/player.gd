extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal died
signal noclip_changed(enabled: bool)

@export_range(1.0, 1000.0, 1.0) var maximum_health: float = 100.0
@export_range(0.1, 20.0, 0.1) var move_speed: float = 4.0
@export_range(0.1, 30.0, 0.1) var sprint_speed: float = 7.0
@export_range(0.1, 10.0, 0.1) var crouch_speed: float = 2.5
@export_range(0.1, 20.0, 0.1) var jump_velocity: float = 6.0
@export_range(0.1, 30.0, 0.1) var rotation_speed: float = 10.0
@export_range(1.0, 2.0, 0.05) var crouching_height: float = 1.2
@export_range(0.0, 1.0, 0.05) var crouch_camera_drop: float = 0.35
@export_range(1.0, 30.0, 0.5) var crouch_transition_speed: float = 8.0
@export_range(0.0, 100.0, 0.5) var health_regeneration_rate: float = 1.0
@export_range(0.0, 30.0, 0.5) var health_regeneration_delay: float = 6.0
@export_range(0.0, 0.9, 0.01) var damage_reduction: float = 0.0
@export_range(1.0, 100.0, 1.0) var noclip_speed: float = 18.0
@export_range(1.0, 10.0, 0.5) var noclip_boost_multiplier: float = 3.0

@onready var camera: Camera3D = %Camera3D
@onready var visual_root: Node3D = %VisualRoot
@onready var interaction_area: Area3D = %InteractionArea
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = %SpringArm3D
@onready var noclip_label: Label = %NoclipLabel
@onready var weapon_controller: Node = $VisualRoot/WeaponPivot

const KNOCKBACK_DECAY := 9.0

var current_health: float
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _knockback_velocity := Vector3.ZERO
var _is_dead: bool = false
var _is_crouching: bool = false
var _is_sprinting: bool = false
var _jump_requested: bool = false
var _time_since_damage: float = 0.0
var _standing_height: float
var _standing_collision_y: float
var _standing_camera_y: float
var _gameplay_input_enabled: bool = true
var _build_mode_active: bool = false
var _noclip_enabled: bool = false
var _last_safe_position := Vector3.ZERO
var _collision_layer_before_noclip: int
var _collision_mask_before_noclip: int
var _spring_arm_mask_before_noclip: int
# Heavy weapons slow the operative down while equipped. Kept apart from
# move_speed so the run upgrades can keep scaling the base value freely.
var _weapon_speed_multiplier: float = 1.0


func configure_character(
	character_data: CharacterData,
	primary_weapon_id: StringName = &"",
	secondary_weapon_id: StringName = &""
) -> void:
	if character_data == null:
		push_error("Player requires valid CharacterData.")
		return
	maximum_health = character_data.base_health
	health_regeneration_rate = character_data.health_regeneration_rate
	health_regeneration_delay = character_data.health_regeneration_delay
	var weapon_controller := get_node("VisualRoot/WeaponPivot")
	if weapon_controller.has_method(&"configure"):
		weapon_controller.call(
			&"configure",
			character_data,
			primary_weapon_id,
			secondary_weapon_id
		)


func _ready() -> void:
	current_health = maximum_health
	var capsule := collision_shape.shape.duplicate() as CapsuleShape3D
	if capsule == null:
		push_error("Player CollisionShape3D requires a CapsuleShape3D.")
	else:
		collision_shape.shape = capsule
		_standing_height = capsule.height
	_standing_collision_y = collision_shape.position.y
	_standing_camera_y = camera_pivot.position.y
	_last_safe_position = global_position
	noclip_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if (
		OS.is_debug_build()
		and event.is_action_pressed("toggle_noclip")
	):
		set_noclip_enabled(not _noclip_enabled)
		get_viewport().set_input_as_handled()
		return
	if _noclip_enabled:
		return
	if not _gameplay_input_enabled:
		return
	if event.is_action_pressed("jump"):
		_jump_requested = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if _build_mode_active:
			return
		_try_interact(&"interact")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("structure_demolish"):
		if _build_mode_active:
			return
		_try_interact(&"demolish")
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _noclip_enabled:
		_update_noclip_movement(delta)
		return
	_time_since_damage += delta
	_regenerate_health(delta)
	if not _gameplay_input_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return
	_update_crouch_state()
	_update_camera_height(delta)
	if is_on_floor():
		if _jump_requested and not _is_crouching:
			velocity.y = jump_velocity
		else:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	_jump_requested = false

	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)
	var movement_direction := _get_camera_relative_direction(input_direction)
	_is_sprinting = (
		Input.is_action_pressed("sprint")
		and not _is_crouching
		and movement_direction != Vector3.ZERO
	)
	var current_speed := move_speed
	if _is_crouching:
		current_speed = crouch_speed
	elif _is_sprinting:
		current_speed = sprint_speed
	current_speed *= _weapon_speed_multiplier

	velocity.x = movement_direction.x * current_speed
	velocity.z = movement_direction.z * current_speed

	# Knockback from Brute/Boss hits is added on top of input and decays fast.
	if _knockback_velocity.length_squared() > 0.01:
		velocity.x += _knockback_velocity.x
		velocity.z += _knockback_velocity.z
		_knockback_velocity = _knockback_velocity.move_toward(
			Vector3.ZERO, KNOCKBACK_DECAY * delta
		)
	else:
		_knockback_velocity = Vector3.ZERO

	var facing_direction := movement_direction
	if (
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and not Input.is_action_pressed("camera_front")
	):
		facing_direction = _get_horizontal_camera_forward()
	if facing_direction != Vector3.ZERO:
		var target_rotation := atan2(-facing_direction.x, -facing_direction.z)
		visual_root.rotation.y = rotate_toward(
			visual_root.rotation.y, target_rotation, rotation_speed * delta
		)

	move_and_slide()
	if is_on_floor():
		_last_safe_position = global_position


func set_noclip_enabled(enabled: bool) -> void:
	if enabled == _noclip_enabled:
		return
	if enabled and not OS.is_debug_build():
		return
	_noclip_enabled = enabled
	velocity = Vector3.ZERO
	_jump_requested = false
	_is_sprinting = false
	noclip_label.visible = enabled
	if enabled:
		_last_safe_position = global_position
		_collision_layer_before_noclip = collision_layer
		_collision_mask_before_noclip = collision_mask
		_spring_arm_mask_before_noclip = spring_arm.collision_mask
		collision_layer = 0
		collision_mask = 0
		spring_arm.collision_mask = 0
		weapon_controller.process_mode = Node.PROCESS_MODE_DISABLED
		remove_from_group(&"enemy_target")
	else:
		collision_layer = _collision_layer_before_noclip
		collision_mask = _collision_mask_before_noclip
		spring_arm.collision_mask = _spring_arm_mask_before_noclip
		weapon_controller.process_mode = Node.PROCESS_MODE_INHERIT
		if not _is_dead and not is_in_group(&"enemy_target"):
			add_to_group(&"enemy_target")
		_place_after_noclip()
	noclip_changed.emit(enabled)


func is_noclip_enabled() -> bool:
	return _noclip_enabled


func _update_noclip_movement(delta: float) -> void:
	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)
	var movement_direction := _get_camera_relative_direction(input_direction)
	var vertical_direction := Input.get_axis("crouch", "jump")
	var direction := movement_direction + Vector3.UP * vertical_direction
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var speed := noclip_speed
	if Input.is_action_pressed("sprint"):
		speed *= noclip_boost_multiplier
	global_position += direction * speed * delta
	velocity = Vector3.ZERO


func _place_after_noclip() -> void:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 2.0,
		global_position + Vector3.DOWN * 250.0,
		_collision_mask_before_noclip,
		[get_rid()]
	)
	query.collide_with_areas = false
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		global_position = _last_safe_position
		return
	var floor_offset := maxf(_standing_height * 0.5, 1.0) + 0.05
	global_position = Vector3(
		global_position.x,
		(result["position"] as Vector3).y + floor_offset,
		global_position.z
	)


func set_gameplay_input_enabled(enabled: bool) -> void:
	_gameplay_input_enabled = enabled
	_jump_requested = false
	if not enabled:
		_is_sprinting = false
		velocity.x = 0.0
		velocity.z = 0.0


func set_weapon_speed_multiplier(multiplier: float) -> void:
	_weapon_speed_multiplier = clampf(multiplier, 0.1, 2.0)


func get_weapon_speed_multiplier() -> float:
	return _weapon_speed_multiplier


func set_build_mode_active(active: bool) -> void:
	_build_mode_active = active
	if active:
		_jump_requested = false


func is_build_mode_active() -> bool:
	return _build_mode_active


func is_crouching() -> bool:
	return _is_crouching


func is_sprinting() -> bool:
	return _is_sprinting


func add_ammunition(amount: int) -> int:
	if amount <= 0:
		return 0
	var weapon_controller := get_node("VisualRoot/WeaponPivot")
	if not weapon_controller.has_method(&"add_ammunition"):
		return 0
	return int(weapon_controller.call(&"add_ammunition", amount))


func take_damage(amount: float) -> void:
	if amount <= 0.0 or _is_dead or _noclip_enabled:
		return

	var reduced_amount := amount * (1.0 - clampf(damage_reduction, 0.0, 0.9))
	_time_since_damage = 0.0
	current_health = maxf(current_health - reduced_amount, 0.0)
	health_changed.emit(current_health, maximum_health)
	if is_zero_approx(current_health):
		_is_dead = true
		remove_from_group(&"enemy_target")
		velocity = Vector3.ZERO
		set_physics_process(false)
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or _is_dead or current_health >= maximum_health:
		return
	current_health = minf(current_health + amount, maximum_health)
	health_changed.emit(current_health, maximum_health)


func apply_knockback(direction: Vector3, force: float) -> void:
	if _is_dead or force <= 0.0:
		return
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.length_squared() <= 0.0001:
		return
	_knockback_velocity = horizontal.normalized() * force


func _regenerate_health(delta: float) -> void:
	if (
		health_regeneration_rate <= 0.0
		or _time_since_damage < health_regeneration_delay
		or current_health >= maximum_health
	):
		return
	heal(health_regeneration_rate * delta)


func _update_crouch_state() -> void:
	var wants_to_crouch := Input.is_action_pressed("crouch")
	if wants_to_crouch and not _is_crouching and is_on_floor():
		_set_crouching(true)
	elif not wants_to_crouch and _is_crouching and _can_stand_up():
		_set_crouching(false)


func _set_crouching(is_crouching: bool) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	_is_crouching = is_crouching
	var target_height := crouching_height if _is_crouching else _standing_height
	capsule.height = target_height
	var center_drop := (_standing_height - target_height) * 0.5
	collision_shape.position.y = _standing_collision_y - center_drop


func _can_stand_up() -> bool:
	var current_capsule := collision_shape.shape as CapsuleShape3D
	if current_capsule == null:
		return true
	var standing_capsule := current_capsule.duplicate() as CapsuleShape3D
	standing_capsule.height = _standing_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_capsule
	var test_transform := collision_shape.global_transform
	test_transform.origin += Vector3.UP * (
		(_standing_height - current_capsule.height) * 0.5 + 0.01
	)
	query.transform = test_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_camera_height(delta: float) -> void:
	var target_height := _standing_camera_y
	if _is_crouching:
		target_height -= crouch_camera_drop
	camera_pivot.position.y = move_toward(
		camera_pivot.position.y,
		target_height,
		crouch_transition_speed * delta
	)


func _try_interact(method: StringName) -> void:
	var closest_area: Area3D
	var closest_distance_squared := INF
	for area in interaction_area.get_overlapping_areas():
		if not area.has_method(method):
			continue
		var distance_squared := global_position.distance_squared_to(
			area.global_position
		)
		if distance_squared < closest_distance_squared:
			closest_area = area
			closest_distance_squared = distance_squared
	if closest_area != null:
		closest_area.call(method, self)


func _get_camera_relative_direction(input_direction: Vector2) -> Vector3:
	if Input.is_action_pressed("camera_front"):
		var character_forward := -visual_root.global_basis.z
		character_forward.y = 0.0
		character_forward = character_forward.normalized()
		var character_right := visual_root.global_basis.x
		character_right.y = 0.0
		character_right = character_right.normalized()
		return (
			character_right * input_direction.x
			- character_forward * input_direction.y
		)
	var camera_forward := _get_horizontal_camera_forward()

	var camera_right := camera.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()

	return camera_right * input_direction.x - camera_forward * input_direction.y


func _get_horizontal_camera_forward() -> Vector3:
	var camera_forward := -camera.global_basis.z
	camera_forward.y = 0.0
	return camera_forward.normalized()
