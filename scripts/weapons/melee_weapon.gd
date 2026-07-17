extends Node3D

signal attack_performed(hit_count: int)

const REST_ROTATION_Y := -0.6
const SWING_ROTATION_Y := 0.9
const WORLD_COLLISION_MASK := 1

@export var display_name: String = "Worn Sword"
@export var weapon_id: StringName = &"worn_sword"
@export_range(0.1, 1000.0, 0.1) var damage: float = 35.0
@export_range(0.1, 5.0, 0.05) var attack_cooldown: float = 0.6
@export_range(0.05, 1.0, 0.05) var swing_duration: float = 0.2
@export_range(1.0, 20.0, 0.1) var aim_range: float = 10.0

@onready var attack_area: Area3D = %AttackArea
@onready var attack_collision: CollisionShape3D = %AttackCollision
@onready var sword_visual_pivot: Node3D = %SwordVisualPivot

var _cooldown_remaining: float = 0.0
var _swing_tween: Tween


func _ready() -> void:
	sword_visual_pivot.rotation.y = REST_ROTATION_Y


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if (
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and not Input.is_action_pressed("camera_front")
		and Input.is_action_just_pressed("attack")
	):
		try_attack()


func try_attack() -> bool:
	if _cooldown_remaining > 0.0:
		return false

	_cooldown_remaining = attack_cooldown
	_play_swing()
	var hit_count := 0
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = attack_collision.shape
	shape_query.transform = attack_collision.global_transform
	shape_query.collision_mask = attack_area.collision_mask
	shape_query.collide_with_areas = true
	shape_query.collide_with_bodies = false
	var aimed_damage := _get_aimed_damage()
	var aimed_target := aimed_damage.get("target") as Node3D
	var aimed_multiplier := float(aimed_damage.get("multiplier", 1.0))
	var damaged_targets: Dictionary[int, bool] = {}
	for result in get_world_3d().direct_space_state.intersect_shape(shape_query):
		var collider: Object = result.get("collider")
		var target := _get_damage_target(collider)
		if target == null:
			continue
		var instance_id := target.get_instance_id()
		if damaged_targets.has(instance_id):
			continue
		damaged_targets[instance_id] = true
		if _has_clear_path_to(target):
			var damage_multiplier := (
				aimed_multiplier if target == aimed_target else 1.0
			)
			target.call(&"take_damage", damage * damage_multiplier)
			hit_count += 1
	attack_performed.emit(hit_count)
	return true


func _get_aimed_damage() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var ray_origin := camera.global_position
	var ray_end := ray_origin - camera.global_basis.z * aim_range
	var ray_query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		WORLD_COLLISION_MASK | attack_area.collision_mask
	)
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = true
	var result := get_world_3d().direct_space_state.intersect_ray(ray_query)
	if result.is_empty():
		return {}
	var collider: Object = result.get("collider")
	var target := _get_damage_target(collider)
	if target == null:
		return {}
	var damage_multiplier := 1.0
	if collider.has_method(&"get_damage_multiplier"):
		damage_multiplier = float(collider.call(&"get_damage_multiplier"))
	return {
		"target": target,
		"multiplier": damage_multiplier,
	}


func _get_damage_target(collider: Object) -> Node3D:
	if collider == null:
		return null
	if collider.has_method(&"get_damage_target"):
		return collider.call(&"get_damage_target") as Node3D
	if collider is Node3D and collider.has_method(&"take_damage"):
		return collider as Node3D
	return null


func _has_clear_path_to(target: Node3D) -> bool:
	if target == null:
		return false
	var ray_query := PhysicsRayQueryParameters3D.create(
		global_position,
		target.global_position + Vector3.UP * 0.4,
		WORLD_COLLISION_MASK
	)
	return get_world_3d().direct_space_state.intersect_ray(ray_query).is_empty()


func _play_swing() -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	sword_visual_pivot.rotation.y = REST_ROTATION_Y
	_swing_tween = create_tween()
	_swing_tween.tween_property(
		sword_visual_pivot, "rotation:y", SWING_ROTATION_Y, swing_duration * 0.45
	)
	_swing_tween.tween_property(
		sword_visual_pivot, "rotation:y", REST_ROTATION_Y, swing_duration * 0.55
	)
