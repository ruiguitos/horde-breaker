extends Node

signal session_progress_changed(session_xp: int, session_credits: int)

@export_range(0, 1000, 1) var wave_xp_multiplier: int = 20
@export_range(0, 10000, 1) var cycle_credit_reward: int = 100

var session_xp: int = 0
var session_credits: int = 0
var _character_id: StringName
var _xp_multiplier: float = 1.0


func _ready() -> void:
	_character_id = SaveManager.get_selected_character()
	_xp_multiplier = float(
		SaveManager.get_skill_bonuses(_character_id).get("xp_mult", 1.0)
	)
	var wave_manager := get_tree().get_first_node_in_group(&"wave_manager")
	if wave_manager == null:
		push_error("CharacterProgression requires a node in the wave_manager group.")
		return
	wave_manager.connect(&"enemy_defeated", _on_enemy_defeated)
	wave_manager.connect(&"wave_completed", _on_wave_completed)
	wave_manager.connect(&"cycle_completed", _on_cycle_completed)
	SaveManager.mastery_completed.connect(_on_mastery_completed)
	SaveManager.weapon_evolved.connect(_on_weapon_evolved)


func _on_enemy_defeated(xp_reward: int) -> void:
	if xp_reward <= 0:
		return
	var boosted := roundi(xp_reward * _xp_multiplier)
	session_xp += boosted
	SaveManager.add_character_xp(_character_id, boosted)
	SaveManager.record_mastery_progress(_character_id, &"kills_100", 1)
	_record_weapon_kill()
	session_progress_changed.emit(session_xp, session_credits)


func _record_weapon_kill() -> void:
	# Credit the kill to whatever weapon is in hand right now.
	var controller := get_tree().get_first_node_in_group(&"weapon_controller")
	if controller == null or not controller.has_method(&"get_active_weapon"):
		return
	var weapon: Node = controller.call(&"get_active_weapon")
	if weapon == null:
		return
	SaveManager.record_weapon_kill(
		_character_id, StringName(weapon.get(&"weapon_id"))
	)


func _on_wave_completed(wave_number: int) -> void:
	var xp_reward := roundi(wave_xp_multiplier * wave_number * _xp_multiplier)
	session_xp += xp_reward
	SaveManager.add_character_xp(_character_id, xp_reward)
	SaveManager.record_mastery_progress(_character_id, &"threat_5", wave_number)
	session_progress_changed.emit(session_xp, session_credits)


func _on_mastery_completed(
	character_id: StringName, objective_id: StringName
) -> void:
	if character_id != _character_id:
		return
	var objective := CharacterMastery.get_objective(objective_id)
	var camp_economy := get_tree().get_first_node_in_group(&"camp_economy")
	if camp_economy != null and camp_economy.has_method(&"request_feedback"):
		camp_economy.call(
			&"request_feedback",
			"MASTERY COMPLETE: %s  •  +%d CREDITS" % [
				String(objective.get("name", "")),
				int(objective.get("reward_credits", 0)),
			],
			4.0
		)


func _on_cycle_completed(_cycle_number: int) -> void:
	session_credits += cycle_credit_reward
	SaveManager.add_credits(cycle_credit_reward)
	session_progress_changed.emit(session_xp, session_credits)


func _on_weapon_evolved(
	character_id: StringName, evolved_weapon_id: StringName
) -> void:
	if character_id != _character_id:
		return
	var weapon_data := WeaponCatalog.get_weapon_data(evolved_weapon_id)
	var weapon_name := (
		weapon_data.display_name.to_upper() if weapon_data != null
		else String(evolved_weapon_id)
	)
	var camp_economy := get_tree().get_first_node_in_group(&"camp_economy")
	if camp_economy != null and camp_economy.has_method(&"request_feedback"):
		camp_economy.call(
			&"request_feedback",
			"WEAPON EVOLVED: %s  •  READY IN THE ARMORY" % weapon_name,
			4.5
		)
