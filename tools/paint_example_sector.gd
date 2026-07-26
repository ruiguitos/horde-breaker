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
const LIBRARY_PATH := "res://resources/map_tiles_pack.meshlib"
const CELL_SIZE := Vector3(8.0, 4.0, 8.0)
## Which sector to paint, in the streamer's coordinates. (1, 0) is east of camp.
const SECTOR_COORDS := Vector2i(1, 0)
## A 64 m sector is 8 cells of 8 m. Sector (sx, sy) is centred on
## (sx * 64, sy * 64), so it spans cells sx * 8 - 4 .. sx * 8 + 3 on each axis.
const SECTOR_CELLS := 8
const SECTOR_ORIGIN := Vector2i(
	SECTOR_COORDS.x * SECTOR_CELLS - SECTOR_CELLS / 2,
	SECTOR_COORDS.y * SECTOR_CELLS - SECTOR_CELLS / 2
)

# Rotation helpers: GridMap orientations are indices into a basis table.
const ROT_0 := 0
const ROT_90 := 22
const ROT_180 := 10
const ROT_270 := 16

## Tiles used, by role. KayKit road pieces are exactly 8 x 8 m once scaled, so
## they land on the cell without any fitting.
const ROAD_STRAIGHT := "kay_road_straight"
const ROAD_JUNCTION := "kay_road_junction"
const GROUND := "kay_base"
const BUILDINGS: Array[String] = [
	"city_building_a", "city_building_d", "city_building_g",
	"city_building_i", "city_building_m",
]
const WAREHOUSES: Array[String] = ["ind_building_a", "ind_building_c"]
const CARS: Array[String] = ["car_sedan", "car_van", "car_taxi", "car_truck"]


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
	# The library changed, so old indices would point at unrelated tiles.
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260726
	var road_column := 3
	var road_row := 3
	for x in SECTOR_CELLS:
		for z in SECTOR_CELLS:
			var cell := _cell(x, z)
			var on_column := x == road_column
			var on_row := z == road_row
			if on_column and on_row:
				_place(roads, cell, ids, ROAD_JUNCTION)
			elif on_column:
				_place(roads, cell, ids, ROAD_STRAIGHT)
			elif on_row:
				_place(roads, cell, ids, ROAD_STRAIGHT, ROT_90)
			else:
				_place(roads, cell, ids, GROUND)

	# Buildings fill the four blocks the roads carve out, one per cell so the
	# streets stay clear.
	for x in SECTOR_CELLS:
		for z in SECTOR_CELLS:
			if x == road_column or z == road_row:
				continue
			# Leave the cells next to the road free: that is the pavement, and
			# it is where the player runs.
			if absi(x - road_column) == 1 and absi(z - road_row) == 1:
				continue
			if rng.randf() > 0.55:
				continue
			var choice: String = BUILDINGS[rng.randi_range(0, BUILDINGS.size() - 1)]
			_place(structures, _cell(x, z), ids, choice, _random_rotation(rng))

	# One warehouse per sector: the interior arena the design asks for.
	_place(structures, _cell(6, 6), ids, WAREHOUSES[0], ROT_180)
	# A landmark to navigate by, per the design rules.
	_place(structures, _cell(0, 0), ids, "env_water_tower")

	# Wrecks on the roads funnel movement; debris dresses the rest.
	_place(props, _cell(road_column, 1), ids, CARS[0])
	_place(props, _cell(road_column, 6), ids, CARS[1], ROT_180)
	_place(props, _cell(6, road_row), ids, CARS[2], ROT_90)
	_place(props, _cell(1, road_row), ids, CARS[3], ROT_270)
	_place(props, _cell(5, 1), ids, "env_container_green")
	_place(props, _cell(2, 5), ids, "env_container_red", ROT_90)
	_place(props, _cell(2, 2), ids, "env_barrel")
	_place(props, _cell(7, 4), ids, "env_barrel")
	_place(props, _cell(0, 5), ids, "env_street_lights")
	_place(props, _cell(5, 0), ids, "env_street_lights", ROT_180)


func _cell(x: int, z: int) -> Vector3i:
	return Vector3i(SECTOR_ORIGIN.x + x, 0, SECTOR_ORIGIN.y + z)


func _random_rotation(rng: RandomNumberGenerator) -> int:
	return [ROT_0, ROT_90, ROT_180, ROT_270][rng.randi_range(0, 3)]


func _place(
	grid: GridMap,
	cell: Vector3i,
	ids: Dictionary,
	tile_name: String,
	rotation: int = ROT_0
) -> void:
	if not ids.has(tile_name):
		push_warning("Tile not in the library: %s" % tile_name)
		return
	grid.set_cell_item(cell, int(ids[tile_name]), rotation)


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
	# The navigation bakers find painted tiles through this group.
	grid.add_to_group(GridMapObstacles.GRIDMAP_GROUP, true)
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
