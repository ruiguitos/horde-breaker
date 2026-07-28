extends Control

## Always-on minimap in the HUD corner. The tactical map on Tab shows the whole
## 512 m world at once, which answers "where am I in the world"; this answers
## "what is around me right now", which is the question you have while running
## from a horde and cannot afford to open a full-screen map.
##
## It draws a fixed radius around the player, rotated so up is always the way the
## player faces — a north-up minimap forces mental rotation at exactly the moment
## the player has no attention to spare.

const PLAYER_GROUP := &"player"
const ENEMY_GROUP := &"enemy"
const CAMP_GROUP := &"camp_core"
const SCRAP_GROUP := &"enemy_scrap_drop"
const AMMO_GROUP := &"enemy_ammo_drop"
const OBJECTIVE_GROUP := &"run_objective"

## Metres from the player shown at the edge of the dial.
@export_range(20.0, 200.0, 5.0) var view_radius: float = 70.0
## Redraw interval. Enemies move every frame but the eye does not need 60 Hz,
## and this runs while a horde of 140 is on screen.
@export_range(0.02, 0.5, 0.01) var refresh_interval: float = 0.08
@export var rotate_with_player: bool = true

const BACKDROP_COLOR := Color(0.025, 0.039, 0.055, 0.82)
const RING_COLOR := Color(0.31, 0.40, 0.45, 0.55)
const GRID_COLOR := Color(0.16, 0.24, 0.28, 0.5)
const PLAYER_COLOR := Color(0.25, 0.78, 1.0, 1.0)
const ENEMY_COLOR := Color(0.91, 0.27, 0.24, 1.0)
const CAMP_COLOR := Color(0.94, 0.57, 0.22, 1.0)
const SCRAP_COLOR := Color(0.44, 0.82, 0.59, 1.0)
const AMMO_COLOR := Color(0.35, 0.72, 0.95, 1.0)
const OBJECTIVE_COLOR := Color(1.0, 0.5, 0.16, 1.0)
const NORTH_COLOR := Color(0.62, 0.68, 0.72, 0.9)

## Enemies are capped so a full horde cannot turn the dial into a red disc, and
## so the draw stays cheap.
const MAX_ENEMY_BLIPS := 40

var _player: Node3D
var _objective: Node
var _refresh_time: float = 0.0


func _ready() -> void:
	# Keeps updating while the tree is paused so the pause screen is not stale.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_acquire_references()


func _process(delta: float) -> void:
	_refresh_time -= delta
	if _refresh_time > 0.0:
		return
	_refresh_time = refresh_interval
	if not is_instance_valid(_player):
		_acquire_references()
	queue_redraw()


func _acquire_references() -> void:
	_player = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	_objective = get_tree().get_first_node_in_group(OBJECTIVE_GROUP)


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	draw_circle(centre, radius, BACKDROP_COLOR)
	draw_arc(centre, radius, 0.0, TAU, 48, RING_COLOR, 1.5, true)
	draw_arc(centre, radius * 0.5, 0.0, TAU, 32, GRID_COLOR, 1.0, true)
	if not is_instance_valid(_player):
		return

	var origin := Vector2(_player.global_position.x, _player.global_position.z)
	var rotation := _get_rotation()
	var scale := radius / view_radius

	_draw_north(centre, radius, rotation)

	# Camp and extraction are clamped to the rim when out of range: knowing the
	# direction home matters more than knowing it is off-screen.
	var camp := get_tree().get_first_node_in_group(CAMP_GROUP) as Node3D
	if camp != null:
		_draw_marker(
			centre, radius, scale, rotation, origin,
			Vector2(camp.global_position.x, camp.global_position.z),
			CAMP_COLOR, 4.0, true
		)
	if _objective != null and _objective.has_method(&"get_extraction_position"):
		var extraction: Vector3 = _objective.call(&"get_extraction_position")
		var window_open := (
			_objective.has_method(&"is_extraction_window_open")
			and bool(_objective.call(&"is_extraction_window_open"))
		)
		if window_open:
			_draw_marker(
				centre, radius, scale, rotation, origin,
				Vector2(extraction.x, extraction.z),
				OBJECTIVE_COLOR, 5.0, true
			)

	for group_name in [SCRAP_GROUP, AMMO_GROUP]:
		var colour := SCRAP_COLOR if group_name == SCRAP_GROUP else AMMO_COLOR
		for value in get_tree().get_nodes_in_group(group_name):
			var pickup := value as Node3D
			if pickup == null or not is_instance_valid(pickup):
				continue
			_draw_marker(
				centre, radius, scale, rotation, origin,
				Vector2(pickup.global_position.x, pickup.global_position.z),
				colour, 2.0, false
			)

	var drawn := 0
	for value in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if drawn >= MAX_ENEMY_BLIPS:
			break
		var enemy := value as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if _draw_marker(
			centre, radius, scale, rotation, origin,
			Vector2(enemy.global_position.x, enemy.global_position.z),
			ENEMY_COLOR, 2.5, false
		):
			drawn += 1

	_draw_player(centre)


## Returns true when the marker was drawn (i.e. it was in range, or clamped).
func _draw_marker(
	centre: Vector2,
	radius: float,
	scale: float,
	rotation: float,
	origin: Vector2,
	world_position: Vector2,
	colour: Color,
	marker_size: float,
	clamp_to_edge: bool
) -> bool:
	var offset := (world_position - origin).rotated(rotation) * scale
	var distance := offset.length()
	if distance > radius - marker_size:
		if not clamp_to_edge:
			return false
		offset = offset.normalized() * (radius - marker_size - 1.0)
	draw_circle(centre + offset, marker_size, colour)
	return true


func _draw_player(centre: Vector2) -> void:
	# A triangle, not a dot: it reads as "facing" even when the dial rotates.
	var points := PackedVector2Array([
		centre + Vector2(0.0, -6.0),
		centre + Vector2(4.5, 5.0),
		centre + Vector2(-4.5, 5.0),
	])
	draw_colored_polygon(points, PLAYER_COLOR)


func _draw_north(centre: Vector2, radius: float, rotation: float) -> void:
	var north := Vector2(0.0, -1.0).rotated(rotation) * (radius - 7.0)
	draw_circle(centre + north, 2.0, NORTH_COLOR)


func _get_rotation() -> float:
	if not rotate_with_player:
		return 0.0
	# The player's visual root carries the facing; rotating by its negative puts
	# "where I am looking" at the top of the dial.
	var visual := _player.get_node_or_null("VisualRoot") as Node3D
	return -(visual.global_rotation.y if visual != null else _player.global_rotation.y)
