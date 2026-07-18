extends Node

signal wave_started(wave_number: int)
signal enemy_count_changed(remaining_enemies: int)
signal wave_completed(wave_number: int)
signal intermission_started(next_wave: int, duration: float)
signal preparation_time_changed(seconds_remaining: int)
signal enemy_defeated(xp_reward: int)
signal all_waves_completed
signal cycle_completed(cycle_number: int)

@export var normal_zombie_scene: PackedScene
@export var runner_zombie_scene: PackedScene
@export var waves: Array[WaveData] = []
@export_range(0.0, 5.0, 0.05) var spawn_interval: float = 0.2
@export_range(0.0, 120.0, 0.5) var initial_preparation_delay: float = 30.0
@export_range(0.0, 120.0, 0.5) var inter_wave_delay: float = 45.0
@export_range(0, 50, 1) var normal_zombies_per_cycle: int = 2

@onready var enemy_spawns: Node3D = %EnemySpawns
@onready var enemies: Node3D = %Enemies

var current_wave: int = 0
var alive_enemy_count: int = 0
var _is_spawning: bool = false
var _is_transitioning: bool = false
var _is_preparing: bool = false


func _ready() -> void:
	call_deferred("_start_initial_preparation")


func is_preparation_active() -> bool:
	return _is_preparing


func spawn_exploration_enemies(
	enemy_scene: PackedScene, spawn_points: Array[Marker3D]
) -> Array[Node3D]:
	var spawned_enemies: Array[Node3D] = []
	if not _is_preparing:
		return spawned_enemies
	if enemy_scene == null or spawn_points.is_empty():
		push_error("Exploration encounters require an enemy scene and spawn points.")
		return spawned_enemies

	for spawn_point in spawn_points:
		if spawn_point == null:
			push_error("Exploration encounter spawn points must be Marker3D nodes.")
			continue
		var enemy := enemy_scene.instantiate() as Node3D
		if enemy == null:
			push_error("Exploration encounter scenes must use Node3D roots.")
			continue
		if not enemy.has_signal(&"died"):
			push_error("Exploration enemies must expose a died signal.")
			enemy.queue_free()
			continue
		enemies.add_child(enemy)
		enemy.global_position = spawn_point.global_position
		enemy.connect(&"died", _on_exploration_enemy_died)
		spawned_enemies.append(enemy)
	return spawned_enemies


func _start_initial_preparation() -> void:
	await _run_preparation(1, initial_preparation_delay)
	_start_next_wave()


func _start_next_wave() -> void:
	if waves.is_empty():
		push_error("WaveManager requires at least one WaveData resource.")
		return

	var wave_index := current_wave % waves.size()
	var completed_cycles := current_wave / waves.size()
	var wave_data := waves[wave_index]
	if wave_data == null:
		push_error("WaveManager received an empty WaveData entry.")
		return
	var enemy_scenes := _build_enemy_scene_list(wave_data, completed_cycles)
	if enemy_scenes.is_empty():
		push_error("WaveManager waves must contain at least one enemy.")
		return

	var spawn_points := enemy_spawns.get_children()
	if spawn_points.is_empty():
		push_error("WaveManager requires at least one enemy spawn point.")
		return

	current_wave += 1
	alive_enemy_count = enemy_scenes.size()
	_is_spawning = true
	_is_transitioning = false
	wave_started.emit(current_wave)
	enemy_count_changed.emit(alive_enemy_count)

	for enemy_index in range(enemy_scenes.size()):
		var spawn_point := spawn_points[enemy_index % spawn_points.size()] as Marker3D
		if spawn_point == null:
			push_error("WaveManager enemy spawn children must be Marker3D nodes.")
			_register_failed_spawn()
			continue
		if not _spawn_enemy(enemy_scenes[enemy_index], spawn_point):
			_register_failed_spawn()
		if spawn_interval > 0.0 and enemy_index < enemy_scenes.size() - 1:
			await get_tree().create_timer(spawn_interval, false).timeout

	_is_spawning = false
	if alive_enemy_count == 0:
		_complete_current_wave()


func _build_enemy_scene_list(
	wave_data: WaveData, completed_cycles: int
) -> Array[PackedScene]:
	var enemy_scenes: Array[PackedScene] = []
	if normal_zombie_scene == null or runner_zombie_scene == null:
		push_error("WaveManager requires Normal Zombie and Runner scenes.")
		return enemy_scenes
	var normal_zombie_count := (
		wave_data.normal_zombie_count
		+ completed_cycles * normal_zombies_per_cycle
	)
	for _enemy_index in range(normal_zombie_count):
		enemy_scenes.append(normal_zombie_scene)
	for _enemy_index in range(wave_data.runner_zombie_count):
		enemy_scenes.append(runner_zombie_scene)
	return enemy_scenes


func _spawn_enemy(enemy_scene: PackedScene, spawn_point: Marker3D) -> bool:
	var enemy := enemy_scene.instantiate() as Node3D
	if enemy == null:
		push_error("WaveManager enemy scenes must have a Node3D root.")
		return false
	if not enemy.has_signal(&"died"):
		push_error("WaveManager enemies must expose a died signal.")
		enemy.queue_free()
		return false

	enemies.add_child(enemy)
	enemy.global_position = spawn_point.global_position
	enemy.connect(&"died", _on_enemy_died)
	return true


func _register_failed_spawn() -> void:
	alive_enemy_count = maxi(alive_enemy_count - 1, 0)
	enemy_count_changed.emit(alive_enemy_count)


func _on_enemy_died(enemy: Node) -> void:
	var xp_reward := int(enemy.get("xp_reward")) if enemy != null else 0
	enemy_defeated.emit(maxi(xp_reward, 0))
	alive_enemy_count = maxi(alive_enemy_count - 1, 0)
	enemy_count_changed.emit(alive_enemy_count)
	if alive_enemy_count == 0 and not _is_spawning:
		_complete_current_wave()


func _on_exploration_enemy_died(enemy: Node) -> void:
	var xp_reward := int(enemy.get("xp_reward")) if enemy != null else 0
	enemy_defeated.emit(maxi(xp_reward, 0))


func _complete_current_wave() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	wave_completed.emit(current_wave)
	if current_wave % waves.size() == 0:
		cycle_completed.emit(current_wave / waves.size())

	await _run_preparation(current_wave + 1, inter_wave_delay)
	_start_next_wave()


func _run_preparation(next_wave: int, duration: float) -> void:
	_is_preparing = true
	intermission_started.emit(next_wave, duration)
	var remaining_time := duration
	while remaining_time > 0.0:
		preparation_time_changed.emit(ceili(remaining_time))
		var wait_duration := minf(remaining_time, 1.0)
		await get_tree().create_timer(wait_duration, false).timeout
		remaining_time -= wait_duration
	preparation_time_changed.emit(0)
	_is_preparing = false
