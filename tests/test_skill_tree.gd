extends SceneTree

## The permanent skill trees: one per class, three categories each, six nodes a
## category, bought with skill points.
##
## The mechanic is accumulation, not selection — buying a node never takes
## another away, and what shapes a build is that points are scarce. Both halves
## of that are worth guarding, because a bug in either turns the tree into
## something else: a refund would make every choice free, and a node that
## replaced its neighbour would make the tree a menu.
##
## Run:  <godot> --headless --path . --script res://tests/test_skill_tree.gd

const SAVE_PATH := "user://horde_breaker_skill_tree_test.cfg"
const SCREEN_SCENE := "res://scenes/menus/skill_tree_screen.tscn"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_shape()
	_test_effects_are_understood()
	_test_prerequisites()
	_test_bonus_aggregation()
	await _test_spending_points()
	await _test_migration()
	await _test_screen()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_shape() -> void:
	var class_ids := SkillTree.get_class_ids()
	_check("there is a tree per class (%d)" % class_ids.size(), class_ids.size() >= 3)
	var seen_ids: Dictionary[StringName, bool] = {}
	for class_id in class_ids:
		var categories := SkillTree.get_categories(class_id)
		# More than one category is the point: a single column gives a player
		# nothing to choose between when deciding where the next point goes.
		_check(
			"%s has several categories (%d)" % [class_id, categories.size()],
			categories.size() >= 3
		)
		for category in categories:
			_check(
				"%s/%s names itself" % [class_id, category["id"]],
				not String(category["title"]).is_empty()
					and not String(category["tagline"]).is_empty()
			)
			var nodes := SkillTree.get_category_nodes(class_id, category["id"])
			_check(
				"%s/%s has a full chain (%d nodes)" % [
					class_id, category["id"], nodes.size()
				],
				nodes.size() == SkillTree.CATEGORY_SHAPE.size()
			)
			for node in nodes:
				var node_id: StringName = node["id"]
				_check("%s is unique" % node_id, not seen_ids.has(node_id))
				seen_ids[node_id] = true
				_check(
					"%s describes itself" % node_id,
					not String(node["title"]).is_empty()
						and not String(node["description"]).is_empty()
				)
				_check(
					"%s does something" % node_id,
					not (node["effect"] as Dictionary).is_empty()
				)
	var previous := 0
	for tier in range(1, SkillTree.TIER_COUNT + 1):
		var required := SkillTree.get_required_level_for_tier(tier)
		_check(
			"tier %d opens later than the one before (level %d)" % [tier, required],
			required > previous
		)
		previous = required


func _test_effects_are_understood() -> void:
	var unknown: Array[String] = []
	for class_id in SkillTree.get_class_ids():
		for node in SkillTree.get_class_nodes(class_id):
			for stat: StringName in node["effect"]:
				if not SkillTree.DEFAULT_BONUSES.has(stat):
					unknown.append("%s.%s" % [node["id"], stat])
	_check(
		"every effect key is one the game applies: %s" % (
			"yes" if unknown.is_empty() else ", ".join(unknown)
		),
		unknown.is_empty()
	)


func _test_prerequisites() -> void:
	var nodes := SkillTree.get_category_nodes(&"recruit", &"firepower")
	var trunk: StringName = nodes[0]["id"]
	var second: StringName = nodes[1]["id"]
	var fork_left: StringName = nodes[2]["id"]
	var fork_right: StringName = nodes[3]["id"]
	var rejoin: StringName = nodes[4]["id"]

	_check("the way in needs nothing", SkillTree.is_prerequisite_met(trunk, []))
	_check(
		"the second node needs the first",
		not SkillTree.is_prerequisite_met(second, [])
			and SkillTree.is_prerequisite_met(second, [trunk])
	)
	_check(
		"both sides of the fork hang off the same node",
		SkillTree.is_prerequisite_met(fork_left, [trunk, second])
			and SkillTree.is_prerequisite_met(fork_right, [trunk, second])
	)
	# The fork rejoins: either side is enough to carry on, so taking both is an
	# investment rather than a requirement.
	_check(
		"either side of the fork opens what follows",
		SkillTree.is_prerequisite_met(rejoin, [fork_left])
			and SkillTree.is_prerequisite_met(rejoin, [fork_right])
	)
	_check(
		"the fork cannot be skipped",
		not SkillTree.is_prerequisite_met(rejoin, [trunk, second])
	)


func _test_bonus_aggregation() -> void:
	var none := SkillTree.get_bonuses([])
	_check(
		"no skills means no change",
		is_equal_approx(float(none["damage_mult"]), 1.0)
			and is_equal_approx(float(none["max_health_add"]), 0.0)
	)
	var firepower := SkillTree.get_category_nodes(&"recruit", &"firepower")
	var stacked := SkillTree.get_bonuses([firepower[0]["id"], firepower[1]["id"]])
	_check(
		"multipliers compound (%.4f)" % float(stacked["damage_mult"]),
		is_equal_approx(float(stacked["damage_mult"]), 1.06 * 1.08)
	)
	var armour := SkillTree.get_category_nodes(&"renegade", &"armour")
	var health := SkillTree.get_bonuses([armour[0]["id"], armour[2]["id"]])
	_check(
		"flat bonuses add (%.0f)" % float(health["max_health_add"]),
		is_equal_approx(float(health["max_health_add"]), 45.0)
	)
	_check(
		"nodes from an older tree contribute nothing",
		is_equal_approx(
			float(SkillTree.get_bonuses([&"off_1", &"rec_1a"])["damage_mult"]), 1.0
		)
	)
	var everything: Array = []
	for node in SkillTree.get_class_nodes(&"renegade"):
		everything.append(node["id"])
	_check(
		"damage reduction stays capped even with the whole tree (%.2f)"
			% float(SkillTree.get_bonuses(everything)["damage_reduction"]),
		float(SkillTree.get_bonuses(everything)["damage_reduction"]) <= 0.75
	)


func _test_spending_points() -> void:
	var save := root.get_node_or_null("/root/SaveManager")
	_check("the save manager is available", save != null)
	if save == null:
		return
	DirAccess.remove_absolute(SAVE_PATH)
	save.call(&"load_progress", SAVE_PATH)
	var nodes := SkillTree.get_category_nodes(&"recruit", &"firepower")
	var trunk: StringName = nodes[0]["id"]
	var second: StringName = nodes[1]["id"]

	_check(
		"nothing can be bought at level 1",
		not bool(save.call(&"can_unlock_skill_node", &"recruit", trunk))
	)

	save.call(&"add_character_xp", &"recruit", 100000)
	var level := int(save.call(&"get_character_level", &"recruit"))
	_check("the operative levelled for the test (%d)" % level, level >= 20)
	var points := int(save.call(&"get_available_skill_points", &"recruit"))
	_check("points accrue with levels (%d)" % points, points >= 10)

	_check(
		"the way in can be bought",
		bool(save.call(&"can_unlock_skill_node", &"recruit", trunk))
	)
	# Prerequisites hold even with points in hand.
	_check(
		"the second node is shut until the first is owned",
		not bool(save.call(&"can_unlock_skill_node", &"recruit", second))
	)
	_check("buying works", bool(save.call(&"unlock_skill_node", &"recruit", trunk)))
	_check(
		"a point was spent (%d left)"
			% int(save.call(&"get_available_skill_points", &"recruit")),
		int(save.call(&"get_available_skill_points", &"recruit")) == points - 1
	)
	_check(
		"the second node opens once the first is owned",
		bool(save.call(&"can_unlock_skill_node", &"recruit", second))
	)

	# The heart of it: this is an upgrade tree, not a choice. Buying the next
	# node must leave the previous one owned.
	save.call(&"unlock_skill_node", &"recruit", second)
	_check(
		"skills accumulate rather than replace each other",
		bool(save.call(&"is_skill_node_unlocked", &"recruit", trunk))
			and bool(save.call(&"is_skill_node_unlocked", &"recruit", second))
	)
	_check(
		"buying the same node twice is refused",
		not bool(save.call(&"unlock_skill_node", &"recruit", trunk))
	)
	_check(
		"a class cannot buy another class's skills",
		not bool(save.call(
			&"unlock_skill_node", &"recruit",
			SkillTree.get_category_nodes(&"renegade", &"armour")[0]["id"]
		))
	)

	var bonuses: Dictionary = save.call(&"get_skill_bonuses", &"recruit")
	_check(
		"the save feeds the bonuses the run reads (%.4f)" % float(bonuses["damage_mult"]),
		is_equal_approx(float(bonuses["damage_mult"]), 1.06 * 1.08)
	)
	await process_frame


## Profiles from either earlier shape of the tree — the shared 36-node one and
## the five-tier choice one — carry ids that no longer exist. They are dropped,
## and because a dropped node is also an unspent point the profile is left able
## to rebuild rather than stranded.
func _test_migration() -> void:
	var save := root.get_node_or_null("/root/SaveManager")
	if save == null:
		return
	DirAccess.remove_absolute(SAVE_PATH)
	save.call(&"load_progress", SAVE_PATH)
	save.call(&"add_character_xp", &"recruit", 100000)
	var valid: StringName = SkillTree.get_category_nodes(
		&"recruit", &"firepower"
	)[0]["id"]
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("recruit", "skill_nodes", PackedStringArray([
		"off_1", "sur_2b", "rec_1a", "renegade_armour_1", String(valid),
	]))
	config.save(SAVE_PATH)
	save.call(&"load_progress", SAVE_PATH)

	var unlocked: PackedStringArray = save.call(
		&"get_unlocked_skill_nodes", &"recruit"
	)
	_check(
		"stale and foreign nodes are dropped, the valid one kept (%s)" % str(unlocked),
		unlocked.size() == 1 and unlocked[0] == String(valid)
	)
	var earned := int(save.call(&"get_earned_skill_points", &"recruit"))
	_check(
		"the points those nodes cost come back (%d of %d spent)" % [
			earned - int(save.call(&"get_available_skill_points", &"recruit")), earned
		],
		int(save.call(&"get_available_skill_points", &"recruit")) == earned - 1
	)
	await process_frame


func _test_screen() -> void:
	var save := root.get_node_or_null("/root/SaveManager")
	if save == null:
		return
	DirAccess.remove_absolute(SAVE_PATH)
	save.call(&"load_progress", SAVE_PATH)
	save.call(&"select_character", &"recruit")
	save.call(&"add_character_xp", &"recruit", 100000)
	if change_scene_to_file(SCREEN_SCENE) != OK:
		_check("the skill screen loads", false)
		return
	await scene_changed
	for _frame in 8:
		await process_frame

	var buttons := _find_nodes(current_scene)
	var expected := SkillTree.get_class_nodes(&"recruit").size()
	_check(
		"a hit area per skill of the class (%d of %d)" % [buttons.size(), expected],
		buttons.size() == expected
	)
	var canvas: SkillTreeCanvas = current_scene.get(&"_canvas")
	_check("the tree is drawn on a canvas", canvas != null)
	if canvas != null:
		_check(
			"one drawn column per category (%d)" % canvas.columns.size(),
			canvas.columns.size() == SkillTree.get_categories(&"recruit").size()
		)

	var trunk: StringName = SkillTree.get_category_nodes(
		&"recruit", &"firepower"
	)[0]["id"]
	var button := buttons.get(trunk) as Button
	_check("the way in has a hit area", button != null)
	if button == null:
		return
	# Spending is permanent, so the click asks first and nothing is spent until
	# the dialog is answered.
	button.emit_signal(&"pressed")
	await process_frame
	var dialog: ConfirmationDialog = current_scene.get(&"_confirm_dialog")
	_check("clicking asks first", dialog != null and dialog.visible)
	_check(
		"nothing is spent before confirming",
		not bool(save.call(&"is_skill_node_unlocked", &"recruit", trunk))
	)
	if dialog != null:
		dialog.emit_signal(&"confirmed")
		await process_frame
		_check(
			"confirming spends the point",
			bool(save.call(&"is_skill_node_unlocked", &"recruit", trunk))
		)


func _find_nodes(node: Node) -> Dictionary:
	var found: Dictionary = {}
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and not SkillTree.get_node_definition(
			StringName(button.name)
		).is_empty():
			found[StringName(button.name)] = button
	return found


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
