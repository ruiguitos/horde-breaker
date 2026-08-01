class_name SectorGenerator
extends RefCounted

## Fills a 64 x 64 m sector with run content from a deterministic seed: caches,
## ammunition, a weapon crate and enemy spawn markers.
##
## It builds no visible map geometry. Terrain3D supplies the continuous ground;
## this generator adds only run content, invisible bounds and navigation.
##
## Stages must run in order: begin -> content -> finish.

const SCRAP_PICKUP_SCENE := preload("res://scenes/pickups/scrap_pickup.tscn")
const AMMO_PICKUP_SCENE := preload("res://scenes/pickups/ammo_pickup.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/pickups/weapon_pickup.tscn")
const NAVIGATION_SCRIPT := preload("res://scripts/systems/arena_navigation.gd")
const TERRAIN_WORLD_DESIGN := preload(
	"res://scripts/systems/terrain3d_world_design.gd"
)
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
	{"id": &"minigun", "name": "Minigun", "weight": 0.12},
]
const SECTOR_HALF_SIZE := 32.0
const SPAWN_MARKER_COUNT := 3
## Footprint every piece of scattered content reserves for itself.
const CONTENT_SIZE := Vector3(2.0, 1.0, 2.0)
## Ring used when a sector is too built up for the random attempts to land.
const SPAWN_FALLBACK_POSITIONS: Array[Vector2] = [
	Vector2(-24.0, -24.0), Vector2(24.0, -24.0), Vector2(24.0, 24.0),
	Vector2(-24.0, 24.0), Vector2(0.0, -28.0), Vector2(28.0, 0.0),
	Vector2(0.0, 28.0), Vector2(-28.0, 0.0),
]


static func begin_sector(config: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config["seed"])
	var sector := Node3D.new()
	sector.name = String(config["id"]).validate_node_name()
	sector.add_to_group(&"world_sector")
	# No per-sector floor: Terrain3D supplies one continuous surface for the
	# complete world. Sector slabs would leave seams and disappear on unload.
	# The Terrain3D island owns one persistent shoreline boundary. Streaming a
	# second square wall per edge sector creates invisible limits out at sea.
	if StringName(config.get("terrain_profile", &"")) != &"world":
		_add_outer_walls(sector, config.get("outer_walls", []))
	return {
		"config": config,
		"rng": rng,
		"sector": sector,
		# Empty in this terrain-only pass. The input remains ready for future
		# terrain-native landmarks that reserve content space.
		"blocked_areas": _get_painted_blocked_areas(
			config.get("painted_obstacles", [])
		),
	}


static func add_content_stage(context: Dictionary) -> void:
	# Content only: caches, ammunition, a possible weapon and enemy spawns. The
	# visible world remains exclusively Terrain3D in this pass.
	var sector: Node3D = context["sector"]
	var rng: RandomNumberGenerator = context["rng"]
	var config: Dictionary = context["config"]
	var blocked_areas: Array[Rect2] = context["blocked_areas"]
	_add_caches(sector, rng, config, blocked_areas)
	_add_ammo_box(sector, rng, config, blocked_areas)
	_add_weapon_crate(sector, rng, config, blocked_areas)
	_add_spawn_markers(sector, rng, config, blocked_areas)


static func finish_sector(context: Dictionary) -> void:
	var config: Dictionary = context["config"]
	_add_navigation(
		context["sector"],
		config.get("painted_obstacles", []),
		config
	)


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
	# Positions are always resolved so the layout stays deterministic even when
	# previously collected caches are skipped.
	var placements := _get_placements(
		_get_authored(config, &"scrap_caches"), cache_count, rng, blocked_areas, config
	)
	for cache_index in placements.size():
		var placement := placements[cache_index]
		if placement == Vector2.INF or cache_index in collected_caches:
			continue
		var cache := SCRAP_PICKUP_SCENE.instantiate() as Area3D
		cache.name = "Cache%d" % cache_index
		caches_root.add_child(cache)
		cache.position = Vector3(
			placement.x,
			_get_ground_height(config, placement) + 0.25,
			placement.y
		)
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
	var placements := _get_placements(
		_get_authored(config, &"ammunition_boxes"), 1, rng, blocked_areas, config
	)
	var placement: Vector2 = placements[0] if not placements.is_empty() else Vector2.INF
	if placement == Vector2.INF or bool(config.get("ammo_collected", false)):
		return
	var ammo_callable: Callable = config.get("ammo_collected_callable", Callable())
	var ammo_box := AMMO_PICKUP_SCENE.instantiate() as Area3D
	ammo_box.name = "AmmoBox"
	sector.add_child(ammo_box)
	ammo_box.position = Vector3(
		placement.x,
		_get_ground_height(config, placement) + 0.25,
		placement.y
	)
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
	var authored := _get_authored(config, &"weapon_crates")
	# An authored crate is a decision, not a roll: it is always there.
	var offers_weapon := rng.randf() < 0.34 or not authored.is_empty()
	var placements := _get_placements(authored, 1, rng, blocked_areas, config)
	var placement: Vector2 = placements[0] if not placements.is_empty() else Vector2.INF
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
	crate.position = Vector3(
		placement.x,
		_get_ground_height(config, placement) + 0.35,
		placement.y
	)
	var weapon_callable: Callable = config.get("weapon_collected_callable", Callable())
	if weapon_callable.is_valid():
		crate.connect(
			&"collected", weapon_callable.bind(StringName(config["id"]))
		)


static func _add_spawn_markers(
	sector: Node3D,
	rng: RandomNumberGenerator,
	config: Dictionary,
	blocked_areas: Array[Rect2]
) -> void:
	var spawns_root := Node3D.new()
	spawns_root.name = "SpawnPoints"
	sector.add_child(spawns_root)
	var placements := _get_placements(
		_get_authored(config, &"enemy_spawns"),
		SPAWN_MARKER_COUNT,
		rng,
		blocked_areas,
		config
	)
	for spawn_index in placements.size():
		var placement := placements[spawn_index]
		if placement == Vector2.INF:
			placement = _find_fallback_spawn(spawn_index, blocked_areas, config)
		if placement == Vector2.INF:
			continue
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % spawn_index
		marker.add_to_group(&"enemy_spawn_point")
		spawns_root.add_child(marker)
		marker.position = Vector3(
			placement.x,
			_get_ground_height(config, placement) + 1.0,
			placement.y
		)


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


static func _bake_navigation_mesh(
	sector: Node3D,
	painted_obstacles: Array = [],
	config: Dictionary = {}
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
			var local_x := -SECTOR_HALF_SIZE + x_index * cell_size
			var local_z := -SECTOR_HALF_SIZE + z_index * cell_size
			vertices.append(Vector3(
				local_x,
				_get_ground_height(config, Vector2(local_x, local_z)),
				local_z
			))
	navigation_mesh.vertices = vertices
	var row_size := cell_count + 1
	var half_cell := cell_size * 0.5
	for z_index in range(cell_count):
		var center_z := -SECTOR_HALF_SIZE + (z_index + 0.5) * cell_size
		for x_index in range(cell_count):
			var center_x := -SECTOR_HALF_SIZE + (x_index + 0.5) * cell_size
			var blocked := _is_terrain_navigation_blocked(
				config, Vector2(center_x, center_z)
			)
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


static func _add_navigation(
	sector: Node3D,
	painted_obstacles: Array,
	config: Dictionary
) -> void:
	var navigation_region := NavigationRegion3D.new()
	navigation_region.name = "NavigationRegion3D"
	navigation_region.set_script(NAVIGATION_SCRIPT)
	navigation_region.set(&"navigation_half_extent", SECTOR_HALF_SIZE)
	# Baked here (worker thread) so entering the tree costs almost nothing.
	navigation_region.navigation_mesh = _bake_navigation_mesh(
		sector, painted_obstacles, config
	)
	sector.add_child(navigation_region)


static func _get_ground_height(config: Dictionary, local_position: Vector2) -> float:
	if StringName(config.get("terrain_profile", &"")) != &"world":
		return 0.0
	var sector_position: Vector3 = config.get("position", Vector3.ZERO)
	return TERRAIN_WORLD_DESIGN.height_at(
		sector_position.x + local_position.x,
		sector_position.z + local_position.y
	)


static func _is_terrain_navigation_blocked(
	config: Dictionary, local_position: Vector2
) -> bool:
	if StringName(config.get("terrain_profile", &"")) != &"world":
		return false
	var sector_position: Vector3 = config.get("position", Vector3.ZERO)
	return TERRAIN_WORLD_DESIGN.is_navigation_blocked(
		Vector2(
			sector_position.x + local_position.x,
			sector_position.z + local_position.y
		)
	)


## The hand-placed positions for one kind of content, or an empty list when this
## sector has no file (see SectorData and world_streamer._load_authored_content).
static func _get_authored(config: Dictionary, list_name: StringName) -> Array:
	var authored: Dictionary = config.get("authored", {})
	return authored.get(list_name, [])


## Where a batch of content goes: the authored positions if this sector has any,
## otherwise `count` positions drawn from the free space.
##
## Each list falls back on its own, so a sector can be authored a piece at a
## time. Authoring one list does shift the random draws for the ones after it —
## a sector half designed is a sector whose remaining loot moves once.
static func _get_placements(
	authored: Array,
	count: int,
	rng: RandomNumberGenerator,
	blocked_areas: Array[Rect2],
	config: Dictionary
) -> Array[Vector2]:
	var placements: Array[Vector2] = []
	if not authored.is_empty():
		for position: Vector2 in authored:
			if not _is_walkable_terrain(config, position):
				placements.append(Vector2.INF)
				continue
			# Reserved so anything still being scattered keeps away from it.
			blocked_areas.append(Rect2(position - Vector2.ONE, Vector2(2.0, 2.0)))
			placements.append(position)
		return placements
	for index in count:
		placements.append(
			_find_free_position(rng, CONTENT_SIZE, blocked_areas, config)
		)
	return placements


## Turns the painted GridMap cells the streamer collected into the flat rectangle
## list content placement uses. Obstacle centres already arrive relative to the
## sector origin, which is the same space `_find_free_position` works in.
static func _get_painted_blocked_areas(painted_obstacles: Array) -> Array[Rect2]:
	var areas: Array[Rect2] = []
	for obstacle in painted_obstacles:
		var centre: Vector3 = obstacle["center"]
		var half_x := float(obstacle["half_x"])
		var half_z := float(obstacle["half_z"])
		areas.append(Rect2(
			Vector2(centre.x - half_x, centre.z - half_z),
			Vector2(half_x * 2.0, half_z * 2.0)
		))
	return areas


static func _find_free_position(
	rng: RandomNumberGenerator,
	size: Vector3,
	blocked_areas: Array[Rect2],
	config: Dictionary
) -> Vector2:
	for attempt in 20:
		var candidate := Vector2(
			rng.randf_range(-24.0, 24.0), rng.randf_range(-24.0, 24.0)
		)
		# Keep the sector centre clear so there is always a way through.
		if absf(candidate.x) < 6.0 and absf(candidate.y) < 6.0:
			continue
		if not _is_walkable_terrain(config, candidate):
			continue
		var footprint := Rect2(
			candidate - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z)
		)
		if _is_area_free(footprint.grow(2.0), blocked_areas):
			# Reserve what was just taken. Without this, everything placed in a
			# sector was tested against the map but never against the rest of the
			# loot, so two caches could share a spot.
			blocked_areas.append(footprint)
			return candidate
	return Vector2.INF


## Last resort for a sector so dense that the random attempts all landed on
## painted geometry. Walking the ring beats the old fixed offsets, which were
## chosen before the map existed and could sit inside a building.
static func _find_fallback_spawn(
	spawn_index: int, blocked_areas: Array[Rect2], config: Dictionary
) -> Vector2:
	var count := SPAWN_FALLBACK_POSITIONS.size()
	for offset in count:
		var candidate := SPAWN_FALLBACK_POSITIONS[(spawn_index + offset) % count]
		if not _is_walkable_terrain(config, candidate):
			continue
		var footprint := Rect2(candidate - Vector2(1.0, 1.0), Vector2(2.0, 2.0))
		if _is_area_free(footprint.grow(2.0), blocked_areas):
			blocked_areas.append(footprint)
			return candidate
	return Vector2.INF


static func _is_walkable_terrain(
	config: Dictionary, local_position: Vector2
) -> bool:
	if StringName(config.get("terrain_profile", &"")) != &"world":
		return true
	var sector_position: Vector3 = config.get("position", Vector3.ZERO)
	return TERRAIN_WORLD_DESIGN.is_walkable_land(Vector2(
		sector_position.x + local_position.x,
		sector_position.z + local_position.y
	))


static func _is_area_free(area: Rect2, blocked_areas: Array[Rect2]) -> bool:
	for blocked_area in blocked_areas:
		if area.intersects(blocked_area):
			return false
	return true
