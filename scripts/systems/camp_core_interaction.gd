extends Area3D

const CAMP_ECONOMY_GROUP := &"camp_economy"
const WAVE_MANAGER_GROUP := &"wave_manager"

@export_range(1.0, 100.0, 1.0) var health_per_scrap: float = 5.0
@export_range(1.0, 500.0, 1.0) var maximum_repair_per_interaction: float = 50.0


func interact(_player: Node) -> bool:
	var camp_core := get_parent()
	var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if camp_core == null or camp_economy == null or wave_manager == null:
		push_error(
			"CampCoreInteraction requires camp core, camp_economy and wave_manager."
		)
		return false

	var carried_scrap := int(camp_economy.get("carried_scrap"))
	if carried_scrap > 0:
		var deposited_scrap := int(camp_economy.call(&"deposit_all_scrap"))
		camp_economy.call(
			&"request_feedback",
			"%d SCRAP GUARDADO NO ACAMPAMENTO" % deposited_scrap
		)
		return deposited_scrap > 0

	if not bool(wave_manager.call(&"is_preparation_active")):
		camp_economy.call(
			&"request_feedback", "REPARAÇÕES APENAS DURANTE A EXPLORAÇÃO"
		)
		return false

	var current_health := float(camp_core.get("current_health"))
	var maximum_health := float(camp_core.get("maximum_health"))
	var missing_health := maximum_health - current_health
	if missing_health <= 0.0:
		camp_economy.call(&"request_feedback", "O NÚCLEO JÁ ESTÁ REPARADO")
		return false

	var repair_amount := minf(missing_health, maximum_repair_per_interaction)
	var scrap_cost := ceili(repair_amount / health_per_scrap)
	if not bool(camp_economy.call(&"spend_stored_scrap", scrap_cost)):
		camp_economy.call(
			&"request_feedback", "SCRAP INSUFICIENTE: NECESSÁRIO %d" % scrap_cost
		)
		return false

	var repaired_health := float(camp_core.call(&"repair", repair_amount))
	camp_economy.call(
		&"request_feedback",
		"NÚCLEO REPARADO +%d  •  CUSTO %d SCRAP"
		% [roundi(repaired_health), scrap_cost]
	)
	return repaired_health > 0.0
