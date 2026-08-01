class_name Terrain3DPrototypeDesign
extends RefCounted

const TERRAIN_SIZE := 512
const TERRAIN_HALF_SIZE := TERRAIN_SIZE / 2.0
const TERRAIN_REGION_SIZE := 256
const DESIGN_SEED := 7302026
const TEXTURE_SIZE := 128


static func create_height_map() -> Image:
	var height_map := Image.create_empty(
		TERRAIN_SIZE, TERRAIN_SIZE, false, Image.FORMAT_RF
	)
	var noise := FastNoiseLite.new()
	noise.seed = DESIGN_SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.009
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.48
	for image_z in range(TERRAIN_SIZE):
		var world_z := float(image_z) - TERRAIN_HALF_SIZE
		for image_x in range(TERRAIN_SIZE):
			var world_x := float(image_x) - TERRAIN_HALF_SIZE
			var height := designed_height(world_x, world_z, noise)
			height_map.set_pixel(image_x, image_z, Color(height, 0.0, 0.0, 1.0))
	return height_map


static func create_surface_images(
	asset_name: String,
	dark_color: Color,
	light_color: Color,
	roughness: float
) -> Array[Image]:
	var albedo_image := Image.create_empty(
		TEXTURE_SIZE, TEXTURE_SIZE, true, Image.FORMAT_RGBA8
	)
	var normal_image := Image.create_empty(
		TEXTURE_SIZE, TEXTURE_SIZE, true, Image.FORMAT_RGBA8
	)
	var noise := FastNoiseLite.new()
	noise.seed = DESIGN_SEED + asset_name.hash()
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	for image_y in range(TEXTURE_SIZE):
		for image_x in range(TEXTURE_SIZE):
			var value := remap(
				noise.get_noise_2d(image_x, image_y), -1.0, 1.0, 0.0, 1.0
			)
			var albedo := dark_color.lerp(light_color, value)
			albedo.a = value
			albedo_image.set_pixel(image_x, image_y, albedo)
			normal_image.set_pixel(
				image_x,
				image_y,
				Color(0.5, 0.5, 1.0, roughness)
			)
	albedo_image.generate_mipmaps()
	normal_image.generate_mipmaps()
	return [albedo_image, normal_image]


static func designed_height(
	world_x: float,
	world_z: float,
	noise: FastNoiseLite
) -> float:
	var height := raw_height(world_x, world_z, noise)

	var path_x := path_center_x(world_z)
	var path_distance := absf(world_x - path_x)
	var path_blend := 1.0 - smoothstep(5.0, 13.0, path_distance)
	var path_height := raw_height(path_x, world_z, noise)
	height = lerpf(height, path_height, path_blend * 0.82)

	var camp_distance := Vector2(world_x, world_z).length()
	var camp_blend := 1.0 - smoothstep(24.0, 37.0, camp_distance)
	height = lerpf(height, 2.0, camp_blend)

	var rock_mound_distance := Vector2(
		world_x + 1.5, world_z + 43.0
	).length()
	var rock_mound := 5.5 * (
		1.0 - smoothstep(3.5, 8.5, rock_mound_distance)
	)
	return height + rock_mound


static func raw_height(world_x: float, world_z: float, noise: FastNoiseLite) -> float:
	var rolling_noise := noise.get_noise_2d(world_x, world_z) * 5.5
	var broad_waves := (
		sin(world_x * 0.021) * 2.2
		+ cos(world_z * 0.017) * 2.7
	)
	var lookout_hill := 15.0 * exp(
		-Vector2(world_x - 76.0, world_z + 58.0).length_squared() / 2200.0
	)
	var northern_ridge := 8.0 * exp(
		-Vector2(world_x + 82.0, world_z + 118.0).length_squared() / 4200.0
	)
	return 5.0 + rolling_noise + broad_waves + lookout_hill + northern_ridge


static func path_center_x(world_z: float) -> float:
	return sin(world_z * 0.026) * 22.0 + sin(world_z * 0.009) * 8.0

