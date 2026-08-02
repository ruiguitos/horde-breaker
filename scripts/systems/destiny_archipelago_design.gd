class_name DestinyArchipelagoDesign
extends RefCounted

const TERRAIN_SIZE := 512
const TERRAIN_REGION_SIZE := 256
const EXPECTED_REGION_COUNT := 4
const TEXTURE_SIZE := 128
const DESIGN_SEED := 7312026
const WATER_HEIGHT := -3.0
const SEABED_HEIGHT := -6.0
const PLAYER_FLOOR_OFFSET := 1.05

const SURFACE_SAND := 0
const SURFACE_COASTAL_GRASS := 1
const SURFACE_SWAMP_MUD := 2
const SURFACE_SWAMP_MOSS := 3
const SURFACE_CLIFF_STONE := 4
const SURFACE_CLIFF_LICHEN := 5
const SURFACE_VOLCANIC_ASH := 6
const SURFACE_OBSIDIAN := 7

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


static func create_control_map() -> Image:
	var control_map := Image.create_empty(
		TERRAIN_SIZE, TERRAIN_SIZE, false, Image.FORMAT_RF
	)
	for image_z in range(TERRAIN_SIZE):
		for image_x in range(TERRAIN_SIZE):
			var surface := get_surface_pair_at(float(image_x), float(image_z))
			var bits := (
				Terrain3DUtil.enc_base(surface.x)
				| Terrain3DUtil.enc_overlay(surface.y)
				| Terrain3DUtil.enc_blend(surface.z)
			)
			control_map.set_pixel(
				image_x,
				image_z,
				Color(Terrain3DUtil.as_float(bits), 0.0, 0.0, 1.0)
			)
	return control_map


static func create_surface_images(
	asset_name: String,
	dark_color: Color,
	light_color: Color,
	roughness: float
) -> Array[Image]:
	var albedo_image := Image.create_empty(
		TEXTURE_SIZE, TEXTURE_SIZE, true, Image.FORMAT_RGBA8
	)
	var normal_image := Image.create_empty(
		TEXTURE_SIZE, TEXTURE_SIZE, true, Image.FORMAT_RGBA8
	)
	var noise := FastNoiseLite.new()
	noise.seed = DESIGN_SEED + asset_name.hash()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.052
	noise.fractal_octaves = 4
	for image_y in range(TEXTURE_SIZE):
		for image_x in range(TEXTURE_SIZE):
			var value := remap(
				noise.get_noise_2d(float(image_x), float(image_y)),
				-1.0,
				1.0,
				0.0,
				1.0
			)
			var albedo := dark_color.lerp(light_color, value)
			albedo.a = value
			albedo_image.set_pixel(image_x, image_y, albedo)
			normal_image.set_pixel(
				image_x,
				image_y,
				Color(0.5, 0.5, 1.0, roughness)
			)
	albedo_image.generate_mipmaps()
	normal_image.generate_mipmaps()
	return [albedo_image, normal_image]


static func height_at(world_x: float, world_z: float) -> float:
	var point := Vector2(world_x, world_z)
	var dawn_weight := _dawn_weight(point)
	var forest_weight := _forest_weight(point)
	var cliffs_weight := _cliffs_weight(point)
	var volcano_weight := _volcano_weight(point)
	var height := maxf(
		_island_height(point, DAWN_CENTER, dawn_weight, 0.4, 0.75),
		_island_height(point, FOREST_CENTER, forest_weight, 1.7, 1.1)
	)
	height = maxf(
		height, _island_height(point, CLIFFS_CENTER, cliffs_weight, 2.4, 4.8)
	)
	height = maxf(
		height, _island_height(point, VOLCANO_CENTER, volcano_weight, 3.1, 1.8)
	)

	# Route A is deliberately terrain-native so it can later be submerged by a
	# tide system without replacing the island meshes.
	var reef_weight := _segment_weight(
		point, Vector2(120.0, 198.0), Vector2(120.0, 332.0), 8.5
	)
	height = maxf(height, lerpf(SEABED_HEIGHT, -2.05, reef_weight))

	# Dawn Beach is a crescent with a real lagoon cut into its western half.
	var lagoon := exp(-(point - Vector2(88.0, 404.0)).length_squared() / 320.0)
	height -= lagoon * 5.2 * dawn_weight

	# Pools and channels give Shadow Forest a low, broken swamp silhouette.
	for pool_center in [Vector2(98.0, 128.0), Vector2(137.0, 153.0)]:
		var pool := exp(-(point - pool_center).length_squared() / 145.0)
		height -= pool * 2.8 * forest_weight
	var forest_channel := _segment_weight(
		point, Vector2(84.0, 155.0), Vector2(151.0, 113.0), 7.0
	)
	height -= forest_channel * 1.5 * forest_weight

	# High Cliffs is a stepped mesa rather than another rounded green island.
	var cliff_ridge := (
		8.6 * exp(-(point - Vector2(408.0, 378.0)).length_squared() / 520.0)
		+ 5.0 * exp(-(point - Vector2(372.0, 365.0)).length_squared() / 330.0)
	)
	height += cliff_ridge * cliffs_weight
	var cliff_terrace := smoothstep(0.42, 0.7, cliffs_weight) * 1.6
	height += floor(cliff_terrace * 2.0) * 0.65

	var volcano_distance := point.distance_to(VOLCANO_CENTER)
	var cone := maxf(0.0, 1.0 - volcano_distance / 68.0) * 21.0
	var crater := 8.5 * exp(-(point - VOLCANO_CENTER).length_squared() / 150.0)
	var radial_ridges := (
		0.8 + sin(atan2(point.y - VOLCANO_CENTER.y, point.x - VOLCANO_CENTER.x) * 5.0) * 0.2
	)
	height += (cone * radial_ridges - crater) * volcano_weight
	return height


static func get_surface_pair_at(world_x: float, world_z: float) -> Vector3i:
	var point := Vector2(world_x, world_z)
	var weights := [
		_dawn_weight(point),
		_forest_weight(point),
		_cliffs_weight(point),
		_volcano_weight(point),
	]
	var selected_index := 0
	for index in range(1, weights.size()):
		if weights[index] > weights[selected_index]:
			selected_index = index
	if float(weights[selected_index]) < 0.08:
		return Vector3i(SURFACE_SAND, SURFACE_SAND, 0)
	var height := height_at(world_x, world_z)
	match selected_index:
		0:
			var inland := smoothstep(WATER_HEIGHT + 0.25, WATER_HEIGHT + 3.2, height)
			return Vector3i(
				SURFACE_SAND, SURFACE_COASTAL_GRASS, roundi(inland * 255.0)
			)
		1:
			var moss := 0.58 + sin(world_x * 0.12) * cos(world_z * 0.1) * 0.22
			moss *= smoothstep(WATER_HEIGHT + 0.3, WATER_HEIGHT + 3.0, height)
			return Vector3i(
				SURFACE_SWAMP_MUD,
				SURFACE_SWAMP_MOSS,
				clampi(roundi(moss * 255.0), 0, 255)
			)
		2:
			var lichen := 0.22 + sin(world_x * 0.075 + world_z * 0.04) * 0.14
			return Vector3i(
				SURFACE_CLIFF_STONE,
				SURFACE_CLIFF_LICHEN,
				clampi(roundi(lichen * 255.0), 0, 255)
			)
		_:
			var obsidian := 0.5 + sin(world_x * 0.16) * cos(world_z * 0.13) * 0.3
			return Vector3i(
				SURFACE_VOLCANIC_ASH,
				SURFACE_OBSIDIAN,
				clampi(roundi(obsidian * 255.0), 0, 255)
			)


static func position_on_land(horizontal_position: Vector3) -> Vector3:
	return Vector3(
		horizontal_position.x,
		height_at(horizontal_position.x, horizontal_position.z),
		horizontal_position.z
	)


static func player_position_on_land(horizontal_position: Vector3) -> Vector3:
	return position_on_land(horizontal_position) + Vector3.UP * PLAYER_FLOOR_OFFSET


static func get_island_at(world_position: Vector2) -> StringName:
	if _dawn_weight(world_position) >= 0.48:
		return &"dawn_beach"
	if _forest_weight(world_position) >= 0.48:
		return &"shadow_forest"
	if _cliffs_weight(world_position) >= 0.48:
		return &"high_cliffs"
	if _volcano_weight(world_position) >= 0.48:
		return &"volcano_peak"
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
	weight: float,
	phase: float,
	plateau_height: float
) -> float:
	var local := point - center
	var relief := sin(local.x * 0.075 + phase) * 0.32
	relief += cos(local.y * 0.082 - phase) * 0.24
	return lerpf(SEABED_HEIGHT, plateau_height + relief, weight)


static func _dawn_weight(point: Vector2) -> float:
	var beach := _island_weight(point, DAWN_CENTER, DAWN_RADII, 0.4)
	var north_spit := _island_weight(
		point, Vector2(120.0, 348.0), Vector2(24.0, 31.0), 0.9
	)
	return maxf(beach, north_spit)


static func _forest_weight(point: Vector2) -> float:
	var west_lobe := _island_weight(
		point, Vector2(98.0, 136.0), Vector2(50.0, 58.0), 1.1
	)
	var east_lobe := _island_weight(
		point, Vector2(145.0, 132.0), Vector2(53.0, 48.0), 2.2
	)
	var south_lobe := _island_weight(
		point, Vector2(120.0, 171.0), Vector2(43.0, 36.0), 0.6
	)
	return maxf(maxf(west_lobe, east_lobe), south_lobe)


static func _cliffs_weight(point: Vector2) -> float:
	var mesa := _island_weight(point, CLIFFS_CENTER, Vector2(58.0, 72.0), 2.4)
	var cave_headland := _island_weight(
		point, Vector2(344.0, 390.0), Vector2(35.0, 31.0), 1.3
	)
	var ruins_headland := _island_weight(
		point, Vector2(385.0, 337.0), Vector2(32.0, 39.0), 2.9
	)
	return maxf(maxf(mesa, cave_headland), ruins_headland)


static func _volcano_weight(point: Vector2) -> float:
	return _island_weight(point, VOLCANO_CENTER, VOLCANO_RADII, 3.1, 0.17)


static func _island_weight(
	point: Vector2,
	center: Vector2,
	radii: Vector2,
	phase: float,
	irregularity_strength: float = 0.1
) -> float:
	var local := point - center
	var angle := atan2(local.y, local.x)
	var irregularity := (
		1.0
		+ sin(angle * 3.0 + phase) * irregularity_strength
		+ cos(angle * 5.0 - phase) * irregularity_strength * 0.55
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
