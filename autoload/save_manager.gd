extends Node

signal credits_changed(credits: int)
signal character_progress_changed(character_id: StringName, level: int, xp: int)
signal character_purchased(character_id: StringName)
signal selected_character_changed(character_id: StringName)
signal weapon_purchased(character_id: StringName, weapon_id: StringName)
signal selected_weapon_changed(character_id: StringName, weapon_id: StringName)
signal selected_loadout_changed(
	character_id: StringName,
	primary_weapon_id: StringName,
	secondary_weapon_id: StringName
)
signal skill_points_changed(character_id: StringName)
signal mastery_progress_changed(character_id: StringName, objective_id: StringName)
signal mastery_completed(character_id: StringName, objective_id: StringName)
signal variant_changed(character_id: StringName)

const DEFAULT_SAVE_PATH := "user://horde_breaker_save.cfg"
const RECRUIT_ID := &"recruit"
const RENEGADE_ID := &"renegade"
const MEDIC_ID := &"medic"
const ASSAULT_RIFLE_ID := &"assault_rifle"
const PISTOL_ID := &"pistol"
const SHOTGUN_ID := &"shotgun"
const WORN_SWORD_ID := &"worn_sword"
const SPEAR_ID := &"spear"
const RECRUIT_DATA: CharacterData = preload("res://data/characters/recruit.tres")
const RENEGADE_DATA: CharacterData = preload("res://data/characters/renegade.tres")
const MEDIC_DATA: CharacterData = preload("res://data/characters/medic.tres")

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
	character_progress_changed.emit(
		RENEGADE_ID, get_character_level(RENEGADE_ID), get_character_xp(RENEGADE_ID)
	)
	character_progress_changed.emit(
		MEDIC_ID, get_character_level(MEDIC_ID), get_character_xp(MEDIC_ID)
	)
	selected_character_changed.emit(get_selected_character())


func save_progress() -> bool:
	var save_error := _config.save(storage_path)
	if save_error != OK:
		push_error("SaveManager could not save player progress: %s" % save_error)
		return false
	return true


func get_world_seed() -> int:
	return int(_config.get_value("world", "seed", 0))


func ensure_world_seed() -> int:
	# The world layout is fixed per profile: the first run draws the seed and
	# every later run reuses it, so sector layouts stay familiar. Loot state is
	# intentionally per-run. Zero means "not drawn yet".
	var world_seed := get_world_seed()
	if world_seed == 0:
		world_seed = (randi() & 0x7FFFFFFF) | 1
		_config.set_value("world", "seed", world_seed)
		save_progress()
	return world_seed


func get_visited_sector_coords() -> Array:
	return Array(_config.get_value("world", "visited_sectors", []))


func mark_sector_visited(coords: Vector2i) -> void:
	var visited := get_visited_sector_coords()
	if coords in visited:
		return
	visited.append(coords)
	_config.set_value("world", "visited_sectors", visited)
	save_progress()


func is_east_beacon_activated() -> bool:
	return bool(_config.get_value("world", "east_beacon_activated", false))


func set_east_beacon_activated() -> void:
	if is_east_beacon_activated():
		return
	_config.set_value("world", "east_beacon_activated", true)
	save_progress()


func get_credits() -> int:
	return int(_config.get_value("profile", "credits", 0))


func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	var updated_credits := get_credits() + amount
	_config.set_value("profile", "credits", updated_credits)
	save_progress()
	credits_changed.emit(updated_credits)


func get_selected_character() -> StringName:
	return StringName(
		_config.get_value("profile", "selected_character", String(RECRUIT_ID))
	)


func is_character_unlocked(character_id: StringName) -> bool:
	return bool(_config.get_value(String(character_id), "unlocked", false))


func can_purchase_character(character_data: CharacterData) -> bool:
	if character_data == null:
		return false
	return (
		not is_character_unlocked(character_data.character_id)
		and get_credits() >= character_data.unlock_cost
	)


func purchase_character(character_data: CharacterData) -> bool:
	if not can_purchase_character(character_data):
		return false

	_config.set_value(String(character_data.character_id), "unlocked", true)
	_config.set_value("profile", "credits", get_credits() - character_data.unlock_cost)
	if not save_progress():
		return false
	credits_changed.emit(get_credits())
	character_purchased.emit(character_data.character_id)
	return true


func select_character(character_id: StringName) -> bool:
	if not is_character_unlocked(character_id):
		return false
	_config.set_value("profile", "selected_character", String(character_id))
	if not save_progress():
		return false
	selected_character_changed.emit(character_id)
	return true


func get_character_level(character_id: StringName) -> int:
	return int(_config.get_value(String(character_id), "level", 1))


func get_character_xp(character_id: StringName) -> int:
	return int(_config.get_value(String(character_id), "xp", 0))


func get_xp_required_for_next_level(level: int) -> int:
	return 100 + maxi(level - 1, 0) * 50


func add_character_xp(character_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0

	# Characters level up without a cap. Skill points are derived from the
	# resulting level and are awarded every two levels.
	var section := String(character_id)
	var level := get_character_level(character_id)
	var xp := get_character_xp(character_id)
	var levels_gained := 0

	xp += amount
	while true:
		var required_xp := get_xp_required_for_next_level(level)
		if xp < required_xp:
			break
		xp -= required_xp
		level += 1
		levels_gained += 1

	_config.set_value(section, "level", level)
	_config.set_value(section, "xp", xp)
	save_progress()
	character_progress_changed.emit(character_id, level, xp)
	if levels_gained > 0:
		skill_points_changed.emit(character_id)
	return levels_gained


func get_earned_skill_points(character_id: StringName) -> int:
	# Levels 2, 4, 6... each grant one permanent point.
	return floori(float(get_character_level(character_id)) / 2.0)


func get_next_skill_point_level(character_id: StringName) -> int:
	return (get_earned_skill_points(character_id) + 1) * 2


func get_unlocked_skill_nodes(character_id: StringName) -> PackedStringArray:
	var stored: Variant = _config.get_value(
		String(character_id), "skill_nodes", PackedStringArray()
	)
	return PackedStringArray(stored)


func get_available_skill_points(character_id: StringName) -> int:
	# Existing profiles keep every unlocked node. If an older profile spent more
	# points than the new cadence grants, it simply earns no new point until its
	# level catches up; the UI must never display a negative value.
	return maxi(
		get_earned_skill_points(character_id)
		- get_unlocked_skill_nodes(character_id).size(),
		0
	)


func is_skill_node_unlocked(character_id: StringName, node_id: StringName) -> bool:
	return String(node_id) in get_unlocked_skill_nodes(character_id)


func can_unlock_skill_node(character_id: StringName, node_id: StringName) -> bool:
	var node_definition := SkillTree.get_node_definition(node_id)
	if (
		node_definition.is_empty()
		or is_skill_node_unlocked(character_id, node_id)
		or get_available_skill_points(character_id) <= 0
		or get_character_level(character_id) < SkillTree.get_required_level(node_id)
	):
		return false
	var prerequisite := SkillTree.get_prerequisite_id(node_id)
	return (
		prerequisite == &""
		or is_skill_node_unlocked(character_id, prerequisite)
	)


func unlock_skill_node(character_id: StringName, node_id: StringName) -> bool:
	if not can_unlock_skill_node(character_id, node_id):
		return false
	var unlocked := get_unlocked_skill_nodes(character_id)
	unlocked.append(String(node_id))
	_config.set_value(String(character_id), "skill_nodes", unlocked)
	if not save_progress():
		return false
	skill_points_changed.emit(character_id)
	return true


func get_skill_bonuses(character_id: StringName) -> Dictionary:
	return SkillTree.get_bonuses(Array(get_unlocked_skill_nodes(character_id)))


func get_mastery_progress(character_id: StringName, objective_id: StringName) -> int:
	return int(
		_config.get_value(String(character_id), "mastery_%s" % objective_id, 0)
	)


func is_mastery_completed(character_id: StringName, objective_id: StringName) -> bool:
	var objective := CharacterMastery.get_objective(objective_id)
	if objective.is_empty():
		return false
	return get_mastery_progress(character_id, objective_id) >= int(objective["goal"])


func record_mastery_progress(
	character_id: StringName, objective_id: StringName, amount: int
) -> void:
	var objective := CharacterMastery.get_objective(objective_id)
	if objective.is_empty() or amount <= 0:
		return
	var was_completed := is_mastery_completed(character_id, objective_id)
	var progress := get_mastery_progress(character_id, objective_id)
	if bool(objective["track_highest"]):
		if amount <= progress:
			return
		progress = amount
	else:
		progress += amount
	progress = mini(progress, int(objective["goal"]))
	_config.set_value(String(character_id), "mastery_%s" % objective_id, progress)
	save_progress()
	mastery_progress_changed.emit(character_id, objective_id)
	# The clamp keeps completed objectives at their goal, so the reward can
	# only ever be paid on the crossing call.
	if not was_completed and progress >= int(objective["goal"]):
		add_credits(int(objective["reward_credits"]))
		mastery_completed.emit(character_id, objective_id)


func is_variant_unlocked(character_id: StringName) -> bool:
	# The class variant is the mastery capstone: it unlocks only when every
	# objective of that class is completed.
	if CharacterVariants.get_variant(character_id).is_empty():
		return false
	for objective_id in CharacterMastery.OBJECTIVES:
		if not is_mastery_completed(character_id, objective_id):
			return false
	return true


func is_variant_active(character_id: StringName) -> bool:
	return (
		is_variant_unlocked(character_id)
		and bool(_config.get_value(String(character_id), "variant_active", false))
	)


func set_variant_active(character_id: StringName, active: bool) -> bool:
	if active and not is_variant_unlocked(character_id):
		return false
	_config.set_value(String(character_id), "variant_active", active)
	if not save_progress():
		return false
	variant_changed.emit(character_id)
	return true


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
	if weapon_data == null:
		return false
	if (
		weapon_data.required_character_id != &""
		and weapon_data.required_character_id != character_id
	):
		return false
	return (
		get_character_level(character_id) >= weapon_data.required_level
		and get_credits() >= weapon_data.credit_cost
	)


func can_purchase_weapon(character_id: StringName, weapon_data: WeaponData) -> bool:
	if weapon_data == null:
		return false
	return (
		is_character_unlocked(character_id)
		and weapon_data.is_playable
		and not is_weapon_purchased(character_id, weapon_data.weapon_id)
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
	return get_primary_weapon(character_id)


func get_primary_weapon(character_id: StringName) -> StringName:
	var character_data := get_character_data(character_id)
	if character_data == null:
		return &""
	return StringName(
		_config.get_value(
			String(character_id),
			"selected_primary_weapon",
			String(character_data.primary_weapon_id)
		)
	)


func get_secondary_weapon(character_id: StringName) -> StringName:
	var character_data := get_character_data(character_id)
	if character_data == null:
		return &""
	return StringName(
		_config.get_value(
			String(character_id),
			"selected_secondary_weapon",
			String(character_data.secondary_weapon_id)
		)
	)


func select_weapon(character_id: StringName, weapon_data: WeaponData) -> bool:
	return select_weapon_for_slot(character_id, weapon_data, &"primary")


func select_weapon_for_slot(
	character_id: StringName, weapon_data: WeaponData, slot: StringName
) -> bool:
	if (
		weapon_data == null
		or slot not in [&"primary", &"secondary"]
		or not is_character_unlocked(character_id)
		or (
			weapon_data.required_character_id != &""
			and weapon_data.required_character_id != character_id
		)
		or not weapon_data.is_playable
		or not is_weapon_purchased(character_id, weapon_data.weapon_id)
	):
		return false
	var primary_weapon_id := get_primary_weapon(character_id)
	var secondary_weapon_id := get_secondary_weapon(character_id)
	if slot == &"primary":
		if primary_weapon_id == weapon_data.weapon_id:
			return true
		if secondary_weapon_id == weapon_data.weapon_id:
			secondary_weapon_id = primary_weapon_id
		primary_weapon_id = weapon_data.weapon_id
	else:
		if secondary_weapon_id == weapon_data.weapon_id:
			return true
		if primary_weapon_id == weapon_data.weapon_id:
			primary_weapon_id = secondary_weapon_id
		secondary_weapon_id = weapon_data.weapon_id
	_config.set_value(
		String(character_id), "selected_primary_weapon", String(primary_weapon_id)
	)
	_config.set_value(
		String(character_id), "selected_secondary_weapon", String(secondary_weapon_id)
	)
	if not save_progress():
		return false
	selected_weapon_changed.emit(character_id, weapon_data.weapon_id)
	selected_loadout_changed.emit(character_id, primary_weapon_id, secondary_weapon_id)
	return true


func get_character_data(character_id: StringName) -> CharacterData:
	if character_id == RECRUIT_ID:
		return RECRUIT_DATA
	if character_id == RENEGADE_ID:
		return RENEGADE_DATA
	if character_id == MEDIC_ID:
		return MEDIC_DATA
	return null


func _get_maximum_level(character_id: StringName) -> int:
	var character_data := get_character_data(character_id)
	return character_data.maximum_level if character_data != null else 10


func _ensure_defaults() -> bool:
	var defaults_added := false
	defaults_added = _set_default("profile", "credits", 0) or defaults_added
	defaults_added = (
		_set_default("profile", "selected_character", String(RECRUIT_ID))
		or defaults_added
	)
	defaults_added = _set_default(String(RECRUIT_ID), "unlocked", true) or defaults_added
	defaults_added = _set_default(String(RECRUIT_ID), "level", 1) or defaults_added
	defaults_added = _set_default(String(RECRUIT_ID), "xp", 0) or defaults_added
	defaults_added = (
		_set_default(
			String(RECRUIT_ID),
			"purchased_weapons",
			PackedStringArray([String(ASSAULT_RIFLE_ID), String(PISTOL_ID)])
		)
		or defaults_added
	)
	defaults_added = (
		_set_default(
			String(RECRUIT_ID),
			"selected_primary_weapon",
			String(ASSAULT_RIFLE_ID)
		)
		or defaults_added
	)
	defaults_added = (
		_set_default(
			String(RECRUIT_ID), "selected_secondary_weapon", String(PISTOL_ID)
		)
		or defaults_added
	)
	defaults_added = _set_default(String(RENEGADE_ID), "unlocked", false) or defaults_added
	defaults_added = _set_default(String(RENEGADE_ID), "level", 1) or defaults_added
	defaults_added = _set_default(String(RENEGADE_ID), "xp", 0) or defaults_added
	defaults_added = (
		_set_default(
			String(RENEGADE_ID),
			"purchased_weapons",
			PackedStringArray([String(SHOTGUN_ID), String(WORN_SWORD_ID)])
		)
		or defaults_added
	)
	defaults_added = (
		_set_default(
			String(RENEGADE_ID), "selected_primary_weapon", String(SHOTGUN_ID)
		)
		or defaults_added
	)
	defaults_added = (
		_set_default(
			String(RENEGADE_ID), "selected_secondary_weapon", String(WORN_SWORD_ID)
		)
		or defaults_added
	)
	defaults_added = _set_default(String(MEDIC_ID), "unlocked", false) or defaults_added
	defaults_added = _set_default(String(MEDIC_ID), "level", 1) or defaults_added
	defaults_added = _set_default(String(MEDIC_ID), "xp", 0) or defaults_added
	defaults_added = (
		_set_default(
			String(MEDIC_ID),
			"purchased_weapons",
			PackedStringArray([String(PISTOL_ID), String(SPEAR_ID)])
		)
		or defaults_added
	)
	defaults_added = (
		_set_default(
			String(MEDIC_ID), "selected_primary_weapon", String(PISTOL_ID)
		)
		or defaults_added
	)
	defaults_added = (
		_set_default(String(MEDIC_ID), "selected_secondary_weapon", String(SPEAR_ID))
		or defaults_added
	)
	# Migrate the former empty/experimental Medic slot to the Spear without
	# changing any other loadout choice already stored by a later profile.
	if String(
		_config.get_value(String(MEDIC_ID), "selected_secondary_weapon", "")
	) in ["", "revolver"]:
		_config.set_value(String(MEDIC_ID), "selected_secondary_weapon", String(SPEAR_ID))
		defaults_added = true
	defaults_added = (
		_ensure_purchased_weapons(
			RECRUIT_ID, PackedStringArray([String(ASSAULT_RIFLE_ID), String(PISTOL_ID)])
		)
		or defaults_added
	)
	defaults_added = (
		_ensure_purchased_weapons(
			RENEGADE_ID, PackedStringArray([String(SHOTGUN_ID), String(WORN_SWORD_ID)])
		)
		or defaults_added
	)
	defaults_added = (
		_ensure_purchased_weapons(
			MEDIC_ID, PackedStringArray([String(PISTOL_ID), String(SPEAR_ID)])
		)
		or defaults_added
	)
	return defaults_added


func _ensure_purchased_weapons(
	character_id: StringName, required_weapons: PackedStringArray
) -> bool:
	var purchased_weapons := get_purchased_weapons(character_id)
	var changed := false
	for weapon_id in required_weapons:
		if weapon_id in purchased_weapons:
			continue
		purchased_weapons.append(weapon_id)
		changed = true
	if changed:
		_config.set_value(String(character_id), "purchased_weapons", purchased_weapons)
	return changed


func _set_default(section: String, key: String, value: Variant) -> bool:
	if _config.has_section_key(section, key):
		return false
	_config.set_value(section, key, value)
	return true
