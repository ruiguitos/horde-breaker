extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal attacked(target: Node, damage: float)
signal died(enemy: Node)

const ALIVE_TARGET_GROUP := &"enemy_target"
const WORLD_COLLISION_LAYER := 1
const TERRAIN_WORLD_GROUP := &"terrain3d_world"
const TERRAIN_FEET_OFFSET := 1.0
const FOOT_BONE_TOKEN := "foot"
const FOOT_CONTACT_DEPTH := 0.02
const TARGET_REPATH_DISTANCE := 0.25
const TARGET_SCAN_INTERVAL := 0.75
const ENEMY_SCRAP_DROP_GROUP := &"enemy_scrap_drop"
const SCRAP_PICKUP_SCENE := preload("res://scenes/pickups/scrap_pickup.tscn")
const XP_ORB_SCENE := preload("res://scenes/pickups/xp_orb.tscn")
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
# Simulation LOD so hundreds of enemies stay affordable:
#   near  — full navmesh pathing (obstacles matter when they are on top of you)
#   mid   — direct steering, zero NavigationServer queries
#   far   — direct steering and the whole physics step runs 1 frame in 3
const SIM_NAVMESH_DISTANCE := 28.0
const SIM_FAR_DISTANCE := 60.0
const FAR_PHYSICS_FRAME_SKIP := 2
const SCRAP_DROP_LIFETIME_SECONDS := 25.0
const MAX_ACTIVE_SCRAP_DROPS := 40
const SCRAP_DROP_HEIGHT := 0.25
const SCRAP_DROP_MIN_OFFSET := 0.15
const SCRAP_DROP_MAX_OFFSET := 0.65
const SCRAP_DROP_CREATED_META := &"enemy_drop_created_usec"
# Hordes of 100+ burn through magazines, so enemies also drop ammunition. The
# pickup itself scales its value with the threat level.
const ENEMY_AMMO_DROP_GROUP := &"enemy_ammo_drop"
const AMMO_PICKUP_SCENE := preload("res://scenes/pickups/ammo_pickup.tscn")
const MAX_ACTIVE_AMMO_DROPS := 30
const AMMO_DROP_LIFETIME_SECONDS := 25.0

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
@export_range(0.0, 1.0, 0.01) var ammo_drop_chance: float = 0.14
@export_range(1, 100, 1) var ammo_drop_amount: int = 8
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
var _target_scan_time: float = 0.0
var _repath_time: float = 0.0
var _steer_time: float = 0.0
var _skipped_physics_frames: int = 0
var _cached_direction := Vector3.ZERO
var _hit_flash_material: StandardMaterial3D
var _hit_flash_tween: Tween
var _flash_meshes: Array[MeshInstance3D] = []
var _hit_flash_active := false
var _scrap_drop_attempted := false
var _ammo_drop_attempted := false
var _uses_terrain_height_query := false
var _terrain_world: Node3D
var _foot_bones: Array[Dictionary] = []
var _visual_animation_players: Array[AnimationPlayer] = []
var _visual_grounding_initialized := false


func _ready() -> void:
	current_health = maximum_health
	# ImportedModelAnimation chooses clips during the regular process pass and its
	# AnimationPlayer advances in physics. Keep the enemy after both components
	# so the current physics pose is the one corrected against the terrain.
	process_priority = 100
	process_physics_priority = 100
	# Terrain3D physics is reserved for the player. A large horde colliding its
	# capsules with the terrain facets is substantially more expensive than one
	# deterministic height lookup per simulated zombie.
	_terrain_world = get_tree().get_first_node_in_group(TERRAIN_WORLD_GROUP) as Node3D
	_uses_terrain_height_query = _terrain_world != null
	if _uses_terrain_height_query:
		collision_mask &= ~WORLD_COLLISION_LAYER
	_configure_animation_grounding_order()
	_cache_visual_foot_bones()
	_setup_hit_flash()
	_repath_time = randf() * REPATH_INTERVAL
	_target_scan_time = randf() * TARGET_SCAN_INTERVAL

	var attack_shape := attack_collision.shape.duplicate() as SphereShape3D
	if attack_shape == null:
		push_error("NormalZombie AttackCollision requires a SphereShape3D.")
	else:
		attack_shape.radius = attack_range
		attack_collision.shape = attack_shape
	navigation_agent.target_desired_distance = (
		preferred_distance if is_ranged else attack_range * 0.8
	)


func _process(_delta: float) -> void:
	# Corpses stop their own physics process while their death clip continues.
	# Living enemies are corrected once in the physics pass, where their imported
	# AnimationPlayer also advances; avoid doing the same bone work twice.
	if not is_physics_processing():
		_align_visual_feet()


func _physics_process(delta: float) -> void:
	_target_scan_time -= delta
	_target = _acquire_target()
	if not is_instance_valid(_target):
		_apply_gravity(delta)
		_stop_horizontal_movement()
		_move_on_ground()
		return
	# Very distant enemies only simulate one frame in three, with the delta
	# scaled so they still travel the right distance.
	if _horizontal_distance_to_target() > SIM_FAR_DISTANCE:
		_skipped_physics_frames += 1
		if _skipped_physics_frames <= FAR_PHYSICS_FRAME_SKIP:
			_snap_to_terrain()
			_align_visual_feet()
			return
		delta *= float(_skipped_physics_frames)
		_skipped_physics_frames = 0
	else:
		_skipped_physics_frames = 0
	_apply_gravity(delta)
	_repath_time -= delta

	if is_ranged:
		_process_ranged(delta)
	elif _is_target_in_attack_range():
		_stop_horizontal_movement()
		_try_attack()
	else:
		_pursue_target(delta)

	_move_on_ground()


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
	# The player and active defense towers share one target group. Rescanning on
	# a staggered interval lets a nearby tower draw pressure without making every
	# zombie iterate the group on every physics frame.
	if (
		is_instance_valid(_cached_target)
		and _cached_target.is_in_group(ALIVE_TARGET_GROUP)
		and _target_scan_time > 0.0
	):
		return _cached_target
	_target_scan_time = TARGET_SCAN_INTERVAL
	_cached_target = _find_closest_target()
	return _cached_target


func _find_closest_target() -> PhysicsBody3D:
	var closest_target: PhysicsBody3D
	var closest_distance_squared := INF
	for node in get_tree().get_nodes_in_group(ALIVE_TARGET_GROUP):
		var candidate := node as PhysicsBody3D
		if candidate == null:
			continue
		if not candidate.has_method(&"take_damage"):
			continue
		var distance_squared := global_position.distance_squared_to(
			candidate.global_position
		)
		if distance_squared < closest_distance_squared:
			closest_target = candidate
			closest_distance_squared = distance_squared
	return closest_target


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
	_try_drop_ammo()
	_drop_xp_orb()
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


func _drop_xp_orb() -> void:
	# Every enemy feeds the survivors-like run level; tougher enemies are worth
	# more, derived from the XP reward they already carry.
	var orb := XP_ORB_SCENE.instantiate() as Node3D
	if orb == null:
		return
	orb.set(&"xp_amount", maxi(int(round(xp_reward / 5.0)), 1))
	var effect_parent: Node = get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_tree().root
	effect_parent.add_child(orb)
	orb.global_position = global_position + Vector3(
		randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4)
	)


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


func _try_drop_ammo() -> void:
	if _ammo_drop_attempted:
		return
	_ammo_drop_attempted = true
	if ammo_drop_chance <= 0.0 or randf() >= ammo_drop_chance:
		return
	var pickup := AMMO_PICKUP_SCENE.instantiate() as Area3D
	if pickup == null:
		return
	_remove_oldest_ammo_drop_if_needed()
	pickup.set(&"ammunition_amount", ammo_drop_amount)
	pickup.set_meta(SCRAP_DROP_CREATED_META, Time.get_ticks_usec())
	pickup.add_to_group(ENEMY_AMMO_DROP_GROUP)
	var spawn_parent: Node = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_tree().root
	spawn_parent.add_child(pickup)
	var angle := randf_range(0.0, TAU)
	pickup.global_position = global_position + Vector3(
		cos(angle) * SCRAP_DROP_MAX_OFFSET,
		SCRAP_DROP_HEIGHT,
		sin(angle) * SCRAP_DROP_MAX_OFFSET
	)
	get_tree().create_timer(AMMO_DROP_LIFETIME_SECONDS).timeout.connect(
		func() -> void:
			if is_instance_valid(pickup):
				pickup.queue_free()
	)


func _remove_oldest_ammo_drop_if_needed() -> void:
	var drops := get_tree().get_nodes_in_group(ENEMY_AMMO_DROP_GROUP)
	if drops.size() < MAX_ACTIVE_AMMO_DROPS:
		return
	var oldest: Node = null
	var oldest_time := 0
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		var created := int(drop.get_meta(SCRAP_DROP_CREATED_META, 0))
		if oldest == null or created < oldest_time:
			oldest = drop
			oldest_time = created
	if oldest != null:
		oldest.queue_free()


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
	if _uses_terrain_height_query:
		velocity.y = 0.0
		return
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta


func _move_on_ground() -> void:
	move_and_slide()
	_snap_to_terrain()
	_align_visual_feet()


func uses_terrain_height_grounding() -> bool:
	return _uses_terrain_height_query and is_instance_valid(_terrain_world)


func _snap_to_terrain() -> void:
	if not _uses_terrain_height_query or not is_instance_valid(_terrain_world):
		return
	var terrain_height := float(
		_terrain_world.call(&"get_terrain_height", global_position)
	)
	global_position.y = terrain_height + TERRAIN_FEET_OFFSET
	velocity.y = 0.0


func _cache_visual_foot_bones() -> void:
	_foot_bones.clear()
	for value in visual_root.find_children("*", "Skeleton3D", true, false):
		var skeleton := value as Skeleton3D
		if skeleton == null or not skeleton.is_visible_in_tree():
			continue
		var indices := PackedInt32Array()
		for bone_index in skeleton.get_bone_count():
			var bone_name := String(skeleton.get_bone_name(bone_index)).to_lower()
			if FOOT_BONE_TOKEN in bone_name:
				indices.append(bone_index)
		if not indices.is_empty():
			_foot_bones.append({"skeleton": skeleton, "indices": indices})


func _configure_animation_grounding_order() -> void:
	_visual_animation_players.clear()
	for value in visual_root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := value as AnimationPlayer
		_visual_animation_players.append(animation_player)
		animation_player.callback_mode_process = (
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		)
		animation_player.process_physics_priority = -100


func _align_visual_feet() -> void:
	# Animation LOD freezes every model outside the nearest animation budget.
	# Its last corrected pose remains valid while the CharacterBody moves over
	# Terrain3D, so reading skeleton bones again would only waste horde CPU time.
	if _visual_grounding_initialized and not _has_active_visual_animation():
		return
	var lowest_foot_y := _get_lowest_visual_foot_local_y()
	if is_inf(lowest_foot_y):
		return
	var target_y := -TERRAIN_FEET_OFFSET - FOOT_CONTACT_DEPTH
	visual_root.position.y += target_y - lowest_foot_y
	_visual_grounding_initialized = true


func _has_active_visual_animation() -> bool:
	for animation_player in _visual_animation_players:
		if is_instance_valid(animation_player) and animation_player.active:
			return true
	return false


func _get_lowest_visual_foot_local_y() -> float:
	var lowest_y := INF
	for foot_set in _foot_bones:
		var skeleton: Skeleton3D = foot_set["skeleton"]
		if not is_instance_valid(skeleton) or not skeleton.is_visible_in_tree():
			continue
		var indices: PackedInt32Array = foot_set["indices"]
		for bone_index in indices:
			var bone_transform := (
				skeleton.global_transform
				* skeleton.get_bone_global_pose(bone_index)
			)
			lowest_y = minf(lowest_y, to_local(bone_transform.origin).y)
	return lowest_y


func get_lowest_visual_foot_world_y() -> float:
	var local_y := _get_lowest_visual_foot_local_y()
	if is_inf(local_y):
		return INF
	return global_position.y + local_y


func _pursue_target(delta: float) -> void:
	var distance := _horizontal_distance_to_target()
	if distance > SIM_NAVMESH_DISTANCE:
		# Beyond the navmesh band the horde just walks at its current target. No
		# NavigationServer work at all, which is what makes big counts viable.
		_steer_time -= delta
		if _steer_time <= 0.0:
			_steer_time = FAR_STEER_INTERVAL
			var to_target := _target.global_position - global_position
			to_target.y = 0.0
			_cached_direction = to_target.normalized()
	else:
		var is_far := distance > FAR_SIMULATION_DISTANCE
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
	# The overlay is attached only while the flash plays. Leaving it on renders a
	# second pass over every enemy on every frame — with a full horde that was
	# half of all the geometry drawn, for a material that is invisible almost all
	# of the time.
	_hit_flash_material = StandardMaterial3D.new()
	_hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_hit_flash_material.albedo_color = HIT_FLASH_COLOR
	for mesh_value in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_value as MeshInstance3D
		if mesh_instance.visible:
			_flash_meshes.append(mesh_instance)


func _play_hit_flash() -> void:
	if _hit_flash_material == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	if not _hit_flash_active:
		_hit_flash_active = true
		for mesh_instance in _flash_meshes:
			mesh_instance.material_overlay = _hit_flash_material
	var flash_color := HIT_FLASH_COLOR
	flash_color.a = 0.55
	_hit_flash_material.albedo_color = flash_color
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(
		_hit_flash_material, "albedo_color:a", 0.0, 0.16
	)
	_hit_flash_tween.finished.connect(_clear_hit_flash)


func _clear_hit_flash() -> void:
	_hit_flash_active = false
	for mesh_instance in _flash_meshes:
		if is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = null
