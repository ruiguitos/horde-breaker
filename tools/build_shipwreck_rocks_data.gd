extends SceneTree

const DESIGN := preload("res://scripts/systems/shipwreck_rocks_design.gd")
const IMPORTER_SCENE := preload("res://addons/terrain_3d/tools/importer.tscn")
const REGION_DIRECTORY := "res://data/shipwreck_rocks/regions"
const TERRAIN_ASSETS := preload(
	"res://data/terrain3d_prototype/assets/terrain_assets.tres"
)

var _failed := false


func _init() -> void:
	call_deferred(&"_build")


func _build() -> void:
	var absolute_directory := ProjectSettings.globalize_path(REGION_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		_fail("could not create the region directory (%d)" % directory_error)
		_finish()
		return

	var build_camera := Camera3D.new()
	root.add_child(build_camera)
	build_camera.current = true
	var terrain := IMPORTER_SCENE.instantiate() as Terrain3D
	if terrain == null:
		_fail("could not instantiate the Terrain3D importer")
		_finish()
		return
	terrain.free_editor_textures = false
	terrain.set_camera(build_camera)
	root.add_child(terrain)
	await process_frame
	terrain.region_size = DESIGN.TERRAIN_REGION_SIZE
	terrain.data_directory = REGION_DIRECTORY
	terrain.assets = TERRAIN_ASSETS
	terrain.data.import_images(
		[DESIGN.create_height_map(), null, null],
		Vector3.ZERO,
		0.0,
		1.0
	)
	terrain.data.save_directory(REGION_DIRECTORY)
	await process_frame

	if terrain.data.get_region_count() != 1:
		_fail("expected one active region, found %d" % terrain.data.get_region_count())
	var region_files := PackedStringArray()
	for file_name in DirAccess.get_files_at(REGION_DIRECTORY):
		if file_name.begins_with("terrain3d") and file_name.ends_with(".res"):
			region_files.append(file_name)
	if region_files.size() != 1:
		_fail("expected one saved region file, found %d" % region_files.size())
	if not _failed:
		print("Shipwreck Rocks: saved one Terrain3D region to %s" % REGION_DIRECTORY)

	terrain.queue_free()
	build_camera.queue_free()
	await process_frame
	_finish()


func _fail(message: String) -> void:
	_failed = true
	push_error("Shipwreck Rocks builder: %s" % message)


func _finish() -> void:
	quit(1 if _failed else 0)
