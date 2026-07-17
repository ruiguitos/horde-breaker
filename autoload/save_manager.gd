extends Node

signal credits_changed(credits: int)
signal character_progress_changed(character_id: StringName, level: int, xp: int)
signal weapon_purchased(character_id: StringName, weapon_id: StringName)

const DEFAULT_SAVE_PATH := "user://horde_breaker_save.cfg"
const RECRUIT_ID := &"recruit"
const ASSAULT_RIFLE_ID := &"assault_rifle"
const RECRUIT_DATA: CharacterData = preload("res://data/characters/recruit.tres")

var storage_path: String = DEFAULT_SAVE_PATH
var _config := ConfigFile.new()


func _ready() -> void:
	load_progress()


func load_progress(path_override: String = "") -> void:
	if not path_override.is_empty():
		storage_path = path_override
	_config = ConfigFile.new()
	var load_error := _config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_error("SaveManager could not load the progress file: %s" % load_error)
	var defaults_added := _ensure_defaults()
	if load_error != OK or defaults_added:
		save_progress()


func reload_progress() -> void:
	load_progress(storage_path)


func reset_progress() -> void:
	_config = ConfigFile.new()
	_ensure_defaults()
	save_progress()
	credits_changed.emit(get_credits())
	character_progress_changed.emit(
		RECRUIT_ID, get_character_level(RECRUIT_ID), get_character_xp(RECRUIT_ID)
	)


func save_progress() -> bool:
	var save_error := _config.save(storage_path)
	if save_error != OK:
		push_error("SaveManager could not save player progress: %s" % save_error)
		return false
	return true


func get_credits() -> int:
	return int(_config.get_value("profile", "credits", 0))


func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	var updated_credits := get_credits() + amount
	_config.set_value("profile", "credits", updated_credits)
	save_progress()
	credits_changed.emit(updated_credits)


func get_character_level(character_id: StringName) -> int:
	return int(_config.get_value(String(character_id), "level", 1))


func get_character_xp(character_id: StringName) -> int:
	return int(_config.get_value(String(character_id), "xp", 0))


func get_xp_required_for_next_level(level: int) -> int:
	return 100 + maxi(level - 1, 0) * 50


func add_character_xp(character_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0

	var section := String(character_id)
	var level := get_character_level(character_id)
	var xp := get_character_xp(character_id)
	var maximum_level := _get_maximum_level(character_id)
	var levels_gained := 0
	if level >= maximum_level:
		return levels_gained

	xp += amount
	while level < maximum_level:
		var required_xp := get_xp_required_for_next_level(level)
		if xp < required_xp:
			break
		xp -= required_xp
		level += 1
		levels_gained += 1
	if level >= maximum_level:
		xp = 0

	_config.set_value(section, "level", level)
	_config.set_value(section, "xp", xp)
	save_progress()
	character_progress_changed.emit(character_id, level, xp)
	return levels_gained


func get_purchased_weapons(character_id: StringName) -> PackedStringArray:
	var stored_weapons: Variant = _config.get_value(
		String(character_id), "purchased_weapons", PackedStringArray()
	)
	return PackedStringArray(stored_weapons)


func is_weapon_purchased(character_id: StringName, weapon_id: StringName) -> bool:
	return String(weapon_id) in get_purchased_weapons(character_id)


func meets_weapon_requirements(
	character_id: StringName, weapon_data: WeaponData
) -> bool:
	if weapon_data == null or weapon_data.required_character_id != character_id:
		return false
	return (
		get_character_level(character_id) >= weapon_data.required_level
		and get_credits() >= weapon_data.credit_cost
	)


func can_purchase_weapon(character_id: StringName, weapon_data: WeaponData) -> bool:
	if weapon_data == null:
		return false
	return (
		not is_weapon_purchased(character_id, weapon_data.weapon_id)
		and meets_weapon_requirements(character_id, weapon_data)
	)


func purchase_weapon(character_id: StringName, weapon_data: WeaponData) -> bool:
	if not can_purchase_weapon(character_id, weapon_data):
		return false

	var purchased_weapons := get_purchased_weapons(character_id)
	purchased_weapons.append(String(weapon_data.weapon_id))
	_config.set_value(String(character_id), "purchased_weapons", purchased_weapons)
	_config.set_value("profile", "credits", get_credits() - weapon_data.credit_cost)
	save_progress()
	credits_changed.emit(get_credits())
	weapon_purchased.emit(character_id, weapon_data.weapon_id)
	return true


func get_selected_weapon(character_id: StringName) -> StringName:
	return StringName(
		_config.get_value(String(character_id), "selected_weapon", ASSAULT_RIFLE_ID)
	)


func select_weapon(character_id: StringName, weapon_data: WeaponData) -> bool:
	if (
		weapon_data == null
		or weapon_data.required_character_id != character_id
		or not is_weapon_purchased(character_id, weapon_data.weapon_id)
	):
		return false
	_config.set_value(
		String(character_id), "selected_weapon", String(weapon_data.weapon_id)
	)
	return save_progress()


func _get_maximum_level(character_id: StringName) -> int:
	if character_id == RECRUIT_ID:
		return RECRUIT_DATA.maximum_level
	return 10


func _ensure_defaults() -> bool:
	var defaults_added := false
	defaults_added = _set_default("profile", "credits", 0) or defaults_added
	defaults_added = (
		_set_default("profile", "selected_character", String(RECRUIT_ID))
		or defaults_added
	)
	defaults_added = _set_default(String(RECRUIT_ID), "level", 1) or defaults_added
	defaults_added = _set_default(String(RECRUIT_ID), "xp", 0) or defaults_added
	defaults_added = (
		_set_default(
			String(RECRUIT_ID),
			"purchased_weapons",
			PackedStringArray([String(ASSAULT_RIFLE_ID)])
		)
		or defaults_added
	)
	defaults_added = (
		_set_default(
			String(RECRUIT_ID), "selected_weapon", String(ASSAULT_RIFLE_ID)
		)
		or defaults_added
	)
	return defaults_added


func _set_default(section: String, key: String, value: Variant) -> bool:
	if _config.has_section_key(section, key):
		return false
	_config.set_value(section, key, value)
	return true
