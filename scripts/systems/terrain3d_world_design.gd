class_name Terrain3DWorldDesign
extends RefCounted

## Terrain3D stores this 512 m world in a 3 x 3 region square. The extra margin
## keeps every sector inside complete 256 m regions and avoids edge sampling at
## the playable bounds (-224 .. 288 m).
const TERRAIN_SIZE := 768
const TERRAIN_REGION_SIZE := 256
const TERRAIN_ORIGIN := Vector2(-256.0, -256.0)
const EXPECTED_REGION_COUNT := 9

const SECTOR_SIZE := 64.0
const GRID_MIN := Vector2i(-3, -3)
const GRID_MAX := Vector2i(4, 4)
const CAMP_SECTOR := Vector2i(-1, -1)
const NATURAL_SECTOR := Vector2i(-1, -2)
const NATURAL_CENTER := Vector2(
	NATURAL_SECTOR.x * SECTOR_SIZE,
	NATURAL_SECTOR.y * SECTOR_SIZE
)
const SECTOR_HALF_SIZE := SECTOR_SIZE * 0.5

const CAMP_HEIGHT := 0.0
const ISLAND_CENTER := Vector2(32.0, 32.0)
const BASE_ISLAND_RADIUS := 220.0
const WATER_HEIGHT := -3.0
const SEABED_HEIGHT := -6.0
const OUTSIDE_HEIGHT := SEABED_HEIGHT
const MINIMUM_PLAYABLE_HEIGHT := 0.10
const NAVIGATION_MINIMUM_HEIGHT := WATER_HEIGHT + 0.45
const INNER_ROUTE_RADIUS := 104.0
const COAST_ROUTE_INSET := 38.0
const ROUTE_CORE_WIDTH := 4.5
const ROUTE_BLEND_WIDTH := 18.0

const CAMP_POSITION := Vector2(-64.0, -64.0)
const NORTH_CONNECTOR_END := Vector2(-32.0, -66.0)
const EAST_CONNECTOR_START := Vector2(132.0, 42.0)
const EAST_CONNECTOR_END := Vector2(194.0, 34.0)
const SOUTH_CONNECTOR_START := Vector2(54.0, 132.0)
const SOUTH_CONNECTOR_END := Vector2(65.0, 196.0)

static func create_height_map() -> Image:
	var height_map := Image.create_empty(
		TERRAIN_SIZE, TERRAIN_SIZE, false, Image.FORMAT_RF
	)
	for image_z in range(TERRAIN_SIZE):
		var world_z := TERRAIN_ORIGIN.y + float(image_z)
		for image_x in range(TERRAIN_SIZE):
			var world_x := TERRAIN_ORIGIN.x + float(image_x)
			height_map.set_pixel(
				image_x,
				image_z,
				Color(height_at(world_x, world_z), 0.0, 0.0, 1.0)
			)
	return height_map


static func height_at(world_x: float, world_z: float) -> float:
	var coords := sector_at(world_x, world_z)
	if not is_playable_sector(coords):
		return SEABED_HEIGHT
	var world_position := Vector2(world_x, world_z)
	var shaped_height := _rolling_height(world_x, world_z)
	shaped_height += _regional_relief(world_position)
	if coords == NATURAL_SECTOR:
		shaped_height = _natural_height(world_x, world_z, shaped_height)
	var island_local := world_position - ISLAND_CENTER
	var island_angle := atan2(island_local.y, island_local.x)
	var island_radius := _island_radius(island_angle)
	var shore_distance := island_radius - island_local.length()
	var coast_blend := smoothstep(-20.0, 26.0, shore_distance)
	shaped_height = lerpf(SEABED_HEIGHT, shaped_height, coast_blend)
	shaped_height = _apply_routes(world_position, shaped_height)
	# The camp, gates and construction grid need one dependable datum. Blend
	# back into the hills outside the perimeter instead of cutting a hard ledge.
	var camp_center := Vector2(CAMP_SECTOR) * SECTOR_SIZE
	var camp_distance := world_position.distance_to(camp_center)
	var camp_blend := smoothstep(48.0, 70.0, camp_distance)
	return lerpf(CAMP_HEIGHT, shaped_height, camp_blend)


static func trail_center_x(world_z: float) -> float:
	var local_z := world_z - NATURAL_CENTER.y
	return NATURAL_CENTER.x - 4.0 + sin(local_z * 0.12) * 4.2


static func sector_at(world_x: float, world_z: float) -> Vector2i:
	return Vector2i(
		floori((world_x + SECTOR_HALF_SIZE) / SECTOR_SIZE),
		floori((world_z + SECTOR_HALF_SIZE) / SECTOR_SIZE)
	)


static func is_playable_sector(coords: Vector2i) -> bool:
	return (
		coords.x >= GRID_MIN.x and coords.x <= GRID_MAX.x
		and coords.y >= GRID_MIN.y and coords.y <= GRID_MAX.y
	)


static func is_natural_sector(coords: Vector2i) -> bool:
	return coords == NATURAL_SECTOR


static func is_navigation_blocked(world_position: Vector2) -> bool:
	# Water is visual rather than a physics body, so the generated navigation
	# mesh must be clipped at the coast. This keeps zombies on dry land without
	# introducing invisible geometry or a square navigation boundary.
	return height_at(world_position.x, world_position.y) < NAVIGATION_MINIMUM_HEIGHT


static func is_walkable_land(world_position: Vector2) -> bool:
	return not is_navigation_blocked(world_position)


static func coastline_radius_at(angle: float) -> float:
	var direction := Vector2(cos(angle), sin(angle))
	var land_radius := 80.0
	var sea_radius := 300.0
	for _iteration in 18:
		var middle := (land_radius + sea_radius) * 0.5
		var sample := ISLAND_CENTER + direction * middle
		if height_at(sample.x, sample.y) >= WATER_HEIGHT:
			land_radius = middle
		else:
			sea_radius = middle
	return (land_radius + sea_radius) * 0.5


static func coastline_point_at(angle: float, inward_offset: float = 0.0) -> Vector2:
	var direction := Vector2(cos(angle), sin(angle))
	return ISLAND_CENTER + direction * (
		coastline_radius_at(angle) - inward_offset
	)


static func create_coastline_points(segment_count: int = 192) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segment_count:
		points.append(coastline_point_at(TAU * float(index) / float(segment_count)))
	return points


static func create_route_polylines(segment_count: int = 128) -> Array[PackedVector2Array]:
	var inner_route := PackedVector2Array()
	var coast_route := PackedVector2Array()
	for index in range(segment_count + 1):
		var angle := TAU * float(index) / float(segment_count)
		var direction := Vector2(cos(angle), sin(angle))
		inner_route.append(ISLAND_CENTER + direction * INNER_ROUTE_RADIUS)
		coast_route.append(
			ISLAND_CENTER
			+ direction * (_island_radius(angle) - COAST_ROUTE_INSET)
		)
	return [
		inner_route,
		coast_route,
		PackedVector2Array([CAMP_POSITION, NORTH_CONNECTOR_END]),
		PackedVector2Array([EAST_CONNECTOR_START, EAST_CONNECTOR_END]),
		PackedVector2Array([SOUTH_CONNECTOR_START, SOUTH_CONNECTOR_END]),
	]


static func get_landmarks() -> Array[Dictionary]:
	return [
		{"id": &"twin_ridge", "name": "TWIN RIDGE", "position": Vector2(32.0, -112.0)},
		{"id": &"red_plateau", "name": "RED PLATEAU", "position": Vector2(116.0, 44.0)},
		{"id": &"west_rise", "name": "WEST RISE", "position": Vector2(-126.0, 68.0)},
		{"id": &"south_cape", "name": "SOUTH CAPE", "position": Vector2(66.0, 196.0)},
	]


static func _island_radius(angle: float) -> float:
	# Several low-frequency waves avoid a mathematically round shoreline while
	# remaining deterministic and cheap to rebuild.
	return (
		BASE_ISLAND_RADIUS
		+ sin(angle * 3.0 + 0.4) * 18.0
		+ cos(angle * 5.0 - 0.6) * 10.0
		+ sin(angle * 7.0 + 0.8) * 5.0
	)


static func _rolling_height(world_x: float, world_z: float) -> float:
	var broad := (sin(world_x * 0.018) + 1.0) * 0.5
	var crossing := (cos(world_z * 0.021) + 1.0) * 0.5
	var diagonal := (sin((world_x + world_z) * 0.013) + 1.0) * 0.5
	return (
		MINIMUM_PLAYABLE_HEIGHT
		+ broad * 2.1
		+ crossing * 1.6
		+ diagonal * 1.2
	)


static func _regional_relief(world_position: Vector2) -> float:
	# Broad, recognisable masses give the player landmarks at a distance: a
	# northern ridge, an eastern highland and a softer western rise. Smaller
	# dressing can later follow these shapes instead of defining the map itself.
	var northern_ridge := 8.5 * exp(
		-pow(world_position.x - 38.0, 2.0) / 9200.0
		-pow(world_position.y + 84.0, 2.0) / 1500.0
	)
	var eastern_highland := 10.5 * exp(
		-(world_position - Vector2(108.0, 42.0)).length_squared() / 5200.0
	)
	var western_rise := 5.0 * exp(
		-(world_position - Vector2(-126.0, 68.0)).length_squared() / 4300.0
	)
	var twin_peak_west := 5.2 * exp(
		-(world_position - Vector2(6.0, -118.0)).length_squared() / 720.0
	)
	var twin_peak_east := 6.0 * exp(
		-(world_position - Vector2(62.0, -112.0)).length_squared() / 760.0
	)
	var south_cape := 3.0 * exp(
		-(world_position - Vector2(66.0, 188.0)).length_squared() / 1500.0
	)
	return (
		northern_ridge + eastern_highland + western_rise
		+ twin_peak_west + twin_peak_east + south_cape
	)


static func _apply_routes(world_position: Vector2, current_height: float) -> float:
	var local := world_position - ISLAND_CENTER
	var angle := atan2(local.y, local.x)
	var radial_distance := local.length()
	var inner_distance := absf(radial_distance - INNER_ROUTE_RADIUS)
	var coast_distance := absf(
		radial_distance - (_island_radius(angle) - COAST_ROUTE_INSET)
	)
	var inner_weight := 1.0 - smoothstep(
		ROUTE_CORE_WIDTH, ROUTE_BLEND_WIDTH, inner_distance
	)
	var coast_weight := 1.0 - smoothstep(
		ROUTE_CORE_WIDTH, ROUTE_BLEND_WIDTH, coast_distance
	)
	var camp_weight := _segment_route_weight(
		world_position, CAMP_POSITION, NORTH_CONNECTOR_END
	)
	var east_weight := _segment_route_weight(
		world_position, EAST_CONNECTOR_START, EAST_CONNECTOR_END
	)
	var south_weight := _segment_route_weight(
		world_position, SOUTH_CONNECTOR_START, SOUTH_CONNECTOR_END
	)
	var route_weight := maxf(
		maxf(inner_weight, coast_weight),
		maxf(camp_weight, maxf(east_weight, south_weight))
	)
	if route_weight <= 0.0:
		return current_height
	var inner_target := 2.1 + sin(angle * 2.0 - 0.4) * 0.55
	var coast_target := 0.55 + sin(angle * 3.0 + 0.7) * 0.28
	var camp_target := lerpf(
		0.0,
		2.0,
		_segment_progress(world_position, CAMP_POSITION, NORTH_CONNECTOR_END)
	)
	var east_target := lerpf(
		6.8,
		1.1,
		_segment_progress(world_position, EAST_CONNECTOR_START, EAST_CONNECTOR_END)
	)
	var south_target := lerpf(
		2.0,
		0.55,
		_segment_progress(world_position, SOUTH_CONNECTOR_START, SOUTH_CONNECTOR_END)
	)
	var target_height := current_height
	var total_weight := 0.0
	for target_and_weight in [
		Vector2(inner_target, inner_weight),
		Vector2(coast_target, coast_weight),
		Vector2(camp_target, camp_weight),
		Vector2(east_target, east_weight),
		Vector2(south_target, south_weight),
	]:
		if target_and_weight.y <= 0.0:
			continue
		target_height += target_and_weight.x * target_and_weight.y
		total_weight += target_and_weight.y
	if total_weight > 0.0:
		target_height /= 1.0 + total_weight
	return lerpf(current_height, target_height, route_weight * 0.78)


static func _segment_route_weight(
	world_position: Vector2, start: Vector2, end: Vector2
) -> float:
	var segment := end - start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.001:
		return 0.0
	var progress := clampf(
		(world_position - start).dot(segment) / segment_length_squared, 0.0, 1.0
	)
	var closest := start + segment * progress
	var distance := world_position.distance_to(closest)
	return 1.0 - smoothstep(ROUTE_CORE_WIDTH, ROUTE_BLEND_WIDTH, distance)


static func _segment_progress(
	world_position: Vector2, start: Vector2, end: Vector2
) -> float:
	var segment := end - start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.001:
		return 0.0
	return clampf(
		(world_position - start).dot(segment) / segment_length_squared, 0.0, 1.0
	)


static func _natural_height(
	world_x: float, world_z: float, rolling_height: float
) -> float:
	var local := Vector2(world_x, world_z) - NATURAL_CENTER
	var edge_distance := minf(
		SECTOR_HALF_SIZE - absf(local.x),
		SECTOR_HALF_SIZE - absf(local.y)
	)
	var edge_blend := smoothstep(0.0, 7.0, edge_distance)
	var hills := (
		2.7 * exp(-(local - Vector2(17.0, -14.0)).length_squared() / 310.0)
		+ 2.1 * exp(-(local - Vector2(-17.0, 13.0)).length_squared() / 250.0)
		+ 1.4 * exp(-(local - Vector2(17.0, 17.0)).length_squared() / 220.0)
		+ sin(local.x * 0.13) * cos(local.y * 0.11) * 0.24
	)
	var trail_distance := absf(world_x - trail_center_x(world_z))
	var trail_blend := 1.0 - smoothstep(3.8, 9.0, trail_distance)
	var raised_height := rolling_height + maxf(hills, 0.0) * edge_blend
	# A low, naturally readable corridor remains even without the old road mesh.
	return lerpf(raised_height, 0.18, trail_blend * 0.88)
