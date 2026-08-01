extends Node3D

signal prototype_ready

const DESIGN := preload("res://scripts/systems/terrain3d_prototype_design.gd")
const EXPECTED_REGION_COUNT := 4
const NAVIGATION_HALF_SIZE := 78.0
const PLAYER_FLOOR_OFFSET := 1.05
const ENEMY_FLOOR_OFFSET := 1.05
const PROP_SEED := 7302026
const TREE_COUNT := 54
const ROCK_COUNT := 18

const TREE_SCENES: Array[PackedScene] = [
	preload("res://assets/models/kenney_mini_forest/tree.glb"),
	preload("res://assets/models/kenney_mini_forest/tree-high.glb"),
]
const ROCK_SCENES: Array[PackedScene] = [
	preload("res://assets/models/kenney_mini_forest/rocks-low.glb"),
	preload("res://assets/models/kenney_mini_forest/rocks-high.glb"),
]
const TENT_SCENE := preload("res://assets/models/kenney_mini_forest/tent.glb")
const FENCE_SCENE := preload("res://assets/models/kenney_mini_forest/fence.glb")
const FLAG_SCENE := preload("res://assets/models/kenney_mini_forest/flag.glb")
const STONES_SCENE := preload("res://assets/models/kenney_mini_forest/stones.glb")

@onready var terrain_mount: Node3D = %TerrainMount
@onready var navigation_region: NavigationRegion3D = %NavigationRegion3D
@onready var player: CharacterBody3D = %Player
@onready var enemies: Node3D = %Enemies
@onready var props: Node3D = %Props
@onready var path_root: Node3D = %PathRoot
@onready var status_label: Label = %StatusLabel

var is_ready := false
var loaded_persistent_data := false
var terrain: Terrain3D
var navigation_polygon_count := 0
var scattered_prop_count := 0
var setup_duration_ms := 0.0


func _ready() -> void:
	status_label.text = "Loading persistent terrain and navigation..."
	# Defer one frame so Terrain3D has completed its own node initialisation.
	call_deferred(&"_build_prototype")


func _build_prototype() -> void:
	var setup_started_usec := Time.get_ticks_usec()
	print("Terrain3D prototype: loading persistent regions")
	terrain = terrain_mount.call(&"get_terrain") as Terrain3D
	if terrain == null:
		await Signal(terrain_mount, &"terrain_ready")
		terrain = terrain_mount.call(&"get_terrain") as Terrain3D
	if terrain == null:
		push_error("Terrain3D prototype mount did not provide a terrain node.")
		status_label.text = "Terrain3D mount failed. Check the editor output."
		return
	if terrain.data.get_region_count() != EXPECTED_REGION_COUNT:
		var message := (
			"Terrain3D prototype expected %d persistent regions in %s, found %d."
			% [
				EXPECTED_REGION_COUNT,
				terrain.data_directory,
				terrain.data.get_region_count(),
			]
		)
		push_error(message)
		status_label.text = "Terrain3D data missing. Run the prototype data builder."
		return
	loaded_persistent_data = true

	# Full collision is appropriate for this small comparison scene. The final
	# map can use dynamic collision to keep only nearby regions active.
	print("Terrain3D prototype: building collision")
	terrain.collision.mode = Terrain3DCollision.FULL_GAME
	terrain.collision.build()

	print("Terrain3D prototype: placing route and props")
	_create_winding_path()
	_create_camp_dressing()
	_create_navigation_obstacles()
	_scatter_existing_props()
	_place_characters_on_terrain()
	print("Terrain3D prototype: baking navigation")
	_bake_navigation()

	await get_tree().physics_frame
	await get_tree().physics_frame
	setup_duration_ms = (Time.get_ticks_usec() - setup_started_usec) / 1000.0
	is_ready = true
	status_label.text = (
		"Persistent Terrain3D | %d NavMesh polygons | %d props | %.0f ms\n"
		+ "WASD: move  |  mouse: camera  |  Esc: release mouse"
	) % [navigation_polygon_count, scattered_prop_count, setup_duration_ms]
	print("Terrain3D prototype: ready")
	prototype_ready.emit()


func _create_winding_path() -> void:
	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color(0.27, 0.16, 0.075)
	path_material.roughness = 1.0
	var path_mesh := ImmediateMesh.new()
	path_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, path_material)
	var point_count := 0
	for world_z in range(-235, 236, 2):
		var z := float(world_z)
		var center_x := DESIGN.path_center_x(z)
		var next_x := DESIGN.path_center_x(z + 1.0)
		var tangent := Vector3(next_x - center_x, 0.0, 1.0).normalized()
		var side := Vector3(tangent.z, 0.0, -tangent.x) * 3.4
		for side_index in range(2):
			var side_sign := -1.0 if side_index == 0 else 1.0
			var point: Vector3 = Vector3(center_x, 0.0, z) + side * side_sign
			point.y = get_terrain_height(point) + 0.035
			path_mesh.surface_set_uv(
				Vector2(0.0 if side_sign < 0.0 else 1.0, point_count * 0.12)
			)
			path_mesh.surface_add_vertex(point)
		point_count += 1
	path_mesh.surface_end()
	var path_instance := MeshInstance3D.new()
	path_instance.name = "WindingDirtPath"
	path_instance.mesh = path_mesh
	path_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	path_root.add_child(path_instance)


func _create_camp_dressing() -> void:
	# The plateau is terrain, not a geometric floor. Existing low-poly assets
	# give the test area a readable camp silhouette without importing anything.
	_add_camp_prop(TENT_SCENE, Vector3(-10.5, 0.0, 1.5), -0.35, 2.0, "WestTent")
	_add_camp_prop(TENT_SCENE, Vector3(10.0, 0.0, -0.5), 0.5, 1.85, "EastTent")
	_add_camp_prop(FLAG_SCENE, Vector3(-5.0, 0.0, -5.5), 0.0, 2.2, "CampFlag")
	_add_camp_prop(STONES_SCENE, Vector3(2.5, 0.0, 2.0), 0.0, 1.7, "FireRing")

	var fence_positions: Array[Vector3] = [
		Vector3(-17.0, 0.0, -8.0),
		Vector3(-17.0, 0.0, 1.0),
		Vector3(-17.0, 0.0, 10.0),
		Vector3(17.0, 0.0, -8.0),
		Vector3(17.0, 0.0, 1.0),
		Vector3(17.0, 0.0, 10.0),
	]
	for index in range(fence_positions.size()):
		_add_camp_prop(
			FENCE_SCENE,
			fence_positions[index],
			0.0,
			1.7,
			"CampFence%02d" % (index + 1)
		)

	var tree_ring := [
		Vector3(-42.0, 0.0, -24.0), Vector3(-48.0, 0.0, 7.0),
		Vector3(-37.0, 0.0, 34.0), Vector3(-19.0, 0.0, 50.0),
		Vector3(20.0, 0.0, 51.0), Vector3(43.0, 0.0, 30.0),
		Vector3(48.0, 0.0, 4.0), Vector3(40.0, 0.0, -30.0),
	]
	for index in range(tree_ring.size()):
		_add_camp_prop(
			TREE_SCENES[index % TREE_SCENES.size()],
			tree_ring[index],
			index * 0.73,
			2.7 + float(index % 3) * 0.25,
			"CampTree%02d" % (index + 1)
		)


func _add_camp_prop(
	source_scene: PackedScene,
	horizontal_position: Vector3,
	y_rotation: float,
	scale_factor: float,
	prop_name: String
) -> void:
	var prop := source_scene.instantiate() as Node3D
	if prop == null:
		return
	prop.name = prop_name
	prop.position = Vector3(
		horizontal_position.x,
		get_terrain_height(horizontal_position),
		horizontal_position.z
	)
	prop.rotation.y = y_rotation
	prop.scale = Vector3.ONE * scale_factor
	props.add_child(prop)
	scattered_prop_count += 1


func _create_navigation_obstacles() -> void:
	var obstacle_positions := [
		Vector3(-4.0, 0.0, -43.0),
		Vector3(-0.5, 0.0, -43.5),
		Vector3(3.0, 0.0, -42.0),
	]
	for index in range(obstacle_positions.size()):
		var obstacle := StaticBody3D.new()
		obstacle.name = "NavigationRock%02d" % (index + 1)
		obstacle.collision_layer = 1
		obstacle.collision_mask = 0
		var position: Vector3 = obstacle_positions[index]
		position.y = get_terrain_height(position) + 0.8
		obstacle.position = position
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 1.3
		shape.height = 1.7
		shape_node.shape = shape
		obstacle.add_child(shape_node)
		var visual := ROCK_SCENES[index % ROCK_SCENES.size()].instantiate() as Node3D
		if visual != null:
			visual.position.y = -0.8
			visual.scale = Vector3.ONE * 2.2
			visual.rotation.y = index * 1.7
			obstacle.add_child(visual)
		navigation_region.add_child(obstacle)


func _scatter_existing_props() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = PROP_SEED
	for index in range(TREE_COUNT + ROCK_COUNT):
		var position := Vector3(
			random.randf_range(-205.0, 205.0),
			0.0,
			random.randf_range(-205.0, 205.0)
		)
		if Vector2(position.x, position.z).length() < 38.0:
			continue
		if absf(position.x - DESIGN.path_center_x(position.z)) < 9.0:
			continue
		if _terrain_slope_degrees(position) > 31.0:
			continue
		var is_tree := index < TREE_COUNT
		var source_scenes := TREE_SCENES if is_tree else ROCK_SCENES
		var packed_scene: PackedScene = source_scenes[
			random.randi_range(0, source_scenes.size() - 1)
		]
		var instance := packed_scene.instantiate() as Node3D
		if instance == null:
			continue
		instance.name = ("Tree" if is_tree else "Rock") + "%02d" % index
		position.y = get_terrain_height(position)
		instance.position = position
		instance.rotation.y = random.randf_range(0.0, TAU)
		var scale_factor := (
			random.randf_range(2.0, 3.4)
			if is_tree
			else random.randf_range(1.4, 2.5)
		)
		instance.scale = Vector3.ONE * scale_factor
		props.add_child(instance)
		scattered_prop_count += 1


func _terrain_slope_degrees(position: Vector3) -> float:
	var left_height := get_terrain_height(position + Vector3.LEFT)
	var right_height := get_terrain_height(position + Vector3.RIGHT)
	var back_height := get_terrain_height(position + Vector3.BACK)
	var forward_height := get_terrain_height(position + Vector3.FORWARD)
	var rise := maxf(
		absf(right_height - left_height),
		absf(forward_height - back_height)
	) * 0.5
	return rad_to_deg(atan(rise))


func _place_characters_on_terrain() -> void:
	player.position = _position_on_terrain(Vector3(0.0, 0.0, 13.0), PLAYER_FLOOR_OFFSET)
	var weapon_controller := player.get_node_or_null("VisualRoot/WeaponPivot")
	if weapon_controller != null:
		weapon_controller.process_mode = Node.PROCESS_MODE_DISABLED

	var enemy_positions := [
		Vector3(-1.5, 0.0, -55.0),
		Vector3(19.0, 0.0, -62.0),
	]
	for index in range(mini(enemy_positions.size(), enemies.get_child_count())):
		var enemy := enemies.get_child(index) as CharacterBody3D
		if enemy != null:
			enemy.position = _position_on_terrain(
				enemy_positions[index], ENEMY_FLOOR_OFFSET
			)


func _position_on_terrain(horizontal_position: Vector3, floor_offset: float) -> Vector3:
	return Vector3(
		horizontal_position.x,
		get_terrain_height(horizontal_position) + floor_offset,
		horizontal_position.z
	)


func get_terrain_height(world_position: Vector3) -> float:
	var height := terrain.data.get_height(world_position)
	return 0.0 if is_nan(height) else height


func _bake_navigation() -> void:
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = 0.75
	navigation_mesh.agent_height = 2.0
	navigation_mesh.agent_max_climb = 0.5
	navigation_mesh.agent_max_slope = 42.0
	navigation_mesh.cell_size = 0.75
	navigation_mesh.cell_height = 0.25
	navigation_mesh.geometry_parsed_geometry_type = (
		NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	)
	navigation_mesh.filter_baking_aabb = AABB(
		Vector3(-NAVIGATION_HALF_SIZE, -30.0, -NAVIGATION_HALF_SIZE),
		Vector3(NAVIGATION_HALF_SIZE * 2.0, 80.0, NAVIGATION_HALF_SIZE * 2.0)
	)

	var source_geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(
		navigation_mesh, source_geometry, navigation_region
	)
	var terrain_faces := terrain.generate_nav_mesh_source_geometry(
		navigation_mesh.filter_baking_aabb,
		false
	)
	if not terrain_faces.is_empty():
		source_geometry.add_faces(terrain_faces, Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(
		navigation_mesh, source_geometry
	)
	navigation_region.navigation_mesh = null
	navigation_region.navigation_mesh = navigation_mesh
	navigation_polygon_count = navigation_mesh.get_polygon_count()
