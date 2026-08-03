extends SceneTree

const SCENE_PATH := "res://scenes/world/destiny_archipelago_prototype.tscn"
const DATA_PATH := "res://data/archipelagos/destiny_archipelago.tres"
const REGION_DIRECTORY := "res://data/destiny_archipelago/regions"
const ASSET_PATH := "res://data/destiny_archipelago/assets/terrain_assets.tres"
const DESIGN := preload("res://scripts/systems/destiny_archipelago_design.gd")
const ZOMBIE_SCRIPT := preload("res://scripts/enemies/normal_zombie.gd")
const READY_TIMEOUT_FRAMES := 900
# Far enough that the zombie is pursuing rather than attacking, close enough to
# be inside the band where it asks its NavigationAgent3D for a direction.
const NAVMESH_BAND_TEST_DISTANCE := 18.0
# Two seconds of walking at the slowest zombie speed covers well over this.
const NAVMESH_BAND_MINIMUM_APPROACH := 2.0

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
	_test_horde_director(prototype)
	await _test_horde_walks_without_a_navmesh(prototype, player)
	_test_world_label_legibility(prototype)
	_test_playable_run(prototype)
	_test_prototype_overlays(prototype)
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


## The horde director, and the budget the plan fixes for it.
##
## The islands had objectives with nothing pushing back before this: a relay
## could charge undisturbed and Volcano Peak would have had no zombies to clear.
## The numbers are checked rather than trusted because they are the one part of
## the plan stated as hard limits rather than playtest targets.
func _test_horde_director(prototype: Node) -> void:
	var director := prototype.get_node_or_null("HordeDirector")
	_check("the archipelago has a horde director", director != null)
	if director == null:
		return
	_check(
		"the director is findable by the group the rest of the game uses",
		director.is_in_group(&"wave_manager")
	)
	_check(
		"the director has its enemy scenes",
		director.get(&"normal_zombie_scene") != null
			and director.get(&"runner_zombie_scene") != null
			and director.get(&"boss_scene") != null
	)

	# The plan: 90 active, an absolute guard of 120, a queue of 12 and two
	# instantiations per physics frame.
	_check(
		"the active budget is 90 (%d)" % int(director.get(&"max_simultaneous_enemies")),
		int(director.get(&"max_simultaneous_enemies")) == 90
	)
	var script: GDScript = director.get_script()
	_check(
		"the absolute guard is 120 (%d)" % int(script.get(&"ABSOLUTE_ENEMY_CAP")),
		int(script.get(&"ABSOLUTE_ENEMY_CAP")) == 120
	)
	_check(
		"the spawn queue holds at most 12 (%d)" % int(script.get(&"MAX_QUEUED_SPAWNS")),
		int(script.get(&"MAX_QUEUED_SPAWNS")) == 12
	)
	_check(
		"at most two are instanced per physics frame (%d)"
			% int(script.get(&"SPAWNS_PER_FRAME")),
		int(script.get(&"SPAWNS_PER_FRAME")) == 2
	)

	var spawns := prototype.get_node_or_null("EnemySpawns")
	_check("the archipelago provides spawn points", spawns != null)
	if spawns == null:
		return
	var markers := spawns.get_children()
	var expected := DESIGN.ISLAND_LAYOUT.size() * int(
		prototype.get_script().get(&"SPAWN_POINTS_PER_ISLAND")
	)
	_check(
		"every island gets a ring of spawn points (%d of %d)" % [markers.size(), expected],
		markers.size() == expected
	)
	var grouped := 0
	var above_water := 0
	for marker_value in markers:
		var marker := marker_value as Marker3D
		if marker == null:
			continue
		if marker.is_in_group(&"enemy_spawn_point"):
			grouped += 1
		# A spawn under the sea drowns the horde before it reaches anyone.
		if marker.global_position.y > DESIGN.WATER_HEIGHT:
			above_water += 1
	_check("every spawn point is in the director's group (%d)" % grouped,
		grouped == markers.size())
	_check("no spawn point sits in the water (%d of %d)" % [above_water, markers.size()],
		above_water == markers.size())


## The horde has to keep walking once it enters the navmesh band.
##
## The archipelago has no NavigationRegion3D at all, and a NavigationAgent3D with
## no navmesh under it hands its own position back as the next path step. Reading
## that as a step of zero length froze every zombie the instant it crossed the
## band, which a playtest saw as a horde standing still at arm's length. The
## direct-steering fallback is not a substitute for a baked navmesh — the enemy
## walks through what it should walk around — but standing still is never right.
func _test_horde_walks_without_a_navmesh(prototype: Node, player: CharacterBody3D) -> void:
	var director := prototype.get_node("HordeDirector")
	var zombie_scene := director.get(&"normal_zombie_scene") as PackedScene
	_check("the director carries a normal zombie scene", zombie_scene != null)
	if zombie_scene == null:
		return
	player.global_position = DESIGN.player_position_on_land(DESIGN.PLAYER_START)
	await physics_frame
	var zombie := zombie_scene.instantiate() as CharacterBody3D
	prototype.get_node("Enemies").add_child(zombie)
	# From the beach side. Inland of the player is the Route A blocker, and a
	# zombie stopped by a wall would prove nothing about its steering.
	zombie.global_position = DESIGN.player_position_on_land(
		DESIGN.PLAYER_START + Vector3(0.0, 0.0, NAVMESH_BAND_TEST_DISTANCE)
	)
	await physics_frame

	var agent := zombie.get_node("%NavigationAgent3D") as NavigationAgent3D
	_check(
		"the archipelago still has no baked navmesh to path over",
		NavigationServer3D.map_get_regions(agent.get_navigation_map()).is_empty()
	)
	var start_distance := zombie.global_position.distance_to(player.global_position)
	_check(
		"the test zombie starts inside the navmesh band (%.1f m)" % start_distance,
		start_distance < ZOMBIE_SCRIPT.SIM_NAVMESH_DISTANCE
	)
	for _frame in 120:
		await physics_frame
	var end_distance := zombie.global_position.distance_to(player.global_position)
	_check(
		"a zombie inside the navmesh band closes on the player (%.1f m -> %.1f m)"
			% [start_distance, end_distance],
		end_distance < start_distance - NAVMESH_BAND_MINIMUM_APPROACH
	)
	zombie.queue_free()
	await physics_frame


## The status readout and the route graph belong to opening this scene straight
## in the editor, where that scaffolding is the point. In a run they cover a
## quarter of the screen with what the HUD already carries.
func _test_prototype_overlays(prototype: Node) -> void:
	var overlays := prototype.get_node_or_null("PrototypeUI") as CanvasLayer
	_check("the prototype scaffolding sits on its own layer", overlays != null)
	if overlays == null:
		return
	# Reached through the tree rather than by name: a --script run compiles this
	# file before the autoloads are registered, so only their constants resolve.
	var game_manager := root.get_node("/root/GameManager")
	_check(
		"opening the scene directly keeps the prototype scaffolding",
		overlays.visible and not bool(game_manager.get(&"started_from_menu"))
	)
	game_manager.set(&"started_from_menu", true)
	prototype.call(&"_configure_prototype_ui")
	_check(
		"starting a run from the menu hides the prototype scaffolding",
		not overlays.visible
	)
	game_manager.set(&"started_from_menu", false)
	prototype.call(&"_configure_prototype_ui")


## World labels have to shrink with distance and disappear beyond a range.
##
## A Label3D with fixed_size keeps the same size on screen however far away it
## is; with no_depth_test on top of that it also draws through the terrain. Every
## label on every island then renders at full size over the player, piled on each
## other. That is exactly what a playtest looked like, so the settings are pinned
## here rather than left to whoever writes the next island.
func _test_world_label_legibility(prototype: Node) -> void:
	var offenders: Array[String] = []
	var checked := 0
	for hub_name in ["DawnBeachHub", "ShadowForestHub", "HighCliffsHub"]:
		var hub := prototype.get_node_or_null(hub_name)
		if hub == null:
			continue
		for child in hub.find_children("*", "Label3D", true, false):
			var label := child as Label3D
			if label == null:
				continue
			checked += 1
			# Two mitigations are acceptable and the islands use both: scale with
			# distance and fade out beyond a range, or stay hidden until the
			# player is close enough for the prompt to be for them.
			if not label.visible:
				continue
			if label.fixed_size:
				offenders.append("%s/%s keeps its size at any distance" % [hub_name, label.name])
			elif label.visibility_range_end <= 0.0:
				offenders.append("%s/%s never fades out" % [hub_name, label.name])
	_check("island labels were found to check (%d)" % checked, checked > 0)
	_check(
		"no island label is drawn at full size from across the sea: %s" % (
			"none" if offenders.is_empty() else ", ".join(offenders)
		),
		offenders.is_empty()
	)


## The archipelago has to be a run you can play, not a scene only the test can
## reach. It was the latter for a while: terrain, islands and objectives, but no
## economy, no clock, no HUD and nothing in the menus pointing at it.
func _test_playable_run(prototype: Node) -> void:
	_check(
		"starting a game loads the archipelago",
		String(GameManager.RUN_SCENE) == SCENE_PATH
	)
	for entry in [
		{"group": &"camp_economy", "method": &"add_carried_scrap"},
		{"group": &"run_objective", "method": &"get_objective_text"},
		{"group": &"run_progression", "method": &"add_run_xp"},
		{"group": &"wave_manager", "method": &"get_living_enemy_count"},
	]:
		var node := get_first_node_in_group(entry["group"])
		_check(
			"%s is wired into the run" % entry["group"],
			node != null and node.has_method(entry["method"])
		)
	for path in [
		"HUDLayer/GameHUD", "PauseLayer/PauseMenu",
		"UpgradeLayer/UpgradeChoicePanel", "GameOverLayer/GameOverPanel",
	]:
		_check(
			"the run has its %s" % path.get_file(),
			prototype.get_node_or_null(path) != null
		)

	# The extraction zone resolves through the camp_core group. Without the Dawn
	# Beach core in it the zone silently becomes the world origin, out at sea.
	var objective := get_first_node_in_group(&"run_objective")
	if objective != null:
		var zone: Vector3 = objective.call(&"get_extraction_position")
		_check(
			"the extraction zone is the camp, not the world origin (%s)" % zone,
			zone.distance_to(Vector3.ZERO) > 1.0
				and zone.y > DESIGN.WATER_HEIGHT
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
