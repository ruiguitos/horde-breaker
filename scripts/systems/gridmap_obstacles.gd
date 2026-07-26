class_name GridMapObstacles
extends RefCounted

## Turns painted GridMap cells into the flat obstacle list the navigation code
## already understands: {center, half_x, half_z}.
##
## Navigation in this project is a runtime grid built from navigation blockers,
## which it finds by looking for StaticBody3D nodes in a group. A GridMap emits
## its collision straight into the physics server without ever creating a node,
## so hand-painted buildings were solid to walk into but invisible to pathing —
## enemies routed straight through them. Rather than add a second navigation
## region and rely on region edges connecting, painted cells are folded into the
## same obstacle list, keeping one source of truth.
##
## Only the shapes authored per tile count, not the cell footprint. That is what
## keeps the warehouse walkable inside: it contributes its four walls, not a
## solid 8 m block.

const GRIDMAP_GROUP := &"map_gridmap"
## Shapes flatter than this are scenery to step over, not obstacles to route
## around (kerbs, road markings, low debris).
const MINIMUM_BLOCKING_HEIGHT := 0.5


## Collects obstacles from every painted GridMap in the tree.
## `bounds` is an XZ rectangle in world space; pass an empty rect for no limit.
## Centres come back relative to `origin`, which is what both navigation bakers
## expect.
static func collect_from_tree(
	tree: SceneTree, bounds: Rect2, origin: Vector3
) -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	for node in tree.get_nodes_in_group(GRIDMAP_GROUP):
		var grid := node as GridMap
		if grid == null or grid.mesh_library == null:
			continue
		obstacles.append_array(collect(grid, bounds, origin))
	return obstacles


static func collect(
	grid: GridMap, bounds: Rect2, origin: Vector3
) -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	var library := grid.mesh_library
	if library == null:
		return obstacles
	var has_bounds := bounds.size.x > 0.0 and bounds.size.y > 0.0
	# Cell shapes are cached per item: a sector's worth of cells reuses the same
	# handful of tiles over and over.
	var shapes_by_item: Dictionary[int, Array] = {}
	for cell in grid.get_used_cells():
		var item := grid.get_cell_item(cell)
		if item == GridMap.INVALID_CELL_ITEM:
			continue
		var cell_origin := grid.global_transform * grid.map_to_local(cell)
		if has_bounds and not bounds.has_point(
			Vector2(cell_origin.x, cell_origin.z)
		):
			continue
		if not shapes_by_item.has(item):
			shapes_by_item[item] = library.get_item_shapes(item)
		var shapes: Array = shapes_by_item[item]
		if shapes.is_empty():
			continue
		var orientation := grid.get_cell_item_orientation(cell)
		var cell_basis := grid.get_basis_with_orthogonal_index(orientation)
		var cell_transform := (
			grid.global_transform
			* Transform3D(cell_basis, grid.map_to_local(cell))
		)
		# get_item_shapes returns a flat [shape, transform, shape, transform...].
		var index := 0
		while index + 1 < shapes.size():
			var shape := shapes[index] as Shape3D
			var shape_transform := shapes[index + 1] as Transform3D
			index += 2
			var obstacle := _describe_shape(
				shape, cell_transform * shape_transform, origin
			)
			if not obstacle.is_empty():
				obstacles.append(obstacle)
	return obstacles


static func _describe_shape(
	shape: Shape3D, transform: Transform3D, origin: Vector3
) -> Dictionary:
	var half_size := _get_half_size(shape)
	if half_size == Vector3.ZERO:
		return {}
	if half_size.y * 2.0 < MINIMUM_BLOCKING_HEIGHT:
		return {}
	# Axis-aligned extents of the rotated box, same projection the other bakers
	# use so a rotated tile reserves the space it actually occupies.
	var basis_x := transform.basis.x
	var basis_y := transform.basis.y
	var basis_z := transform.basis.z
	return {
		"center": transform.origin - origin,
		"half_x": (
			absf(basis_x.x) * half_size.x + absf(basis_y.x) * half_size.y
			+ absf(basis_z.x) * half_size.z
		),
		"half_z": (
			absf(basis_x.z) * half_size.x + absf(basis_y.z) * half_size.y
			+ absf(basis_z.z) * half_size.z
		),
	}


static func _get_half_size(shape: Shape3D) -> Vector3:
	var box := shape as BoxShape3D
	if box != null:
		return box.size * 0.5
	var cylinder := shape as CylinderShape3D
	if cylinder != null:
		return Vector3(cylinder.radius, cylinder.height * 0.5, cylinder.radius)
	var sphere := shape as SphereShape3D
	if sphere != null:
		return Vector3(sphere.radius, sphere.radius, sphere.radius)
	var capsule := shape as CapsuleShape3D
	if capsule != null:
		return Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
	return Vector3.ZERO
