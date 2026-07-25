extends Node3D

signal shot_fired(hit_position: Vector3, hit_collider: Object)
signal ammunition_changed(
	current_ammunition: int, magazine_size: int, reserve_ammunition: int
)
signal reload_started(duration: float)

const HIT_COLLISION_MASK: int = (1 << 0) | (1 << 2)
const WORLD_COLLISION_MASK := 1 << 0
const ENEMY_GROUP := &"enemy"
const PLAYER_GROUP := &"player"
const MUZZLE_FLASH_DURATION := 0.05
const TRACER_DURATION := 0.06
const TRACER_THICKNESS := 0.025
const AIM_RAY_EXTENSION := 0.1
const DAMAGE_NUMBER_SCENE := preload("res://scenes/ui/damage_number_3d.tscn")

@export_range(0.1, 1000.0, 0.1) var damage: float = 25.0
@export_range(0.1, 30.0, 0.1) var fire_rate: float = 6.0
@export_range(1.0, 500.0, 1.0) var maximum_range: float = 100.0
@export_range(1, 200, 1) var magazine_size: int = 30
@export_range(0, 1000, 1) var starting_reserve_ammunition: int = 90
@export_range(0, 2000, 1) var maximum_reserve_ammunition: int = 180
@export_range(0.1, 10.0, 0.1) var reload_duration: float = 1.5
@export_range(1, 20, 1) var pellet_count: int = 1
@export_range(0.0, 20.0, 0.5) var spread_degrees: float = 0.0
@export var automatic_fire: bool = true
@export var proximity_auto_fire_enabled: bool = true
@export_range(1.0, 12.0, 0.25) var proximity_auto_fire_range: float = 6.0
@export var weapon_id: StringName = &"assault_rifle"
@export var display_name: String = "Assault Rifle"

@onready var muzzle: Marker3D = %Muzzle
@onready var muzzle_flash: MeshInstance3D = %MuzzleFlash
@onready var muzzle_flash_timer: Timer = %MuzzleFlashTimer
@onready var reload_timer: Timer = %ReloadTimer

const PROXIMITY_SCAN_INTERVAL := 0.12

var current_ammunition: int
var reserve_ammunition: int
var _cooldown_remaining: float = 0.0
var _reload_duration_multiplier: float = 1.0
var _tracer_material: StandardMaterial3D
var _player_body: Node3D
var _proximity_scan_time: float = 0.0
var _cached_proximity_target: Node3D


func _ready() -> void:
	_player_body = _find_player_body()
	muzzle_flash_timer.timeout.connect(_hide_muzzle_flash)
	reload_timer.timeout.connect(_finish_reload)
	reload_timer.wait_time = _get_effective_reload_duration()
	current_ammunition = magazine_size
	reserve_ammunition = mini(starting_reserve_ammunition, maximum_reserve_ammunition)
	_tracer_material = StandardMaterial3D.new()
	_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_material.albedo_color = Color(1.0, 0.75, 0.15, 1.0)
	_tracer_material.emission_enabled = true
	_tracer_material.emission = Color(1.0, 0.55, 0.05, 1.0)
	_tracer_material.emission_energy_multiplier = 2.0


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_proximity_scan_time = maxf(_proximity_scan_time - delta, 0.0)
	# Auto-reload the moment the magazine runs dry, without waiting for a fire
	# input: in the survivors-like loop the player only handles positioning.
	if current_ammunition <= 0:
		_start_reload()
	if Input.is_action_pressed("reload"):
		_start_reload()
	var attack_requested := (
		Input.is_action_pressed("attack")
		if automatic_fire
		else Input.is_action_just_pressed("attack")
	)
	var manual_attack_allowed := (
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and not Input.is_action_pressed("camera_front")
		and attack_requested
	)
	var proximity_target: Node3D
	var proximity_aim_position := Vector3.ZERO
	if not manual_attack_allowed:
		proximity_target = _acquire_proximity_target()
	if proximity_target != null:
		proximity_aim_position = _get_target_aim_position(proximity_target)
		_aim_weapon_at(proximity_aim_position)
		if not _has_clear_path_to(proximity_aim_position):
			proximity_target = null
	else:
		_update_weapon_aim()
	if (
		(proximity_target != null or manual_attack_allowed)
		and _cooldown_remaining <= 0.0
		and reload_timer.is_stopped()
	):
		if current_ammunition <= 0:
			_start_reload()
			return
		if proximity_target != null:
			_fire_at(proximity_aim_position)
		else:
			_fire()
		current_ammunition -= 1
		_emit_ammunition_changed()
		_cooldown_remaining = 1.0 / fire_rate


func _start_reload() -> void:
	if (
		current_ammunition >= magazine_size
		or reserve_ammunition <= 0
		or not reload_timer.is_stopped()
	):
		return
	var effective_duration := _get_effective_reload_duration()
	reload_timer.start(effective_duration)
	reload_started.emit(effective_duration)


func _finish_reload() -> void:
	var missing_ammunition := magazine_size - current_ammunition
	var transferred_ammunition := mini(missing_ammunition, reserve_ammunition)
	current_ammunition += transferred_ammunition
	reserve_ammunition -= transferred_ammunition
	_emit_ammunition_changed()


func _fire() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("HitscanWeapon requires an active Camera3D.")
		return

	var aim_position := _get_camera_aim_position(camera)
	_aim_weapon_at(aim_position)
	_fire_at(aim_position)


func _fire_at(aim_position: Vector3) -> void:
	var ray_origin := muzzle.global_position
	var base_direction := ray_origin.direction_to(aim_position)
	if base_direction == Vector3.ZERO:
		return
	var damage_feedback: Dictionary = {}
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
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		var hit_position := pellet_end
		var hit_collider: Object = null
		if not result.is_empty():
			hit_position = result["position"]
			hit_collider = result["collider"]
			if hit_collider != null and hit_collider.has_method("take_damage"):
				var applied_result: Variant = hit_collider.call("take_damage", damage)
				var applied_damage := _get_applied_damage(
					applied_result, hit_collider
				)
				if applied_damage > 0.0:
					_record_damage_feedback(
						damage_feedback,
						hit_collider,
						hit_position,
						applied_damage
					)
		if pellet_index == 0:
			reported_hit_position = hit_position
			reported_hit_collider = hit_collider
		_show_tracer(muzzle.global_position, hit_position)
	_show_damage_feedback(damage_feedback)

	muzzle_flash.visible = true
	muzzle_flash_timer.start(MUZZLE_FLASH_DURATION)
	shot_fired.emit(reported_hit_position, reported_hit_collider)


func get_proximity_auto_fire_range() -> float:
	return proximity_auto_fire_range


func get_proximity_target() -> Node3D:
	return _get_nearest_proximity_target()


func set_reload_duration_multiplier(multiplier: float) -> void:
	_reload_duration_multiplier = maxf(multiplier, 0.1)
	reload_timer.wait_time = _get_effective_reload_duration()


func get_reload_duration_multiplier() -> float:
	return _reload_duration_multiplier


func cancel_reload() -> void:
	reload_timer.stop()


func add_ammunition(amount: int) -> int:
	if amount <= 0:
		return 0
	var previous_reserve := reserve_ammunition
	reserve_ammunition = mini(
		reserve_ammunition + amount, maximum_reserve_ammunition
	)
	var added_ammunition := reserve_ammunition - previous_reserve
	if added_ammunition > 0:
		_emit_ammunition_changed()
	return added_ammunition


func _emit_ammunition_changed() -> void:
	ammunition_changed.emit(
		current_ammunition, magazine_size, reserve_ammunition
	)


func _get_effective_reload_duration() -> float:
	return reload_duration * _reload_duration_multiplier


func _get_applied_damage(applied_result: Variant, collider: Object) -> float:
	if applied_result != null:
		return float(applied_result)
	var damage_multiplier := 1.0
	if collider.has_method(&"get_damage_multiplier"):
		damage_multiplier = float(collider.call(&"get_damage_multiplier"))
	return damage * damage_multiplier


func _record_damage_feedback(
	feedback_by_target: Dictionary,
	collider: Object,
	hit_position: Vector3,
	applied_damage: float
) -> void:
	var target: Object = collider
	if collider.has_method(&"get_damage_target"):
		var damage_target: Object = collider.call(&"get_damage_target")
		if damage_target != null:
			target = damage_target
	var target_id := target.get_instance_id()
	var is_headshot: bool = (
		collider.has_method(&"get_hit_zone")
		and collider.call(&"get_hit_zone") == &"head"
	)
	if feedback_by_target.has(target_id):
		var feedback: Dictionary = feedback_by_target[target_id]
		feedback["damage"] = float(feedback["damage"]) + applied_damage
		if is_headshot:
			feedback["position"] = hit_position
			feedback["is_headshot"] = true
		return
	feedback_by_target[target_id] = {
		"damage": applied_damage,
		"position": hit_position,
		"is_headshot": is_headshot,
	}


func _show_damage_feedback(feedback_by_target: Dictionary) -> void:
	for feedback: Dictionary in feedback_by_target.values():
		_spawn_damage_number(
			float(feedback["damage"]),
			feedback["position"] as Vector3,
			bool(feedback["is_headshot"])
		)


func _spawn_damage_number(
	damage_amount: float, hit_position: Vector3, is_headshot: bool
) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate() as Label3D
	if damage_number == null:
		push_error("HitscanWeapon could not create the damage number.")
		return
	var effect_parent: Node = get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_tree().root
	effect_parent.add_child(damage_number)
	damage_number.global_position = hit_position + Vector3.UP * 0.12
	damage_number.call(&"configure", damage_amount, is_headshot)


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


func _acquire_proximity_target() -> Node3D:
	# The full scan raycasts every candidate enemy, so it only runs a few times
	# a second; between scans the cached target is reused if still in range.
	# is_instance_valid must gate the call: a freed node cannot even be passed
	# to a Node3D-typed parameter.
	if (
		_proximity_scan_time > 0.0
		and is_instance_valid(_cached_proximity_target)
		and _is_proximity_target_valid(_cached_proximity_target)
	):
		return _cached_proximity_target
	_proximity_scan_time = PROXIMITY_SCAN_INTERVAL
	_cached_proximity_target = _get_nearest_proximity_target()
	return _cached_proximity_target


func _is_proximity_target_valid(target: Node3D) -> bool:
	if (
		target.is_queued_for_deletion()
		or not is_instance_valid(_player_body)
	):
		return false
	var distance_squared := _player_body.global_position.distance_squared_to(
		target.global_position
	)
	return distance_squared <= proximity_auto_fire_range * proximity_auto_fire_range


func _get_nearest_proximity_target() -> Node3D:
	if not proximity_auto_fire_enabled or not is_instance_valid(_player_body):
		return null
	var nearest_target: Node3D
	var nearest_distance_squared := proximity_auto_fire_range * proximity_auto_fire_range
	for enemy_value in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := enemy_value as Node3D
		if (
			enemy == null
			or not is_instance_valid(enemy)
			or enemy.is_queued_for_deletion()
			or not enemy.has_method(&"take_damage")
		):
			continue
		var distance_squared := _player_body.global_position.distance_squared_to(
			enemy.global_position
		)
		if distance_squared > nearest_distance_squared:
			continue
		var aim_position := _get_target_aim_position(enemy)
		if not _has_clear_path_to(aim_position):
			continue
		nearest_target = enemy
		nearest_distance_squared = distance_squared
	return nearest_target


func _get_target_aim_position(target: Node3D) -> Vector3:
	var body_hitbox := target.get_node_or_null("BodyHitbox") as Node3D
	if body_hitbox != null:
		return body_hitbox.global_position
	return target.global_position + Vector3.UP * 0.4


func _has_clear_path_to(target_position: Vector3) -> bool:
	var sight_origin := muzzle.global_position
	if is_instance_valid(_player_body):
		sight_origin = _player_body.global_position + Vector3.UP * 0.4
	var query := PhysicsRayQueryParameters3D.create(
		sight_origin, target_position, WORLD_COLLISION_MASK
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _find_player_body() -> Node3D:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Node3D and ancestor.is_in_group(PLAYER_GROUP):
			return ancestor as Node3D
		ancestor = ancestor.get_parent()
	return null


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
	query.collide_with_areas = true
	query.collide_with_bodies = true
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
