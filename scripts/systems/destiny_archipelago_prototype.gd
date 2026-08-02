class_name DestinyArchipelagoPrototype
extends Node3D

signal prototype_ready
signal island_discovered(island_id: StringName)

const DESIGN := preload("res://scripts/systems/destiny_archipelago_design.gd")
const REGION_DIRECTORY := "res://data/destiny_archipelago/regions"

const TREE_SCENE := preload("res://assets/models/kenney_mini_forest/tree.glb")
const TREE_HIGH_SCENE := preload("res://assets/models/kenney_mini_forest/tree-high.glb")
const PLANT_SCENE := preload("res://assets/models/kenney_mini_forest/plant.glb")
const TENT_SCENE := preload("res://assets/models/kenney_mini_forest/tent.glb")
const FLAG_SCENE := preload("res://assets/models/kenney_mini_forest/flag.glb")
const ROCK_LOW_SCENE := preload("res://assets/models/kenney_mini_forest/rocks-low.glb")
const ROCK_HIGH_SCENE := preload("res://assets/models/kenney_mini_forest/rocks-high.glb")
const PINE_SCENE := preload("res://assets/models/kenney_graveyard_kit/pine.glb")
const PINE_CROOKED_SCENE := preload("res://assets/models/kenney_graveyard_kit/pine-crooked.glb")
const ROCK_TALL_SCENE := preload("res://assets/models/kenney_graveyard_kit/rocks-tall.glb")
const PILLAR_SCENE := preload("res://assets/models/kenney_graveyard_kit/pillar-square.glb")
const OBELISK_SCENE := preload("res://assets/models/kenney_graveyard_kit/pillar-obelisk.glb")
const ALTAR_SCENE := preload("res://assets/models/kenney_graveyard_kit/altar-stone.glb")
const FIRE_BASKET_SCENE := preload("res://assets/models/kenney_graveyard_kit/fire-basket.glb")

@export var archipelago_data: ArchipelagoData

@onready var terrain_mount: Terrain3DPersistentMount = %TerrainMount
@onready var player: CharacterBody3D = %Player
@onready var props: Node3D = %Props
@onready var routes: Node3D = %Routes
@onready var landmarks: Node3D = %Landmarks
@onready var status_label: Label = %StatusLabel
@onready var graph_map: ArchipelagoGraphMap = %ArchipelagoMap

var terrain: Terrain3D
var rope_bridge: DestructibleRouteBridge
var cave_gate: ArchipelagoRouteGate
var is_ready := false
var loaded_persistent_data := false
var prop_count := 0
var route_count := 0
var current_island_id: StringName = &""
var visited_island_ids: Dictionary[StringName, bool] = {}
var route_traversal_count := 0
var boss_island_reached := false


func _ready() -> void:
	status_label.text = "Preparing Destiny Archipelago..."
	_build_prototype.call_deferred()


func _physics_process(_delta: float) -> void:
	if not is_ready:
		return
	var detected_island := DESIGN.get_island_at(
		Vector2(player.global_position.x, player.global_position.z)
	)
	if detected_island != &"" and detected_island != current_island_id:
		_enter_island(detected_island)
	if player.global_position.y < DESIGN.WATER_HEIGHT - 0.8:
		player.global_position = DESIGN.get_safe_position(current_island_id)
		player.velocity = Vector3.ZERO
		status_label.text = "DEEP WATER // RETURNED TO %s" % _current_island_name().to_upper()


func get_visited_count() -> int:
	return visited_island_ids.size()


func _build_prototype() -> void:
	if archipelago_data == null:
		push_error("Destiny Archipelago requires ArchipelagoData.")
		return
	var graph_errors := archipelago_data.validate_graph()
	if not graph_errors.is_empty():
		for graph_error in graph_errors:
			push_error("Destiny Archipelago graph: %s" % graph_error)
		return
	terrain = terrain_mount.get_terrain()
	if terrain == null:
		await terrain_mount.terrain_ready
		terrain = terrain_mount.get_terrain()
	if terrain == null:
		push_error("Destiny Archipelago could not mount Terrain3D data.")
		return
	if terrain.data.get_region_count() != DESIGN.EXPECTED_REGION_COUNT:
		push_error(
			"Destiny Archipelago expected %d regions in %s, found %d."
			% [DESIGN.EXPECTED_REGION_COUNT, REGION_DIRECTORY, terrain.data.get_region_count()]
		)
		return
	loaded_persistent_data = true
	terrain.collision.mode = Terrain3DCollision.FULL_GAME
	terrain.collision.build()

	_build_safety_boundary()
	_build_island_labels()
	_build_shallow_reef()
	_build_sea_cave()
	_build_rope_bridge()
	_build_ancient_ruins()
	_build_island_dressing()
	_configure_player()
	graph_map.configure(archipelago_data)
	_enter_island(archipelago_data.starting_island_id)
	await get_tree().physics_frame
	await get_tree().physics_frame
	is_ready = true
	status_label.text = (
		"DESTINY ARCHIPELAGO // 4 ISLANDS // 4 ROUTES\n"
		+ "Choose Route A north or Route B east // Reach the boss island"
	)
	prototype_ready.emit()


func _configure_player() -> void:
	player.global_position = DESIGN.player_position_on_land(DESIGN.PLAYER_START)
	var tactical_map_layer := player.get_node_or_null("TacticalMapLayer") as CanvasLayer
	if tactical_map_layer != null:
		tactical_map_layer.visible = false


func _build_shallow_reef() -> void:
	var reef_material := StandardMaterial3D.new()
	reef_material.albedo_color = Color(0.64, 0.53, 0.3)
	reef_material.roughness = 0.98
	var reef_mesh := CylinderMesh.new()
	reef_mesh.top_radius = 1.0
	reef_mesh.bottom_radius = 1.0
	reef_mesh.height = 0.1
	reef_mesh.radial_segments = 10
	reef_mesh.material = reef_material
	var patch_count := 22
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = reef_mesh
	multimesh.instance_count = patch_count
	for index in range(patch_count):
		var progress := float(index) / float(patch_count - 1)
		var width := 4.2 + sin(float(index) * 1.73) * 0.75
		var depth := 4.4 + cos(float(index) * 1.17) * 0.55
		var basis := Basis.IDENTITY.scaled(Vector3(width, 1.0, depth))
		var patch_position := Vector3(
			120.0 + sin(float(index) * 1.31) * 1.35,
			-1.98,
			lerpf(198.0, 332.0, progress)
		)
		multimesh.set_instance_transform(index, Transform3D(basis, patch_position))
	var reef := MultiMeshInstance3D.new()
	reef.name = "RouteA_ShallowReef"
	reef.multimesh = multimesh
	routes.add_child(reef)
	_add_route_label(
		"RouteALabel", "ROUTE A // SHALLOW REEF\nLOW TIDE // OPEN",
		Vector3(120.0, -0.2, 326.0), Color(0.92, 0.78, 0.38)
	)
	route_count += 1


func _build_sea_cave() -> void:
	var route_data := archipelago_data.get_route(&"sea_cave")
	cave_gate = ArchipelagoRouteGate.new()
	cave_gate.name = "RouteB_SeaCaveGate"
	routes.add_child(cave_gate)
	cave_gate.global_position = DESIGN.player_position_on_land(DESIGN.CAVE_ENTRY) - Vector3.UP
	cave_gate.configure(route_data, DESIGN.player_position_on_land(DESIGN.CLIFFS_SAFE))
	cave_gate.route_traversed.connect(_on_route_traversed)
	_build_cave_mouth(DESIGN.CAVE_ENTRY, "DawnCaveMouth", 1.0)
	_build_cave_mouth(DESIGN.CAVE_EXIT, "CliffsCaveMouth", -1.0)
	_add_route_label(
		"CliffsCaveExitLabel", "ROUTE B // SEA CAVE EXIT",
		DESIGN.position_on_land(DESIGN.CAVE_EXIT) + Vector3.UP * 3.2,
		Color(0.34, 0.82, 1.0)
	)
	route_count += 1


func _build_cave_mouth(position: Vector3, prefix: String, facing: float) -> void:
	for index in range(5):
		var angle := lerpf(-1.05, 1.05, float(index) / 4.0)
		var offset := Vector3(cos(angle) * 3.0 * facing, 0.0, sin(angle) * 3.6)
		_add_prop(
			ROCK_TALL_SCENE, position + offset, angle, 2.2,
			"%sRock%02d" % [prefix, index + 1]
		)


func _build_rope_bridge() -> void:
	rope_bridge = DestructibleRouteBridge.new()
	rope_bridge.name = "RouteC_RopeBridge"
	routes.add_child(rope_bridge)
	rope_bridge.configure(
		Vector3(183.0, -1.35, 135.0), Vector3(317.0, -1.35, 135.0)
	)
	rope_bridge.destroyed.connect(_on_bridge_destroyed)
	route_count += 1


func _build_ancient_ruins() -> void:
	var route_root := StaticBody3D.new()
	route_root.name = "RouteD_AncientRuins"
	route_root.collision_layer = 1
	route_root.collision_mask = 0
	routes.add_child(route_root)
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.3, 0.31, 0.29)
	stone_material.roughness = 0.96
	var step_mesh := BoxMesh.new()
	step_mesh.size = Vector3(5.2, 0.32, 3.8)
	step_mesh.material = stone_material
	var step_count := 32
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = step_mesh
	multimesh.instance_count = step_count
	for index in range(step_count):
		var progress := float(index) / float(step_count - 1)
		var step_position := Vector3(
			385.0, lerpf(-1.5, 0.15, progress), lerpf(315.0, 200.0, progress)
		)
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, step_position))
		var collision := CollisionShape3D.new()
		collision.name = "StepCollision%02d" % (index + 1)
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.2, 0.34, 3.8)
		collision.shape = shape
		collision.position = step_position
		route_root.add_child(collision)
	var steps := MultiMeshInstance3D.new()
	steps.name = "StoneSteps"
	steps.multimesh = multimesh
	route_root.add_child(steps)
	for index in range(6):
		var progress := float(index) / 5.0
		var z_position := lerpf(308.0, 207.0, progress)
		for side in [-1.0, 1.0]:
			_add_prop(
				PILLAR_SCENE, Vector3(389.0 + side * 3.0, 0.0, z_position),
				0.0, 1.6, "RuinsPillar%02d_%s" % [index + 1, "L" if side < 0.0 else "R"]
			)
	_add_route_label(
		"RouteDLabel", "ROUTE D // ANCIENT RUINS\nGUARD ENCOUNTER PLACEHOLDER",
		Vector3(385.0, 2.0, 306.0), Color(0.78, 0.72, 0.58)
	)
	route_count += 1


func _build_island_dressing() -> void:
	_add_prop(TENT_SCENE, Vector3(108.0, 0.0, 391.0), 0.4, 1.8, "DawnHubTent")
	_add_prop(FLAG_SCENE, Vector3(124.0, 0.0, 382.0), -0.2, 2.2, "DawnHubFlag")
	_scatter_scene(TREE_SCENE, DESIGN.DAWN_CENTER, DESIGN.DAWN_RADII, 7, 101, "DawnTree", 1.4, 2.0)
	_scatter_scene(TREE_HIGH_SCENE, DESIGN.FOREST_CENTER, DESIGN.FOREST_RADII, 22, 202, "ForestTree", 1.8, 2.8)
	_scatter_scene(PINE_SCENE, DESIGN.FOREST_CENTER, DESIGN.FOREST_RADII, 16, 203, "ForestPine", 1.7, 2.5)
	_scatter_scene(PINE_CROOKED_SCENE, DESIGN.FOREST_CENTER, DESIGN.FOREST_RADII, 8, 204, "ForestCrookedPine", 1.5, 2.2)
	_scatter_scene(PLANT_SCENE, DESIGN.FOREST_CENTER, DESIGN.FOREST_RADII, 10, 205, "ForestPlant", 1.4, 2.1)
	_scatter_scene(ROCK_HIGH_SCENE, DESIGN.CLIFFS_CENTER, DESIGN.CLIFFS_RADII, 18, 303, "CliffRock", 1.7, 3.0)
	_scatter_scene(ROCK_TALL_SCENE, DESIGN.CLIFFS_CENTER, DESIGN.CLIFFS_RADII, 12, 304, "CliffSpire", 1.8, 2.8)
	_add_prop(OBELISK_SCENE, Vector3(405.0, 0.0, 374.0), 0.3, 2.5, "CliffsWindMarker")
	_scatter_scene(ROCK_TALL_SCENE, DESIGN.VOLCANO_CENTER, DESIGN.VOLCANO_RADII, 20, 404, "VolcanoRock", 1.8, 3.2)
	for index in range(4):
		var angle := float(index) * TAU / 4.0
		_add_prop(
			FIRE_BASKET_SCENE,
			Vector3(385.0 + cos(angle) * 17.0, 0.0, 130.0 + sin(angle) * 17.0),
			angle, 2.0, "VolcanoFire%02d" % (index + 1)
		)
	_add_prop(ALTAR_SCENE, Vector3(385.0, 0.0, 145.0), 0.0, 2.0, "BossAltar")
	_build_volcano_crater()


func _build_volcano_crater() -> void:
	var lava_material := StandardMaterial3D.new()
	lava_material.albedo_color = Color(0.85, 0.08, 0.015)
	lava_material.emission_enabled = true
	lava_material.emission = Color(1.0, 0.12, 0.01)
	lava_material.emission_energy_multiplier = 3.5
	lava_material.roughness = 0.22
	var lava_mesh := CylinderMesh.new()
	lava_mesh.top_radius = 7.0
	lava_mesh.bottom_radius = 7.0
	lava_mesh.height = 0.14
	lava_mesh.radial_segments = 24
	lava_mesh.material = lava_material
	var lava := MeshInstance3D.new()
	lava.name = "VolcanoLava"
	lava.position = DESIGN.position_on_land(Vector3(385.0, 0.0, 130.0)) + Vector3.UP * 0.08
	lava.mesh = lava_mesh
	landmarks.add_child(lava)
	var light := OmniLight3D.new()
	light.name = "LavaGlow"
	light.position = lava.position + Vector3.UP * 2.0
	light.light_color = Color(1.0, 0.18, 0.04)
	light.light_energy = 2.2
	light.omni_range = 24.0
	landmarks.add_child(light)
	var boss_marker := Marker3D.new()
	boss_marker.name = "BossArenaMarker"
	boss_marker.position = DESIGN.player_position_on_land(DESIGN.VOLCANO_SAFE)
	landmarks.add_child(boss_marker)
	_add_route_label(
		"BossArenaLabel", "VOLCANO PEAK // BOSS ARENA\nENCOUNTER PLACEHOLDER",
		DESIGN.position_on_land(Vector3(385.0, 0.0, 150.0)) + Vector3.UP * 4.0,
		Color(1.0, 0.25, 0.08)
	)


func _build_island_labels() -> void:
	for island in archipelago_data.islands:
		var position := DESIGN.position_on_land(
			Vector3(island.world_position.x, 0.0, island.world_position.y)
		) + Vector3.UP * 4.5
		var suffix := " // FINAL BOSS" if island.island_id == &"volcano_peak" else ""
		_add_route_label(
			"%sLabel" % island.island_id,
			"%s%s\n%s // %s" % [
				island.display_name.to_upper(), suffix,
				island.difficulty.to_upper(), island.terrain_type.to_upper()
			],
			position,
			Color(1.0, 0.62, 0.2) if island.island_id == &"volcano_peak" else Color(0.84, 0.9, 0.82)
		)


func _build_safety_boundary() -> void:
	var boundary := StaticBody3D.new()
	boundary.name = "ArchipelagoSafetyBoundary"
	boundary.add_to_group(&"archipelago_boundary")
	boundary.collision_layer = 1
	boundary.collision_mask = 0
	add_child(boundary)
	for entry in [
		{"position": Vector3(14.0, 2.0, 256.0), "size": Vector3(2.0, 16.0, 484.0)},
		{"position": Vector3(498.0, 2.0, 256.0), "size": Vector3(2.0, 16.0, 484.0)},
		{"position": Vector3(256.0, 2.0, 14.0), "size": Vector3(484.0, 16.0, 2.0)},
		{"position": Vector3(256.0, 2.0, 498.0), "size": Vector3(484.0, 16.0, 2.0)},
	]:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = entry["size"]
		collision.shape = shape
		collision.position = entry["position"]
		boundary.add_child(collision)


func _scatter_scene(
	source: PackedScene,
	center: Vector2,
	radii: Vector2,
	count: int,
	seed_value: int,
	prefix: String,
	minimum_scale: float,
	maximum_scale: float
) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 20:
		attempts += 1
		var angle := random.randf_range(0.0, TAU)
		var radius := sqrt(random.randf_range(0.12, 0.7))
		var point := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * radius
		if DESIGN.height_at(point.x, point.y) <= DESIGN.WATER_HEIGHT + 0.3:
			continue
		var scale_factor := random.randf_range(minimum_scale, maximum_scale)
		_add_prop(
			source, Vector3(point.x, 0.0, point.y), random.randf_range(0.0, TAU),
			scale_factor, "%s%02d" % [prefix, placed + 1]
		)
		placed += 1


func _add_prop(
	source: PackedScene,
	horizontal_position: Vector3,
	y_rotation: float,
	scale_factor: float,
	prop_name: String
) -> void:
	var instance := source.instantiate() as Node3D
	if instance == null:
		return
	instance.name = prop_name
	instance.position = DESIGN.position_on_land(horizontal_position)
	instance.rotation.y = y_rotation
	instance.scale = Vector3.ONE * scale_factor
	props.add_child(instance)
	prop_count += 1


func _add_route_label(
	label_name: String, text: String, position: Vector3, color: Color
) -> void:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.font_size = 44
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = color
	landmarks.add_child(label)


func _enter_island(island_id: StringName) -> void:
	current_island_id = island_id
	var first_visit := not visited_island_ids.has(island_id)
	visited_island_ids[island_id] = true
	graph_map.set_current_island(island_id)
	var island := archipelago_data.get_island(island_id)
	if island == null:
		return
	status_label.text = "%s // %s\n%s" % [
		island.display_name.to_upper(), island.difficulty.to_upper(), island.terrain_type
	]
	if island_id == &"volcano_peak":
		boss_island_reached = true
		status_label.text += " // BOSS ARENA REACHED"
	if first_visit:
		island_discovered.emit(island_id)


func _on_route_traversed(route_id: StringName, destination_id: StringName) -> void:
	route_traversal_count += 1
	_enter_island(destination_id)
	var route_data := archipelago_data.get_route(route_id)
	if route_data != null:
		status_label.text = "%s COMPLETE // %s" % [
			route_data.display_name.to_upper(), _current_island_name().to_upper()
		]


func _on_bridge_destroyed() -> void:
	status_label.text = "ROUTE C DESTROYED // ROUTE D REMAINS AVAILABLE"


func _current_island_name() -> String:
	var island := archipelago_data.get_island(current_island_id)
	return island.display_name if island != null else "Dawn Beach"
