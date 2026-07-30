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

const WAVE_MANAGER_GROUP := &"wave_manager"
const PLAYER_GROUP := &"player"

var run_level: int = 1
var run_xp: int = 0
var xp_multiplier: float = 1.0
var pickup_radius_multiplier: float = 1.0
## Fraction of maximum health restored per kill, granted by VAMPIRIC ROUNDS.
var lifesteal_per_kill: float = 0.0

var _rng := RandomNumberGenerator.new()
# Which cards were taken, and how many times. The count is the upgrade's level:
# RunUpgrades applies an upgrade and forgets it, so by level 15 the player had no
# way to see what they were carrying — which is exactly what they need to pick
# the next card well.
var _taken_upgrades: Dictionary[StringName, int] = {}


func _ready() -> void:
	add_to_group(&"run_progression")
	_rng.randomize()
	run_xp_changed.emit(run_xp, get_required_xp(), run_level)
	call_deferred(&"_connect_wave_manager")


func _connect_wave_manager() -> void:
	# Lifesteal hangs off the director's kill report rather than off the enemies
	# themselves: it already fires for both horde and exploration kills, and it
	# survives enemies being freed.
	var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
	if wave_manager == null or not wave_manager.has_signal(&"enemy_defeated"):
		return
	if not wave_manager.is_connected(&"enemy_defeated", _on_enemy_defeated):
		wave_manager.connect(&"enemy_defeated", _on_enemy_defeated)


func _on_enemy_defeated(_xp_reward: int) -> void:
	if lifesteal_per_kill <= 0.0:
		return
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null or not player.has_method(&"heal"):
		return
	var healed := float(player.get(&"maximum_health")) * lifesteal_per_kill
	if healed > 0.0:
		player.call(&"heal", healed)


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
		run_level_gained.emit(run_level, draw_choices())
	run_xp_changed.emit(run_xp, get_required_xp(), run_level)
	return gained


## The cards offered for one level, weighted by rarity and skipping anything the
## player has already taken to its maximum level.
func draw_choices() -> Array:
	return RunUpgrades.draw_choices(_rng, CHOICE_COUNT, _taken_upgrades)


## The level the player holds in an upgrade, 0 if they have never taken it.
func get_upgrade_level(upgrade_id: StringName) -> int:
	return int(_taken_upgrades.get(upgrade_id, 0))


func apply_upgrade(upgrade_id: StringName) -> void:
	if get_upgrade_level(upgrade_id) >= RunUpgrades.get_max_level(upgrade_id):
		return
	RunUpgrades.apply(upgrade_id, get_tree())
	_taken_upgrades[upgrade_id] = get_upgrade_level(upgrade_id) + 1


## The run's upgrades, highest level first, as
## `[{"id", "name", "effect", "level", "max_level", "rarity", "colour"}]`.
func get_taken_upgrades() -> Array[Dictionary]:
	var taken: Array[Dictionary] = []
	for upgrade_id in _taken_upgrades:
		var upgrade := RunUpgrades.get_upgrade(upgrade_id)
		if upgrade.is_empty():
			continue
		var rarity := RunUpgrades.get_rarity(upgrade_id)
		taken.append({
			"id": upgrade_id,
			"name": String(upgrade.get("name", String(upgrade_id))),
			"effect": String(upgrade.get("effect", "")),
			"level": int(_taken_upgrades[upgrade_id]),
			"max_level": RunUpgrades.get_max_level(upgrade_id),
			"rarity": String(rarity["name"]),
			"colour": rarity["colour"],
		})
	taken.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["level"]) != int(b["level"]):
				return int(a["level"]) > int(b["level"])
			return String(a["name"]) < String(b["name"])
	)
	return taken


func get_taken_upgrade_count() -> int:
	var total := 0
	for count in _taken_upgrades.values():
		total += int(count)
	return total
