class_name RunUpgrades
extends RefCounted

## Survivors-like in-run upgrades: every run level grants a choice of three
## cards. They only last for the current run — permanent progression stays with
## the skill tree, mastery and the armory.

const PLAYER_GROUP := &"player"
const WEAPON_CONTROLLER_GROUP := &"weapon_controller"
const RUN_PROGRESSION_GROUP := &"run_progression"

const UPGRADES: Array[Dictionary] = [
	{
		"id": &"damage",
		"name": "HIGH CALIBER",
		"description": "+20% weapon damage",
	},
	{
		"id": &"fire_rate",
		"name": "RAPID FIRE",
		"description": "+15% fire rate",
	},
	{
		"id": &"max_health",
		"name": "BODY ARMOR",
		"description": "+25 max health, healed instantly",
	},
	{
		"id": &"move_speed",
		"name": "ADRENALINE",
		"description": "+10% movement speed",
	},
	{
		"id": &"reload",
		"name": "FAST HANDS",
		"description": "-20% reload time",
	},
	{
		"id": &"magazine",
		"name": "EXTENDED MAGS",
		"description": "+25% magazine size",
	},
	{
		"id": &"ammo_reserve",
		"name": "BANDOLIER",
		"description": "+30% ammo reserve, topped up now",
	},
	{
		"id": &"pickup_radius",
		"name": "MAGNETIC FIELD",
		"description": "+60% pickup range",
	},
	{
		"id": &"xp_gain",
		"name": "FAST LEARNER",
		"description": "+25% experience gained",
	},
	{
		"id": &"regeneration",
		"name": "FIELD MEDIC",
		"description": "+1 health regenerated per second",
	},
]


static func get_upgrade(upgrade_id: StringName) -> Dictionary:
	for upgrade in UPGRADES:
		if upgrade["id"] == upgrade_id:
			return upgrade
	return {}


static func draw_choices(rng: RandomNumberGenerator, amount: int) -> Array:
	# Distinct random cards, so the player never sees the same option twice.
	var pool := UPGRADES.duplicate()
	var choices: Array = []
	for index in mini(amount, pool.size()):
		var pick := rng.randi_range(0, pool.size() - 1)
		choices.append(pool[pick])
		pool.remove_at(pick)
	return choices


static func apply(upgrade_id: StringName, tree: SceneTree) -> void:
	var player := tree.get_first_node_in_group(PLAYER_GROUP)
	match upgrade_id:
		&"damage":
			_scale_weapons(tree, &"damage", 1.2)
		&"fire_rate":
			_scale_weapons(tree, &"fire_rate", 1.15)
		&"magazine":
			_scale_weapon_int(tree, &"magazine_size", 1.25)
		&"ammo_reserve":
			_add_reserve_capacity(tree, 0.3)
		&"reload":
			_scale_reload(tree, 0.8)
		&"max_health":
			if player != null:
				player.set(
					&"maximum_health", float(player.get(&"maximum_health")) + 25.0
				)
				if player.has_method(&"heal"):
					player.call(&"heal", 25.0)
		&"move_speed":
			if player != null:
				player.set(&"move_speed", float(player.get(&"move_speed")) * 1.1)
				player.set(&"sprint_speed", float(player.get(&"sprint_speed")) * 1.1)
		&"regeneration":
			if player != null:
				player.set(
					&"health_regeneration_rate",
					float(player.get(&"health_regeneration_rate")) + 1.0
				)
		&"pickup_radius":
			var progression := tree.get_first_node_in_group(RUN_PROGRESSION_GROUP)
			if progression != null:
				progression.set(
					&"pickup_radius_multiplier",
					float(progression.get(&"pickup_radius_multiplier")) * 1.6
				)
		&"xp_gain":
			var xp_progression := tree.get_first_node_in_group(RUN_PROGRESSION_GROUP)
			if xp_progression != null:
				xp_progression.set(
					&"xp_multiplier",
					float(xp_progression.get(&"xp_multiplier")) * 1.25
				)


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
