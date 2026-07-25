extends Node

## Survivors-like run level: XP orbs dropped by enemies fill a bar that levels
## up during the run and opens the upgrade card panel. Independent from the
## permanent character level handled by SaveManager/CharacterProgression.

signal run_xp_changed(current_xp: int, required_xp: int, level: int)
signal run_level_gained(level: int, choices: Array)

const BASE_XP_REQUIREMENT := 10
const XP_REQUIREMENT_GROWTH := 6
const CHOICE_COUNT := 3

var run_level: int = 1
var run_xp: int = 0
var xp_multiplier: float = 1.0
var pickup_radius_multiplier: float = 1.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"run_progression")
	_rng.randomize()
	run_xp_changed.emit(run_xp, get_required_xp(), run_level)


func get_required_xp() -> int:
	return BASE_XP_REQUIREMENT + XP_REQUIREMENT_GROWTH * (run_level - 1)


func add_run_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var gained := maxi(roundi(amount * xp_multiplier), 1)
	run_xp += gained
	while run_xp >= get_required_xp():
		run_xp -= get_required_xp()
		run_level += 1
		run_level_gained.emit(run_level, RunUpgrades.draw_choices(_rng, CHOICE_COUNT))
	run_xp_changed.emit(run_xp, get_required_xp(), run_level)
	return gained


func apply_upgrade(upgrade_id: StringName) -> void:
	RunUpgrades.apply(upgrade_id, get_tree())
