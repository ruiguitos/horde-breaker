@tool
extends EditorScript

## Runs the Phase 1/2 checks from docs/CITY_REBUILD_PLAN.md (boundary
## continuity across all 24 internal edges, determinism under repeated
## builds, and graph validation) for several fixed seeds, without entering
## Play mode. Run from the Script panel via File > Run. Recommended before
## moving on to Phase 3.

const TEST_SEEDS: Array[int] = [0, 1, 12345, 987654321, -1]


func _run() -> void:
	var total_errors := 0
	for seed_value in TEST_SEEDS:
		var boundary_errors := CityLayoutGenerator.verify_boundary_continuity(
			seed_value,
			WorldStreamer.GRID_MIN,
			WorldStreamer.GRID_MAX,
			WorldStreamer.SECTOR_SIZE
		)
		var determinism_errors := CityLayoutGenerator.verify_determinism(
			seed_value,
			WorldStreamer.GRID_MIN,
			WorldStreamer.GRID_MAX,
			WorldStreamer.SECTOR_SIZE
		)
		var graph := CityLayoutGenerator.build_debug_graph(
			seed_value,
			WorldStreamer.GRID_MIN,
			WorldStreamer.GRID_MAX,
			WorldStreamer.SECTOR_SIZE
		)
		var graph_errors := graph.validate()
		var seed_error_count := (
			boundary_errors.size() + determinism_errors.size() + graph_errors.size()
		)
		total_errors += seed_error_count
		print(
			"CityGraph seed %d: %d nodes, %d edges, %d error(s)."
			% [seed_value, graph.nodes.size(), graph.edges.size(), seed_error_count]
		)
		for error in boundary_errors:
			print("  [boundary] %s" % error)
		for error in determinism_errors:
			print("  [determinism] %s" % error)
		for error in graph_errors:
			print("  [graph] %s" % error)
	if total_errors == 0:
		print("CityGraph: all %d seeds passed with zero errors." % TEST_SEEDS.size())
	else:
		print(
			"CityGraph: %d total error(s) across %d seeds."
			% [total_errors, TEST_SEEDS.size()]
		)
