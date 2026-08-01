extends StaticBody3D

signal health_changed(current_health: float, maximum_health: float)
signal level_changed(level: int)
signal built
signal destroyed

const ARENA_NAVIGATION_GROUP := &"arena_navigation"
const CAMP_ECONOMY_GROUP := &"camp_economy"
const RUN_PROGRESSION_GROUP := &"run_progression"
const WAVE_MANAGER_GROUP := &"wave_manager"
const ENEMY_GROUP := &"enemy"
const ENEMY_TARGET_GROUP := &"enemy_target"

const LEVEL_DEFINITIONS: Array[Dictionary] = [
	{
		"cost": 45,
		"required_run_level": 1,
		"maximum_health": 200.0,
		"damage": 12.0,
		"range": 14.0,
		"fire_interval": 0.9,
	},
	{
		"cost": 90,
		"required_run_level": 5,
		"maximum_health": 325.0,
		"damage": 18.0,
		"range": 17.0,
		"fire_interval": 0.7,
	},
	{
		"cost": 150,
		"required_run_level": 10,
		"maximum_health": 475.0,
		"damage": 28.0,
		"range": 20.0,
		"fire_interval": 0.5,
	},
]

@export_range(1.0, 100.0, 1.0) var health_per_scrap: float = 5.0
@export_range(1.0, 500.0, 1.0) var maximum_repair_per_interaction: float = 75.0
@export_range(0.1, 5.0, 0.1) var attack_target_radius: float = 1.9

@onready var site_visual: Node3D = %SiteVisual
@onready var tower_visual: Node3D = %TowerVisual
@onready var level_two_visual: Node3D = %LevelTwoVisual
@onready var level_three_visual: Node3D = %LevelThreeVisual
@onready var turret_pivot: Node3D = %TurretPivot
@onready var muzzle: Marker3D = %Muzzle
@onready var status_label: Label3D = %StatusLabel
@onready var collision: CollisionShape3D = %Collision

var tower_level: int = 0
var current_health: float = 0.0
var _fire_time: float = 0.0
var _current_target: Node3D


func _ready() -> void:
	_update_presentation()


func _physics_process(delta: float) -> void:
	if tower_level <= 0:
		return
	_fire_time = maxf(_fire_time - delta, 0.0)
	_current_target = _find_target()
	if not is_instance_valid(_current_target):
		return
	_aim_at(_current_target.global_position + Vector3.UP * 0.8)
	if _fire_time <= 0.0 and _has_clear_shot(_current_target):
		_fire_at(_current_target)


func interact(_player: Node) -> bool:
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if camp_economy == null or wave_manager == null:
		push_error("DefenseTowerSite requires camp_economy and wave_manager nodes.")
		return false
	if not bool(wave_manager.call(&"is_preparation_active")):
		camp_economy.call(&"request_feedback", "TOWERS LOCKED DURING LAST STAND")
		return false
	if tower_level <= 0:
		return _purchase_next_level(camp_economy)
	if current_health < get_maximum_health():
		return _repair_tower(camp_economy)
	if tower_level < LEVEL_DEFINITIONS.size():
		return _purchase_next_level(camp_economy)
	camp_economy.call(&"request_feedback", "DEFENSE TOWER ALREADY MAXED")
	return false


func take_damage(amount: float) -> float:
	if amount <= 0.0 or tower_level <= 0:
		return 0.0
	var applied_damage := minf(amount, current_health)
	current_health -= applied_damage
	health_changed.emit(current_health, get_maximum_health())
	_update_presentation()
	if is_zero_approx(current_health):
		_destroy_tower()
	return applied_damage


func take_enemy_damage(amount: float) -> float:
	return take_damage(amount)


func repair(amount: float) -> float:
	if amount <= 0.0 or tower_level <= 0:
		return 0.0
	var repaired_health := minf(amount, get_maximum_health() - current_health)
	current_health += repaired_health
	if repaired_health > 0.0:
		health_changed.emit(current_health, get_maximum_health())
		_update_presentation()
	return repaired_health


func get_attack_target_radius() -> float:
	return attack_target_radius


func get_tower_level() -> int:
	return tower_level


func get_maximum_health() -> float:
	if tower_level <= 0:
		return 0.0
	return float(LEVEL_DEFINITIONS[tower_level - 1]["maximum_health"])


func get_damage() -> float:
	if tower_level <= 0:
		return 0.0
	return float(LEVEL_DEFINITIONS[tower_level - 1]["damage"])


func get_attack_range() -> float:
	if tower_level <= 0:
		return 0.0
	return float(LEVEL_DEFINITIONS[tower_level - 1]["range"])


func get_fire_interval() -> float:
	if tower_level <= 0:
		return 0.0
	return float(LEVEL_DEFINITIONS[tower_level - 1]["fire_interval"])


func _purchase_next_level(camp_economy: Node) -> bool:
	var next_level := tower_level + 1
	if next_level > LEVEL_DEFINITIONS.size():
		return false
	var definition := LEVEL_DEFINITIONS[next_level - 1]
	var required_level := int(definition["required_run_level"])
	var run_level := _get_run_level()
	if run_level < required_level:
		camp_economy.call(
			&"request_feedback", "RUN LEVEL %d REQUIRED" % required_level
		)
		return false
	var cost := int(definition["cost"])
	if not bool(camp_economy.call(&"spend_stored_scrap", cost)):
		_request_insufficient_scrap_feedback(camp_economy, cost)
		return false
	tower_level = next_level
	current_health = get_maximum_health()
	_fire_time = 0.0
	if not is_in_group(ENEMY_TARGET_GROUP):
		add_to_group(ENEMY_TARGET_GROUP)
	_update_presentation()
	call_deferred(&"_apply_collision_state", true)
	health_changed.emit(current_health, get_maximum_health())
	level_changed.emit(tower_level)
	if tower_level == 1:
		camp_economy.call(
			&"request_feedback", "DEFENSE TOWER BUILT  •  COST %d SCRAP" % cost
		)
		built.emit()
	else:
		camp_economy.call(
			&"request_feedback",
			"DEFENSE TOWER UPGRADED TO LV %d  •  COST %d SCRAP"
			% [tower_level, cost]
		)
	return true


func _repair_tower(camp_economy: Node) -> bool:
	var missing_health := get_maximum_health() - current_health
	if missing_health <= 0.0:
		return false
	var repair_amount := minf(missing_health, maximum_repair_per_interaction)
	var scrap_cost := ceili(repair_amount / health_per_scrap)
	if not bool(camp_economy.call(&"spend_stored_scrap", scrap_cost)):
		_request_insufficient_scrap_feedback(camp_economy, scrap_cost)
		return false
	var repaired_health := repair(repair_amount)
	camp_economy.call(
		&"request_feedback",
		"DEFENSE TOWER REPAIRED +%d  •  COST %d SCRAP"
		% [roundi(repaired_health), scrap_cost]
	)
	return repaired_health > 0.0


func _destroy_tower() -> void:
	remove_from_group(ENEMY_TARGET_GROUP)
	tower_level = 0
	current_health = 0.0
	_current_target = null
	_update_presentation()
	call_deferred(&"_apply_collision_state", false)
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy != null:
		camp_economy.call(&"request_feedback", "DEFENSE TOWER DESTROYED")
	destroyed.emit()


func _find_target() -> Node3D:
	var best_target: Node3D
	var best_distance_squared := get_attack_range() * get_attack_range()
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var candidate := node as Node3D
		if candidate == null or not candidate.has_method(&"take_damage"):
			continue
		var distance_squared := global_position.distance_squared_to(
			candidate.global_position
		)
		if distance_squared <= best_distance_squared:
			best_target = candidate
			best_distance_squared = distance_squared
	return best_target


func _aim_at(world_position: Vector3) -> void:
	var flat_target := world_position
	flat_target.y = turret_pivot.global_position.y
	if turret_pivot.global_position.distance_squared_to(flat_target) <= 0.001:
		return
	turret_pivot.look_at(flat_target, Vector3.UP)


func _has_clear_shot(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		muzzle.global_position,
		target.global_position + Vector3.UP * 0.8,
		1
	)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _fire_at(target: Node3D) -> void:
	_fire_time = get_fire_interval()
	target.call(&"take_damage", get_damage())
	_spawn_tracer(muzzle.global_position, target.global_position + Vector3.UP * 0.8)


func _spawn_tracer(start: Vector3, end: Vector3) -> void:
	var distance := start.distance_to(end)
	if distance <= 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.055, 0.055, distance)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.68, 0.16)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.28, 0.03)
	material.emission_energy_multiplier = 2.2
	mesh.material = material
	var tracer := MeshInstance3D.new()
	tracer.name = "TowerTracer"
	tracer.mesh = mesh
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = start.lerp(end, 0.5)
	tracer.look_at(end, Vector3.UP)
	get_tree().create_timer(0.07).timeout.connect(tracer.queue_free)


func _get_run_level() -> int:
	var progression := get_tree().get_first_node_in_group(RUN_PROGRESSION_GROUP)
	if progression == null:
		return 1
	return maxi(int(progression.get(&"run_level")), 1)


func _apply_collision_state(enabled: bool) -> void:
	collision.disabled = not enabled
	for navigation in get_tree().get_nodes_in_group(ARENA_NAVIGATION_GROUP):
		if not navigation.has_method(&"build_navigation_mesh"):
			continue
		var region := navigation as Node3D
		if region == null:
			continue
		var local_site_position := region.to_local(global_position)
		var half_extent := float(region.get(&"navigation_half_extent"))
		if (
			absf(local_site_position.x) <= half_extent
			and absf(local_site_position.z) <= half_extent
		):
			navigation.call(&"build_navigation_mesh")


func _request_insufficient_scrap_feedback(
	camp_economy: Node, required_scrap: int
) -> void:
	if int(camp_economy.get(&"carried_scrap")) > 0:
		camp_economy.call(&"request_feedback", "DEPOSIT YOUR SCRAP AT THE CORE FIRST")
		return
	camp_economy.call(
		&"request_feedback", "NOT ENOUGH STORED SCRAP: %d NEEDED" % required_scrap
	)


func _update_presentation() -> void:
	var active := tower_level > 0
	site_visual.visible = not active
	tower_visual.visible = active
	level_two_visual.visible = tower_level >= 2
	level_three_visual.visible = tower_level >= 3
	if not active:
		var definition := LEVEL_DEFINITIONS[0]
		status_label.text = "DEFENSE TOWER\n%d SCRAP  •  RUN LV %d\n[F] BUILD" % [
			int(definition["cost"]), int(definition["required_run_level"])
		]
		return
	var maximum_health := get_maximum_health()
	if current_health < maximum_health:
		status_label.text = "DEFENSE TOWER  LV %d\n%d / %d HP\n[F] REPAIR" % [
			tower_level, roundi(current_health), roundi(maximum_health)
		]
		return
	if tower_level >= LEVEL_DEFINITIONS.size():
		status_label.text = "DEFENSE TOWER  LV %d MAX\n%d / %d HP" % [
			tower_level, roundi(current_health), roundi(maximum_health)
		]
		return
	var next_definition := LEVEL_DEFINITIONS[tower_level]
	status_label.text = "DEFENSE TOWER  LV %d\nNEXT: %d SCRAP  •  RUN LV %d\n[F] UPGRADE" % [
		tower_level,
		int(next_definition["cost"]),
		int(next_definition["required_run_level"]),
	]
