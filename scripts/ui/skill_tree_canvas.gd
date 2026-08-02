class_name SkillTreeCanvas
extends Control

## Draws the skill tree itself: a spine running down the tiers, a connector out
## to each of the two options, and a diamond node at the end of each connector.
##
## It draws only. The clickable areas are transparent Buttons the screen places
## on top of the diamonds, so hover, focus and keyboard navigation stay ordinary
## Control behaviour instead of something reimplemented on top of _draw().
##
## A parent's _draw() runs beneath its children, which is exactly the stacking
## this needs: spine and connectors behind, buttons and labels in front.

## Geometry, in pixels inside the canvas.
const TIER_SPACING := 104.0
const TOP_MARGIN := 58.0
const BRANCH_REACH := 152.0
const NODE_RADIUS := 26.0
const SPINE_WIDTH := 4.0
const CONNECTOR_WIDTH := 3.0

const SPINE_DIM := Color(0.20, 0.23, 0.27, 1.0)
const NODE_FILL := Color(0.09, 0.11, 0.13, 1.0)
const LOCKED_LINE := Color(0.22, 0.25, 0.29, 1.0)
const OPEN_LINE := Color(0.38, 0.43, 0.49, 1.0)

## One entry per tier: {"open": bool, "taken": -1 left, 1 right, 0 none}.
var tiers: Array[Dictionary] = []
## The class colour. Everything lit is drawn in it.
var accent: Color = Color(0.957, 0.694, 0.31, 1.0)


func get_tier_centre(tier_index: int) -> Vector2:
	return Vector2(size.x * 0.5, TOP_MARGIN + TIER_SPACING * float(tier_index))


func get_node_centre(tier_index: int, side: int) -> Vector2:
	var centre := get_tier_centre(tier_index)
	return centre + Vector2(BRANCH_REACH * float(side), 0.0)


## Height the canvas needs for the tiers it has been given.
func get_required_height() -> float:
	if tiers.is_empty():
		return 0.0
	return TOP_MARGIN * 2.0 + TIER_SPACING * float(tiers.size() - 1)


func _draw() -> void:
	if tiers.is_empty():
		return
	_draw_spine()
	for tier_index in tiers.size():
		var tier: Dictionary = tiers[tier_index]
		var is_open := bool(tier["open"])
		var taken := int(tier["taken"])
		for side: int in [-1, 1]:
			var lit: bool = is_open and taken == side
			_draw_connector(tier_index, side, lit, is_open)
			_draw_node(tier_index, side, lit, is_open)
		# The spine knot marks the tier itself, filled once a side is taken.
		var centre := get_tier_centre(tier_index)
		var knot_colour := accent if (is_open and taken != 0) else (
			OPEN_LINE if is_open else LOCKED_LINE
		)
		draw_circle(centre, 7.0, NODE_FILL)
		draw_arc(centre, 7.0, 0.0, TAU, 24, knot_colour, 2.5, true)


func _draw_spine() -> void:
	var top := get_tier_centre(0)
	var bottom := get_tier_centre(tiers.size() - 1)
	draw_line(top, bottom, SPINE_DIM, SPINE_WIDTH, true)
	# The lit part of the spine reaches as far as the deepest tier already
	# chosen, so progress down the tree reads at a glance.
	var deepest := -1
	for tier_index in tiers.size():
		if int(tiers[tier_index]["taken"]) != 0:
			deepest = tier_index
	if deepest >= 0:
		draw_line(
			top, get_tier_centre(deepest), accent.lerp(Color.WHITE, 0.1),
			SPINE_WIDTH, true
		)


func _draw_connector(tier_index: int, side: int, lit: bool, is_open: bool) -> void:
	var start := get_tier_centre(tier_index)
	var finish := get_node_centre(tier_index, side)
	var colour := LOCKED_LINE
	if lit:
		colour = accent
	elif is_open:
		colour = OPEN_LINE
	draw_line(start, finish, colour, CONNECTOR_WIDTH, true)


func _draw_node(tier_index: int, side: int, lit: bool, is_open: bool) -> void:
	var centre := get_node_centre(tier_index, side)
	var diamond := PackedVector2Array([
		centre + Vector2(0.0, -NODE_RADIUS),
		centre + Vector2(NODE_RADIUS, 0.0),
		centre + Vector2(0.0, NODE_RADIUS),
		centre + Vector2(-NODE_RADIUS, 0.0),
	])
	draw_colored_polygon(diamond, NODE_FILL)
	var outline := LOCKED_LINE
	if lit:
		outline = accent
	elif is_open:
		outline = OPEN_LINE
	# Closed loop: the last segment back to the top point.
	var loop := diamond.duplicate()
	loop.append(diamond[0])
	draw_polyline(loop, outline, 3.0 if lit else 2.0, true)
	if lit:
		# A second, smaller diamond reads as the node being filled rather than
		# merely outlined — the difference between "available" and "taken" has
		# to survive being glanced at from across the screen.
		var inner := PackedVector2Array([
			centre + Vector2(0.0, -NODE_RADIUS * 0.52),
			centre + Vector2(NODE_RADIUS * 0.52, 0.0),
			centre + Vector2(0.0, NODE_RADIUS * 0.52),
			centre + Vector2(-NODE_RADIUS * 0.52, 0.0),
		])
		draw_colored_polygon(inner, accent)
