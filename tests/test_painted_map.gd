extends SceneTree

## Checks the hand-painted map against the two faults a playtest kept turning up
## and nobody had written down.
##
## The first is buildings driven through each other. Six of the tiles the painter
## uses are wider than the 8 m cell — the industrial blocks reach 12.6 m — so
## painting neighbouring cells made them interpenetrate and spill over the
## pavement. The painter now places against an occupancy map; this is what says
## it worked, and it reads the real arena rather than a mock, because the fault
## only exists in the painted result.
##
## The second is points of interest, which went out with the graybox. They are
## back as painted compounds with the encounter, its markers and the reward cache
## dropped into the yard. A trigger inside a wall is the failure to catch.
##
## Run:  <godot> --headless --path . --script res://tests/test_painted_map.gd

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const PAINTER_PATH := "res://tools/paint_world.gd"
const POI_GROUP := &"point_of_interest"
const GRIDMAP_GROUP := &"map_gridmap"
## Tiles that fill their cell touch their neighbours exactly. Only an overlap
## deeper than this is two buildings sharing the same ground.
const OVERLAP_TOLERANCE := 0.3
## Matches build_poi_scenes.TRIGGER_SIZE. The yard has to stay clear across it.
const TRIGGER_HALF := Vector2(6.0, 6.0)
const REWARD_SCRAP := 50

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

	var obstacles := _collect_painted_obstacles()
	_check("the world is painted (%d obstacles)" % obstacles.size(), obstacles.size() > 200)
	_test_no_overlaps(obstacles)
	_test_points_of_interest(obstacles)
	_report()


func _collect_painted_obstacles() -> Array[Dictionary]:
	# Whole world, no bounds: the seams between sectors are exactly where a wide
	# tile used to end up inside its neighbour.
	return GridMapObstacles.collect_from_tree(self, Rect2(), Vector3.ZERO)


func _to_rect(obstacle: Dictionary) -> Rect2:
	var centre: Vector3 = obstacle["center"]
	var half_x := float(obstacle["half_x"])
	var half_z := float(obstacle["half_z"])
	return Rect2(
		Vector2(centre.x - half_x, centre.z - half_z),
		Vector2(half_x * 2.0, half_z * 2.0)
	)


func _test_no_overlaps(obstacles: Array[Dictionary]) -> void:
	var rects: Array[Rect2] = []
	for obstacle in obstacles:
		rects.append(_to_rect(obstacle).grow(-OVERLAP_TOLERANCE))
	var overlaps := 0
	var worst := 0.0
	var worst_at := Vector2.ZERO
	for first in rects.size():
		for second in range(first + 1, rects.size()):
			if not rects[first].intersects(rects[second]):
				continue
			overlaps += 1
			var shared := rects[first].intersection(rects[second])
			var depth := minf(shared.size.x, shared.size.y)
			if depth > worst:
				worst = depth
				worst_at = shared.position
	# Before the occupancy map this was in the hundreds.
	_check(
		"no painted piece overlaps another (%d overlaps, worst %.1f m at %s)" % [
			overlaps, worst, worst_at
		],
		overlaps == 0
	)


func _test_points_of_interest(obstacles: Array[Dictionary]) -> void:
	var painter: GDScript = load(PAINTER_PATH)
	var expected: Array = painter.get(&"POINTS_OF_INTEREST") if painter != null else []
	var points := get_nodes_in_group(POI_GROUP)
	_check(
		"every painted compound has a POI (%d of %d)" % [points.size(), expected.size()],
		points.size() == expected.size() and not expected.is_empty()
	)

	var yard_rects: Array[Rect2] = []
	for value in points:
		var poi := value as Node3D
		if poi == null:
			_check("a POI is a Node3D", false)
			continue

		# The encounter, its markers and the reward: what the graybox POIs used to
		# provide and the sector generator lost when they went.
		var encounter: Area3D = null
		var reward: Node3D = null
		for child in poi.get_children():
			# The reward cache is an Area3D with a script too, so the encounter
			# has to be identified by what it answers, not by its type.
			var area := child as Area3D
			if area != null and area.has_method(&"is_encounter_available"):
				encounter = area
			if child.name == &"RewardCache":
				reward = child as Node3D
		_check("%s has an encounter trigger" % poi.name, encounter != null)
		if encounter != null:
			_check(
				"%s reacts to the player only (mask %d)" % [poi.name, encounter.collision_mask],
				encounter.collision_mask == 2 and encounter.collision_layer == 0
			)
			_check(
				"%s can start an encounter" % poi.name,
				encounter.has_method(&"is_encounter_available")
					and bool(encounter.call(&"is_encounter_available"))
			)
		_check(
			"%s carries the %d Scrap reward" % [poi.name, REWARD_SCRAP],
			reward != null and int(reward.get(&"scrap_amount")) == REWARD_SCRAP
		)

		var centre := Vector2(poi.global_position.x, poi.global_position.z)
		yard_rects.append(Rect2(centre - TRIGGER_HALF, TRIGGER_HALF * 2.0))

	var buried := 0
	for obstacle in obstacles:
		var rect := _to_rect(obstacle)
		for yard in yard_rects:
			if rect.intersects(yard):
				buried += 1
				break
	_check("no POI yard is painted over (%d pieces inside)" % buried, buried == 0)


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
