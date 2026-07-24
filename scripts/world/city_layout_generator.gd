class_name CityLayoutGenerator
extends RefCounted

## Orchestrates SectorEdgeContract + RoadGraph across the whole sector grid.
## Phase 1/2 only: builds a debug graph (one centre node per sector plus its
## four boundary connectors), a debug line visual, and the two checks the
## rebuild plan calls for before any real geometry is built — boundary
## continuity across every shared edge, and determinism under repeated
## builds of the same seed.

const RULES: CityLayoutRules = preload("res://data/city_layout_rules.tres")


static func build_debug_graph(
	run_seed: int, grid_min: Vector2i, grid_max: Vector2i, sector_size: float
) -> RoadGraph:
	var graph := RoadGraph.new()
	for grid_x in range(grid_min.x, grid_max.x + 1):
		for grid_z in range(grid_min.y, grid_max.y + 1):
			var coords := Vector2i(grid_x, grid_z)
			var center_id := StringName("center_%d_%d" % [coords.x, coords.y])
			var center_position := Vector3(
				coords.x * sector_size, 0.0, coords.y * sector_size
			)
			graph.add_node(center_id, center_position, &"center_intersection", coords)
			for side in SectorEdgeContract.SIDES:
				var connector := SectorEdgeContract.get_edge_connector(
					run_seed, coords, side, grid_min, grid_max, sector_size
				)
				var connector_id: StringName = connector["id"]
				graph.add_node(
					connector_id, connector["world_position"], connector["kind"], coords
				)
				var edge_id := StringName("%s__%s" % [center_id, connector_id])
				graph.add_edge(
					edge_id,
					center_id,
					connector_id,
					connector["width"],
					connector["kind"],
					side
				)
	return graph


static func build_debug_visual(
	graph: RoadGraph, invalid_node_ids: Array[StringName] = []
) -> MeshInstance3D:
	var immediate_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for edge in graph.edges.values():
		var from_position: Vector3 = graph.nodes[edge["from"]]["position"]
		var to_position: Vector3 = graph.nodes[edge["to"]]["position"]
		immediate_mesh.surface_set_color(RULES.debug_line_color)
		immediate_mesh.surface_add_vertex(from_position + Vector3.UP * 0.05)
		immediate_mesh.surface_set_color(RULES.debug_line_color)
		immediate_mesh.surface_add_vertex(to_position + Vector3.UP * 0.05)
	var marker_half := RULES.debug_node_marker_size * 0.5
	for node_id in graph.nodes:
		var node: Dictionary = graph.nodes[node_id]
		var color := _node_color(node_id, node["kind"], invalid_node_ids)
		var position: Vector3 = node["position"] + Vector3.UP * 0.06
		for offset in [
			Vector3.LEFT * marker_half,
			Vector3.RIGHT * marker_half,
			Vector3.FORWARD * marker_half,
			Vector3.BACK * marker_half,
		]:
			immediate_mesh.surface_set_color(color)
			immediate_mesh.surface_add_vertex(position + offset)
	immediate_mesh.surface_end()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "CityGraphDebugVisual"
	mesh_instance.mesh = immediate_mesh
	return mesh_instance


static func verify_boundary_continuity(
	run_seed: int, grid_min: Vector2i, grid_max: Vector2i, sector_size: float
) -> Array[String]:
	var errors: Array[String] = []
	# Only checking the east and south side of every sector visits each of the
	# grid's 24 internal boundaries exactly once (12 east/west + 12 north/south).
	for grid_x in range(grid_min.x, grid_max.x + 1):
		for grid_z in range(grid_min.y, grid_max.y + 1):
			var coords := Vector2i(grid_x, grid_z)
			for side in [&"east", &"south"]:
				var opposite: StringName = &"west" if side == &"east" else &"north"
				var neighbor: Vector2i = (
					coords + SectorEdgeContract.SIDE_OFFSETS[side]
				)
				if (
					neighbor.x < grid_min.x or neighbor.x > grid_max.x
					or neighbor.y < grid_min.y or neighbor.y > grid_max.y
				):
					continue
				var from_here := SectorEdgeContract.get_edge_connector(
					run_seed, coords, side, grid_min, grid_max, sector_size
				)
				var from_neighbor := SectorEdgeContract.get_edge_connector(
					run_seed, neighbor, opposite, grid_min, grid_max, sector_size
				)
				errors.append_array(
					_compare_connectors(coords, side, from_here, from_neighbor)
				)
	return errors


static func verify_determinism(
	run_seed: int,
	grid_min: Vector2i,
	grid_max: Vector2i,
	sector_size: float,
	attempts: int = 3
) -> Array[String]:
	var errors: Array[String] = []
	var baseline := build_debug_graph(run_seed, grid_min, grid_max, sector_size).to_dict()
	for attempt_index in range(1, attempts):
		var candidate := build_debug_graph(
			run_seed, grid_min, grid_max, sector_size
		).to_dict()
		if candidate != baseline:
			errors.append(
				"Graph for seed %d differs between build attempt 0 and %d."
				% [run_seed, attempt_index]
			)
	return errors


static func _node_color(
	node_id: StringName, kind: StringName, invalid_node_ids: Array[StringName]
) -> Color:
	if node_id in invalid_node_ids:
		return RULES.debug_validation_error_color
	match kind:
		&"center_intersection":
			return RULES.debug_center_node_color
		&"world_edge_dead_end":
			return RULES.debug_boundary_dead_end_color
		_:
			return RULES.debug_boundary_connected_color


static func _compare_connectors(
	coords: Vector2i, side: StringName, a: Dictionary, b: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	var label := "boundary %s of sector %s" % [side, coords]
	if a["id"] != b["id"]:
		errors.append("%s: id mismatch (%s vs %s)." % [label, a["id"], b["id"]])
	var drift: float = (
		(a["world_position"] as Vector3).distance_to(b["world_position"])
	)
	if drift > RoadGraph.POSITION_EPSILON:
		errors.append("%s: position mismatch (%.3f m drift)." % [label, drift])
	if not is_equal_approx(a["width"], b["width"]):
		errors.append(
			"%s: width mismatch (%.2f vs %.2f)." % [label, a["width"], b["width"]]
		)
	if a["type"] != b["type"]:
		errors.append("%s: type mismatch (%s vs %s)." % [label, a["type"], b["type"]])
	return errors
