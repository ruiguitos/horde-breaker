class_name SectorGenerator
extends RefCounted

## Builds a 64 x 64 m graybox sector procedurally from a deterministic seed.
## Generation is split into stages (shell, road quadrants, content and
## navigation) so the WorldStreamer can spread the cost over several frames.
## Stages must run in order: begin -> roads 0..3 -> content -> finish.

const ROAD_GRID_SCENE := preload("res://scenes/world/city_road_grid.tscn")
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
const CITY_PLANTER_SCENE := preload("res://assets/models/city_test_model/Exports/glTF (Godot)/Prop_Planter_Single.gltf")
const CITY_BOLLARD_SCENE := preload("res://assets/models/city_test_model/Exports/glTF (Godot)/Prop_Bollard.gltf")
const CITY_MANHOLE_SCENE := preload("res://assets/models/city_test_model/Exports/glTF (Godot)/Prop_ManholeCover.gltf")
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
const ROAD_QUADRANTS: Array[Dictionary] = [
	{"position": Vector3(-16.0, 0.0, -16.0), "rotation": 0.0},
	{"position": Vector3(16.0, 0.0, -16.0), "rotation": -PI / 2.0},
	{"position": Vector3(-16.0, 0.0, 16.0), "rotation": PI / 2.0},
	{"position": Vector3(16.0, 0.0, 16.0), "rotation": PI},
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
	var sector: Node3D = context["sector"]
	var rng: RandomNumberGenerator = context["rng"]
	var roads_root := sector.get_node_or_null("Roads") as Node3D
	if roads_root == null:
		# The four quadrant rotations form a proven coherent 64 x 64 layout;
		# a whole-sector quarter turn varies orientation without breaking it.
		roads_root = Node3D.new()
		roads_root.name = "Roads"
		roads_root.rotation.y = rng.randi_range(0, 3) * (PI / 2.0)
		sector.add_child(roads_root)
	if quadrant_index < 0 or quadrant_index >= ROAD_QUADRANTS.size():
		return
	var quadrant: Dictionary = ROAD_QUADRANTS[quadrant_index]
	var road := ROAD_GRID_SCENE.instantiate() as Node3D
	road.name = "RoadQuadrant%d" % quadrant_index
	roads_root.add_child(road)
	road.position = quadrant["position"]
	road.rotation.y = float(quadrant["rotation"])


static func add_content_stage(context: Dictionary) -> void:
	var sector: Node3D = context["sector"]
	var rng: RandomNumberGenerator = context["rng"]
	var config: Dictionary = context["config"]
	var blocked_areas: Array[Rect2] = context["blocked_areas"]
	# Reserve the point of interest first so nothing else lands on its footprint.
	_add_poi_building(sector, rng, config, blocked_areas)
	_add_city_buildings(sector, rng, blocked_areas)
	_add_containers(sector, rng, blocked_areas)
	_add_set_dressing(sector, rng, blocked_areas)
	_add_city_props(sector, rng, blocked_areas)
	_add_caches(sector, rng, config, blocked_areas)
	_add_ammo_box(sector, rng, config, blocked_areas)
	_add_weapon_crate(sector, rng, config, blocked_areas)
	_add_spawn_markers(sector, rng, blocked_areas)


static func finish_sector(context: Dictionary) -> void:
	_add_navigation(context["sector"])


static func build_sector(config: Dictionary) -> Node3D:
	var context := begin_sector(config)
	for quadrant_index in ROAD_QUADRANTS.size():
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

	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = POI_WALL_COLOR
	wall_material.roughness = 0.9

	var half := POI_BUILDING_HALF
	var height := POI_WALL_HEIGHT
	var thickness := POI_WALL_THICKNESS
	var span := half * 2.0
	_add_poi_wall(
		building, "WallNorth", Vector3(0.0, height * 0.5, -half),
		Vector3(span, height, thickness), wall_material
	)
	_add_poi_wall(
		building, "WallEast", Vector3(half, height * 0.5, 0.0),
		Vector3(thickness, height, span), wall_material
	)
	_add_poi_wall(
		building, "WallWest", Vector3(-half, height * 0.5, 0.0),
		Vector3(thickness, height, span), wall_material
	)
	var segment_length := (span - POI_DOORWAY_WIDTH) * 0.5
	var segment_offset := POI_DOORWAY_WIDTH * 0.5 + segment_length * 0.5
	_add_poi_wall(
		building, "WallFrontLeft", Vector3(-segment_offset, height * 0.5, half),
		Vector3(segment_length, height, thickness), wall_material
	)
	_add_poi_wall(
		building, "WallFrontRight", Vector3(segment_offset, height * 0.5, half),
		Vector3(segment_length, height, thickness), wall_material
	)

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
	label.text = POI_NAMES[rng.randi_range(0, POI_NAMES.size() - 1)]
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
) -> void:
	var buildings_root := Node3D.new()
	buildings_root.name = "Buildings"
	sector.add_child(buildings_root)
	var building_count := 2 + rng.randi_range(0, 1)
	for building_index in building_count:
		var choice: Dictionary = CITY_BUILDINGS[
			rng.randi_range(0, CITY_BUILDINGS.size() - 1)
		]
		var footprint: Vector2 = choice["footprint"]
		var height := float(choice["height"])
		var quarter := rng.randi_range(0, 3)
		# A quarter turn swaps the footprint's axis-aligned bounds, so reserve
		# the rotated extents while the collision box stays in local space
		# (arena_navigation handles the rotated blocker).
		var reserved := (
			footprint if quarter % 2 == 0 else Vector2(footprint.y, footprint.x)
		)
		var placement := _find_free_position(
			rng, Vector3(reserved.x, height, reserved.y), blocked_areas
		)
		if placement == Vector2.INF:
			continue
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
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		collision.position = Vector3(0.0, height * 0.5, 0.0)
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(footprint.x, height, footprint.y)
		collision.shape = box_shape
		building.add_child(collision)
		buildings_root.add_child(building)
		blocked_areas.append(Rect2(placement - reserved * 0.5, reserved))


static func _add_city_props(
	sector: Node3D, rng: RandomNumberGenerator, blocked_areas: Array[Rect2]
) -> void:
	var props_root := Node3D.new()
	props_root.name = "CityProps"
	sector.add_child(props_root)
	# Planters are solid, so they block navigation like the buildings.
	var planter_count := rng.randi_range(1, 3)
	for planter_index in planter_count:
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
	# Bollards and manhole covers are pure decoration: thin/flat, no collision
	# and no reservation, so they never affect navigation or spawns.
	for bollard_index in rng.randi_range(0, 5):
		var placement := _find_free_position(
			rng, Vector3(1.0, 1.0, 1.0), blocked_areas
		)
		if placement == Vector2.INF:
			continue
		var bollard := CITY_BOLLARD_SCENE.instantiate() as Node3D
		bollard.name = "Bollard%d" % bollard_index
		props_root.add_child(bollard)
		bollard.position = Vector3(placement.x, 0.0, placement.y)
	for manhole_index in rng.randi_range(0, 2):
		var manhole := CITY_MANHOLE_SCENE.instantiate() as Node3D
		manhole.name = "Manhole%d" % manhole_index
		props_root.add_child(manhole)
		manhole.position = Vector3(
			rng.randf_range(-24.0, 24.0), 0.02, rng.randf_range(-24.0, 24.0)
		)
		manhole.rotation.y = rng.randf() * TAU


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
