extends StaticBody3D

signal health_changed(current_health: float, maximum_health: float)
signal built
signal destroyed

const ARENA_NAVIGATION_GROUP := &"arena_navigation"
const CAMP_ECONOMY_GROUP := &"camp_economy"
const WAVE_MANAGER_GROUP := &"wave_manager"

@export_range(1, 500, 1) var build_cost: int = 30
@export_range(1.0, 5000.0, 1.0) var maximum_health: float = 200.0
@export_range(1.0, 100.0, 1.0) var health_per_scrap: float = 5.0
@export_range(1.0, 500.0, 1.0) var maximum_repair_per_interaction: float = 50.0
@export_range(0.1, 5.0, 0.1) var attack_target_radius: float = 1.8

@onready var barricade_visual: Node3D = %BarricadeVisual
@onready var site_marker: MeshInstance3D = %SiteMarker
@onready var status_label: Label3D = %StatusLabel
@onready var collision: CollisionShape3D = %Collision

var current_health: float = 0.0
var is_built: bool = false


func _ready() -> void:
	_update_presentation()


func interact(_player: Node) -> bool:
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if camp_economy == null or wave_manager == null:
		push_error("FortificationSite requires camp_economy and wave_manager nodes.")
		return false
	if not bool(wave_manager.call(&"is_preparation_active")):
		camp_economy.call(
			&"request_feedback", "BUILDING ONLY WHILE EXPLORING"
		)
		return false
	if not is_built:
		return _build_barricade(camp_economy)
	return _repair_barricade(camp_economy)


func take_enemy_damage(amount: float) -> float:
	if amount <= 0.0 or not is_built:
		return 0.0
	var applied_damage := minf(amount, current_health)
	current_health -= applied_damage
	health_changed.emit(current_health, maximum_health)
	_update_presentation()
	if is_zero_approx(current_health):
		_destroy_barricade()
	return applied_damage


func repair(amount: float) -> float:
	if amount <= 0.0 or not is_built or current_health >= maximum_health:
		return 0.0
	var repaired_health := minf(amount, maximum_health - current_health)
	current_health += repaired_health
	health_changed.emit(current_health, maximum_health)
	_update_presentation()
	return repaired_health


func get_attack_target_radius() -> float:
	return attack_target_radius


func _build_barricade(camp_economy: Node) -> bool:
	if not bool(camp_economy.call(&"spend_stored_scrap", build_cost)):
		_request_insufficient_scrap_feedback(camp_economy, build_cost)
		return false
	current_health = maximum_health
	is_built = true
	health_changed.emit(current_health, maximum_health)
	_update_presentation()
	call_deferred("_apply_collision_state", true)
	camp_economy.call(
		&"request_feedback", "BARRICADE BUILT  •  COST %d SCRAP" % build_cost
	)
	built.emit()
	return true


func _repair_barricade(camp_economy: Node) -> bool:
	var missing_health := maximum_health - current_health
	if missing_health <= 0.0:
		camp_economy.call(&"request_feedback", "THE BARRICADE IS ALREADY REPAIRED")
		return false
	var repair_amount := minf(missing_health, maximum_repair_per_interaction)
	var scrap_cost := ceili(repair_amount / health_per_scrap)
	if not bool(camp_economy.call(&"spend_stored_scrap", scrap_cost)):
		_request_insufficient_scrap_feedback(camp_economy, scrap_cost)
		return false
	var repaired_health := repair(repair_amount)
	camp_economy.call(
		&"request_feedback",
		"BARRICADE REPAIRED +%d  •  COST %d SCRAP"
		% [roundi(repaired_health), scrap_cost]
	)
	return repaired_health > 0.0


func _destroy_barricade() -> void:
	is_built = false
	_update_presentation()
	call_deferred("_apply_collision_state", false)
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy != null:
		camp_economy.call(&"request_feedback", "BARRICADE DESTROYED")
	destroyed.emit()


func _apply_collision_state(enabled: bool) -> void:
	collision.disabled = not enabled
	# Rebuild the streamed navigation region that owns this defense point. The
	# arena can have several regions active, so the first group member is not a
	# reliable choice.
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
	if int(camp_economy.get("carried_scrap")) > 0:
		camp_economy.call(
			&"request_feedback", "DEPOSIT YOUR SCRAP AT THE CORE FIRST"
		)
		return
	camp_economy.call(
		&"request_feedback", "NOT ENOUGH SCRAP: %d NEEDED" % required_scrap
	)


func _update_presentation() -> void:
	barricade_visual.visible = is_built
	site_marker.visible = not is_built
	if is_built:
		status_label.text = "BARRICADE\n%d / %d\n[F] REPAIR" % [
			roundi(current_health), roundi(maximum_health)
		]
	else:
		status_label.text = "DEFENSE POINT\n%d SCRAP\n[F] BUILD" % build_cost
