extends Node

## Continuous horde director: rounds were removed, enemies now spawn around
## the player while they travel across the map. Threat escalates over time.
## Legacy signal names are kept so encounters, progression and loot restock
## keep working: wave_* signals now describe threat levels and cycles group
## three levels, matching the old three-wave cycle rewards.

signal wave_started(threat_level: int)
signal enemy_count_changed(remaining_enemies: int)
signal wave_completed(threat_level: int)
signal intermission_started(next_level: int, duration: float)
signal preparation_time_changed(seconds_remaining: int)
signal enemy_defeated(xp_reward: int)
signal cycle_completed(cycle_number: int)

const PLAYER_GROUP := &"player"
const ENEMY_GROUP := &"enemy"
## Only enemies the director spawned. Encounter enemies guard a POI and must
## stay where they were placed, so they are excluded from recycling and from
## the alive count.
const HORDE_ENEMY_GROUP := &"horde_enemy"
const SPAWN_POINT_GROUP := &"enemy_spawn_point"
const MAX_ACTIVE_SPAWN_POINTS := 6
const SPAWN_POSITION_JITTER := 1.5
const MINIMUM_SPAWN_DISTANCE := 12.0
const LEVELS_PER_CYCLE := 3
const HARD_ENEMY_CAP := 140
const CAMP_ECONOMY_GROUP := &"camp_economy"
# Instancing a whole batch in one frame costs ~10 ms with the bigger hordes, so
# spawns are queued and drip-fed a few per physics frame.
const SPAWNS_PER_FRAME := 3
# The extraction window turns the pressure up: faster spawns, bigger batches.
const SURGE_INTERVAL_SCALE := 0.55
const SURGE_BATCH_BONUS := 6
# The player outruns the horde (4-7 m/s against 2.5), so enemies pile up behind
# them. Stranded enemies are no threat but still occupy the alive cap, which is
# what made the HUD read "140 HOSTILES" with nothing in sight while new spawns
# stopped appearing. Anything left this far behind is moved back into the fight.
const RECYCLE_DISTANCE := 78.0
const RECYCLE_INTERVAL := 1.0
# The opening used to hand the player a full horde inside twenty seconds, with
# no room to find a weapon, a street or the camp first. The first threat levels
# now run longer and the extra time decays away: level 1 lasts 110 s, level 5
# lasts the standard 75 s, and nothing past level 5 is any slower than before.
const EARLY_LEVEL_BONUS := 35.0
const EARLY_LEVEL_COUNT := 5
# Paired with base_spawn_interval: the opening interval is longer, so it has to
# fall faster to arrive at the same place. 6.0 - 5 * 0.65 = 2.75, which is what
# 4.5 - 5 * 0.35 used to give at threat level 5.
const SPAWN_INTERVAL_DECAY := 0.65

@export var normal_zombie_scene: PackedScene
@export var runner_zombie_scene: PackedScene
@export var brute_zombie_scene: PackedScene
@export var spitter_zombie_scene: PackedScene
@export var boss_scene: PackedScene
@export_range(1.0, 120.0, 0.5) var first_surge_delay: float = 45.0
## The pace the run settles into. The opening is slower than this and converges
## on it — see EARLY_LEVEL_BONUS.
@export_range(10.0, 300.0, 1.0) var level_up_interval: float = 75.0
@export_range(0.5, 30.0, 0.5) var base_spawn_interval: float = 6.0
## Base and per-level are read together: threat level 1 allows 20 enemies where
## it used to allow 32, and level 5 lands on the same 80 as before. The opening
## is thinner; the run it grows into is not.
@export_range(1, 200, 1) var base_max_alive: int = 5
@export_range(0, 40, 1) var max_alive_per_level: int = 15
@export_range(2, 20, 1) var boss_every_levels: int = 5

@onready var enemy_spawns: Node3D = %EnemySpawns
@onready var enemies: Node3D = %Enemies

var current_wave: int = 0
var alive_enemy_count: int = 0
var _spawning_enabled: bool = false
var _spawn_cooldown: float = 0.0
var _level_time_remaining: float = 0.0
var _last_reported_seconds: int = -1
var _spawn_queue: Array = []
var _surge_active: bool = false
var _recycle_time: float = 0.0


func _ready() -> void:
	call_deferred(&"_start_first_threat_level")


func _physics_process(delta: float) -> void:
	if not _spawning_enabled:
		return
	_advance_level_timer(delta)
	_drain_spawn_queue()
	_recycle_time -= delta
	if _recycle_time <= 0.0:
		_recycle_time = RECYCLE_INTERVAL
		_recycle_distant_enemies()
	_spawn_cooldown -= delta
	if _spawn_cooldown > 0.0:
		return
	_spawn_cooldown = get_current_spawn_interval()
	_spawn_travel_batch()


func is_preparation_active() -> bool:
	# Building, repairing and exploration encounters are always available in
	# the continuous mode; the method is kept for compatibility.
	return true


func get_maximum_alive_enemies() -> int:
	return mini(base_max_alive + max_alive_per_level * current_wave, HARD_ENEMY_CAP)


func get_current_spawn_interval() -> float:
	var interval := maxf(
		base_spawn_interval - float(current_wave) * SPAWN_INTERVAL_DECAY, 1.2
	)
	return interval * SURGE_INTERVAL_SCALE if _surge_active else interval


## How long the level the player is on lasts. The first few run long and the
## duration walks down to `level_up_interval` by EARLY_LEVEL_COUNT, so the
## opening minutes have room to breathe without the whole run being slower: from
## threat level 5 onwards this is exactly the old pace.
func get_level_duration(level: int) -> float:
	# Spread over the levels between the first and EARLY_LEVEL_COUNT, so the bonus
	# is fully paid out *at* that level rather than one past it.
	var eased := clampf(
		1.0 - float(level - 1) / float(maxi(EARLY_LEVEL_COUNT - 1, 1)), 0.0, 1.0
	)
	return level_up_interval + EARLY_LEVEL_BONUS * eased


func set_surge_active(active: bool) -> void:
	_surge_active = active


func spawn_exploration_enemies(
	enemy_scene: PackedScene, spawn_points: Array[Marker3D]
) -> Array[Node3D]:
	var spawned_enemies: Array[Node3D] = []
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


func _start_first_threat_level() -> void:
	current_wave = 1
	_level_time_remaining = get_level_duration(current_wave)
	_spawn_cooldown = first_surge_delay
	_spawning_enabled = true
	wave_started.emit(current_wave)
	enemy_count_changed.emit(alive_enemy_count)
	intermission_started.emit(current_wave, first_surge_delay)
	_report_countdown(first_surge_delay)


func _advance_level_timer(delta: float) -> void:
	_level_time_remaining -= delta
	_report_countdown(_level_time_remaining)
	if _level_time_remaining > 0.0:
		return
	wave_completed.emit(current_wave)
	if current_wave % LEVELS_PER_CYCLE == 0:
		cycle_completed.emit(current_wave / LEVELS_PER_CYCLE)
	current_wave += 1
	_level_time_remaining = get_level_duration(current_wave)
	wave_started.emit(current_wave)
	intermission_started.emit(current_wave, _level_time_remaining)
	if boss_scene != null and current_wave % boss_every_levels == 0:
		_spawn_boss()


func _report_countdown(seconds_remaining: float) -> void:
	var whole_seconds := maxi(ceili(seconds_remaining), 0)
	if whole_seconds == _last_reported_seconds:
		return
	_last_reported_seconds = whole_seconds
	preparation_time_changed.emit(whole_seconds)


func _spawn_travel_batch() -> void:
	if normal_zombie_scene == null or runner_zombie_scene == null:
		push_error("HordeDirector requires Normal Zombie and Runner scenes.")
		return
	var maximum_alive := get_maximum_alive_enemies()
	if alive_enemy_count >= maximum_alive:
		return
	var spawn_points := _gather_active_spawn_points()
	if spawn_points.is_empty():
		return
	spawn_points.shuffle()
	var batch_size := mini(
		5 + current_wave * 2 + (SURGE_BATCH_BONUS if _surge_active else 0),
		maximum_alive - alive_enemy_count
	)
	for spawn_index in batch_size:
		var spawn_point := spawn_points[spawn_index % spawn_points.size()]
		if spawn_point != null:
			_spawn_queue.append([_pick_enemy_scene(), spawn_point])


func _drain_spawn_queue() -> void:
	# Spread instancing over frames so a big batch never lands in one frame.
	if _spawn_queue.is_empty():
		return
	var spawned := 0
	var changed := false
	while spawned < SPAWNS_PER_FRAME and not _spawn_queue.is_empty():
		var entry: Array = _spawn_queue.pop_front()
		spawned += 1
		var scene: PackedScene = entry[0]
		var marker: Marker3D = entry[1]
		if scene == null or not is_instance_valid(marker):
			continue
		if alive_enemy_count >= get_maximum_alive_enemies():
			_spawn_queue.clear()
			break
		if _spawn_enemy(scene, marker):
			alive_enemy_count += 1
			changed = true
	if changed:
		enemy_count_changed.emit(alive_enemy_count)


func _recycle_distant_enemies() -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	if player == null:
		return
	var spawn_points := _gather_active_spawn_points()
	var player_position := player.global_position
	var alive := 0
	for child in enemies.get_children():
		var enemy := child as Node3D
		# Corpses waiting out their death animation have already left the enemy
		# group; they must not be counted or recycled.
		if enemy == null or not enemy.is_in_group(HORDE_ENEMY_GROUP):
			continue
		if not enemy.is_in_group(ENEMY_GROUP):
			continue
		alive += 1
		if enemy.global_position.distance_to(player_position) < RECYCLE_DISTANCE:
			continue
		if spawn_points.is_empty():
			enemy.queue_free()
			alive -= 1
			continue
		# Moved rather than respawned: no instancing cost, and the horde keeps
		# pressing instead of trailing uselessly behind.
		var marker := spawn_points[randi() % spawn_points.size()]
		enemy.global_position = marker.global_position + Vector3(
			randf_range(-SPAWN_POSITION_JITTER, SPAWN_POSITION_JITTER),
			0.0,
			randf_range(-SPAWN_POSITION_JITTER, SPAWN_POSITION_JITTER)
		)
	# Reconciled against the tree: an enemy can leave without emitting `died`
	# (freed, recycled away, or lost with its parent), and every one of those
	# used to leak a slot in the cap forever.
	if alive != alive_enemy_count:
		alive_enemy_count = alive
		enemy_count_changed.emit(alive_enemy_count)


func _pick_enemy_scene() -> PackedScene:
	# Weighted by threat level: runners appear early, brutes from level 2 and
	# spitters from level 3, all growing more common as the horde escalates.
	var weighted_scenes: Array = [[normal_zombie_scene, 1.0]]
	weighted_scenes.append([runner_zombie_scene, minf(0.15 * current_wave, 0.7)])
	if brute_zombie_scene != null and current_wave >= 2:
		weighted_scenes.append(
			[brute_zombie_scene, minf(0.08 * float(current_wave - 1), 0.35)]
		)
	if spitter_zombie_scene != null and current_wave >= 3:
		weighted_scenes.append(
			[spitter_zombie_scene, minf(0.1 * float(current_wave - 2), 0.4)]
		)
	var total_weight := 0.0
	for entry in weighted_scenes:
		total_weight += float(entry[1])
	var pick := randf() * total_weight
	for entry in weighted_scenes:
		pick -= float(entry[1])
		if pick <= 0.0:
			return entry[0] as PackedScene
	return normal_zombie_scene


func _spawn_boss() -> void:
	var spawn_points := _gather_active_spawn_points()
	if spawn_points.is_empty():
		return
	spawn_points.shuffle()
	if _spawn_enemy(boss_scene, spawn_points[0]):
		alive_enemy_count += 1
		enemy_count_changed.emit(alive_enemy_count)
		_announce("⚠  THE BREAKER HAS ARRIVED")


func _announce(message: String) -> void:
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy != null and camp_economy.has_method(&"request_feedback"):
		camp_economy.call(&"request_feedback", message)


func _gather_active_spawn_points() -> Array[Marker3D]:
	# Hordes emerge from the spawn points closest to the player (but never on
	# top of them), so streamed sector markers take over away from the camp.
	var candidates: Array[Marker3D] = []
	for child in enemy_spawns.get_children():
		var marker := child as Marker3D
		if marker != null:
			candidates.append(marker)
	for node in get_tree().get_nodes_in_group(SPAWN_POINT_GROUP):
		var marker := node as Marker3D
		if marker != null and marker not in candidates:
			candidates.append(marker)
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	if player == null:
		return candidates
	var player_position := player.global_position
	var distant_candidates: Array[Marker3D] = []
	for candidate in candidates:
		if (
			candidate.global_position.distance_to(player_position)
			>= MINIMUM_SPAWN_DISTANCE
		):
			distant_candidates.append(candidate)
	if not distant_candidates.is_empty():
		candidates = distant_candidates
	if candidates.size() <= MAX_ACTIVE_SPAWN_POINTS:
		return candidates
	candidates.sort_custom(
		func(a: Marker3D, b: Marker3D) -> bool:
			return (
				a.global_position.distance_squared_to(player_position)
				< b.global_position.distance_squared_to(player_position)
			)
	)
	candidates.resize(MAX_ACTIVE_SPAWN_POINTS)
	return candidates


func _spawn_enemy(enemy_scene: PackedScene, spawn_point: Marker3D) -> bool:
	var enemy := enemy_scene.instantiate() as Node3D
	if enemy == null:
		push_error("HordeDirector enemy scenes must have a Node3D root.")
		return false
	if not enemy.has_signal(&"died"):
		push_error("HordeDirector enemies must expose a died signal.")
		enemy.queue_free()
		return false

	enemies.add_child(enemy)
	enemy.add_to_group(HORDE_ENEMY_GROUP)
	enemy.global_position = spawn_point.global_position + Vector3(
		randf_range(-SPAWN_POSITION_JITTER, SPAWN_POSITION_JITTER),
		0.0,
		randf_range(-SPAWN_POSITION_JITTER, SPAWN_POSITION_JITTER)
	)
	enemy.connect(&"died", _on_enemy_died)
	return true


func _on_enemy_died(enemy: Node) -> void:
	var xp_reward := int(enemy.get("xp_reward")) if enemy != null else 0
	enemy_defeated.emit(maxi(xp_reward, 0))
	alive_enemy_count = maxi(alive_enemy_count - 1, 0)
	enemy_count_changed.emit(alive_enemy_count)


func _on_exploration_enemy_died(enemy: Node) -> void:
	var xp_reward := int(enemy.get("xp_reward")) if enemy != null else 0
	enemy_defeated.emit(maxi(xp_reward, 0))
