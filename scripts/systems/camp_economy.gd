extends Node

signal scrap_changed(carried_scrap: int, stored_scrap: int)
signal feedback_requested(message: String, duration: float)

var carried_scrap: int = 0
var stored_scrap: int = 0
var _scrap_multiplier: float = 1.0


func _ready() -> void:
	_scrap_multiplier = float(
		SaveManager.get_skill_bonuses(SaveManager.get_selected_character()).get(
			"scrap_mult", 1.0
		)
	)


func add_carried_scrap(amount: int) -> int:
	if amount <= 0:
		return 0
	var boosted := maxi(roundi(amount * _scrap_multiplier), amount)
	carried_scrap += boosted
	scrap_changed.emit(carried_scrap, stored_scrap)
	return boosted


func deposit_all_scrap() -> int:
	if carried_scrap <= 0:
		return 0
	var deposited_scrap := carried_scrap
	stored_scrap += deposited_scrap
	carried_scrap = 0
	scrap_changed.emit(carried_scrap, stored_scrap)
	return deposited_scrap


func spend_stored_scrap(amount: int) -> bool:
	if amount <= 0 or stored_scrap < amount:
		return false
	stored_scrap -= amount
	scrap_changed.emit(carried_scrap, stored_scrap)
	return true


func request_feedback(message: String, duration: float = 2.5) -> void:
	feedback_requested.emit(message, duration)
