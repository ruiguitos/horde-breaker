extends SceneTree

const DESIGN := preload("res://scripts/systems/terrain3d_world_design.gd")
const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
const ROUTE_MAXIMUM_SLOPE := 0.45
const GENERAL_MAXIMUM_SLOPE := 1.20

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var routes := DESIGN.create_route_polylines(192)
	_check("two terrain loops and three connectors exist", routes.size() == 5)
	var route_maximum_slope := 0.0
	var submerged_route_points := 0
	for route in routes:
		for point_index in route.size():
			var point := route[point_index]
			var height := DESIGN.height_at(point.x, point.y)
			if height < DESIGN.NAVIGATION_MINIMUM_HEIGHT:
				submerged_route_points += 1
			if point_index == 0:
				continue
			var previous := route[point_index - 1]
			var distance := point.distance_to(previous)
			if distance <= 0.001:
				continue
			var previous_height := DESIGN.height_at(previous.x, previous.y)
			route_maximum_slope = maxf(
				route_maximum_slope,
				absf(height - previous_height) / distance
			)
	_check("all route samples remain on dry navigable land (%d submerged)"
		% submerged_route_points, submerged_route_points == 0)
	_check("terrain routes stay gently graded (%.3f slope)" % route_maximum_slope,
		route_maximum_slope <= ROUTE_MAXIMUM_SLOPE)

	var maximum_slope := 0.0
	var maximum_slope_position := Vector2.ZERO
	var steep_sample_count := 0
	for world_z in range(-208, 273, 4):
		for world_x in range(-208, 273, 4):
			var center := Vector2(world_x, world_z)
			if not DESIGN.is_walkable_land(center):
				continue
			var center_height := DESIGN.height_at(center.x, center.y)
			var east_height := DESIGN.height_at(center.x + 1.0, center.y)
			var south_height := DESIGN.height_at(center.x, center.y + 1.0)
			var slope := Vector2(
				east_height - center_height,
				south_height - center_height
			).length()
			if slope > maximum_slope:
				maximum_slope = slope
				maximum_slope_position = center
			if slope > GENERAL_MAXIMUM_SLOPE:
				steep_sample_count += 1
	_check("walkable terrain has no extreme sampled slopes (max %.3f at %s, %d steep)"
		% [maximum_slope, maximum_slope_position, steep_sample_count],
		steep_sample_count == 0)

	var landmarks := DESIGN.get_landmarks()
	var invalid_landmarks := 0
	for landmark in landmarks:
		var point: Vector2 = landmark["position"]
		if not DESIGN.is_walkable_land(point):
			invalid_landmarks += 1
	_check("all four terrain landmarks are on accessible land",
		landmarks.size() == 4 and invalid_landmarks == 0)
	await _test_player_route_samples(routes)
	_report()


func _test_player_route_samples(routes: Array[PackedVector2Array]) -> void:
	if change_scene_to_file(ARENA_SCENE) != OK:
		_check("arena loads for the route playtest", false)
		return
	await scene_changed
	var terrain_world := get_first_node_in_group(&"terrain3d_world") as Node3D
	var player := get_first_node_in_group(&"player") as CharacterBody3D
	_check("player and Terrain3D load for the route playtest",
		terrain_world != null and player != null)
	if terrain_world == null or player == null:
		return
	if not bool(terrain_world.get(&"is_ready")):
		await Signal(terrain_world, &"world_ready")
	var wave_manager := get_first_node_in_group(&"wave_manager")
	if wave_manager != null:
		wave_manager.set_process(false)
		wave_manager.set_physics_process(false)
	var world_streamer := get_first_node_in_group(&"world_streamer")
	if world_streamer != null:
		world_streamer.set_process(false)
	for enemy in get_nodes_in_group(&"enemy"):
		enemy.queue_free()
	var failed_landings := 0
	for route_index in 2:
		var route := routes[route_index]
		for sample_index in range(0, route.size() - 1, 32):
			var point := route[sample_index]
			var expected_height := float(terrain_world.call(
				&"get_terrain_height", Vector3(point.x, 0.0, point.y)
			))
			player.velocity = Vector3.ZERO
			player.global_position = Vector3(point.x, expected_height + 2.5, point.y)
			for _frame in 48:
				await physics_frame
			var feet_error := absf(player.global_position.y - (expected_height + 1.0))
			if not player.is_on_floor() or feet_error > 0.22:
				failed_landings += 1
				print("ROUTE LANDING: %s expected %.2f actual %.2f floor=%s error=%.2f" % [
					point, expected_height + 1.0, player.global_position.y,
					player.is_on_floor(), feet_error
				])
	_check("player lands across both terrain routes (%d failed samples)"
		% failed_landings, failed_landings == 0)


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
