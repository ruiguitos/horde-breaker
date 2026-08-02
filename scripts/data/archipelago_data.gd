class_name ArchipelagoData
extends Resource

@export var map_name := ""
@export var starting_island_id: StringName = &""
@export var islands: Array[IslandData] = []
@export var routes: Array[IslandRouteData] = []


func get_island(island_id: StringName) -> IslandData:
	for island in islands:
		if island != null and island.island_id == island_id:
			return island
	return null


func get_route(route_id: StringName) -> IslandRouteData:
	for route in routes:
		if route != null and route.route_id == route_id:
			return route
	return null


func get_route_between(
	source_id: StringName, destination_id: StringName
) -> IslandRouteData:
	for route in routes:
		if (
			route != null
			and route.source_island_id == source_id
			and route.destination_island_id == destination_id
		):
			return route
	return null


func validate_graph() -> PackedStringArray:
	var errors := PackedStringArray()
	if get_island(starting_island_id) == null:
		errors.append("Starting island '%s' does not exist." % starting_island_id)
	var known_ids: Dictionary[StringName, bool] = {}
	for island in islands:
		if island == null or island.island_id == &"":
			errors.append("Every island requires a non-empty id.")
			continue
		if known_ids.has(island.island_id):
			errors.append("Duplicate island id '%s'." % island.island_id)
		known_ids[island.island_id] = true
	for island in islands:
		if island == null:
			continue
		for destination_id in island.connection_ids:
			if get_island(destination_id) == null:
				errors.append(
					"Island '%s' links to missing island '%s'."
					% [island.island_id, destination_id]
				)
			elif get_route_between(island.island_id, destination_id) == null:
				errors.append(
					"Connection '%s' -> '%s' has no route data."
					% [island.island_id, destination_id]
				)
	return errors
