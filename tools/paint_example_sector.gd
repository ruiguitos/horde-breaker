extends SceneTree

## Paints one example sector into the arena's GridMaps so the tile set can be
## judged at real scale. It is a starting point to edit in the editor, not a
## generator: everything it writes is ordinary GridMap cell data.
##
## Run:  <godot> --headless --path . --script res://tools/paint_example_sector.gd
##
## Layout follows docs/MAP_DESIGN.md: a crossroads through the middle, pavement
## framing four blocks, buildings inside the blocks, and a landmark to navigate
## by. The camp sector (0,0) is left alone.

const ARENA_PATH := "res://scenes/world/test_arena.tscn"
const LIBRARY_PATH := "res://resources/map_tiles.meshlib"
const CELL_SIZE := Vector3(8.0, 4.0, 8.0)
## Sector (1, 0), east of the camp: cells 8..15 on x, 0..7 on z.
const SECTOR_ORIGIN := Vector2i(8, 0)
const SECTOR_CELLS := 8

# Rotation helpers: GridMap orientations are indices into a basis table.
const ROT_0 := 0
const ROT_90 := 22
const ROT_180 := 10
const ROT_270 := 16


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load(ARENA_PATH)
	var arena := packed.instantiate() as Node3D
	if arena == null:
		push_error("Could not instantiate the arena")
		quit(1)
		return
	var library: MeshLibrary = load(LIBRARY_PATH)
	var ids := _index_library(library)

	var roads := _ensure_gridmap(arena, "MapRoads", library)
	var structures := _ensure_gridmap(arena, "MapStructures", library)
	var props := _ensure_gridmap(arena, "MapProps", library)
	roads.clear()
	structures.clear()
	props.clear()

	_paint_sector(roads, structures, props, ids)

	var scene := PackedScene.new()
	_reown(arena, arena)
	if scene.pack(arena) != OK:
		push_error("Could not pack the arena")
		quit(1)
		return
	var error := ResourceSaver.save(scene, ARENA_PATH)
	if error != OK:
		push_error("Could not save the arena: %d" % error)
		quit(1)
		return
	print("PAINTED: roads=%d structures=%d props=%d" % [
		roads.get_used_cells().size(),
		structures.get_used_cells().size(),
		props.get_used_cells().size(),
	])
	quit(0)


func _paint_sector(
	roads: GridMap, structures: GridMap, props: GridMap, ids: Dictionary
) -> void:
	var origin := SECTOR_ORIGIN
	# Two roads crossing the sector: column 3 north-south, row 3 east-west.
	var road_column := 3
	var road_row := 3
	for x in SECTOR_CELLS:
		for z in SECTOR_CELLS:
			var cell := Vector3i(origin.x + x, 0, origin.y + z)
			var on_column := x == road_column
			var on_row := z == road_row
			if on_column and on_row:
				roads.set_cell_item(cell, ids["road_crossing"], ROT_0)
			elif on_column:
				roads.set_cell_item(cell, ids["road_straight"], ROT_0)
			elif on_row:
				roads.set_cell_item(cell, ids["road_straight"], ROT_90)
			elif _is_pavement(x, z, road_column, road_row):
				roads.set_cell_item(cell, ids["sidewalk"], _pavement_rotation(
					x, z, road_column, road_row
				))

	# Four blocks, each with a couple of buildings and a warehouse in one.
	_place(structures, origin, 1, 1, ids["building_medium"])
	_place(structures, origin, 1, 5, ids["building_small"])
	_place(structures, origin, 5, 1, ids["building_tall"])
	_place(structures, origin, 6, 5, ids["warehouse"], ROT_180)
	_place(structures, origin, 0, 0, ids["building_small"])
	_place(structures, origin, 6, 0, ids["building_medium"])

	# Landmark for orientation, per the design rules.
	_place(structures, origin, 0, 6, ids["water_tower"])

	# Props: wrecks funnel movement on the roads, debris dresses the corners.
	_place(props, origin, road_column, 1, ids["car_wreck"])
	_place(props, origin, road_column, 6, ids["car_wreck"], ROT_180)
	_place(props, origin, 6, road_row, ids["car_wreck"], ROT_90)
	_place(props, origin, 2, road_row, ids["barricade"], ROT_90)
	_place(props, origin, 5, 6, ids["container"])
	_place(props, origin, 2, 2, ids["rubble"])
	_place(props, origin, 7, 2, ids["rubble"])
	_place(props, origin, 0, 4, ids["tree"])
	_place(props, origin, 4, 7, ids["tree"])


func _is_pavement(x: int, z: int, column: int, row: int) -> bool:
	return (
		absi(x - column) == 1 or absi(z - row) == 1
	)


func _pavement_rotation(x: int, z: int, column: int, row: int) -> int:
	if x == column - 1:
		return ROT_270
	if x == column + 1:
		return ROT_90
	if z == row - 1:
		return ROT_0
	return ROT_180


func _place(
	grid: GridMap,
	origin: Vector2i,
	x: int,
	z: int,
	item: int,
	rotation: int = ROT_0
) -> void:
	grid.set_cell_item(Vector3i(origin.x + x, 0, origin.y + z), item, rotation)


func _ensure_gridmap(arena: Node3D, node_name: String, library: MeshLibrary) -> GridMap:
	var existing := arena.get_node_or_null(node_name) as GridMap
	if existing != null:
		existing.mesh_library = library
		existing.cell_size = CELL_SIZE
		return existing
	var grid := GridMap.new()
	grid.name = node_name
	grid.mesh_library = library
	grid.cell_size = CELL_SIZE
	# Cells are addressed by their corner, so a tile authored around its own
	# origin lands centred on the cell.
	grid.cell_center_x = true
	grid.cell_center_y = false
	grid.cell_center_z = true
	arena.add_child(grid)
	return grid


func _index_library(library: MeshLibrary) -> Dictionary:
	var ids: Dictionary = {}
	for id in library.get_item_list():
		ids[library.get_item_name(id)] = id
	return ids


func _reown(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner_node
		_reown(child, owner_node)
