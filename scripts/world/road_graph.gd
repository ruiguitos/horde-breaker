class_name RoadGraph
extends RefCounted

## A minimal node/edge graph built from SectorEdgeContract connectors across
## the whole sector grid. Phase 1/2 only: one centre node per sector plus its
## four boundary connectors, enough to prove the edge contract is consistent
## before any real road geometry exists. Nodes/edges are added idempotently so
## two neighbouring sectors can each contribute their half of a shared
## boundary without either one owning it.

const POSITION_EPSILON := 0.01

var nodes: Dictionary[StringName, Dictionary] = {}
var edges: Dictionary[StringName, Dictionary] = {}


func add_node(
	node_id: StringName, position: Vector3, kind: StringName, sector_coords: Vector2i
) -> void:
	if nodes.has(node_id):
		var existing: Dictionary = nodes[node_id]
		var drift: float = (existing["position"] as Vector3).distance_to(position)
		if drift > POSITION_EPSILON:
			push_warning(
				"RoadGraph: node '%s' repositioned by sector %s (%.3f m drift)."
				% [node_id, sector_coords, drift]
			)
		var touching: Array = existing["touching_sectors"]
		if sector_coords not in touching:
			touching.append(sector_coords)
		return
	nodes[node_id] = {
		"position": position,
		"kind": kind,
		"touching_sectors": [sector_coords],
	}


func add_edge(
	edge_id: StringName,
	from_id: StringName,
	to_id: StringName,
	width: float,
	kind: StringName,
	side: StringName
) -> void:
	if edges.has(edge_id):
		return
	edges[edge_id] = {
		"from": from_id,
		"to": to_id,
		"width": width,
		"kind": kind,
		"side": side,
	}


func get_degree(node_id: StringName) -> int:
	var degree := 0
	for edge in edges.values():
		if edge["from"] == node_id or edge["to"] == node_id:
			degree += 1
	return degree


func get_dead_end_ids() -> Array[StringName]:
	var dead_ends: Array[StringName] = []
	for node_id in nodes:
		if get_degree(node_id) == 1:
			dead_ends.append(node_id)
	return dead_ends


func validate() -> Array[String]:
	var errors: Array[String] = []
	for node_id in get_dead_end_ids():
		var node: Dictionary = nodes[node_id]
		if node["kind"] != &"world_edge_dead_end":
			errors.append(
				"Unintended dead end at node '%s' (kind %s)." % [node_id, node["kind"]]
			)
	var minimum_length := SectorEdgeContract.RULES.minimum_segment_length
	for edge_id in edges:
		var edge: Dictionary = edges[edge_id]
		if not nodes.has(edge["from"]) or not nodes.has(edge["to"]):
			errors.append("Edge '%s' references a missing node." % edge_id)
			continue
		var from_position: Vector3 = nodes[edge["from"]]["position"]
		var to_position: Vector3 = nodes[edge["to"]]["position"]
		var length := from_position.distance_to(to_position)
		if length < minimum_length:
			errors.append(
				"Edge '%s' is %.2f m, below the %.2f m minimum."
				% [edge_id, length, minimum_length]
			)
	errors.append_array(_find_impossible_crossings())
	return errors


func to_dict() -> Dictionary:
	return {"nodes": nodes.duplicate(true), "edges": edges.duplicate(true)}


func _find_impossible_crossings() -> Array[String]:
	var errors: Array[String] = []
	var edge_ids := edges.keys()
	for edge_index in edge_ids.size():
		var edge_a: Dictionary = edges[edge_ids[edge_index]]
		var a_from: Vector3 = nodes[edge_a["from"]]["position"]
		var a_to: Vector3 = nodes[edge_a["to"]]["position"]
		for other_index in range(edge_index + 1, edge_ids.size()):
			var edge_b: Dictionary = edges[edge_ids[other_index]]
			if _shares_endpoint(edge_a, edge_b):
				continue
			var b_from: Vector3 = nodes[edge_b["from"]]["position"]
			var b_to: Vector3 = nodes[edge_b["to"]]["position"]
			if _segments_intersect_xz(a_from, a_to, b_from, b_to):
				errors.append(
					"Edges '%s' and '%s' cross without sharing a node."
					% [edge_ids[edge_index], edge_ids[other_index]]
				)
	return errors


func _shares_endpoint(edge_a: Dictionary, edge_b: Dictionary) -> bool:
	return (
		edge_a["from"] == edge_b["from"]
		or edge_a["from"] == edge_b["to"]
		or edge_a["to"] == edge_b["from"]
		or edge_a["to"] == edge_b["to"]
	)


static func _segments_intersect_xz(
	a_from: Vector3, a_to: Vector3, b_from: Vector3, b_to: Vector3
) -> bool:
	var p1 := Vector2(a_from.x, a_from.z)
	var p2 := Vector2(a_to.x, a_to.z)
	var p3 := Vector2(b_from.x, b_from.z)
	var p4 := Vector2(b_to.x, b_to.z)
	var d1 := _cross2(p4 - p3, p1 - p3)
	var d2 := _cross2(p4 - p3, p2 - p3)
	var d3 := _cross2(p2 - p1, p3 - p1)
	var d4 := _cross2(p2 - p1, p4 - p1)
	return ((d1 > 0.0) != (d2 > 0.0)) and ((d3 > 0.0) != (d4 > 0.0))


static func _cross2(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x
