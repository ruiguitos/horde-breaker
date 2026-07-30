extends SceneTree

## The sector generator scatters loot and enemy spawns over a map it does not
## build. It used to know nothing about that map: `_find_free_position` only
## avoided the areas it had reserved itself, so caches and spawn markers landed
## inside hand-painted buildings. The painted cells are now handed to it in the
## same {center, half_x, half_z} form the navigation bake already receives.
##
## Run:  <godot> --headless --path . --script res://tests/test_sector_content.gd

## How many seeds each placement check runs over. Placement is random inside a
## sector, so a single seed proves very little.
const SEED_COUNT := 40
## Blocks of 6 m on an 8 m grid with the centre lanes left open: the shape a
## painted sector actually has, roads included.
const BLOCK_HALF := 3.0
const BLOCK_SPACING := 8.0

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_content_avoids_painted_cells()
	_test_content_does_not_stack()
	_test_open_sector_still_gets_content()
	_test_dense_sector_still_gets_spawns()
	_test_authored_content_wins()
	_test_authoring_one_list_leaves_the_others_scattered()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _make_painted_obstacles() -> Array:
	var obstacles: Array = []
	for x in range(-3, 4):
		for z in range(-3, 4):
			# Row and column zero are the streets, which must stay walkable.
			if x == 0 or z == 0:
				continue
			obstacles.append({
				"center": Vector3(x * BLOCK_SPACING, 0.0, z * BLOCK_SPACING),
				"half_x": BLOCK_HALF,
				"half_z": BLOCK_HALF,
			})
	return obstacles


func _build(
	sector_seed: int, painted_obstacles: Array, authored: Dictionary = {}
) -> Node3D:
	return SectorGenerator.build_sector({
		"id": &"test_sector",
		"seed": sector_seed,
		"collected_caches": [],
		"ammo_collected": false,
		"weapon_collected": false,
		"outer_walls": [],
		"painted_obstacles": painted_obstacles,
		"authored": authored,
		"label": "TEST",
	})


## Every cache, ammo box, weapon crate and spawn marker in the sector, as flat
## XZ positions.
func _collect_placements(sector: Node3D) -> Array[Vector2]:
	var placements: Array[Vector2] = []
	for group in ["ScrapCaches", "SpawnPoints"]:
		var root := sector.get_node_or_null(group)
		if root == null:
			continue
		for child in root.get_children():
			var spatial := child as Node3D
			if spatial != null:
				placements.append(Vector2(spatial.position.x, spatial.position.z))
	for single in ["AmmoBox", "WeaponCrate"]:
		var node := sector.get_node_or_null(single) as Node3D
		if node != null:
			placements.append(Vector2(node.position.x, node.position.z))
	return placements


func _is_inside_obstacle(point: Vector2, obstacles: Array) -> bool:
	for obstacle in obstacles:
		var centre: Vector3 = obstacle["center"]
		if (
			absf(point.x - centre.x) <= float(obstacle["half_x"])
			and absf(point.y - centre.z) <= float(obstacle["half_z"])
		):
			return true
	return false


func _test_content_avoids_painted_cells() -> void:
	var obstacles := _make_painted_obstacles()
	var buried := 0
	var checked := 0
	for sector_seed in SEED_COUNT:
		var sector := _build(sector_seed * 7919, obstacles)
		for placement in _collect_placements(sector):
			checked += 1
			if _is_inside_obstacle(placement, obstacles):
				buried += 1
		sector.free()
	_check("placements were made to check (%d)" % checked, checked > 0)
	# Before painted cells reached the generator this was in the dozens.
	_check(
		"no content sits inside a painted building (%d of %d)" % [buried, checked],
		buried == 0
	)


func _test_content_does_not_stack() -> void:
	var obstacles := _make_painted_obstacles()
	var collisions := 0
	for sector_seed in SEED_COUNT:
		var sector := _build(sector_seed * 104_729, obstacles)
		var placements := _collect_placements(sector)
		for first in placements.size():
			for second in range(first + 1, placements.size()):
				if placements[first].distance_to(placements[second]) < 2.0:
					collisions += 1
		sector.free()
	_check(
		"no two pieces of content share a spot (%d)" % collisions, collisions == 0
	)


func _test_open_sector_still_gets_content() -> void:
	# The guard against the fix going too far: an empty sector must still fill up.
	var caches := 0
	var spawns := 0
	for sector_seed in SEED_COUNT:
		var sector := _build(sector_seed * 31, [])
		var caches_root := sector.get_node_or_null("ScrapCaches")
		if caches_root != null:
			caches += caches_root.get_child_count()
		var spawns_root := sector.get_node_or_null("SpawnPoints")
		if spawns_root != null:
			spawns += spawns_root.get_child_count()
		sector.free()
	_check("open sectors still hold caches (%d)" % caches, caches >= SEED_COUNT * 2)
	_check(
		"every sector gets its spawn markers (%d)" % spawns,
		spawns == SEED_COUNT * SectorGenerator.SPAWN_MARKER_COUNT
	)


func _test_dense_sector_still_gets_spawns() -> void:
	# A sector with no room left at all still has to produce spawn markers, or
	# the horde has nowhere to come from. They fall back to the ring, which is
	# only useful if the ring itself is checked against the map.
	# Covers the whole area the random attempts draw from (+-24 m), leaving only
	# the outermost ring positions.
	var wall: Array = [{
		"center": Vector3.ZERO, "half_x": 24.0, "half_z": 24.0,
	}]
	var sector := _build(4242, wall)
	var spawns_root := sector.get_node_or_null("SpawnPoints")
	_check("a full sector still has spawn markers", spawns_root != null
		and spawns_root.get_child_count() == SectorGenerator.SPAWN_MARKER_COUNT)
	var buried := 0
	if spawns_root != null:
		for child in spawns_root.get_children():
			var marker := child as Marker3D
			if marker != null and _is_inside_obstacle(
				Vector2(marker.position.x, marker.position.z), wall
			):
				buried += 1
	_check("fallback spawns land outside the block (%d buried)" % buried, buried == 0)
	sector.free()


## A sector with a SectorData file is designed, not scattered: the content goes
## exactly where it was put, including on top of a painted building if that is
## what the author asked for.
func _test_authored_content_wins() -> void:
	var spawns: Array[Vector2] = [Vector2(-20.0, 18.0), Vector2(20.0, -18.0)]
	var caches: Array[Vector2] = [Vector2(-9.0, -9.0)]
	var ammunition: Array[Vector2] = [Vector2(11.0, 4.0)]
	var weapons: Array[Vector2] = [Vector2(0.0, 15.0)]
	var sector := _build(1234, _make_painted_obstacles(), {
		&"enemy_spawns": spawns,
		&"scrap_caches": caches,
		&"ammunition_boxes": ammunition,
		&"weapon_crates": weapons,
	})

	var placed_spawns: Array[Vector2] = []
	var spawns_root := sector.get_node_or_null("SpawnPoints")
	if spawns_root != null:
		for child in spawns_root.get_children():
			var marker := child as Node3D
			placed_spawns.append(Vector2(marker.position.x, marker.position.z))
	_check(
		"authored spawns are used exactly (%d)" % placed_spawns.size(),
		placed_spawns == spawns
	)

	var cache := sector.get_node_or_null("ScrapCaches/Cache0") as Node3D
	_check(
		"the authored cache lands where it was put",
		cache != null and Vector2(cache.position.x, cache.position.z) == caches[0]
	)
	var ammo_box := sector.get_node_or_null("AmmoBox") as Node3D
	_check(
		"the authored ammunition lands where it was put",
		ammo_box != null and Vector2(ammo_box.position.x, ammo_box.position.z) == ammunition[0]
	)
	# The generator offers a weapon in roughly one sector in three; an authored
	# crate is a decision and has to beat that roll every time.
	var crate := sector.get_node_or_null("WeaponCrate") as Node3D
	_check(
		"an authored weapon crate always appears",
		crate != null and Vector2(crate.position.x, crate.position.z) == weapons[0]
	)
	sector.free()


func _test_authoring_one_list_leaves_the_others_scattered() -> void:
	# Half-authored sectors are the normal case while a sector is being taken
	# over, and they must not lose the content nobody has placed yet.
	var spawns: Array[Vector2] = [Vector2(-20.0, 20.0)]
	var obstacles := _make_painted_obstacles()
	var sector := _build(99, obstacles, {&"enemy_spawns": spawns})
	var spawns_root := sector.get_node_or_null("SpawnPoints")
	_check(
		"only the authored spawn is placed",
		spawns_root != null and spawns_root.get_child_count() == spawns.size()
	)
	var caches_root := sector.get_node_or_null("ScrapCaches")
	_check(
		"the caches are still scattered",
		caches_root != null and caches_root.get_child_count() >= 2
	)
	var buried := 0
	for placement in _collect_placements(sector):
		if placement != spawns[0] and _is_inside_obstacle(placement, obstacles):
			buried += 1
	_check(
		"the scattered half still avoids the map (%d buried)" % buried, buried == 0
	)
	sector.free()


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
