extends SceneTree

const PROTOTYPE_SCENE_PATH := "res://scenes/world/terrain3d_prototype.tscn"
const REGION_DIRECTORY := "res://data/terrain3d_prototype/regions"
const ASSETS_PATH := "res://data/terrain3d_prototype/assets/terrain_assets.tres"
const READY_TIMEOUT_FRAMES := 900

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(PROTOTYPE_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "prototype scene loads")
	if packed_scene == null:
		_finish()
		return
	var prototype := packed_scene.instantiate()
	root.add_child(prototype)
	current_scene = prototype

	var waited_frames := 0
	while prototype.get(&"is_ready") != true and waited_frames < READY_TIMEOUT_FRAMES:
		await physics_frame
		waited_frames += 1

	_expect(prototype.get(&"is_ready") == true, "prototype finishes persistent setup")
	_expect(
		prototype.get(&"loaded_persistent_data") == true,
		"prototype loads saved terrain instead of generating heights at runtime"
	)
	for _frame in range(6):
		await physics_frame
	var terrain_mount := prototype.get_node(
		"NavigationRegion3D/TerrainMount"
	) as Node3D
	_expect(terrain_mount != null, "scene exposes its persistent terrain mount")
	if terrain_mount != null:
		_expect(
			terrain_mount.get(&"select_terrain_action") is Callable,
			"terrain mount exposes the editor selection action"
		)
		_expect(
			terrain_mount.get(&"save_terrain_action") is Callable,
			"terrain mount exposes the explicit region save action"
		)
	var terrain := prototype.get_node(
		"NavigationRegion3D/TerrainMount/Terrain3D"
	) as Terrain3D
	_expect(terrain != null, "scene contains a Terrain3D node")
	if terrain != null:
		_expect(
			terrain.data_directory == REGION_DIRECTORY,
			"scene references the persistent Terrain3D data directory"
		)
		_expect(terrain.data.get_region_count() == 4, "512 m terrain creates four 256 m regions")
		_expect(
			terrain.assets != null and terrain.assets.resource_path == ASSETS_PATH,
			"scene loads its external terrain asset list"
		)
		_expect(
			terrain.material != null and terrain.material.auto_shader,
			"mounted terrain enables its slope-based material"
		)
		_expect(
			terrain.collision.mode == Terrain3DCollision.FULL_GAME,
			"prototype enables full runtime collision"
		)
		var camp_height := terrain.data.get_height(Vector3.ZERO)
		var hill_height := terrain.data.get_height(Vector3(76.0, 0.0, -58.0))
		_expect(absf(camp_height - 2.0) < 0.2, "camp clearing is level at the designed height")
		_expect(hill_height > camp_height + 7.0, "terrain includes meaningful vertical relief")

	var player := prototype.get_node("Player") as CharacterBody3D
	if terrain != null and player != null:
		var player_floor := terrain.data.get_height(player.global_position)
		_expect(
			absf(player.global_position.y - player_floor - 1.05) < 0.25,
			"player feet align with the sampled terrain height"
		)

	var navigation_region := prototype.get_node("NavigationRegion3D") as NavigationRegion3D
	_expect(
		navigation_region != null and navigation_region.navigation_mesh != null,
		"runtime navigation mesh is assigned"
	)
	if navigation_region != null and navigation_region.navigation_mesh != null:
		_expect(
			navigation_region.navigation_mesh.get_polygon_count() > 0,
			"runtime navigation mesh contains walkable polygons"
		)
		var nav_path := NavigationServer3D.map_get_path(
			navigation_region.get_navigation_map(),
			prototype.get_node("Enemies/TerrainZombieA").global_position,
			player.global_position,
			true
		)
		_expect(nav_path.size() >= 3, "zombie path routes around the rock obstacle")

	_expect(
		int(prototype.get(&"scattered_prop_count")) >= 35,
		"existing forest assets are scattered across the prototype"
	)
	_expect(
		prototype.get_node("NavigationRegion3D/NavigationRock01") != null,
		"navigation obstacle cluster exists"
	)
	var region_file_count := 0
	for file_name in DirAccess.get_files_at(REGION_DIRECTORY):
		if file_name.begins_with("terrain3d") and file_name.ends_with(".res"):
			region_file_count += 1
			_expect(
				load(REGION_DIRECTORY + "/" + file_name) is Terrain3DRegion,
				"%s is a valid Terrain3D region" % file_name
			)
	_expect(region_file_count == 4, "persistent data directory contains four region files")

	prototype.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Terrain3D prototype loaded persistent terrain, collision, props and navigation.")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
