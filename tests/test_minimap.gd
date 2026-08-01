extends SceneTree

## The HUD minimap answers "what is around me", which the full-screen tactical
## map on Tab cannot while a horde is chasing you. Also guards the tactical map's
## world bounds, which were hard-coded copies of the streamer's and went stale
## the moment the world grew to 8x8 and the camp moved off the origin.

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
## Loaded at runtime: both reference the SaveManager autoload, and preloading
## them from a --script tool compiles before the autoloads exist, which leaves
## the scripts broken for whatever loads them next.
const STREAMER_PATH := "res://scripts/systems/world_streamer.gd"
const TACTICAL_MAP_PATH := "res://scripts/ui/tactical_map.gd"

var STREAMER: GDScript
var TACTICAL_MAP: GDScript

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	STREAMER = load(STREAMER_PATH)
	TACTICAL_MAP = load(TACTICAL_MAP_PATH)
	_test_tactical_map_bounds()
	await _test_minimap()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_tactical_map_bounds() -> void:
	# Read from a live instance: the bounds are resolved in _read_world_bounds,
	# which is what keeps them from drifting from the streamer.
	var map := Control.new()
	map.set_script(TACTICAL_MAP)
	root.add_child(map)
	map.call(&"_read_world_bounds")

	var grid_min: Vector2i = map.get(&"GRID_MIN")
	var grid_max: Vector2i = map.get(&"GRID_MAX")
	var sector_size := float(map.get(&"SECTOR_SIZE"))
	var world_min: Vector2 = map.get(&"WORLD_MIN")
	var world_max: Vector2 = map.get(&"WORLD_MAX")

	_check(
		"map grid matches the streamer (%s..%s)" % [grid_min, grid_max],
		grid_min == STREAMER.GRID_MIN and grid_max == STREAMER.GRID_MAX
	)
	_check(
		"map camp matches the streamer (%s)" % map.get(&"CAMP_COORDS"),
		map.get(&"CAMP_COORDS") == STREAMER.CAMP_COORDS
	)
	var expected_min := Vector2(
		float(STREAMER.GRID_MIN.x) * sector_size - sector_size * 0.5,
		float(STREAMER.GRID_MIN.y) * sector_size - sector_size * 0.5
	)
	_check(
		"map world bounds start at %s" % expected_min,
		world_min.is_equal_approx(expected_min)
	)
	var span := world_max.x - world_min.x
	var sectors := float(STREAMER.GRID_MAX.x - STREAMER.GRID_MIN.x + 1)
	_check(
		"map spans the whole world (%.0f m)" % span,
		is_equal_approx(span, sectors * sector_size)
	)
	_check("tactical map has a detailed coastline",
		int(map.call(&"get_coastline_point_count")) >= 128)
	_check("tactical map includes both loops and their connectors",
		int(map.call(&"get_route_count")) >= 5)
	_check("tactical map includes terrain landmarks",
		int(map.call(&"get_terrain_landmark_count")) >= 4)
	_check("tactical map distinguishes sea from the camp",
		not bool(map.call(&"is_land_at_world_position", Vector2(-220.0, -220.0)))
		and bool(map.call(&"is_land_at_world_position", Vector2(-64.0, -64.0))))
	map.queue_free()


func _test_minimap() -> void:
	if change_scene_to_file(ARENA_SCENE) != OK:
		_check("arena loads", false)
		return
	await scene_changed
	for _frame in 60:
		await process_frame

	var hud := current_scene.find_child("GameHUD", true, false)
	_check("HUD is present", hud != null)
	if hud == null:
		return
	var minimap := hud.get_node_or_null("Minimap") as Control
	_check("minimap exists in the HUD", minimap != null)
	if minimap == null:
		return

	_check("minimap has a size", minimap.size.x > 0.0 and minimap.size.y > 0.0)
	_check(
		"minimap keeps clear of the pointer",
		minimap.mouse_filter == Control.MOUSE_FILTER_IGNORE
	)
	# Anchored right, so it stays in the corner at any resolution.
	_check("minimap is anchored right", is_equal_approx(minimap.anchor_right, 1.0))
	_check(
		"minimap runs while paused",
		minimap.process_mode == Node.PROCESS_MODE_ALWAYS
	)
	_check(
		"minimap radius is smaller than the world",
		float(minimap.get(&"view_radius")) < STREAMER.SECTOR_SIZE * 4.0
	)
	_check(
		"enemy blips are capped",
		int(minimap.get(&"MAX_ENEMY_BLIPS")) > 0
			and int(minimap.get(&"MAX_ENEMY_BLIPS")) <= 60
	)
	# It has to survive a redraw with the world running.
	minimap.queue_redraw()
	await process_frame
	await process_frame
	_check("minimap redraws without error", is_instance_valid(minimap))


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
