extends SceneTree

## Turns folders of imported models into a GridMap MeshLibrary, and reports what
## it measured so the cell size can be chosen from the assets rather than
## guessed.
##
## Run:  <godot> --headless --path . --script res://tools/build_tile_library.gd
## Opt:  -- <output.meshlib>            write somewhere other than the default
##       -- <output.meshlib> measure    measure only, write nothing
##
## Add a pack by dropping it under assets/models/ and listing the folder in
## SOURCES. Nothing here is specific to one vendor: it reads whatever Godot
## imported, merges each model into a single mesh, and derives a box collider
## from the model's own bounds.

const OUTPUT_PATH := "res://resources/map_tiles_pack.meshlib"

## Folders to pull models from. `prefix` keeps names unique across packs and
## groups them in the GridMap palette, which sorts alphabetically.
const SOURCES: Array[Dictionary] = [
	{
		"path": "res://assets/models/quaternius_zombie_apocalypse/environment",
		"prefix": "env_",
	},
	{
		"path": "res://assets/models/quaternius_zombie_apocalypse/vehicles",
		"prefix": "veh_",
	},
	# Drop new packs in here, for example:
	# {"path": "res://assets/models/kenney_city_kit_commercial", "prefix": "city_"},
	# {"path": "res://assets/models/kenney_car_kit", "prefix": "car_"},
]

## Anything flatter than this is ground to walk on, not an obstacle, so it gets
## no collider (roads, pavement, manhole covers).
const MINIMUM_COLLIDER_HEIGHT := 0.5
## Common modular grid sizes to test the measured footprints against.
const CANDIDATE_MODULES: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0]
const MODULE_TOLERANCE := 0.15


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var arguments := OS.get_cmdline_user_args()
	var output_path := String(arguments[0]) if arguments.size() > 0 else OUTPUT_PATH
	var measure_only := arguments.size() > 1 and String(arguments[1]) == "measure"

	var library := MeshLibrary.new()
	var next_id := 0
	var footprints: Array[float] = []
	var missing: Array[String] = []

	for source in SOURCES:
		var folder := String(source["path"])
		var prefix := String(source["prefix"])
		var files := _list_models(folder)
		if files.is_empty():
			missing.append(folder)
			continue
		print("")
		print("=== %s (%d models)" % [folder, files.size()])
		for file_path in files:
			var entry := _build_item(file_path, prefix)
			if entry.is_empty():
				continue
			var bounds: AABB = entry["bounds"]
			# Only tiling pieces say anything about the grid. A barrel or a
			# streetlight is placed freely and would drag the estimate down.
			if not entry.has("shape"):
				footprints.append(bounds.size.x)
				footprints.append(bounds.size.z)
			print("  %-28s %5.2f x %5.2f x %5.2f m   collider=%s" % [
				String(entry["name"]),
				bounds.size.x, bounds.size.y, bounds.size.z,
				"yes" if entry.has("shape") else "no",
			])
			if measure_only:
				continue
			var id := next_id
			next_id += 1
			library.create_item(id)
			library.set_item_name(id, String(entry["name"]))
			library.set_item_mesh(id, entry["mesh"])
			if entry.has("shape"):
				library.set_item_shapes(id, [
					entry["shape"], Transform3D(Basis(), entry["shape_offset"])
				])

	for folder in missing:
		print("MISSING: %s — folder not found, skipped" % folder)
	_report_module(footprints)

	if measure_only:
		print("MEASURE ONLY: nothing written")
		quit(0)
		return
	if next_id == 0:
		push_error("No models found; nothing to write.")
		quit(1)
		return
	var error := ResourceSaver.save(library, output_path)
	if error != OK:
		push_error("Could not save the mesh library: %d" % error)
		quit(1)
		return
	print("")
	print("DONE: %d items -> %s" % [next_id, output_path])
	quit(0)


func _list_models(folder: String) -> PackedStringArray:
	var files := PackedStringArray()
	var directory := DirAccess.open(folder)
	if directory == null:
		return files
	for file_name in directory.get_files():
		# Godot reports imported resources with an .import suffix in exports;
		# accept the source extensions it knows how to load as scenes.
		var clean := file_name.trim_suffix(".import")
		var extension := clean.get_extension().to_lower()
		if extension in ["gltf", "glb", "obj", "dae", "fbx"]:
			var full := "%s/%s" % [folder, clean]
			if full not in files:
				files.append(full)
	files.sort()
	return files


func _build_item(file_path: String, prefix: String) -> Dictionary:
	var packed := load(file_path) as PackedScene
	if packed == null:
		push_warning("Could not load %s" % file_path)
		return {}
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_warning("%s has no Node3D root" % file_path)
		return {}
	root.add_child(instance)
	var merged := _merge_meshes(instance)
	var bounds := _get_bounds(instance)
	instance.queue_free()
	if merged == null:
		return {}

	var entry := {
		"name": prefix + file_path.get_file().get_basename().to_snake_case(),
		"mesh": merged,
		"bounds": bounds,
	}
	# A box derived from the model's own bounds: cheap, and good enough for a
	# navigation obstacle and for walking into. Flat pieces get none.
	if bounds.size.y >= MINIMUM_COLLIDER_HEIGHT:
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		entry["shape"] = shape
		entry["shape_offset"] = bounds.position + bounds.size * 0.5
	return entry


func _merge_meshes(instance: Node3D) -> ArrayMesh:
	# One SurfaceTool per material so a model keeps its materials without
	# exploding into a draw call per node.
	var tools: Dictionary = {}
	var order: Array = []
	for value in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := value as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var relative := instance.global_transform.affine_inverse() \
			* mesh_instance.global_transform
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface)
			var key := material.resource_path if material != null else "none"
			if key == "":
				key = str(material.get_instance_id())
			if not tools.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = {"tool": tool, "material": material}
				order.append(key)
			(tools[key]["tool"] as SurfaceTool).append_from(
				mesh_instance.mesh, surface, relative
			)
	if order.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for key in order:
		var entry: Dictionary = tools[key]
		var surface_index := mesh.get_surface_count()
		(entry["tool"] as SurfaceTool).commit(mesh)
		if entry["material"] != null:
			mesh.surface_set_material(surface_index, entry["material"])
	return mesh


func _get_bounds(instance: Node3D) -> AABB:
	var bounds := AABB()
	var started := false
	for value in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := value as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var relative := instance.global_transform.affine_inverse() \
			* mesh_instance.global_transform
		var item_bounds := relative * mesh_instance.mesh.get_aabb()
		if not started:
			bounds = item_bounds
			started = true
		else:
			bounds = bounds.merge(item_bounds)
	return bounds


func _report_module(footprints: Array[float]) -> void:
	print("")
	if footprints.is_empty():
		print("--- module check: no flat tiling pieces found, nothing to measure ---")
		print("    (props are placed freely; the grid comes from ground tiles)")
		return
	print("--- module check, from %d flat tiling pieces ---" % (footprints.size() / 2))
	var best_module := 0.0
	var best_score := -1.0
	for module in CANDIDATE_MODULES:
		var fitting := 0
		for size in footprints:
			var remainder := fmod(size, module)
			if remainder <= MODULE_TOLERANCE or module - remainder <= MODULE_TOLERANCE:
				fitting += 1
		var score := float(fitting) / float(footprints.size())
		print("  %5.1f m grid: %3d%% of footprints align" % [module, score * 100.0])
		# Prefer the largest grid that still fits: an 8 m tile aligns to a 1 m
		# grid too, but 8 m is the module the pack was actually authored on.
		if score >= best_score:
			best_score = score
			best_module = module
	var largest := 0.0
	for size in footprints:
		largest = maxf(largest, size)
	print("  largest footprint: %.2f m" % largest)
	print("  suggested cell_size: %.1f m (%.0f%% of pieces align)" % [
		best_module, best_score * 100.0
	])
