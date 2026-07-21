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


func _on_enemy_defeated(xp_reward: int) -> void:
	if xp_reward <= 0:
		return
	var boosted := roundi(xp_reward * _xp_multiplier)
	session_xp += boosted
	SaveManager.add_character_xp(_character_id, boosted)
	session_progress_changed.emit(session_xp, session_credits)


func _on_wave_completed(wave_number: int) -> void:
	var xp_reward := roundi(wave_xp_multiplier * wave_number * _xp_multiplier)
	session_xp += xp_reward
	SaveManager.add_character_xp(_character_id, xp_reward)
	session_progress_changed.emit(session_xp, session_credits)


func _on_cycle_completed(_cycle_number: int) -> void:
	session_credits += cycle_credit_reward
	SaveManager.add_credits(cycle_credit_reward)
	session_progress_changed.emit(session_xp, session_credits)
