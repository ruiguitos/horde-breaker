extends SceneTree

## The skill tree grew from three straight lines of five into three forking
## trees of eight. This checks the shape, that old save data still works, and
## that every bonus a node grants is actually consumed by something.

const SKILL_TREE_PATH := "res://scripts/systems/skill_tree.gd"

var _passed := 0
var _failed := 0
var _tree: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_tree = load(SKILL_TREE_PATH)
	_test_shape()
	_test_prerequisites()
	_test_bonuses()
	_test_legacy_saves()
	await _test_unlock_flow()
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_shape() -> void:
	_check("shape: three branches", SkillTree.BRANCHES.size() == 3)
	_check("shape: 36 nodes", SkillTree.NODES.size() == 36)
	for branch in SkillTree.BRANCHES:
		var branch_id: StringName = branch["id"]
		var nodes := SkillTree.get_branch_nodes(branch_id)
		var name := String(branch["title"])
		_check("shape: %s has 12 nodes" % name, nodes.size() == 12)
		var by_tier: Dictionary[int, int] = {}
		for node in nodes:
			var tier := int(node["tier"])
			by_tier[tier] = int(by_tier.get(tier, 0)) + 1
		_check(
			"shape: %s is 1-2-2-2-2-2-1" % name,
			by_tier.get(1, 0) == 1 and by_tier.get(2, 0) == 2
			and by_tier.get(3, 0) == 2 and by_tier.get(4, 0) == 2
			and by_tier.get(5, 0) == 2 and by_tier.get(6, 0) == 2
			and by_tier.get(7, 0) == 1
		)
		_check(
			"shape: %s tiers are sorted" % name,
			int(nodes[0]["tier"]) == 1
			and int(nodes[nodes.size() - 1]["tier"]) == SkillTree.TIER_COUNT
		)
		_check("shape: %s capstone forks back in" % name,
			SkillTree.get_prerequisites(nodes[nodes.size() - 1]["id"]).size() == 2
		)
		for tier in range(1, SkillTree.TIER_COUNT + 1):
			_check(
				"shape: %s tier %d has a required level" % [name, tier],
				int(SkillTree.REQUIRED_LEVEL_BY_TIER.get(tier, 0)) > 0
			)


func _test_prerequisites() -> void:
	_check(
		"prereq: the root needs nothing",
		SkillTree.is_prerequisite_met(&"off_1", [])
	)
	_check(
		"prereq: tier 2 needs the root",
		not SkillTree.is_prerequisite_met(&"off_2", [])
		and SkillTree.is_prerequisite_met(&"off_2", ["off_1"])
	)
	_check(
		"prereq: the paths do not cross",
		not SkillTree.is_prerequisite_met(&"off_3b", ["off_1", "off_2"])
	)
	# The whole point of the fork: either side reaches the capstone.
	_check(
		"prereq: capstone opens from the left path",
		SkillTree.is_prerequisite_met(&"off_7", ["off_6"])
	)
	_check(
		"prereq: capstone opens from the right path",
		SkillTree.is_prerequisite_met(&"off_7", ["off_6b"])
	)
	_check(
		"prereq: capstone stays shut a tier early",
		not SkillTree.is_prerequisite_met(&"off_7", ["off_5", "off_5b"])
	)
	for node in SkillTree.NODES:
		var node_id: StringName = node["id"]
		for prerequisite in SkillTree.get_prerequisites(node_id):
			var definition := SkillTree.get_node_definition(
				StringName(prerequisite)
			)
			_check(
				"prereq: %s -> %s exists and is one tier lower" % [
					prerequisite, node_id
				],
				not definition.is_empty()
				and int(definition["tier"]) == int(node["tier"]) - 1
				and definition["branch"] == node["branch"]
			)


func _test_bonuses() -> void:
	var every_id: Array = []
	for node in SkillTree.NODES:
		every_id.append(String(node["id"]))
		for stat: StringName in node["effect"]:
			_check(
				"bonus: %s declares %s" % [node["id"], stat],
				SkillTree.DEFAULT_BONUSES.has(stat)
			)
	var bonuses := SkillTree.get_bonuses(every_id)
	_check("bonus: damage stacks", float(bonuses["damage_mult"]) > 1.25)
	_check("bonus: health stacks", float(bonuses["max_health_add"]) >= 140.0)
	_check(
		"bonus: damage reduction is capped",
		float(bonuses["damage_reduction"]) <= 0.75
	)
	_check(
		"bonus: the new magazine node lands",
		float(bonuses["magazine_mult"]) > 1.0
	)
	_check(
		"bonus: the new pickup node lands",
		float(bonuses["pickup_radius_mult"]) > 1.0
	)


func _test_legacy_saves() -> void:
	# Profiles from the five-node layout must keep every point they spent.
	var legacy := [
		"off_1", "off_2", "off_3", "off_4", "off_5",
		"sur_1", "sur_2", "sur_3", "sur_4", "sur_5",
		"exp_1", "exp_2", "exp_3", "exp_4", "exp_5",
	]
	for node_id in legacy:
		_check(
			"legacy: %s still exists" % node_id,
			not SkillTree.get_node_definition(StringName(node_id)).is_empty()
		)
	var bonuses := SkillTree.get_bonuses(legacy)
	_check(
		"legacy: the old path still grants its bonuses",
		float(bonuses["damage_mult"]) > 1.0
		and float(bonuses["max_health_add"]) == 100.0
	)


func _test_unlock_flow() -> void:
	# Drives the real screen: an earlier build unlocked correctly when called
	# directly but was unusable with a mouse, because hovering a node changed
	# the selection while the cursor travelled to a separate UNLOCK button.
	var save := root.get_node("/root/SaveManager")
	# Start from nothing: a leftover file from the previous run would arrive
	# with the node already unlocked and quietly skip the whole flow.
	DirAccess.remove_absolute("user://horde_breaker_unlock_flow_test.cfg")
	save.call(&"load_progress", "user://horde_breaker_unlock_flow_test.cfg")
	save.call(&"select_character", &"recruit")
	save.call(&"add_character_xp", &"recruit", 20000)
	if change_scene_to_file("res://scenes/menus/skill_tree_screen.tscn") != OK:
		_check("unlock: skill screen loads", false)
		return
	await scene_changed
	for _frame in 6:
		await process_frame
	var screen := current_scene
	var buttons: Dictionary = screen.get(&"_node_buttons")
	_check("unlock: a button per node", buttons.size() == SkillTree.NODES.size())

	var root_button := buttons.get(&"off_1") as Button
	_check("unlock: the root node has a button", root_button != null)
	if root_button == null:
		return
	# Clicking an available node asks first and spends nothing until confirmed.
	root_button.emit_signal(&"pressed")
	await process_frame
	var dialog: ConfirmationDialog = screen.get(&"_confirm_dialog")
	_check("unlock: clicking asks for confirmation", dialog.visible)
	_check(
		"unlock: the prompt names the skill",
		dialog.dialog_text.contains("SHARPSHOOTER")
	)
	_check(
		"unlock: nothing is spent before confirming",
		not bool(save.call(&"is_skill_node_unlocked", &"recruit", &"off_1"))
	)
	# Answering NO leaves the point unspent.
	dialog.hide()
	await process_frame
	_check(
		"unlock: answering no spends nothing",
		not bool(save.call(&"is_skill_node_unlocked", &"recruit", &"off_1"))
	)
	# Answering YES spends it.
	root_button.emit_signal(&"pressed")
	await process_frame
	dialog.emit_signal(&"confirmed")
	# A real OK click closes the window; emitting the signal by hand does not.
	dialog.hide()
	await process_frame
	_check(
		"unlock: confirming unlocks the node",
		bool(save.call(&"is_skill_node_unlocked", &"recruit", &"off_1"))
	)

	# Hovering must not arm anything: only the click decides.
	var locked_button := buttons.get(&"off_3") as Button
	if locked_button != null:
		locked_button.emit_signal(&"mouse_entered")
		await process_frame
		_check(
			"unlock: hovering never opens the dialog",
			not dialog.visible
		)
		locked_button.emit_signal(&"pressed")
		await process_frame
		_check(
			"unlock: a locked node cannot be bought",
			not dialog.visible
			and not bool(save.call(&"is_skill_node_unlocked", &"recruit", &"off_3"))
		)


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
