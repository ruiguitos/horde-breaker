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
	await _test_debug_noclip(player)
	await physics_frame

	var dawn_hub := prototype.get_node("DawnBeachHub") as DawnBeachHub
	_check("Dawn Beach builds an expedition camp", dawn_hub != null)
	_check("Dawn Beach starts with three power cells", dawn_hub.get_power_cells().size() == 3)
	for cell_index in dawn_hub.get_power_cells().size():
		_check(
			"Dawn power cell %d is placed above the sea" % (cell_index + 1),
			dawn_hub.get_power_cells()[cell_index].global_position.y
			> DESIGN.WATER_HEIGHT + 0.5
		)
	_check("Dawn Beach starts without recovered power", dawn_hub.get_collected_power_cell_count() == 0)
	var cave_gate := prototype.get_node("Routes/RouteB_SeaCaveGate") as ArchipelagoRouteGate
	_check("Route B starts locked at the flooded cave", not cave_gate.is_unlocked())
	_check("Route A starts behind a visible blocker", not dawn_hub.is_route_a_open())
	var first_cell := dawn_hub.get_power_cells()[0]
	player.global_position = first_cell.global_position
	for _frame in 4:
		await physics_frame
	var interaction_area := player.get_node("InteractionArea") as Area3D
	_check("player interaction reaches a Dawn power cell", first_cell in interaction_area.get_overlapping_areas())
	_check("power cell prompt appears by proximity", (first_cell.get_node("InfoLabel") as Label3D).visible)
	_check("first Dawn power cell can be recovered", first_cell.interact(player))
	for cell_index in range(1, dawn_hub.get_power_cells().size()):
		_check(
			"Dawn power cell %d can be recovered" % (cell_index + 1),
			dawn_hub.get_power_cells()[cell_index].interact(player)
		)
	_check("three cells restore camp power", dawn_hub.get_collected_power_cell_count() == 3)
	var route_b_terminal := dawn_hub.get_node(
		"RouteTerminals/RouteBTerminal"
	) as DawnRouteTerminal
	_check("powered Route B terminal accepts the route choice", route_b_terminal.interact(player))
	_check("the Dawn hub records Route B", dawn_hub.get_selected_route_id() == &"sea_cave")
	_check("Route B unlocks after the camp choice", cave_gate.is_unlocked())
	_check("Route A stays closed when Route B is selected", not dawn_hub.is_route_a_open())
	_test_route_a_choice(prototype, player)
	_test_shadow_forest_objective(prototype, player)
	await _test_high_cliffs_objective(prototype, player)
	await physics_frame

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

	player.global_position = DESIGN.player_position_on_land(DESIGN.CAVE_ENTRY)
	for _frame in 4:
		await physics_frame
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


func _test_debug_noclip(player: CharacterBody3D) -> void:
	_check("noclip input action exists", InputMap.has_action(&"toggle_noclip"))
	var has_mouse_4 := false
	for event in InputMap.action_get_events(&"toggle_noclip"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_XBUTTON1:
			has_mouse_4 = true
	_check("Mouse 4 is the default noclip binding", has_mouse_4)
	var health_before := float(player.get(&"current_health"))
	player.call(&"set_noclip_enabled", true)
	_check("debug noclip can be enabled", bool(player.call(&"is_noclip_enabled")))
	_check("noclip disables player collision", player.collision_layer == 0 and player.collision_mask == 0)
	_check("noclip disables camera collision", (player.get_node("CameraPivot/ShoulderOffset/SpringArm3D") as SpringArm3D).collision_mask == 0)
	_check("noclip displays its debug HUD", (player.get_node("DebugToolsLayer/NoclipLabel") as Label).visible)
	var movement_start := player.global_position
	Input.action_press(&"move_forward")
	for _frame in 5:
		await physics_frame
	Input.action_release(&"move_forward")
	_check("noclip moves freely with gameplay actions", player.global_position.distance_to(movement_start) > 0.2)
	var height_before := player.global_position.y
	Input.action_press(&"jump")
	for _frame in 5:
		await physics_frame
	Input.action_release(&"jump")
	_check("noclip can rise with the jump action", player.global_position.y > height_before + 0.2)
	player.call(&"take_damage", 25.0)
	_check("noclip ignores gameplay damage", is_equal_approx(float(player.get(&"current_health")), health_before))
	player.call(&"set_noclip_enabled", false)
	_check("debug noclip can be disabled", not bool(player.call(&"is_noclip_enabled")))
	_check("noclip restores player collision", player.collision_layer == 2 and player.collision_mask == 1)
	_check("noclip restores camera collision", (player.get_node("CameraPivot/ShoulderOffset/SpringArm3D") as SpringArm3D).collision_mask == 1)


func _test_route_a_choice(prototype: Node, player: CharacterBody3D) -> void:
	var route_a_hub := DawnBeachHub.new()
	route_a_hub.name = "RouteAChoiceTestHub"
	prototype.add_child(route_a_hub)
	for cell in route_a_hub.get_power_cells():
		cell.interact(player)
	_check("an independent Dawn session can choose Route A", route_a_hub.request_route_activation(&"shallow_reef"))
	_check("Route A choice opens the shallow reef", route_a_hub.is_route_a_open())
	_check("Route A choice is recorded once", route_a_hub.get_selected_route_id() == &"shallow_reef")
	route_a_hub.queue_free()


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


## Shadow Forest: clear three nests, recover the winch parts they drop, repair
## the Rope Bridge.
##
## The plan's hard rule for the island is that a destructible route must never
## soft-lock the run, so the case that matters most here is the second break:
## a bridge that goes down again after being repaired has to be repairable again.
func _test_shadow_forest_objective(prototype: Node, player: CharacterBody3D) -> void:
	var hub := prototype.get_node_or_null("ShadowForestHub") as ShadowForestHub
	_check("Shadow Forest builds its objective", hub != null)
	if hub == null:
		return
	var bridge := prototype.get(&"rope_bridge") as DestructibleRouteBridge
	_check("the forest hub holds the Rope Bridge", hub.rope_bridge == bridge)

	var nests := hub.get_nests()
	_check("Shadow Forest has three nests (%d)" % nests.size(), nests.size() == 3)
	var on_land := 0
	for nest in nests:
		if nest.global_position.y > DESIGN.WATER_HEIGHT:
			on_land += 1
	_check("every nest sits on land (%d of %d)" % [on_land, nests.size()], on_land == nests.size())
	_check("nests start uncleared", hub.get_cleared_nest_count() == 0)
	_check("no winch parts exist before a nest falls", hub.get_available_parts().is_empty())

	# Nests are shot down, not walked up to.
	var first := nests[0]
	first.take_damage(first.maximum_health * 0.5)
	_check("a wounded nest is not cleared", not first.is_cleared)
	_check("no part drops from a wounded nest", hub.get_available_parts().size() == 0)
	first.take_damage(first.maximum_health)
	_check("a nest falls when its health runs out", first.is_cleared)
	_check("clearing a nest drops one part", hub.get_available_parts().size() == 1)
	# Overkill on an already dead nest must not mint a second part.
	first.take_damage(first.maximum_health)
	_check(
		"a cleared nest cannot drop a second part",
		hub.get_available_parts().size() == 1
	)

	for index in range(1, nests.size()):
		nests[index].take_damage(nests[index].maximum_health)
	_check("three nests give three parts", hub.get_available_parts().size() == 3)

	_check(
		"the winch refuses to run before the parts are carried",
		not hub.request_bridge_repair()
	)
	for part in hub.get_available_parts():
		part.interact(player)
	_check("all three parts are recovered", hub.get_recovered_part_count() == 3)
	_check(
		"the winch refuses to repair a bridge that is standing",
		not hub.request_bridge_repair()
	)

	bridge.take_damage(bridge.maximum_health)
	_check("the bridge can be brought down", bridge.is_destroyed)
	_check("the winch repairs it", hub.request_bridge_repair())
	_check("the bridge is standing again", not bridge.is_destroyed)

	# The soft-lock case: break it a second time and the island must still open.
	bridge.take_damage(bridge.maximum_health)
	_check("the bridge can fall a second time", bridge.is_destroyed)
	_check(
		"a second break is still repairable (no soft-lock)",
		hub.request_bridge_repair()
	)
	_check("the route out of the forest is open (%d repairs)" % hub.bridge_repairs,
		hub.is_bridge_repaired() and hub.bridge_repairs == 2)


## High Cliffs: bring three relays online and the Ancient Ruins stairway opens.
##
## The half worth guarding is the charge. A relay that finished the moment it was
## touched would make the island "walk to three places"; it only becomes "hold
## three places" because the charge takes time and can be interrupted.
func _test_high_cliffs_objective(prototype: Node, player: CharacterBody3D) -> void:
	var hub := prototype.get_node_or_null("HighCliffsHub") as HighCliffsHub
	_check("High Cliffs builds its objective", hub != null)
	if hub == null:
		return
	var relays := hub.get_relays()
	_check("High Cliffs has three relays (%d)" % relays.size(), relays.size() == 3)

	# Verticality is the island's identity, so the three must not sit on one shelf.
	var heights: Array[float] = []
	for relay in relays:
		heights.append(relay.global_position.y)
	heights.sort()
	var spread: float = heights[heights.size() - 1] - heights[0]
	_check(
		"the relays sit at different elevations (%.1f m apart)" % spread,
		spread > 1.5
	)

	_check("the ruins start sealed", not hub.is_ruins_open())
	_check("no relay starts online", hub.get_online_relay_count() == 0)

	var first := relays[0]
	_check("activating a relay starts a charge", first.interact(player))
	_check("a charging relay is not online yet", not first.is_online())
	_check("activating twice does nothing", not first.interact(player))

	# Interrupted halfway: the relay drops back and has to be started again.
	first.charge_progress = 0.5
	first.take_damage(10.0)
	_check("damage knocks a charging relay offline", not first.is_online())
	_check("an interrupted relay loses its progress", is_zero_approx(first.charge_progress))
	_check("it can be started again", first.interact(player))

	for relay in relays:
		relay.interact(player)
		# Finish the charge without waiting out the real timer.
		relay.charge_seconds = 0.01
		relay.set_process(true)
	for _frame in 12:
		await process_frame
	_check(
		"holding all three brings them online (%d of %d)" % [
			hub.get_online_relay_count(), relays.size()
		],
		hub.get_online_relay_count() == relays.size()
	)
	_check("the Ancient Ruins open", hub.is_ruins_open())
	# An online relay is paid for and cannot be lost, or a late hit would reseal
	# an island the player had already cleared.
	relays[0].take_damage(999.0)
	_check("an online relay cannot be knocked out", relays[0].is_online())
	_check("the ruins stay open", hub.is_ruins_open())


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
