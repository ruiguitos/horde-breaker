class_name RunUpgrades
extends RefCounted

## Survivors-like in-run upgrades: every run level grants a choice of three
## cards. They only last for the current run — permanent progression stays with
## the skill tree, mastery and the armory.
##
## Each upgrade has a **rarity** and **levels**. Rarity is fixed per upgrade, not
## rolled per card: EXTENDED MAGS is always bronze and VAMPIRIC ROUNDS is always
## legendary, so a name always means the same thing. It decides two things — how
## often the card is offered, and how much one level of it is worth. Taking a
## card the player already holds raises its level; at MAX_LEVEL the card stops
## being offered, which keeps the pool turning over instead of letting one
## upgrade absorb every pick of a long run.

const PLAYER_GROUP := &"player"
const WEAPON_CONTROLLER_GROUP := &"weapon_controller"
const RUN_PROGRESSION_GROUP := &"run_progression"

## How high a card can be stacked. Overridden per upgrade where the effect is
## strong enough that five levels of it would end the balancing conversation.
const MAX_LEVEL := 5

## Weights are relative, not percentages: a bronze card is about twenty times
## likelier to be offered than a legendary one. Colours are used by the card
## panel and by the pause summary, so a rarity reads the same everywhere.
const RARITIES: Dictionary[StringName, Dictionary] = {
	&"bronze": {
		"name": "BRONZE", "weight": 1.0, "colour": Color(0.80, 0.55, 0.34),
	},
	&"silver": {
		"name": "SILVER", "weight": 0.62, "colour": Color(0.78, 0.82, 0.87),
	},
	&"gold": {
		"name": "GOLD", "weight": 0.34, "colour": Color(0.96, 0.76, 0.26),
	},
	&"epic": {
		"name": "EPIC", "weight": 0.15, "colour": Color(0.69, 0.47, 0.96),
	},
	&"legendary": {
		"name": "LEGENDARY", "weight": 0.045, "colour": Color(1.0, 0.45, 0.20),
	},
}
const DEFAULT_RARITY := &"bronze"

## `value` is what one level is worth; `effect` is how that reads on the card.
## The magnitudes are the ones the game already shipped with — the rarities were
## fitted to them rather than the other way round, so this change alters how
## often a card appears and how far it stacks, not how strong a single pick is.
const UPGRADES: Array[Dictionary] = [
	{
		"id": &"magazine",
		"name": "EXTENDED MAGS",
		"rarity": &"bronze",
		"value": 0.25,
		"effect": "+25% magazine size",
	},
	{
		"id": &"reload",
		"name": "FAST HANDS",
		"rarity": &"bronze",
		"value": 0.2,
		"effect": "-20% reload time",
	},
	{
		"id": &"ammo_reserve",
		"name": "BANDOLIER",
		"rarity": &"silver",
		"value": 0.3,
		"effect": "+30% ammo reserve, topped up now",
	},
	{
		"id": &"pickup_radius",
		"name": "MAGNETIC FIELD",
		"rarity": &"silver",
		"value": 0.6,
		"effect": "+60% pickup range",
	},
	{
		"id": &"xp_gain",
		"name": "FAST LEARNER",
		"rarity": &"silver",
		"value": 0.25,
		"effect": "+25% experience gained",
	},
	{
		"id": &"damage",
		"name": "HIGH CALIBER",
		"rarity": &"gold",
		"value": 0.2,
		"effect": "+20% weapon damage",
	},
	{
		"id": &"fire_rate",
		"name": "RAPID FIRE",
		"rarity": &"gold",
		"value": 0.15,
		"effect": "+15% fire rate",
	},
	{
		"id": &"max_health",
		"name": "BODY ARMOR",
		"rarity": &"gold",
		"value": 25.0,
		"effect": "+25 max health, healed instantly",
	},
	{
		"id": &"move_speed",
		"name": "ADRENALINE",
		"rarity": &"epic",
		"value": 0.1,
		"effect": "+10% movement speed",
	},
	{
		"id": &"regeneration",
		"name": "FIELD MEDIC",
		"rarity": &"epic",
		"value": 1.0,
		"effect": "+1 health regenerated per second",
	},
	{
		# The one card that changes how a run is played rather than how fast the
		# numbers go up: with it, pushing into the horde heals instead of costing.
		# Capped at three levels because 6% of a big health pool per kill already
		# outruns anything the horde can do.
		"id": &"lifesteal",
		"name": "VAMPIRIC ROUNDS",
		"rarity": &"legendary",
		"value": 0.02,
		"max_level": 3,
		"effect": "each kill restores 2% of max health",
	},
]


static func get_upgrade(upgrade_id: StringName) -> Dictionary:
	for upgrade in UPGRADES:
		if upgrade["id"] == upgrade_id:
			return upgrade
	return {}


static func get_max_level(upgrade_id: StringName) -> int:
	var upgrade := get_upgrade(upgrade_id)
	return int(upgrade.get("max_level", MAX_LEVEL)) if not upgrade.is_empty() else 0


## The rarity record for an upgrade, as `{name, weight, colour}`.
static func get_rarity(upgrade_id: StringName) -> Dictionary:
	var upgrade := get_upgrade(upgrade_id)
	var rarity_id: StringName = upgrade.get("rarity", DEFAULT_RARITY)
	return RARITIES.get(rarity_id, RARITIES[DEFAULT_RARITY])


## Three distinct cards, weighted by rarity, skipping anything already at its
## maximum level. `levels` maps upgrade id to the level the player holds.
static func draw_choices(
	rng: RandomNumberGenerator, amount: int, levels: Dictionary = {}
) -> Array:
	var pool: Array = []
	for upgrade in UPGRADES:
		var upgrade_id: StringName = upgrade["id"]
		if int(levels.get(upgrade_id, 0)) >= get_max_level(upgrade_id):
			continue
		pool.append(upgrade)

	var choices: Array = []
	for index in mini(amount, pool.size()):
		var total_weight := 0.0
		for upgrade in pool:
			total_weight += float(get_rarity(upgrade["id"])["weight"])
		var pick := rng.randf() * total_weight
		var chosen := pool.size() - 1
		for pool_index in pool.size():
			pick -= float(get_rarity(pool[pool_index]["id"])["weight"])
			if pick <= 0.0:
				chosen = pool_index
				break
		choices.append(pool[chosen])
		pool.remove_at(chosen)
	return choices


## Applies one level of an upgrade. Every level is worth the same, so this needs
## no knowledge of which level it is — the caller caps the count.
static func apply(upgrade_id: StringName, tree: SceneTree) -> void:
	var upgrade := get_upgrade(upgrade_id)
	if upgrade.is_empty():
		push_error("Unknown run upgrade '%s'." % upgrade_id)
		return
	var value := float(upgrade["value"])
	var player := tree.get_first_node_in_group(PLAYER_GROUP)
	match upgrade_id:
		&"damage":
			_scale_weapons(tree, &"damage", 1.0 + value)
		&"fire_rate":
			_scale_weapons(tree, &"fire_rate", 1.0 + value)
		&"magazine":
			_scale_weapon_int(tree, &"magazine_size", 1.0 + value)
		&"ammo_reserve":
			_add_reserve_capacity(tree, value)
		&"reload":
			_scale_reload(tree, 1.0 - value)
		&"max_health":
			if player != null:
				player.set(
					&"maximum_health", float(player.get(&"maximum_health")) + value
				)
				if player.has_method(&"heal"):
					player.call(&"heal", value)
		&"move_speed":
			if player != null:
				player.set(
					&"move_speed", float(player.get(&"move_speed")) * (1.0 + value)
				)
				player.set(
					&"sprint_speed", float(player.get(&"sprint_speed")) * (1.0 + value)
				)
		&"regeneration":
			if player != null:
				player.set(
					&"health_regeneration_rate",
					float(player.get(&"health_regeneration_rate")) + value
				)
		&"pickup_radius":
			_scale_progression(tree, &"pickup_radius_multiplier", 1.0 + value)
		&"xp_gain":
			_scale_progression(tree, &"xp_multiplier", 1.0 + value)
		&"lifesteal":
			# Additive, not multiplicative: the run progression node reads this
			# when the wave director reports a kill.
			var progression := tree.get_first_node_in_group(RUN_PROGRESSION_GROUP)
			if progression != null:
				progression.set(
					&"lifesteal_per_kill",
					float(progression.get(&"lifesteal_per_kill")) + value
				)


static func _scale_progression(
	tree: SceneTree, property: StringName, multiplier: float
) -> void:
	var progression := tree.get_first_node_in_group(RUN_PROGRESSION_GROUP)
	if progression != null:
		progression.set(property, float(progression.get(property)) * multiplier)


static func _get_weapons(tree: SceneTree) -> Array:
	var controller := tree.get_first_node_in_group(WEAPON_CONTROLLER_GROUP)
	if controller == null or not controller.has_method(&"get_loadout_weapons"):
		return []
	return controller.call(&"get_loadout_weapons")


static func _scale_weapons(
	tree: SceneTree, property: StringName, multiplier: float
) -> void:
	for weapon in _get_weapons(tree):
		var value: Variant = weapon.get(property)
		if value != null:
			weapon.set(property, float(value) * multiplier)


static func _scale_weapon_int(
	tree: SceneTree, property: StringName, multiplier: float
) -> void:
	for weapon in _get_weapons(tree):
		var value: Variant = weapon.get(property)
		if value != null:
			weapon.set(property, ceili(int(value) * multiplier))


static func _add_reserve_capacity(tree: SceneTree, ratio: float) -> void:
	for weapon in _get_weapons(tree):
		if weapon.has_method(&"add_reserve_capacity"):
			weapon.call(&"add_reserve_capacity", ratio)


static func _scale_reload(tree: SceneTree, multiplier: float) -> void:
	for weapon in _get_weapons(tree):
		if (
			weapon.has_method(&"set_reload_duration_multiplier")
			and weapon.has_method(&"get_reload_duration_multiplier")
		):
			weapon.call(
				&"set_reload_duration_multiplier",
				float(weapon.call(&"get_reload_duration_multiplier")) * multiplier
			)
