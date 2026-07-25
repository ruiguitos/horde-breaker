class_name WeaponEvolution
extends RefCounted

## Survivors-like weapon evolution: kills scored with a weapon accumulate per
## character and, once the threshold is reached, permanently unlock its evolved
## version in the ARMORY (no Credits needed). The base weapon stays usable.

const EVOLUTIONS: Dictionary[StringName, Dictionary] = {
	&"assault_rifle": {
		"evolved_id": &"storm_rifle",
		"name": "STORM RIFLE",
		"kills_required": 300,
	},
	&"shotgun": {
		"evolved_id": &"siege_breaker",
		"name": "SIEGE BREAKER",
		"kills_required": 250,
	},
	&"smg": {
		"evolved_id": &"hornet",
		"name": "HORNET",
		"kills_required": 350,
	},
	&"machine_gun": {
		"evolved_id": &"minigun",
		"name": "MINIGUN",
		"kills_required": 400,
	},
	&"worn_sword": {
		"evolved_id": &"cleaver",
		"name": "CLEAVER",
		"kills_required": 200,
	},
}


static func get_evolution(base_weapon_id: StringName) -> Dictionary:
	return EVOLUTIONS.get(base_weapon_id, {})


static func has_evolution(base_weapon_id: StringName) -> bool:
	return EVOLUTIONS.has(base_weapon_id)


static func get_base_weapon_id(evolved_weapon_id: StringName) -> StringName:
	for base_id in EVOLUTIONS:
		if EVOLUTIONS[base_id]["evolved_id"] == evolved_weapon_id:
			return base_id
	return &""


static func is_evolved_weapon(weapon_id: StringName) -> bool:
	return get_base_weapon_id(weapon_id) != &""
