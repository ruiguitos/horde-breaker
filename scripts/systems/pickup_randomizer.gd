extends Node3D

## Repositions the child pickups (scrap caches and ammo boxes) to random free
## spots inside the camp sector every run, so loot locations never repeat.

const NAVIGATION_BLOCKER_GROUP := &"navigation_blocker"

@export_range(4.0, 32.0, 0.5) var placement_half_extent: float = 28.0
@export_range(0.0, 24.0, 0.5) var minimum_center_distance: float = 8.0
@export_range(2.0, 20.0, 0.5) var minimum_spacing: float = 6.0
@export_range(0.0, 6.0, 0.5) var blocker_clearance: float = 2.0


func _ready() -> void:
	# Deferred so every navigation blocker has entered the tree first.
	call_deferred(&"_randomize_positions")


func _randomize_positions() -> void:
	var blocker_rects := _collect_blocker_rects()
	var placed_positions: Array[Vector2] = []
	for child in get_children():
		var pickup := child as Node3D
		if pickup == null:
			continue
		var placement := _find_free_position(blocker_rects, placed_positions)
		if placement == Vector2.INF:
			placed_positions.append(
				Vector2(pickup.global_position.x, pickup.global_position.z)
			)
			continue
		pickup.global_position = Vector3(
			placement.x, pickup.global_position.y, placement.y
		)
		placed_positions.append(placement)


func _find_free_position(
	blocker_rects: Array[Rect2], placed_positions: Array[Vector2]
) -> Vector2:
	for attempt in 40:
		var candidate := Vector2(
			randf_range(-placement_half_extent, placement_half_extent),
			randf_range(-placement_half_extent, placement_half_extent)
		)
		if candidate.length() < minimum_center_distance:
			continue
		var too_close := false
		for placed_position in placed_positions:
			if candidate.distance_to(placed_position) < minimum_spacing:
				too_close = true
				break
		if too_close:
			continue
		var blocked := false
		for blocker_rect in blocker_rects:
			if blocker_rect.grow(blocker_clearance).has_point(candidate):
				blocked = true
				break
		if not blocked:
			return candidate
	return Vector2.INF


func _collect_blocker_rects() -> Array[Rect2]:
	var blocker_rects: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group(NAVIGATION_BLOCKER_GROUP):
		var blocker := node as StaticBody3D
		if blocker == null:
			continue
		var collision := blocker.get_node_or_null("Collision") as CollisionShape3D
		if collision == null or collision.disabled:
			continue
		var box_shape := collision.shape as BoxShape3D
		if box_shape == null:
			continue
		var collision_basis := collision.global_basis
		var half_size := box_shape.size * 0.5
		var extent := Vector2(
			absf(collision_basis.x.x) * half_size.x
				+ absf(collision_basis.y.x) * half_size.y
				+ absf(collision_basis.z.x) * half_size.z,
			absf(collision_basis.x.z) * half_size.x
				+ absf(collision_basis.y.z) * half_size.y
				+ absf(collision_basis.z.z) * half_size.z
		)
		var center := Vector2(
			collision.global_position.x, collision.global_position.z
		)
		blocker_rects.append(Rect2(center - extent, extent * 2.0))
	return blocker_rects
