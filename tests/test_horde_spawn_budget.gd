extends SceneTree

const WAVE_MANAGER_PATH := "res://scripts/systems/wave_manager.gd"
const ZOMBIE_SCENE := "res://scenes/enemies/normal_zombie.tscn"
const RUNNER_SCENE := "res://scenes/enemies/runner_zombie.tscn"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	var director := _build_director(world)
	await process_frame
	director.set_physics_process(false)
	director.set(&"current_wave", 10)

	# A high threat level may request a large batch, but only a short queue is
	# reserved. Nothing is instantiated by this call.
	director.call(&"_spawn_travel_batch")
	var queue: Array = director.get(&"_spawn_queue")
	_check("queue: capped at 12 reservations", queue.size() == 12)
	_check(
		"queue: reservations consume available capacity",
		int(director.call(&"get_available_spawn_slots")) == 78
	)
	queue.clear()

	# Exploration enemies share the same global budget with the travelling horde.
	director.set(&"max_simultaneous_enemies", 6)
	var enemies := director.get_node("Enemies") as Node3D
	var zombie_scene := load(ZOMBIE_SCENE) as PackedScene
	for index in 4:
		var guard := zombie_scene.instantiate() as Node3D
		enemies.add_child(guard)
		guard.set_physics_process(false)
		guard.global_position = Vector3(float(index), 0.0, 4.0)
	_check(
		"global: four encounter enemies leave two slots",
		int(director.call(&"get_available_spawn_slots")) == 2
	)

	director.call(&"_spawn_travel_batch")
	queue = director.get(&"_spawn_queue")
	_check("global: horde reserves only the remaining two slots", queue.size() == 2)
	director.call(&"_drain_spawn_queue")
	await process_frame
	_check(
		"frame: no more than two enemies are instantiated",
		int(director.call(&"get_living_enemy_count")) == 6
	)
	_check(
		"global: the simultaneous cap is never exceeded",
		int(director.call(&"get_available_spawn_slots")) == 0
	)

	var encounter_points: Array[Marker3D] = []
	for index in 3:
		var point := Marker3D.new()
		world.add_child(point)
		point.global_position = Vector3(10.0 + float(index), 0.0, 10.0)
		encounter_points.append(point)
	var spawned: Array = director.call(
		&"spawn_exploration_enemies", zombie_scene, encounter_points
	)
	_check("encounter: a full budget rejects extra enemies", spawned.is_empty())

	world.queue_free()
	await process_frame
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _build_director(world: Node3D) -> Node:
	var director := Node.new()
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	director.add_child(spawns)
	spawns.owner = director
	spawns.unique_name_in_owner = true
	var marker := Marker3D.new()
	spawns.add_child(marker)
	marker.position = Vector3(20.0, 0.0, 0.0)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	director.add_child(enemies)
	enemies.owner = director
	enemies.unique_name_in_owner = true
	director.set_script(load(WAVE_MANAGER_PATH))
	director.set(&"normal_zombie_scene", load(ZOMBIE_SCENE))
	director.set(&"runner_zombie_scene", load(RUNNER_SCENE))
	world.add_child(director)
	director.set_physics_process(false)
	return director


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
