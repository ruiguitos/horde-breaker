extends Area3D

@export var hit_zone: StringName = &"body"
@export_range(0.1, 10.0, 0.1) var damage_multiplier: float = 1.0

var _damage_target: Node3D


func _ready() -> void:
	_damage_target = _find_damage_target()
	if _damage_target == null:
		push_error("DamageHitbox requires an ancestor with take_damage(amount).")


func take_damage(amount: float) -> float:
	if amount <= 0.0 or not is_instance_valid(_damage_target):
		return 0.0
	var final_damage := amount * damage_multiplier
	var applied_damage: Variant = _damage_target.call(&"take_damage", final_damage)
	if applied_damage == null:
		return final_damage
	return float(applied_damage)


func get_damage_target() -> Node3D:
	return _damage_target


func get_damage_multiplier() -> float:
	return damage_multiplier


func get_hit_zone() -> StringName:
	return hit_zone


func _find_damage_target() -> Node3D:
	var current_node := get_parent()
	while current_node != null:
		if current_node is Node3D and current_node.has_method(&"take_damage"):
			return current_node as Node3D
		current_node = current_node.get_parent()
	return null
