class_name WeaponCatalog
extends RefCounted

const ASSAULT_RIFLE: WeaponData = preload("res://data/weapons/assault_rifle.tres")
const PISTOL: WeaponData = preload("res://data/weapons/pistol.tres")
const SHOTGUN: WeaponData = preload("res://data/weapons/shotgun.tres")
const WORN_SWORD: WeaponData = preload("res://data/weapons/worn_sword.tres")
const SPEAR: WeaponData = preload("res://data/weapons/spear.tres")
const SMG: WeaponData = preload("res://data/weapons/smg.tres")
const FIRE_AXE: WeaponData = preload("res://data/weapons/fire_axe.tres")
const STORM_RIFLE: WeaponData = preload("res://data/weapons/storm_rifle.tres")
const SIEGE_BREAKER: WeaponData = preload("res://data/weapons/siege_breaker.tres")
const HORNET: WeaponData = preload("res://data/weapons/hornet.tres")
const CLEAVER: WeaponData = preload("res://data/weapons/cleaver.tres")
const MACHINE_GUN: WeaponData = preload("res://data/weapons/machine_gun.tres")
const MINIGUN: WeaponData = preload("res://data/weapons/minigun.tres")

const ALL_WEAPONS: Array[WeaponData] = [
	ASSAULT_RIFLE,
	PISTOL,
	SHOTGUN,
	SMG,
	MACHINE_GUN,
	WORN_SWORD,
	SPEAR,
	FIRE_AXE,
	STORM_RIFLE,
	SIEGE_BREAKER,
	HORNET,
	CLEAVER,
	MINIGUN,
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
