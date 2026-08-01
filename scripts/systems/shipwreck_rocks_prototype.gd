class_name ShipwreckRocksPrototype
extends Node3D

signal prototype_ready

const DESIGN := preload("res://scripts/systems/shipwreck_rocks_design.gd")
const EXPECTED_REGION_COUNT := 1
const REGION_DIRECTORY := "res://data/shipwreck_rocks/regions"

const BRIDGE_SCENE := preload("res://assets/models/kenney_mini_forest/bridge.glb")
const ROCK_LOW_SCENE := preload("res://assets/models/kenney_mini_forest/rocks-low.glb")
const ROCK_HIGH_SCENE := preload("res://assets/models/kenney_mini_forest/rocks-high.glb")
const ROCK_TALL_SCENE := preload("res://assets/models/kenney_graveyard_kit/rocks-tall.glb")
const WRECK_SCENE := preload("res://assets/models/kenney_car_kit/truck-flat.glb")
const TIRE_SCENE := preload("res://assets/models/kenney_car_kit/debris-tire.glb")
const DOOR_SCENE := preload("res://assets/models/kenney_car_kit/debris-door.glb")
const BOX_LARGE_SCENE := preload("res://assets/models/kenney_factory_kit/box-large.glb")
const BOX_SMALL_SCENE := preload("res://assets/models/kenney_factory_kit/box-small.glb")

@onready var terrain_mount: Terrain3DPersistentMount = %TerrainMount
@onready var player: CharacterBody3D = %Player
@onready var props: Node3D = %Props
@onready var docks: Node3D = %Docks
@onready var ferry: AutomaticFerry = %AutomaticFerry
@onready var home_terminal: FerryTerminal = %HomeTerminal
@onready var island_terminal: FerryTerminal = %IslandTerminal
@onready var exclusive_salvage: ShipwreckSalvage = %ExclusiveSalvage
@onready var status_label: Label = %StatusLabel

var terrain: Terrain3D
var is_ready := false
var loaded_persistent_data := false
var prop_count := 0
var trip_count := 0
var salvage_found := false


func _ready() -> void:
	status_label.text = "Preparing Shipwreck Rocks..."
	call_deferred(&"_build_prototype")


func _physics_process(_delta: float) -> void:
	if not is_ready or ferry.is_moving():
		return
	if player.global_position.y < DESIGN.WATER_HEIGHT - 0.8:
		var safe_position := (
			DESIGN.player_position_on_land(DESIGN.HOME_DISEMBARK_POSITION)
			if ferry.current_dock_index == 0
			else DESIGN.player_position_on_land(DESIGN.ISLAND_DISEMBARK_POSITION)
		)
		player.global_position = safe_position
		player.velocity = Vector3.ZERO
		status_label.text = "DEEP WATER - RETURNED TO THE NEAREST DOCK"


func _build_prototype() -> void:
	terrain = terrain_mount.get_terrain()
	if terrain == null:
		await terrain_mount.terrain_ready
		terrain = terrain_mount.get_terrain()
	if terrain == null:
		push_error("Shipwreck Rocks could not mount its Terrain3D data.")
		status_label.text = "Terrain3D mount failed."
		return
	if terrain.data.get_region_count() != EXPECTED_REGION_COUNT:
		push_error(
			"Shipwreck Rocks expected one region in %s, found %d."
			% [REGION_DIRECTORY, terrain.data.get_region_count()]
		)
		status_label.text = "Terrain data missing. Run build_shipwreck_rocks_data.gd."
		return
	loaded_persistent_data = true
	terrain.collision.mode = Terrain3DCollision.FULL_GAME
	terrain.collision.build()

	_create_docks()
	_create_island_dressing()
	_configure_gameplay()
	await get_tree().physics_frame
	await get_tree().physics_frame
	is_ready = true
	status_label.text = (
		"SHIPWRECK ROCKS PILOT  -  %d REUSED PROPS\n"
		+ "Walk to the east dock and press F  -  Deep water returns you to shore"
	) % prop_count
	prototype_ready.emit()


func _configure_gameplay() -> void:
	player.global_position = DESIGN.player_position_on_land(
		DESIGN.HOME_PLAYER_POSITION
	)
	var weapon_controller := player.get_node_or_null("VisualRoot/WeaponPivot")
	if weapon_controller != null:
		weapon_controller.process_mode = Node.PROCESS_MODE_DISABLED
	var tactical_map_layer := player.get_node_or_null("TacticalMapLayer") as CanvasLayer
	if tactical_map_layer != null:
		tactical_map_layer.visible = false

	var dock_positions: Array[Vector3] = [
		DESIGN.HOME_FERRY_POSITION, DESIGN.ISLAND_FERRY_POSITION,
	]
	var landing_positions: Array[Vector3] = [
		DESIGN.player_position_on_land(DESIGN.HOME_DISEMBARK_POSITION),
		DESIGN.player_position_on_land(DESIGN.ISLAND_DISEMBARK_POSITION),
	]
	ferry.configure(dock_positions, landing_positions)
	home_terminal.global_position = DESIGN.player_position_on_land(
		DESIGN.HOME_TERMINAL_POSITION
	) - Vector3.UP * 0.65
	island_terminal.global_position = DESIGN.player_position_on_land(
		DESIGN.ISLAND_TERMINAL_POSITION
	) - Vector3.UP * 0.65
	home_terminal.configure(ferry)
	island_terminal.configure(ferry)
	ferry.trip_started.connect(_on_trip_started)
	ferry.trip_completed.connect(_on_trip_completed)

	exclusive_salvage.global_position = DESIGN.position_on_land(
		DESIGN.SALVAGE_POSITION
	)
	var salvage_visual := BOX_LARGE_SCENE.instantiate() as Node3D
	if salvage_visual != null:
		salvage_visual.name = "Visual"
		salvage_visual.scale = Vector3.ONE * 1.8
		exclusive_salvage.add_child(salvage_visual)
		prop_count += 1
	exclusive_salvage.recovered.connect(_on_salvage_recovered)


func _create_docks() -> void:
	for dock_entry in [
		{"prefix": "Home", "positions": [98.0, 102.0, 106.0], "z": 128.0},
		{"prefix": "Island", "positions": [142.0, 146.0, 150.0], "z": 129.0},
	]:
		var positions: Array = dock_entry["positions"]
		for index in range(positions.size()):
			var bridge := BRIDGE_SCENE.instantiate() as Node3D
			if bridge == null:
				continue
			bridge.name = "%sDock%02d" % [dock_entry["prefix"], index + 1]
			bridge.position = Vector3(
				float(positions[index]), DESIGN.WATER_HEIGHT + 0.32, float(dock_entry["z"])
			)
			bridge.rotation.y = PI * 0.5
			bridge.scale = Vector3.ONE * 1.8
			docks.add_child(bridge)
			prop_count += 1


func _create_island_dressing() -> void:
	_add_prop(ROCK_HIGH_SCENE, Vector3(171.0, 0.0, 117.0), 0.4, 2.4, "NorthRocks")
	_add_prop(ROCK_LOW_SCENE, Vector3(196.0, 0.0, 139.0), 1.8, 2.2, "SouthRocks")
	_add_prop(ROCK_TALL_SCENE, Vector3(198.0, 0.0, 121.0), 2.5, 1.9, "EastRocks")
	_add_prop(WRECK_SCENE, Vector3(189.0, 0.0, 134.0), -0.55, 1.7, "TruckWreck", 0.15)
	_add_prop(TIRE_SCENE, Vector3(176.0, 0.0, 137.0), 0.8, 2.0, "LooseTire", 0.3)
	_add_prop(DOOR_SCENE, Vector3(180.0, 0.0, 140.0), -1.1, 2.0, "WreckDoor", 0.4)
	_add_prop(BOX_LARGE_SCENE, Vector3(182.0, 0.0, 119.0), 0.25, 1.7, "CargoLarge")
	_add_prop(BOX_SMALL_SCENE, Vector3(188.0, 0.0, 118.0), -0.4, 2.0, "CargoSmall")
	_add_prop(ROCK_LOW_SCENE, Vector3(90.0, 0.0, 111.0), 0.9, 1.8, "HomeMarkerRock")


func _add_prop(
	source: PackedScene,
	horizontal_position: Vector3,
	y_rotation: float,
	scale_factor: float,
	prop_name: String,
	z_tilt: float = 0.0
) -> void:
	var instance := source.instantiate() as Node3D
	if instance == null:
		return
	instance.name = prop_name
	instance.position = DESIGN.position_on_land(horizontal_position)
	instance.rotation = Vector3(0.0, y_rotation, z_tilt)
	instance.scale = Vector3.ONE * scale_factor
	props.add_child(instance)
	prop_count += 1


func _on_trip_started(destination_index: int) -> void:
	status_label.text = (
		"FERRY DEPARTING FOR SHIPWRECK ROCKS..."
		if destination_index == 1
		else "FERRY RETURNING TO HOME SHORE..."
	)


func _on_trip_completed(dock_index: int) -> void:
	trip_count += 1
	status_label.text = (
		"SHIPWRECK ROCKS REACHED  -  SEARCH FOR THE ORANGE SALVAGE CACHE"
		if dock_index == 1
		else "HOME SHORE REACHED  -  FERRY READY"
	)


func _on_salvage_recovered(item_name: String) -> void:
	salvage_found = true
	status_label.text = "EXCLUSIVE FOUND  -  %s" % item_name
