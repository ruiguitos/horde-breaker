extends Area3D

## Diegetic upgrade pedestal near the camp core: `F` buys the next level of one
## camp upgrade with stored scrap. State and effects live in CampEconomy.

const CAMP_ECONOMY_GROUP := &"camp_economy"

@export var upgrade_id: StringName = &"resupply_rate"

@onready var info_label: Label3D = %InfoLabel

var _camp_economy: Node


func _ready() -> void:
	_camp_economy = get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if _camp_economy == null:
		push_error("CampUpgradeStation requires a camp_economy node.")
		return
	_camp_economy.connect(&"upgrade_purchased", _on_upgrade_purchased)
	_refresh_label()


func interact(_player: Node) -> bool:
	if _camp_economy == null:
		return false
	return bool(_camp_economy.call(&"purchase_upgrade", upgrade_id))


func _on_upgrade_purchased(purchased_id: StringName, _new_level: int) -> void:
	if purchased_id == upgrade_id:
		_refresh_label()


func _refresh_label() -> void:
	var upgrade_name := String(_camp_economy.call(&"get_upgrade_name", upgrade_id))
	var level := int(_camp_economy.call(&"get_upgrade_level", upgrade_id))
	var max_level := int(_camp_economy.call(&"get_upgrade_max_level", upgrade_id))
	var cost := int(_camp_economy.call(&"get_next_upgrade_cost", upgrade_id))
	var action_line := (
		"MAXED" if cost < 0 else "[F] UPGRADE — %d SCRAP" % cost
	)
	info_label.text = "%s\nLV %d / %d\n%s" % [
		upgrade_name, level, max_level, action_line
	]
