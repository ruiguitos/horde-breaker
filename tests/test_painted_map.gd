extends SceneTree

## The old city painter is intentionally retained as a clearing tool. Terrain3D
## is now the only world surface outside the camp, so no road, house, prop or
## authored POI may silently return when the arena is repacked.

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const GRIDMAP_GROUP := &"map_gridmap"

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
	for _frame in 30:
		await process_frame

	var grids := get_nodes_in_group(GRIDMAP_GROUP)
	_check("the three legacy map layers remain available for tooling",
		grids.size() == 3)
	var painted_cells := 0
	for value in grids:
		var grid := value as GridMap
		if grid != null:
			painted_cells += grid.get_used_cells().size()
	_check("no legacy road, house or prop cells remain (%d)" % painted_cells,
		painted_cells == 0)
	_check("no authored building POIs remain",
		get_nodes_in_group(&"point_of_interest").is_empty())
	_check("Terrain3D is the active world surface",
		get_first_node_in_group(&"terrain3d_world") != null)
	_check("the camp remains for the core loop",
		get_first_node_in_group(&"camp_core") != null)
	_report()


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
