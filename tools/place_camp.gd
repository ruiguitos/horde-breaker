extends SceneTree

## Puts the camp into the arena and rewires everything that points at it.
##
## Run:  <godot> --headless --path . --script res://tools/place_camp.gd
##
## The camp's position is a single constant here and in world_streamer.gd
## (CAMP_COORDS). Moving the camp is changing those two and re-running this plus
## paint_world.gd — the painter leaves the camp's sector unbuilt.

const ARENA_PATH := "res://scenes/world/test_arena.tscn"
const CAMP_SCENE := preload("res://scenes/world/camp_sector.tscn")
const SECTOR_SIZE := 64.0

## Which sector holds the camp, in streamer coordinates. Must match
## world_streamer.CAMP_COORDS and paint_world.CENTRE.
##
## Off-centre on purpose. Dead centre makes every run the same shape — out and
## back along a radius, with no side of the map more dangerous or more
## rewarding than any other. Sitting in a quadrant gives the world a long side
## and a short side, so how deep to push becomes a decision.
const CAMP_COORDS := Vector2i(-1, -1)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var arena := (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	if arena == null:
		push_error("Could not instantiate the arena")
		quit(1)
		return

	var camp_position := Vector3(
		float(CAMP_COORDS.x) * SECTOR_SIZE, 0.0, float(CAMP_COORDS.y) * SECTOR_SIZE
	)

	var existing := arena.get_node_or_null("CampSector")
	if existing != null:
		arena.remove_child(existing)
		existing.queue_free()
	var camp := CAMP_SCENE.instantiate() as Node3D
	camp.name = "CampSector"
	arena.add_child(camp)
	camp.position = camp_position

	# The player starts at the camp, not at the old world origin.
	var spawn := arena.get_node_or_null("PlayerSpawn") as Marker3D
	if spawn != null:
		spawn.position = camp_position + Vector3(0.0, 1.0, 6.0)

	# CampBuilder was left pointing at nodes that no longer existed when the camp
	# was removed; repoint it at the ones inside the camp scene.
	var builder := arena.get_node_or_null("Gameplay/CampBuilder")
	if builder == null:
		builder = Node.new()
		builder.name = "CampBuilder"
		builder.set_script(load("res://scripts/systems/camp_builder.gd"))
		arena.get_node("Gameplay").add_child(builder)
	builder.set(&"build_grid_path", NodePath("../../CampSector/CampConstruction/BuildGrid"))
	builder.set(&"ghost_container_path", NodePath("../../CampSector/CampConstruction/GhostContainer"))
	builder.set(&"built_container_path", NodePath("../../CampSector/CampConstruction/BuiltStructures"))
	# The build catalog UI and its CanvasLayer both went with the camp.
	var layer := arena.get_node_or_null("BuildCatalogLayer")
	if layer == null:
		var canvas := CanvasLayer.new()
		canvas.name = "BuildCatalogLayer"
		arena.add_child(canvas)
		layer = canvas
	if layer != null:
		var catalog := layer.get_node_or_null("BuildCatalog")
		if catalog == null:
			catalog = (load("res://scenes/ui/build_catalog.tscn") as PackedScene).instantiate()
			catalog.name = "BuildCatalog"
			layer.add_child(catalog)
		builder.set(&"build_catalog_path", NodePath("../../BuildCatalogLayer/BuildCatalog"))

	_reown(arena, arena)
	var scene := PackedScene.new()
	if scene.pack(arena) != OK or ResourceSaver.save(scene, ARENA_PATH) != OK:
		push_error("Could not save the arena")
		quit(1)
		return
	print("PLACED: camp at sector %s -> %s" % [CAMP_COORDS, camp_position])
	print("PLACED: player spawn at %s" % spawn.position if spawn != null else "no spawn")
	quit(0)


func _reown(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner_node
		_reown(child, owner_node)
