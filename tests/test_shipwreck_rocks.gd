extends SceneTree

const PROTOTYPE_SCENE_PATH := "res://scenes/world/shipwreck_rocks_prototype.tscn"
const DESIGN := preload("res://scripts/systems/shipwreck_rocks_design.gd")
const REGION_DIRECTORY := "res://data/shipwreck_rocks/regions"
const READY_TIMEOUT_FRAMES := 900

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load(PROTOTYPE_SCENE_PATH) as PackedScene
	_check("the Shipwreck Rocks scene loads", packed_scene != null)
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

	_check("the pilot scene finishes setup", bool(prototype.get(&"is_ready")))
	_check(
		"the pilot loads persistent Terrain3D data",
		bool(prototype.get(&"loaded_persistent_data"))
	)
	var terrain_mount := prototype.get_node_or_null("TerrainMount") as Node3D
	var terrain := (
		terrain_mount.call(&"get_terrain") as Terrain3D
		if terrain_mount != null
		else null
	)
	_check("one Terrain3D node is mounted", terrain != null)
	if terrain != null:
		_check(
			"the pilot contains exactly one persistent 256 m region",
			terrain.data.get_region_count() == 1
		)
		_check(
			"departure shore is above the sea",
			terrain.data.get_height(Vector3(DESIGN.HOME_CENTER.x, 0.0, DESIGN.HOME_CENTER.y))
			> DESIGN.WATER_HEIGHT
		)
		_check(
			"Shipwreck Rocks is above the sea",
			terrain.data.get_height(Vector3(DESIGN.ISLAND_CENTER.x, 0.0, DESIGN.ISLAND_CENTER.y))
			> DESIGN.WATER_HEIGHT
		)
		_check(
			"open water separates the two landforms",
			terrain.data.get_height(Vector3(126.0, 0.0, 152.0))
			< DESIGN.WATER_HEIGHT
		)
		_check(
			"runtime terrain collision is enabled",
			terrain.collision.mode == Terrain3DCollision.FULL_GAME
		)

	var water := prototype.get_node_or_null("WaterPlane") as MeshInstance3D
	var water_mesh := water.mesh as PlaneMesh if water != null else null
	_check(
		"water covers the full pilot region at the designed height",
		water != null
		and water_mesh != null
		and water_mesh.size == Vector2(256.0, 256.0)
		and water.position == Vector3(128.0, DESIGN.WATER_HEIGHT, 128.0)
	)
	_check(
		"the island uses at least sixteen lightweight reused props",
		int(prototype.get(&"prop_count")) >= 16
	)

	var player := prototype.get_node("Player") as CharacterBody3D
	var ferry := prototype.get_node("Transport/AutomaticFerry") as AutomaticFerry
	var home_terminal := prototype.get_node("Transport/HomeTerminal") as FerryTerminal
	var island_terminal := prototype.get_node("Transport/IslandTerminal") as FerryTerminal
	var salvage := prototype.get_node("ExclusiveSalvage") as ShipwreckSalvage
	_check(
		"the generated ferry has a hull, deck and cabin",
		ferry.get_node_or_null("Hull") != null
		and ferry.get_node_or_null("Deck") != null
		and ferry.get_node_or_null("Cabin") != null
	)
	_check(
		"the player starts on the departure shore",
		player.global_position.distance_to(
			DESIGN.player_position_on_land(DESIGN.HOME_PLAYER_POSITION)
		) < 0.35
	)
	var home_ground_position := DESIGN.player_position_on_land(
		DESIGN.HOME_PLAYER_POSITION
	)
	player.global_position = home_ground_position + Vector3.UP * 3.0
	for _frame in 60:
		await physics_frame
	_check(
		"the player lands on the pilot Terrain3D collision",
		player.is_on_floor()
		and player.global_position.distance_to(home_ground_position) < 0.35
	)

	player.global_position = DESIGN.player_position_on_land(
		DESIGN.HOME_TERMINAL_POSITION
	)
	for _frame in 4:
		await physics_frame
	var interaction_area := player.get_node("InteractionArea") as Area3D
	_check(
		"the player's interaction sensor reaches the home terminal",
		home_terminal in interaction_area.get_overlapping_areas()
	)
	_check(
		"the ferry prompt only appears when the player is nearby",
		(home_terminal.get_node("InfoLabel") as Label3D).visible
	)

	ferry.travel_duration = 0.2
	_check(
		"the home terminal starts an automatic outbound trip",
		home_terminal.interact(player)
	)
	await _wait_for_ferry(ferry)
	_check("the ferry reaches the island dock", ferry.current_dock_index == 1)
	_check(
		"the passenger disembarks safely on Shipwreck Rocks",
		player.global_position.distance_to(
			DESIGN.player_position_on_land(DESIGN.ISLAND_DISEMBARK_POSITION)
		) < 0.35
	)
	_check("the trip is counted by the pilot", int(prototype.get(&"trip_count")) == 1)

	_check("the exclusive salvage can be recovered once", salvage.interact(player))
	_check("the exclusive salvage cannot be duplicated", not salvage.interact(player))
	_check("the pilot records the exclusive discovery", bool(prototype.get(&"salvage_found")))

	_check(
		"the island terminal starts the automatic return trip",
		island_terminal.interact(player)
	)
	await _wait_for_ferry(ferry)
	_check("the ferry returns to the departure dock", ferry.current_dock_index == 0)
	_check(
		"the passenger disembarks safely at home",
		player.global_position.distance_to(
			DESIGN.player_position_on_land(DESIGN.HOME_DISEMBARK_POSITION)
		) < 0.35
	)
	_check("both journeys are counted", int(prototype.get(&"trip_count")) == 2)

	var region_file_count := 0
	for file_name in DirAccess.get_files_at(REGION_DIRECTORY):
		if file_name.begins_with("terrain3d") and file_name.ends_with(".res"):
			region_file_count += 1
			_check(
				"%s is a valid Terrain3D region" % file_name,
				load(REGION_DIRECTORY + "/" + file_name) is Terrain3DRegion
			)
	_check("the pilot stores one region file", region_file_count == 1)

	prototype.queue_free()
	await process_frame
	_report()


func _wait_for_ferry(ferry: AutomaticFerry) -> void:
	var waited_frames := 0
	while ferry.is_moving() and waited_frames < 180:
		await physics_frame
		waited_frames += 1
	_check("the automatic trip finishes before its timeout", not ferry.is_moving())


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
