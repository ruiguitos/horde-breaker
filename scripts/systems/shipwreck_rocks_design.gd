class_name ShipwreckRocksDesign
extends RefCounted

## One 256 m Terrain3D region containing two deliberately different landforms:
## a broad departure shore and the smaller, asymmetric Shipwreck Rocks island.

const TERRAIN_SIZE := 256
const TERRAIN_HALF_SIZE := TERRAIN_SIZE * 0.5
const TERRAIN_REGION_SIZE := 256
const TERRAIN_CENTER := Vector2(128.0, 128.0)
const WATER_HEIGHT := -3.0
const SEABED_HEIGHT := -6.0
const PLAYER_FLOOR_OFFSET := 1.05

const HOME_CENTER := Vector2(55.0, 128.0)
const HOME_RADII := Vector2(50.0, 58.0)
const ISLAND_CENTER := Vector2(181.0, 130.0)
const ISLAND_RADII := Vector2(37.0, 29.0)

const HOME_PLAYER_POSITION := Vector3(59.0, 0.0, 128.0)
const HOME_TERMINAL_POSITION := Vector3(97.0, 0.0, 128.0)
const ISLAND_TERMINAL_POSITION := Vector3(150.0, 0.0, 129.0)
const HOME_FERRY_POSITION := Vector3(107.0, -2.05, 128.0)
const ISLAND_FERRY_POSITION := Vector3(140.0, -2.05, 129.0)
const HOME_DISEMBARK_POSITION := Vector3(94.0, 0.0, 128.0)
const ISLAND_DISEMBARK_POSITION := Vector3(153.0, 0.0, 129.0)
const SALVAGE_POSITION := Vector3(186.0, 0.0, 124.0)


static func create_height_map() -> Image:
	var height_map := Image.create_empty(
		TERRAIN_SIZE, TERRAIN_SIZE, false, Image.FORMAT_RF
	)
	for image_z in range(TERRAIN_SIZE):
		var world_z := float(image_z)
		for image_x in range(TERRAIN_SIZE):
			var world_x := float(image_x)
			height_map.set_pixel(
				image_x,
				image_z,
				Color(height_at(world_x, world_z), 0.0, 0.0, 1.0)
			)
	return height_map


static func height_at(world_x: float, world_z: float) -> float:
	var world_position := Vector2(world_x, world_z)
	var home_height := _island_height(
		world_position, HOME_CENTER, HOME_RADII, 0.35, 1.4
	)
	var shipwreck_height := _island_height(
		world_position, ISLAND_CENTER, ISLAND_RADII, 1.75, 1.0
	)
	var height := maxf(home_height, shipwreck_height)

	# A raised spine and two rock mounds make the small island readable from the
	# departure dock without making its landing point too steep.
	var ridge := 2.8 * exp(
		-(world_position - Vector2(189.0, 132.0)).length_squared() / 240.0
	)
	var north_rock := 1.7 * exp(
		-(world_position - Vector2(177.0, 116.0)).length_squared() / 85.0
	)
	var island_weight := _land_weight(
		world_position, ISLAND_CENTER, ISLAND_RADII, 1.75
	)
	return height + (ridge + north_rock) * island_weight


static func is_land(world_position: Vector2) -> bool:
	return height_at(world_position.x, world_position.y) > WATER_HEIGHT + 0.15


static func position_on_land(horizontal_position: Vector3) -> Vector3:
	return Vector3(
		horizontal_position.x,
		height_at(horizontal_position.x, horizontal_position.z),
		horizontal_position.z
	)


static func player_position_on_land(horizontal_position: Vector3) -> Vector3:
	return position_on_land(horizontal_position) + Vector3.UP * PLAYER_FLOOR_OFFSET


static func _island_height(
	world_position: Vector2,
	center: Vector2,
	radii: Vector2,
	phase: float,
	plateau_height: float
) -> float:
	var weight := _land_weight(world_position, center, radii, phase)
	var local := world_position - center
	var relief := (
		sin(local.x * 0.09 + phase) * 0.38
		+ cos(local.y * 0.11 - phase) * 0.28
	)
	return lerpf(SEABED_HEIGHT, plateau_height + relief, weight)


static func _land_weight(
	world_position: Vector2,
	center: Vector2,
	radii: Vector2,
	phase: float
) -> float:
	var local := world_position - center
	var angle := atan2(local.y, local.x)
	var irregularity := (
		1.0
		+ sin(angle * 3.0 + phase) * 0.11
		+ cos(angle * 5.0 - phase * 0.7) * 0.06
	)
	var normalized_distance := Vector2(
		local.x / radii.x, local.y / radii.y
	).length() / irregularity
	return 1.0 - smoothstep(0.72, 1.06, normalized_distance)
