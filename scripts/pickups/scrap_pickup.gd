extends Area3D

signal collected

const CAMP_ECONOMY_GROUP := &"camp_economy"

@export_range(1, 500, 1) var scrap_amount: int = 25


func interact(_player: Node) -> bool:
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	if camp_economy == null or not camp_economy.has_method(&"add_carried_scrap"):
		push_error("ScrapPickup requires a camp_economy node.")
		return false
	var collected_scrap := int(
		camp_economy.call(&"add_carried_scrap", scrap_amount)
	)
	if collected_scrap <= 0:
		return false
	camp_economy.call(
		&"request_feedback", "+%d SCRAP TRANSPORTADO" % collected_scrap
	)
	collected.emit()
	queue_free()
	return true
