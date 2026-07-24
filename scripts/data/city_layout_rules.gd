class_name CityLayoutRules
extends Resource

@export_range(2.0, 16.0, 0.5) var road_width: float = 8.0
@export_range(0.0, 16.0, 0.5) var edge_connector_jitter: float = 0.0
@export_range(1.0, 32.0, 0.5) var minimum_segment_length: float = 4.0
@export_range(0.1, 5.0, 0.1) var debug_node_marker_size: float = 0.6
@export var debug_line_color: Color = Color(0.2, 1.0, 0.4, 0.9)
@export var debug_center_node_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var debug_boundary_connected_color: Color = Color(0.2, 0.7, 1.0, 0.9)
@export var debug_boundary_dead_end_color: Color = Color(1.0, 0.85, 0.1, 0.9)
@export var debug_validation_error_color: Color = Color(1.0, 0.15, 0.15, 1.0)
