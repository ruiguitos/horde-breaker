class_name ArchipelagoGraphMap
extends Control

const PANEL_COLOR := Color(0.025, 0.035, 0.04, 0.94)
const BORDER_COLOR := Color(0.28, 0.36, 0.4, 0.9)
const TEXT_COLOR := Color(0.93, 0.94, 0.9)
const MUTED_COLOR := Color(0.56, 0.63, 0.66)
const ROUTE_COLOR := Color(0.3, 0.48, 0.55)
const VISITED_COLOR := Color(0.2, 0.68, 0.58)
const CURRENT_COLOR := Color(0.95, 0.48, 0.1)
const BOSS_COLOR := Color(0.75, 0.18, 0.12)

var archipelago_data: ArchipelagoData
var current_island_id: StringName = &""
var visited_islands: Dictionary[StringName, bool] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(data: ArchipelagoData) -> void:
	archipelago_data = data
	queue_redraw()


func set_current_island(island_id: StringName) -> void:
	current_island_id = island_id
	if island_id != &"":
		visited_islands[island_id] = true
	queue_redraw()


func get_node_count() -> int:
	return archipelago_data.islands.size() if archipelago_data != null else 0


func get_route_count() -> int:
	return archipelago_data.routes.size() if archipelago_data != null else 0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 4.0)), CURRENT_COLOR)
	_draw_text("DESTINY ARCHIPELAGO", Vector2(18.0, 28.0), 20, TEXT_COLOR)
	_draw_text("ROUTE NETWORK // LIVE PROTOTYPE", Vector2(18.0, 48.0), 11, MUTED_COLOR)
	if archipelago_data == null:
		return
	for route in archipelago_data.routes:
		_draw_route(route)
	for island in archipelago_data.islands:
		_draw_island(island)


func _draw_route(route: IslandRouteData) -> void:
	var source := archipelago_data.get_island(route.source_island_id)
	var destination := archipelago_data.get_island(route.destination_island_id)
	if source == null or destination == null:
		return
	var start := _map_point(source.map_position)
	var end := _map_point(destination.map_position)
	draw_line(start, end, ROUTE_COLOR, 3.0, true)
	var midpoint := start.lerp(end, 0.5)
	var route_letter := route.display_name.trim_prefix("Route ").get_slice(":", 0)
	draw_circle(midpoint, 9.0, PANEL_COLOR)
	draw_circle(midpoint, 9.0, ROUTE_COLOR, false, 2.0)
	_draw_text(route_letter, midpoint + Vector2(-4.0, 4.0), 11, TEXT_COLOR)


func _draw_island(island: IslandData) -> void:
	var center := _map_point(island.map_position)
	var color := Color(0.13, 0.18, 0.2)
	if island.island_id == &"volcano_peak":
		color = BOSS_COLOR
	if visited_islands.has(island.island_id):
		color = VISITED_COLOR
	if island.island_id == current_island_id:
		color = CURRENT_COLOR
	draw_circle(center, 15.0, color)
	draw_circle(center, 15.0, TEXT_COLOR, false, 2.0)
	var title := island.display_name.to_upper()
	if island.island_id == &"volcano_peak":
		title += " // BOSS"
	_draw_text(title, center + Vector2(-52.0, 34.0), 11, TEXT_COLOR)
	_draw_text(island.difficulty.to_upper(), center + Vector2(-28.0, 49.0), 9, MUTED_COLOR)


func _map_point(normalized: Vector2) -> Vector2:
	return Vector2(22.0, 55.0) + normalized * Vector2(size.x - 44.0, size.y - 112.0)


func _draw_text(text: String, position: Vector2, font_size: int, color: Color) -> void:
	draw_string(
		get_theme_default_font(), position, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color
	)
