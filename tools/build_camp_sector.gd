extends SceneTree

## Rebuilds scenes/world/camp_sector.tscn: the camp, packaged as one scene that
## can be dropped anywhere in the world instead of being loose nodes in the
## arena. Everything it uses already existed — the camp was removed from the
## arena during the map rebuild, not deleted.
##
## Run:  <godot> --headless --path . --script res://tools/build_camp_sector.gd

const OUTPUT_PATH := "res://scenes/world/camp_sector.tscn"
const CAMP_CORE := preload("res://scenes/world/camp_core.tscn")
const UPGRADE_STATION := preload("res://scenes/world/camp_upgrade_station.tscn")
const FORTIFICATION := preload("res://scenes/world/fortification_site.tscn")
const BUILD_GRID_SCRIPT := preload("res://scripts/systems/build_grid.gd")

## Laid out around the core at the origin, so the whole camp can be positioned
## by moving one node.
const UPGRADES: Array[Dictionary] = [
	{"id": &"resupply_rate", "name": "ResupplyRate", "offset": Vector3(-6.0, 0.0, -4.0)},
	{"id": &"resupply_range", "name": "ResupplyRange", "offset": Vector3(0.0, 0.0, -6.5)},
	{"id": &"scavenging", "name": "Scavenging", "offset": Vector3(6.0, 0.0, -4.0)},
]
## Three barricade points covering the approaches the player cannot watch at once.
const FORTIFICATIONS: Array[Dictionary] = [
	{"name": "FortificationNorth", "offset": Vector3(0.0, 0.0, -10.0)},
	{"name": "FortificationWest", "offset": Vector3(-9.0, 0.0, 4.0)},
	{"name": "FortificationEast", "offset": Vector3(9.0, 0.0, 4.0)},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var camp := Node3D.new()
	camp.name = "CampSector"

	var core := CAMP_CORE.instantiate() as Node3D
	core.name = "CampCore"
	camp.add_child(core)

	var stations := Node3D.new()
	stations.name = "UpgradeStations"
	camp.add_child(stations)
	for entry in UPGRADES:
		var station := UPGRADE_STATION.instantiate() as Node3D
		station.name = String(entry["name"])
		station.set(&"upgrade_id", entry["id"])
		stations.add_child(station)
		station.position = entry["offset"]

	var forts := Node3D.new()
	forts.name = "Fortifications"
	camp.add_child(forts)
	for entry in FORTIFICATIONS:
		var site := FORTIFICATION.instantiate() as Node3D
		site.name = String(entry["name"])
		forts.add_child(site)
		site.position = entry["offset"]

	# The three nodes CampBuilder expects, kept together so its NodePaths are
	# stable wherever the camp is placed.
	var construction := Node3D.new()
	construction.name = "CampConstruction"
	camp.add_child(construction)
	var grid := Node3D.new()
	grid.name = "BuildGrid"
	grid.set_script(BUILD_GRID_SCRIPT)
	construction.add_child(grid)
	var ghosts := Node3D.new()
	ghosts.name = "GhostContainer"
	construction.add_child(ghosts)
	var built := Node3D.new()
	built.name = "BuiltStructures"
	construction.add_child(built)

	# Where the player starts the run, just inside the camp.
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	camp.add_child(spawn)
	spawn.position = Vector3(0.0, 1.0, 6.0)

	_reown(camp, camp)
	var scene := PackedScene.new()
	if scene.pack(camp) != OK:
		push_error("Could not pack the camp")
		quit(1)
		return
	var error := ResourceSaver.save(scene, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save the camp: %d" % error)
		quit(1)
		return
	print("BUILT: %s (%d upgrade stations, %d fortifications)" % [
		OUTPUT_PATH, UPGRADES.size(), FORTIFICATIONS.size()
	])
	quit(0)


func _reown(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner_node
		_reown(child, owner_node)
