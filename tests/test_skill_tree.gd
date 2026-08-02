extends SceneTree

## The permanent skill trees: one per class, five tiers, two options each.
##
## The shape carries most of the design, so most of this checks the shape holds —
## every tier really is a choice, taking one side drops the other, and a tier the
## character has not levelled into cannot be touched. The rest covers the two
## things that would silently do nothing if they broke: effect keys the bonus
## aggregator does not know about, and the migration off the old 36-node tree.
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
	_test_bonus_aggregation()
	await _test_save_choices()
	await _test_migration_from_the_old_tree()
	await _test_screen()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_shape() -> void:
	var class_ids := SkillTree.get_class_ids()
	_check("there is a tree per class (%d)" % class_ids.size(), class_ids.size() >= 3)
	var seen_ids: Dictionary[StringName, bool] = {}
	for class_id in class_ids:
		var tree := SkillTree.get_class_tree(class_id)
		_check("%s has a title" % class_id, not String(tree.get("title", "")).is_empty())
		_check(
			"%s has a tagline saying what it is for" % class_id,
			not String(tree.get("tagline", "")).is_empty()
		)
		for tier in range(1, SkillTree.TIER_COUNT + 1):
			var options := SkillTree.get_tier_options(class_id, tier)
			# Two is the whole point: one option is not a decision, three is a
			# menu nobody reads.
			_check(
				"%s tier %d offers exactly two options (%d)" % [
					class_id, tier, options.size()
				],
				options.size() == 2
			)
			for option: Dictionary in options:
				var node_id: StringName = option["id"]
				_check("%s is unique" % node_id, not seen_ids.has(node_id))
				seen_ids[node_id] = true
				_check(
					"%s describes itself" % node_id,
					not String(option.get("title", "")).is_empty()
						and not String(option.get("description", "")).is_empty()
				)
				_check(
					"%s actually does something" % node_id,
					not (option.get("effect", {}) as Dictionary).is_empty()
				)
	# Tiers have to open at rising levels or the ordering means nothing.
	var previous := 0
	for tier in range(1, SkillTree.TIER_COUNT + 1):
		var required := SkillTree.get_required_level_for_tier(tier)
		_check(
			"tier %d opens later than the one before (level %d)" % [tier, required],
			required > previous
		)
		previous = required


## Any effect key the aggregator does not know about is silently ignored, which
## would make a skill look real on screen and do nothing in the run.
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


func _test_bonus_aggregation() -> void:
	var none := SkillTree.get_bonuses([])
	_check(
		"no choices means no change",
		is_equal_approx(float(none["damage_mult"]), 1.0)
			and is_equal_approx(float(none["max_health_add"]), 0.0)
	)
	# rec_1a is +8% damage, rec_5a another +20%: multipliers compound.
	var stacked := SkillTree.get_bonuses([&"rec_1a", &"rec_5a"])
	_check(
		"multipliers compound (%.3f)" % float(stacked["damage_mult"]),
		is_equal_approx(float(stacked["damage_mult"]), 1.08 * 1.20)
	)
	# ren_1a is +30 health, ren_5a another +60: flat bonuses add.
	var health := SkillTree.get_bonuses([&"ren_1a", &"ren_5a"])
	_check(
		"flat bonuses add (%.0f)" % float(health["max_health_add"]),
		is_equal_approx(float(health["max_health_add"]), 90.0)
	)
	# A tier-5 pick that costs something has to actually cost it.
	var berserker := SkillTree.get_bonuses([&"ren_5b"])
	_check(
		"a downside is applied, not dropped (%.0f health)"
			% float(berserker["max_health_add"]),
		float(berserker["max_health_add"]) < 0.0
	)
	var unknown := SkillTree.get_bonuses([&"off_1", &"not_a_node"])
	_check(
		"nodes from the old tree contribute nothing",
		is_equal_approx(float(unknown["damage_mult"]), 1.0)
	)
	# Damage reduction is the one stat that could reach immortality by stacking.
	var capped := SkillTree.get_bonuses([&"ren_2a", &"ren_5a", &"med_4a"])
	_check(
		"damage reduction stays capped (%.2f)" % float(capped["damage_reduction"]),
		float(capped["damage_reduction"]) <= 0.75
	)


func _test_save_choices() -> void:
	var save := root.get_node_or_null("/root/SaveManager")
	_check("the save manager is available", save != null)
	if save == null:
		return
	DirAccess.remove_absolute(SAVE_PATH)
	save.call(&"load_progress", SAVE_PATH)

	# Level 1: nothing is open yet.
	_check(
		"tier 1 is shut before its level",
		not bool(save.call(&"can_choose_skill_node", &"recruit", &"rec_1a"))
	)
	_check(
		"a shut tier cannot be taken anyway",
		not bool(save.call(&"set_skill_choice", &"recruit", &"rec_1a"))
	)

	save.call(&"add_character_xp", &"recruit", 100000)
	var level := int(save.call(&"get_character_level", &"recruit"))
	_check("the operative levelled up for the test (%d)" % level, level >= 20)
	_check(
		"tier 1 opens once levelled",
		bool(save.call(&"can_choose_skill_node", &"recruit", &"rec_1a"))
	)
	_check(
		"five tiers are waiting to be picked (%d)"
			% int(save.call(&"get_pending_skill_choices", &"recruit")),
		int(save.call(&"get_pending_skill_choices", &"recruit")) == SkillTree.TIER_COUNT
	)

	_check("taking a skill works", bool(save.call(&"set_skill_choice", &"recruit", &"rec_1a")))
	_check(
		"it is recorded",
		bool(save.call(&"is_skill_node_chosen", &"recruit", &"rec_1a"))
	)
	_check(
		"one fewer choice is waiting (%d)"
			% int(save.call(&"get_pending_skill_choices", &"recruit")),
		int(save.call(&"get_pending_skill_choices", &"recruit")) == SkillTree.TIER_COUNT - 1
	)

	# The rule that makes a tier a decision: taking one side drops the other.
	save.call(&"set_skill_choice", &"recruit", &"rec_1b")
	_check(
		"taking the other side drops the first",
		bool(save.call(&"is_skill_node_chosen", &"recruit", &"rec_1b"))
			and not bool(save.call(&"is_skill_node_chosen", &"recruit", &"rec_1a"))
	)
	_check(
		"the tier still counts as chosen",
		int(save.call(&"get_pending_skill_choices", &"recruit")) == SkillTree.TIER_COUNT - 1
	)

	# Choosing what is already active clears it, so a pick is never a trap.
	save.call(&"set_skill_choice", &"recruit", &"rec_1b")
	_check(
		"taking the active skill again clears the tier",
		not bool(save.call(&"is_skill_node_chosen", &"recruit", &"rec_1b"))
	)

	# A class cannot wear another class's skills.
	_check(
		"skills belong to their class",
		not bool(save.call(&"can_choose_skill_node", &"recruit", &"ren_1a"))
	)
	_check(
		"and cannot be taken across classes",
		not bool(save.call(&"set_skill_choice", &"recruit", &"med_5a"))
	)

	save.call(&"set_skill_choice", &"recruit", &"rec_1a")
	save.call(&"set_skill_choice", &"recruit", &"rec_5a")
	var bonuses: Dictionary = save.call(&"get_skill_bonuses", &"recruit")
	_check(
		"the save feeds the bonuses the run reads (%.3f)" % float(bonuses["damage_mult"]),
		is_equal_approx(float(bonuses["damage_mult"]), 1.08 * 1.20)
	)
	await process_frame


## Profiles from the 36-node shared tree carry ids that no longer exist. They are
## dropped rather than migrated: choices cost nothing and are gated only by
## level, so the profile can re-pick every tier it has earned straight away.
func _test_migration_from_the_old_tree() -> void:
	var save := root.get_node_or_null("/root/SaveManager")
	if save == null:
		return
	DirAccess.remove_absolute(SAVE_PATH)
	save.call(&"load_progress", SAVE_PATH)
	save.call(&"add_character_xp", &"recruit", 100000)
	# Straight from an old profile: branch nodes, plus one real node to prove the
	# valid entries survive the cleaning, and one belonging to another class.
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("recruit", "skill_nodes", PackedStringArray([
		"off_1", "off_2b", "sur_3", "exp_5", "rec_2a", "ren_1a",
	]))
	config.save(SAVE_PATH)
	save.call(&"load_progress", SAVE_PATH)

	var choices: PackedStringArray = save.call(&"get_skill_choices", &"recruit")
	_check(
		"stale nodes are dropped, the valid one kept (%s)" % str(choices),
		choices.size() == 1 and choices[0] == "rec_2a"
	)
	_check(
		"the four tiers left are pickable again (%d)"
			% int(save.call(&"get_pending_skill_choices", &"recruit")),
		int(save.call(&"get_pending_skill_choices", &"recruit")) == SkillTree.TIER_COUNT - 1
	)
	var bonuses: Dictionary = save.call(&"get_skill_bonuses", &"recruit")
	_check(
		"an old profile grants only what it still holds",
		is_equal_approx(float(bonuses["magazine_mult"]), 1.20)
			and is_equal_approx(float(bonuses["damage_mult"]), 1.0)
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
	for _frame in 6:
		await process_frame

	var cards := _find_cards(current_scene)
	_check(
		"a card per skill of the class (%d)" % cards.size(),
		cards.size() == SkillTree.TIER_COUNT * 2
	)
	var card := cards.get(&"rec_1a") as Button
	_check("the first skill has a card", card != null)
	if card == null:
		return
	# No confirmation any more: the click is the decision, because it can be
	# undone with another click.
	card.emit_signal(&"pressed")
	await process_frame
	_check(
		"clicking a card takes the skill",
		bool(save.call(&"is_skill_node_chosen", &"recruit", &"rec_1a"))
	)
	# The state is drawn, not written: the canvas records which side of each tier
	# is taken and lights the node and its connector from that.
	var canvas: SkillTreeCanvas = current_scene.get(&"_canvas")
	_check("the tree is drawn on a canvas", canvas != null)
	if canvas != null:
		_check(
			"the canvas has a row per tier (%d)" % canvas.tiers.size(),
			canvas.tiers.size() == SkillTree.TIER_COUNT
		)
		_check(
			"the taken side of tier 1 is lit (%d)" % int(canvas.tiers[0]["taken"]),
			int(canvas.tiers[0]["taken"]) == -1
		)
		_check(
			"a tier nobody has picked stays unlit",
			int(canvas.tiers[SkillTree.TIER_COUNT - 1]["taken"]) == 0
		)
	var refreshed := _find_cards(current_scene)
	var active_card := refreshed.get(&"rec_1a") as Button
	if active_card != null:
		active_card.emit_signal(&"pressed")
		await process_frame
		_check(
			"clicking it again clears the tier",
			not bool(save.call(&"is_skill_node_chosen", &"recruit", &"rec_1a"))
		)


func _find_cards(node: Node) -> Dictionary:
	var cards: Dictionary = {}
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and not SkillTree.get_node_definition(
			StringName(button.name)
		).is_empty():
			cards[StringName(button.name)] = button
	return cards


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
