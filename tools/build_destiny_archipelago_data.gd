extends SceneTree

const DESIGN := preload("res://scripts/systems/destiny_archipelago_design.gd")
const IMPORTER_SCENE := preload("res://addons/terrain_3d/tools/importer.tscn")
const REGION_DIRECTORY := "res://data/destiny_archipelago/regions"
const TERRAIN_ASSETS := preload(
	"res://data/terrain3d_prototype/assets/terrain_assets.tres"
)

var _failed := false


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var absolute_directory := ProjectSettings.globalize_path(REGION_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		_fail("could not create the region directory")
		_finish()
		return
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var terrain := IMPORTER_SCENE.instantiate() as Terrain3D
	if terrain == null:
		_fail("could not instantiate the Terrain3D importer")
		_finish()
		return
	terrain.free_editor_textures = false
	terrain.set_camera(camera)
	root.add_child(terrain)
	await process_frame
	terrain.region_size = DESIGN.TERRAIN_REGION_SIZE
	terrain.data_directory = REGION_DIRECTORY
	terrain.assets = TERRAIN_ASSETS
	terrain.data.import_images(
		[DESIGN.create_height_map(), null, null], Vector3.ZERO, 0.0, 1.0
	)
	terrain.data.save_directory(REGION_DIRECTORY)
	await process_frame
	if terrain.data.get_region_count() != DESIGN.EXPECTED_REGION_COUNT:
		_fail(
			"expected %d regions, found %d"
			% [DESIGN.EXPECTED_REGION_COUNT, terrain.data.get_region_count()]
		)
	var region_count := 0
	for file_name in DirAccess.get_files_at(REGION_DIRECTORY):
		if file_name.begins_with("terrain3d") and file_name.ends_with(".res"):
			region_count += 1
	if region_count != DESIGN.EXPECTED_REGION_COUNT:
		_fail("expected %d saved region files, found %d" % [DESIGN.EXPECTED_REGION_COUNT, region_count])
	if not _failed:
		print("Destiny Archipelago: saved %d Terrain3D regions." % region_count)
	terrain.queue_free()
	camera.queue_free()
	await process_frame
	_finish()


func _fail(message: String) -> void:
	_failed = true
	push_error("Destiny Archipelago builder: %s" % message)


func _finish() -> void:
	quit(1 if _failed else 0)
