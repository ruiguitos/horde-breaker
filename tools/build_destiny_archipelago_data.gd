extends SceneTree

const DESIGN := preload("res://scripts/systems/destiny_archipelago_design.gd")
const IMPORTER_SCENE := preload("res://addons/terrain_3d/tools/importer.tscn")
const REGION_DIRECTORY := "res://data/destiny_archipelago/regions"
const ASSET_DIRECTORY := "res://data/destiny_archipelago/assets"
const ASSETS_PATH := ASSET_DIRECTORY + "/terrain_assets.tres"

const SURFACE_DEFINITIONS := [
	{
		"name": "Dawn sand",
		"slug": "dawn_sand",
		"dark": Color(0.38, 0.27, 0.13),
		"light": Color(0.82, 0.67, 0.38),
		"roughness": 0.9,
		"uv_scale": 0.11,
	},
	{
		"name": "Coastal grass",
		"slug": "coastal_grass",
		"dark": Color(0.12, 0.21, 0.07),
		"light": Color(0.37, 0.46, 0.19),
		"roughness": 0.94,
		"uv_scale": 0.13,
	},
	{
		"name": "Swamp mud",
		"slug": "swamp_mud",
		"dark": Color(0.055, 0.045, 0.03),
		"light": Color(0.19, 0.14, 0.075),
		"roughness": 0.82,
		"uv_scale": 0.1,
	},
	{
		"name": "Swamp moss",
		"slug": "swamp_moss",
		"dark": Color(0.035, 0.11, 0.055),
		"light": Color(0.18, 0.34, 0.11),
		"roughness": 0.96,
		"uv_scale": 0.15,
	},
	{
		"name": "Cliff stone",
		"slug": "cliff_stone",
		"dark": Color(0.16, 0.18, 0.2),
		"light": Color(0.43, 0.46, 0.47),
		"roughness": 0.92,
		"uv_scale": 0.09,
	},
	{
		"name": "Cliff lichen",
		"slug": "cliff_lichen",
		"dark": Color(0.2, 0.23, 0.15),
		"light": Color(0.5, 0.51, 0.34),
		"roughness": 0.97,
		"uv_scale": 0.12,
	},
	{
		"name": "Volcanic ash",
		"slug": "volcanic_ash",
		"dark": Color(0.035, 0.03, 0.032),
		"light": Color(0.16, 0.125, 0.12),
		"roughness": 0.98,
		"uv_scale": 0.1,
	},
	{
		"name": "Obsidian",
		"slug": "obsidian",
		"dark": Color(0.012, 0.01, 0.015),
		"light": Color(0.085, 0.055, 0.07),
		"roughness": 0.48,
		"uv_scale": 0.075,
	},
]

var _failed := false


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var absolute_directory := ProjectSettings.globalize_path(REGION_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		_fail("could not create the region directory")
		_finish()
		return
	var terrain_assets := _build_assets()
	if terrain_assets == null:
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
	terrain.assets = terrain_assets
	terrain.data.import_images(
		[DESIGN.create_height_map(), DESIGN.create_control_map(), null],
		Vector3.ZERO,
		0.0,
		1.0
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


func _build_assets() -> Terrain3DAssets:
	var absolute_directory := ProjectSettings.globalize_path(ASSET_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		_fail("could not create the terrain asset directory")
		return null
	var assets := Terrain3DAssets.new()
	for index in range(SURFACE_DEFINITIONS.size()):
		var definition: Dictionary = SURFACE_DEFINITIONS[index]
		var images := DESIGN.create_surface_images(
			String(definition["name"]),
			definition["dark"] as Color,
			definition["light"] as Color,
			float(definition["roughness"])
		)
		var slug := String(definition["slug"])
		var albedo := _save_texture(images[0], "%s_albedo.res" % slug)
		var normal := _save_texture(images[1], "%s_normal_roughness.res" % slug)
		if albedo == null or normal == null:
			return null
		var texture_asset := Terrain3DTextureAsset.new()
		texture_asset.name = String(definition["name"])
		texture_asset.albedo_texture = albedo
		texture_asset.normal_texture = normal
		texture_asset.uv_scale = float(definition["uv_scale"])
		texture_asset.detiling_rotation = 0.14
		assets.set_texture(index, texture_asset)
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


func _fail(message: String) -> void:
	_failed = true
	push_error("Destiny Archipelago builder: %s" % message)


func _finish() -> void:
	quit(1 if _failed else 0)
