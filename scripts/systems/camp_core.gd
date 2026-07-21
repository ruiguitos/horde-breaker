extends StaticBody3D

signal health_changed(current_health: float, maximum_health: float)
signal destroyed

const PLAYER_GROUP := &"player"
const CAMP_ECONOMY_GROUP := &"camp_economy"

@export_range(1.0, 5000.0, 1.0) var maximum_health: float = 500.0
@export_range(0.1, 5.0, 0.1) var attack_target_radius: float = 1.1
@export_range(4.0, 40.0, 0.5) var resupply_radius: float = 12.0
@export_range(0.0, 50.0, 0.5) var resupply_heal_per_second: float = 5.0
@export_range(0, 50, 1) var resupply_ammo_per_second: int = 3

@onready var health_label: Label3D = %HealthLabel
@onready var core_light: OmniLight3D = %CoreLight

var current_health: float
var _is_destroyed: bool = false
var _resupply_tick_time: float = 0.0
var _player_inside_resupply: bool = false


func _ready() -> void:
	current_health = maximum_health
	_update_world_label()


func _physics_process(delta: float) -> void:
	# The camp acts as the run's safe hub: standing near the core slowly
	# heals the operative and trickles reserve ammunition back in.
	if _is_destroyed:
		return
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	if player == null:
		return
	var player_inside := (
		global_position.distance_to(player.global_position) <= resupply_radius
	)
	if player_inside and not _player_inside_resupply:
		_request_feedback("CAMP RESUPPLY ACTIVE")
	_player_inside_resupply = player_inside
	if not player_inside:
		_resupply_tick_time = 0.0
		return
	_resupply_tick_time += delta
	if _resupply_tick_time < 1.0:
		return
	_resupply_tick_time -= 1.0
	if player.has_method(&"heal"):
		player.call(&"heal", resupply_heal_per_second)
	if player.has_method(&"add_ammunition"):
		player.call(&"add_ammunition", resupply_ammo_per_second)


func _request_feedback(message: String) -> void:
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy != null and camp_economy.has_method(&"request_feedback"):
		camp_economy.call(&"request_feedback", message)


func take_enemy_damage(amount: float) -> float:
	if amount <= 0.0 or _is_destroyed:
		return 0.0

	var applied_damage := minf(amount, current_health)
	current_health -= applied_damage
	health_changed.emit(current_health, maximum_health)
	_update_world_label()
	if is_zero_approx(current_health):
		_is_destroyed = true
		core_light.light_color = Color(0.75, 0.08, 0.04, 1.0)
		destroyed.emit()
	return applied_damage


func repair(amount: float) -> float:
	if amount <= 0.0 or _is_destroyed or current_health >= maximum_health:
		return 0.0
	var repaired_health := minf(amount, maximum_health - current_health)
	current_health += repaired_health
	health_changed.emit(current_health, maximum_health)
	_update_world_label()
	return repaired_health


func get_attack_target_radius() -> float:
	return attack_target_radius


func _update_world_label() -> void:
	health_label.text = "CAMP CORE\n%d / %d\n[F] DEPOSIT / REPAIR\nRESUPPLY ZONE" % [
		roundi(current_health), roundi(maximum_health)
	]
