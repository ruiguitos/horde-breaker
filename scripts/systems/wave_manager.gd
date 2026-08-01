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
## The clock ran out: no more spawns, and what is left on the map is all there
## is. The run objective drives this and waits for the count to reach zero.
signal final_phase_started(remaining_enemies: int)

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
const SPAWN_DEBUG_ROOT_NAME := &"SpawnDebug"
const SPAWN_DEBUG_MARKER_RADIUS := 0.32
const LEVELS_PER_CYCLE := 3
## Absolute guardrail: even an accidentally edited scene cannot ask the game to
## simulate an unbounded horde. The normal play budget is lower and exported.
const ABSOLUTE_ENEMY_CAP := 120
const CAMP_ECONOMY_GROUP := &"camp_economy"
# Instancing a whole batch in one frame costs ~10 ms with the bigger hordes, so
# spawns are queued and drip-fed a few per physics frame.
const SPAWNS_PER_FRAME := 2
## A large threat-level batch is a design request, not permission to reserve
## dozens of instances. A short queue keeps pressure steady and frame spikes low.
const MAX_QUEUED_SPAWNS := 12
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
## Global budget shared by the travelling horde, bosses and exploration
## encounters. Difficulty beyond this point comes from enemy composition.
@export_range(20, 120, 5) var max_simultaneous_enemies: int = 90
@export_range(2, 20, 1) var boss_every_levels: int = 5
## Editor/playtest aid. Shows every candidate marker and why the current
## director selected or rejected it. Kept off in normal runs.
@export var debug_spawn_points: bool = false

@onready var enemy_spawns: Node3D = %EnemySpawns
@onready var enemies: Node3D = %Enemies

var current_wave: int = 0
var alive_enemy_count: int = 0
var _spawning_enabled: bool = false
## Last stand: the horde is finite and no longer replaced.
var _final_phase: bool = false
var _spawn_cooldown: float = 0.0
var _level_time_remaining: float = 0.0
var _last_reported_seconds: int = -1
var _spawn_queue: Array = []
var _boss_pending: bool = false
var _surge_active: bool = false
var _recycle_time: float = 0.0
var _spawn_debug_root: Node3D = null
var _spawn_debug_mesh: SphereMesh = null
var _spawn_debug_materials: Dictionary = {}


func _ready() -> void:
	call_deferred(&"_start_first_threat_level")


func _physics_process(delta: float) -> void:
	if not _spawning_enabled:
		return
	if _final_phase:
		# Nothing new is coming, but the horde already out there still has to be
		# herded back to the player or the last few strays are unfindable.
		_recycle_time -= delta
		if _recycle_time <= 0.0:
			_recycle_time = RECYCLE_INTERVAL
			_recycle_distant_enemies()
		return
	_advance_level_timer(delta)
	if _boss_pending:
		_spawn_boss()
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


## Closes the tap. The threat level stops climbing, the queue is dropped and
## nothing new is born — from here the horde is a finite number that can be
## brought to zero, which is what the run's last stand is built on.
func begin_final_phase() -> void:
	if _final_phase:
		return
	_final_phase = true
	_surge_active = false
	_spawn_queue.clear()
	_boss_pending = false
	final_phase_started.emit(get_living_enemy_count())


func end_final_phase() -> void:
	_final_phase = false


func is_final_phase() -> bool:
	return _final_phase


## Every enemy alive anywhere, not just the ones this director spawned: sector
## ambushes and POI encounters make their own, and "clear the horde" means all
## of them. Corpses leave the group as they die, so this counts the living.
func get_living_enemy_count() -> int:
	# The director is also queried by tests and tools before it enters a tree.
	# Calling get_tree() in that state already logs an engine error, so check the
	# node state first instead of testing the returned value afterwards.
	if not is_inside_tree():
		return 0
	return get_tree().get_nodes_in_group(ENEMY_GROUP).size()


func is_preparation_active() -> bool:
	# Gates sector ambushes and POI encounters. They are always available in the
	# continuous mode — except during the last stand, where a POI spawning a
	# fresh pack would make the map impossible to clear.
	return not _final_phase


func get_maximum_alive_enemies() -> int:
	return mini(
		base_max_alive + max_alive_per_level * current_wave,
		mini(max_simultaneous_enemies, ABSOLUTE_ENEMY_CAP)
	)


## Capacity is based on every living enemy in the scene, not only the director's
## own counter. This prevents sector ambushes and POIs from exceeding the same
## performance budget. Queued horde spawns reserve their slots before instancing.
func get_available_spawn_slots(include_queue: bool = true) -> int:
	var living_count := (
		get_living_enemy_count() if is_inside_tree() else alive_enemy_count
	)
	var reserved_count := _spawn_queue.size() if include_queue else 0
	return maxi(get_maximum_alive_enemies() - living_count - reserved_count, 0)


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

	var available_slots := get_available_spawn_slots()
	for spawn_point in spawn_points:
		if available_slots <= 0:
			break
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
		available_slots -= 1
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
	var available_slots := get_available_spawn_slots()
	if available_slots <= 0:
		return
	var spawn_points := _gather_active_spawn_points()
	if spawn_points.is_empty():
		return
	spawn_points.shuffle()
	var batch_size := mini(
		5 + current_wave * 2 + (SURGE_BATCH_BONUS if _surge_active else 0),
		mini(available_slots, MAX_QUEUED_SPAWNS - _spawn_queue.size())
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
		if get_available_spawn_slots(false) <= 0:
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
	if get_available_spawn_slots(false) <= 0:
		_boss_pending = true
		return
	var spawn_points := _gather_active_spawn_points()
	if spawn_points.is_empty():
		_boss_pending = true
		return
	spawn_points.shuffle()
	if _spawn_enemy(boss_scene, spawn_points[0]):
		_boss_pending = false
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
	var candidates := _gather_all_spawn_points()
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	if player == null:
		_update_spawn_debug(candidates, candidates, null)
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
	if candidates.size() > MAX_ACTIVE_SPAWN_POINTS:
		candidates.sort_custom(
			func(a: Marker3D, b: Marker3D) -> bool:
				return (
					a.global_position.distance_squared_to(player_position)
					< b.global_position.distance_squared_to(player_position)
				)
		)
		candidates.resize(MAX_ACTIVE_SPAWN_POINTS)
	if debug_spawn_points:
		_update_spawn_debug(_gather_all_spawn_points(), candidates, player)
	else:
		_clear_spawn_debug()
	return candidates


func _gather_all_spawn_points() -> Array[Marker3D]:
	var spawn_points: Array[Marker3D] = []
	for child in enemy_spawns.get_children():
		var marker := child as Marker3D
		if marker != null:
			spawn_points.append(marker)
	for node in get_tree().get_nodes_in_group(SPAWN_POINT_GROUP):
		var marker := node as Marker3D
		if marker != null and marker not in spawn_points:
			spawn_points.append(marker)
	return spawn_points


func _update_spawn_debug(
	all_candidates: Array[Marker3D],
	selected_candidates: Array[Marker3D],
	player: Node3D
) -> void:
	if not debug_spawn_points:
		_clear_spawn_debug()
		return
	_clear_spawn_debug()
	_spawn_debug_root = Node3D.new()
	_spawn_debug_root.name = SPAWN_DEBUG_ROOT_NAME
	add_child(_spawn_debug_root)
	for index in all_candidates.size():
		var marker := all_candidates[index]
		if marker == null or not is_instance_valid(marker):
			continue
		var distance := (
			marker.global_position.distance_to(player.global_position)
			if player != null else 0.0
		)
		var state := &"available"
		var label := "AVAILABLE"
		if marker in selected_candidates:
			state = &"active"
			label = "ACTIVE"
		elif player != null and distance < MINIMUM_SPAWN_DISTANCE:
			state = &"rejected"
			label = "REJECT: TOO CLOSE"
		else:
			state = &"inactive"
			label = "INACTIVE: FARTHER"
		_add_spawn_debug_point(index, marker.global_position, state, label, distance)


func _add_spawn_debug_point(
	index: int,
	position: Vector3,
	state: StringName,
	label_text: String,
	distance: float
) -> void:
	var point := Node3D.new()
	point.name = "Point%d" % index
	_spawn_debug_root.add_child(point)
	point.global_position = position + Vector3.UP * 0.5

	var marker_visual := MeshInstance3D.new()
	marker_visual.name = "Marker"
	marker_visual.mesh = _get_spawn_debug_mesh()
	marker_visual.material_override = _get_spawn_debug_material(state)
	point.add_child(marker_visual)

	var label := Label3D.new()
	label.name = "Reason"
	label.position = Vector3.UP * 0.75
	label.text = "%s  %.0f m" % [label_text, distance]
	label.font_size = 22
	label.outline_size = 6
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0.02, 0.02, 0.02, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	point.add_child(label)


func _get_spawn_debug_mesh() -> SphereMesh:
	if _spawn_debug_mesh == null:
		_spawn_debug_mesh = SphereMesh.new()
		_spawn_debug_mesh.radius = SPAWN_DEBUG_MARKER_RADIUS
		_spawn_debug_mesh.height = SPAWN_DEBUG_MARKER_RADIUS * 2.0
		_spawn_debug_mesh.radial_segments = 12
		_spawn_debug_mesh.rings = 6
	return _spawn_debug_mesh


func _get_spawn_debug_material(state: StringName) -> StandardMaterial3D:
	if _spawn_debug_materials.has(state):
		return _spawn_debug_materials[state] as StandardMaterial3D
	var colors: Dictionary = {
		&"active": Color(0.12, 1.0, 0.32, 0.92),
		&"rejected": Color(1.0, 0.12, 0.08, 0.92),
		&"inactive": Color(1.0, 0.62, 0.08, 0.92),
		&"available": Color(0.18, 0.68, 1.0, 0.92),
	}
	var color: Color = colors.get(state, Color.WHITE)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.4
	material.no_depth_test = true
	_spawn_debug_materials[state] = material
	return material


func _clear_spawn_debug() -> void:
	if _spawn_debug_root == null or not is_instance_valid(_spawn_debug_root):
		_spawn_debug_root = null
		return
	_spawn_debug_root.free()
	_spawn_debug_root = null


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
