extends SceneTree

## Exports the archipelago height field as reference data for the Unity port.
##
## The terrain is not sculpted — it comes out of `height_at()`. That makes it the
## one part of the world that can cross to another engine unchanged, but only if
## the port is provably the same function. This writes a grid plus the points
## that actually matter (island centres, route endpoints, the lagoon, the
## crater), and the C# side asserts against it.
##
## Run:
##   <godot> --headless --path . --script res://tools/export_archipelago_height_reference.gd [output.csv]

const DESIGN := preload("res://scripts/systems/destiny_archipelago_design.gd")
const DEFAULT_OUTPUT := "res://data/destiny_archipelago/height_reference.csv"
## Step over the 512 m terrain. 16 m gives 33x33 samples: enough to catch a
## wrong weight function anywhere, small enough to read.
const GRID_STEP := 16.0

## Points where being wrong would be invisible in a grid but fatal in play.
const NAMED_POINTS: Array[Dictionary] = [
	{"name": "dawn_center", "x": 120.0, "z": 390.0},
	{"name": "dawn_player_start", "x": 120.0, "z": 405.0},
	{"name": "dawn_lagoon", "x": 88.0, "z": 404.0},
	{"name": "dawn_north_spit", "x": 120.0, "z": 348.0},
	{"name": "forest_center", "x": 120.0, "z": 135.0},
	{"name": "forest_west_pool", "x": 98.0, "z": 128.0},
	{"name": "forest_east_pool", "x": 137.0, "z": 153.0},
	{"name": "cliffs_center", "x": 385.0, "z": 390.0},
	{"name": "cliffs_ridge", "x": 408.0, "z": 378.0},
	{"name": "cliffs_cave_headland", "x": 344.0, "z": 390.0},
	{"name": "volcano_center", "x": 385.0, "z": 130.0},
	{"name": "volcano_crater_rim", "x": 385.0, "z": 155.0},
	{"name": "reef_south", "x": 120.0, "z": 210.0},
	{"name": "reef_middle", "x": 120.0, "z": 265.0},
	{"name": "reef_north", "x": 120.0, "z": 320.0},
	{"name": "cave_entry", "x": 176.0, "z": 390.0},
	{"name": "cave_exit", "x": 329.0, "z": 390.0},
	{"name": "bridge_start", "x": 190.0, "z": 135.0},
	{"name": "bridge_end", "x": 310.0, "z": 135.0},
	{"name": "ruins_start", "x": 385.0, "z": 315.0},
	{"name": "ruins_end", "x": 385.0, "z": 200.0},
	{"name": "open_sea", "x": 256.0, "z": 256.0},
	{"name": "corner_origin", "x": 0.0, "z": 0.0},
	{"name": "corner_far", "x": 512.0, "z": 512.0},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output_path := DEFAULT_OUTPUT
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		output_path = arguments[0]

	var lines := PackedStringArray()
	lines.append("name,x,z,height")
	for entry in NAMED_POINTS:
		lines.append(_sample_line(String(entry["name"]), entry["x"], entry["z"]))

	var steps := int(DESIGN.TERRAIN_SIZE / GRID_STEP)
	for grid_z in steps + 1:
		for grid_x in steps + 1:
			var x := float(grid_x) * GRID_STEP
			var z := float(grid_z) * GRID_STEP
			lines.append(_sample_line("grid", x, z))

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s: %s" % [output_path, FileAccess.get_open_error()])
		quit(1)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("Wrote %d samples to %s" % [lines.size() - 1, output_path])
	quit()


func _sample_line(sample_name: String, x: float, z: float) -> String:
	# Six decimals is far below anything the terrain cares about and keeps the
	# file diffable.
	return "%s,%.4f,%.4f,%.6f" % [sample_name, x, z, DESIGN.height_at(x, z)]
