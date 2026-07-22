extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal attacked(target: Node, damage: float)
signal died(enemy: Node)

const PLAYER_GROUP := &"player"
const ALIVE_TARGET_GROUP := &"enemy_target"
const TARGET_REPATH_DISTANCE := 0.25
const ENEMY_SCRAP_DROP_GROUP := &"enemy_scrap_drop"
const SCRAP_PICKUP_SCENE := preload("res://scenes/pickups/scrap_pickup.tscn")
const HIT_FLASH_COLOR := Color(1.0, 0.82, 0.6, 0.0)
const RANGED_DISTANCE_MARGIN := 1.5
# Navigation paths are the expensive part of the chase. Recomputing every
# frame for every zombie causes frame spikes, so each one repaths on a fixed
# interval, staggered per instance so they never all repath on the same frame.
const REPATH_INTERVAL := 0.35
# How long the corpse lingers so the death clip can play before freeing.
const DEATH_LINGER_SECONDS := 2.5
# Distant enemies run on a simulation budget: paths and steering refresh far
# less often, while close-range behaviour stays untouched.
const FAR_SIMULATION_DISTANCE := 40.0
const FAR_REPATH_INTERVAL := 1.2
const FAR_STEER_INTERVAL := 0.3
const SCRAP_DROP_LIFETIME_SECONDS := 25.0
const MAX_ACTIVE_SCRAP_DROPS := 40
const SCRAP_DROP_HEIGHT := 0.25
const SCRAP_DROP_MIN_OFFSET := 0.15
const SCRAP_DROP_MAX_OFFSET := 0.65
const SCRAP_DROP_CREATED_META := &"enemy_drop_created_usec"

@export_range(1.0, 5000.0, 1.0) var maximum_health: float = 50.0
@export_range(0.1, 20.0, 0.1) var move_speed: float = 2.5
@export_range(0.1, 1000.0, 0.1) var attack_damage: float = 10.0
@export_range(0.5, 5.0, 0.1) var attack_range: float = 1.4
@export_range(0.1, 10.0, 0.1) var attack_cooldown: float = 1.0
@export_range(0.1, 30.0, 0.1) var rotation_speed: float = 8.0
@export_range(0, 1000, 1) var xp_reward: int = 5
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.15
@export_range(0, 100, 1) var drop_amount_min: int = 1
@export_range(0, 100, 1) var drop_amount_max: int = 2
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
var _cached_target: PhysicsBody3D
var _repath_time: float = 0.0
var _steer_time: float = 0.0
var _cached_direction := Vector3.ZERO
var _hit_flash_material: StandardMaterial3D
var _hit_flash_tween: Tween
var _scrap_drop_attempted := false


func _ready() -> void:
	current_health = maximum_health
	_setup_hit_flash()
	_repath_time = randf() * REPATH_INTERVAL

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
	_repath_time -= delta
	_target = _acquire_target()
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


func _acquire_target() -> PhysicsBody3D:
	# Cache the player reference and only rescan the group when it becomes
	# invalid (e.g. on death), instead of iterating a group every frame.
	if (
		is_instance_valid(_cached_target)
		and _cached_target.is_in_group(ALIVE_TARGET_GROUP)
	):
		return _cached_target
	_cached_target = _find_player_target()
	return _cached_target


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
		_begin_death()
	return applied_damage


func _begin_death() -> void:
	_try_drop_scrap()
	# Leave a short-lived corpse for the death animation: no AI, no physics
	# collision, no target group, and hitboxes off so shots pass through to
	# live enemies behind it.
	set_physics_process(false)
	if is_in_group(&"enemy"):
		remove_from_group(&"enemy")
	collision_layer = 0
	collision_mask = 0
	for area in find_children("*", "Area3D", true, false):
		var area_node := area as Area3D
		area_node.set_deferred(&"monitoring", false)
		area_node.set_deferred(&"monitorable", false)
		area_node.collision_layer = 0
	get_tree().create_timer(DEATH_LINGER_SECONDS).timeout.connect(queue_free)


func _try_drop_scrap() -> void:
	var amount := _roll_scrap_drop()
	if amount > 0:
		_spawn_scrap_drop(amount)


func _roll_scrap_drop() -> int:
	if _scrap_drop_attempted:
		return 0
	_scrap_drop_attempted = true
	if drop_chance <= 0.0 or randf() >= drop_chance:
		return 0
	var minimum := mini(drop_amount_min, drop_amount_max)
	var maximum := maxi(drop_amount_min, drop_amount_max)
	return randi_range(minimum, maximum)


func _spawn_scrap_drop(amount: int) -> void:
	if amount <= 0:
		return
	var pickup := SCRAP_PICKUP_SCENE.instantiate() as Area3D
	if pickup == null:
		push_error("NormalZombie could not instantiate the ScrapPickup scene.")
		return
	_remove_oldest_scrap_drop_if_needed()
	pickup.set(&"scrap_amount", amount)
	pickup.set(&"despawn_seconds", SCRAP_DROP_LIFETIME_SECONDS)
	pickup.set_meta(SCRAP_DROP_CREATED_META, Time.get_ticks_usec())
	pickup.add_to_group(ENEMY_SCRAP_DROP_GROUP)
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_tree().root
	spawn_parent.add_child(pickup)
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(SCRAP_DROP_MIN_OFFSET, SCRAP_DROP_MAX_OFFSET)
	pickup.global_position = global_position + Vector3(
		cos(angle) * distance,
		SCRAP_DROP_HEIGHT,
		sin(angle) * distance
	)


func _remove_oldest_scrap_drop_if_needed() -> void:
	var active_drops: Array[Node] = []
	for node in get_tree().get_nodes_in_group(ENEMY_SCRAP_DROP_GROUP):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			active_drops.append(node)
	if active_drops.size() < MAX_ACTIVE_SCRAP_DROPS:
		return
	var oldest := active_drops[0]
	var oldest_created := int(
		oldest.get_meta(SCRAP_DROP_CREATED_META, Time.get_ticks_usec())
	)
	for pickup in active_drops:
		var created := int(
			pickup.get_meta(SCRAP_DROP_CREATED_META, Time.get_ticks_usec())
		)
		if created < oldest_created:
			oldest = pickup
			oldest_created = created
	oldest.queue_free()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta


func _pursue_target(delta: float) -> void:
	var is_far := _horizontal_distance_to_target() > FAR_SIMULATION_DISTANCE
	if _repath_time <= 0.0:
		_repath_time = FAR_REPATH_INTERVAL if is_far else REPATH_INTERVAL
		if navigation_agent.target_position.distance_to(
			_target.global_position
		) >= TARGET_REPATH_DISTANCE:
			navigation_agent.target_position = _target.global_position
	# Near enemies steer every frame; far ones reuse the cached direction
	# between refreshes so the per-frame NavigationServer queries drop away.
	_steer_time -= delta
	if not is_far or _steer_time <= 0.0:
		_steer_time = FAR_STEER_INTERVAL
		if not _refresh_steering():
			return
	velocity.x = _cached_direction.x * move_speed
	velocity.z = _cached_direction.z * move_speed

	if _cached_direction != Vector3.ZERO:
		var target_rotation := atan2(-_cached_direction.x, -_cached_direction.z)
		visual_root.rotation.y = rotate_toward(
			visual_root.rotation.y, target_rotation, rotation_speed * delta
		)


func _refresh_steering() -> bool:
	var navigation_map := navigation_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		_stop_horizontal_movement()
		_cached_direction = Vector3.ZERO
		return false
	if navigation_agent.is_navigation_finished():
		_stop_horizontal_movement()
		_cached_direction = Vector3.ZERO
		return false
	var next_path_position := navigation_agent.get_next_path_position()
	next_path_position.y = global_position.y
	_cached_direction = global_position.direction_to(next_path_position)
	return true


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
	_hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
