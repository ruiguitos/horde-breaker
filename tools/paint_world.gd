extends SceneTree

## Paints every sector of the world into the arena's GridMap layers.
##
## Run:  <godot> --headless --path . --script res://tools/paint_world.gd
##
## Density follows the rings in docs/MAP_DESIGN.md: an open plaza at the centre,
## low suburbs around it, and dense urban plus industrial corners further out.
## Everything written is ordinary GridMap cell data — open the scene and edit it.

const ARENA_PATH := "res://scenes/world/test_arena.tscn"
const LIBRARY_PATH := "res://resources/map_tiles_pack.meshlib"
const CELL_SIZE := Vector3(8.0, 4.0, 8.0)
const SECTOR_CELLS := 8
## Loaded at runtime rather than preloaded: world_streamer.gd references the
## SaveManager autoload, which does not exist yet while a --script tool compiles.
const STREAMER_PATH := "res://scripts/systems/world_streamer.gd"
var _grid_min := Vector2i(-3, -3)
var _grid_max := Vector2i(4, 4)
## The camp sector: left open so the extraction zone stays readable. Must match
## world_streamer.CAMP_COORDS and place_camp.CAMP_COORDS.
const CENTRE := Vector2i(-1, -1)
## Road lane inside every sector. Fixed, so streets run unbroken across borders.
const ROAD_COLUMN := 3
const ROAD_ROW := 3

const ROT_0 := 0
const ROT_90 := 22
const ROT_180 := 10
const ROT_270 := 16

const ROAD_STRAIGHT := "kay_road_straight"
const ROAD_JUNCTION := "kay_road_junction"
const ROAD_TSPLIT := "kay_road_tsplit"
const ROAD_CORNER := "kay_road_corner"
const GROUND := "kay_base"

const URBAN_BUILDINGS: Array[String] = [
	"city_building_a", "city_building_d", "city_building_g",
	"city_building_i", "city_building_j", "city_building_m",
]
const SUBURB_BUILDINGS: Array[String] = [
	"city_building_c", "city_building_e", "kay_building_a", "kay_building_b",
]
const INDUSTRIAL: Array[String] = [
	"ind_building_a", "ind_building_b", "ind_building_c", "ind_building_e",
]
const CARS: Array[String] = ["car_sedan", "car_van", "car_taxi", "car_truck", "car_police"]
const CLUTTER: Array[String] = [
	"env_barrel", "env_container_green", "env_container_red", "env_cinder_block",
]

var _ids: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var arena := (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	if arena == null:
		push_error("Could not instantiate the arena")
		quit(1)
		return
	# Match whatever the streamer actually streams, so the painted area and the
	# loaded area can never drift apart.
	var streamer: GDScript = load(STREAMER_PATH)
	if streamer != null:
		_grid_min = streamer.get(&"GRID_MIN")
		_grid_max = streamer.get(&"GRID_MAX")
	var library: MeshLibrary = load(LIBRARY_PATH)
	for id in library.get_item_list():
		_ids[library.get_item_name(id)] = id

	var roads := _ensure_gridmap(arena, "MapRoads", library)
	var structures := _ensure_gridmap(arena, "MapStructures", library)
	var props := _ensure_gridmap(arena, "MapProps", library)
	roads.clear()
	structures.clear()
	props.clear()

	for sx in range(_grid_min.x, _grid_max.x + 1):
		for sy in range(_grid_min.y, _grid_max.y + 1):
			var coords := Vector2i(sx, sy)
			# Deterministic per sector, so repainting gives the same world.
			_rng.seed = hash(coords) * 7919
			_paint_sector(roads, structures, props, coords)

	var scene := PackedScene.new()
	_reown(arena, arena)
	if scene.pack(arena) != OK or ResourceSaver.save(scene, ARENA_PATH) != OK:
		push_error("Could not save the arena")
		quit(1)
		return
	print("PAINTED: roads=%d structures=%d props=%d over %d sectors" % [
		roads.get_used_cells().size(),
		structures.get_used_cells().size(),
		props.get_used_cells().size(),
		(_grid_max.x - _grid_min.x + 1) * (_grid_max.y - _grid_min.y + 1),
	])
	quit(0)


func _get_ring(coords: Vector2i) -> int:
	# Chebyshev distance from the camp: 0 centre, 1 suburb, 2+ outer.
	return maxi(absi(coords.x - CENTRE.x), absi(coords.y - CENTRE.y))


func _paint_sector(
	roads: GridMap, structures: GridMap, props: GridMap, coords: Vector2i
) -> void:
	var origin := Vector2i(
		coords.x * SECTOR_CELLS - SECTOR_CELLS / 2,
		coords.y * SECTOR_CELLS - SECTOR_CELLS / 2
	)
	var ring := _get_ring(coords)
	# The same column and row in every sector, so roads line up across sector
	# borders into continuous streets. Varying it per sector left the network
	# broken at every seam.
	var road_column := ROAD_COLUMN
	var road_row := ROAD_ROW

	for x in SECTOR_CELLS:
		for z in SECTOR_CELLS:
			var cell := Vector3i(origin.x + x, 0, origin.y + z)
			if x == road_column and z == road_row:
				_place(roads, cell, ROAD_JUNCTION)
			elif x == road_column:
				_place(roads, cell, ROAD_STRAIGHT)
			elif z == road_row:
				_place(roads, cell, ROAD_STRAIGHT, ROT_90)
			else:
				_place(roads, cell, GROUND)

	if ring == 0:
		_paint_camp(props, origin, road_column, road_row)
		return

	var density := 0.3 if ring == 1 else 0.5
	var pool := SUBURB_BUILDINGS if ring == 1 else URBAN_BUILDINGS
	var is_corner := absi(coords.x - CENTRE.x) >= 2 and absi(coords.y - CENTRE.y) >= 2
	if is_corner:
		pool = INDUSTRIAL
		density = 0.4

	for x in SECTOR_CELLS:
		for z in SECTOR_CELLS:
			if x == road_column or z == road_row:
				continue
			# The cells flanking a road stay clear: that is the pavement, and it
			# is where the player runs when the horde is behind.
			if absi(x - road_column) == 1 and absi(z - road_row) == 1:
				continue
			if _rng.randf() > density:
				continue
			var choice: String = pool[_rng.randi_range(0, pool.size() - 1)]
			_place(
				structures, Vector3i(origin.x + x, 0, origin.y + z),
				choice, _random_rotation()
			)

	# One landmark per sector, so the player can orient without the map.
	var landmark_x := 0 if road_column > 3 else 7
	var landmark_z := 0 if road_row > 3 else 7
	_place(
		structures,
		Vector3i(origin.x + landmark_x, 0, origin.y + landmark_z),
		"env_water_tower" if ring >= 2 else "forest_tree"
	)

	_scatter_props(props, origin, road_column, road_row, ring)


func _paint_camp(props: GridMap, origin: Vector2i, column: int, row: int) -> void:
	# The camp sector stays deliberately open: it is the extraction zone and the
	# one place where the horde has to be visible coming from every side.
	# Corners only. The middle stays completely clear: the player spawns there,
	# and a prop on the spawn cell ends up sitting on top of them.
	var corners: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 7), Vector2i(7, 7)
	]
	for corner in corners:
		_place(
			props, Vector3i(origin.x + corner.x, 0, origin.y + corner.y),
			"env_container_green", _random_rotation()
		)


func _scatter_props(
	props: GridMap, origin: Vector2i, column: int, row: int, ring: int
) -> void:
	# Wrecks go on the roads, where they split the horde and give cover.
	for index in (2 if ring == 1 else 3):
		var along := _rng.randi_range(0, SECTOR_CELLS - 1)
		if along == row:
			continue
		_place(
			props, Vector3i(origin.x + column, 0, origin.y + along),
			CARS[_rng.randi_range(0, CARS.size() - 1)], _random_rotation()
		)
	for index in 3:
		var x := _rng.randi_range(0, SECTOR_CELLS - 1)
		var z := _rng.randi_range(0, SECTOR_CELLS - 1)
		if x == column or z == row:
			continue
		_place(
			props, Vector3i(origin.x + x, 0, origin.y + z),
			CLUTTER[_rng.randi_range(0, CLUTTER.size() - 1)], _random_rotation()
		)


func _random_rotation() -> int:
	return [ROT_0, ROT_90, ROT_180, ROT_270][_rng.randi_range(0, 3)]


func _place(grid: GridMap, cell: Vector3i, tile_name: String, rotation: int = ROT_0) -> void:
	if not _ids.has(tile_name):
		push_warning("Tile not in the library: %s" % tile_name)
		return
	grid.set_cell_item(cell, int(_ids[tile_name]), rotation)


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
	grid.cell_center_x = true
	grid.cell_center_y = false
	grid.cell_center_z = true
	grid.add_to_group(GridMapObstacles.GRIDMAP_GROUP, true)
	arena.add_child(grid)
	return grid


func _reown(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner_node
		_reown(child, owner_node)
