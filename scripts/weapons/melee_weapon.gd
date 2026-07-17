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
	shape_query.collide_with_areas = false
	shape_query.collide_with_bodies = true
	var damaged_bodies: Dictionary[int, bool] = {}
	for result in get_world_3d().direct_space_state.intersect_shape(shape_query):
		var body: Object = result.get("collider")
		if body == null:
			continue
		var instance_id := body.get_instance_id()
		if damaged_bodies.has(instance_id):
			continue
		damaged_bodies[instance_id] = true
		if body.has_method(&"take_damage") and _has_clear_path_to(body as Node3D):
			body.call(&"take_damage", damage)
			hit_count += 1
	attack_performed.emit(hit_count)
	return true


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
