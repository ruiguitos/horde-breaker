extends Node3D

## Phase 1/2 of docs/CITY_REBUILD_PLAN.md: builds the debug graph across the
## whole sector grid, runs the boundary-continuity check, and shows a
## coloured line/marker visual so continuity can be verified in the editor
## before any real road geometry replaces the current road quadrants.
## Purely additive — does not touch SectorGenerator or the loaded sectors.

@export var enabled: bool = true

var _visual: MeshInstance3D


func _ready() -> void:
	visible = enabled
	if enabled:
		call_deferred(&"_build")


func _build() -> void:
	var run_seed := SaveManager.ensure_world_seed()
	var graph := CityLayoutGenerator.build_debug_graph(
		run_seed,
		WorldStreamer.GRID_MIN,
		WorldStreamer.GRID_MAX,
		WorldStreamer.SECTOR_SIZE
	)
	var errors := graph.validate()
	errors.append_array(
		CityLayoutGenerator.verify_boundary_continuity(
			run_seed,
			WorldStreamer.GRID_MIN,
			WorldStreamer.GRID_MAX,
			WorldStreamer.SECTOR_SIZE
		)
	)
	for error in errors:
		push_warning("CityGraph: %s" % error)
	if _visual != null:
		_visual.queue_free()
	_visual = CityLayoutGenerator.build_debug_visual(graph)
	add_child(_visual)
