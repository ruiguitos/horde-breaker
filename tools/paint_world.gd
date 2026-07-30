extends SceneTree

## Paints every sector of the world into the arena's GridMap layers.
##
## Run:  <godot> --headless --path . --script res://tools/paint_world.gd
##
## Density follows the rings in docs/MAP_DESIGN.md: an open plaza at the centre,
## low suburbs around it, and dense urban plus industrial corners further out.
## Everything written is ordinary GridMap cell data — open the scene and edit it.
##
## Tiles are not all one cell wide. Six of the ones used here measure between
## 9.8 m and 12.6 m against an 8 m cell (the industrial blocks worst of all), so
## painting neighbouring cells drove them through each other and out over the
## pavement. Structures are therefore placed against an occupancy map that
## reserves the cells a tile actually covers, seeded with the road network before
## anything is built and shared across sector borders so the seams line up too.

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

## Points of interest: a compound of real pieces around an open yard, one per
## landmark sector. Two of each kind, spread so no single push out of the camp
## sweeps them all, and none of them next door to the camp.
const POINTS_OF_INTEREST: Array[Dictionary] = [
	{"coords": Vector2i(2, -3), "kind": "warehouse"},
	{"coords": Vector2i(-2, 4), "kind": "warehouse"},
	{"coords": Vector2i(-3, 1), "kind": "military_outpost"},
	{"coords": Vector2i(4, -1), "kind": "military_outpost"},
	{"coords": Vector2i(3, 3), "kind": "fuel_station"},
	{"coords": Vector2i(0, 2), "kind": "fuel_station"},
]
## The compound fills the quadrant away from the crossroads: cells 4..7 on both
## axes. Only tiles that fit inside a cell are used here, so the yard stays clear
## and the encounter trigger is never buried.
const POI_CELL_MIN := 4
const POI_CELL_MAX := 7
## Yard centre, in metres from the sector centre. place_pois.gd reads this to put
## the encounter where the buildings leave room for it.
const POI_YARD_OFFSET := Vector2(12.0, 12.0)
## The compound is laid out cell by cell, so every piece in it has to stay inside
## its own cell. That rules out the whole ind_building_* family the first sketch
## reached for: they are modelled off-centre and hang up to 7.5 m out of an 8 m
## cell, which put the warehouse's own walls through each other. The kit still
## carries the industrial read through the chimneys and tanks.
const POI_TILES := {
	"warehouse": {
		"back": ["kay_building_a", "kay_building_b", "city_building_m"],
		"side": ["kay_building_b", "city_building_i"],
		"props": ["env_container_green", "env_container_red"],
	},
	"military_outpost": {
		"back": ["city_building_d", "kay_building_a", "city_building_d"],
		"side": ["fac_hopper_high_square", "fac_hopper_square"],
		"props": ["env_container_green", "car_truck"],
	},
	"fuel_station": {
		"back": ["ind_chimney_large", "city_building_a", "ind_chimney_large"],
		"side": ["ind_detail_tank", "city_building_g"],
		"props": ["env_barrel", "car_van"],
	},
}

var _ids: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _library: MeshLibrary
## Cells already claimed, in world cell coordinates. Kept for the whole world
## rather than per sector so a wide building on a border cannot land on top of
## its neighbour across the seam.
var _occupied: Dictionary[Vector2i, bool] = {}
## How many cells each tile covers, worked out from its mesh once per tile.
var _footprints: Dictionary[String, Vector2i] = {}


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
	_library = load(LIBRARY_PATH)
	for id in _library.get_item_list():
		_ids[_library.get_item_name(id)] = id

	var roads := _ensure_gridmap(arena, "MapRoads", _library)
	var structures := _ensure_gridmap(arena, "MapStructures", _library)
	var props := _ensure_gridmap(arena, "MapProps", _library)
	roads.clear()
	structures.clear()
	props.clear()
	_occupied.clear()

	# Roads first, for the whole world: they decide where nothing may be built,
	# and a building is only safe to place once every street is known.
	for sx in range(_grid_min.x, _grid_max.x + 1):
		for sy in range(_grid_min.y, _grid_max.y + 1):
			_paint_roads(roads, Vector2i(sx, sy))
	var poi_count := 0
	for sx in range(_grid_min.x, _grid_max.x + 1):
		for sy in range(_grid_min.y, _grid_max.y + 1):
			var coords := Vector2i(sx, sy)
			# Deterministic per sector, so repainting gives the same world.
			_rng.seed = hash(coords) * 7919
			if _paint_sector(structures, props, coords):
				poi_count += 1

	var scene := PackedScene.new()
	_reown(arena, arena)
	if scene.pack(arena) != OK or ResourceSaver.save(scene, ARENA_PATH) != OK:
		push_error("Could not save the arena")
		arena.free()
		quit(1)
		return
	print("PAINTED: roads=%d structures=%d props=%d over %d sectors (%d POIs)" % [
		roads.get_used_cells().size(),
		structures.get_used_cells().size(),
		props.get_used_cells().size(),
		(_grid_max.x - _grid_min.x + 1) * (_grid_max.y - _grid_min.y + 1),
		poi_count,
	])
	# Freeing the arena keeps the tool from ending on a wall of leaked-RID errors,
	# which is noise in exactly the logs used to spot real ones.
	arena.free()
	quit(0)


func _get_ring(coords: Vector2i) -> int:
	# Chebyshev distance from the camp: 0 centre, 1 suburb, 2+ outer.
	return maxi(absi(coords.x - CENTRE.x), absi(coords.y - CENTRE.y))


func _get_sector_origin(coords: Vector2i) -> Vector2i:
	return Vector2i(
		coords.x * SECTOR_CELLS - SECTOR_CELLS / 2,
		coords.y * SECTOR_CELLS - SECTOR_CELLS / 2
	)


## Returns the POI kind painted in this sector, or an empty string.
func _get_poi_kind(coords: Vector2i) -> String:
	for entry in POINTS_OF_INTEREST:
		if Vector2i(entry["coords"]) == coords:
			return String(entry["kind"])
	return ""


func _paint_roads(roads: GridMap, coords: Vector2i) -> void:
	var origin := _get_sector_origin(coords)
	for x in SECTOR_CELLS:
		for z in SECTOR_CELLS:
			var cell := Vector3i(origin.x + x, 0, origin.y + z)
			if x == ROAD_COLUMN and z == ROAD_ROW:
				_place(roads, cell, ROAD_JUNCTION)
			elif x == ROAD_COLUMN:
				_place(roads, cell, ROAD_STRAIGHT)
			elif z == ROAD_ROW:
				_place(roads, cell, ROAD_STRAIGHT, ROT_90)
			else:
				_place(roads, cell, GROUND)
			# The street and the cells flanking it stay clear: that is the
			# pavement, and it is where the player runs with the horde behind.
			if (
				x == ROAD_COLUMN or z == ROAD_ROW
				or (absi(x - ROAD_COLUMN) <= 1 and absi(z - ROAD_ROW) <= 1)
			):
				_occupied[Vector2i(cell.x, cell.z)] = true


## Paints one sector's structures and props. Returns true if it holds a POI.
func _paint_sector(structures: GridMap, props: GridMap, coords: Vector2i) -> bool:
	var origin := _get_sector_origin(coords)
	var ring := _get_ring(coords)
	if ring == 0:
		_paint_camp(props, origin)
		return false

	var poi_kind := _get_poi_kind(coords)
	if not poi_kind.is_empty():
		# Claim the whole compound before anything random is placed, so the yard
		# cannot be built over and the encounter trigger stays reachable.
		for x in range(POI_CELL_MIN, POI_CELL_MAX + 1):
			for z in range(POI_CELL_MIN, POI_CELL_MAX + 1):
				_occupied[Vector2i(origin.x + x, origin.y + z)] = true

	# Raised from 0.3/0.5/0.4: a candidate that lands on a cell another building
	# already reaches into is now dropped instead of being pushed through it, so
	# the same numbers painted a third fewer buildings than before.
	var density := 0.4 if ring == 1 else 0.65
	var pool := SUBURB_BUILDINGS if ring == 1 else URBAN_BUILDINGS
	var is_corner := absi(coords.x - CENTRE.x) >= 2 and absi(coords.y - CENTRE.y) >= 2
	if is_corner:
		pool = INDUSTRIAL
		density = 0.55

	if poi_kind.is_empty():
		# One landmark per sector, so the player can orient without the map.
		# Placed before anything random, or a dense sector eats its own landmark.
		# A POI is its own landmark and does not want a water tower in the yard.
		_try_place_structure(
			structures, Vector2i(origin.x + 7, origin.y + 7),
			"env_water_tower" if ring >= 2 else "forest_tree", ROT_0
		)

	for x in SECTOR_CELLS:
		for z in SECTOR_CELLS:
			if _rng.randf() > density:
				continue
			var choice: String = pool[_rng.randi_range(0, pool.size() - 1)]
			_try_place_structure(
				structures, Vector2i(origin.x + x, origin.y + z),
				choice, _random_rotation()
			)

	if not poi_kind.is_empty():
		_paint_poi(structures, props, origin, poi_kind)

	_scatter_props(props, origin, ring)
	return not poi_kind.is_empty()


## A compound of real pieces wrapped around an open yard. The back row and one
## side are built; the two sides facing the crossroads stay open, so the player
## walks in from the street and the horde can follow.
func _paint_poi(
	structures: GridMap, props: GridMap, origin: Vector2i, kind: String
) -> void:
	var tiles: Dictionary = POI_TILES[kind]
	var back: Array = tiles["back"]
	var side: Array = tiles["side"]
	var poi_props: Array = tiles["props"]
	for index in range(POI_CELL_MIN, POI_CELL_MAX + 1):
		_place(
			structures,
			Vector3i(origin.x + index, 0, origin.y + POI_CELL_MAX),
			String(back[(index - POI_CELL_MIN) % back.size()]),
			ROT_180
		)
	for index in range(POI_CELL_MIN, POI_CELL_MAX):
		_place(
			structures,
			Vector3i(origin.x + POI_CELL_MAX, 0, origin.y + index),
			String(side[(index - POI_CELL_MIN) % side.size()]),
			ROT_270
		)
	# One piece halfway along each open side: enough to read as a compound, with
	# the corner nearest the crossroads left as the way in.
	_place(
		props, Vector3i(origin.x + POI_CELL_MIN, 0, origin.y + POI_CELL_MAX - 1),
		String(poi_props[0]), ROT_90
	)
	_place(
		props, Vector3i(origin.x + POI_CELL_MAX - 1, 0, origin.y + POI_CELL_MIN),
		String(poi_props[poi_props.size() - 1]), ROT_0
	)


func _paint_camp(props: GridMap, origin: Vector2i) -> void:
	# The camp sector stays deliberately open: it is the extraction zone and the
	# one place where the horde has to be visible coming from every side.
	# Corners only. The middle stays completely clear: the player spawns there,
	# and a prop on the spawn cell ends up sitting on top of them.
	var corners: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 7), Vector2i(7, 7)
	]
	for corner in corners:
		var cell := Vector2i(origin.x + corner.x, origin.y + corner.y)
		_place(
			props, Vector3i(cell.x, 0, cell.y),
			"env_container_green", _random_rotation()
		)
		_occupied[cell] = true


func _scatter_props(props: GridMap, origin: Vector2i, ring: int) -> void:
	# Wrecks go on the roads, where they split the horde and give cover. They are
	# the one thing allowed on the street: a car is cover, not a wall.
	for index in (2 if ring == 1 else 3):
		var along := _rng.randi_range(0, SECTOR_CELLS - 1)
		if along == ROAD_ROW:
			continue
		_place(
			props, Vector3i(origin.x + ROAD_COLUMN, 0, origin.y + along),
			CARS[_rng.randi_range(0, CARS.size() - 1)], _random_rotation()
		)
	for index in 3:
		var x := _rng.randi_range(0, SECTOR_CELLS - 1)
		var z := _rng.randi_range(0, SECTOR_CELLS - 1)
		var cell := Vector2i(origin.x + x, origin.y + z)
		if _occupied.has(cell):
			continue
		_place(
			props, Vector3i(cell.x, 0, cell.y),
			CLUTTER[_rng.randi_range(0, CLUTTER.size() - 1)], _random_rotation()
		)
		_occupied[cell] = true


## Places a structure only if every cell its mesh actually covers is still free,
## then claims them. This is what stops the wide tiles from interpenetrating.
func _try_place_structure(
	grid: GridMap, cell: Vector2i, tile_name: String, rotation: int
) -> bool:
	var reach := _get_reach(tile_name, rotation)
	for x in range(cell.x - reach.x, cell.x + reach.x + 1):
		for z in range(cell.y - reach.y, cell.y + reach.y + 1):
			if _occupied.has(Vector2i(x, z)):
				return false
	_place(grid, Vector3i(cell.x, 0, cell.y), tile_name, rotation)
	for x in range(cell.x - reach.x, cell.x + reach.x + 1):
		for z in range(cell.y - reach.y, cell.y + reach.y + 1):
			_occupied[Vector2i(x, z)] = true
	return true


## How many cells a tile reaches out from its own, per axis. A tile that fits
## inside the cell reaches nothing; a 12.5 m one reaches a cell either side.
##
## Measured from the distance the mesh travels from its origin, not from its
## width: the Kenney industrial blocks are modelled off-centre, so ind_building_h
## is 7.9 m across and still hangs 5.6 m out of an 8 m cell on one side. Sizing
## by width alone said it fit, and it was one of the pieces found interpenetrating
## its neighbour.
func _get_reach(tile_name: String, rotation: int) -> Vector2i:
	if not _footprints.has(tile_name):
		var footprint := Vector2i.ONE
		if _ids.has(tile_name):
			var mesh := _library.get_item_mesh(int(_ids[tile_name]))
			if mesh != null:
				var bounds := mesh.get_aabb()
				var reach_x := maxf(
					absf(bounds.position.x), absf(bounds.position.x + bounds.size.x)
				)
				var reach_z := maxf(
					absf(bounds.position.z), absf(bounds.position.z + bounds.size.z)
				)
				footprint = Vector2i(
					maxi(1, ceili((reach_x * 2.0 - 0.1) / CELL_SIZE.x)),
					maxi(1, ceili((reach_z * 2.0 - 0.1) / CELL_SIZE.z))
				)
		_footprints[tile_name] = footprint
	var footprint: Vector2i = _footprints[tile_name]
	if rotation == ROT_90 or rotation == ROT_270:
		footprint = Vector2i(footprint.y, footprint.x)
	return Vector2i(footprint.x / 2, footprint.y / 2)


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
