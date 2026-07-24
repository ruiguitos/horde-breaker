class_name SectorGenerator
extends RefCounted

## Builds a 64 x 64 m graybox sector procedurally from a deterministic seed.
## Generation is split into stages (shell, road quadrants, content and
## navigation) so the WorldStreamer can spread the cost over several frames.
## Stages must run in order: begin -> roads 0..3 -> content -> finish.

const SCRAP_PICKUP_SCENE := preload("res://scenes/pickups/scrap_pickup.tscn")
const AMMO_PICKUP_SCENE := preload("res://scenes/pickups/ammo_pickup.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/pickups/weapon_pickup.tscn")
const NAVIGATION_SCRIPT := preload("res://scripts/systems/arena_navigation.gd")
const WEAPON_POOL: Array[Dictionary] = [
	{"id": &"assault_rifle", "name": "Assault Rifle"},
	{"id": &"shotgun", "name": "Shotgun"},
	{"id": &"pistol", "name": "Pistol"},
]
const CONTAINER_SCENES: Array[PackedScene] = [
	preload("res://assets/models/quaternius_zombie_apocalypse/environment/Container_Green.gltf"),
	preload("res://assets/models/quaternius_zombie_apocalypse/environment/Container_Red.gltf"),
]
const WATER_TOWER_SCENE := preload("res://assets/models/quaternius_zombie_apocalypse/environment/WaterTower.gltf")
const TRUCK_SCENE := preload("res://assets/models/quaternius_zombie_apocalypse/vehicles/Vehicle_Truck_Armored.gltf")
const STREET_LIGHT_SCENE := preload("res://assets/models/quaternius_zombie_apocalypse/environment/StreetLights.gltf")

const SECTOR_HALF_SIZE := 32.0
const SPAWN_MARKER_COUNT := 3
# Real low-poly city buildings (CC0 Quaternius Downtown MegaKit) replace the old
# graybox landmark boxes. Each is a single mesh, so draw calls stay low. The
# footprint (x, z in metres) and height come from measuring the models.
const CITY_BUILDINGS: Array[Dictionary] = [
	{
		"scene": preload("res://assets/models/city_test_model/Exports/glTF (Godot)/Building_Small_1.gltf"),
		"footprint": Vector2(12.5, 14.5),
		"height": 17.0,
		"center": Vector2(-1.0, -4.96),
	},
	{
		"scene": preload("res://assets/models/city_test_model/Exports/glTF (Godot)/Building_Medium_2_001.gltf"),
		"footprint": Vector2(15.1, 13.1),
		"height": 25.0,
		"center": Vector2(0.0, -5.96),
	},
	{
		"scene": preload("res://assets/models/city_test_model/Exports/glTF (Godot)/Building_Large_2.gltf"),
		"footprint": Vector2(20.6, 16.6),
		"height": 28.0,
		"center": Vector2(1.0, -8.0),
	},
]
const CITY_LOT_COLOR := Color(0.5, 0.49, 0.47, 1.0)
const CITY_LOT_MARGIN := 3.0
# City layout: the sector is an 8 x 8 grid of 8 m cells. Cells whose centre sits
# on |4| along an axis form the cross-shaped streets (16 m wide); everything else
# is a city block paved with sidewalk. Buildings only ever go inside blocks, so
# they never sit on top of road markings or crosswalks.
const STREET_CELL_SIZE := 8.0
const STREET_CELLS_PER_AXIS := 8
const STREET_AXIS_CENTER := 4.0
const STREET_STRAIGHT_SCENE := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Street_Straight_Crack1.gltf")
const STREET_4WAY_SCENE := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Street_4Way.gltf")
# Blocks fill the corners: cells from 8 m to 32 m on both axes.
const BLOCK_HALF := 12.0
const BLOCK_CENTER_OFFSET := 20.0
const BLOCK_COLOR := Color(0.62, 0.6, 0.56, 1.0)
const BLOCK_BUILDING_MARGIN := 1.5
const CITY_PLANTER_SCENE := preload("res://assets/models/city_test_model/Exports/glTF (Godot)/Prop_Planter_Single.gltf")
const CITY_BOLLARD_SCENE := preload("res://assets/models/city_test_model/Exports/glTF (Godot)/Prop_Bollard.gltf")
const CITY_MANHOLE_SCENE := preload("res://assets/models/city_test_model/Exports/glTF (Godot)/Prop_ManholeCover.gltf")
const CITY_AC_UNIT_SCENE := preload("res://scenes/world/props/ac_unit.tscn")
const CITY_DRAIN_PIPE_SCENE := preload("res://scenes/world/props/drain_pipe.tscn")
const ABANDONED_CAR_SCENE := preload("res://scenes/world/props/abandoned_car.tscn")
const TRASH_PILE_SCENE := preload("res://scenes/world/props/trash_pile.tscn")
const PROP_PLACEMENT_RULES: PropPlacementRules = preload("res://data/prop_placement_rules.tres")
const POI_REGISTRY: POIRegistry = preload("res://data/poi_registry.tres")
# Explorable point of interest: a walled graybox building with one doorway and a
# reward cache inside. The cache reuses the per-sector cache state under a
# reserved index so it never reappears once collected during a run.
const POI_SPAWN_CHANCE := 0.5
const POI_BUILDING_HALF := 5.5
const POI_WALL_THICKNESS := 0.5
const POI_WALL_HEIGHT := 3.2
const POI_DOORWAY_WIDTH := 4.0
const POI_CACHE_INDEX := 90
const POI_REWARD_SCRAP := 50
const POI_NAMES: Array[String] = ["OUTPOST", "DEPOT", "BUNKER", "RUINS"]
const POI_WALL_COLOR := Color(0.34, 0.36, 0.4, 1.0)
const POI_FLOOR_COLOR := Color(0.2, 0.22, 0.25, 1.0)
const POI_LABEL_COLOR := Color(0.95, 0.77, 0.3, 1.0)
const LANDMARK_VARIANTS: Array[Vector3] = [
	Vector3(12.0, 5.0, 10.0),
	Vector3(8.0, 3.5, 8.0),
	Vector3(6.0, 4.5, 6.0),
	Vector3(10.0, 3.0, 5.0),
]
const LANDMARK_COLORS: Array[Color] = [
	Color(0.55, 0.24, 0.08, 1.0),
	Color(0.3, 0.34, 0.38, 1.0),
	Color(0.46, 0.4, 0.28, 1.0),
]


static func begin_sector(config: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config["seed"])
	var sector := Node3D.new()
	sector.name = String(config["id"]).validate_node_name()
	sector.add_to_group(&"world_sector")
	_add_floor(sector)
	_add_outer_walls(sector, config.get("outer_walls", []))
	_add_sector_label(sector, String(config.get("label", "")))
	return {
		"config": config,
		"rng": rng,
		"sector": sector,
		"blocked_areas": [] as Array[Rect2],
	}


static func add_roads_stage(context: Dictionary, quadrant_index: int) -> void:
	# Streets form a cross through the sector centre; the four corners are city
	# blocks paved with sidewalk. One quadrant is built per stage so the cost
	# stays spread over frames.
	var sector: Node3D = context["sector"]
	var roads_root := sector.get_node_or_null("Roads") as Node3D
	if roads_root == null:
		roads_root = Node3D.new()
		roads_root.name = "Roads"
		sector.add_child(roads_root)
	if quadrant_index < 0 or quadrant_index >= 4:
		return
	for cell_x in range(STREET_CELLS_PER_AXIS):
		for cell_z in range(STREET_CELLS_PER_AXIS):
			var center_x := (
				-STREET_CELLS_PER_AXIS * 0.5 + cell_x + 0.5
			) * STREET_CELL_SIZE
			var center_z := (
				-STREET_CELLS_PER_AXIS * 0.5 + cell_z + 0.5
			) * STREET_CELL_SIZE
			var cell_quadrant := (
				(1 if center_x > 0.0 else 0) + (2 if center_z > 0.0 else 0)
			)
			if cell_quadrant != quadrant_index:
				continue
			var runs_north_south := is_equal_approx(
				absf(center_x), STREET_AXIS_CENTER
			)
			var runs_east_west := is_equal_approx(
				absf(center_z), STREET_AXIS_CENTER
			)
			if not runs_north_south and not runs_east_west:
				continue
			var is_crossing := runs_north_south and runs_east_west
			var tile_scene := (
				STREET_4WAY_SCENE if is_crossing else STREET_STRAIGHT_SCENE
			)
			var tile := tile_scene.instantiate() as Node3D
			tile.name = "Street_%d_%d" % [cell_x, cell_z]
			roads_root.add_child(tile)
			tile.position = Vector3(center_x, -0.1, center_z)
			if not is_crossing and runs_east_west:
				tile.rotation.y = PI / 2.0
	_add_city_block(sector, quadrant_index)


static func _get_block_center(block_index: int) -> Vector2:
	return Vector2(
		BLOCK_CENTER_OFFSET * (1.0 if block_index % 2 == 1 else -1.0),
		BLOCK_CENTER_OFFSET * (1.0 if block_index >= 2 else -1.0)
	)


static func _add_city_block(sector: Node3D, block_index: int) -> void:
	# Flat sidewalk platform (no step, so movement is unaffected) that gives the
	# block its own paved ground instead of road markings.
	var block := MeshInstance3D.new()
	block.name = "Block%d" % block_index
	var block_mesh := BoxMesh.new()
	block_mesh.size = Vector3(BLOCK_HALF * 2.0, 0.06, BLOCK_HALF * 2.0)
	var block_material := StandardMaterial3D.new()
	block_material.albedo_color = BLOCK_COLOR
	block_material.roughness = 0.95
	block_mesh.material = block_material
	block.mesh = block_mesh
	sector.add_child(block)
	var block_center := _get_block_center(block_index)
	block.position = Vector3(block_center.x, 0.03, block_center.y)


static func add_content_stage(context: Dictionary) -> void:
	var sector: Node3D = context["sector"]
	var rng: RandomNumberGenerator = context["rng"]
	var config: Dictionary = context["config"]
	var blocked_areas: Array[Rect2] = context["blocked_areas"]
	# Reserve the point of interest first so nothing else lands on its footprint.
	_add_poi_building(sector, rng, config, blocked_areas)
	var building_infos := _add_city_buildings(sector, rng, blocked_areas)
	_add_containers(sector, rng, blocked_areas)
	_add_set_dressing(sector, rng, blocked_areas)
	_add_city_props(sector, rng, blocked_areas, building_infos, int(config["seed"]))
	_add_caches(sector, rng, config, blocked_areas)
	_add_ammo_box(sector, rng, config, blocked_areas)
	_add_weapon_crate(sector, rng, config, blocked_areas)
	_add_spawn_markers(sector, rng, blocked_areas)


static func finish_sector(context: Dictionary) -> void:
	_add_navigation(context["sector"])


static func build_sector(config: Dictionary) -> Node3D:
	var context := begin_sector(config)
	for quadrant_index in 4:
		add_roads_stage(context, quadrant_index)
	add_content_stage(context)
	finish_sector(context)
	return context["sector"]


static func _add_floor(sector: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(SECTOR_HALF_SIZE * 2.0, 1.0, SECTOR_HALF_SIZE * 2.0)
	collision.shape = floor_shape
	floor_body.add_child(collision)
	sector.add_child(floor_body)


static func _add_poi_building(
	sector: Node3D,
	rng: RandomNumberGenerator,
	config: Dictionary,
	blocked_areas: Array[Rect2]
) -> void:
	# Roughly half the generated sectors get an explorable building: three solid
	# walls plus a front wall split around a wide doorway. The walls are
	# navigation blockers, so the doorway is the only gap the runtime nav grid
	# leaves open — the player loots the reward inside and enemies chase in
	# through the same opening.
	if rng.randf() >= POI_SPAWN_CHANCE:
		return
	var footprint := Vector3(
		POI_BUILDING_HALF * 2.0, POI_WALL_HEIGHT, POI_BUILDING_HALF * 2.0
	)
	var placement := _find_free_position(rng, footprint, blocked_areas)
	if placement == Vector2.INF:
		return
	var building := Node3D.new()
	building.name = "PointOfInterest"
	sector.add_child(building)
	building.position = Vector3(placement.x, 0.0, placement.y)
	# The square footprint keeps its axis-aligned reservation valid after the
	# quarter-turn, which just points the doorway at a different street.
	building.rotation.y = rng.randi_range(0, 3) * (PI / 2.0)

	var half := POI_BUILDING_HALF
	var height := POI_WALL_HEIGHT
	var thickness := POI_WALL_THICKNESS
	var span := half * 2.0
	var poi_entry: POIEntry
	if not POI_REGISTRY.entries.is_empty():
		poi_entry = POI_REGISTRY.get_entry_at(
			rng.randi_range(0, POI_REGISTRY.entries.size() - 1)
		)
	if poi_entry != null and poi_entry.facade_scene != null:
		var facade := poi_entry.facade_scene.instantiate() as Node3D
		if facade != null:
			facade.name = "Facade"
			building.add_child(facade)

	var floor_patch := MeshInstance3D.new()
	floor_patch.name = "InteriorFloor"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(span - thickness, 0.1, span - thickness)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = POI_FLOOR_COLOR
	floor_material.roughness = 0.95
	floor_mesh.material = floor_material
	floor_patch.mesh = floor_mesh
	building.add_child(floor_patch)
	floor_patch.position = Vector3(0.0, 0.05, 0.0)

	var marker := Marker3D.new()
	marker.name = "PoiMarker"
	marker.add_to_group(&"point_of_interest")
	building.add_child(marker)

	var label := Label3D.new()
	label.name = "PoiLabel"
	label.text = (
		poi_entry.display_name
		if poi_entry != null
		else POI_NAMES[rng.randi_range(0, POI_NAMES.size() - 1)]
	)
	label.font_size = 24
	label.outline_size = 8
	label.modulate = POI_LABEL_COLOR
	label.outline_modulate = Color(0.04, 0.02, 0.01, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, height + 1.2, 0.0)
	building.add_child(label)

	_add_poi_loot(building, config)

	blocked_areas.append(
		Rect2(placement - Vector2(half, half), Vector2(span, span))
	)


static func _add_poi_wall(
	building: Node3D,
	wall_name: String,
	local_position: Vector3,
	size: Vector3,
	material: StandardMaterial3D
) -> void:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.add_to_group(&"navigation_blocker")
	building.add_child(wall)
	wall.position = local_position
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	wall.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	wall.add_child(collision)


static func _add_poi_loot(building: Node3D, config: Dictionary) -> void:
	var collected_caches: Array = config.get("collected_caches", [])
	if POI_CACHE_INDEX in collected_caches:
		return
	var cache := SCRAP_PICKUP_SCENE.instantiate() as Area3D
	cache.name = "PoiCache"
	cache.set(&"scrap_amount", POI_REWARD_SCRAP)
	building.add_child(cache)
	cache.position = Vector3(0.0, 0.25, 0.0)
	var cache_callable: Callable = config.get("cache_collected_callable", Callable())
	if cache_callable.is_valid():
		cache.connect(
			&"collected",
			cache_callable.bind(StringName(config["id"]), POI_CACHE_INDEX)
		)


static func _add_city_buildings(
	sector: Node3D, rng: RandomNumberGenerator, blocked_areas: Array[Rect2]
) -> Array[Dictionary]:
	var building_infos: Array[Dictionary] = []
	var buildings_root := Node3D.new()
	buildings_root.name = "Buildings"
	sector.add_child(buildings_root)
	# Buildings belong to city blocks only, never to the streets, so they can no
	# longer end up standing on road markings or crosswalks.
	var building_index := -1
	for block_index in 4:
		var block_center := _get_block_center(block_index)
		var buildings_in_block := 1 + rng.randi_range(0, 1)
		for slot in buildings_in_block:
			building_index += 1
			var choice: Dictionary = CITY_BUILDINGS[
				rng.randi_range(0, CITY_BUILDINGS.size() - 1)
			]
			var footprint: Vector2 = choice["footprint"]
			var height := float(choice["height"])
			var quarter := rng.randi_range(0, 3)
			# A quarter turn swaps the footprint's axis-aligned bounds, so
			# reserve the rotated extents while the collision box stays local
			# (arena_navigation handles the rotated blocker).
			var reserved := (
				footprint if quarter % 2 == 0 else Vector2(footprint.y, footprint.x)
			)
			var placement := _find_free_position_in_block(
				rng, reserved, blocked_areas, block_center
			)
			if placement == Vector2.INF:
				continue
			var building_info := _spawn_city_building(
				buildings_root,
				choice,
				placement,
				quarter,
				reserved,
				height,
				building_index,
				blocked_areas
			)
			if not building_info.is_empty():
				building_infos.append(building_info)
	return building_infos


static func _find_free_position_in_block(
	rng: RandomNumberGenerator,
	size: Vector2,
	blocked_areas: Array[Rect2],
	block_center: Vector2
) -> Vector2:
	var limit := BLOCK_HALF - BLOCK_BUILDING_MARGIN
	var half := size * 0.5
	if half.x > limit or half.y > limit:
		return Vector2.INF
	for attempt in 16:
		var candidate := block_center + Vector2(
			rng.randf_range(-(limit - half.x), limit - half.x),
			rng.randf_range(-(limit - half.y), limit - half.y)
		)
		var candidate_area := Rect2(
			candidate - half - Vector2(1.5, 1.5), size + Vector2(3.0, 3.0)
		)
		var overlaps := false
		for blocked_area in blocked_areas:
			if candidate_area.intersects(blocked_area):
				overlaps = true
				break
		if not overlaps:
			return candidate
	return Vector2.INF


static func _spawn_city_building(
	buildings_root: Node3D,
	choice: Dictionary,
	placement: Vector2,
	quarter: int,
	reserved: Vector2,
	height: float,
	building_index: int,
	blocked_areas: Array[Rect2]
) -> Dictionary:
	var footprint: Vector2 = choice["footprint"]
	var building := StaticBody3D.new()
	building.name = "Building%d" % building_index
	building.add_to_group(&"navigation_blocker")
	building.position = Vector3(placement.x, 0.0, placement.y)
	building.rotation.y = quarter * (PI / 2.0)
	var visual := (choice["scene"] as PackedScene).instantiate() as Node3D
	visual.name = "Visual"
	building.add_child(visual)
	# The Quaternius meshes are not centred on their origin; shifting the
	# visual by -center puts the footprint centre on the body origin so the
	# collision box and the reserved area line up with what you see.
	var center: Vector2 = choice.get("center", Vector2.ZERO)
	visual.position = Vector3(-center.x, 0.0, -center.y)
	# A paved lot under the footprint separates the building from the block
	# sidewalk, so it reads as standing on its own plot.
	var lot := MeshInstance3D.new()
	lot.name = "Lot"
	var lot_mesh := BoxMesh.new()
	lot_mesh.size = Vector3(
		footprint.x + CITY_LOT_MARGIN, 0.12, footprint.y + CITY_LOT_MARGIN
	)
	var lot_material := StandardMaterial3D.new()
	lot_material.albedo_color = CITY_LOT_COLOR
	lot_material.roughness = 0.95
	lot_mesh.material = lot_material
	lot.mesh = lot_mesh
	lot.position = Vector3(0.0, 0.07, 0.0)
	building.add_child(lot)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.position = Vector3(0.0, height * 0.5, 0.0)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(footprint.x, height, footprint.y)
	collision.shape = box_shape
	building.add_child(collision)
	buildings_root.add_child(building)
	# Reserve the lot footprint so other buildings/props keep their distance.
	var lot_reserved := reserved + Vector2(CITY_LOT_MARGIN, CITY_LOT_MARGIN)
	blocked_areas.append(Rect2(placement - lot_reserved * 0.5, lot_reserved))
	return {
		"node": building,
		"footprint": footprint,
		"height": height,
	}


static func _add_city_props(
	sector: Node3D,
	rng: RandomNumberGenerator,
	blocked_areas: Array[Rect2],
	building_infos: Array[Dictionary],
	sector_seed: int
) -> void:
	var props_root := Node3D.new()
	props_root.name = "CityProps"
	sector.add_child(props_root)
	var collidable_count := 0
	var visual_count := 0
	var collidable_limit := PROP_PLACEMENT_RULES.maximum_collidable_props
	var visual_limit := PROP_PLACEMENT_RULES.maximum_visual_props

	# Planters are solid, so they block navigation like the buildings.
	var planter_count := rng.randi_range(1, 3)
	for planter_index in planter_count:
		if collidable_count >= collidable_limit:
			break
		var placement := _find_free_position(
			rng, Vector3(2.0, 1.0, 2.0), blocked_areas
		)
		if placement == Vector2.INF:
			continue
		var planter := StaticBody3D.new()
		planter.name = "Planter%d" % planter_index
		planter.add_to_group(&"navigation_blocker")
		planter.position = Vector3(placement.x, 0.0, placement.y)
		var visual := CITY_PLANTER_SCENE.instantiate() as Node3D
		visual.name = "Visual"
		planter.add_child(visual)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		collision.position = Vector3(0.0, 0.3, 0.0)
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(2.0, 0.6, 2.0)
		collision.shape = box_shape
		planter.add_child(collision)
		props_root.add_child(planter)
		blocked_areas.append(Rect2(placement - Vector2(1.0, 1.0), Vector2(2.0, 2.0)))
		collidable_count += 1

	# Bollards and manhole covers are pure decoration: thin/flat, no collision
	# and no reservation, so they never affect navigation or spawns.
	for bollard_index in rng.randi_range(0, 5):
		if visual_count >= visual_limit:
			break
		var placement := _find_free_position(
			rng, Vector3(1.0, 1.0, 1.0), blocked_areas
		)
		if placement == Vector2.INF:
			continue
		var bollard := CITY_BOLLARD_SCENE.instantiate() as Node3D
		bollard.name = "Bollard%d" % bollard_index
		props_root.add_child(bollard)
		bollard.position = Vector3(placement.x, 0.0, placement.y)
		visual_count += 1
	for manhole_index in rng.randi_range(0, 2):
		if visual_count >= visual_limit:
			break
		var manhole := CITY_MANHOLE_SCENE.instantiate() as Node3D
		manhole.name = "Manhole%d" % manhole_index
		props_root.add_child(manhole)
		manhole.position = Vector3(
			rng.randf_range(-24.0, 24.0), 0.02, rng.randf_range(-24.0, 24.0)
		)
		manhole.rotation.y = rng.randf() * TAU
		visual_count += 1

	# Extra facade and ground dressing use a dedicated seed offset, keeping the
	# established building/loot layout stable while increasing visual density.
	var prop_rng := RandomNumberGenerator.new()
	prop_rng.seed = sector_seed + 999
	for building_info in building_infos:
		var building: Node3D = building_info["node"]
		var footprint: Vector2 = building_info["footprint"]
		var height := float(building_info["height"])
		if (
			collidable_count < collidable_limit
			and prop_rng.randf() < PROP_PLACEMENT_RULES.ac_unit_chance_per_building
		):
			var ac_unit := CITY_AC_UNIT_SCENE.instantiate() as Node3D
			if ac_unit != null:
				ac_unit.name = "RoofAC"
				building.add_child(ac_unit)
				ac_unit.position = Vector3(
					prop_rng.randf_range(-footprint.x * 0.22, footprint.x * 0.22),
					height,
					prop_rng.randf_range(-footprint.y * 0.22, footprint.y * 0.22)
				)
				collidable_count += 1
		if (
			collidable_count < collidable_limit
			and prop_rng.randf() < PROP_PLACEMENT_RULES.drain_chance_per_building
		):
			var drain := CITY_DRAIN_PIPE_SCENE.instantiate() as Node3D
			if drain != null:
				drain.name = "FacadeDrain"
				building.add_child(drain)
				drain.position = Vector3(
					prop_rng.randf_range(-footprint.x * 0.35, footprint.x * 0.35),
					0.0,
					footprint.y * 0.5 + 0.2
				)
				collidable_count += 1

	var car_count := prop_rng.randi_range(
		PROP_PLACEMENT_RULES.abandoned_car_minimum,
		PROP_PLACEMENT_RULES.abandoned_car_maximum
	)
	for car_index in car_count:
		if collidable_count >= collidable_limit:
			break
		var quarter_turn := prop_rng.randi_range(0, 3)
		var reserved_size := (
			Vector2(6.4, 3.2) if quarter_turn % 2 == 1 else Vector2(3.2, 6.4)
		)
		var car_size := Vector3(reserved_size.x, 2.3, reserved_size.y)
		var placement := _find_free_position(prop_rng, car_size, blocked_areas)
		if placement == Vector2.INF:
			continue
		var car := ABANDONED_CAR_SCENE.instantiate() as Node3D
		if car == null:
			continue
		car.name = "AbandonedCar%d" % car_index
		props_root.add_child(car)
		car.position = Vector3(placement.x, 0.0, placement.y)
		car.rotation.y = quarter_turn * (PI / 2.0)
		blocked_areas.append(Rect2(placement - reserved_size * 0.5, reserved_size))
		collidable_count += 1

	var trash_count := prop_rng.randi_range(
		PROP_PLACEMENT_RULES.trash_pile_minimum,
		PROP_PLACEMENT_RULES.trash_pile_maximum
	)
	for trash_index in trash_count:
		if visual_count >= visual_limit:
			break
		var placement := _find_free_position(
			prop_rng, Vector3(1.4, 0.8, 1.4), blocked_areas
		)
		if placement == Vector2.INF:
			continue
		var trash := TRASH_PILE_SCENE.instantiate() as Node3D
		if trash == null:
			continue
		trash.name = "TrashPile%d" % trash_index
		props_root.add_child(trash)
		trash.position = Vector3(placement.x, 0.02, placement.y)
		trash.rotation.y = prop_rng.randf() * TAU
		visual_count += 1


static func _add_landmarks(
	sector: Node3D, rng: RandomNumberGenerator, blocked_areas: Array[Rect2]
) -> void:
	var landmarks_root := Node3D.new()
	landmarks_root.name = "Landmarks"
	sector.add_child(landmarks_root)
	var landmark_count := 2 + rng.randi_range(0, 1)
	for landmark_index in landmark_count:
		var size: Vector3 = LANDMARK_VARIANTS[
			rng.randi_range(0, LANDMARK_VARIANTS.size() - 1)
		]
		var placement := _find_free_position(rng, size, blocked_areas)
		if placement == Vector2.INF:
			continue
		var landmark := StaticBody3D.new()
		landmark.name = "Landmark%d" % landmark_index
		landmark.add_to_group(&"navigation_blocker")
		landmark.position = Vector3(placement.x, size.y * 0.5, placement.y)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		var material := StandardMaterial3D.new()
		material.albedo_color = LANDMARK_COLORS[
			rng.randi_range(0, LANDMARK_COLORS.size() - 1)
		]
		material.roughness = 0.85
		box_mesh.material = material
		mesh_instance.mesh = box_mesh
		landmark.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision.shape = box_shape
		landmark.add_child(collision)
		landmarks_root.add_child(landmark)
		blocked_areas.append(
			Rect2(
				placement - Vector2(size.x, size.z) * 0.5,
				Vector2(size.x, size.z)
			)
		)


static func _add_containers(
	sector: Node3D, rng: RandomNumberGenerator, blocked_areas: Array[Rect2]
) -> void:
	var container_count := rng.randi_range(0, 2)
	for container_index in container_count:
		var placement := _find_free_position(
			rng, Vector3(6.0, 3.0, 3.0), blocked_areas
		)
		if placement == Vector2.INF:
			continue
		var container_scene: PackedScene = CONTAINER_SCENES[
			rng.randi_range(0, CONTAINER_SCENES.size() - 1)
		]
		var container := container_scene.instantiate() as Node3D
		container.name = "Container%d" % container_index
		sector.add_child(container)
		container.position = Vector3(placement.x, 0.0, placement.y)
		container.rotation.y = rng.randi_range(0, 3) * (PI / 2.0)


static func _add_set_dressing(
	sector: Node3D, rng: RandomNumberGenerator, blocked_areas: Array[Rect2]
) -> void:
	# Larger CC0 props give each block a recognisable silhouette. Water tower
	# and truck get collision blockers; street lights are decoration only.
	if rng.randf() < 0.35:
		_add_prop_with_blocker(
			sector,
			rng,
			WATER_TOWER_SCENE,
			"WaterTower",
			Vector3(4.0, 12.0, 4.0),
			blocked_areas
		)
	if rng.randf() < 0.45:
		_add_prop_with_blocker(
			sector,
			rng,
			TRUCK_SCENE,
			"WreckedTruck",
			Vector3(3.4, 3.0, 8.0),
			blocked_areas
		)
	for corner_index in 4:
		var corner := Vector2(
			12.0 if corner_index % 2 == 0 else -12.0,
			12.0 if corner_index / 2 == 0 else -12.0
		)
		var street_light := STREET_LIGHT_SCENE.instantiate() as Node3D
		street_light.name = "StreetLight%d" % corner_index
		sector.add_child(street_light)
		street_light.position = Vector3(corner.x, 0.0, corner.y)
		street_light.rotation.y = corner_index * (PI / 2.0)


static func _add_prop_with_blocker(
	sector: Node3D,
	rng: RandomNumberGenerator,
	prop_scene: PackedScene,
	prop_name: String,
	blocker_size: Vector3,
	blocked_areas: Array[Rect2]
) -> void:
	var placement := _find_free_position(rng, blocker_size, blocked_areas)
	if placement == Vector2.INF:
		return
	var prop_body := StaticBody3D.new()
	prop_body.name = prop_name
	prop_body.add_to_group(&"navigation_blocker")
	prop_body.position = Vector3(placement.x, 0.0, placement.y)
	prop_body.rotation.y = rng.randi_range(0, 3) * (PI / 2.0)
	var visual := prop_scene.instantiate() as Node3D
	visual.name = "Visual"
	prop_body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.position = Vector3(0.0, blocker_size.y * 0.5, 0.0)
	var box_shape := BoxShape3D.new()
	box_shape.size = blocker_size
	collision.shape = box_shape
	prop_body.add_child(collision)
	sector.add_child(prop_body)
	blocked_areas.append(
		Rect2(
			placement - Vector2(blocker_size.x, blocker_size.z) * 0.5,
			Vector2(blocker_size.x, blocker_size.z)
		)
	)


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


static func _add_weapon_crate(
	sector: Node3D,
	rng: RandomNumberGenerator,
	config: Dictionary,
	blocked_areas: Array[Rect2]
) -> void:
	# Roughly one in three sectors offers a weapon to find while exploring.
	# The choice is seeded so the same sector always holds the same weapon.
	var weapon_choice: Dictionary = WEAPON_POOL[rng.randi_range(0, WEAPON_POOL.size() - 1)]
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


static func _add_navigation(sector: Node3D) -> void:
	var navigation_region := NavigationRegion3D.new()
	navigation_region.name = "NavigationRegion3D"
	navigation_region.set_script(NAVIGATION_SCRIPT)
	navigation_region.set(&"navigation_half_extent", SECTOR_HALF_SIZE)
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
		# Keep the central crossroads corridor free for circulation.
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
