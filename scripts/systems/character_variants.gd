class_name CharacterVariants
extends RefCounted

## Class variants: modifiers applied on top of the base class at run start.
## They are not separate characters — XP, skill tree, mastery and armory keep
## belonging to the base class. A variant unlocks when every mastery objective
## of its class is completed, and the player toggles it in class selection.

const VARIANTS: Dictionary[StringName, Dictionary] = {
	&"recruit": {
		"name": "VETERAN",
		"description": "Trades the fast reload for +15% fire rate.",
		"reload_multiplier_override": 1.0,
		"fire_rate_mult": 1.15,
		"tint": Color(0.85, 0.72, 0.35, 1.0),
	},
	&"renegade": {
		"name": "BERSERKER",
		"description": "110 max health, but melee hits restore 2 health.",
		"max_health_override": 110.0,
		"melee_lifesteal": 2.0,
		"tint": Color(0.95, 0.3, 0.22, 1.0),
	},
	&"medic": {
		"name": "COMBAT MEDIC",
		"description": "Weaker regeneration, but every kill restores 5 health.",
		"regen_rate_override": 1.5,
		"regen_delay_override": 5.0,
		"heal_on_kill": 5.0,
		"tint": Color(0.3, 0.9, 0.55, 1.0),
	},
}


static func get_variant(class_id: StringName) -> Dictionary:
	return VARIANTS.get(class_id, {})


static func get_variant_name(class_id: StringName) -> String:
	return String(get_variant(class_id).get("name", ""))
