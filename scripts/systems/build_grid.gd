class_name BuildGrid
extends Node3D

@export var grid_size: Vector2i = Vector2i(14, 14)
@export_range(0.5, 5.0, 0.5) var cell_size: float = 2.0
@export_range(0, 5, 1) var reserved_center_radius: int = 2

var occupied_cells: Dictionary = {}
var _grid_visual: MeshInstance3D


func _ready() -> void:
	_create_grid_visual()
	set_grid_visible(false)


func world_to_grid(world_position: Vector3) -> Vector2i:
	var local := to_local(world_position)
	return Vector2i(
		floori(local.x / cell_size),
		floori(local.z / cell_size)
	)


func grid_to_world(grid_position: Vector2i) -> Vector3:
	return to_global(
		Vector3(
			(grid_position.x + 0.5) * cell_size,
			0.0,
			(grid_position.y + 0.5) * cell_size
		)
	)


func get_placement_world(grid_position: Vector2i, footprint: Vector2i) -> Vector3:
	var local_center := Vector3(
		(grid_position.x + float(footprint.x) * 0.5) * cell_size,
		0.0,
		(grid_position.y + float(footprint.y) * 0.5) * cell_size
	)
	return to_global(local_center)


func get_rotated_size(base_size: Vector2i, rotation_steps: int) -> Vector2i:
	return base_size if posmod(rotation_steps, 2) == 0 else Vector2i(base_size.y, base_size.x)


func is_cell_free(grid_position: Vector2i, footprint: Vector2i = Vector2i.ONE) -> bool:
	for offset_x in range(footprint.x):
		for offset_y in range(footprint.y):
			var cell := grid_position + Vector2i(offset_x, offset_y)
			if not _is_within_bounds(cell) or _is_reserved(cell):
				return false
			if occupied_cells.has(cell):
				return false
	return true


func occupy_cells(
	grid_position: Vector2i, footprint: Vector2i, structure: StructureBase
) -> void:
	for offset_x in range(footprint.x):
		for offset_y in range(footprint.y):
			occupied_cells[grid_position + Vector2i(offset_x, offset_y)] = structure


func free_structure(structure: StructureBase) -> void:
	for cell in occupied_cells.keys():
		if occupied_cells[cell] == structure:
			occupied_cells.erase(cell)


func set_grid_visible(is_visible: bool) -> void:
	if _grid_visual != null:
		_grid_visual.visible = is_visible


func _is_within_bounds(cell: Vector2i) -> bool:
	var minimum := Vector2i(
		floori(-float(grid_size.x) * 0.5),
		floori(-float(grid_size.y) * 0.5)
	)
	var maximum := minimum + grid_size
	return (
		cell.x >= minimum.x and cell.x < maximum.x
		and cell.y >= minimum.y and cell.y < maximum.y
	)


func _is_reserved(cell: Vector2i) -> bool:
	return (
		absi(cell.x) <= reserved_center_radius
		and absi(cell.y) <= reserved_center_radius
	)


func _create_grid_visual() -> void:
	var immediate_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.25, 0.82, 1.0, 0.42)
	material.no_depth_test = true
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var half_x := grid_size.x * cell_size * 0.5
	var half_z := grid_size.y * cell_size * 0.5
	for line_x in range(grid_size.x + 1):
		var x := -half_x + line_x * cell_size
		immediate_mesh.surface_add_vertex(Vector3(x, 0.04, -half_z))
		immediate_mesh.surface_add_vertex(Vector3(x, 0.04, half_z))
	for line_z in range(grid_size.y + 1):
		var z := -half_z + line_z * cell_size
		immediate_mesh.surface_add_vertex(Vector3(-half_x, 0.04, z))
		immediate_mesh.surface_add_vertex(Vector3(half_x, 0.04, z))
	immediate_mesh.surface_end()
	_grid_visual = MeshInstance3D.new()
	_grid_visual.name = "GridVisual"
	_grid_visual.mesh = immediate_mesh
	add_child(_grid_visual)
