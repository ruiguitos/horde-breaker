extends Area3D

signal encounter_started(enemy_count: int)

const PLAYER_GROUP := &"player"
const WAVE_MANAGER_GROUP := &"wave_manager"
const CAMP_ECONOMY_GROUP := &"camp_economy"

@export var enemy_scene: PackedScene
@export var scrap_pickup_scene: PackedScene
@export var ammunition_pickup_scene: PackedScene

@onready var enemy_spawns: Node3D = %WarehouseEnemySpawns
@onready var scrap_spawn: Marker3D = %WarehouseScrapSpawn
@onready var ammunition_spawn: Marker3D = %WarehouseAmmunitionSpawn

var _wave_manager: Node
var _camp_economy: Node
var _encounter_available := true
var _reset_pending := false
var _active_enemies: Array[Node3D] = []
var _scrap_pickup: Node3D
var _ammunition_pickup: Node3D


func _ready() -> void:
	_wave_manager = get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	_camp_economy = get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if _wave_manager == null:
		push_error("WarehouseEncounter requires a wave_manager node.")
		return
	if not _wave_manager.has_method(&"spawn_exploration_enemies"):
		push_error("WarehouseEncounter requires exploration spawning support.")
		return
	if not _wave_manager.has_signal(&"cycle_completed"):
		push_error("WarehouseEncounter requires the cycle_completed signal.")
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

	var spawn_points := _get_spawn_points()
	if spawn_points.is_empty():
		return
	var spawned_value: Variant = _wave_manager.call(
		&"spawn_exploration_enemies", enemy_scene, spawn_points
	)
	if not spawned_value is Array:
		push_error("WaveManager must return the spawned exploration enemies.")
		return

	var spawned_enemies: Array = spawned_value
	for spawned_value_item: Variant in spawned_enemies:
		var enemy := spawned_value_item as Node3D
		if enemy == null:
			continue
		_active_enemies.append(enemy)
		enemy.connect(&"died", _on_encounter_enemy_died)
	if _active_enemies.is_empty():
		return

	_encounter_available = false
	_reset_pending = false
	_request_feedback("ARMAZÉM INFESTADO  •  %d AMEAÇAS" % _active_enemies.size())
	encounter_started.emit(_active_enemies.size())


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
	var replenished_pickups := _spawn_missing_loot()
	if replenished_pickups > 0:
		_request_feedback("LOOT DO ARMAZÉM REPÔS-SE")


func _on_intermission_started(_next_wave: int, _duration: float) -> void:
	call_deferred(&"_try_start_for_overlapping_player")


func _try_start_for_overlapping_player() -> void:
	for body in get_overlapping_bodies():
		var player := body as Node3D
		if player != null and player.is_in_group(PLAYER_GROUP):
			_try_start_encounter(player)
			return


func _get_spawn_points() -> Array[Marker3D]:
	var spawn_points: Array[Marker3D] = []
	for child in enemy_spawns.get_children():
		var spawn_point := child as Marker3D
		if spawn_point == null:
			push_error("Warehouse encounter spawn points must be Marker3D nodes.")
			continue
		spawn_points.append(spawn_point)
	return spawn_points


func _spawn_initial_loot() -> void:
	_spawn_missing_loot()


func _spawn_missing_loot() -> int:
	var spawned_count := 0
	if not _is_pickup_active(_scrap_pickup):
		_scrap_pickup = _spawn_pickup(
			scrap_pickup_scene, scrap_spawn, &"InteriorScrap"
		)
		if _scrap_pickup != null:
			spawned_count += 1
	if not _is_pickup_active(_ammunition_pickup):
		_ammunition_pickup = _spawn_pickup(
			ammunition_pickup_scene,
			ammunition_spawn,
			&"InteriorAmmunition"
		)
		if _ammunition_pickup != null:
			spawned_count += 1
	return spawned_count


func _spawn_pickup(
	pickup_scene: PackedScene, spawn_point: Marker3D, pickup_name: StringName
) -> Node3D:
	if pickup_scene == null:
		push_error("WarehouseEncounter requires both pickup scenes.")
		return null
	var pickup := pickup_scene.instantiate() as Node3D
	if pickup == null:
		push_error("Warehouse pickup scenes must use Node3D roots.")
		return null
	pickup.name = pickup_name
	get_parent().add_child(pickup)
	pickup.global_transform = spawn_point.global_transform
	return pickup


func _is_pickup_active(pickup: Variant) -> bool:
	return (
		is_instance_valid(pickup)
		and not pickup.is_queued_for_deletion()
	)


func _prune_active_enemies() -> void:
	var living_enemies: Array[Node3D] = []
	for enemy in _active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			living_enemies.append(enemy)
	_active_enemies = living_enemies


func _request_feedback(message: String) -> void:
	if _camp_economy != null and _camp_economy.has_method(&"request_feedback"):
		_camp_economy.call(&"request_feedback", message)
