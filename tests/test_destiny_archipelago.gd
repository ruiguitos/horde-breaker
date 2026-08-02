extends SceneTree

const SCENE_PATH := "res://scenes/world/destiny_archipelago_prototype.tscn"
const DATA_PATH := "res://data/archipelagos/destiny_archipelago.tres"
const REGION_DIRECTORY := "res://data/destiny_archipelago/regions"
const ASSET_PATH := "res://data/destiny_archipelago/assets/terrain_assets.tres"
const DESIGN := preload("res://scripts/systems/destiny_archipelago_design.gd")
const READY_TIMEOUT_FRAMES := 900

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data := load(DATA_PATH) as ArchipelagoData
	_check("archipelago data loads", data != null)
	if data == null:
		_report()
		return
	_test_graph_data(data)
	_test_height_design()
	_test_surface_design()

	var packed_scene := load(SCENE_PATH) as PackedScene
	_check("Destiny Archipelago scene loads", packed_scene != null)
	if packed_scene == null:
		_report()
		return
	var prototype := packed_scene.instantiate()
	root.add_child(prototype)
	current_scene = prototype
	var waited_frames := 0
	while not bool(prototype.get(&"is_ready")) and waited_frames < READY_TIMEOUT_FRAMES:
		await physics_frame
		waited_frames += 1
	_check("prototype finishes persistent setup", bool(prototype.get(&"is_ready")))
	_check("prototype loads persistent terrain", bool(prototype.get(&"loaded_persistent_data")))

	var terrain_mount := prototype.get_node("TerrainMount") as Terrain3DPersistentMount
	var terrain := terrain_mount.get_terrain()
	_check("one Terrain3D node is mounted", terrain != null)
	if terrain != null:
		_check("four Terrain3D regions are loaded", terrain.data.get_region_count() == 4)
		_check(
			"archipelago mounts eight biome-specific Terrain3D surfaces",
			terrain.assets.get_texture_count() == 8
		)
		for entry in [
			{
				"name": "Dawn Beach",
				"position": DESIGN.DAWN_CENTER,
				"base": DESIGN.SURFACE_SAND,
				"overlay": DESIGN.SURFACE_COASTAL_GRASS,
			},
			{
				"name": "Shadow Forest",
				"position": DESIGN.FOREST_CENTER,
				"base": DESIGN.SURFACE_SWAMP_MUD,
				"overlay": DESIGN.SURFACE_SWAMP_MOSS,
			},
			{
				"name": "High Cliffs",
				"position": DESIGN.CLIFFS_CENTER,
				"base": DESIGN.SURFACE_CLIFF_STONE,
				"overlay": DESIGN.SURFACE_CLIFF_LICHEN,
			},
			{
				"name": "Volcano Peak",
				"position": DESIGN.VOLCANO_CENTER,
				"base": DESIGN.SURFACE_VOLCANIC_ASH,
				"overlay": DESIGN.SURFACE_OBSIDIAN,
			},
		]:
			var position: Vector2 = entry["position"]
			var sample := Vector3(position.x, 0.0, position.y)
			_check(
				"%s control map is persisted in Terrain3D" % entry["name"],
				terrain.data.get_control_base_id(sample) == int(entry["base"])
				and terrain.data.get_control_overlay_id(sample) == int(entry["overlay"])
			)
		_check("full player collision is enabled", terrain.collision.mode == Terrain3DCollision.FULL_GAME)
		_check(
			"the shallow reef is physically above water",
			terrain.data.get_height(Vector3(120.0, 0.0, 265.0)) > DESIGN.WATER_HEIGHT
		)

	_check("all four route implementations are built", int(prototype.get(&"route_count")) == 4)
	var prop_count := int(prototype.get(&"prop_count"))
	_check(
		"island dressing stays within a measured pilot budget (%d props)" % prop_count,
		prop_count >= 150 and prop_count <= 180
	)
	for landmark_name in [
		"DawnSignalBeacon",
		"ForestSunkenCrypt",
		"CliffWatchtower",
		"VolcanoRitualGate",
		"VolcanoLavaCracks",
		"VolcanoSmoke",
	]:
		_check(
			"%s gives its biome a unique landmark" % landmark_name,
			prototype.get_node_or_null("Landmarks/" + landmark_name) != null
		)
	var boundary := prototype.get_node("ArchipelagoSafetyBoundary") as StaticBody3D
	_check("four offshore safety walls protect the data edge", boundary.get_child_count() == 4)

	var graph_map := prototype.get_node("PrototypeUI/ArchipelagoMap") as ArchipelagoGraphMap
	_check("graph map draws four island nodes", graph_map.get_node_count() == 4)
	_check("graph map draws four directed routes", graph_map.get_route_count() == 4)
	var player := prototype.get_node("Player") as CharacterBody3D
	var start_position := DESIGN.player_position_on_land(DESIGN.PLAYER_START)
	_check("player starts at Dawn Beach", player.global_position.distance_to(start_position) < 0.35)
	player.global_position = start_position + Vector3.UP * 3.0
	for _frame in 100:
		await physics_frame
	_check(
		"player lands on the starting island Terrain3D collision",
		player.is_on_floor() and player.global_position.distance_to(start_position) < 0.4
	)
	player.global_position = Vector3(120.0, 5.0, 265.0)
	for _frame in 100:
		await physics_frame
	_check(
		"player lands on the Route A terrain causeway (position %s, floor %s)"
		% [player.global_position, player.is_on_floor()],
		player.is_on_floor()
		and absf(player.global_position.x - 120.0) < 0.2
		and absf(player.global_position.z - 265.0) < 0.2
	)

	var cave_gate := prototype.get_node("Routes/RouteB_SeaCaveGate") as ArchipelagoRouteGate
	player.global_position = DESIGN.player_position_on_land(DESIGN.CAVE_ENTRY)
	for _frame in 4:
		await physics_frame
	var interaction_area := player.get_node("InteractionArea") as Area3D
	_check("player interaction reaches the flooded cave", cave_gate in interaction_area.get_overlapping_areas())
	_check("sea cave prompt appears by proximity", (cave_gate.get_node("InfoLabel") as Label3D).visible)
	_check("Route B accepts a tunnel traversal", cave_gate.interact(player))
	await physics_frame
	_check("Route B arrives safely at High Cliffs", player.global_position.distance_to(DESIGN.get_safe_position(&"high_cliffs")) < 0.4)
	_check("Route B is counted once", int(prototype.get(&"route_traversal_count")) == 1)
	_check("High Cliffs becomes the current island", prototype.get(&"current_island_id") == &"high_cliffs")

	player.global_position = DESIGN.get_safe_position(&"shadow_forest")
	for _frame in 4:
		await physics_frame
	_check("Route A destination can be discovered on foot", prototype.get(&"current_island_id") == &"shadow_forest")

	var bridge := prototype.get_node("Routes/RouteC_RopeBridge") as DestructibleRouteBridge
	_check("Route C starts with 400 HP", is_equal_approx(bridge.current_health, 400.0))
	player.global_position = Vector3(250.0, 5.0, 135.0)
	for _frame in 100:
		await physics_frame
	_check(
		"player lands on the physical Route C bridge (position %s, floor %s)"
		% [player.global_position, player.is_on_floor()],
		player.is_on_floor()
		and absf(player.global_position.x - 250.0) < 0.2
		and absf(player.global_position.z - 135.0) < 0.2
	)
	_check("Route C accepts weapon-style damage", is_equal_approx(bridge.take_damage(100.0), 100.0))
	_check("Route C keeps its remaining health", is_equal_approx(bridge.current_health, 300.0))
	bridge.take_damage(500.0)
	await physics_frame
	_check("Route C can be destroyed", bridge.is_destroyed)
	_check("destroyed rope bridge disables its collision", (bridge.get_node("BridgeCollision") as CollisionShape3D).disabled)
	bridge.reset_bridge()
	_check("rope bridge can be reset for another prototype run", not bridge.is_destroyed and is_equal_approx(bridge.current_health, 400.0))

	var ruins := prototype.get_node("Routes/RouteD_AncientRuins") as StaticBody3D
	var ruins_collision_count := 0
	for child in ruins.get_children():
		if child is CollisionShape3D:
			ruins_collision_count += 1
	_check("Route D contains thirty-two physical stone steps", ruins_collision_count == 32)
	_check("Route D uses one MultiMesh for all visible steps", ruins.get_node_or_null("StoneSteps") is MultiMeshInstance3D)
	player.global_position = Vector3(385.0, 5.0, 257.5)
	for _frame in 60:
		await physics_frame
	_check(
		"player lands on the physical Route D steps",
		player.is_on_floor()
		and absf(player.global_position.x - 385.0) < 0.2
		and absf(player.global_position.z - 257.5) < 0.2
	)

	player.global_position = DESIGN.get_safe_position(&"volcano_peak")
	for _frame in 4:
		await physics_frame
	_check("either final route can reach Volcano Peak", prototype.get(&"current_island_id") == &"volcano_peak")
	_check("boss island arrival is recorded", bool(prototype.get(&"boss_island_reached")))
	_check("all four islands can be discovered", int(prototype.call(&"get_visited_count")) == 4)
	_check("final island exposes a boss arena marker", prototype.get_node_or_null("Landmarks/BossArenaMarker") != null)

	player.global_position = Vector3(256.0, DESIGN.WATER_HEIGHT - 2.0, 256.0)
	await physics_frame
	_check("deep water returns the player to the latest island", player.global_position.distance_to(DESIGN.get_safe_position(&"volcano_peak")) < 0.4)

	var region_file_count := 0
	for file_name in DirAccess.get_files_at(REGION_DIRECTORY):
		if file_name.begins_with("terrain3d") and file_name.ends_with(".res"):
			region_file_count += 1
			_check(
				"%s is a valid Terrain3D region" % file_name,
				load(REGION_DIRECTORY + "/" + file_name) is Terrain3DRegion
			)
	_check("persistent directory stores four region files", region_file_count == 4)

	prototype.queue_free()
	await process_frame
	_report()


func _test_graph_data(data: ArchipelagoData) -> void:
	_check("map keeps the requested name", data.map_name == "Destiny Archipelago")
	_check("Dawn Beach is the starting hub", data.starting_island_id == &"dawn_beach")
	_check("graph contains four islands", data.islands.size() == 4)
	_check("graph contains four routes", data.routes.size() == 4)
	_check("graph validates without missing nodes or routes", data.validate_graph().is_empty())
	var dawn := data.get_island(&"dawn_beach")
	var forest := data.get_island(&"shadow_forest")
	var cliffs := data.get_island(&"high_cliffs")
	var volcano := data.get_island(&"volcano_peak")
	_check("hub branches to forest and cliffs", dawn.connects_to(&"shadow_forest") and dawn.connects_to(&"high_cliffs"))
	_check("forest converges on the boss island", forest.connects_to(&"volcano_peak"))
	_check("cliffs converge on the boss island", cliffs.connects_to(&"volcano_peak"))
	_check("boss island is terminal", volcano.connection_ids.is_empty())
	_check("Route A is a low-tide causeway", data.get_route(&"shallow_reef").traversal_type == "low_tide_causeway")
	_check("Route B is a flooded tunnel", data.get_route(&"sea_cave").traversal_type == "flooded_tunnel")
	_check("Route C is destructible", data.get_route(&"rope_bridge").traversal_type == "destructible_bridge")
	_check("Route D is prepared for guards", data.get_route(&"ancient_ruins").traversal_type == "guarded_stairs")


func _test_height_design() -> void:
	for entry in [
		{"name": "Dawn Beach", "center": DESIGN.DAWN_CENTER},
		{"name": "Shadow Forest", "center": DESIGN.FOREST_CENTER},
		{"name": "High Cliffs", "center": DESIGN.CLIFFS_CENTER},
		{"name": "Volcano Peak", "center": DESIGN.VOLCANO_CENTER},
	]:
		var center: Vector2 = entry["center"]
		_check(
			"%s rises above the sea" % entry["name"],
			DESIGN.height_at(center.x, center.y) > DESIGN.WATER_HEIGHT
		)
	_check("Route A raises a continuous reef", DESIGN.height_at(120.0, 265.0) > DESIGN.WATER_HEIGHT)
	var reef_is_continuous := true
	for sample_index in range(35):
		var sample_z := lerpf(198.0, 332.0, float(sample_index) / 34.0)
		if DESIGN.height_at(120.0, sample_z) <= DESIGN.WATER_HEIGHT:
			reef_is_continuous = false
	_check("Route A stays above water along its full length", reef_is_continuous)
	_check("Route B remains separated by open water", DESIGN.height_at(255.0, 390.0) < DESIGN.WATER_HEIGHT)
	_check("Route C spans open water", DESIGN.height_at(255.0, 135.0) < DESIGN.WATER_HEIGHT)
	_check("Route D spans open water", DESIGN.height_at(385.0, 258.0) < DESIGN.WATER_HEIGHT)
	_check(
		"Volcano Peak has substantially more relief than Dawn Beach",
		DESIGN.height_at(DESIGN.VOLCANO_CENTER.x, DESIGN.VOLCANO_CENTER.y)
		> DESIGN.height_at(DESIGN.DAWN_CENTER.x, DESIGN.DAWN_CENTER.y) + 7.0
	)
	_check(
		"Dawn Beach contains a water-filled crescent lagoon",
		DESIGN.height_at(88.0, 404.0) < DESIGN.WATER_HEIGHT
	)
	_check(
		"High Cliffs has a readable elevated mesa",
		DESIGN.height_at(408.0, 378.0)
		> DESIGN.height_at(DESIGN.FOREST_CENTER.x, DESIGN.FOREST_CENTER.y) + 6.0
	)


func _test_surface_design() -> void:
	var assets := load(ASSET_PATH) as Terrain3DAssets
	_check("archipelago terrain asset library loads", assets != null)
	if assets != null:
		_check("terrain asset library contains eight surfaces", assets.get_texture_count() == 8)
	var expected_surfaces := [
		{
			"name": "Dawn Beach",
			"position": DESIGN.DAWN_CENTER,
			"base": DESIGN.SURFACE_SAND,
			"overlay": DESIGN.SURFACE_COASTAL_GRASS,
		},
		{
			"name": "Shadow Forest",
			"position": DESIGN.FOREST_CENTER,
			"base": DESIGN.SURFACE_SWAMP_MUD,
			"overlay": DESIGN.SURFACE_SWAMP_MOSS,
		},
		{
			"name": "High Cliffs",
			"position": DESIGN.CLIFFS_CENTER,
			"base": DESIGN.SURFACE_CLIFF_STONE,
			"overlay": DESIGN.SURFACE_CLIFF_LICHEN,
		},
		{
			"name": "Volcano Peak",
			"position": DESIGN.VOLCANO_CENTER,
			"base": DESIGN.SURFACE_VOLCANIC_ASH,
			"overlay": DESIGN.SURFACE_OBSIDIAN,
		},
	]
	for entry in expected_surfaces:
		var position: Vector2 = entry["position"]
		var surface := DESIGN.get_surface_pair_at(position.x, position.y)
		_check(
			"%s uses its own base and overlay surfaces" % entry["name"],
			surface.x == int(entry["base"]) and surface.y == int(entry["overlay"])
		)


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
