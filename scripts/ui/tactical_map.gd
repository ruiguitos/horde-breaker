extends Control

const PLAYER_GROUP := &"player"
const CAMP_GROUP := &"camp_core"
const ENEMY_GROUP := &"enemy"
const POI_GROUP := &"point_of_interest"
const WORLD_STREAMER_GROUP := &"world_streamer"
const SECTOR_SIZE := 64.0
const SECTOR_HALF_SIZE := SECTOR_SIZE * 0.5
const GRID_MIN := Vector2i(-1, -1)
const GRID_MAX := Vector2i(2, 2)
const CAMP_COORDS := Vector2i.ZERO
const EAST_COORDS := Vector2i(1, 0)
const WORLD_MIN := Vector2(-96.0, -96.0)
const WORLD_MAX := Vector2(160.0, 160.0)
const PANEL_COLOR := Color(0.025, 0.039, 0.055, 0.96)
const MAP_COLOR := Color(0.045, 0.067, 0.086, 1.0)
const SECTOR_COLOR := Color(0.075, 0.11, 0.135, 1.0)
const LOADED_SECTOR_COLOR := Color(0.16, 0.24, 0.28, 1.0)
const CAMP_SECTOR_COLOR := Color(0.31, 0.20, 0.09, 1.0)
const BORDER_COLOR := Color(0.31, 0.40, 0.45, 1.0)
const ACCENT_COLOR := Color(0.94, 0.57, 0.22, 1.0)
const TEXT_COLOR := Color(0.94, 0.94, 0.91, 1.0)
const MUTED_TEXT_COLOR := Color(0.62, 0.68, 0.72, 1.0)
const PLAYER_COLOR := Color(0.25, 0.78, 1.0, 1.0)
const ENEMY_COLOR := Color(0.91, 0.27, 0.24, 1.0)
const POI_COLOR := Color(0.95, 0.77, 0.30, 1.0)
const SCRAP_COLOR := Color(0.44, 0.82, 0.59, 1.0)
const AMMO_COLOR := Color(0.35, 0.72, 0.95, 1.0)
const HEALTH_COLOR := Color(0.93, 0.45, 0.5, 1.0)
const WEAPON_COLOR := Color(1.0, 0.78, 0.32, 1.0)
const OBJECTIVE_COLOR := Color(1.0, 0.5, 0.16, 1.0)
const VISITED_SECTOR_COLOR := Color(0.11, 0.16, 0.19, 1.0)
const SCRAP_GROUP := &"scrap_pickup"
const AMMO_GROUP := &"ammo_pickup"
const HEALTH_GROUP := &"health_pickup"
const WEAPON_GROUP := &"weapon_pickup"
const OBJECTIVE_GROUP := &"sector_objective"

var _map_rect := Rect2()
var _player: Node3D
var _world_streamer: Node
var _visited_sectors: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Visited sectors persist per profile, so the map keeps its knowledge
	# across runs.
	for coords in SaveManager.get_visited_sector_coords():
		_visited_sectors[Vector2i(coords)] = true


# _input instead of _unhandled_input: Tab is also the built-in ui_focus_next
# shortcut, so any focused button (e.g. the upgrade choice panel) would
# consume the event before it ever reached unhandled input.
func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if not event.is_action_pressed("toggle_map") or event.is_echo():
		return
	visible = not visible
	if visible:
		_refresh_references()
		queue_redraw()
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_track_visited_sector()
	if get_tree().paused:
		visible = false
		return
	if visible:
		queue_redraw()


func _track_visited_sector() -> void:
	if not is_instance_valid(_player):
		_refresh_references()
	if not is_instance_valid(_player):
		return
	var coords := _get_player_sector_coords()
	if _visited_sectors.has(coords):
		return
	_visited_sectors[coords] = true
	SaveManager.mark_sector_visited(coords)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var map_side := maxf(240.0, minf(size.x - 120.0, size.y - 190.0))
	map_side = minf(map_side, 680.0)
	_map_rect = Rect2(
		Vector2((size.x - map_side) * 0.5, (size.y - map_side) * 0.5 + 10.0),
		Vector2(map_side, map_side)
	)
	var panel_rect := Rect2(
		_map_rect.position - Vector2(24.0, 70.0),
		_map_rect.size + Vector2(48.0, 124.0)
	)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.52))
	draw_rect(panel_rect, PANEL_COLOR)
	draw_rect(panel_rect, BORDER_COLOR, false, 2.0)
	draw_rect(
		Rect2(panel_rect.position, Vector2(panel_rect.size.x, 4.0)), ACCENT_COLOR
	)
	# Skewed accent chip matching the HUD plate style.
	var chip_origin := panel_rect.position + Vector2(18.0, 16.0)
	draw_colored_polygon(
		PackedVector2Array([
			chip_origin + Vector2(6.0, 0.0),
			chip_origin + Vector2(30.0, 0.0),
			chip_origin + Vector2(24.0, 28.0),
			chip_origin + Vector2(0.0, 28.0),
		]),
		ACCENT_COLOR
	)
	_draw_text(
		"TACTICAL MAP",
		panel_rect.position + Vector2(0.0, 37.0),
		26,
		TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x
	)
	_draw_text(
		"TAB  ·  CLOSE",
		panel_rect.position + Vector2(0.0, 59.0),
		13,
		MUTED_TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x
	)
	draw_rect(_map_rect, MAP_COLOR)
	_draw_sectors()
	_draw_loot()
	_draw_points_of_interest()
	_draw_objectives()
	_draw_enemies()
	_draw_camp()
	_draw_player()
	_draw_compass()
	_draw_footer(panel_rect)


func _draw_compass() -> void:
	# North indicator so the player can orient the grid at a glance.
	var center := Vector2(_map_rect.end.x - 4.0, _map_rect.position.y + 4.0)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -12.0),
			center + Vector2(6.0, 4.0),
			center + Vector2(0.0, 0.0),
			center + Vector2(-6.0, 4.0),
		]),
		ACCENT_COLOR
	)
	_draw_text("N", center + Vector2(-4.0, 22.0), 12, TEXT_COLOR)


func _draw_sectors() -> void:
	var player_coords := _get_player_sector_coords()
	for grid_z in range(GRID_MIN.y, GRID_MAX.y + 1):
		for grid_x in range(GRID_MIN.x, GRID_MAX.x + 1):
			var coords := Vector2i(grid_x, grid_z)
			var top_left := _world_to_map(
				Vector3(
					grid_x * SECTOR_SIZE - SECTOR_HALF_SIZE,
					0.0,
					grid_z * SECTOR_SIZE - SECTOR_HALF_SIZE
				)
			)
			var bottom_right := _world_to_map(
				Vector3(
					grid_x * SECTOR_SIZE + SECTOR_HALF_SIZE,
					0.0,
					grid_z * SECTOR_SIZE + SECTOR_HALF_SIZE
				)
			)
			var sector_rect := Rect2(top_left, bottom_right - top_left)
			var fill_color := SECTOR_COLOR
			if coords == CAMP_COORDS:
				fill_color = CAMP_SECTOR_COLOR
			elif _is_sector_loaded(coords):
				fill_color = LOADED_SECTOR_COLOR
			elif _visited_sectors.has(coords):
				fill_color = VISITED_SECTOR_COLOR
			draw_rect(sector_rect.grow(-3.0), fill_color)
			if coords == player_coords:
				draw_rect(sector_rect.grow(-1.0), ACCENT_COLOR, false, 2.0)
			else:
				draw_rect(sector_rect, BORDER_COLOR, false, 1.0)
			var sector_label := "BASE" if coords == CAMP_COORDS else "%d · %d" % [grid_x, grid_z]
			_draw_text(
				sector_label,
				sector_rect.position + Vector2(6.0, 17.0),
				11,
				MUTED_TEXT_COLOR
			)


func _draw_loot() -> void:
	_draw_loot_group(SCRAP_GROUP, SCRAP_COLOR)
	_draw_loot_group(AMMO_GROUP, AMMO_COLOR)
	_draw_loot_group(HEALTH_GROUP, HEALTH_COLOR)
	_draw_weapon_crates()


func _draw_weapon_crates() -> void:
	for pickup_value in get_tree().get_nodes_in_group(WEAPON_GROUP):
		var pickup := pickup_value as Node3D
		if (
			pickup == null
			or not pickup.visible
			or not _is_inside_world(pickup.global_position)
		):
			continue
		# Upward triangle sets weapon crates apart from the loot diamonds.
		var center := _world_to_map(pickup.global_position)
		draw_colored_polygon(
			PackedVector2Array([
				center + Vector2(0.0, -6.0),
				center + Vector2(6.0, 5.0),
				center + Vector2(-6.0, 5.0),
			]),
			WEAPON_COLOR
		)


func _draw_objectives() -> void:
	for objective_value in get_tree().get_nodes_in_group(OBJECTIVE_GROUP):
		var objective := objective_value as Node3D
		if objective == null or not _is_inside_world(objective.global_position):
			continue
		var center := _world_to_map(objective.global_position)
		draw_arc(center, 7.0, 0.0, TAU, 20, OBJECTIVE_COLOR, 2.0)
		draw_circle(center, 2.5, OBJECTIVE_COLOR)


func _draw_loot_group(group_name: StringName, color: Color) -> void:
	for pickup_value in get_tree().get_nodes_in_group(group_name):
		var pickup := pickup_value as Node3D
		if (
			pickup == null
			or not pickup.visible
			or not _is_inside_world(pickup.global_position)
		):
			continue
		_draw_diamond(_world_to_map(pickup.global_position), 4.5, color)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		]),
		color
	)


func _get_player_sector_coords() -> Vector2i:
	if not is_instance_valid(_player):
		return Vector2i.ZERO
	return Vector2i(
		floori((_player.global_position.x + SECTOR_HALF_SIZE) / SECTOR_SIZE),
		floori((_player.global_position.z + SECTOR_HALF_SIZE) / SECTOR_SIZE)
	)


func _draw_points_of_interest() -> void:
	for point_value in get_tree().get_nodes_in_group(POI_GROUP):
		var point := point_value as Node3D
		if point == null or not _is_inside_world(point.global_position):
			continue
		var map_position := _world_to_map(point.global_position)
		draw_rect(Rect2(map_position - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), POI_COLOR)


func _draw_enemies() -> void:
	for enemy_value in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := enemy_value as Node3D
		if enemy == null or not _is_inside_world(enemy.global_position):
			continue
		draw_circle(_world_to_map(enemy.global_position), 3.5, ENEMY_COLOR)


func _draw_camp() -> void:
	var camp := get_tree().get_first_node_in_group(CAMP_GROUP) as Node3D
	if camp == null:
		return
	var map_position := _world_to_map(camp.global_position)
	draw_rect(Rect2(map_position - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), ACCENT_COLOR)
	draw_rect(
		Rect2(map_position - Vector2(6.0, 6.0), Vector2(12.0, 12.0)),
		TEXT_COLOR,
		false,
		1.5
	)


func _draw_player() -> void:
	if not is_instance_valid(_player):
		_refresh_references()
	if not is_instance_valid(_player):
		return
	var map_position := _world_to_map(_player.global_position)
	var forward_3d := -_player.global_basis.z
	var forward_2d := Vector2(forward_3d.x, forward_3d.z).normalized()
	draw_circle(map_position, 7.0, PLAYER_COLOR)
	draw_circle(map_position, 7.0, TEXT_COLOR, false, 2.0)
	draw_line(map_position, map_position + forward_2d * 16.0, PLAYER_COLOR, 4.0, true)


func _draw_footer(panel_rect: Rect2) -> void:
	var player_coords := _get_player_sector_coords()
	var footer_y := _map_rect.end.y + 30.0
	_draw_text(
		"● PLAYER   ● HOSTILE   ■ CAMP   ■ POI   ◆ SCRAP   ◆ AMMO   ◆ MEDKIT   ▲ WEAPON   ◎ OBJECTIVE",
		Vector2(panel_rect.position.x, footer_y),
		12,
		MUTED_TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x
	)
	_draw_text(
		"CURRENT SECTOR  %d · %d" % [player_coords.x, player_coords.y],
		Vector2(panel_rect.position.x, footer_y + 20.0),
		12,
		ACCENT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x
	)


func _is_sector_loaded(coords: Vector2i) -> bool:
	if coords == CAMP_COORDS:
		return true
	if (
		not is_instance_valid(_world_streamer)
		or not _world_streamer.has_method(&"is_sector_loaded")
	):
		return false
	var sector_id := (
		StringName("east")
		if coords == EAST_COORDS
		else StringName("sector_%d_%d" % [coords.x, coords.y])
	)
	return bool(_world_streamer.call(&"is_sector_loaded", sector_id))


func _world_to_map(world_position: Vector3) -> Vector2:
	var normalized := Vector2(
		inverse_lerp(WORLD_MIN.x, WORLD_MAX.x, world_position.x),
		inverse_lerp(WORLD_MIN.y, WORLD_MAX.y, world_position.z)
	)
	return _map_rect.position + normalized * _map_rect.size


func _is_inside_world(world_position: Vector3) -> bool:
	return (
		world_position.x >= WORLD_MIN.x
		and world_position.x <= WORLD_MAX.x
		and world_position.z >= WORLD_MIN.y
		and world_position.z <= WORLD_MAX.y
	)


func _refresh_references() -> void:
	_player = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	_world_streamer = get_tree().get_first_node_in_group(WORLD_STREAMER_GROUP)


func _draw_text(
	text: String,
	position: Vector2,
	font_size: int,
	color: Color,
	alignment := HORIZONTAL_ALIGNMENT_LEFT,
	width := -1.0
) -> void:
	draw_string(
		ThemeDB.fallback_font,
		position,
		text,
		alignment,
		width,
		font_size,
		color
	)
