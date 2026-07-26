extends SceneTree

## Builds the blockout tile set for the hand-authored map and exports it as a
## MeshLibrary the GridMap can paint with. No external asset packs: every tile is
## primitives with the project's post-apocalyptic palette, which is how a level
## blockout is meant to look before art lands.
##
## Run:  <godot> --headless --path . --script res://tools/generate_map_tiles.gd
## Out:  res://resources/map_tiles.meshlib
##
## Tiles are authored for a 8 x 4 x 8 m GridMap cell. Roads sit 6 cm proud of the
## world ground so the asphalt reads without creating a step to walk over.

const OUTPUT_PATH := "res://resources/map_tiles.meshlib"
const CELL := 8.0
const ROAD_TOP := 0.06
const SIDEWALK_TOP := 0.18

# Palette from the design manual.
const COLOR_ASPHALT := Color("#1A1C1E")
const COLOR_MOSS := Color("#2D302E")
const COLOR_CONCRETE := Color("#4A4E4D")
const COLOR_DIRT := Color("#8C7A6B")
const COLOR_ROAD_LINE := Color(0.62, 0.58, 0.44)
const COLOR_RUST := Color(0.36, 0.22, 0.16)
const COLOR_METAL := Color(0.28, 0.31, 0.33)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var library := MeshLibrary.new()
	var next_id := 0
	for tile in _build_tiles():
		var id := next_id
		next_id += 1
		library.create_item(id)
		library.set_item_name(id, String(tile["name"]))
		library.set_item_mesh(id, tile["mesh"])
		var shapes: Array = tile.get("shapes", [])
		if not shapes.is_empty():
			library.set_item_shapes(id, shapes)
		print("TILE: %-22s surfaces=%d collision=%d" % [
			String(tile["name"]),
			(tile["mesh"] as ArrayMesh).get_surface_count(),
			shapes.size() / 2,
		])
	var error := ResourceSaver.save(library, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save the mesh library: %d" % error)
		quit(1)
		return
	print("DONE: %d tiles -> %s" % [next_id, OUTPUT_PATH])
	quit(0)


func _build_tiles() -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	tiles.append(_road_straight())
	tiles.append(_road_crossing())
	tiles.append(_road_t())
	tiles.append(_road_corner())
	tiles.append(_sidewalk())
	tiles.append(_sidewalk_corner())
	tiles.append(_building("building_small", 9.0, COLOR_CONCRETE))
	tiles.append(_building("building_medium", 15.0, COLOR_CONCRETE.darkened(0.1)))
	tiles.append(_building("building_tall", 23.0, COLOR_CONCRETE.darkened(0.2)))
	tiles.append(_warehouse())
	tiles.append(_car_wreck())
	tiles.append(_container())
	tiles.append(_barricade())
	tiles.append(_rubble())
	tiles.append(_tree())
	tiles.append(_water_tower())
	return tiles


# --- ground tiles -----------------------------------------------------------

func _road_straight() -> Dictionary:
	var builder := _Builder.new()
	builder.slab(COLOR_ASPHALT, ROAD_TOP)
	# Dashed centre line running north-south.
	for index in 3:
		var offset := -CELL * 0.5 + CELL * (0.2 + 0.3 * float(index))
		builder.box(
			COLOR_ROAD_LINE,
			Vector3(0.0, ROAD_TOP + 0.005, offset),
			Vector3(0.22, 0.01, 1.6)
		)
	return {"name": "road_straight", "mesh": builder.commit()}


func _road_crossing() -> Dictionary:
	var builder := _Builder.new()
	builder.slab(COLOR_ASPHALT, ROAD_TOP)
	# Crosswalk bars on all four approaches.
	for side in 4:
		var angle := float(side) * PI * 0.5
		var forward := Vector3(sin(angle), 0.0, cos(angle))
		var right := Vector3(cos(angle), 0.0, -sin(angle))
		for bar in 4:
			var lateral := (-1.5 + float(bar)) * 0.9
			builder.box(
				COLOR_ROAD_LINE,
				forward * (CELL * 0.42) + right * lateral
					+ Vector3(0.0, ROAD_TOP + 0.005, 0.0),
				Vector3(0.5, 0.01, 1.0) if absf(forward.z) > 0.5
					else Vector3(1.0, 0.01, 0.5)
			)
	return {"name": "road_crossing", "mesh": builder.commit()}


func _road_t() -> Dictionary:
	var builder := _Builder.new()
	builder.slab(COLOR_ASPHALT, ROAD_TOP)
	for index in 3:
		var offset := -CELL * 0.5 + CELL * (0.2 + 0.3 * float(index))
		builder.box(
			COLOR_ROAD_LINE,
			Vector3(offset, ROAD_TOP + 0.005, -CELL * 0.32),
			Vector3(1.6, 0.01, 0.22)
		)
	return {"name": "road_t", "mesh": builder.commit()}


func _road_corner() -> Dictionary:
	var builder := _Builder.new()
	builder.slab(COLOR_ASPHALT, ROAD_TOP)
	builder.box(
		COLOR_ROAD_LINE,
		Vector3(-CELL * 0.18, ROAD_TOP + 0.005, -CELL * 0.18),
		Vector3(0.22, 0.01, 2.4)
	)
	builder.box(
		COLOR_ROAD_LINE,
		Vector3(-CELL * 0.05, ROAD_TOP + 0.005, -CELL * 0.05),
		Vector3(2.4, 0.01, 0.22)
	)
	return {"name": "road_corner", "mesh": builder.commit()}


func _sidewalk() -> Dictionary:
	var builder := _Builder.new()
	builder.slab(COLOR_CONCRETE, SIDEWALK_TOP)
	# A kerb edge so the pavement reads as raised from above.
	builder.box(
		COLOR_CONCRETE.darkened(0.25),
		Vector3(0.0, SIDEWALK_TOP * 0.5, -CELL * 0.5 + 0.15),
		Vector3(CELL, SIDEWALK_TOP, 0.3)
	)
	builder.box(
		COLOR_MOSS,
		Vector3(CELL * 0.3, SIDEWALK_TOP + 0.01, CELL * 0.3),
		Vector3(1.4, 0.02, 1.4)
	)
	return {"name": "sidewalk", "mesh": builder.commit()}


func _sidewalk_corner() -> Dictionary:
	var builder := _Builder.new()
	builder.slab(COLOR_CONCRETE, SIDEWALK_TOP)
	builder.box(
		COLOR_CONCRETE.darkened(0.25),
		Vector3(0.0, SIDEWALK_TOP * 0.5, -CELL * 0.5 + 0.15),
		Vector3(CELL, SIDEWALK_TOP, 0.3)
	)
	builder.box(
		COLOR_CONCRETE.darkened(0.25),
		Vector3(-CELL * 0.5 + 0.15, SIDEWALK_TOP * 0.5, 0.0),
		Vector3(0.3, SIDEWALK_TOP, CELL)
	)
	return {"name": "sidewalk_corner", "mesh": builder.commit()}


# --- buildings --------------------------------------------------------------

func _building(tile_name: String, height: float, color: Color) -> Dictionary:
	var builder := _Builder.new()
	var footprint := CELL - 0.6
	builder.slab(COLOR_CONCRETE.darkened(0.3), 0.12)
	builder.box(color, Vector3(0.0, height * 0.5, 0.0), Vector3(footprint, height, footprint))
	# Window bands: darker recesses every 3 m, which is what sells the scale.
	var band_count := int(height / 3.0)
	for band in band_count:
		var y := 2.0 + float(band) * 3.0
		if y > height - 1.0:
			break
		builder.box(
			COLOR_ASPHALT,
			Vector3(0.0, y, 0.0),
			Vector3(footprint + 0.06, 1.1, footprint + 0.06)
		)
	# Parapet on the roof.
	builder.box(
		color.darkened(0.15),
		Vector3(0.0, height + 0.3, 0.0),
		Vector3(footprint + 0.3, 0.6, footprint + 0.3)
	)
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint, height, footprint)
	return {
		"name": tile_name,
		"mesh": builder.commit(),
		"shapes": [shape, Transform3D(Basis(), Vector3(0.0, height * 0.5, 0.0))],
	}


func _warehouse() -> Dictionary:
	# Walkable interior: three walls plus a front split around a wide doorway.
	var builder := _Builder.new()
	var height := 6.0
	var half := CELL * 0.5 - 0.3
	var thickness := 0.4
	var door_half := 1.8
	builder.slab(COLOR_CONCRETE.darkened(0.35), 0.1)
	var shapes: Array = []
	# Back and sides.
	builder.box(COLOR_RUST, Vector3(0.0, height * 0.5, -half), Vector3(half * 2.0, height, thickness))
	shapes.append_array(_box_shape(Vector3(0.0, height * 0.5, -half), Vector3(half * 2.0, height, thickness)))
	builder.box(COLOR_RUST, Vector3(-half, height * 0.5, 0.0), Vector3(thickness, height, half * 2.0))
	shapes.append_array(_box_shape(Vector3(-half, height * 0.5, 0.0), Vector3(thickness, height, half * 2.0)))
	builder.box(COLOR_RUST, Vector3(half, height * 0.5, 0.0), Vector3(thickness, height, half * 2.0))
	shapes.append_array(_box_shape(Vector3(half, height * 0.5, 0.0), Vector3(thickness, height, half * 2.0)))
	# Front wall, split around the doorway.
	var side_width := half - door_half
	if side_width > 0.1:
		var offset := door_half + side_width * 0.5
		for direction in [-1.0, 1.0]:
			var centre := Vector3(direction * offset, height * 0.5, half)
			var size := Vector3(side_width, height, thickness)
			builder.box(COLOR_RUST, centre, size)
			shapes.append_array(_box_shape(centre, size))
	# Lintel over the door.
	builder.box(
		COLOR_RUST.darkened(0.2),
		Vector3(0.0, height - 0.6, half),
		Vector3(door_half * 2.0, 1.2, thickness)
	)
	# Roof, left open at the front so the interior stays lit and readable.
	builder.box(COLOR_METAL, Vector3(0.0, height, 0.0), Vector3(half * 2.0, 0.3, half * 2.0))
	return {"name": "warehouse", "mesh": builder.commit(), "shapes": shapes}


# --- props ------------------------------------------------------------------

func _car_wreck() -> Dictionary:
	var builder := _Builder.new()
	builder.box(COLOR_RUST, Vector3(0.0, 0.55, 0.0), Vector3(1.9, 0.7, 4.2))
	builder.box(COLOR_ASPHALT, Vector3(0.0, 1.15, -0.2), Vector3(1.7, 0.6, 2.0))
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			builder.box(
				COLOR_ASPHALT,
				Vector3(side * 0.85, 0.35, end * 1.45),
				Vector3(0.3, 0.7, 0.7)
			)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.5, 4.3)
	return {
		"name": "car_wreck",
		"mesh": builder.commit(),
		"shapes": [shape, Transform3D(Basis(), Vector3(0.0, 0.75, 0.0))],
	}


func _container() -> Dictionary:
	var builder := _Builder.new()
	var size := Vector3(2.4, 2.6, 6.0)
	builder.box(COLOR_MOSS.lightened(0.05), Vector3(0.0, size.y * 0.5, 0.0), size)
	for index in 5:
		builder.box(
			COLOR_MOSS.darkened(0.25),
			Vector3(size.x * 0.5 + 0.02, size.y * 0.5, -2.0 + float(index)),
			Vector3(0.06, size.y - 0.3, 0.18)
		)
	var shape := BoxShape3D.new()
	shape.size = size
	return {
		"name": "container",
		"mesh": builder.commit(),
		"shapes": [shape, Transform3D(Basis(), Vector3(0.0, size.y * 0.5, 0.0))],
	}


func _barricade() -> Dictionary:
	var builder := _Builder.new()
	builder.box(COLOR_CONCRETE, Vector3(0.0, 0.55, 0.0), Vector3(CELL - 1.0, 1.1, 0.5))
	for side in [-1.0, 1.0]:
		builder.box(
			COLOR_RUST,
			Vector3(side * (CELL * 0.5 - 1.0), 0.75, 0.0),
			Vector3(0.35, 1.5, 0.8)
		)
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL - 1.0, 1.2, 0.8)
	return {
		"name": "barricade",
		"mesh": builder.commit(),
		"shapes": [shape, Transform3D(Basis(), Vector3(0.0, 0.6, 0.0))],
	}


func _rubble() -> Dictionary:
	var builder := _Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	# Two tones only: a colour per chunk would mean a surface, and a draw call,
	# for every lump of debris.
	for index in 9:
		var offset := Vector3(
			rng.randf_range(-2.4, 2.4), 0.0, rng.randf_range(-2.4, 2.4)
		)
		var size := Vector3(
			rng.randf_range(0.5, 1.3),
			rng.randf_range(0.3, 0.9),
			rng.randf_range(0.5, 1.3)
		)
		offset.y = size.y * 0.5
		builder.box(
			COLOR_CONCRETE if index % 2 == 0 else COLOR_CONCRETE.darkened(0.22),
			offset,
			size
		)
	return {"name": "rubble", "mesh": builder.commit()}


func _tree() -> Dictionary:
	var builder := _Builder.new()
	builder.box(COLOR_RUST.darkened(0.35), Vector3(0.0, 1.6, 0.0), Vector3(0.5, 3.2, 0.5))
	builder.box(COLOR_MOSS, Vector3(0.0, 3.9, 0.0), Vector3(3.2, 1.8, 3.2))
	builder.box(COLOR_MOSS.darkened(0.15), Vector3(0.0, 4.9, 0.0), Vector3(2.2, 1.2, 2.2))
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 3.2
	return {
		"name": "tree",
		"mesh": builder.commit(),
		"shapes": [shape, Transform3D(Basis(), Vector3(0.0, 1.6, 0.0))],
	}


func _water_tower() -> Dictionary:
	# The per-sector landmark: tall enough to navigate by from across the map.
	var builder := _Builder.new()
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			builder.box(
				COLOR_METAL,
				Vector3(side * 1.6, 5.0, end * 1.6),
				Vector3(0.35, 10.0, 0.35)
			)
	builder.box(COLOR_METAL.darkened(0.2), Vector3(0.0, 10.2, 0.0), Vector3(4.4, 0.4, 4.4))
	builder.box(COLOR_RUST, Vector3(0.0, 12.6, 0.0), Vector3(5.0, 4.4, 5.0))
	builder.box(COLOR_RUST.darkened(0.25), Vector3(0.0, 15.1, 0.0), Vector3(5.4, 0.6, 5.4))
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 10.0, 4.0)
	return {
		"name": "water_tower",
		"mesh": builder.commit(),
		"shapes": [shape, Transform3D(Basis(), Vector3(0.0, 5.0, 0.0))],
	}


func _box_shape(centre: Vector3, size: Vector3) -> Array:
	var shape := BoxShape3D.new()
	shape.size = size
	return [shape, Transform3D(Basis(), centre)]


## Merges coloured boxes into one ArrayMesh, one surface per colour so the tile
## stays a single draw call per material.
class _Builder:
	extends RefCounted

	var _by_color: Dictionary = {}

	func slab(color: Color, top: float) -> void:
		box(color, Vector3(0.0, top * 0.5, 0.0), Vector3(CELL, top, CELL))

	func box(color: Color, centre: Vector3, size: Vector3) -> void:
		var key := color.to_html(false)
		if not _by_color.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			_by_color[key] = {"tool": tool, "color": color}
		var source := BoxMesh.new()
		source.size = size
		var tool: SurfaceTool = _by_color[key]["tool"]
		tool.append_from(source, 0, Transform3D(Basis(), centre))

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for key: String in _by_color:
			var entry: Dictionary = _by_color[key]
			var tool: SurfaceTool = entry["tool"]
			tool.generate_normals()
			var surface_index := mesh.get_surface_count()
			tool.commit(mesh)
			var material := StandardMaterial3D.new()
			material.albedo_color = entry["color"] as Color
			# Matte and desaturated: shine only belongs on wet or bloodied
			# surfaces, per the design manual.
			material.roughness = 0.95
			material.metallic = 0.0
			mesh.surface_set_material(surface_index, material)
		return mesh
