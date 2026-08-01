extends SceneTree

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const ZOMBIE_SCENE := preload("res://scenes/enemies/normal_zombie.tscn")
const SECTOR_GENERATOR := preload("res://scripts/systems/sector_generator.gd")
const DESIGN := preload("res://scripts/systems/terrain3d_world_design.gd")
const NATURAL_SECTOR_ID := &"sector_-1_-2"

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
	var world := get_first_node_in_group(&"terrain3d_world") as Node3D
	_check("the main arena contains the full Terrain3D world", world != null)
	if world == null:
		_report()
		return
	if not bool(world.get(&"is_ready")):
		await Signal(world, &"world_ready")
	var terrain := world.call(&"get_terrain") as Terrain3D
	_check("the world exposes its Terrain3D node", terrain != null)
	if terrain == null:
		_report()
		return
	_check(
		"all nine persistent terrain regions are loaded",
		terrain.data.get_region_count() == DESIGN.EXPECTED_REGION_COUNT
	)
	_check("collision follows the active camera", terrain.collision.is_dynamic_mode())
	_check("runtime terrain uses four clipmap LODs", terrain.mesh_lods == 4)
	_check("runtime terrain uses 32-vertex patches", terrain.mesh_size == 32)
	_check("the lightweight world shader is enabled",
		terrain.material.shader_override_enabled)
	_test_world_coverage(world)
	_test_water_plane()
	_test_coastline_system()
	_test_coastal_sector_filtering()
	_test_legacy_map_removed()
	await _test_streamed_sectors()
	await _test_player_floor(world)
	await _test_enemy_height_query()
	_report()


func _test_world_coverage(world: Node3D) -> void:
	var invalid_centres := 0
	for x in range(DESIGN.GRID_MIN.x, DESIGN.GRID_MAX.x + 1):
		for z in range(DESIGN.GRID_MIN.y, DESIGN.GRID_MAX.y + 1):
			var point := Vector3(x * DESIGN.SECTOR_SIZE, 0.0, z * DESIGN.SECTOR_SIZE)
			var height := float(world.call(&"get_terrain_height", point))
			if is_nan(height):
				invalid_centres += 1
	_check("Terrain3D stores all 64 sector centres (%d invalid)" % invalid_centres,
		invalid_centres == 0)
	var camp_height := float(world.call(
		&"get_terrain_height", Vector3(-64.0, 0.0, -64.0)
	))
	var city_height := float(world.call(
		&"get_terrain_height", Vector3(128.0, 0.0, 64.0)
	))
	var lookout_height := float(world.call(
		&"get_terrain_height", Vector3(-47.0, 0.0, -142.0)
	))
	var trail_height := float(world.call(
		&"get_terrain_height",
		Vector3(DESIGN.trail_center_x(-128.0), 0.0, -128.0)
	))
	var sea_height := float(world.call(
		&"get_terrain_height", Vector3(-192.0, 0.0, -192.0)
	))
	_check("the camp platform remains level (%.2f)" % camp_height,
		absf(camp_height - DESIGN.CAMP_HEIGHT) < 0.02)
	_check("the island interior has rolling relief (%.2f)" % city_height,
		city_height > DESIGN.MINIMUM_PLAYABLE_HEIGHT)
	_check("the north-west corner is below sea level (%.2f)" % sea_height,
		sea_height < DESIGN.WATER_HEIGHT)
	_check("the natural lookout still rises above 2 m (%.2f)" % lookout_height,
		lookout_height > 2.0)
	_check("the winding trail remains gently graded (%.2f)" % trail_height,
		trail_height < 0.8)
	_check("coastal water is excluded from zombie navigation",
		DESIGN.is_navigation_blocked(Vector2(-192.0, -192.0)))
	_check("the camp remains valid navigation land",
		not DESIGN.is_navigation_blocked(Vector2(-64.0, -64.0)))


func _test_water_plane() -> void:
	var water := get_first_node_in_group(&"terrain3d_water") as MeshInstance3D
	_check("the island has a dedicated water plane", water != null)
	if water == null:
		return
	_check("the water plane matches the design height (%.2f)" % water.global_position.y,
		absf(water.global_position.y - DESIGN.WATER_HEIGHT) < 0.01)
	var plane := water.mesh as PlaneMesh
	_check("the water plane covers all persistent regions",
		plane != null
		and plane.size.x >= DESIGN.TERRAIN_SIZE
		and plane.size.y >= DESIGN.TERRAIN_SIZE)


func _test_coastline_system() -> void:
	var boundary := get_first_node_in_group(&"shoreline_boundary") as StaticBody3D
	var foam := get_first_node_in_group(&"terrain3d_coast_foam") as MeshInstance3D
	_check("the shoreline has one persistent collision body", boundary != null)
	_check("the shoreline barrier uses a continuous segmented ring",
		boundary != null and boundary.get_child_count() >= 96)
	_check("the coastline has one lightweight foam mesh",
		foam != null
		and foam.mesh != null
		and foam.mesh.get_surface_count() == 1)


func _test_coastal_sector_filtering() -> void:
	var sea_sector := SECTOR_GENERATOR.build_sector({
		"id": "test_sea_sector",
		"seed": 24680,
		"position": Vector3(-192.0, 0.0, -192.0),
		"terrain_profile": &"world",
		"collected_caches": [],
		"ammo_collected": false,
		"weapon_collected": false,
		"outer_walls": [],
		"label": "SEA",
	})
	var spawn_root := sea_sector.get_node_or_null("SpawnPoints")
	var cache_root := sea_sector.get_node_or_null("ScrapCaches")
	var navigation := sea_sector.get_node_or_null(
		"NavigationRegion3D"
	) as NavigationRegion3D
	var navigation_mesh := navigation.navigation_mesh if navigation != null else null
	_check("sea sectors do not create enemy spawn markers",
		spawn_root != null and spawn_root.get_child_count() == 0)
	_check("sea sectors do not create scrap caches",
		cache_root != null and cache_root.get_child_count() == 0)
	_check("sea sectors have no walkable navigation polygons",
		navigation_mesh != null and navigation_mesh.get_polygon_count() == 0)
	sea_sector.free()


func _test_legacy_map_removed() -> void:
	var painted_cells := 0
	for value in get_nodes_in_group(&"map_gridmap"):
		var grid := value as GridMap
		if grid != null:
			painted_cells += grid.get_used_cells().size()
	_check("all legacy city GridMaps are empty (%d cells)" % painted_cells,
		painted_cells == 0)
	_check("all authored building POIs were removed",
		get_nodes_in_group(&"point_of_interest").is_empty())


func _test_streamed_sectors() -> void:
	var streamer := get_first_node_in_group(&"world_streamer")
	_check("the world streamer is available", streamer != null)
	if streamer == null:
		return
	for _frame in 360:
		if bool(streamer.call(&"is_sector_loaded", NATURAL_SECTOR_ID)):
			break
		await process_frame
	var natural_sector := streamer.call(&"get_sector", NATURAL_SECTOR_ID) as Node3D
	_check("the natural Terrain3D sector streams in", natural_sector != null)
	if natural_sector == null:
		return
	var navigation := natural_sector.get_node_or_null(
		"NavigationRegion3D"
	) as NavigationRegion3D
	var mesh := navigation.navigation_mesh if navigation != null else null
	_check("the natural sector has a navigation mesh", mesh != null)
	if mesh != null:
		var minimum_y := INF
		var maximum_y := -INF
		for vertex in mesh.vertices:
			minimum_y = minf(minimum_y, vertex.y)
			maximum_y = maxf(maximum_y, vertex.y)
		_check("navigation follows the relief (%.2f m)" % (maximum_y - minimum_y),
			maximum_y - minimum_y > 1.5)


func _test_player_floor(world: Node3D) -> void:
	var player := get_first_node_in_group(&"player") as CharacterBody3D
	_check("the player is available for a terrain collision test", player != null)
	if player == null:
		return
	var wave_manager := get_first_node_in_group(&"wave_manager")
	if wave_manager != null:
		wave_manager.set_process(false)
		wave_manager.set_physics_process(false)
	var test_position := Vector3(-47.0, 0.0, -142.0)
	var ground_height := float(world.call(&"get_terrain_height", test_position))
	player.global_position = Vector3(test_position.x, ground_height + 3.0, test_position.z)
	for _frame in 45:
		await physics_frame
	var feet_error := absf(player.global_position.y - (ground_height + 1.0))
	_check("the player lands on the sculpted terrain (%.2f m error)" % feet_error,
		player.is_on_floor() and feet_error < 0.3)


func _test_enemy_height_query() -> void:
	var enemy := ZOMBIE_SCENE.instantiate() as CharacterBody3D
	current_scene.add_child(enemy)
	enemy.global_position = Vector3(128.0, 10.0, 64.0)
	for _frame in 6:
		await physics_frame
	var terrain_world := get_first_node_in_group(&"terrain3d_world") as Node3D
	var expected_y := float(terrain_world.call(
		&"get_terrain_height", enemy.global_position
	)) + 1.0
	_check(
		"zombies cache the active Terrain3D world",
		bool(enemy.get(&"_uses_terrain_height_query"))
		and enemy.get(&"_terrain_world") == terrain_world
	)
	_check(
		"zombies do not collide with terrain facets",
		(enemy.collision_mask & 1) == 0
	)
	_check(
		"zombie feet follow the terrain (%.2f m error)"
		% absf(enemy.global_position.y - expected_y),
		absf(enemy.global_position.y - expected_y) < 0.05
	)
	enemy.queue_free()
	await process_frame


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
