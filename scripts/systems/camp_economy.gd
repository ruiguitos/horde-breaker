extends Node

signal scrap_changed(carried_scrap: int, stored_scrap: int)
signal feedback_requested(message: String, duration: float)
signal upgrade_purchased(upgrade_id: StringName, new_level: int)

## Camp upgrades bought at the core stations with stored scrap. They last the
## current run, giving the deposit loop a real payoff.
const UPGRADE_DEFINITIONS: Dictionary[StringName, Dictionary] = {
	&"resupply_rate": {
		"name": "RESUPPLY RATE",
		"costs": [40, 80, 120],
		"heal_per_level": 4.0,
		"ammo_per_level": 2,
	},
	&"resupply_range": {
		"name": "RESUPPLY RANGE",
		"costs": [30, 60, 90],
		"radius_per_level": 4.0,
	},
	&"scavenging": {
		"name": "SCAVENGING",
		"costs": [50, 100, 150],
		"scrap_percent_per_level": 15,
	},
}

var carried_scrap: int = 0
var stored_scrap: int = 0
var _scrap_multiplier: float = 1.0
var _upgrade_levels: Dictionary[StringName, int] = {}


func _ready() -> void:
	_scrap_multiplier = float(
		SaveManager.get_skill_bonuses(SaveManager.get_selected_character()).get(
			"scrap_mult", 1.0
		)
	)


func add_carried_scrap(amount: int) -> int:
	if amount <= 0:
		return 0
	var total_multiplier := _scrap_multiplier * get_upgrade_scrap_multiplier()
	var boosted := maxi(roundi(amount * total_multiplier), amount)
	carried_scrap += boosted
	SaveManager.record_mastery_progress(
		SaveManager.get_selected_character(), &"scrap_500", boosted
	)
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


func refund_stored_scrap(amount: int) -> void:
	if amount <= 0:
		return
	stored_scrap += amount
	scrap_changed.emit(carried_scrap, stored_scrap)


func get_stored_scrap() -> int:
	return stored_scrap


func can_afford_stored_scrap(amount: int) -> bool:
	return amount >= 0 and stored_scrap >= amount


func get_upgrade_name(upgrade_id: StringName) -> String:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(upgrade_id, {})
	return String(definition.get("name", ""))


func get_upgrade_level(upgrade_id: StringName) -> int:
	return int(_upgrade_levels.get(upgrade_id, 0))


func get_upgrade_max_level(upgrade_id: StringName) -> int:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(upgrade_id, {})
	return Array(definition.get("costs", [])).size()


func get_next_upgrade_cost(upgrade_id: StringName) -> int:
	# -1 means the upgrade is already at its maximum level.
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(upgrade_id, {})
	if definition.is_empty():
		return -1
	var level := get_upgrade_level(upgrade_id)
	var costs: Array = definition["costs"]
	if level >= costs.size():
		return -1
	return int(costs[level])


func purchase_upgrade(upgrade_id: StringName) -> bool:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(upgrade_id, {})
	if definition.is_empty():
		push_error("CampEconomy has no upgrade named '%s'." % upgrade_id)
		return false
	var cost := get_next_upgrade_cost(upgrade_id)
	if cost < 0:
		request_feedback("%s ALREADY MAXED" % String(definition["name"]))
		return false
	if not spend_stored_scrap(cost):
		request_feedback("NOT ENOUGH STORED SCRAP: %d NEEDED" % cost)
		return false
	var new_level := get_upgrade_level(upgrade_id) + 1
	_upgrade_levels[upgrade_id] = new_level
	upgrade_purchased.emit(upgrade_id, new_level)
	request_feedback(
		"%s UPGRADED TO LV %d" % [String(definition["name"]), new_level]
	)
	return true


func get_resupply_heal_bonus() -> float:
	return (
		float(UPGRADE_DEFINITIONS[&"resupply_rate"]["heal_per_level"])
		* get_upgrade_level(&"resupply_rate")
	)


func get_resupply_ammo_bonus() -> int:
	return (
		int(UPGRADE_DEFINITIONS[&"resupply_rate"]["ammo_per_level"])
		* get_upgrade_level(&"resupply_rate")
	)


func get_resupply_radius_bonus() -> float:
	return (
		float(UPGRADE_DEFINITIONS[&"resupply_range"]["radius_per_level"])
		* get_upgrade_level(&"resupply_range")
	)


func get_upgrade_scrap_multiplier() -> float:
	return 1.0 + (
		float(UPGRADE_DEFINITIONS[&"scavenging"]["scrap_percent_per_level"]) / 100.0
		* get_upgrade_level(&"scavenging")
	)


func request_feedback(message: String, duration: float = 2.5) -> void:
	feedback_requested.emit(message, duration)
