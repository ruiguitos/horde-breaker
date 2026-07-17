extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal attacked(target: Node, damage: float)
signal died(enemy: Node)

const ENEMY_TARGET_GROUP := &"enemy_target"
const TARGET_REPATH_DISTANCE := 0.25

@export_range(1.0, 1000.0, 1.0) var maximum_health: float = 50.0
@export_range(0.1, 20.0, 0.1) var move_speed: float = 2.5
@export_range(0.1, 1000.0, 0.1) var attack_damage: float = 10.0
@export_range(0.5, 5.0, 0.1) var attack_range: float = 1.4
@export_range(0.1, 10.0, 0.1) var attack_cooldown: float = 1.0
@export_range(0.1, 30.0, 0.1) var rotation_speed: float = 8.0
@export_range(0, 1000, 1) var xp_reward: int = 5

@onready var navigation_agent: NavigationAgent3D = %NavigationAgent3D
@onready var attack_area: Area3D = %AttackArea
@onready var attack_collision: CollisionShape3D = %AttackCollision
@onready var attack_cooldown_timer: Timer = %AttackCooldownTimer
@onready var visual_root: Node3D = %VisualRoot

var current_health: float
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _target: PhysicsBody3D


func _ready() -> void:
	current_health = maximum_health
	_target = _find_nearest_target()
	if _target == null:
		push_error("NormalZombie requires a PhysicsBody3D in the enemy_target group.")

	var attack_shape := attack_collision.shape.duplicate() as SphereShape3D
	if attack_shape == null:
		push_error("NormalZombie AttackCollision requires a SphereShape3D.")
	else:
		attack_shape.radius = attack_range
		attack_collision.shape = attack_shape
	navigation_agent.target_desired_distance = attack_range * 0.8


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_target = _find_nearest_target()
	if not is_instance_valid(_target):
		_stop_horizontal_movement()
		move_and_slide()
		return

	if _is_target_in_attack_range():
		_stop_horizontal_movement()
		_try_attack()
	else:
		_pursue_target(delta)

	move_and_slide()


func _find_nearest_target() -> PhysicsBody3D:
	var nearest_target: PhysicsBody3D
	var nearest_distance_squared := INF
	for node in get_tree().get_nodes_in_group(ENEMY_TARGET_GROUP):
		var candidate := node as PhysicsBody3D
		if candidate == null:
			continue
		if (
			not candidate.has_method(&"take_damage")
			and not candidate.has_method(&"take_enemy_damage")
		):
			continue
		var distance_squared := global_position.distance_squared_to(
			candidate.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest_target = candidate
			nearest_distance_squared = distance_squared
	return nearest_target


func _is_target_in_attack_range() -> bool:
	if attack_area.overlaps_body(_target):
		return true
	if not _target.has_method(&"get_attack_target_radius"):
		return false
	var target_radius := float(_target.call(&"get_attack_target_radius"))
	var horizontal_offset := Vector2(
		_target.global_position.x - global_position.x,
		_target.global_position.z - global_position.z
	)
	return horizontal_offset.length() <= attack_range + target_radius


func take_damage(amount: float) -> float:
	if amount <= 0.0 or current_health <= 0.0:
		return 0.0

	var applied_damage := minf(amount, current_health)
	current_health -= applied_damage
	health_changed.emit(current_health, maximum_health)
	if is_zero_approx(current_health):
		died.emit(self)
		queue_free()
	return applied_damage


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta


func _pursue_target(delta: float) -> void:
	if navigation_agent.target_position.distance_to(
		_target.global_position
	) >= TARGET_REPATH_DISTANCE:
		navigation_agent.target_position = _target.global_position
	var navigation_map := navigation_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		_stop_horizontal_movement()
		return
	if navigation_agent.is_navigation_finished():
		_stop_horizontal_movement()
		return

	var next_path_position := navigation_agent.get_next_path_position()
	next_path_position.y = global_position.y
	var movement_direction := global_position.direction_to(next_path_position)
	movement_direction = movement_direction.normalized()
	velocity.x = movement_direction.x * move_speed
	velocity.z = movement_direction.z * move_speed

	if movement_direction != Vector3.ZERO:
		var target_rotation := atan2(-movement_direction.x, -movement_direction.z)
		visual_root.rotation.y = rotate_toward(
			visual_root.rotation.y, target_rotation, rotation_speed * delta
		)


func _try_attack() -> void:
	if not attack_cooldown_timer.is_stopped():
		return

	attacked.emit(_target, attack_damage)
	if _target.has_method(&"take_enemy_damage"):
		_target.call(&"take_enemy_damage", attack_damage)
	elif _target.has_method(&"take_damage"):
		_target.call("take_damage", attack_damage)
	attack_cooldown_timer.start(attack_cooldown)


func _stop_horizontal_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
