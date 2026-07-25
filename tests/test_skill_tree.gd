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
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_shape() -> void:
	_check("shape: three branches", SkillTree.BRANCHES.size() == 3)
	_check("shape: 24 nodes", SkillTree.NODES.size() == 24)
	for branch in SkillTree.BRANCHES:
		var branch_id: StringName = branch["id"]
		var nodes := SkillTree.get_branch_nodes(branch_id)
		var name := String(branch["title"])
		_check("shape: %s has 8 nodes" % name, nodes.size() == 8)
		var by_tier: Dictionary[int, int] = {}
		for node in nodes:
			var tier := int(node["tier"])
			by_tier[tier] = int(by_tier.get(tier, 0)) + 1
		_check(
			"shape: %s is 1-2-2-2-1" % name,
			by_tier.get(1, 0) == 1 and by_tier.get(2, 0) == 2
			and by_tier.get(3, 0) == 2 and by_tier.get(4, 0) == 2
			and by_tier.get(5, 0) == 1
		)
		_check(
			"shape: %s tiers are sorted" % name,
			int(nodes[0]["tier"]) == 1 and int(nodes[7]["tier"]) == 5
		)
		_check("shape: %s capstone forks back in" % name,
			SkillTree.get_prerequisites(nodes[7]["id"]).size() == 2
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
		SkillTree.is_prerequisite_met(&"off_5", ["off_4"])
	)
	_check(
		"prereq: capstone opens from the right path",
		SkillTree.is_prerequisite_met(&"off_5", ["off_4b"])
	)
	_check(
		"prereq: capstone stays shut at tier 3",
		not SkillTree.is_prerequisite_met(&"off_5", ["off_3", "off_3b"])
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


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
