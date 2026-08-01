extends SceneTree

signal idle_completed

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const ENEMY_SCENES := [
	"res://scenes/enemies/normal_zombie.tscn",
	"res://scenes/enemies/runner_zombie.tscn",
	"res://scenes/enemies/brute_zombie.tscn",
	"res://scenes/enemies/spitter_zombie.tscn",
	"res://scenes/enemies/boss_breaker.tscn",
]

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
	var terrain_world := get_first_node_in_group(&"terrain3d_world") as Node3D
	_check("Terrain3D world is available", terrain_world != null)
	if terrain_world == null:
		_report()
		return
	if not bool(terrain_world.get(&"is_ready")):
		await Signal(terrain_world, &"world_ready")
	var wave_manager := get_first_node_in_group(&"wave_manager")
	if wave_manager != null:
		wave_manager.set_process(false)
		wave_manager.set_physics_process(false)
	for existing in get_nodes_in_group(&"enemy"):
		existing.queue_free()
	await process_frame

	for enemy_index in ENEMY_SCENES.size():
		var scene_path: String = ENEMY_SCENES[enemy_index]
		var enemy := (load(scene_path) as PackedScene).instantiate() as CharacterBody3D
		current_scene.add_child(enemy)
		var horizontal := Vector3(-42.0 + enemy_index * 12.0, 0.0, -112.0)
		var terrain_height := float(terrain_world.call(&"get_terrain_height", horizontal))
		enemy.global_position = Vector3(horizontal.x, terrain_height + 1.0, horizontal.z)
		for _frame in 24:
			await _wait_for_idle_completion()
		var foot_y := float(enemy.call(&"get_lowest_visual_foot_world_y"))
		var current_terrain_height := float(terrain_world.call(
			&"get_terrain_height", enemy.global_position
		))
		var error := absf(foot_y - (current_terrain_height - 0.02))
		_check("%s feet touch Terrain3D (%.3f m error)" % [enemy.name, error],
			not is_inf(foot_y) and error < 0.035)
		enemy.queue_free()
		await process_frame
	_report()


func _wait_for_idle_completion() -> void:
	await process_frame
	_idle_complete.call_deferred()
	await idle_completed


func _idle_complete() -> void:
	idle_completed.emit()


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
