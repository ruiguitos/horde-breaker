extends SceneTree

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const EXPECTED_FACILITIES: Array[String] = [
	"Storage",
	"Workshop",
	"Armory",
	"Medbay",
]
const EXPECTED_GATES: Array[String] = [
	"GateNorth",
	"GateSouth",
	"GateWest",
	"GateEast",
]
const GATE_CENTERS: Array[Vector3] = [
	Vector3(0.0, 0.0, -22.0),
	Vector3(0.0, 0.0, 22.0),
	Vector3(-22.0, 0.0, 0.0),
	Vector3(22.0, 0.0, 0.0),
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if change_scene_to_file(ARENA_SCENE) != OK:
		_check("arena scene loads", false)
		_report()
		return
	await scene_changed
	for _frame in 60:
		await process_frame

	var camp := current_scene.get_node_or_null("CampSector") as Node3D
	_check("camp sector is integrated in the arena", camp != null)
	if camp == null:
		_report()
		return
	var visuals := camp.get_node_or_null("CampVisuals") as Node3D
	_check("fortified visual shell exists", visuals != null)
	if visuals == null:
		_report()
		return

	for facility_name in EXPECTED_FACILITIES:
		_check(
			"%s facility exists" % facility_name,
			visuals.get_node_or_null("Facilities/%s" % facility_name) != null
		)
	for gate_name in EXPECTED_GATES:
		_check(
			"%s exists" % gate_name,
			visuals.get_node_or_null(
				"FortifiedPerimeter/%s" % gate_name
			) != null
		)
	_check(
		"decorative graybox watchtowers were removed",
		visuals.get_node_or_null(
			"FortifiedPerimeter/WatchTowerSouthWest"
		) == null
		and visuals.get_node_or_null(
			"FortifiedPerimeter/WatchTowerNorthEast"
		) == null
	)

	var visual_blockers := 0
	for blocker in get_nodes_in_group(&"navigation_blocker"):
		if visuals.is_ancestor_of(blocker):
			visual_blockers += 1
	_check(
		"visual obstacles participate in navigation (%d)" % visual_blockers,
		visual_blockers >= 25
	)

	_test_upgrade_stations(camp)
	_test_defense_towers(camp)
	_test_navigation(camp)
	_report()


func _test_upgrade_stations(camp: Node3D) -> void:
	var core := camp.get_node_or_null("CampCore")
	var station_count := 0
	for child in core.get_children():
		if child.name.begins_with("UpgradeStation_"):
			station_count += 1
			var station := child as Node3D
			_check(
				"%s is placed at the workshop" % child.name,
				station.position.x >= 1.7
				and station.position.x <= 12.7
				and station.position.z <= -15.2
			)
	_check("exactly three upgrade stations spawn", station_count == 3)
	_check(
		"legacy duplicate station container is absent",
		camp.get_node_or_null("UpgradeStations") == null
	)


func _test_defense_towers(camp: Node3D) -> void:
	var towers := camp.get_node("DefenseTowers")
	_check("three secondary gates have tower sites", towers.get_child_count() == 3)
	var north := towers.get_node("DefenseTowerNorth") as Node3D
	var west := towers.get_node("DefenseTowerWest") as Node3D
	var east := towers.get_node("DefenseTowerEast") as Node3D
	_check("north tower is outside and beside its gate", north.position.is_equal_approx(Vector3(-8.2, 0.0, -25.5)))
	_check("west tower is outside and beside its gate", west.position.is_equal_approx(Vector3(-25.5, 0.0, 8.2)))
	_check("east tower is outside and beside its gate", east.position.is_equal_approx(Vector3(25.5, 0.0, -8.2)))
	_check("tower sites expose the defense tower group", towers.get_child(0).is_in_group(&"defense_tower"))
	_check("legacy interior fortifications are absent", camp.get_node_or_null("Fortifications") == null)


func _test_navigation(camp: Node3D) -> void:
	var navigation := camp.get_node_or_null("CampNavigation") as NavigationRegion3D
	_check("camp has a local navigation region", navigation != null)
	if navigation == null or navigation.navigation_mesh == null:
		_check("camp navigation mesh was built", false)
		return
	var navigation_mesh := navigation.navigation_mesh
	_check(
		"camp navigation mesh has walkable cells",
		navigation_mesh.get_polygon_count() > 0
	)
	for index in GATE_CENTERS.size():
		_check(
			"%s remains open in navigation" % EXPECTED_GATES[index],
			_has_polygon_near(navigation_mesh, GATE_CENTERS[index], 0.8)
		)
	# The same row as the south gate must be blocked where the wall exists.
	_check(
		"perimeter wall is excluded from navigation",
		not _has_polygon_near(navigation_mesh, Vector3(12.0, 0.0, 22.0), 0.8)
	)


func _has_polygon_near(
	navigation_mesh: NavigationMesh, target: Vector3, maximum_distance: float
) -> bool:
	var vertices := navigation_mesh.vertices
	for polygon_index in navigation_mesh.get_polygon_count():
		var polygon := navigation_mesh.get_polygon(polygon_index)
		var center := Vector3.ZERO
		for vertex_index in polygon:
			center += vertices[vertex_index]
		center /= polygon.size()
		if Vector2(center.x, center.z).distance_to(Vector2(target.x, target.z)) <= maximum_distance:
			return true
	return false


func _report() -> void:
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
