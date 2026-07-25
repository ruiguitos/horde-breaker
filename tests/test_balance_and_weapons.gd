extends SceneTree

## Covers this session's changes: the two-class roster, the Machine Gun and its
## Minigun evolution, the additive/capped ammo reserve and the steeper run XP
## curve.

const RUN_PROGRESSION_PATH := "res://scripts/systems/run_progression.gd"
const MACHINE_GUN_SCENE_PATH := "res://scenes/weapons/machine_gun.tscn"
const MINIGUN_SCENE_PATH := "res://scenes/weapons/minigun.tscn"
const RECRUIT_PATH := "res://data/characters/recruit.tres"
const RENEGADE_PATH := "res://data/characters/renegade.tres"
const MEDIC_PATH := "res://data/characters/medic.tres"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_roster()
	_test_categories()
	_test_machine_gun()
	_test_reserve_capacity()
	_test_xp_curve()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_roster() -> void:
	var recruit: CharacterData = load(RECRUIT_PATH)
	var renegade: CharacterData = load(RENEGADE_PATH)
	var medic: CharacterData = load(MEDIC_PATH)
	_check("roster: recruit selectable", recruit.is_selectable)
	_check("roster: renegade selectable", renegade.is_selectable)
	_check("roster: medic parked", not medic.is_selectable)
	_check("roster: medic data intact", medic.character_scene != null)
	# The Spear was Medic-only; with the Medic parked it has to stay reachable.
	var spear := WeaponCatalog.get_weapon_data(&"spear")
	_check("roster: spear no longer medic-only", spear.required_character_id == &"")
	var recruit_weapons := WeaponCatalog.get_compatible_weapons(&"recruit")
	var recruit_ids: Array[StringName] = []
	for weapon_data in recruit_weapons:
		recruit_ids.append(weapon_data.weapon_id)
	_check("roster: recruit can buy the spear", recruit_ids.has(&"spear"))


func _test_categories() -> void:
	var sections := WeaponCatalog.get_compatible_weapons_by_category(&"recruit")
	_check("categories: every section is used", sections.size() == 5)
	var names: Array[String] = []
	var listed := 0
	for section in sections:
		names.append(String(section["name"]))
		listed += (section["weapons"] as Array).size()
		_check(
			"categories: %s is not empty" % String(section["name"]),
			(section["weapons"] as Array).size() > 0
		)
	_check(
		"categories: in display order",
		names == ["ASSAULT", "SIDEARM", "CLOSE RANGE", "HEAVY", "MELEE"]
	)
	# Shotgun and Worn Sword are Renegade-only, so the Recruit sees fewer than
	# the full catalog; nothing compatible may go missing though.
	var compatible := WeaponCatalog.get_compatible_weapons(&"recruit").size()
	_check(
		"categories: every compatible weapon is listed once (%d of %d)" % [
			listed, compatible
		],
		listed == compatible
	)
	_check(
		"categories: machine gun is heavy",
		WeaponCatalog.get_weapon_data(&"machine_gun").category == &"heavy"
	)


func _test_machine_gun() -> void:
	var data := WeaponCatalog.get_weapon_data(&"machine_gun")
	_check("machine gun: in the catalog", data != null)
	if data == null:
		return
	_check("machine gun: level 6", data.required_level == 6)
	_check("machine gun: 800 credits", data.credit_cost == 800)
	_check("machine gun: playable", data.is_playable)
	var scene: PackedScene = load(MACHINE_GUN_SCENE_PATH)
	var weapon := scene.instantiate() as Node3D
	root.add_child(weapon)
	_check("machine gun: damage 20", is_equal_approx(float(weapon.get(&"damage")), 20.0))
	_check("machine gun: fire rate 14", is_equal_approx(float(weapon.get(&"fire_rate")), 14.0))
	_check("machine gun: magazine 100", int(weapon.get(&"magazine_size")) == 100)
	_check(
		"machine gun: reload 3.5 s",
		is_equal_approx(float(weapon.get(&"reload_duration")), 3.5)
	)
	_check(
		"machine gun: auto-fire 14 m",
		is_equal_approx(float(weapon.get(&"proximity_auto_fire_range")), 14.0)
	)
	_check(
		"machine gun: -15% move speed",
		is_equal_approx(float(weapon.get(&"move_speed_multiplier")), 0.85)
	)
	weapon.queue_free()

	var evolution := WeaponEvolution.get_evolution(&"machine_gun")
	_check("minigun: evolution registered", not evolution.is_empty())
	if evolution.is_empty():
		return
	_check("minigun: 400 kills", int(evolution["kills_required"]) == 400)
	_check("minigun: evolved id", evolution["evolved_id"] == &"minigun")
	_check(
		"minigun: reverse lookup",
		WeaponEvolution.get_base_weapon_id(&"minigun") == &"machine_gun"
	)
	_check(
		"minigun: in the catalog",
		WeaponCatalog.get_weapon_data(&"minigun") != null
	)
	var minigun := (load(MINIGUN_SCENE_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(minigun)
	_check(
		"minigun: outguns the machine gun",
		float(minigun.get(&"damage")) > 20.0
		and float(minigun.get(&"fire_rate")) > 14.0
	)
	minigun.queue_free()
	# Both carry the embedded Rifle mesh, so both need an armory icon.
	_check(
		"machine gun: has an icon",
		UiVisualCatalog.get_weapon_icon(&"machine_gun") != null
	)
	_check(
		"minigun: falls back to the base icon",
		UiVisualCatalog.get_weapon_icon(&"minigun") != null
	)


func _test_reserve_capacity() -> void:
	var weapon := (load(MACHINE_GUN_SCENE_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(weapon)
	var base_capacity := int(weapon.get(&"maximum_reserve_ammunition"))
	_check("reserve: base capacity 600", base_capacity == 600)
	weapon.call(&"add_reserve_capacity", 0.3)
	_check(
		"reserve: one card adds 30% of the base",
		int(weapon.get(&"maximum_reserve_ammunition")) == 780
	)
	_check(
		"reserve: topped up on pickup of the card",
		int(weapon.get(&"reserve_ammunition")) == 780
	)
	# Six cards used to compound to 600 x 1.3^6 = 2661 rounds.
	for index in range(5):
		weapon.call(&"add_reserve_capacity", 0.3)
	_check(
		"reserve: capped at twice the base",
		int(weapon.get(&"maximum_reserve_ammunition")) == 1200
	)
	_check(
		"reserve: pickups still respect the cap",
		int(weapon.call(&"add_ammunition", 5000)) == 0
	)
	weapon.queue_free()


func _test_xp_curve() -> void:
	var progression := Node.new()
	progression.set_script(load(RUN_PROGRESSION_PATH))
	root.add_child(progression)
	_check(
		"xp: level 1 costs 12",
		int(progression.call(&"get_required_xp")) == 12
	)
	var total := 0
	for level in range(1, 50):
		progression.set(&"run_level", level)
		total += int(progression.call(&"get_required_xp"))
	# The old linear curve reached level 50 for ~7550 XP, which a ten-minute run
	# produced. The same budget must now stop in the low twenties.
	progression.set(&"run_level", 1)
	var budget := 7550
	var reached := 1
	var spent := 0
	while reached < 60:
		progression.set(&"run_level", reached)
		var cost := int(progression.call(&"get_required_xp"))
		if spent + cost > budget:
			break
		spent += cost
		reached += 1
	_check(
		"xp: a 7550 XP run lands in the twenties (got %d)" % reached,
		reached >= 20 and reached <= 27
	)
	_check("xp: total to level 50 grew a lot (%d)" % total, total > 40000)
	progression.queue_free()


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
