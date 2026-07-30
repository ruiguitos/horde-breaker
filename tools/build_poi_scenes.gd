extends SceneTree

## Rebuilds the three point-of-interest scenes.
##
## Run:  <godot> --headless --path . --script res://tools/build_poi_scenes.gd
##
## The old scenes/world/exploration_pois.tscn built its own hospital, warehouse,
## outpost and fuel station out of box meshes. That was graybox from before the
## map existed, and it went out with it. A POI is now a compound of real painted
## pieces (tools/paint_world.gd) and these scenes hold only what cannot be
## painted: the encounter trigger, its spawn markers, the reward cache and the
## label. Nothing here builds walls.
##
## Everything sits in the POI's local space with the origin at the centre of the
## painted yard. The buildings stand at +16 m on x and z; the two open sides face
## the crossroads.

const OUTPUT_DIRECTORY := "res://scenes/world/"
const POI_GROUP := &"point_of_interest"
const ACCESS_POINT_GROUP := &"poi_access_point"
const INTERIOR_POINT_GROUP := &"poi_interior_point"
## The cache the procedural POIs used to drop and that went with them. Worth
## crossing a sector for, and gone for the rest of the run once taken.
const REWARD_SCRAP := 50
## Sits inside the 24 m yard without touching the buildings or the two props on
## the open sides, so the player has to actually walk into the compound.
const TRIGGER_SIZE := Vector3(12.0, 3.0, 12.0)
const TRIGGER_CENTRE := Vector3(0.0, 1.5, 1.0)
## Player physics layer. The trigger detects nothing else and is not detectable.
const PLAYER_MASK := 2

## Resources are pulled in at runtime, never preloaded: several of these scenes
## reach for autoloads, which do not exist yet while a --script tool compiles,
## and a preload here leaves the script broken for whoever loads it next.
const SCRAP_PICKUP_PATH := "res://scenes/pickups/scrap_pickup.tscn"
const AMMO_PICKUP_PATH := "res://scenes/pickups/ammo_pickup.tscn"
const NORMAL_ZOMBIE_PATH := "res://scenes/enemies/normal_zombie.tscn"
const RUNNER_ZOMBIE_PATH := "res://scenes/enemies/runner_zombie.tscn"

const POI_DEFINITIONS: Array[Dictionary] = [
	{
		"file": "poi_warehouse.tscn",
		"root": "WarehousePOI",
		"label": "WAREHOUSE",
		"colour": Color(0.45, 0.8, 1.0),
		"script": "res://scripts/systems/warehouse_encounter.gd",
		"encounter": "WarehouseEncounter",
		"encounter_group": &"warehouse_encounter",
		"exports": {
			&"enemy_scene": NORMAL_ZOMBIE_PATH,
			&"scrap_pickup_scene": SCRAP_PICKUP_PATH,
			&"ammunition_pickup_scene": AMMO_PICKUP_PATH,
		},
		"containers": [{
			"name": "WarehouseEnemySpawns",
			"markers": [
				{"name": "LeftSpawn", "position": Vector3(-6.0, 1.0, 7.0)},
				{"name": "RightSpawn", "position": Vector3(6.0, 1.0, 7.0)},
				{"name": "BackSpawn", "position": Vector3(9.0, 1.0, 0.0)},
			],
		}],
		"markers": [
			{"name": "WarehouseScrapSpawn", "position": Vector3(-2.5, 0.35, 3.0)},
			{"name": "WarehouseAmmunitionSpawn", "position": Vector3(2.5, 0.25, 3.0)},
		],
	},
	{
		"file": "poi_military_outpost.tscn",
		"root": "MilitaryOutpostPOI",
		"label": "MILITARY OUTPOST",
		"colour": Color(0.65, 0.82, 0.46),
		"script": "res://scripts/systems/military_outpost_encounter.gd",
		"encounter": "MilitaryOutpostEncounter",
		"encounter_group": &"military_outpost_encounter",
		"exports": {
			&"normal_enemy_scene": NORMAL_ZOMBIE_PATH,
			&"runner_enemy_scene": RUNNER_ZOMBIE_PATH,
			&"ammunition_pickup_scene": AMMO_PICKUP_PATH,
		},
		"containers": [
			{
				"name": "MilitaryEnemySpawns",
				"markers": [
					{
						"name": "NormalLeftSpawn",
						"position": Vector3(-6.0, 1.0, 7.0),
						"groups": [&"military_normal_spawn"],
					},
					{
						"name": "NormalRightSpawn",
						"position": Vector3(6.0, 1.0, 7.0),
						"groups": [&"military_normal_spawn"],
					},
					{
						"name": "RunnerSpawn",
						"position": Vector3(9.0, 1.0, 2.0),
						"groups": [&"military_runner_spawn"],
					},
				],
			},
			{
				"name": "MilitaryAmmunitionSpawns",
				"markers": [
					{"name": "LeftAmmunitionSpawn", "position": Vector3(-2.5, 0.25, 3.0)},
					{"name": "RightAmmunitionSpawn", "position": Vector3(2.5, 0.25, 3.0)},
				],
			},
		],
		"markers": [],
	},
	{
		"file": "poi_fuel_station.tscn",
		"root": "FuelStationPOI",
		"label": "FUEL DEPOT",
		"colour": Color(1.0, 0.65, 0.35),
		"script": "res://scripts/systems/fuel_station_encounter.gd",
		"encounter": "FuelStationEncounter",
		"encounter_group": &"fuel_station_encounter",
		"exports": {
			&"runner_enemy_scene": RUNNER_ZOMBIE_PATH,
			&"scrap_pickup_scene": SCRAP_PICKUP_PATH,
		},
		"containers": [
			{
				"name": "FuelStationEnemySpawns",
				"markers": [
					{"name": "LeftRunnerSpawn", "position": Vector3(-7.0, 1.0, 7.0)},
					{"name": "RightRunnerSpawn", "position": Vector3(7.0, 1.0, 7.0)},
					{"name": "YardRunnerSpawn", "position": Vector3(0.0, 1.0, 9.0)},
				],
			},
			{
				"name": "FuelStationScrapSpawns",
				"markers": [
					{"name": "LeftScrapSpawn", "position": Vector3(-2.5, 0.35, 3.0)},
					{"name": "RightScrapSpawn", "position": Vector3(2.5, 0.35, 3.0)},
				],
			},
		],
		"markers": [],
	},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var scrap_pickup: PackedScene = load(SCRAP_PICKUP_PATH)
	if scrap_pickup == null:
		push_error("Could not load the Scrap pickup")
		quit(1)
		return
	for definition in POI_DEFINITIONS:
		if not _build(definition, scrap_pickup):
			quit(1)
			return
	print("BUILT: %d point-of-interest scenes" % POI_DEFINITIONS.size())
	quit(0)


func _build(definition: Dictionary, scrap_pickup: PackedScene) -> bool:
	var root := Node3D.new()
	root.name = String(definition["root"])
	root.add_to_group(POI_GROUP, true)

	_add_encounter(root, definition)
	var unique_names: Array[Node] = []
	for container_value in definition["containers"]:
		var container_definition: Dictionary = container_value
		var container := Node3D.new()
		container.name = String(container_definition["name"])
		root.add_child(container)
		unique_names.append(container)
		for marker_value in container_definition["markers"]:
			_add_marker(container, marker_value)
	for marker_value in definition["markers"]:
		unique_names.append(_add_marker(root, marker_value))

	# The reward the procedural POIs used to carry, standing where the player
	# sees it on the way in.
	var reward := scrap_pickup.instantiate() as Node3D
	reward.name = "RewardCache"
	reward.set(&"scrap_amount", REWARD_SCRAP)
	root.add_child(reward)
	reward.position = Vector3(0.0, 0.35, -2.0)

	_add_marker(root, {
		"name": "InteriorPoint",
		"position": Vector3.ZERO,
		"groups": [INTERIOR_POINT_GROUP],
	})
	_add_marker(root, {
		"name": "AccessPoint",
		"position": Vector3(0.0, 0.0, -12.0),
		"groups": [ACCESS_POINT_GROUP],
	})

	var label := Label3D.new()
	label.name = "Label"
	label.text = String(definition["label"])
	label.font_size = 32
	label.outline_size = 10
	label.modulate = definition["colour"]
	label.outline_modulate = Color(0.03, 0.02, 0.01, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)
	label.position = Vector3(0.0, 7.0, 0.0)

	_reown(root, root)
	# Set after ownership: the encounter scripts reach their markers through
	# %UniqueName, which only resolves once the node has an owner to register in.
	for node in unique_names:
		node.unique_name_in_owner = true

	var scene := PackedScene.new()
	if scene.pack(root) != OK:
		push_error("Could not pack %s" % definition["root"])
		root.free()
		return false
	var output_path: String = OUTPUT_DIRECTORY + String(definition["file"])
	var error := ResourceSaver.save(scene, output_path)
	root.free()
	if error != OK:
		push_error("Could not save %s: %d" % [output_path, error])
		return false
	print("BUILT: %s" % output_path)
	return true


func _add_encounter(root: Node3D, definition: Dictionary) -> void:
	var encounter := Area3D.new()
	encounter.name = String(definition["encounter"])
	encounter.add_to_group(StringName(definition["encounter_group"]), true)
	encounter.collision_layer = 0
	encounter.collision_mask = PLAYER_MASK
	encounter.monitorable = false
	encounter.set_script(load(String(definition["script"])))
	root.add_child(encounter)
	encounter.position = TRIGGER_CENTRE
	for property: StringName in definition["exports"]:
		encounter.set(property, load(String(definition["exports"][property])))
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = TRIGGER_SIZE
	collision.shape = box
	encounter.add_child(collision)


func _add_marker(parent: Node3D, definition: Dictionary) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = String(definition["name"])
	for group_value in definition.get("groups", []):
		marker.add_to_group(StringName(group_value), true)
	parent.add_child(marker)
	marker.position = definition["position"]
	return marker


func _reown(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner_node
		_reown(child, owner_node)
