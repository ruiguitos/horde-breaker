extends SceneTree

const ICON_SIZE := Vector2i(320, 320)
const OUTPUT_DIRECTORY := "res://assets/icons"
const EMBEDDED_WEAPON_NAMES: Array[StringName] = [
	&"Axe",
	&"Guitar",
	&"Knife",
	&"Pistol",
	&"Rifle",
	&"Shotgun",
	&"SMG",
	&"Spear",
	&"WoodenBat_Barbed",
	&"WoodenBat_Saw",
]
const CHARACTER_SPECS: Array[Dictionary] = [
	{
		"id": "recruit",
		"scene": preload("res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Matt.gltf"),
		"weapon": &"Rifle",
	},
	{
		"id": "renegade",
		"scene": preload("res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Lis.gltf"),
		"weapon": &"Shotgun",
	},
	{
		"id": "medic",
		"scene": preload("res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Sam.gltf"),
		"weapon": &"Pistol",
	},
]
const WEAPON_SPECS: Array[Dictionary] = [
	{
		"id": "assault_rifle",
		"scene": preload("res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Matt.gltf"),
		"weapon": &"Rifle",
		"size": 1.45,
	},
	{
		"id": "pistol",
		"scene": preload("res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Sam.gltf"),
		"weapon": &"Pistol",
		"size": 1.25,
	},
	{
		"id": "shotgun",
		"scene": preload("res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Lis.gltf"),
		"weapon": &"Shotgun",
		"size": 1.55,
	},
	{
		"id": "worn_sword",
		"scene": preload("res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Lis.gltf"),
		"weapon": &"Knife",
		"size": 1.25,
	},
	{
		"id": "spear",
		"scene": preload("res://assets/models/quaternius_zombie_apocalypse/characters/Characters_Sam.gltf"),
		"weapon": &"Spear",
		"size": 2.2,
	},
]


func _initialize() -> void:
	call_deferred(&"_generate_all")


func _generate_all() -> void:
	await process_frame
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	if directory_error != OK:
		push_error("UI icon generator could not create the output directory.")
		quit(1)
		return
	var failed_count := 0
	for spec in CHARACTER_SPECS:
		var success: bool = await _render_icon(spec, true)
		if not success:
			failed_count += 1
	for spec in WEAPON_SPECS:
		var success: bool = await _render_icon(spec, false)
		if not success:
			failed_count += 1
	if failed_count > 0:
		push_error("UI icon generator failed for %d icons." % failed_count)
		quit(1)
		return
	print("ICON GENERATOR: wrote %d transparent PNGs" % (
		CHARACTER_SPECS.size() + WEAPON_SPECS.size()
	))
	quit(0)


func _render_icon(spec: Dictionary, is_portrait: bool) -> bool:
	var viewport := SubViewport.new()
	viewport.size = ICON_SIZE
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var stage := Node3D.new()
	viewport.add_child(stage)
	_add_lighting(stage)
	var packed_scene: PackedScene = spec["scene"] as PackedScene
	var model := packed_scene.instantiate() as Node3D
	if model == null:
		viewport.queue_free()
		return false
	stage.add_child(model)
	var weapon_name := StringName(spec["weapon"])
	if not _configure_geometry(model, weapon_name, is_portrait):
		push_error("UI icon generator could not find mesh %s." % weapon_name)
		viewport.queue_free()
		return false
	_play_idle(model)

	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	if is_portrait:
		model.rotation.y = deg_to_rad(-18.0)
		camera.position = Vector3(0.0, 1.3, 2.7)
		camera.fov = 34.0
		camera.look_at(Vector3(0.0, 1.25, 0.0), Vector3.UP)
	else:
		model.rotation.y = deg_to_rad(8.0)
		var weapon_bounds := _get_visible_bounds(model)
		var weapon_center := weapon_bounds.get_center()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(
			maxf(weapon_bounds.size.y, weapon_bounds.size.z) * 1.35,
			0.55
		)
		camera.position = weapon_center + Vector3(3.2, 0.0, 0.0)
		camera.look_at(weapon_center, Vector3.UP)

	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var image := _center_subject(viewport.get_texture().get_image(), is_portrait)
	var prefix := "class_" if is_portrait else "weapon_"
	var output_path := ProjectSettings.globalize_path(
		"%s/%s%s.png" % [OUTPUT_DIRECTORY, prefix, String(spec["id"])]
	)
	var save_error := image.save_png(output_path)
	viewport.queue_free()
	await process_frame
	if save_error != OK:
		push_error("UI icon generator could not save %s." % output_path)
		return false
	print("ICON: %s" % output_path)
	return true


func _center_subject(source: Image, is_portrait: bool) -> Image:
	source.convert(Image.FORMAT_RGBA8)
	var used_rect := source.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return source
	var cropped := source.get_region(used_rect)
	var target_extent := 296 if is_portrait else 278
	var resize_factor := minf(
		float(target_extent) / float(cropped.get_width()),
		float(target_extent) / float(cropped.get_height())
	)
	var resized_size := Vector2i(
		maxi(1, roundi(cropped.get_width() * resize_factor)),
		maxi(1, roundi(cropped.get_height() * resize_factor))
	)
	cropped.resize(resized_size.x, resized_size.y, Image.INTERPOLATE_LANCZOS)
	var centered := Image.create(
		ICON_SIZE.x, ICON_SIZE.y, false, Image.FORMAT_RGBA8
	)
	centered.fill(Color(0.0, 0.0, 0.0, 0.0))
	var destination := Vector2i(
		(ICON_SIZE.x - resized_size.x) / 2,
		(ICON_SIZE.y - resized_size.y) / 2
	)
	centered.blit_rect(cropped, Rect2i(Vector2i.ZERO, resized_size), destination)
	return centered


func _add_lighting(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.4, 0.52, 1.0)
	environment.ambient_light_energy = 1.2
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation = Vector3(-0.55, -0.75, 0.0)
	key_light.light_color = Color(1.0, 0.78, 0.55, 1.0)
	key_light.light_energy = 1.9
	stage.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-1.8, 1.7, 2.0)
	fill_light.light_color = Color(0.35, 0.58, 0.9, 1.0)
	fill_light.light_energy = 2.3
	fill_light.omni_range = 6.0
	stage.add_child(fill_light)


func _configure_geometry(
	model: Node, visible_weapon: StringName, is_portrait: bool
) -> bool:
	var found_weapon := false
	for geometry_value in model.find_children("*", "GeometryInstance3D", true, false):
		var geometry := geometry_value as GeometryInstance3D
		if geometry == null:
			continue
		var is_weapon := StringName(geometry.name) in EMBEDDED_WEAPON_NAMES
		if is_weapon:
			geometry.visible = StringName(geometry.name) == visible_weapon
			found_weapon = found_weapon or geometry.visible
		elif not is_portrait:
			geometry.visible = false
	return found_weapon


func _get_visible_bounds(model: Node) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for mesh_value in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_value as MeshInstance3D
		if mesh_instance == null or not mesh_instance.visible:
			continue
		var local_bounds := mesh_instance.get_aabb()
		for corner_x in 2:
			for corner_y in 2:
				for corner_z in 2:
					var local_point := local_bounds.position + Vector3(
						local_bounds.size.x * corner_x,
						local_bounds.size.y * corner_y,
						local_bounds.size.z * corner_z
					)
					var world_point := mesh_instance.global_transform * local_point
					if not has_bounds:
						bounds = AABB(world_point, Vector3.ZERO)
						has_bounds = true
					else:
						bounds = bounds.expand(world_point)
	return bounds


func _play_idle(model: Node) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	if player == null:
		return
	var idle := &"Idle_Gun" if player.has_animation(&"Idle_Gun") else &"Idle"
	if player.has_animation(idle):
		player.play(idle)
		player.advance(0.0)
