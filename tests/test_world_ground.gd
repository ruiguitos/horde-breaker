extends SceneTree

## The 4x4 sector grid must stand on one continuous ground plane. Per-sector
## floor slabs left seams at the borders and, worse, punched holes in the world
## whenever a sector streamed out. This pins both halves of that rule: sectors
## carry no floor of their own, and the arena's ground covers every sector.

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const SECTOR_GENERATOR := "res://scripts/systems/sector_generator.gd"
const WORLD_STREAMER := "res://scripts/systems/world_streamer.gd"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var streamer: GDScript = load(WORLD_STREAMER)
	var sector_size := float(streamer.get(&"SECTOR_SIZE"))
	var grid_min: Vector2i = streamer.get(&"GRID_MIN")
	var grid_max: Vector2i = streamer.get(&"GRID_MAX")
	var sectors_per_axis := grid_max.x - grid_min.x + 1
	_check("grid: 4 sectors per axis", sectors_per_axis == 4)

	# World bounds, in metres, derived from the streamer's own numbers.
	var world_min := Vector2(
		float(grid_min.x) * sector_size - sector_size * 0.5,
		float(grid_min.y) * sector_size - sector_size * 0.5
	)
	var world_max := Vector2(
		float(grid_max.x) * sector_size + sector_size * 0.5,
		float(grid_max.y) * sector_size + sector_size * 0.5
	)

	if change_scene_to_file(ARENA_SCENE) != OK:
		_check("arena loads", false)
		quit(1)
		return
	await scene_changed
	for _frame in 30:
		await process_frame

	var ground := current_scene.get_node_or_null("Floor") as StaticBody3D
	_check("ground: the arena has a Floor body", ground != null)
	if ground == null:
		_report()
		return
	var collision := ground.get_node_or_null("Collision") as CollisionShape3D
	var box := collision.shape as BoxShape3D if collision != null else null
	_check("ground: floor collision is a box", box != null)
	if box == null:
		_report()
		return

	var half := Vector2(box.size.x, box.size.z) * 0.5
	var centre := Vector2(ground.global_position.x, ground.global_position.z)
	var ground_min := centre - half
	var ground_max := centre + half
	_check(
		"ground: covers the west/north edge (%.0f,%.0f <= %.0f,%.0f)" % [
			ground_min.x, ground_min.y, world_min.x, world_min.y
		],
		ground_min.x <= world_min.x + 0.01 and ground_min.y <= world_min.y + 0.01
	)
	_check(
		"ground: covers the east/south edge (%.0f,%.0f >= %.0f,%.0f)" % [
			ground_max.x, ground_max.y, world_max.x, world_max.y
		],
		ground_max.x >= world_max.x - 0.01 and ground_max.y >= world_max.y - 0.01
	)

	# Every sector centre, and every sector corner, must sit over solid ground.
	var uncovered := 0
	for grid_x in range(grid_min.x, grid_max.x + 1):
		for grid_y in range(grid_min.y, grid_max.y + 1):
			var sector_centre := Vector2(
				float(grid_x) * sector_size, float(grid_y) * sector_size
			)
			for corner in [
				Vector2(0.0, 0.0),
				Vector2(-0.5, -0.5) * sector_size,
				Vector2(0.5, -0.5) * sector_size,
				Vector2(-0.5, 0.5) * sector_size,
				Vector2(0.5, 0.5) * sector_size,
			]:
				var point: Vector2 = sector_centre + corner
				if (
					point.x < ground_min.x - 0.01 or point.x > ground_max.x + 0.01
					or point.y < ground_min.y - 0.01 or point.y > ground_max.y + 0.01
				):
					uncovered += 1
	_check("ground: all 16 sectors sit on it (%d points off)" % uncovered, uncovered == 0)

	# A generated sector must not bring a floor of its own.
	var generator: GDScript = load(SECTOR_GENERATOR)
	var sector: Node3D = generator.call(&"build_sector", {
		"id": "test_sector",
		"seed": 12345,
		"collected_caches": [],
		"ammo_collected": false,
		"weapon_collected": false,
		"outer_walls": [],
		"label": "TEST",
	})
	_check("sector: generated", sector != null)
	if sector == null:
		_report()
		return
	_check(
		"sector: carries no floor node",
		sector.get_node_or_null("Floor") == null
	)
	var floor_like := 0
	for value in sector.find_children("*", "StaticBody3D", true, false):
		var body := value as StaticBody3D
		var body_collision := body.get_node_or_null("Collision") as CollisionShape3D
		if body_collision == null:
			continue
		var body_box := body_collision.shape as BoxShape3D
		if body_box == null:
			continue
		# A slab as wide as the sector and flat is a floor by any other name.
		if body_box.size.x >= sector_size - 1.0 and body_box.size.y <= 2.0:
			floor_like += 1
	_check("sector: no sector-wide slab left (%d found)" % floor_like, floor_like == 0)
	sector.free()
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
