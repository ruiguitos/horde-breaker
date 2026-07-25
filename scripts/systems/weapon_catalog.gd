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


## Armory sections, in display order. A weapon whose category matches none of
## these falls into the last group.
const CATEGORIES: Array[Dictionary] = [
	{"id": &"assault", "name": "ASSAULT"},
	{"id": &"sidearm", "name": "SIDEARM"},
	{"id": &"close_range", "name": "CLOSE RANGE"},
	{"id": &"heavy", "name": "HEAVY"},
	{"id": &"melee", "name": "MELEE"},
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


static func get_compatible_weapons_by_category(
	character_id: StringName
) -> Array[Dictionary]:
	# One entry per non-empty section, already in CATEGORIES order, so the
	# armory can lay itself out without knowing the category rules.
	var by_category: Dictionary[StringName, Array] = {}
	var last_category: StringName = CATEGORIES[CATEGORIES.size() - 1]["id"]
	for weapon_data in get_compatible_weapons(character_id):
		if not weapon_data.is_playable:
			continue
		var category := weapon_data.category
		if not _has_category(category):
			category = last_category
		if not by_category.has(category):
			by_category[category] = []
		by_category[category].append(weapon_data)
	var sections: Array[Dictionary] = []
	for category in CATEGORIES:
		var category_id: StringName = category["id"]
		if by_category.has(category_id):
			sections.append({
				"name": String(category["name"]),
				"weapons": by_category[category_id],
			})
	return sections


static func _has_category(category_id: StringName) -> bool:
	for category in CATEGORIES:
		if category["id"] == category_id:
			return true
	return false
