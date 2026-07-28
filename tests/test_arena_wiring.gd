extends SceneTree

## The arena is edited by tools that repack the scene, and a node can quietly
## lose its script that way — the node stays, its group stays, and nothing fails
## until something calls a method on it mid-run. That is exactly how the world
## streamer went missing: "Nonexistent function 'get_loaded_sector_count'".
##
## This checks the systems the arena is expected to provide are actually wired,
## by calling into them the way the rest of the game does.

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"

## group -> a method the rest of the game calls on that node.
const REQUIRED: Array[Dictionary] = [
	{"group": &"world_streamer", "method": &"get_loaded_sector_count"},
	{"group": &"wave_manager", "method": &"get_maximum_alive_enemies"},
	{"group": &"camp_economy", "method": &"request_feedback"},
	{"group": &"run_objective", "method": &"get_time_text"},
	{"group": &"run_progression", "method": &"add_run_xp"},
	{"group": &"player", "method": &"take_damage"},
	{"group": &"arena_navigation", "method": &"build_navigation_mesh"},
	# The camp: without these the core loop has no Scrap deposit and no upgrades.
	{"group": &"camp_core", "method": &"get_effective_resupply_radius"},
	{"group": &"fortification_site", "method": &"interact"},
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
	for _frame in 60:
		await process_frame

	for entry in REQUIRED:
		var group: StringName = entry["group"]
		var method: StringName = entry["method"]
		var node := get_first_node_in_group(group)
		if node == null:
			_check("%s: a node is in the group" % group, false)
			continue
		_check(
			"%s: %s answers %s()" % [group, node.name, method],
			node.has_method(method)
		)

	# The map layers have to reach the navigation bakers, which find them by
	# group rather than by path.
	var painted := get_nodes_in_group(&"map_gridmap")
	_check("map layers are grouped (%d)" % painted.size(), painted.size() >= 3)
	var with_library := 0
	for value in painted:
		var grid := value as GridMap
		if grid != null and grid.mesh_library != null and not grid.get_used_cells().is_empty():
			with_library += 1
	_check("map layers are painted (%d of %d)" % [with_library, painted.size()],
		with_library >= 2)
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
