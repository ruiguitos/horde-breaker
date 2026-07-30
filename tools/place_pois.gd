extends SceneTree

## Puts the point-of-interest encounters into the arena, one per painted
## compound.
##
## Run:  <godot> --headless --path . --script res://tools/place_pois.gd
##       (after tools/paint_world.gd and tools/build_poi_scenes.gd)
##
## The compounds themselves are painted into the GridMap layers, so all that
## goes into the scene tree is the trigger, its markers and the reward cache.
## Which sectors hold a POI, and where the yard sits inside them, are read from
## paint_world.gd rather than repeated here: a POI whose trigger and buildings
## disagree is a trigger inside a wall.

const ARENA_PATH := "res://scenes/world/test_arena.tscn"
const PAINTER_PATH := "res://tools/paint_world.gd"
const CONTAINER_NAME := "PointsOfInterest"
const SECTOR_SIZE := 64.0
const SCENE_BY_KIND := {
	"warehouse": "res://scenes/world/poi_warehouse.tscn",
	"military_outpost": "res://scenes/world/poi_military_outpost.tscn",
	"fuel_station": "res://scenes/world/poi_fuel_station.tscn",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var arena := (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	if arena == null:
		push_error("Could not instantiate the arena")
		quit(1)
		return
	var painter: GDScript = load(PAINTER_PATH)
	if painter == null:
		push_error("Could not load the world painter")
		arena.free()
		quit(1)
		return
	var points: Array = painter.get(&"POINTS_OF_INTEREST")
	var yard_offset: Vector2 = painter.get(&"POI_YARD_OFFSET")

	# Rebuilt from scratch every run, so moving a POI in paint_world.gd never
	# leaves an orphan trigger behind in an empty field.
	var existing := arena.get_node_or_null(CONTAINER_NAME)
	if existing != null:
		arena.remove_child(existing)
		existing.queue_free()
	var container := Node3D.new()
	container.name = CONTAINER_NAME
	arena.add_child(container)

	var placed := 0
	for entry_value in points:
		var entry: Dictionary = entry_value
		var kind := String(entry["kind"])
		if not SCENE_BY_KIND.has(kind):
			push_error("No scene for POI kind '%s'" % kind)
			continue
		var poi_scene: PackedScene = load(String(SCENE_BY_KIND[kind]))
		if poi_scene == null:
			push_error("Could not load the scene for '%s'" % kind)
			continue
		var coords: Vector2i = entry["coords"]
		var poi := poi_scene.instantiate() as Node3D
		poi.name = ("%s_%d_%d" % [kind, coords.x, coords.y]).validate_node_name()
		container.add_child(poi)
		poi.position = Vector3(
			float(coords.x) * SECTOR_SIZE + yard_offset.x,
			0.0,
			float(coords.y) * SECTOR_SIZE + yard_offset.y
		)
		placed += 1
		print("PLACED: %s at sector %s -> %s" % [kind, coords, poi.position])

	_reown(arena, arena)
	var scene := PackedScene.new()
	if scene.pack(arena) != OK or ResourceSaver.save(scene, ARENA_PATH) != OK:
		push_error("Could not save the arena")
		arena.free()
		quit(1)
		return
	print("PLACED: %d points of interest" % placed)
	arena.free()
	quit(0)


func _reown(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner_node
		_reown(child, owner_node)
