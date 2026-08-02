class_name UiVisualCatalog
extends RefCounted

const CHARACTER_ICONS := {
	&"recruit": preload("res://assets/icons/class_recruit.png"),
	&"renegade": preload("res://assets/icons/class_renegade.png"),
	&"medic": preload("res://assets/icons/class_medic.png"),
}
## One colour per class, shared by every screen that shows a class: selection,
## the skill tree and the ARMORY. Kept here rather than per screen so the colour
## a player learns to associate with an operative never changes between pages.
## Chosen by role, not by taste — red closes distance, blue holds it, green keeps
## you alive.
const CHARACTER_COLORS := {
	&"recruit": Color(0.42, 0.68, 0.95, 1.0),
	&"renegade": Color(0.93, 0.42, 0.36, 1.0),
	&"medic": Color(0.44, 0.82, 0.59, 1.0),
}
const DEFAULT_CHARACTER_COLOR := Color(0.957, 0.694, 0.31, 1.0)

const WEAPON_ICONS := {
	&"assault_rifle": preload("res://assets/icons/weapon_assault_rifle.png"),
	&"pistol": preload("res://assets/icons/weapon_pistol.png"),
	&"shotgun": preload("res://assets/icons/weapon_shotgun.png"),
	&"smg": preload("res://assets/icons/weapon_smg.png"),
	# The Machine Gun carries the same embedded Rifle mesh the rifle icon was
	# rendered from.
	&"machine_gun": preload("res://assets/icons/weapon_assault_rifle.png"),
}


static func get_character_icon(character_id: StringName) -> Texture2D:
	return CHARACTER_ICONS.get(character_id) as Texture2D


static func get_character_color(character_id: StringName) -> Color:
	return CHARACTER_COLORS.get(character_id, DEFAULT_CHARACTER_COLOR)


static func get_weapon_icon(weapon_id: StringName) -> Texture2D:
	var icon := WEAPON_ICONS.get(weapon_id) as Texture2D
	if icon != null:
		return icon
	# Evolved weapons fall back to their base weapon's icon: they share the
	# embedded mesh every icon was generated from.
	return WEAPON_ICONS.get(
		WeaponEvolution.get_base_weapon_id(weapon_id)
	) as Texture2D
