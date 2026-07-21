extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal attacked(target: Node, damage: float)
signal died(enemy: Node)

const PLAYER_GROUP := &"player"
const ALIVE_TARGET_GROUP := &"enemy_target"
const TARGET_REPATH_DISTANCE := 0.25
const HIT_FLASH_COLOR := Color(1.0, 0.82, 0.6, 0.0)
const RANGED_DISTANCE_MARGIN := 1.5

@export_range(1.0, 5000.0, 1.0) var maximum_health: float = 50.0
@export_range(0.1, 20.0, 0.1) var move_speed: float = 2.5
@export_range(0.1, 1000.0, 0.1) var attack_damage: float = 10.0
@export_range(0.5, 5.0, 0.1) var attack_range: float = 1.4
@export_range(0.1, 10.0, 0.1) var attack_cooldown: float = 1.0
@export_range(0.1, 30.0, 0.1) var rotation_speed: float = 8.0
@export_range(0, 1000, 1) var xp_reward: int = 5
@export_range(0.0, 30.0, 0.5) var knockback_force: float = 0.0
@export var is_ranged: bool = false
@export_range(3.0, 24.0, 0.5) var preferred_distance: float = 9.0
@export_range(4.0, 40.0, 0.5) var ranged_attack_range: float = 16.0
@export var projectile_scene: PackedScene

@onready var navigation_agent: NavigationAgent3D = %NavigationAgent3D
@onready var attack_area: Area3D = %AttackArea
@onready var attack_collision: CollisionShape3D = %AttackCollision
@onready var attack_cooldown_timer: Timer = %AttackCooldownTimer
@onready var visual_root: Node3D = %VisualRoot

var current_health: float
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _target: PhysicsBody3D
var _hit_flash_material: StandardMaterial3D
var _hit_flash_tween: Tween


func _ready() -> void:
	current_health = maximum_health
	_setup_hit_flash()

	var attack_shape := attack_collision.shape.duplicate() as SphereShape3D
	if attack_shape == null:
		push_error("NormalZombie AttackCollision requires a SphereShape3D.")
	else:
		attack_shape.radius = attack_range
		attack_collision.shape = attack_shape
	navigation_agent.target_desired_distance = (
		preferred_distance if is_ranged else attack_range * 0.8
	)


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_target = _find_player_target()
	if not is_instance_valid(_target):
		_stop_horizontal_movement()
		move_and_slide()
		return

	if is_ranged:
		_process_ranged(delta)
	elif _is_target_in_attack_range():
		_stop_horizontal_movement()
		_try_attack()
	else:
		_pursue_target(delta)

	move_and_slide()


func _process_ranged(delta: float) -> void:
	# Spitters keep their distance and fire projectiles: close in when too far,
	# back off when too close, and shoot from the sweet spot.
	var horizontal_distance := _horizontal_distance_to_target()
	_face_target(delta)
	if horizontal_distance > preferred_distance + RANGED_DISTANCE_MARGIN:
		_pursue_target(delta)
	elif horizontal_distance < preferred_distance - RANGED_DISTANCE_MARGIN:
		var away := (global_position - _target.global_position)
		away.y = 0.0
		var retreat := away.normalized()
		velocity.x = retreat.x * move_speed
		velocity.z = retreat.z * move_speed
	else:
		_stop_horizontal_movement()
		if horizontal_distance <= ranged_attack_range:
			_try_ranged_attack()


func _find_player_target() -> PhysicsBody3D:
	# Enemies pursue only the player; camp, core and fortifications are
	# never targeted. The player leaves the alive-target group on death.
	for node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		var candidate := node as PhysicsBody3D
		if candidate == null:
			continue
		if not candidate.is_in_group(ALIVE_TARGET_GROUP):
			continue
		if not candidate.has_method(&"take_damage"):
			continue
		return candidate
	return null


func _horizontal_distance_to_target() -> float:
	return Vector2(
		_target.global_position.x - global_position.x,
		_target.global_position.z - global_position.z
	).length()


func _is_target_in_attack_range() -> bool:
	if attack_area.overlaps_body(_target):
		return true
	if not _target.has_method(&"get_attack_target_radius"):
		return false
	var target_radius := float(_target.call(&"get_attack_target_radius"))
	return _horizontal_distance_to_target() <= attack_range + target_radius


func take_damage(amount: float) -> float:
	if amount <= 0.0 or current_health <= 0.0:
		return 0.0

	var applied_damage := minf(amount, current_health)
	current_health -= applied_damage
	health_changed.emit(current_health, maximum_health)
	_play_hit_flash()
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


func _face_target(delta: float) -> void:
	var direction := (_target.global_position - global_position)
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return
	direction = direction.normalized()
	var target_rotation := atan2(-direction.x, -direction.z)
	visual_root.rotation.y = rotate_toward(
		visual_root.rotation.y, target_rotation, rotation_speed * delta
	)


func _try_attack() -> void:
	if not attack_cooldown_timer.is_stopped():
		return

	attacked.emit(_target, attack_damage)
	if _target.has_method(&"take_damage"):
		_target.call("take_damage", attack_damage)
	_apply_knockback_to_target()
	attack_cooldown_timer.start(attack_cooldown)


func _try_ranged_attack() -> void:
	if not attack_cooldown_timer.is_stopped():
		return
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Node3D
	if projectile == null:
		push_error("Ranged enemy requires a Node3D projectile scene.")
		return
	var muzzle_position := global_position + Vector3.UP * 1.2
	var aim_position := _target.global_position + Vector3.UP * 0.6
	var direction := (aim_position - muzzle_position).normalized()
	var effect_parent: Node = get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_tree().root
	effect_parent.add_child(projectile)
	projectile.global_position = muzzle_position
	if projectile.has_method(&"launch"):
		projectile.call(&"launch", direction, attack_damage)
	attacked.emit(_target, attack_damage)
	attack_cooldown_timer.start(attack_cooldown)


func _apply_knockback_to_target() -> void:
	if knockback_force <= 0.0 or not _target.has_method(&"apply_knockback"):
		return
	var direction := (_target.global_position - global_position)
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return
	_target.call(&"apply_knockback", direction.normalized(), knockback_force)


func _stop_horizontal_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _setup_hit_flash() -> void:
	_hit_flash_material = StandardMaterial3D.new()
	_hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hit_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_hit_flash_material.albedo_color = HIT_FLASH_COLOR
	for mesh_instance in visual_root.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).material_overlay = _hit_flash_material


func _play_hit_flash() -> void:
	if _hit_flash_material == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	var flash_color := HIT_FLASH_COLOR
	flash_color.a = 0.55
	_hit_flash_material.albedo_color = flash_color
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(
		_hit_flash_material, "albedo_color:a", 0.0, 0.16
	)
