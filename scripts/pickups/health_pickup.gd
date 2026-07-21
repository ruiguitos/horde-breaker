extends Area3D

signal collected(healed_amount: float)
signal restocked

const WAVE_MANAGER_GROUP := &"wave_manager"
const CAMP_ECONOMY_GROUP := &"camp_economy"

@export_range(1.0, 500.0, 1.0) var healing_amount: float = 40.0
@export var restock_after_cycle := true

@onready var collision_shape: CollisionShape3D = %CollisionShape3D

var _is_available := true
var _camp_economy: Node


func _ready() -> void:
	_camp_economy = get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if not restock_after_cycle:
		return
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager == null or not wave_manager.has_signal(&"cycle_completed"):
		push_error("HealthPickup requires a wave_manager node for restocking.")
		return
	wave_manager.connect(&"cycle_completed", _on_cycle_completed)


func interact(player: Node) -> bool:
	if (
		not _is_available
		or player == null
		or not player.has_method(&"heal")
	):
		return false

	var current_health := float(player.get("current_health"))
	var maximum_health := float(player.get("maximum_health"))
	var healed_amount := minf(healing_amount, maximum_health - current_health)
	if healed_amount <= 0.0:
		return false

	player.call(&"heal", healed_amount)
	_set_available(false)
	_request_feedback("+%d HEALTH" % roundi(healed_amount))
	collected.emit(healed_amount)
	return true


func is_available() -> bool:
	return _is_available


func _on_cycle_completed(_cycle_number: int) -> void:
	if _is_available:
		return
	_set_available(true)
	_request_feedback("HOSPITAL MEDKIT RESTOCKED")
	restocked.emit()


func _set_available(is_available: bool) -> void:
	_is_available = is_available
	visible = _is_available
	collision_shape.set_deferred(&"disabled", not _is_available)


func _request_feedback(message: String) -> void:
	if _camp_economy != null and _camp_economy.has_method(&"request_feedback"):
		_camp_economy.call(&"request_feedback", message)
