extends SceneTree

## The edge of the world used to be a bare StaticBody3D: 65 m of collision with
## no mesh on it, built per sector by SectorGenerator._add_outer_walls. Walking
## out across open ground you stopped dead against nothing, which a playtest
## reported twice — and the first investigation blamed the wrong thing, because
## it measured the tiles instead of asking the physics engine where the player
## actually gets stopped.
##
## The island pass replaces the old ring of visible buildings with coastline.
## This test now requires the terrain to enter the visible sea before the hidden
## backstop is reached. The backstop remains a last safety measure, not the map's
## visual explanation for why the player should turn around.
##
## Run:  <godot> --headless --path . --script res://tests/test_world_edge.gd

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const TERRAIN_DESIGN := preload("res://scripts/systems/terrain3d_world_design.gd")
const SECTOR_SIZE := 64.0
const WORLD_LAYER := 1
## Roughly the player's girth, so the probe stops where the player would.
const PROBE_RADIUS := 0.45
const PROBE_HEIGHT := 1.0
const STEP := 0.5
## How far past the last sector centre to keep probing.
const OVERSHOOT := 48.0
## Frames to let the streamer build and attach the edge sectors.
const SETTLE_FRAMES := 200

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

	var streamer := get_first_node_in_group(&"world_streamer")
	var player := get_first_node_in_group(&"player") as Node3D
	_check("the world streamer is present", streamer != null)
	_check("the player is present", player != null)
	var water := get_first_node_in_group(&"terrain3d_water") as MeshInstance3D
	_check("the world edge is represented by a visible sea",
		water != null and water.visible)
	if streamer == null or player == null:
		_report()
		return

	var grid_min: Vector2i = streamer.get(&"GRID_MIN")
	var grid_max: Vector2i = streamer.get(&"GRID_MAX")
	for edge in [
		{"name": "east", "direction": Vector3.RIGHT, "sector": Vector2i(grid_max.x, 0)},
		{"name": "west", "direction": Vector3.LEFT, "sector": Vector2i(grid_min.x, 0)},
		{"name": "south", "direction": Vector3.BACK, "sector": Vector2i(0, grid_max.y)},
		{"name": "north", "direction": Vector3.FORWARD, "sector": Vector2i(0, grid_min.y)},
	]:
		await _test_edge(player, edge)
	_report()


func _test_edge(player: Node3D, edge: Dictionary) -> void:
	var sector: Vector2i = edge["sector"]
	var direction: Vector3 = edge["direction"]
	var start := Vector3(
		float(sector.x) * SECTOR_SIZE, PROBE_HEIGHT, float(sector.y) * SECTOR_SIZE
	)
	player.global_position = start
	for _frame in SETTLE_FRAMES:
		await process_frame

	# Three lines across the edge, so a single lucky gap cannot pass for a wall.
	var across := Vector3(direction.z, 0.0, direction.x)
	var dry_backstops: Array[String] = []
	var unstopped := 0
	for offset: float in [-18.0, 0.0, 18.0]:
		var origin: Vector3 = start + across * offset
		var hit := _find_first_collision(origin, direction)
		if hit.is_empty():
			unstopped += 1
			continue
		if not _crosses_visible_water(origin, direction, float(hit["distance"])):
			dry_backstops.append("%s at %.0f m (%s)" % [
				edge["name"], hit["distance"], hit["name"]
			])
	_check(
		"the %s edge stops the player on all three lines (%d open)" % [
			edge["name"], unstopped
		],
		unstopped == 0
	)
	_check(
		"the %s edge crosses visible water before its backstop: %s" % [
			edge["name"],
			"yes" if dry_backstops.is_empty() else ", ".join(dry_backstops)
		],
		dry_backstops.is_empty()
	)


## The first solid thing along a direction, as {position, distance, name}.
func _find_first_collision(origin: Vector3, direction: Vector3) -> Dictionary:
	var space := root.world_3d.direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = PROBE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	var travelled := 0.0
	while travelled <= OVERSHOOT:
		var point := origin + direction * travelled
		query.transform = Transform3D(Basis(), point)
		var hits := space.intersect_shape(query, 1)
		if not hits.is_empty():
			var collider: Node = hits[0]["collider"]
			return {
				"position": point,
				"distance": travelled,
				"name": collider.name if collider != null else "unknown",
			}
		travelled += STEP
	return {}

func _crosses_visible_water(
	origin: Vector3, direction: Vector3, maximum_distance: float
) -> bool:
	var travelled := 0.0
	while travelled <= maximum_distance:
		var point := origin + direction * travelled
		if TERRAIN_DESIGN.height_at(point.x, point.z) < TERRAIN_DESIGN.WATER_HEIGHT:
			return true
		travelled += STEP
	return false


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
