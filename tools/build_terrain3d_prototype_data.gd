extends SceneTree

const DESIGN := preload("res://scripts/systems/terrain3d_prototype_design.gd")
const IMPORTER_SCENE := preload("res://addons/terrain_3d/tools/importer.tscn")
const DATA_ROOT := "res://data/terrain3d_prototype"
const REGION_DIRECTORY := DATA_ROOT + "/regions"
const ASSET_DIRECTORY := DATA_ROOT + "/assets"
const ASSETS_PATH := ASSET_DIRECTORY + "/terrain_assets.tres"

var _failed := false


func _init() -> void:
	call_deferred(&"_build")


func _build() -> void:
	if not _ensure_directory(REGION_DIRECTORY):
		_finish()
		return
	if not _ensure_directory(ASSET_DIRECTORY):
		_finish()
		return

	print("Terrain3D data builder: creating external texture resources")
	var terrain_assets := _build_assets()
	if terrain_assets == null:
		_finish()
		return

	print("Terrain3D data builder: generating four persistent regions")
	var build_camera := Camera3D.new()
	root.add_child(build_camera)
	build_camera.current = true
	var terrain := IMPORTER_SCENE.instantiate() as Terrain3D
	if terrain == null:
		_fail("could not instantiate the official Terrain3D importer")
		build_camera.queue_free()
		await process_frame
		_finish()
		return
	terrain.free_editor_textures = false
	terrain.set_camera(build_camera)
	root.add_child(terrain)
	await process_frame
	terrain.region_size = DESIGN.TERRAIN_REGION_SIZE
	terrain.data_directory = REGION_DIRECTORY
	terrain.assets = terrain_assets

	var height_map := DESIGN.create_height_map()
	terrain.data.import_images(
		[height_map, null, null],
		Vector3(-DESIGN.TERRAIN_HALF_SIZE, 0.0, -DESIGN.TERRAIN_HALF_SIZE),
		0.0,
		1.0
	)
	terrain.data.save_directory(REGION_DIRECTORY)
	await process_frame

	if terrain.data.get_region_count() != 4:
		_fail("expected four active regions, found %d" % terrain.data.get_region_count())
	var region_files := _get_region_files()
	if region_files.size() != 4:
		_fail("expected four saved region files, found %d" % region_files.size())
	if not _failed:
		print(
			"Terrain3D data builder: saved %d regions to %s"
			% [region_files.size(), REGION_DIRECTORY]
		)

	terrain.queue_free()
	build_camera.queue_free()
	await process_frame
	_finish()


func _build_assets() -> Terrain3DAssets:
	var soil_images := DESIGN.create_surface_images(
		"Exposed soil",
		Color(0.19, 0.11, 0.055),
		Color(0.39, 0.25, 0.12),
		0.94
	)
	var grass_images := DESIGN.create_surface_images(
		"Dry grass",
		Color(0.13, 0.2, 0.065),
		Color(0.27, 0.34, 0.14),
		0.88
	)
	var soil_albedo := _save_texture(soil_images[0], "soil_albedo.res")
	var soil_normal := _save_texture(soil_images[1], "soil_normal_roughness.res")
	var grass_albedo := _save_texture(grass_images[0], "grass_albedo.res")
	var grass_normal := _save_texture(grass_images[1], "grass_normal_roughness.res")
	if [soil_albedo, soil_normal, grass_albedo, grass_normal].has(null):
		return null

	var soil_asset := Terrain3DTextureAsset.new()
	soil_asset.name = "Exposed soil"
	soil_asset.albedo_texture = soil_albedo
	soil_asset.normal_texture = soil_normal
	soil_asset.uv_scale = 0.08
	soil_asset.detiling_rotation = 0.12

	var grass_asset := Terrain3DTextureAsset.new()
	grass_asset.name = "Dry grass"
	grass_asset.albedo_texture = grass_albedo
	grass_asset.normal_texture = grass_normal
	grass_asset.uv_scale = 0.13
	grass_asset.detiling_rotation = 0.12

	var assets := Terrain3DAssets.new()
	assets.set_texture(0, soil_asset)
	assets.set_texture(1, grass_asset)
	if ResourceSaver.save(assets, ASSETS_PATH) != OK:
		_fail("could not save %s" % ASSETS_PATH)
		return null
	return assets


func _save_texture(image: Image, file_name: String) -> Texture2D:
	var path := ASSET_DIRECTORY + "/" + file_name
	var texture := ImageTexture.create_from_image(image)
	if ResourceSaver.save(texture, path, ResourceSaver.FLAG_COMPRESS) != OK:
		_fail("could not save %s" % path)
		return null
	return load(path) as Texture2D


func _ensure_directory(resource_path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK:
		_fail("could not create %s (error %d)" % [resource_path, error])
		return false
	return true


func _get_region_files() -> PackedStringArray:
	var region_files := PackedStringArray()
	for file_name in DirAccess.get_files_at(REGION_DIRECTORY):
		if file_name.begins_with("terrain3d") and file_name.ends_with(".res"):
			region_files.append(file_name)
	return region_files


func _fail(message: String) -> void:
	_failed = true
	push_error("Terrain3D data builder: %s" % message)


func _finish() -> void:
	quit(1 if _failed else 0)
