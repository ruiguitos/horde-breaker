class_name WeaponCatalog
extends RefCounted

const ASSAULT_RIFLE: WeaponData = preload("res://data/weapons/assault_rifle.tres")
const PISTOL: WeaponData = preload("res://data/weapons/pistol.tres")
const SHOTGUN: WeaponData = preload("res://data/weapons/shotgun.tres")
const WORN_SWORD: WeaponData = preload("res://data/weapons/worn_sword.tres")
const SPEAR: WeaponData = preload("res://data/weapons/spear.tres")

const ALL_WEAPONS: Array[WeaponData] = [
	ASSAULT_RIFLE,
	PISTOL,
	SHOTGUN,
	WORN_SWORD,
	SPEAR,
]


static func get_weapon_data(weapon_id: StringName) -> WeaponData:
	for weapon_data in ALL_WEAPONS:
		if weapon_data.weapon_id == weapon_id:
			return weapon_data
	return null


static func get_compatible_weapons(character_id: StringName) -> Array[WeaponData]:
	var compatible: Array[WeaponData] = []
	for weapon_data in ALL_WEAPONS:
		if (
			weapon_data.required_character_id == &""
			or weapon_data.required_character_id == character_id
		):
			compatible.append(weapon_data)
	return compatible
