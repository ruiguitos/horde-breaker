class_name SectorEdgeContract
extends RefCounted

## Computes the four edge connectors of a sector purely from the global run
## seed and grid coordinates, so two neighbouring sectors independently
## derive the exact same shared connector without communicating with each
## other. This is the foundation the road graph is built on top of (see
## docs/CITY_REBUILD_PLAN.md).

const RULES: CityLayoutRules = preload("res://data/city_layout_rules.tres")

const SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]
const SIDE_OFFSETS: Dictionary[StringName, Vector2i] = {
	&"north": Vector2i(0, -1),
	&"south": Vector2i(0, 1),
	&"east": Vector2i(1, 0),
	&"west": Vector2i(-1, 0),
}


static func get_edge_connector(
	run_seed: int,
	coords: Vector2i,
	side: StringName,
	grid_min: Vector2i,
	grid_max: Vector2i,
	sector_size: float
) -> Dictionary:
	var neighbor: Vector2i = coords + SIDE_OFFSETS[side]
	var half_size := sector_size * 0.5
	var sector_center := Vector3(coords.x * sector_size, 0.0, coords.y * sector_size)
	var is_within_grid := (
		neighbor.x >= grid_min.x and neighbor.x <= grid_max.x
		and neighbor.y >= grid_min.y and neighbor.y <= grid_max.y
	)
	if not is_within_grid:
		return {
			"id": StringName("boundary_%d_%d_%s" % [coords.x, coords.y, side]),
			"side": side,
			"connected": false,
			"kind": &"world_edge_dead_end",
			"world_position": _edge_midpoint(sector_center, side, half_size),
			"width": RULES.road_width,
			"type": &"road",
			"neighbor_coords": neighbor,
		}
	# Canonicalize on the lower of the two neighbouring coordinates along the
	# axis that differs between them, so both sides of a shared edge hash and
	# position identically regardless of which sector asks first.
	var axis: StringName = &"x" if (side == &"east" or side == &"west") else &"z"
	var low := coords if _is_lower(coords, neighbor, axis) else neighbor
	var edge_id := StringName("edge_%d_%d_%s" % [low.x, low.y, axis])
	var edge_seed := hash([run_seed, &"sector_edge", low.x, low.y, axis]) & 0x7FFFFFFF
	var midpoint := _edge_midpoint(sector_center, side, half_size)
	if RULES.edge_connector_jitter > 0.0:
		var jitter_rng := RandomNumberGenerator.new()
		jitter_rng.seed = edge_seed
		var jitter := jitter_rng.randf_range(
			-RULES.edge_connector_jitter, RULES.edge_connector_jitter
		)
		var tangent := Vector3.BACK if axis == &"x" else Vector3.RIGHT
		midpoint += tangent * jitter
	return {
		"id": edge_id,
		"side": side,
		"connected": true,
		"kind": &"boundary_connector",
		"world_position": midpoint,
		"width": RULES.road_width,
		"type": &"road",
		"neighbor_coords": neighbor,
	}


static func _edge_midpoint(
	sector_center: Vector3, side: StringName, half_size: float
) -> Vector3:
	match side:
		&"north":
			return sector_center + Vector3(0.0, 0.0, -half_size)
		&"south":
			return sector_center + Vector3(0.0, 0.0, half_size)
		&"east":
			return sector_center + Vector3(half_size, 0.0, 0.0)
		&"west":
			return sector_center + Vector3(-half_size, 0.0, 0.0)
	return sector_center


static func _is_lower(a: Vector2i, b: Vector2i, axis: StringName) -> bool:
	if axis == &"x":
		return a.x <= b.x
	return a.y <= b.y
