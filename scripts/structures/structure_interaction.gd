extends Area3D

const CAMP_ECONOMY_GROUP := &"camp_economy"
const REPAIR_COST := 10
const REPAIR_AMOUNT := 50
const DEMOLISH_REFUND_RATIO := 0.5


func interact(_player: Node) -> bool:
	var structure := get_parent() as StructureBase
	if structure == null or structure.data == null:
		return false
	if structure.current_health >= structure.data.max_health:
		_request_feedback("%s IS ALREADY FULLY REPAIRED" % structure.data.display_name.to_upper())
		return false
	var economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if economy == null or not economy.has_method(&"spend_stored_scrap"):
		return false
	if not bool(economy.call(&"spend_stored_scrap", REPAIR_COST)):
		_request_feedback("NOT ENOUGH STORED SCRAP: %d NEEDED" % REPAIR_COST)
		return false
	var repaired := structure.repair(REPAIR_AMOUNT)
	_request_feedback("%s REPAIRED +%d" % [structure.data.display_name.to_upper(), repaired])
	return repaired > 0


func demolish(_player: Node) -> bool:
	var structure := get_parent() as StructureBase
	if structure == null or structure.data == null:
		return false
	var refund := roundi(structure.data.scrap_cost * DEMOLISH_REFUND_RATIO)
	var economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if economy != null and refund > 0 and economy.has_method(&"refund_stored_scrap"):
		economy.call(&"refund_stored_scrap", refund)
	_request_feedback(
		"%s DEMOLISHED  •  REFUND %d SCRAP" % [structure.data.display_name.to_upper(), refund]
	)
	structure.destroy()
	return true


func _request_feedback(message: String) -> void:
	var economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if economy != null and economy.has_method(&"request_feedback"):
		economy.call(&"request_feedback", message)
