extends SceneTree

## Starts a hand-placed layout for one sector.
##
## Run:  <godot> --headless --path . --script res://tools/new_sector_data.gd -- <x> <y>
##
## Writes res://data/sectors/sector_<x>_<y>.tres with a workable starting layout,
## then open it in the inspector and drag the numbers around. Positions are in
## metres from the sector centre. Emptying a list puts that kind of content back
## on the generator's random scattering, so a sector can be taken over one piece
## at a time.
##
## Refuses to overwrite: a layout somebody spent an evening on is not something
## a mistyped sector number should be able to erase.

const OUTPUT_DIRECTORY := "res://data/sectors/"
const SECTOR_DATA_SCRIPT := "res://scripts/data/sector_data.gd"
## A starting point, not a design: spawns out at the edges where the horde comes
## from, loot in off the corners.
const TEMPLATE_SPAWNS: Array[Vector2] = [
	Vector2(-22.0, -22.0), Vector2(22.0, -22.0), Vector2(0.0, 24.0),
]
const TEMPLATE_CACHES: Array[Vector2] = [
	Vector2(-14.0, 10.0), Vector2(14.0, -10.0),
]
const TEMPLATE_AMMUNITION: Array[Vector2] = [Vector2(10.0, 14.0)]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		push_error("Usage: --script res://tools/new_sector_data.gd -- <x> <y>")
		quit(1)
		return
	var coords := Vector2i(int(arguments[0]), int(arguments[1]))
	var output_path := "%ssector_%d_%d.tres" % [
		OUTPUT_DIRECTORY, coords.x, coords.y
	]
	if ResourceLoader.exists(output_path):
		push_error("%s already exists; edit it instead." % output_path)
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	) != OK and not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	):
		push_error("Could not create %s" % OUTPUT_DIRECTORY)
		quit(1)
		return

	var script: GDScript = load(SECTOR_DATA_SCRIPT)
	if script == null:
		push_error("Could not load %s" % SECTOR_DATA_SCRIPT)
		quit(1)
		return
	var data: Resource = script.new()
	data.set(&"enemy_spawns", TEMPLATE_SPAWNS.duplicate())
	data.set(&"scrap_caches", TEMPLATE_CACHES.duplicate())
	data.set(&"ammunition_boxes", TEMPLATE_AMMUNITION.duplicate())
	# Left empty on purpose: an authored crate always appears, and every sector
	# holding a weapon would undo the one-in-three that makes finding one matter.
	data.set(&"weapon_crates", [] as Array[Vector2])

	var error := ResourceSaver.save(data, output_path)
	if error != OK:
		push_error("Could not save %s: %d" % [output_path, error])
		quit(1)
		return
	print("WROTE: %s  (sector centre is at %s m)" % [
		output_path, Vector2(coords) * 64.0
	])
	print("WROTE: %d spawns, %d caches, %d ammunition, 0 weapon crates" % [
		TEMPLATE_SPAWNS.size(), TEMPLATE_CACHES.size(), TEMPLATE_AMMUNITION.size()
	])
	quit(0)
