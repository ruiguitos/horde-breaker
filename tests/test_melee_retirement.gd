extends Node

const TEST_SAVE_PATH := "user://horde_breaker_melee_retirement_test.cfg"
const RETIRED_IDS := [&"worn_sword", &"cleaver", &"spear", &"fire_axe"]

var _passed := 0
var _failed := 0
var _save_manager: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_write_legacy_save()
	_save_manager = get_node_or_null("/root/SaveManager")
	if _save_manager == null:
		_failed += 1
		print("TEST FAIL: SaveManager autoload is unavailable")
		_finish()
		return
	_save_manager.call(&"load_progress", TEST_SAVE_PATH)

	for weapon_id in RETIRED_IDS:
		_check(
			"catalog: %s is retired" % weapon_id,
			WeaponCatalog.get_weapon_data(weapon_id) == null
		)
	_check(
		"evolution: the sword path is retired",
		WeaponEvolution.get_evolution(&"worn_sword").is_empty()
	)
	_check(
		"migration: Recruit falls back to Pistol",
		_save_manager.call(&"get_secondary_weapon", &"recruit") == &"pistol"
	)
	_check(
		"migration: Renegade becomes Shotgun + SMG",
		_save_manager.call(&"get_primary_weapon", &"renegade") == &"shotgun"
		and _save_manager.call(&"get_secondary_weapon", &"renegade") == &"smg"
	)
	_check(
		"migration: Medic becomes Pistol + SMG",
		_save_manager.call(&"get_primary_weapon", &"medic") == &"pistol"
		and _save_manager.call(&"get_secondary_weapon", &"medic") == &"smg"
	)
	for character_id in [&"recruit", &"renegade", &"medic"]:
		var purchased: PackedStringArray = _save_manager.call(
			&"get_purchased_weapons", character_id
		)
		var has_retired := false
		for weapon_id in RETIRED_IDS:
			if String(weapon_id) in purchased:
				has_retired = true
		_check(
			"migration: %s owns no retired weapon" % character_id,
			not has_retired
		)
	_check(
		"migration: historical sword kills are preserved",
		_save_manager.call(&"get_weapon_kills", &"renegade", &"worn_sword") == 123
	)

	var berserker := CharacterVariants.get_variant(&"renegade")
	_check(
		"variant: Berserker no longer depends on melee",
		not berserker.has("melee_lifesteal")
		and is_equal_approx(float(berserker.get("damage_mult", 1.0)), 1.20)
	)

	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _write_legacy_save() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "selected_character", "renegade")
	config.set_value(
		"recruit",
		"purchased_weapons",
		PackedStringArray(["assault_rifle", "pistol", "fire_axe"])
	)
	config.set_value("recruit", "selected_primary_weapon", "assault_rifle")
	config.set_value("recruit", "selected_secondary_weapon", "fire_axe")
	config.set_value(
		"renegade",
		"purchased_weapons",
		PackedStringArray(["shotgun", "worn_sword", "cleaver"])
	)
	config.set_value("renegade", "selected_primary_weapon", "worn_sword")
	config.set_value("renegade", "selected_secondary_weapon", "shotgun")
	config.set_value("renegade", "kills_worn_sword", 123)
	config.set_value(
		"medic",
		"purchased_weapons",
		PackedStringArray(["pistol", "spear"])
	)
	config.set_value("medic", "selected_primary_weapon", "pistol")
	config.set_value("medic", "selected_secondary_weapon", "spear")
	var save_error := config.save(TEST_SAVE_PATH)
	if save_error != OK:
		_failed += 1
		print("TEST FAIL: could not create legacy save (%s)" % save_error)


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
