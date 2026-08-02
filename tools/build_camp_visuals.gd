extends SceneTree

## Builds the authored visual shell for the camp. Gameplay nodes (core,
## upgrades, fortifications and free construction) remain in camp_sector.tscn;
## this scene only provides readable spaces, cover and a fortified perimeter.
##
## Run: <godot> --headless --path . --script res://tools/build_camp_visuals.gd

const OUTPUT_PATH := "res://scenes/world/camp_visuals.tscn"
const WALL_HEIGHT := 2.6
const WALL_THICKNESS := 0.65
## The arena's physical floor ends at Y = 0. Decorative walkable surfaces only
## sit a few millimetres above it to avoid z-fighting without burying feet.
const WALKABLE_SURFACE_Y := 0.004
const CAMP_FLOOR_HEIGHT := 0.1
const ROUTE_NORTH_SOUTH_HEIGHT := 0.055
const ROUTE_EAST_WEST_HEIGHT := 0.06
## Measured from Street_Straight_Crack1.gltf. Its authored origin is below the
## visible surface, so placing the root at Y = 0 raised the road by about 12 cm.
const DAMAGED_ROAD_LOCAL_TOP_Y := 0.12
const MODEL_FENCE := preload("res://assets/models/kenney_graveyard_kit/fence.glb")
const MODEL_FENCE_DAMAGED := preload("res://assets/models/kenney_graveyard_kit/fence-damaged.glb")
const MODEL_LIGHTPOST := preload("res://assets/models/kenney_graveyard_kit/lightpost-single.glb")
const MODEL_FACTORY_POST := preload("res://assets/models/kenney_factory_kit/structure-yellow-high.glb")
const MODEL_MACHINE := preload("res://assets/models/kenney_factory_kit/machine-fortified.glb")
const MODEL_SCREEN := preload("res://assets/models/kenney_factory_kit/screen-panel-wide.glb")
const MODEL_CONTAINER_GREEN := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Container_Green.gltf")
const MODEL_CONTAINER_RED := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Container_Red.gltf")
const MODEL_BARREL := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Barrel.gltf")
const MODEL_CHEST := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Chest.gltf")
const MODEL_PALLET := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Pallet.gltf")
const MODEL_PALLET_BROKEN := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Pallet_Broken.gltf")
const MODEL_WHEELS := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Wheels_Stack.gltf")
const MODEL_TENT := preload("res://assets/models/kenney_mini_forest/tent.glb")
const MODEL_AMBULANCE := preload("res://assets/models/kenney_car_kit/ambulance.glb")
const MODEL_RIFLE := preload("res://assets/models/quaternius_zombie_apocalypse/weapons/Rifle.gltf")
const MODEL_PISTOL := preload("res://assets/models/quaternius_zombie_apocalypse/weapons/Pistol.gltf")
const MODEL_SHOTGUN := preload("res://assets/models/quaternius_zombie_apocalypse/weapons/Shotgun.gltf")
const MODEL_ROAD_DAMAGED := preload("res://assets/models/quaternius_zombie_apocalypse/environment/Street_Straight_Crack1.gltf")
const MODEL_TRAFFIC_BARRIER := preload("res://assets/models/quaternius_zombie_apocalypse/environment/TrafficBarrier_1.gltf")
const MODEL_PLASTIC_BARRIER := preload("res://assets/models/quaternius_zombie_apocalypse/environment/PlasticBarrier.gltf")
const MODEL_TOWN_SIGN := preload("res://assets/models/quaternius_zombie_apocalypse/environment/TownSign.gltf")
const MODEL_STREET_LIGHTS := preload("res://assets/models/quaternius_zombie_apocalypse/environment/StreetLights.gltf")
const MODEL_WATER_TOWER := preload("res://assets/models/quaternius_zombie_apocalypse/environment/WaterTower.gltf")
const MODEL_ARMORED_TRUCK := preload("res://assets/models/quaternius_zombie_apocalypse/vehicles/Vehicle_Truck_Armored.gltf")
const MODEL_FLAG := preload("res://assets/models/kenney_mini_forest/flag.glb")

var _materials: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_create_materials()

	var camp := Node3D.new()
	camp.name = "CampVisuals"
	_add_ground(camp)
	_add_perimeter(camp)
	_add_exterior_approaches(camp)
	_add_facilities(camp)
	_add_core_dressing(camp)

	_reown(camp, camp)
	var packed := PackedScene.new()
	if packed.pack(camp) != OK:
		push_error("Could not pack the camp visuals.")
		camp.free()
		_materials.clear()
		quit(1)
		return
	var error := ResourceSaver.save(packed, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save the camp visuals: %d" % error)
		camp.free()
		_materials.clear()
		quit(1)
		return
	camp.free()
	_materials.clear()
	print("BUILT: %s" % OUTPUT_PATH)
	quit(0)


func _create_materials() -> void:
	_material(&"floor", Color(0.105, 0.12, 0.13), 0.05, 0.94)
	_material(&"route", Color(0.17, 0.19, 0.2), 0.08, 0.88)
	_material(&"metal", Color(0.22, 0.25, 0.26), 0.72, 0.55)
	_material(&"dark_metal", Color(0.095, 0.11, 0.12), 0.82, 0.4)
	_material(&"rust", Color(0.45, 0.18, 0.065), 0.42, 0.82)
	_material(&"wood", Color(0.3, 0.19, 0.09), 0.02, 0.94)
	_material(&"canvas", Color(0.2, 0.3, 0.2), 0.0, 0.96)
	_material(&"medical", Color(0.17, 0.31, 0.23), 0.0, 0.92)
	_material(&"crate", Color(0.33, 0.22, 0.1), 0.0, 0.95)
	_material(&"sandbag", Color(0.42, 0.37, 0.25), 0.0, 0.98)
	_material(
		&"orange_glow", Color(0.95, 0.38, 0.06), 0.2, 0.42,
		Color(1.0, 0.22, 0.025), 2.0
	)
	_material(
		&"blue_glow", Color(0.12, 0.62, 0.9), 0.12, 0.46,
		Color(0.04, 0.4, 1.0), 1.6
	)
	_material(
		&"green_glow", Color(0.22, 0.9, 0.48), 0.05, 0.52,
		Color(0.03, 0.72, 0.28), 1.45
	)
	_material(
		&"white_glow", Color(0.86, 0.94, 0.87), 0.0, 0.48,
		Color(0.5, 1.0, 0.7), 1.15
	)


func _material(
	id: StringName,
	color: Color,
	metallic: float,
	roughness: float,
	emission: Color = Color(0.0, 0.0, 0.0, 0.0),
	emission_energy: float = 0.0
) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	_materials[id] = material


func _add_ground(parent: Node3D) -> void:
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 23.6
	floor_mesh.bottom_radius = 23.6
	floor_mesh.height = CAMP_FLOOR_HEIGHT
	floor_mesh.radial_segments = 32
	floor_mesh.material = _materials[&"floor"]
	var floor_visual := MeshInstance3D.new()
	floor_visual.name = "CampFloor"
	floor_visual.position.y = WALKABLE_SURFACE_Y - CAMP_FLOOR_HEIGHT * 0.5
	floor_visual.mesh = floor_mesh
	parent.add_child(floor_visual)

	# Clear axes make the four gates and the route back to the core readable.
	_add_visual_box(
		parent, "RouteNorthSouth",
		Vector3(
			0.0,
			WALKABLE_SURFACE_Y - ROUTE_NORTH_SOUTH_HEIGHT * 0.5,
			0.0
		),
		Vector3(6.2, ROUTE_NORTH_SOUTH_HEIGHT, 46.0), _materials[&"route"]
	)
	_add_visual_box(
		parent, "RouteEastWest",
		Vector3(
			0.0,
			WALKABLE_SURFACE_Y - ROUTE_EAST_WEST_HEIGHT * 0.5,
			0.0
		),
		Vector3(46.0, ROUTE_EAST_WEST_HEIGHT, 6.2), _materials[&"route"]
	)


func _add_perimeter(parent: Node3D) -> void:
	var perimeter := Node3D.new()
	perimeter.name = "FortifiedPerimeter"
	parent.add_child(perimeter)

	for z_position in [-22.0, 22.0]:
		for x_position in [-12.5, 12.5]:
			_add_wall_segment(
				perimeter,
				"Wall_%s_%s" % [_side_name(z_position), _side_name(x_position)],
				Vector3(x_position, WALL_HEIGHT * 0.5, z_position),
				Vector3(13.0, WALL_HEIGHT, WALL_THICKNESS)
			)
	for x_position in [-22.0, 22.0]:
		for z_position in [-12.5, 12.5]:
			_add_wall_segment(
				perimeter,
				"Wall_%s_%s" % [_side_name(x_position), _side_name(z_position)],
				Vector3(x_position, WALL_HEIGHT * 0.5, z_position),
				Vector3(13.0, WALL_HEIGHT, WALL_THICKNESS),
				PI * 0.5
			)

	var corners: Array[Dictionary] = [
		{"name": "CornerNW", "position": Vector3(-19.9, WALL_HEIGHT * 0.5, -19.9), "rotation": PI * 0.25},
		{"name": "CornerNE", "position": Vector3(19.9, WALL_HEIGHT * 0.5, -19.9), "rotation": -PI * 0.25},
		{"name": "CornerSW", "position": Vector3(-19.9, WALL_HEIGHT * 0.5, 19.9), "rotation": -PI * 0.25},
		{"name": "CornerSE", "position": Vector3(19.9, WALL_HEIGHT * 0.5, 19.9), "rotation": PI * 0.25},
	]
	for entry in corners:
		_add_wall_segment(
			perimeter, entry["name"], entry["position"],
			Vector3(5.2, WALL_HEIGHT, WALL_THICKNESS), entry["rotation"]
		)

	_add_gate(perimeter, "GateNorth", Vector3(0.0, 0.0, -22.0), 0.0)
	_add_gate(perimeter, "GateSouth", Vector3(0.0, 0.0, 22.0), 0.0)
	_add_gate(perimeter, "GateWest", Vector3(-22.0, 0.0, 0.0), PI * 0.5)
	_add_gate(perimeter, "GateEast", Vector3(22.0, 0.0, 0.0), PI * 0.5)

func _add_wall_segment(
	parent: Node3D,
	name: String,
	position: Vector3,
	size: Vector3,
	rotation_y: float = 0.0
) -> void:
	var body := _add_static_box(
		parent, name, position, size, _materials[&"metal"], rotation_y
	)
	(body.get_node("Mesh") as MeshInstance3D).visible = false
	var panel_count := maxi(floori(size.x / 4.0), 1)
	var spacing := size.x / float(panel_count)
	for index in panel_count:
		var x_position := -size.x * 0.5 + spacing * (index + 0.5)
		var panel_scene := MODEL_FENCE_DAMAGED if index % 3 == 1 else MODEL_FENCE
		_add_model(
			body, "FencePanel%d" % index, panel_scene,
			Vector3(x_position, -size.y * 0.5, 0.0), Vector3.ZERO,
			Vector3(4.0, 4.0, 4.0)
		)
		if index % 2 == 0:
			_add_model(
				body, "ScrapPallet%d" % index, MODEL_PALLET_BROKEN,
				Vector3(x_position + spacing * 0.18, -0.15, -0.42),
				Vector3(PI * 0.5, 0.12, 0.0), Vector3(1.55, 1.55, 1.55)
			)


func _add_gate(
	parent: Node3D, gate_name: String, position: Vector3, rotation_y: float
) -> void:
	var gate := Node3D.new()
	gate.name = gate_name
	gate.position = position
	gate.rotation.y = rotation_y
	parent.add_child(gate)
	for side in [-1.0, 1.0]:
		var post := _add_static_box(
			gate,
			"GatePost%s" % ("Left" if side < 0.0 else "Right"),
			Vector3(side * 5.3, 2.1, 0.0),
			Vector3(0.75, 4.2, 0.95),
			_materials[&"dark_metal"]
		)
		(post.get_node("Mesh") as MeshInstance3D).visible = false
		_add_model(
			post, "IndustrialPost", MODEL_FACTORY_POST,
			Vector3(0.0, -2.1, 0.0), Vector3.ZERO, Vector3(2.5, 2.8, 0.8)
		)
		_add_visual_box(
			post, "Beacon", Vector3(0.0, 0.35, -0.52),
			Vector3(0.44, 0.75, 0.08), _materials[&"orange_glow"]
		)
	_add_visual_box(
		gate, "GateHeader", Vector3(0.0, 4.2, 0.0),
		Vector3(11.2, 0.38, 0.75), _materials[&"metal"]
	)
	_add_visual_box(
		gate, "GateSignal", Vector3(0.0, 4.18, -0.41),
		Vector3(3.0, 0.15, 0.06), _materials[&"orange_glow"]
	)


func _add_exterior_approaches(parent: Node3D) -> void:
	var approaches := Node3D.new()
	approaches.name = "ExteriorApproaches"
	parent.add_child(approaches)

	var north := _add_approach_route(
		approaches, "NorthApproach", Vector3(0.0, 0.0, -28.0), PI * 0.5
	)
	_add_defense_checkpoint(north, 1.0)
	_add_static_model(
		north, "WaterTowerLandmark", MODEL_WATER_TOWER,
		Vector3(0.0, 0.0, 13.0), Vector3.ZERO, Vector3.ONE,
		Vector3(3.4, 8.0, 3.4)
	)

	var west := _add_approach_route(
		approaches, "WestApproach", Vector3(-28.0, 0.0, 0.0), 0.0
	)
	_add_defense_checkpoint(west, -1.0)
	_add_static_model(
		west, "ArmoredTruckLandmark", MODEL_ARMORED_TRUCK,
		Vector3(0.0, 0.0, -11.0), Vector3(0.0, PI * 0.5, 0.0),
		Vector3.ONE, Vector3(5.8, 2.8, 2.8)
	)

	var east := _add_approach_route(
		approaches, "EastApproach", Vector3(28.0, 0.0, 0.0), 0.0
	)
	_add_defense_checkpoint(east, 1.0)
	# The sign mesh is offset around its authored origin. It remains decorative
	# so its large gantry never creates a misleading invisible collision volume.
	_add_model(
		east, "TownSignLandmark", MODEL_TOWN_SIGN,
		Vector3(0.0, 0.0, 10.5), Vector3(0.0, -PI * 0.5, 0.0),
		Vector3(0.8, 0.8, 0.8)
	)
	_add_model(
		east, "StreetLightLandmark", MODEL_STREET_LIGHTS,
		Vector3(1.5, 0.0, 7.5), Vector3(0.0, PI * 0.5, 0.0),
		Vector3.ONE
	)

	var south := _add_approach_route(
		approaches, "SouthApproach", Vector3(0.0, 0.0, 28.0), PI * 0.5
	)
	for side in [-1.0, 1.0]:
		_add_model(
			south, "EvacuationFlag%s" % ("Left" if side < 0.0 else "Right"),
			MODEL_FLAG, Vector3(0.5, 0.0, side * 5.0),
			Vector3(0.0, PI if side < 0.0 else 0.0, 0.0),
			Vector3(2.1, 2.1, 2.1)
		)


func _add_approach_route(
	parent: Node3D, approach_name: String, position: Vector3, rotation_y: float
) -> Node3D:
	var approach := Node3D.new()
	approach.name = approach_name
	approach.position = position
	approach.rotation.y = rotation_y
	parent.add_child(approach)
	_add_model(
		approach, "DamagedRoad", MODEL_ROAD_DAMAGED,
		Vector3(0.0, WALKABLE_SURFACE_Y - DAMAGED_ROAD_LOCAL_TOP_Y, 0.0),
		Vector3.ZERO, Vector3.ONE
	)
	for side in [-1.0, 1.0]:
		_add_visual_box(
			approach, "Reflector%s" % ("Left" if side < 0.0 else "Right"),
			Vector3(-2.8, 0.18, side * 4.2), Vector3(0.16, 0.36, 0.7),
			_materials[&"orange_glow"]
		)
	return approach


func _add_defense_checkpoint(approach: Node3D, roadside: float) -> void:
	var checkpoint := _add_static_box(
		approach, "DefenseCheckpoint", Vector3(0.4, 0.55, roadside * 5.35),
		Vector3(4.2, 1.1, 1.35), _materials[&"dark_metal"]
	)
	(checkpoint.get_node("Mesh") as MeshInstance3D).visible = false
	_add_model(
		checkpoint, "TrafficBarrier", MODEL_TRAFFIC_BARRIER,
		Vector3(-1.0, -0.55, 0.0), Vector3.ZERO, Vector3.ONE
	)
	_add_model(
		checkpoint, "PlasticBarrier", MODEL_PLASTIC_BARRIER,
		Vector3(1.15, -0.55, 0.0), Vector3.ZERO, Vector3.ONE
	)
	_add_visual_box(
		checkpoint, "SafetySignal", Vector3(0.0, 0.25, 0.0),
		Vector3(1.4, 0.12, 0.08), _materials[&"orange_glow"]
	)


func _add_static_model(
	parent: Node3D,
	node_name: String,
	scene: PackedScene,
	position: Vector3,
	rotation: Vector3,
	scale: Vector3,
	collision_size: Vector3
) -> StaticBody3D:
	var body := _add_static_box(
		parent, node_name, position + Vector3.UP * collision_size.y * 0.5,
		collision_size, _materials[&"dark_metal"]
	)
	(body.get_node("Mesh") as MeshInstance3D).visible = false
	_add_model(
		body, "Model", scene, Vector3.DOWN * collision_size.y * 0.5,
		rotation, scale
	)
	return body


func _add_watch_tower(
	parent: Node3D, tower_name: String, position: Vector3, rotation_y: float
) -> void:
	var body := _add_static_box(
		parent, tower_name, position + Vector3(0.0, 2.35, 0.0),
		Vector3(3.8, 4.7, 3.8), _materials[&"dark_metal"], rotation_y
	)
	# Replace the full-box look with exposed supports while retaining one simple
	# collision footprint for predictable navigation.
	body.get_node("Mesh").visible = false
	for x_position in [-1.35, 1.35]:
		for z_position in [-1.35, 1.35]:
			_add_visual_box(
				body, "Post_%s_%s" % [_side_name(x_position), _side_name(z_position)],
				Vector3(x_position, -0.1, z_position), Vector3(0.28, 4.5, 0.28),
				_materials[&"wood"]
			)
	_add_visual_box(
		body, "Platform", Vector3(0.0, 1.35, 0.0),
		Vector3(3.8, 0.3, 3.8), _materials[&"metal"]
	)
	_add_visual_box(
		body, "Roof", Vector3(0.0, 2.65, 0.0),
		Vector3(4.5, 0.28, 4.5), _materials[&"canvas"]
	)
	for z_position in [-1.72, 1.72]:
		_add_visual_box(
			body, "RailZ_%s" % _side_name(z_position),
			Vector3(0.0, 2.0, z_position), Vector3(3.7, 0.16, 0.16),
			_materials[&"metal"]
		)
	var light := SpotLight3D.new()
	light.name = "FloodLight"
	light.position = Vector3(0.0, 2.1, -1.45)
	light.rotation.x = -0.82
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 2.4
	light.spot_range = 24.0
	light.spot_angle = 38.0
	light.shadow_enabled = false
	body.add_child(light)


func _add_facilities(parent: Node3D) -> void:
	var facilities := Node3D.new()
	facilities.name = "Facilities"
	parent.add_child(facilities)

	var storage := _add_facility_shell(
		facilities, "Storage", Vector3(-8.2, 0.0, -19.0), Vector2(10.5, 4.5),
		0.0, "STORAGE  /  SCRAP", _materials[&"orange_glow"]
	)
	_add_storage_details(storage)

	var workshop := _add_facility_shell(
		facilities, "Workshop", Vector3(7.2, 0.0, -19.0), Vector2(11.0, 4.5),
		0.0, "WORKSHOP  /  UPGRADES", _materials[&"blue_glow"]
	)
	_add_workshop_details(workshop)

	var armory := _add_facility_shell(
		facilities, "Armory", Vector3(-19.0, 0.0, 8.4), Vector2(9.5, 4.5),
		PI * 0.5, "ARMORY", _materials[&"orange_glow"]
	)
	_add_armory_details(armory)

	var medbay := _add_facility_shell(
		facilities, "Medbay", Vector3(19.0, 0.0, 8.4), Vector2(9.5, 4.5),
		-PI * 0.5, "MEDBAY  /  RESUPPLY", _materials[&"green_glow"]
	)
	_add_medbay_details(medbay)


func _add_facility_shell(
	parent: Node3D,
	facility_name: String,
	position: Vector3,
	size: Vector2,
	rotation_y: float,
	label_text: String,
	accent: Material
) -> Node3D:
	var facility := Node3D.new()
	facility.name = facility_name
	facility.position = position
	facility.rotation.y = rotation_y
	parent.add_child(facility)
	_add_visual_box(
		facility, "FloorPad", Vector3(0.0, 0.1, 0.0),
		Vector3(size.x, 0.12, size.y), _materials[&"route"]
	)
	_add_static_box(
		facility, "BackWall", Vector3(0.0, 1.35, -size.y * 0.5),
		Vector3(size.x, 2.7, 0.45), _materials[&"metal"]
	)
	var back_wall := facility.get_node("BackWall") as StaticBody3D
	(back_wall.get_node("Mesh") as MeshInstance3D).visible = false
	var fence_count := maxi(floori(size.x / 4.0), 1)
	var fence_spacing := size.x / float(fence_count)
	for index in fence_count:
		_add_model(
			back_wall, "Fence%d" % index, MODEL_FENCE,
			Vector3(
				-size.x * 0.5 + fence_spacing * (index + 0.5),
				-1.35,
				0.0
			),
			Vector3.ZERO, Vector3(4.0, 4.0, 4.0)
		)
	_add_model(
		facility, "WorkLight", MODEL_LIGHTPOST,
		Vector3(-size.x * 0.42, 0.0, size.y * 0.28),
		Vector3.ZERO, Vector3(3.0, 3.0, 3.0)
	)
	_add_visual_box(
		facility, "Accent", Vector3(0.0, 2.45, -size.y * 0.5 + 0.25),
		Vector3(size.x * 0.72, 0.13, 0.08), accent
	)
	var label := Label3D.new()
	label.name = "FacilityLabel"
	label.position = Vector3(0.0, 5.1, 0.0)
	label.text = label_text
	label.font_size = 27
	label.outline_size = 8
	label.modulate = Color(0.95, 0.88, 0.7)
	label.outline_modulate = Color(0.025, 0.025, 0.025)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	facility.add_child(label)
	return facility


func _add_storage_details(storage: Node3D) -> void:
	_add_model(
		storage, "StorageContainer", MODEL_CONTAINER_GREEN,
		Vector3(-1.7, 0.0, -0.55), Vector3.ZERO, Vector3.ONE
	)
	for entry in [
		{"name": "PalletA", "scene": MODEL_PALLET, "position": Vector3(2.2, 0.0, -1.0), "rotation": Vector3.ZERO},
		{"name": "PalletB", "scene": MODEL_PALLET_BROKEN, "position": Vector3(3.3, 0.0, -0.6), "rotation": Vector3(0.0, 0.35, 0.0)},
		{"name": "ChestA", "scene": MODEL_CHEST, "position": Vector3(2.2, 0.0, 0.55), "rotation": Vector3(0.0, -0.2, 0.0)},
		{"name": "ChestB", "scene": MODEL_CHEST, "position": Vector3(3.5, 0.0, 0.9), "rotation": Vector3(0.0, 0.18, 0.0)},
	]:
		_add_model(
			storage, String(entry["name"]), entry["scene"], entry["position"],
			entry["rotation"], Vector3.ONE
		)
	for index in 2:
		_add_model(
			storage, "Barrel%d" % index, MODEL_BARREL,
			Vector3(0.7 + index * 0.85, 0.0, 0.75), Vector3.ZERO, Vector3.ONE
		)
	_add_model(
		storage, "SpareWheels", MODEL_WHEELS,
		Vector3(4.25, 0.0, -1.2), Vector3.ZERO, Vector3(1.25, 1.25, 1.25)
	)


func _add_workshop_details(workshop: Node3D) -> void:
	var workbench := _add_static_box(
		workshop, "Workbench", Vector3(-2.3, 0.65, 0.7),
		Vector3(4.4, 1.3, 1.35), _materials[&"wood"]
	)
	(workbench.get_node("Mesh") as MeshInstance3D).visible = false
	var generator := _add_static_box(
		workshop, "Generator", Vector3(2.7, 0.85, -0.1),
		Vector3(3.0, 3.2, 3.8), _materials[&"dark_metal"]
	)
	(generator.get_node("Mesh") as MeshInstance3D).visible = false
	_add_model(
		workshop, "FortifiedMachine", MODEL_MACHINE,
		Vector3(2.7, 0.0, -0.1), Vector3.ZERO, Vector3(2.35, 2.35, 2.35)
	)
	_add_model(
		workshop, "DiagnosticScreen", MODEL_SCREEN,
		Vector3(-2.7, 0.0, 0.55), Vector3(0.0, PI, 0.0),
		Vector3(2.0, 2.0, 2.0)
	)
	_add_model(
		workshop, "PartsPallet", MODEL_PALLET,
		Vector3(-0.7, 0.0, -0.8), Vector3(0.0, 0.22, 0.0), Vector3.ONE
	)
	_add_visual_cylinder(
		workshop, "Antenna", Vector3(4.35, 3.0, -2.45),
		0.08, 5.6, _materials[&"metal"]
	)
	var light := OmniLight3D.new()
	light.name = "WorkshopLight"
	light.position = Vector3(2.7, 2.3, 0.2)
	light.light_color = Color(0.18, 0.66, 1.0)
	light.light_energy = 1.35
	light.omni_range = 7.0
	light.shadow_enabled = false
	workshop.add_child(light)


func _add_armory_details(armory: Node3D) -> void:
	_add_model(
		armory, "ArmoryContainer", MODEL_CONTAINER_RED,
		Vector3(0.0, 0.0, -0.75), Vector3.ZERO, Vector3.ONE
	)
	_add_static_box(
		armory, "Counter", Vector3(0.0, 0.7, 1.55),
		Vector3(5.7, 1.4, 1.1), _materials[&"wood"]
	)
	var firearm_scenes: Array[PackedScene] = [MODEL_RIFLE, MODEL_PISTOL, MODEL_SHOTGUN]
	for index in firearm_scenes.size():
		_add_model(
			armory, "Firearm%d" % index, firearm_scenes[index],
			Vector3(-2.0 + index * 2.0, 1.65, 0.92),
			Vector3(0.0, PI * 0.5, -0.12), Vector3(1.15, 1.15, 1.15)
		)
	var light := OmniLight3D.new()
	light.name = "ArmoryLight"
	light.position = Vector3(0.0, 2.25, 0.2)
	light.light_color = Color(1.0, 0.42, 0.08)
	light.light_energy = 1.45
	light.omni_range = 7.0
	light.shadow_enabled = false
	armory.add_child(light)


func _add_medbay_details(medbay: Node3D) -> void:
	_add_model(
		medbay, "MedicalTent", MODEL_TENT,
		Vector3(-1.35, 0.0, -0.25), Vector3(0.0, PI, 0.0),
		Vector3(4.0, 4.0, 4.0)
	)
	_add_model(
		medbay, "Ambulance", MODEL_AMBULANCE,
		Vector3(3.25, 0.0, 0.15), Vector3(0.0, PI, 0.0),
		Vector3(1.25, 1.25, 1.25)
	)
	_add_visual_box(
		medbay, "MedicalCrossHorizontal", Vector3(-1.35, 2.55, 1.9),
		Vector3(1.7, 0.48, 0.08), _materials[&"white_glow"]
	)
	_add_visual_box(
		medbay, "MedicalCrossVertical", Vector3(-1.35, 2.55, 1.91),
		Vector3(0.48, 1.7, 0.08), _materials[&"white_glow"]
	)
	var light := OmniLight3D.new()
	light.name = "MedbayLight"
	light.position = Vector3(0.0, 2.2, 0.2)
	light.light_color = Color(0.22, 1.0, 0.52)
	light.light_energy = 1.35
	light.omni_range = 7.0
	light.shadow_enabled = false
	medbay.add_child(light)


func _add_core_dressing(parent: Node3D) -> void:
	var dressing := Node3D.new()
	dressing.name = "CoreDressing"
	parent.add_child(dressing)
	for degrees in [30.0, 60.0, 120.0, 150.0, 210.0, 240.0, 300.0, 330.0]:
		var angle := deg_to_rad(degrees)
		var position := Vector3(cos(angle) * 4.5, 0.3, sin(angle) * 4.5)
		_add_static_box(
			dressing, "Sandbag%d" % roundi(degrees), position,
			Vector3(1.8, 0.55, 0.75), _materials[&"sandbag"], -angle
		)
	for degrees in [45.0, 135.0, 225.0, 315.0]:
		_add_core_light_post(dressing, degrees)
	for index in 2:
		_add_model(
			dressing, "SupplyChest%d" % index, MODEL_CHEST,
			Vector3(-6.0 if index == 0 else 6.5, 0.0, 7.0 + index * 0.5),
			Vector3(0.0, 0.18 if index == 0 else -0.16, 0.0),
			Vector3(1.15, 1.15, 1.15)
		)


func _add_core_light_post(parent: Node3D, degrees: float) -> void:
	var angle := deg_to_rad(degrees)
	var position := Vector3(cos(angle) * 3.7, 0.0, sin(angle) * 3.7)
	var post := Node3D.new()
	post.name = "CoreLightPost%d" % roundi(degrees)
	post.position = position
	parent.add_child(post)
	_add_visual_cylinder(
		post, "Pole", Vector3(0.0, 1.55, 0.0),
		0.075, 3.1, _materials[&"dark_metal"]
	)
	_add_visual_box(
		post, "Lamp", Vector3(0.0, 2.95, 0.0),
		Vector3(0.52, 0.32, 0.52), _materials[&"orange_glow"]
	)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, 2.75, 0.0)
	light.light_color = Color(1.0, 0.55, 0.22)
	light.light_energy = 1.4
	light.omni_range = 7.5
	light.shadow_enabled = false
	post.add_child(light)


func _add_model(
	parent: Node3D,
	node_name: String,
	scene: PackedScene,
	position: Vector3,
	rotation: Vector3,
	scale: Vector3
) -> Node3D:
	var instance := scene.instantiate() as Node3D
	if instance == null:
		push_error("Camp visual model '%s' must instantiate as Node3D." % node_name)
		return null
	instance.name = node_name
	instance.position = position
	instance.rotation = rotation
	instance.scale = scale
	parent.add_child(instance)
	return instance


func _add_static_box(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	rotation_y: float = 0.0
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation.y = rotation_y
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(&"navigation_blocker", true)
	parent.add_child(body)

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	body.add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_visual_box(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	rotation_y: float = 0.0,
	rotation_z: float = 0.0
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position
	visual.rotation = Vector3(0.0, rotation_y, rotation_z)
	visual.mesh = mesh
	parent.add_child(visual)
	return visual


func _add_visual_cylinder(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	radius: float,
	height: float,
	material: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.92
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position
	visual.mesh = mesh
	parent.add_child(visual)
	return visual


func _side_name(value: float) -> String:
	return "Negative" if value < 0.0 else "Positive"


func _reown(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner_node
		_reown(child, owner_node)
