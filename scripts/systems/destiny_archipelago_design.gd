class_name DestinyArchipelagoDesign
extends RefCounted

const TERRAIN_SIZE := 512
const TERRAIN_REGION_SIZE := 256
const EXPECTED_REGION_COUNT := 4
const WATER_HEIGHT := -3.0
const SEABED_HEIGHT := -6.0
const PLAYER_FLOOR_OFFSET := 1.05

const DAWN_CENTER := Vector2(120.0, 390.0)
const DAWN_RADII := Vector2(70.0, 60.0)
const FOREST_CENTER := Vector2(120.0, 135.0)
const FOREST_RADII := Vector2(70.0, 65.0)
const CLIFFS_CENTER := Vector2(385.0, 390.0)
const CLIFFS_RADII := Vector2(65.0, 70.0)
const VOLCANO_CENTER := Vector2(385.0, 130.0)
const VOLCANO_RADII := Vector2(75.0, 65.0)

const PLAYER_START := Vector3(120.0, 0.0, 405.0)
const DAWN_SAFE := Vector3(120.0, 0.0, 375.0)
const FOREST_SAFE := Vector3(120.0, 0.0, 158.0)
const CLIFFS_SAFE := Vector3(365.0, 0.0, 390.0)
const VOLCANO_SAFE := Vector3(350.0, 0.0, 145.0)
const CAVE_ENTRY := Vector3(176.0, 0.0, 390.0)
const CAVE_EXIT := Vector3(329.0, 0.0, 390.0)
const BRIDGE_START := Vector3(190.0, 0.0, 135.0)
const BRIDGE_END := Vector3(310.0, 0.0, 135.0)
const RUINS_START := Vector3(385.0, 0.0, 315.0)
const RUINS_END := Vector3(385.0, 0.0, 200.0)

const ISLAND_LAYOUT := {
	&"dawn_beach": {"center": DAWN_CENTER, "radii": DAWN_RADII},
	&"shadow_forest": {"center": FOREST_CENTER, "radii": FOREST_RADII},
	&"high_cliffs": {"center": CLIFFS_CENTER, "radii": CLIFFS_RADII},
	&"volcano_peak": {"center": VOLCANO_CENTER, "radii": VOLCANO_RADII},
}


static func create_height_map() -> Image:
	var height_map := Image.create_empty(
		TERRAIN_SIZE, TERRAIN_SIZE, false, Image.FORMAT_RF
	)
	for image_z in range(TERRAIN_SIZE):
		for image_x in range(TERRAIN_SIZE):
			height_map.set_pixel(
				image_x,
				image_z,
				Color(height_at(float(image_x), float(image_z)), 0.0, 0.0, 1.0)
			)
	return height_map


static func height_at(world_x: float, world_z: float) -> float:
	var point := Vector2(world_x, world_z)
	var dawn_weight := _island_weight(point, DAWN_CENTER, DAWN_RADII, 0.4)
	var forest_weight := _island_weight(point, FOREST_CENTER, FOREST_RADII, 1.7)
	var cliffs_weight := _island_weight(point, CLIFFS_CENTER, CLIFFS_RADII, 2.4)
	var volcano_weight := _island_weight(point, VOLCANO_CENTER, VOLCANO_RADII, 3.1)
	var height := maxf(
		_island_height(point, DAWN_CENTER, DAWN_RADII, 0.4, 0.9),
		_island_height(point, FOREST_CENTER, FOREST_RADII, 1.7, 1.25)
	)
	height = maxf(
		height, _island_height(point, CLIFFS_CENTER, CLIFFS_RADII, 2.4, 3.8)
	)
	height = maxf(
		height, _island_height(point, VOLCANO_CENTER, VOLCANO_RADII, 3.1, 2.2)
	)

	# Route A is deliberately terrain-native so it can later be submerged by a
	# tide system without replacing the island meshes.
	var reef_weight := _segment_weight(
		point, Vector2(120.0, 198.0), Vector2(120.0, 332.0), 8.5
	)
	height = maxf(height, lerpf(SEABED_HEIGHT, -2.05, reef_weight))

	# Shallow pools break up the forest silhouette and let the global water plane
	# create a swamp without extra water draw calls.
	for pool_center in [Vector2(98.0, 128.0), Vector2(137.0, 153.0)]:
		var pool := exp(-(point - pool_center).length_squared() / 145.0)
		height -= pool * 2.0 * forest_weight

	var cliff_ridge := (
		5.8 * exp(-(point - Vector2(403.0, 380.0)).length_squared() / 580.0)
		+ 3.2 * exp(-(point - Vector2(367.0, 365.0)).length_squared() / 360.0)
	)
	height += cliff_ridge * cliffs_weight

	var volcano_distance := point.distance_to(VOLCANO_CENTER)
	var cone := maxf(0.0, 1.0 - volcano_distance / 66.0) * 14.0
	var crater := 5.2 * exp(-(point - VOLCANO_CENTER).length_squared() / 92.0)
	height += (cone - crater) * volcano_weight
	return height


static func position_on_land(horizontal_position: Vector3) -> Vector3:
	return Vector3(
		horizontal_position.x,
		height_at(horizontal_position.x, horizontal_position.z),
		horizontal_position.z
	)


static func player_position_on_land(horizontal_position: Vector3) -> Vector3:
	return position_on_land(horizontal_position) + Vector3.UP * PLAYER_FLOOR_OFFSET


static func get_island_at(world_position: Vector2) -> StringName:
	for island_id: StringName in ISLAND_LAYOUT:
		var layout: Dictionary = ISLAND_LAYOUT[island_id]
		var center: Vector2 = layout["center"]
		var radii: Vector2 = layout["radii"]
		var local := world_position - center
		if Vector2(local.x / radii.x, local.y / radii.y).length() <= 0.9:
			return island_id
	return &""


static func get_safe_position(island_id: StringName) -> Vector3:
	match island_id:
		&"shadow_forest":
			return player_position_on_land(FOREST_SAFE)
		&"high_cliffs":
			return player_position_on_land(CLIFFS_SAFE)
		&"volcano_peak":
			return player_position_on_land(VOLCANO_SAFE)
		_:
			return player_position_on_land(DAWN_SAFE)


static func _island_height(
	point: Vector2,
	center: Vector2,
	radii: Vector2,
	phase: float,
	plateau_height: float
) -> float:
	var weight := _island_weight(point, center, radii, phase)
	var local := point - center
	var relief := sin(local.x * 0.075 + phase) * 0.32
	relief += cos(local.y * 0.082 - phase) * 0.24
	return lerpf(SEABED_HEIGHT, plateau_height + relief, weight)


static func _island_weight(
	point: Vector2, center: Vector2, radii: Vector2, phase: float
) -> float:
	var local := point - center
	var angle := atan2(local.y, local.x)
	var irregularity := (
		1.0
		+ sin(angle * 3.0 + phase) * 0.1
		+ cos(angle * 5.0 - phase) * 0.055
	)
	var distance := Vector2(local.x / radii.x, local.y / radii.y).length()
	return 1.0 - smoothstep(0.72, 1.04, distance / irregularity)


static func _segment_weight(
	point: Vector2, start: Vector2, end: Vector2, radius: float
) -> float:
	var segment := end - start
	var progress := clampf(
		(point - start).dot(segment) / segment.length_squared(), 0.0, 1.0
	)
	var distance := point.distance_to(start + segment * progress)
	return 1.0 - smoothstep(radius * 0.7, radius, distance)
