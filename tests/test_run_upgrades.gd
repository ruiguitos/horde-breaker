extends SceneTree

## Field upgrades have rarity and levels. Rarity is fixed per upgrade and decides
## both how often a card is offered and how much one level of it is worth; taking
## a card again raises its level until it caps out, at which point it stops being
## offered so the pool keeps turning over.
##
## What this covers is the machinery around that: the draw honours the weights,
## never offers a maxed card, never offers the same card twice in one hand, and
## the levels are capped where they say they are. Plus the two things a player
## would notice immediately if they broke — the legendary lifesteal healing on a
## kill, and the level-up panel picking for you when the ten seconds run out.
##
## Run:  <godot> --headless --path . --script res://tests/test_run_upgrades.gd

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"
## Enough draws that a weight this lopsided cannot pass by luck.
const DRAW_SAMPLES := 400

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_catalogue()
	_test_draw_weighting()
	_test_maxed_cards_leave_the_pool()
	await _test_in_the_arena()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_catalogue() -> void:
	_check("the catalogue is not empty", not RunUpgrades.UPGRADES.is_empty())
	var rarities_used: Dictionary = {}
	var missing: Array[String] = []
	for upgrade in RunUpgrades.UPGRADES:
		var upgrade_id: StringName = upgrade["id"]
		if not upgrade.has("rarity") or not upgrade.has("value") or not upgrade.has("effect"):
			missing.append(String(upgrade_id))
			continue
		if not RunUpgrades.RARITIES.has(upgrade["rarity"]):
			missing.append("%s (unknown rarity)" % upgrade_id)
			continue
		rarities_used[upgrade["rarity"]] = true
		_check(
			"%s caps somewhere sensible (%d)" % [
				upgrade_id, RunUpgrades.get_max_level(upgrade_id)
			],
			RunUpgrades.get_max_level(upgrade_id) >= 1
				and RunUpgrades.get_max_level(upgrade_id) <= RunUpgrades.MAX_LEVEL
		)
	_check(
		"every card carries a rarity, a value and an effect: %s" % (
			"yes" if missing.is_empty() else ", ".join(missing)
		),
		missing.is_empty()
	)
	# A rarity nobody uses is a rarity the player never learns to read.
	_check(
		"all five rarities are in use (%d of %d)" % [
			rarities_used.size(), RunUpgrades.RARITIES.size()
		],
		rarities_used.size() == RunUpgrades.RARITIES.size()
	)
	_check(
		"the legendary lifesteal card exists",
		RunUpgrades.get_upgrade(&"lifesteal").get("rarity", &"") == &"legendary"
	)


func _test_draw_weighting() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260730
	var seen_by_rarity: Dictionary = {}
	var duplicate_hands := 0
	for sample in DRAW_SAMPLES:
		var choices := RunUpgrades.draw_choices(rng, 3, {})
		var ids: Dictionary = {}
		for choice in choices:
			var upgrade_id: StringName = choice["id"]
			if ids.has(upgrade_id):
				duplicate_hands += 1
			ids[upgrade_id] = true
			var rarity := String(RunUpgrades.get_rarity(upgrade_id)["name"])
			seen_by_rarity[rarity] = int(seen_by_rarity.get(rarity, 0)) + 1
	_check("a hand never repeats a card (%d)" % duplicate_hands, duplicate_hands == 0)
	var bronze := int(seen_by_rarity.get("BRONZE", 0))
	var legendary := int(seen_by_rarity.get("LEGENDARY", 0))
	_check(
		"bronze cards are common (%d in %d hands)" % [bronze, DRAW_SAMPLES],
		bronze > legendary
	)
	# Rare, but not so rare the card may as well not exist.
	_check(
		"legendary cards are rare but reachable (%d in %d hands)" % [
			legendary, DRAW_SAMPLES
		],
		legendary > 0 and legendary < bronze / 4
	)


func _test_maxed_cards_leave_the_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Max out everything but two cards; the draw can then only return those.
	var levels: Dictionary[StringName, int] = {}
	var spared: Array[StringName] = []
	for upgrade in RunUpgrades.UPGRADES:
		var upgrade_id: StringName = upgrade["id"]
		if spared.size() < 2:
			spared.append(upgrade_id)
			continue
		levels[upgrade_id] = RunUpgrades.get_max_level(upgrade_id)
	var choices := RunUpgrades.draw_choices(rng, 3, levels)
	_check(
		"a hand cannot offer more cards than remain (%d)" % choices.size(),
		choices.size() == spared.size()
	)
	var only_spared := true
	for choice in choices:
		if StringName(choice["id"]) not in spared:
			only_spared = false
	_check("maxed cards are never offered again", only_spared)


func _test_in_the_arena() -> void:
	if change_scene_to_file(ARENA_SCENE) != OK:
		_check("arena loads", false)
		return
	await scene_changed
	for _frame in 60:
		await process_frame

	var progression := get_first_node_in_group(&"run_progression")
	_check("run progression is present", progression != null)
	if progression == null:
		return

	# Levels stop where the catalogue says they do, however many times the card
	# is taken. Without the cap a long run could pour every pick into one stat.
	var maximum := RunUpgrades.get_max_level(&"lifesteal")
	for attempt in maximum + 3:
		progression.call(&"apply_upgrade", &"lifesteal")
	_check(
		"a card stops at its maximum level (%d of %d)" % [
			int(progression.call(&"get_upgrade_level", &"lifesteal")), maximum
		],
		int(progression.call(&"get_upgrade_level", &"lifesteal")) == maximum
	)

	var player := get_first_node_in_group(&"player")
	_check("the player is present", player != null)
	if player != null:
		var maximum_health := float(player.get(&"maximum_health"))
		player.set(&"current_health", maximum_health * 0.5)
		var before := float(player.get(&"current_health"))
		var wave_manager := get_first_node_in_group(&"wave_manager")
		_check("the wave director reports kills", wave_manager != null
			and wave_manager.has_signal(&"enemy_defeated"))
		if wave_manager != null:
			wave_manager.emit_signal(&"enemy_defeated", 10)
			await process_frame
			var after := float(player.get(&"current_health"))
			var expected := maximum_health * float(
				RunUpgrades.get_upgrade(&"lifesteal")["value"]
			) * maximum
			_check(
				"a kill heals with vampiric rounds (%.1f -> %.1f, expected +%.1f)" % [
					before, after, expected
				],
				after > before and is_equal_approx(after - before, expected)
			)

	await _test_auto_pick(progression)


func _test_auto_pick(progression: Node) -> void:
	var panel := current_scene.find_child("UpgradeChoicePanel", true, false)
	_check("the level-up panel is present", panel != null)
	if panel == null:
		return
	var taken_before := int(progression.call(&"get_taken_upgrade_count"))
	progression.emit_signal(
		&"run_level_gained", 2, progression.call(&"draw_choices")
	)
	await process_frame
	_check("a level opens the panel", bool(panel.get(&"visible")))
	# Constants are not properties, so the limit is read off the script itself.
	var limit := float(panel.get_script().get(&"AUTO_PICK_SECONDS"))
	var remaining := float(panel.get(&"_time_left"))
	_check(
		"the countdown starts at %.0f s (%.2f left)" % [limit, remaining],
		limit > 0.0 and remaining > limit - 0.5 and remaining <= limit
	)

	# Run the clock out. The panel processes while the tree is paused, which is
	# the whole point of it being PROCESS_MODE_ALWAYS.
	panel.set(&"_time_left", 0.05)
	for _frame in 20:
		await process_frame
	_check(
		"the countdown picks a card on its own (%d -> %d)" % [
			taken_before, int(progression.call(&"get_taken_upgrade_count"))
		],
		int(progression.call(&"get_taken_upgrade_count")) > taken_before
	)
	_check("the panel closes after picking", not bool(panel.get(&"visible")))
	_check("the run resumes", not paused)


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
