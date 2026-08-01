extends SceneTree

## The edge of the world used to be a bare StaticBody3D: 65 m of collision with
## no mesh on it, built per sector by SectorGenerator._add_outer_walls. Walking
## out across open ground you stopped dead against nothing, which a playtest
## reported twice — and the first investigation blamed the wrong thing, because
## it measured the tiles instead of asking the physics engine where the player
## actually gets stopped.
##
## The island owns one persistent invisible barrier out at sea. It replaces the
## streamed square walls, leaves a real band of water after the foam and remains
## continuous from above the surface down below the seabed.
##
## Run:  <godot> --headless --path . --script res://tests/test_world_edge.gd

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const TERRAIN_DESIGN := preload("res://scripts/systems/terrain3d_world_design.gd")
const SECTOR_GENERATOR := preload("res://scripts/systems/sector_generator.gd")
const WORLD_LAYER := 1
## Roughly the player's girth, so the probe stops where the player would.
const PROBE_RADIUS := 0.45
const BARRIER_SAMPLE_COUNT := 32

var _passed := 0
var _failed := 0
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if change_scene_to_file(ARENA_SCENE) != OK:
		_check("arena loads", false)
		_report()
		return
	await scene_changed
	for _frame in 60:
		await process_frame

	var player := get_first_node_in_group(&"player") as Node3D
	_check("the player is present", player != null)
	var water := get_first_node_in_group(&"terrain3d_water") as MeshInstance3D
	_check("the world edge is represented by a visible sea",
		water != null and water.visible)
	var boundary := get_first_node_in_group(&"shoreline_boundary") as StaticBody3D
	_check("one persistent offshore boundary exists", boundary != null)
	if player == null or boundary == null:
		_report()
		return
	_check("the player collides with world boundaries",
		(player.collision_mask & WORLD_LAYER) != 0)
	var coastline_system := boundary.get_parent()
	var offshore_distance := float(
		coastline_system.get(&"barrier_offshore_distance")
	)
	_check("the safety line is 24 m offshore", is_equal_approx(offshore_distance, 24.0))
	var surface_collision_count := 0
	var seabed_collision_count := 0
	var clear_shore_count := 0
	var submerged_boundary_count := 0
	var inside_terrain_count := 0
	for sample_index in BARRIER_SAMPLE_COUNT:
		var angle := TAU * float(sample_index) / float(BARRIER_SAMPLE_COUNT)
		var shore_point := TERRAIN_DESIGN.coastline_point_at(angle)
		var point := TERRAIN_DESIGN.coastline_point_at(angle, -offshore_distance)
		if not _point_hits_boundary(
			Vector3(shore_point.x, TERRAIN_DESIGN.WATER_HEIGHT + 0.5, shore_point.y),
			boundary
		):
			clear_shore_count += 1
		if _point_hits_boundary(
			Vector3(point.x, TERRAIN_DESIGN.WATER_HEIGHT + 0.5, point.y),
			boundary
		):
			surface_collision_count += 1
		if _point_hits_boundary(
			Vector3(point.x, TERRAIN_DESIGN.SEABED_HEIGHT + 0.5, point.y),
			boundary
		):
			seabed_collision_count += 1
		if TERRAIN_DESIGN.height_at(point.x, point.y) < TERRAIN_DESIGN.WATER_HEIGHT:
			submerged_boundary_count += 1
		if _is_inside_terrain(point, 2.0):
			inside_terrain_count += 1
	_check("the shoreline itself has no invisible wall (%d/%d clear)" % [
		clear_shore_count, BARRIER_SAMPLE_COUNT
	], clear_shore_count == BARRIER_SAMPLE_COUNT)
	_check("the offshore wall is continuous at the surface (%d/%d)" % [
		surface_collision_count, BARRIER_SAMPLE_COUNT
	], surface_collision_count == BARRIER_SAMPLE_COUNT)
	_check("the offshore wall reaches below the seabed (%d/%d)" % [
		seabed_collision_count, BARRIER_SAMPLE_COUNT
	], seabed_collision_count == BARRIER_SAMPLE_COUNT)
	_check("the complete safety line is in visible water (%d/%d)" % [
		submerged_boundary_count, BARRIER_SAMPLE_COUNT
	], submerged_boundary_count == BARRIER_SAMPLE_COUNT)
	_check("the safety line remains inside Terrain3D (%d/%d)" % [
		inside_terrain_count, BARRIER_SAMPLE_COUNT
	], inside_terrain_count == BARRIER_SAMPLE_COUNT)
	_test_square_sector_walls_removed()
	_report()


func _point_hits_boundary(point: Vector3, boundary: StaticBody3D) -> bool:
	var space := root.world_3d.direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = PROBE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	query.transform = Transform3D(Basis(), point)
	for hit in space.intersect_shape(query, 16):
		if hit["collider"] == boundary:
			return true
	return false


func _is_inside_terrain(point: Vector2, margin: float) -> bool:
	var terrain_min: Vector2 = TERRAIN_DESIGN.TERRAIN_ORIGIN + Vector2.ONE * margin
	var terrain_max := (
		TERRAIN_DESIGN.TERRAIN_ORIGIN
		+ Vector2.ONE * (float(TERRAIN_DESIGN.TERRAIN_SIZE) - margin)
	)
	return (
		point.x >= terrain_min.x and point.x <= terrain_max.x
		and point.y >= terrain_min.y and point.y <= terrain_max.y
	)


func _test_square_sector_walls_removed() -> void:
	var sector := SECTOR_GENERATOR.build_sector({
		"id": "test_edge_sector",
		"seed": 1234,
		"position": Vector3(256.0, 0.0, 0.0),
		"terrain_profile": &"world",
		"outer_walls": [&"east"],
		"collected_caches": [],
		"ammo_collected": false,
		"weapon_collected": false,
	})
	_check("Terrain3D sectors no longer create square outer walls",
		sector.get_node_or_null("OuterWalls") == null)
	sector.free()


func _report() -> void:
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
