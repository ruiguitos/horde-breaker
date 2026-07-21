extends Area3D

signal encounter_started(enemy_count: int)

const PLAYER_GROUP := &"player"
const WAVE_MANAGER_GROUP := &"wave_manager"
const CAMP_ECONOMY_GROUP := &"camp_economy"
const NORMAL_SPAWN_GROUP := &"military_normal_spawn"
const RUNNER_SPAWN_GROUP := &"military_runner_spawn"

@export var normal_enemy_scene: PackedScene
@export var runner_enemy_scene: PackedScene
@export var ammunition_pickup_scene: PackedScene

@onready var enemy_spawns: Node3D = %MilitaryEnemySpawns
@onready var ammunition_spawns: Node3D = %MilitaryAmmunitionSpawns

var _wave_manager: Node
var _camp_economy: Node
var _encounter_available := true
var _reset_pending := false
var _active_enemies: Array[Node3D] = []
var _ammunition_pickups: Array[Node3D] = []


func _ready() -> void:
	_wave_manager = get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	_camp_economy = get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if _wave_manager == null:
		push_error("MilitaryOutpostEncounter requires a wave_manager node.")
		return
	if not _wave_manager.has_method(&"spawn_exploration_enemies"):
		push_error("MilitaryOutpostEncounter requires exploration spawning support.")
		return
	if not _wave_manager.has_signal(&"cycle_completed"):
		push_error("MilitaryOutpostEncounter requires the cycle_completed signal.")
		return

	body_entered.connect(_on_body_entered)
	_wave_manager.connect(&"cycle_completed", _on_cycle_completed)
	_wave_manager.connect(&"intermission_started", _on_intermission_started)
	call_deferred(&"_spawn_initial_loot")


func is_encounter_available() -> bool:
	return _encounter_available


func get_active_enemy_count() -> int:
	_prune_active_enemies()
	return _active_enemies.size()


func get_active_ammunition_count() -> int:
	var active_count := 0
	for pickup in _ammunition_pickups:
		if _is_pickup_active(pickup):
			active_count += 1
	return active_count


func _on_body_entered(body: Node3D) -> void:
	_try_start_encounter(body)


func _try_start_encounter(body: Node3D) -> void:
	if (
		not _encounter_available
		or body == null
		or not body.is_in_group(PLAYER_GROUP)
		or not bool(_wave_manager.call(&"is_preparation_active"))
	):
		return

	var spawned_enemies: Array[Node3D] = []
	spawned_enemies.append_array(
		_spawn_enemy_group(normal_enemy_scene, NORMAL_SPAWN_GROUP)
	)
	spawned_enemies.append_array(
		_spawn_enemy_group(runner_enemy_scene, RUNNER_SPAWN_GROUP)
	)
	for enemy in spawned_enemies:
		_active_enemies.append(enemy)
		enemy.connect(&"died", _on_encounter_enemy_died)
	if _active_enemies.is_empty():
		return

	_encounter_available = false
	_reset_pending = false
	_request_feedback("MILITARY OUTPOST  •  %d HOSTILES" % _active_enemies.size())
	encounter_started.emit(_active_enemies.size())


func _spawn_enemy_group(
	enemy_scene: PackedScene, spawn_group: StringName
) -> Array[Node3D]:
	var spawn_points := _get_spawn_points(spawn_group)
	var spawned_enemies: Array[Node3D] = []
	if enemy_scene == null or spawn_points.is_empty():
		push_error("MilitaryOutpostEncounter requires both enemy scenes and spawns.")
		return spawned_enemies
	var spawned_value: Variant = _wave_manager.call(
		&"spawn_exploration_enemies", enemy_scene, spawn_points
	)
	if not spawned_value is Array:
		push_error("WaveManager must return the spawned exploration enemies.")
		return spawned_enemies
	for spawned_value_item: Variant in spawned_value:
		var enemy := spawned_value_item as Node3D
		if enemy != null:
			spawned_enemies.append(enemy)
	return spawned_enemies


func _on_encounter_enemy_died(enemy: Node) -> void:
	_active_enemies.erase(enemy)
	_prune_active_enemies()
	if not _active_enemies.is_empty() or not _reset_pending:
		return
	_reset_pending = false
	_encounter_available = true
	call_deferred(&"_try_start_for_overlapping_player")


func _on_cycle_completed(_cycle_number: int) -> void:
	_prune_active_enemies()
	if _active_enemies.is_empty():
		_encounter_available = true
		_reset_pending = false
	else:
		_reset_pending = true
	var replenished_pickups := _spawn_missing_ammunition()
	if replenished_pickups > 0:
		_request_feedback("OUTPOST AMMO RESTOCKED")


func _on_intermission_started(_next_wave: int, _duration: float) -> void:
	call_deferred(&"_try_start_for_overlapping_player")


func _try_start_for_overlapping_player() -> void:
	for body in get_overlapping_bodies():
		var player := body as Node3D
		if player != null and player.is_in_group(PLAYER_GROUP):
			_try_start_encounter(player)
			return


func _get_spawn_points(spawn_group: StringName = &"") -> Array[Marker3D]:
	var spawn_points: Array[Marker3D] = []
	for child in enemy_spawns.get_children():
		var spawn_point := child as Marker3D
		if spawn_point == null:
			push_error("Military encounter spawn points must be Marker3D nodes.")
			continue
		if spawn_group == &"" or spawn_point.is_in_group(spawn_group):
			spawn_points.append(spawn_point)
	return spawn_points


func _spawn_initial_loot() -> void:
	_spawn_missing_ammunition()


func _spawn_missing_ammunition() -> int:
	var spawn_points: Array[Marker3D] = []
	for child in ammunition_spawns.get_children():
		var spawn_point := child as Marker3D
		if spawn_point == null:
			push_error("Military ammunition spawns must be Marker3D nodes.")
			continue
		spawn_points.append(spawn_point)
	_ammunition_pickups.resize(spawn_points.size())

	var spawned_count := 0
	for spawn_index in range(spawn_points.size()):
		var pickup := _ammunition_pickups[spawn_index]
		if _is_pickup_active(pickup):
			continue
		pickup = _spawn_ammunition(spawn_points[spawn_index], spawn_index)
		_ammunition_pickups[spawn_index] = pickup
		if pickup != null:
			spawned_count += 1
	return spawned_count


func _spawn_ammunition(spawn_point: Marker3D, spawn_index: int) -> Node3D:
	if ammunition_pickup_scene == null:
		push_error("MilitaryOutpostEncounter requires an ammunition pickup scene.")
		return null
	var pickup := ammunition_pickup_scene.instantiate() as Node3D
	if pickup == null:
		push_error("Military ammunition pickup must use a Node3D root.")
		return null
	pickup.name = "MilitaryAmmunition%d" % (spawn_index + 1)
	get_parent().add_child(pickup)
	pickup.global_transform = spawn_point.global_transform
	return pickup


func _is_pickup_active(pickup: Variant) -> bool:
	return is_instance_valid(pickup) and not pickup.is_queued_for_deletion()


func _prune_active_enemies() -> void:
	var living_enemies: Array[Node3D] = []
	for enemy in _active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			living_enemies.append(enemy)
	_active_enemies = living_enemies


func _request_feedback(message: String) -> void:
	if _camp_economy != null and _camp_economy.has_method(&"request_feedback"):
		_camp_economy.call(&"request_feedback", message)
