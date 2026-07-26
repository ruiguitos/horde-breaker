extends NavigationRegion3D

const NAVIGATION_BLOCKER_GROUP := &"navigation_blocker"

@export_range(1.0, 100.0, 0.5) var navigation_half_extent: float = 15.5
@export_range(0.25, 4.0, 0.25) var navigation_cell_size: float = 1.0
@export_range(0.0, 2.0, 0.05) var obstacle_clearance: float = 0.65


func _ready() -> void:
	# A pre-baked mesh (built on the generator's worker thread) is used as is;
	# rebuilding here would cost ~300 ms on the main thread.
	if navigation_mesh == null:
		build_navigation_mesh()


func build_navigation_mesh() -> void:
	var cell_count := roundi(navigation_half_extent * 2.0 / navigation_cell_size)
	if not is_equal_approx(
		cell_count * navigation_cell_size, navigation_half_extent * 2.0
	):
		push_error("ArenaNavigation extent must be divisible by its cell size.")
		return

	var blockers: Array[StaticBody3D] = []
	for node in get_tree().get_nodes_in_group(NAVIGATION_BLOCKER_GROUP):
		var blocker := node as StaticBody3D
		if blocker != null:
			blockers.append(blocker)
	# Hand-painted map tiles never become nodes, so they have to be folded in
	# separately or enemies path straight through them.
	var painted := GridMapObstacles.collect_from_tree(
		get_tree(),
		Rect2(
			global_position.x - navigation_half_extent,
			global_position.z - navigation_half_extent,
			navigation_half_extent * 2.0,
			navigation_half_extent * 2.0
		),
		global_position
	)

	var navigation_mesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	for z_index in range(cell_count + 1):
		for x_index in range(cell_count + 1):
			vertices.append(
				Vector3(
					-navigation_half_extent + x_index * navigation_cell_size,
					0.0,
					-navigation_half_extent + z_index * navigation_cell_size
				)
			)
	navigation_mesh.vertices = vertices

	var row_size := cell_count + 1
	for z_index in range(cell_count):
		for x_index in range(cell_count):
			var cell_center := Vector3(
				-navigation_half_extent + (x_index + 0.5) * navigation_cell_size,
				0.0,
				-navigation_half_extent + (z_index + 0.5) * navigation_cell_size
			)
			if (
				_is_cell_blocked(cell_center, blockers)
				or _is_cell_blocked_by_painted(cell_center, painted)
			):
				continue
			var bottom_left := z_index * row_size + x_index
			var bottom_right := bottom_left + 1
			var top_left := (z_index + 1) * row_size + x_index
			var top_right := top_left + 1
			navigation_mesh.add_polygon(
				PackedInt32Array([bottom_left, bottom_right, top_right, top_left])
			)
	self.navigation_mesh = navigation_mesh


func _is_cell_blocked_by_painted(
	cell_center: Vector3, painted: Array[Dictionary]
) -> bool:
	var cell_half_size := navigation_cell_size * 0.5
	for obstacle in painted:
		var center: Vector3 = obstacle["center"]
		if (
			absf(cell_center.x - center.x)
			<= float(obstacle["half_x"]) + obstacle_clearance + cell_half_size
			and absf(cell_center.z - center.z)
			<= float(obstacle["half_z"]) + obstacle_clearance + cell_half_size
		):
			return true
	return false


func _is_cell_blocked(
	cell_center: Vector3, blockers: Array[StaticBody3D]
) -> bool:
	var cell_half_size := navigation_cell_size * 0.5
	for blocker in blockers:
		var collision := blocker.get_node_or_null("Collision") as CollisionShape3D
		if collision == null:
			push_error("Navigation blockers require a CollisionShape3D named Collision.")
			continue
		if collision.disabled:
			continue
		var box_shape := collision.shape as BoxShape3D
		if box_shape == null:
			push_error("Navigation blockers currently require a BoxShape3D.")
			continue
		var obstacle_center := to_local(collision.global_position)
		var collision_basis := global_basis.inverse() * collision.global_basis
		var shape_half_size := box_shape.size * 0.5
		var obstacle_half_size := Vector3(
			absf(collision_basis.x.x) * shape_half_size.x
				+ absf(collision_basis.y.x) * shape_half_size.y
				+ absf(collision_basis.z.x) * shape_half_size.z,
			absf(collision_basis.x.y) * shape_half_size.x
				+ absf(collision_basis.y.y) * shape_half_size.y
				+ absf(collision_basis.z.y) * shape_half_size.z,
			absf(collision_basis.x.z) * shape_half_size.x
				+ absf(collision_basis.y.z) * shape_half_size.y
				+ absf(collision_basis.z.z) * shape_half_size.z
		)
		if (
			absf(cell_center.x - obstacle_center.x)
			<= obstacle_half_size.x + obstacle_clearance + cell_half_size
			and absf(cell_center.z - obstacle_center.z)
			<= obstacle_half_size.z + obstacle_clearance + cell_half_size
		):
			return true
	return false
