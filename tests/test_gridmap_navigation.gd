extends SceneTree

## Painted GridMap tiles emit collision straight into the physics server without
## creating nodes, so the navigation grid - which finds obstacles by looking for
## StaticBody3D nodes in a group - could not see them and enemies pathed through
## solid buildings. This checks painted cells reach the navmesh, and that the
## warehouse stays walkable inside, which is the case a naive "block the whole
## cell" fix would break.

const LIBRARY_PATH := "res://resources/map_tiles.meshlib"
const NAVIGATION_SCRIPT := "res://scripts/systems/arena_navigation.gd"
const CELL_SIZE := Vector3(8.0, 4.0, 8.0)

var _passed := 0
var _failed := 0
var _library: MeshLibrary
var _ids: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_library = load(LIBRARY_PATH)
	for id in _library.get_item_list():
		_ids[_library.get_item_name(id)] = id
	_check("library loads", _library != null and not _ids.is_empty())
	await _test_extraction()
	await _test_navmesh()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _make_grid(parent: Node3D) -> GridMap:
	var grid := GridMap.new()
	grid.mesh_library = _library
	grid.cell_size = CELL_SIZE
	grid.cell_center_x = true
	grid.cell_center_y = false
	grid.cell_center_z = true
	grid.add_to_group(GridMapObstacles.GRIDMAP_GROUP)
	parent.add_child(grid)
	return grid


func _test_extraction() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var grid := _make_grid(world)
	await process_frame

	# A road tile has no collision shapes: it must never block anything.
	grid.set_cell_item(Vector3i(0, 0, 0), _ids["road_straight"])
	await process_frame
	var road_obstacles := GridMapObstacles.collect(grid, Rect2(), Vector3.ZERO)
	_check("roads do not obstruct (%d)" % road_obstacles.size(), road_obstacles.is_empty())

	# A building does.
	grid.set_cell_item(Vector3i(3, 0, 0), _ids["building_medium"])
	await process_frame
	var all_obstacles := GridMapObstacles.collect(grid, Rect2(), Vector3.ZERO)
	_check("a painted building obstructs", all_obstacles.size() >= 1)
	var building := all_obstacles[0] if not all_obstacles.is_empty() else {}
	if not building.is_empty():
		# Cells are centred, so cell 3 sits at 3 * 8 + 4.
		var centre: Vector3 = building["center"]
		_check(
			"obstacle lands on its cell (x=%.1f, expected 28)" % centre.x,
			is_equal_approx(centre.x, 28.0)
		)
		_check(
			"obstacle is roughly tile-sized (%.1f m)" % (float(building["half_x"]) * 2.0),
			float(building["half_x"]) * 2.0 > 6.0
				and float(building["half_x"]) * 2.0 < 9.0
		)

	# The warehouse contributes its walls, not one solid block: four or more
	# separate obstacles, none of them covering the whole tile.
	grid.set_cell_item(Vector3i(6, 0, 0), _ids["warehouse"])
	await process_frame
	# Cell 6 sits at 6 * 8 + 4 = 52 on x, and cell 0 at 4 on z.
	var warehouse := GridMapObstacles.collect(
		grid, Rect2(48.0, 0.0, 8.0, 8.0), Vector3.ZERO
	)
	_check("warehouse contributes walls (%d)" % warehouse.size(), warehouse.size() >= 4)
	var solid := false
	for obstacle in warehouse:
		if float(obstacle["half_x"]) > 3.5 and float(obstacle["half_z"]) > 3.5:
			solid = true
	_check("warehouse is not one solid block", not solid)

	# Bounds must actually filter.
	var bounded := GridMapObstacles.collect(
		grid, Rect2(-4.0, -4.0, 8.0, 8.0), Vector3.ZERO
	)
	_check("bounds filter cells outside them (%d)" % bounded.size(), bounded.is_empty())
	world.queue_free()
	await process_frame


func _test_navmesh() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var grid := _make_grid(world)
	# Ring of buildings around the origin, leaving the centre open.
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1]:
			if x == 0 and z == 0:
				continue
			grid.set_cell_item(Vector3i(x, 0, z), _ids["building_small"])
	var region := NavigationRegion3D.new()
	region.set_script(load(NAVIGATION_SCRIPT))
	region.set(&"navigation_half_extent", 16.0)
	region.set(&"navigation_cell_size", 1.0)
	world.add_child(region)
	await process_frame
	region.call(&"build_navigation_mesh")
	await process_frame

	var mesh: NavigationMesh = region.navigation_mesh
	_check("navmesh was built", mesh != null)
	if mesh == null:
		world.queue_free()
		return
	var polygons := mesh.get_polygon_count()
	_check("navmesh has walkable area (%d polys)" % polygons, polygons > 0)

	# Cells are centred, so the untouched cell (0,0) is the ground at (4,4) and
	# the painted cell (-1,-1) is the building at (-4,-4).
	var open := _has_polygon_near(mesh, Vector2(4.0, 4.0), 1.5)
	var blocked := _has_polygon_near(mesh, Vector2(-4.0, -4.0), 1.0)
	_check("open ground stays walkable", open)
	_check("painted buildings are carved out", not blocked)

	# Without the fix every cell in the 32 m square would be walkable.
	var total_cells := 32 * 32
	_check(
		"a meaningful area is blocked (%d of %d cells walkable)" % [
			polygons, total_cells
		],
		polygons < total_cells * 0.85
	)
	world.queue_free()
	await process_frame


func _has_polygon_near(mesh: NavigationMesh, point: Vector2, radius: float) -> bool:
	var vertices := mesh.vertices
	for index in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(index)
		var centre := Vector2.ZERO
		for vertex_index in polygon:
			var vertex := vertices[vertex_index]
			centre += Vector2(vertex.x, vertex.z)
		centre /= float(polygon.size())
		if centre.distance_to(point) <= radius:
			return true
	return false


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
