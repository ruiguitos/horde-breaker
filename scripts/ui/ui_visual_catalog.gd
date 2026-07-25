class_name UiVisualCatalog
extends RefCounted

const CHARACTER_ICONS := {
	&"recruit": preload("res://assets/icons/class_recruit.png"),
	&"renegade": preload("res://assets/icons/class_renegade.png"),
	&"medic": preload("res://assets/icons/class_medic.png"),
}
const WEAPON_ICONS := {
	&"assault_rifle": preload("res://assets/icons/weapon_assault_rifle.png"),
	&"pistol": preload("res://assets/icons/weapon_pistol.png"),
	&"shotgun": preload("res://assets/icons/weapon_shotgun.png"),
	&"smg": preload("res://assets/icons/weapon_smg.png"),
	# The Machine Gun carries the same embedded Rifle mesh the rifle icon was
	# rendered from.
	&"machine_gun": preload("res://assets/icons/weapon_assault_rifle.png"),
	&"worn_sword": preload("res://assets/icons/weapon_worn_sword.png"),
	&"spear": preload("res://assets/icons/weapon_spear.png"),
	&"fire_axe": preload("res://assets/icons/weapon_fire_axe.png"),
}


static func get_character_icon(character_id: StringName) -> Texture2D:
	return CHARACTER_ICONS.get(character_id) as Texture2D


static func get_weapon_icon(weapon_id: StringName) -> Texture2D:
	var icon := WEAPON_ICONS.get(weapon_id) as Texture2D
	if icon != null:
		return icon
	# Evolved weapons fall back to their base weapon's icon: they share the
	# embedded mesh every icon was generated from.
	return WEAPON_ICONS.get(
		WeaponEvolution.get_base_weapon_id(weapon_id)
	) as Texture2D
