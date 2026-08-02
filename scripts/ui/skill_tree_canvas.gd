class_name SkillTreeCanvas
extends Control

## Draws the skill tree: three category columns side by side, each a spine that
## forks at tier 3 and rejoins at tier 4.
##
## It draws only. The clickable areas are transparent Buttons the screen places
## over the nodes, so hover, focus and keyboard navigation stay ordinary Control
## behaviour rather than something reimplemented inside _draw(). A parent's
## _draw() runs beneath its children, which is the stacking this needs: lines and
## node bodies behind, buttons and labels in front.
##
## A connector lights when the node it leads *to* is unlocked, so the lit part of
## a column is exactly the part that has been paid for.

const TIER_SPACING := 86.0
const TOP_MARGIN := 54.0
const FORK_REACH := 58.0
const NODE_RADIUS := 21.0
const SPINE_WIDTH := 3.0
const CONNECTOR_WIDTH := 2.5

const NODE_FILL := Color(0.09, 0.11, 0.13, 1.0)
const LOCKED_LINE := Color(0.20, 0.23, 0.27, 1.0)
## Reachable now: the prerequisites are met and a point is in hand.
const AVAILABLE_LINE := Color(0.50, 0.56, 0.63, 1.0)

## One entry per category column, in display order:
##   {"nodes": [{"tier": int, "column": int, "unlocked": bool, "available": bool}]}
var columns: Array[Dictionary] = []
## The class colour. Everything unlocked is drawn in it.
var accent: Color = Color(0.957, 0.694, 0.31, 1.0)


func get_column_centre_x(column_index: int) -> float:
	var count := maxi(columns.size(), 1)
	return size.x * (float(column_index) + 0.5) / float(count)


func get_node_centre(column_index: int, tier: int, column: int) -> Vector2:
	return Vector2(
		get_column_centre_x(column_index) + FORK_REACH * float(column),
		TOP_MARGIN + TIER_SPACING * float(tier - 1)
	)


func get_required_height() -> float:
	return TOP_MARGIN * 2.0 + TIER_SPACING * float(maxi(SkillTree.TIER_COUNT - 1, 1))


func _draw() -> void:
	for column_index in columns.size():
		_draw_column(column_index)


func _draw_column(column_index: int) -> void:
	var nodes: Array = columns[column_index]["nodes"]
	# Connectors first so the node bodies sit on top of their ends.
	for node: Dictionary in nodes:
		for parent: Dictionary in _get_parents(nodes, node):
			_draw_connector(column_index, parent, node)
	for node: Dictionary in nodes:
		_draw_node(column_index, node)


## The nodes one tier above that lead into this one. Tier 4 rejoins both sides of
## the fork, so it has two.
func _get_parents(nodes: Array, node: Dictionary) -> Array[Dictionary]:
	var parents: Array[Dictionary] = []
	var tier := int(node["tier"])
	if tier <= 1:
		return parents
	for candidate: Dictionary in nodes:
		if int(candidate["tier"]) == tier - 1:
			parents.append(candidate)
	return parents


func _draw_connector(
	column_index: int, from_node: Dictionary, to_node: Dictionary
) -> void:
	var start := get_node_centre(
		column_index, int(from_node["tier"]), int(from_node["column"])
	)
	var finish := get_node_centre(
		column_index, int(to_node["tier"]), int(to_node["column"])
	)
	var lit := bool(to_node["unlocked"])
	var colour := LOCKED_LINE
	if lit:
		colour = accent
	elif bool(to_node["available"]):
		colour = AVAILABLE_LINE
	draw_line(start, finish, colour, SPINE_WIDTH if lit else CONNECTOR_WIDTH, true)


func _draw_node(column_index: int, node: Dictionary) -> void:
	var centre := get_node_centre(
		column_index, int(node["tier"]), int(node["column"])
	)
	var unlocked := bool(node["unlocked"])
	var available := bool(node["available"])
	var diamond := PackedVector2Array([
		centre + Vector2(0.0, -NODE_RADIUS),
		centre + Vector2(NODE_RADIUS, 0.0),
		centre + Vector2(0.0, NODE_RADIUS),
		centre + Vector2(-NODE_RADIUS, 0.0),
	])
	draw_colored_polygon(diamond, NODE_FILL)
	var outline := LOCKED_LINE
	if unlocked:
		outline = accent
	elif available:
		outline = AVAILABLE_LINE
	var loop := diamond.duplicate()
	loop.append(diamond[0])
	draw_polyline(loop, outline, 3.0 if unlocked else 2.0, true)
	if unlocked:
		# Filled, not merely outlined: the difference between "you could buy
		# this" and "you own this" has to survive being glanced at.
		var inner := PackedVector2Array([
			centre + Vector2(0.0, -NODE_RADIUS * 0.5),
			centre + Vector2(NODE_RADIUS * 0.5, 0.0),
			centre + Vector2(0.0, NODE_RADIUS * 0.5),
			centre + Vector2(-NODE_RADIUS * 0.5, 0.0),
		])
		draw_colored_polygon(inner, accent)
