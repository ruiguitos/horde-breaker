extends Node

## Survivors-like run level: XP orbs dropped by enemies fill a bar that levels
## up during the run and opens the upgrade card panel. Independent from the
## permanent character level handled by SaveManager/CharacterProgression.

signal run_xp_changed(current_xp: int, required_xp: int, level: int)
signal run_level_gained(level: int, choices: Array)

## The requirement grows quadratically: a purely linear curve let a ten-minute
## run reach level 50, which burned through the whole upgrade pool in one
## sitting. With the quadratic term the same run lands around level 23.
const BASE_XP_REQUIREMENT := 12
const XP_REQUIREMENT_GROWTH := 8
const XP_REQUIREMENT_CURVE := 1.35
const CHOICE_COUNT := 3

var run_level: int = 1
var run_xp: int = 0
var xp_multiplier: float = 1.0
var pickup_radius_multiplier: float = 1.0

var _rng := RandomNumberGenerator.new()
# Which cards were taken, and how many times. RunUpgrades applies an upgrade and
# forgets it, so by level 15 the player had no way to see what they were
# carrying — which is exactly what they need to pick the next card well.
var _taken_upgrades: Dictionary[StringName, int] = {}


func _ready() -> void:
	add_to_group(&"run_progression")
	_rng.randomize()
	run_xp_changed.emit(run_xp, get_required_xp(), run_level)


func get_required_xp() -> int:
	var levels_gained := float(run_level - 1)
	return (
		BASE_XP_REQUIREMENT
		+ XP_REQUIREMENT_GROWTH * (run_level - 1)
		+ roundi(XP_REQUIREMENT_CURVE * levels_gained * levels_gained)
	)


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
	_taken_upgrades[upgrade_id] = int(_taken_upgrades.get(upgrade_id, 0)) + 1


## The run's upgrades, most-taken first, as
## `[{"id", "name", "description", "count"}]`.
func get_taken_upgrades() -> Array[Dictionary]:
	var taken: Array[Dictionary] = []
	for upgrade_id in _taken_upgrades:
		var upgrade := RunUpgrades.get_upgrade(upgrade_id)
		if upgrade.is_empty():
			continue
		taken.append({
			"id": upgrade_id,
			"name": String(upgrade.get("name", String(upgrade_id))),
			"description": String(upgrade.get("description", "")),
			"count": int(_taken_upgrades[upgrade_id]),
		})
	taken.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["count"]) != int(b["count"]):
				return int(a["count"]) > int(b["count"])
			return String(a["name"]) < String(b["name"])
	)
	return taken


func get_taken_upgrade_count() -> int:
	var total := 0
	for count in _taken_upgrades.values():
		total += int(count)
	return total
