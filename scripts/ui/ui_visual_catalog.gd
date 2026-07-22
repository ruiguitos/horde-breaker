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
	&"worn_sword": preload("res://assets/icons/weapon_worn_sword.png"),
	&"spear": preload("res://assets/icons/weapon_spear.png"),
}


static func get_character_icon(character_id: StringName) -> Texture2D:
	return CHARACTER_ICONS.get(character_id) as Texture2D


static func get_weapon_icon(weapon_id: StringName) -> Texture2D:
	return WEAPON_ICONS.get(weapon_id) as Texture2D
