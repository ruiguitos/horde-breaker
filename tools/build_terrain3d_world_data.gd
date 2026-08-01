extends SceneTree

const DESIGN := preload("res://scripts/systems/terrain3d_world_design.gd")
const IMPORTER_SCENE := preload("res://addons/terrain_3d/tools/importer.tscn")
const TERRAIN_ASSETS := preload(
	"res://data/terrain3d_prototype/assets/terrain_assets.tres"
)
const REGION_DIRECTORY := "res://data/terrain3d_world/regions"

var _failed := false


func _init() -> void:
	call_deferred(&"_build")


func _build() -> void:
	if not _ensure_directory(REGION_DIRECTORY):
		_finish()
		return
	if not _clear_region_files():
		_finish()
		return
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var terrain := IMPORTER_SCENE.instantiate() as Terrain3D
	if terrain == null:
		_fail("could not instantiate the official Terrain3D importer")
		camera.queue_free()
		await process_frame
		_finish()
		return
	terrain.free_editor_textures = false
	terrain.set_camera(camera)
	terrain.collision.mode = Terrain3DCollision.DISABLED
	root.add_child(terrain)
	await process_frame
	terrain.region_size = DESIGN.TERRAIN_REGION_SIZE
	terrain.data_directory = REGION_DIRECTORY
	terrain.assets = TERRAIN_ASSETS
	terrain.data.import_images(
		[DESIGN.create_height_map(), null, null],
		Vector3(DESIGN.TERRAIN_ORIGIN.x, 0.0, DESIGN.TERRAIN_ORIGIN.y),
		0.0,
		1.0
	)
	terrain.data.save_directory(REGION_DIRECTORY)
	await process_frame
	var region_files := _get_region_files()
	if (
		terrain.data.get_region_count() != DESIGN.EXPECTED_REGION_COUNT
		or region_files.size() != DESIGN.EXPECTED_REGION_COUNT
	):
		_fail(
			"expected %d saved regions, found %d active and %d files"
			% [
				DESIGN.EXPECTED_REGION_COUNT,
				terrain.data.get_region_count(),
				region_files.size(),
			]
		)
	else:
		print(
			"Terrain3D world builder: saved %d regions to %s"
			% [region_files.size(), REGION_DIRECTORY]
		)
	terrain.queue_free()
	camera.queue_free()
	await process_frame
	_finish()


func _ensure_directory(resource_path: String) -> bool:
	var error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(resource_path)
	)
	if error != OK:
		_fail("could not create %s (error %d)" % [resource_path, error])
		return false
	return true


func _get_region_files() -> PackedStringArray:
	var result := PackedStringArray()
	for file_name in DirAccess.get_files_at(REGION_DIRECTORY):
		if file_name.begins_with("terrain3d") and file_name.ends_with(".res"):
			result.append(file_name)
	return result


func _clear_region_files() -> bool:
	var absolute_directory := ProjectSettings.globalize_path(REGION_DIRECTORY)
	for file_name in _get_region_files():
		var resource_path := REGION_DIRECTORY + "/" + file_name
		var absolute_path := ProjectSettings.globalize_path(resource_path)
		if not absolute_path.begins_with(absolute_directory + "/"):
			_fail("refused to remove a region outside %s" % REGION_DIRECTORY)
			return false
		var error := DirAccess.remove_absolute(absolute_path)
		if error != OK:
			_fail("could not replace %s (error %d)" % [resource_path, error])
			return false
	return true


func _fail(message: String) -> void:
	_failed = true
	push_error("Terrain3D world builder: %s" % message)


func _finish() -> void:
	quit(1 if _failed else 0)
