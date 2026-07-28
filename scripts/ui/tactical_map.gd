extends Control

const PLAYER_GROUP := &"player"
const CAMP_GROUP := &"camp_core"
const ENEMY_GROUP := &"enemy"
const POI_GROUP := &"point_of_interest"
const WORLD_STREAMER_GROUP := &"world_streamer"
## World bounds are read from the streamer at runtime, not preloaded: it
## references the SaveManager autoload, and a preload of it from a --script tool
## compiles before the autoloads exist, which leaves the script broken for
## everyone who loads it afterwards.
##
## These were hard-coded copies before, and went stale the moment the world grew
## to 8x8 and the camp moved: the map was still drawing a 4x4, 256 m world with
## its base at the origin.
const STREAMER_PATH := "res://scripts/systems/world_streamer.gd"

var SECTOR_SIZE: float = 64.0
var SECTOR_HALF_SIZE: float = 32.0
var GRID_MIN := Vector2i(-3, -3)
var GRID_MAX := Vector2i(4, 4)
var CAMP_COORDS := Vector2i(-1, -1)
var WORLD_MIN := Vector2(-224.0, -224.0)
var WORLD_MAX := Vector2(288.0, 288.0)


func _read_world_bounds() -> void:
	var streamer: GDScript = load(STREAMER_PATH)
	if streamer == null:
		return
	SECTOR_SIZE = float(streamer.get(&"SECTOR_SIZE"))
	SECTOR_HALF_SIZE = SECTOR_SIZE * 0.5
	GRID_MIN = streamer.get(&"GRID_MIN")
	GRID_MAX = streamer.get(&"GRID_MAX")
	CAMP_COORDS = streamer.get(&"CAMP_COORDS")
	WORLD_MIN = Vector2(
		float(GRID_MIN.x) * SECTOR_SIZE - SECTOR_HALF_SIZE,
		float(GRID_MIN.y) * SECTOR_SIZE - SECTOR_HALF_SIZE
	)
	WORLD_MAX = Vector2(
		float(GRID_MAX.x) * SECTOR_SIZE + SECTOR_HALF_SIZE,
		float(GRID_MAX.y) * SECTOR_SIZE + SECTOR_HALF_SIZE
	)
const PANEL_COLOR := Color(0.025, 0.039, 0.055, 0.96)
const MAP_COLOR := Color(0.045, 0.067, 0.086, 1.0)
const SECTOR_COLOR := Color(0.075, 0.11, 0.135, 1.0)
const LOADED_SECTOR_COLOR := Color(0.16, 0.24, 0.28, 1.0)
const CAMP_SECTOR_COLOR := Color(0.31, 0.20, 0.09, 1.0)
const BORDER_COLOR := Color(0.31, 0.40, 0.45, 0.62)
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
var _open_tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_read_world_bounds()
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
		_animate_open()
	else:
		modulate.a = 1.0
	get_viewport().set_input_as_handled()


func _animate_open() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tween.set_trans(Tween.TRANS_QUAD)
	_open_tween.set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(self, "modulate:a", 1.0, 0.16)


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
		_map_rect.size + Vector2(48.0, 150.0)
	)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.52))
	var panel_style := get_theme_stylebox(&"panel", &"MenuPanel")
	if panel_style != null:
		draw_style_box(panel_style, panel_rect)
	else:
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
			draw_rect(sector_rect.grow(-2.0), fill_color)
			if coords == player_coords:
				draw_rect(sector_rect.grow(-1.0), ACCENT_COLOR, false, 2.0)
				draw_rect(
					sector_rect.grow(-5.0),
					Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.42),
					false,
					1.0
				)
			else:
				draw_rect(sector_rect, BORDER_COLOR, false, 0.75)
			var sector_label := "BASE" if coords == CAMP_COORDS else "%d · %d" % [grid_x, grid_z]
			_draw_text(
				sector_label,
				sector_rect.position + Vector2(6.0, 17.0),
				11,
				MUTED_TEXT_COLOR
			)


func _draw_loot() -> void:
	_draw_loot_group(SCRAP_GROUP, SCRAP_COLOR, &"scrap")
	_draw_loot_group(AMMO_GROUP, AMMO_COLOR, &"ammo")
	_draw_loot_group(HEALTH_GROUP, HEALTH_COLOR, &"health")
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


func _draw_loot_group(
	group_name: StringName, color: Color, marker_type: StringName
) -> void:
	for pickup_value in get_tree().get_nodes_in_group(group_name):
		var pickup := pickup_value as Node3D
		if (
			pickup == null
			or not pickup.visible
			or not _is_inside_world(pickup.global_position)
		):
			continue
		_draw_marker(_world_to_map(pickup.global_position), marker_type, color)


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


func _draw_marker(
	center: Vector2, marker_type: StringName, color: Color
) -> void:
	match marker_type:
		&"scrap":
			_draw_diamond(center, 4.5, color)
		&"ammo":
			draw_rect(Rect2(center + Vector2(-5.0, -4.0), Vector2(3.0, 8.0)), color)
			draw_rect(Rect2(center + Vector2(2.0, -4.0), Vector2(3.0, 8.0)), color)
		&"health":
			draw_rect(Rect2(center + Vector2(-5.0, -1.5), Vector2(10.0, 3.0)), color)
			draw_rect(Rect2(center + Vector2(-1.5, -5.0), Vector2(3.0, 10.0)), color)
		&"weapon":
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(0.0, -5.5),
					center + Vector2(5.5, 5.0),
					center + Vector2(-5.5, 5.0),
				]),
				color
			)
		&"objective":
			draw_arc(center, 5.5, 0.0, TAU, 16, color, 1.5)
			draw_circle(center, 1.8, color)
		&"camp":
			draw_rect(Rect2(center - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), color)
		&"poi":
			draw_rect(
				Rect2(center - Vector2(4.5, 4.5), Vector2(9.0, 9.0)),
				color,
				false,
				1.5
			)
			draw_circle(center, 1.6, color)
		&"enemy":
			draw_circle(center, 4.0, color)
			draw_line(center + Vector2(-2.0, 0.0), center + Vector2(2.0, 0.0), TEXT_COLOR, 1.0)
			draw_line(center + Vector2(0.0, -2.0), center + Vector2(0.0, 2.0), TEXT_COLOR, 1.0)
		&"player":
			draw_circle(center, 4.5, color)
			draw_circle(center, 4.5, TEXT_COLOR, false, 1.2)


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
		draw_rect(
			Rect2(map_position - Vector2(4.5, 4.5), Vector2(9.0, 9.0)),
			POI_COLOR,
			false,
			1.5
		)
		draw_circle(map_position, 1.8, POI_COLOR)


func _draw_enemies() -> void:
	for enemy_value in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := enemy_value as Node3D
		if enemy == null or not _is_inside_world(enemy.global_position):
			continue
		var center := _world_to_map(enemy.global_position)
		draw_circle(center, 4.0, ENEMY_COLOR)
		draw_line(center + Vector2(-2.0, 0.0), center + Vector2(2.0, 0.0), TEXT_COLOR, 1.0)
		draw_line(center + Vector2(0.0, -2.0), center + Vector2(0.0, 2.0), TEXT_COLOR, 1.0)


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
	var footer_y := _map_rect.end.y + 18.0
	var content_width := panel_rect.size.x - 36.0
	var first_item_width := content_width / 5.0
	var second_item_width := content_width / 4.0
	var first_row_x := panel_rect.position.x + 18.0
	var second_row_x := panel_rect.position.x + 18.0
	_draw_legend_item(Vector2(first_row_x, footer_y), first_item_width, &"player", "PLAYER", PLAYER_COLOR)
	_draw_legend_item(Vector2(first_row_x + first_item_width, footer_y), first_item_width, &"enemy", "HOSTILE", ENEMY_COLOR)
	_draw_legend_item(Vector2(first_row_x + first_item_width * 2.0, footer_y), first_item_width, &"camp", "CAMP", ACCENT_COLOR)
	_draw_legend_item(Vector2(first_row_x + first_item_width * 3.0, footer_y), first_item_width, &"poi", "POI", POI_COLOR)
	_draw_legend_item(Vector2(first_row_x + first_item_width * 4.0, footer_y), first_item_width, &"scrap", "SCRAP", SCRAP_COLOR)
	_draw_legend_item(Vector2(second_row_x, footer_y + 18.0), second_item_width, &"ammo", "AMMO", AMMO_COLOR)
	_draw_legend_item(Vector2(second_row_x + second_item_width, footer_y + 18.0), second_item_width, &"health", "MEDKIT", HEALTH_COLOR)
	_draw_legend_item(Vector2(second_row_x + second_item_width * 2.0, footer_y + 18.0), second_item_width, &"weapon", "WEAPON", WEAPON_COLOR)
	_draw_legend_item(Vector2(second_row_x + second_item_width * 3.0, footer_y + 18.0), second_item_width, &"objective", "OBJECTIVE", OBJECTIVE_COLOR)
	_draw_text(
		"CURRENT SECTOR  %d · %d" % [player_coords.x, player_coords.y],
		Vector2(panel_rect.position.x, footer_y + 40.0),
		12,
		ACCENT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x
	)


func _draw_legend_item(
	origin: Vector2,
	item_width: float,
	marker_type: StringName,
	label: String,
	color: Color
) -> void:
	_draw_marker(origin + Vector2(7.0, -3.5), marker_type, color)
	_draw_text(
		label,
		origin + Vector2(17.0, 0.0),
		10,
		MUTED_TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT,
		item_width - 18.0
	)


func _is_sector_loaded(coords: Vector2i) -> bool:
	if coords == CAMP_COORDS:
		return true
	if (
		not is_instance_valid(_world_streamer)
		or not _world_streamer.has_method(&"is_sector_loaded")
	):
		return false
	# The hand-made east sector is gone; every chunk is generated now.
	return bool(_world_streamer.call(
		&"is_sector_loaded", StringName("sector_%d_%d" % [coords.x, coords.y])
	))


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
		get_theme_default_font(),
		position,
		text,
		alignment,
		width,
		font_size,
		color
	)
