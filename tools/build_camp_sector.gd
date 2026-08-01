extends SceneTree

## Rebuilds scenes/world/camp_sector.tscn: the camp, packaged as one scene that
## can be dropped anywhere in the world instead of being loose nodes in the
## arena. Everything it uses already existed — the camp was removed from the
## arena during the map rebuild, not deleted.
##
## Run:  <godot> --headless --path . --script res://tools/build_camp_sector.gd

const OUTPUT_PATH := "res://scenes/world/camp_sector.tscn"
const CAMP_VISUALS := preload("res://scenes/world/camp_visuals.tscn")
const CAMP_CORE := preload("res://scenes/world/camp_core.tscn")
const DEFENSE_TOWER := preload("res://scenes/world/defense_tower_site.tscn")
const BUILD_GRID_SCRIPT := preload("res://scripts/systems/build_grid.gd")
const ARENA_NAVIGATION_SCRIPT := preload("res://scripts/systems/arena_navigation.gd")

## Towers sit outside and to one side of each secondary gate: they protect the
## approaches without becoming a new wall across the player's route.
const DEFENSE_TOWERS: Array[Dictionary] = [
	{"name": "DefenseTowerNorth", "offset": Vector3(-8.2, 0.0, -25.5), "rotation": 0.0},
	{"name": "DefenseTowerWest", "offset": Vector3(-25.5, 0.0, 8.2), "rotation": PI * 0.5},
	{"name": "DefenseTowerEast", "offset": Vector3(25.5, 0.0, -8.2), "rotation": -PI * 0.5},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var camp := Node3D.new()
	camp.name = "CampSector"

	var visuals := CAMP_VISUALS.instantiate() as Node3D
	visuals.name = "CampVisuals"
	camp.add_child(visuals)

	var core := CAMP_CORE.instantiate() as Node3D
	core.name = "CampCore"
	camp.add_child(core)

	var towers := Node3D.new()
	towers.name = "DefenseTowers"
	camp.add_child(towers)
	for entry in DEFENSE_TOWERS:
		var site := DEFENSE_TOWER.instantiate() as Node3D
		site.name = String(entry["name"])
		towers.add_child(site)
		site.position = entry["offset"]
		site.rotation.y = float(entry["rotation"])

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
	spawn.position = Vector3(0.0, 1.0, 8.0)

	# The camp lives in a streamed sector outside the arena's original navmesh.
	# A local region makes enemies respect the perimeter, facilities and anything
	# placed later on the free-construction grid.
	var navigation := NavigationRegion3D.new()
	navigation.name = "CampNavigation"
	navigation.set_script(ARENA_NAVIGATION_SCRIPT)
	navigation.set(&"navigation_half_extent", 32.0)
	navigation.add_to_group(&"arena_navigation", true)
	camp.add_child(navigation)

	_reown(camp, camp)
	var scene := PackedScene.new()
	if scene.pack(camp) != OK:
		push_error("Could not pack the camp")
		camp.free()
		quit(1)
		return
	var error := ResourceSaver.save(scene, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save the camp: %d" % error)
		camp.free()
		quit(1)
		return
	camp.free()
	print("BUILT: %s (fortified visuals, local navigation, %d defense towers)" % [
		OUTPUT_PATH, DEFENSE_TOWERS.size()
	])
	quit(0)


func _reown(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner_node
		_reown(child, owner_node)
