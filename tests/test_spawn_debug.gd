extends SceneTree

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if change_scene_to_file(ARENA_SCENE) != OK:
		_check("arena scene loads", false)
		_report()
		return
	await scene_changed
	for _frame in 60:
		await process_frame

	var director := current_scene.get_node_or_null("Gameplay/WaveManager")
	_check("horde director exists", director != null)
	if director == null:
		_report()
		return
	_check("spawn diagnostics are disabled by default", not bool(director.get(&"debug_spawn_points")))
	_check("disabled diagnostics create no scene nodes", director.get_node_or_null("SpawnDebug") == null)
	var baseline_selection: Array = director.call(&"_gather_active_spawn_points")

	director.set(&"debug_spawn_points", true)
	var selected: Array = director.call(&"_gather_active_spawn_points")
	_check(
		"diagnostics do not change spawn selection",
		_same_instances(baseline_selection, selected)
	)
	var debug_root := director.get_node_or_null("SpawnDebug")
	_check("enabling diagnostics creates the overlay", debug_root != null)
	if debug_root != null:
		var active_count := 0
		var labelled_count := 0
		for point in debug_root.get_children():
			var reason := point.get_node_or_null("Reason") as Label3D
			if reason == null:
				continue
			labelled_count += 1
			if reason.text.begins_with("ACTIVE"):
				active_count += 1
		_check("every debug point explains its state", labelled_count == debug_root.get_child_count())
		_check("active labels match selected spawn points", active_count == selected.size())

	director.set(&"debug_spawn_points", false)
	director.call(&"_gather_active_spawn_points")
	await process_frame
	_check("disabling diagnostics removes the overlay", director.get_node_or_null("SpawnDebug") == null)
	_report()


func _same_instances(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for instance in first:
		if instance not in second:
			return false
	return true


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
