class_name SectorGenerator
extends RefCounted

## Fills a 64 x 64 m sector with run content from a deterministic seed: caches,
## ammunition, a weapon crate and enemy spawn markers.
##
## It builds no geometry. The map itself — roads, pavement, buildings, props —
## is hand-painted in the arena's GridMap layers (see docs/MAP_DESIGN.md), and
## anything procedural placed here would land on top of it. Loot and spawns are
## scattered over whatever was painted.
##
## Stages must run in order: begin -> content -> finish.

const SCRAP_PICKUP_SCENE := preload("res://scenes/pickups/scrap_pickup.tscn")
const AMMO_PICKUP_SCENE := preload("res://scenes/pickups/ammo_pickup.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/pickups/weapon_pickup.tscn")
const NAVIGATION_SCRIPT := preload("res://scripts/systems/arena_navigation.gd")
## Weapons found while exploring. These are field pickups: they take over the
## secondary slot for the current run only and never touch the permanent ARMORY
## loadout, so a rare heavy find is a run highlight rather than a shortcut past
## the Credits or the kill-count evolutions.
const WEAPON_POOL: Array[Dictionary] = [
	{"id": &"assault_rifle", "name": "Assault Rifle", "weight": 1.0},
	{"id": &"shotgun", "name": "Shotgun", "weight": 1.0},
	{"id": &"pistol", "name": "Pistol", "weight": 0.6},
	{"id": &"smg", "name": "SMG", "weight": 1.0},
	{"id": &"machine_gun", "name": "Machine Gun", "weight": 0.55},
	{"id": &"fire_axe", "name": "Fire Axe", "weight": 0.7},
	{"id": &"spear", "name": "Spear", "weight": 0.7},
	{"id": &"worn_sword", "name": "Worn Sword", "weight": 0.6},
	{"id": &"minigun", "name": "Minigun", "weight": 0.12},
]
const SECTOR_HALF_SIZE := 32.0
const SPAWN_MARKER_COUNT := 3


static func begin_sector(config: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config["seed"])
	var sector := Node3D.new()
	sector.name = String(config["id"]).validate_node_name()
	sector.add_to_group(&"world_sector")
	# No per-sector floor: the whole 4x4 grid stands on one continuous ground
	# plane owned by the arena. Sector-sized slabs left seams at the borders and
	# punched holes in the world whenever a sector streamed out.
	_add_outer_walls(sector, config.get("outer_walls", []))
	_add_sector_label(sector, String(config.get("label", "")))
	return {
		"config": config,
		"rng": rng,
		"sector": sector,
		"blocked_areas": [] as Array[Rect2],
	}


static func add_content_stage(context: Dictionary) -> void:
	# Content only. The generator no longer builds anything structural — no
	# buildings, landmarks, containers or set dressing — because the map itself
	# is now hand-painted in the GridMap layers and procedural geometry would
	# land on top of it. What is left is the run's loot and where enemies come
	# from, scattered over whatever was painted.
	var sector: Node3D = context["sector"]
	var rng: RandomNumberGenerator = context["rng"]
	var config: Dictionary = context["config"]
	var blocked_areas: Array[Rect2] = context["blocked_areas"]
	_add_caches(sector, rng, config, blocked_areas)
	_add_ammo_box(sector, rng, config, blocked_areas)
	_add_weapon_crate(sector, rng, config, blocked_areas)
	_add_spawn_markers(sector, rng, blocked_areas)


static func finish_sector(context: Dictionary) -> void:
	var config: Dictionary = context["config"]
	_add_navigation(context["sector"], config.get("painted_obstacles", []))


static func build_sector(config: Dictionary) -> Node3D:
	var context := begin_sector(config)
	add_content_stage(context)
	finish_sector(context)
	return context["sector"]


static func _add_caches(
	sector: Node3D,
	rng: RandomNumberGenerator,
	config: Dictionary,
	blocked_areas: Array[Rect2]
) -> void:
	var collected_caches: Array = config.get("collected_caches", [])
	var cache_callable: Callable = config.get("cache_collected_callable", Callable())
	var caches_root := Node3D.new()
	caches_root.name = "ScrapCaches"
	sector.add_child(caches_root)
	var cache_count := 2 + rng.randi_range(0, 1)
	for cache_index in cache_count:
		# Positions are always drawn so the layout stays deterministic even
		# when previously collected caches are skipped.
		var placement := _find_free_position(
			rng, Vector3(2.0, 1.0, 2.0), blocked_areas
		)
		if placement == Vector2.INF or cache_index in collected_caches:
			continue
		var cache := SCRAP_PICKUP_SCENE.instantiate() as Area3D
		cache.name = "Cache%d" % cache_index
		caches_root.add_child(cache)
		cache.position = Vector3(placement.x, 0.25, placement.y)
		if cache_callable.is_valid():
			cache.connect(
				&"collected",
				cache_callable.bind(StringName(config["id"]), cache_index)
			)


static func _add_ammo_box(
	sector: Node3D,
	rng: RandomNumberGenerator,
	config: Dictionary,
	blocked_areas: Array[Rect2]
) -> void:
	var placement := _find_free_position(
		rng, Vector3(2.0, 1.0, 2.0), blocked_areas
	)
	if placement == Vector2.INF or bool(config.get("ammo_collected", false)):
		return
	var ammo_callable: Callable = config.get("ammo_collected_callable", Callable())
	var ammo_box := AMMO_PICKUP_SCENE.instantiate() as Area3D
	ammo_box.name = "AmmoBox"
	sector.add_child(ammo_box)
	ammo_box.position = Vector3(placement.x, 0.25, placement.y)
	if ammo_callable.is_valid():
		ammo_box.connect(
			&"collected", ammo_callable.bind(StringName(config["id"]))
		)


static func _pick_weapon(rng: RandomNumberGenerator) -> Dictionary:
	# Seeded draw, so a given sector always holds the same weapon.
	var total_weight := 0.0
	for entry in WEAPON_POOL:
		total_weight += float(entry["weight"])
	var pick := rng.randf() * total_weight
	for entry in WEAPON_POOL:
		pick -= float(entry["weight"])
		if pick <= 0.0:
			return entry
	return WEAPON_POOL[0]


static func _add_weapon_crate(
	sector: Node3D,
	rng: RandomNumberGenerator,
	config: Dictionary,
	blocked_areas: Array[Rect2]
) -> void:
	# Roughly one in three sectors offers a weapon to find while exploring.
	# The choice is seeded so the same sector always holds the same weapon.
	var weapon_choice := _pick_weapon(rng)
	var offers_weapon := rng.randf() < 0.34
	var placement := _find_free_position(
		rng, Vector3(2.0, 1.0, 2.0), blocked_areas
	)
	if (
		not offers_weapon
		or placement == Vector2.INF
		or bool(config.get("weapon_collected", false))
	):
		return
	var crate := WEAPON_PICKUP_SCENE.instantiate() as Area3D
	crate.name = "WeaponCrate"
	crate.set(&"weapon_id", weapon_choice["id"])
	crate.set(&"weapon_display_name", weapon_choice["name"])
	sector.add_child(crate)
	crate.position = Vector3(placement.x, 0.35, placement.y)
	var weapon_callable: Callable = config.get("weapon_collected_callable", Callable())
	if weapon_callable.is_valid():
		crate.connect(
			&"collected", weapon_callable.bind(StringName(config["id"]))
		)


static func _add_spawn_markers(
	sector: Node3D, rng: RandomNumberGenerator, blocked_areas: Array[Rect2]
) -> void:
	var spawns_root := Node3D.new()
	spawns_root.name = "SpawnPoints"
	sector.add_child(spawns_root)
	for spawn_index in SPAWN_MARKER_COUNT:
		var placement := _find_free_position(
			rng, Vector3(2.0, 1.0, 2.0), blocked_areas
		)
		if placement == Vector2.INF:
			placement = Vector2(
				-24.0 + 24.0 * spawn_index, -24.0 if spawn_index % 2 == 0 else 24.0
			)
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % spawn_index
		marker.add_to_group(&"enemy_spawn_point")
		spawns_root.add_child(marker)
		marker.position = Vector3(placement.x, 1.0, placement.y)


static func _add_outer_walls(sector: Node3D, outer_walls: Array) -> void:
	if outer_walls.is_empty():
		return
	var walls_root := Node3D.new()
	walls_root.name = "OuterWalls"
	sector.add_child(walls_root)
	var wall_offset := SECTOR_HALF_SIZE + 0.5
	var horizontal_size := Vector3(SECTOR_HALF_SIZE * 2.0 + 1.0, 4.0, 1.0)
	var vertical_size := Vector3(1.0, 4.0, SECTOR_HALF_SIZE * 2.0 + 1.0)
	var wall_layouts: Dictionary[StringName, Dictionary] = {
		&"north": {"position": Vector3(0.0, 2.0, -wall_offset), "size": horizontal_size},
		&"south": {"position": Vector3(0.0, 2.0, wall_offset), "size": horizontal_size},
		&"east": {"position": Vector3(wall_offset, 2.0, 0.0), "size": vertical_size},
		&"west": {"position": Vector3(-wall_offset, 2.0, 0.0), "size": vertical_size},
	}
	for wall_side in outer_walls:
		var layout: Dictionary = wall_layouts.get(StringName(wall_side), {})
		if layout.is_empty():
			continue
		var wall := StaticBody3D.new()
		wall.name = "OuterWall%s" % String(wall_side).capitalize()
		wall.position = layout["position"]
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var wall_shape := BoxShape3D.new()
		wall_shape.size = layout["size"]
		collision.shape = wall_shape
		wall.add_child(collision)
		walls_root.add_child(wall)


static func _add_sector_label(sector: Node3D, label_text: String) -> void:
	if label_text.is_empty():
		return
	var label := Label3D.new()
	label.name = "SectorLabel"
	label.text = label_text
	label.font_size = 30
	label.outline_size = 10
	label.modulate = Color(0.95, 0.55, 0.2, 1.0)
	label.outline_modulate = Color(0.04, 0.02, 0.01, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 6.0, 0.0)
	sector.add_child(label)


static func _bake_navigation_mesh(
	sector: Node3D, painted_obstacles: Array = []
) -> NavigationMesh:
	# Same grid logic as arena_navigation, but computed with transforms relative
	# to the still-detached sector so it can run off the main thread. Painted
	# GridMap cells arrive pre-collected from the main thread, in the same
	# {center, half_x, half_z} form as the node blockers below.
	var cell_size := 1.0
	var clearance := 0.65
	var cell_count := int(round(SECTOR_HALF_SIZE * 2.0 / cell_size))
	var blockers: Array = painted_obstacles.duplicate()
	for node in sector.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body == null or not body.is_in_group(&"navigation_blocker"):
			continue
		var collision := body.get_node_or_null("Collision") as CollisionShape3D
		if collision == null or collision.disabled:
			continue
		var box_shape := collision.shape as BoxShape3D
		if box_shape == null:
			continue
		var relative := _get_transform_relative_to(collision, sector)
		var half_size := box_shape.size * 0.5
		var basis_x := relative.basis.x
		var basis_y := relative.basis.y
		var basis_z := relative.basis.z
		blockers.append({
			"center": relative.origin,
			"half_x": (
				absf(basis_x.x) * half_size.x + absf(basis_y.x) * half_size.y
				+ absf(basis_z.x) * half_size.z
			),
			"half_z": (
				absf(basis_x.z) * half_size.x + absf(basis_y.z) * half_size.y
				+ absf(basis_z.z) * half_size.z
			),
		})

	var navigation_mesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	for z_index in range(cell_count + 1):
		for x_index in range(cell_count + 1):
			vertices.append(Vector3(
				-SECTOR_HALF_SIZE + x_index * cell_size,
				0.0,
				-SECTOR_HALF_SIZE + z_index * cell_size
			))
	navigation_mesh.vertices = vertices
	var row_size := cell_count + 1
	var half_cell := cell_size * 0.5
	for z_index in range(cell_count):
		var center_z := -SECTOR_HALF_SIZE + (z_index + 0.5) * cell_size
		for x_index in range(cell_count):
			var center_x := -SECTOR_HALF_SIZE + (x_index + 0.5) * cell_size
			var blocked := false
			for blocker in blockers:
				var center: Vector3 = blocker["center"]
				if (
					absf(center_x - center.x)
					<= float(blocker["half_x"]) + clearance + half_cell
					and absf(center_z - center.z)
					<= float(blocker["half_z"]) + clearance + half_cell
				):
					blocked = true
					break
			if blocked:
				continue
			var bottom_left := z_index * row_size + x_index
			navigation_mesh.add_polygon(PackedInt32Array([
				bottom_left, bottom_left + 1,
				(z_index + 1) * row_size + x_index + 1,
				(z_index + 1) * row_size + x_index,
			]))
	return navigation_mesh


static func _get_transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		var spatial := current as Node3D
		if spatial != null:
			result = spatial.transform * result
		current = current.get_parent()
	return result


static func _add_navigation(sector: Node3D, painted_obstacles: Array) -> void:
	var navigation_region := NavigationRegion3D.new()
	navigation_region.name = "NavigationRegion3D"
	navigation_region.set_script(NAVIGATION_SCRIPT)
	navigation_region.set(&"navigation_half_extent", SECTOR_HALF_SIZE)
	# Baked here (worker thread) so entering the tree costs almost nothing.
	navigation_region.navigation_mesh = _bake_navigation_mesh(
		sector, painted_obstacles
	)
	sector.add_child(navigation_region)


static func _find_free_position(
	rng: RandomNumberGenerator,
	size: Vector3,
	blocked_areas: Array[Rect2]
) -> Vector2:
	for attempt in 20:
		var candidate := Vector2(
			rng.randf_range(-24.0, 24.0), rng.randf_range(-24.0, 24.0)
		)
		# Keep the sector centre clear so there is always a way through.
		if absf(candidate.x) < 6.0 and absf(candidate.y) < 6.0:
			continue
		var candidate_area := Rect2(
			candidate - Vector2(size.x, size.z) * 0.5 - Vector2(2.0, 2.0),
			Vector2(size.x, size.z) + Vector2(4.0, 4.0)
		)
		var overlaps := false
		for blocked_area in blocked_areas:
			if candidate_area.intersects(blocked_area):
				overlaps = true
				break
		if not overlaps:
			return candidate
	return Vector2.INF
