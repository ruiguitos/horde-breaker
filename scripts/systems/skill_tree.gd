class_name SkillTree
extends RefCounted

## Permanent skill trees: one per class, three categories each, spent with skill
## points earned by levelling.
##
## Each category is a chain that forks once and rejoins:
##
##       tier 1        level 2      the way in
##       tier 2        level 5
##     3a    3b        level 9      fork: take one side, or pay for both
##       tier 4        level 14     either side opens it
##       tier 5        level 20     the category's payoff
##
## Six nodes a category, eighteen a class, fifty-four in all. Nodes accumulate —
## unlocking one never takes another away. What makes a build is scarcity: points
## come one every two levels, so a character cannot hold its whole tree and has
## to decide which categories to push and which to leave shallow.
##
## This replaced a five-tier "pick one side of each tier" layout, which read
## quickly but gave the player nothing to save towards and no way to go deep on
## anything. It also replaced a single shared tree that all three classes walked
## identically; the categories now differ by class, because they are where the
## class's identity lives.
##
## Only the keys in DEFAULT_BONUSES do anything: character_skills.gd reads that
## dictionary and nothing else.

const CLASS_RECRUIT := &"recruit"
const CLASS_RENEGADE := &"renegade"
const CLASS_MEDIC := &"medic"

const TIER_COUNT := 5
const REQUIRED_LEVEL_BY_TIER := {1: 2, 2: 5, 3: 9, 4: 14, 5: 20}

const DEFAULT_BONUSES: Dictionary = {
	"damage_mult": 1.0,
	"fire_rate_mult": 1.0,
	"reload_mult": 1.0,
	"magazine_mult": 1.0,
	"max_health_add": 0.0,
	"regen_add": 0.0,
	"damage_reduction": 0.0,
	"move_speed_mult": 1.0,
	"scrap_mult": 1.0,
	"xp_mult": 1.0,
	"ammo_reserve_mult": 1.0,
	"pickup_radius_mult": 1.0,
}

const ADDITIVE_STATS: Array[StringName] = [
	&"max_health_add", &"regen_add", &"damage_reduction",
]

## Every category has the same skeleton: trunk, trunk, fork, rejoin, payoff.
## Written once here and stamped onto each category's six nodes below, so a
## category is defined by what its nodes do rather than by repeating the wiring.
const CATEGORY_SHAPE: Array[Dictionary] = [
	{"key": "1", "tier": 1, "column": 0, "requires": []},
	{"key": "2", "tier": 2, "column": 0, "requires": ["1"]},
	{"key": "3a", "tier": 3, "column": -1, "requires": ["2"]},
	{"key": "3b", "tier": 3, "column": 1, "requires": ["2"]},
	{"key": "4", "tier": 4, "column": 0, "requires": ["3a", "3b"]},
	{"key": "5", "tier": 5, "column": 0, "requires": ["4"]},
]

## class -> title, tagline, and three categories of six effects each, in the
## order of CATEGORY_SHAPE.
const TREES: Dictionary[StringName, Dictionary] = {
	CLASS_RECRUIT: {
		"title": "RECRUIT",
		"tagline": "Never stops shooting.",
		"categories": [
			{
				"id": &"firepower", "title": "FIREPOWER",
				"tagline": "Every round hits harder.",
				"nodes": [
					{"title": "Marksman", "description": "+6% weapon damage.",
						"effect": {"damage_mult": 1.06}},
					{"title": "Heavy Rounds", "description": "+8% weapon damage.",
						"effect": {"damage_mult": 1.08}},
					{"title": "Long Barrel", "description": "+12% magazine size.",
						"effect": {"magazine_mult": 1.12}},
					{"title": "Hair Trigger", "description": "+8% fire rate.",
						"effect": {"fire_rate_mult": 1.08}},
					{"title": "Armour Piercing", "description": "+10% weapon damage.",
						"effect": {"damage_mult": 1.10}},
					{"title": "Gunsmith", "description": "+18% weapon damage.",
						"effect": {"damage_mult": 1.18}},
				],
			},
			{
				"id": &"sustained", "title": "SUSTAINED FIRE",
				"tagline": "The gun never goes quiet.",
				"nodes": [
					{"title": "Fast Hands", "description": "-8% reload time.",
						"effect": {"reload_mult": 0.92}},
					{"title": "Bandolier", "description": "+15% ammo reserve.",
						"effect": {"ammo_reserve_mult": 1.15}},
					{"title": "Practised Reload", "description": "-12% reload time.",
						"effect": {"reload_mult": 0.88}},
					{"title": "Drum Mags", "description": "+12% magazine size.",
						"effect": {"magazine_mult": 1.12}},
					{"title": "Deep Pockets", "description": "+20% ammo reserve.",
						"effect": {"ammo_reserve_mult": 1.20}},
					{"title": "Trigger Discipline",
						"description": "-20% reload time and +10% fire rate.",
						"effect": {"reload_mult": 0.80, "fire_rate_mult": 1.10}},
				],
			},
			{
				"id": &"fieldcraft", "title": "FIELDCRAFT",
				"tagline": "More ground, more loot, more levels.",
				"nodes": [
					{"title": "Light Kit", "description": "+4% movement speed.",
						"effect": {"move_speed_mult": 1.04}},
					{"title": "Magnetic Pouches", "description": "+25% pickup range.",
						"effect": {"pickup_radius_mult": 1.25}},
					{"title": "Quick Study", "description": "+12% experience gained.",
						"effect": {"xp_mult": 1.12}},
					{"title": "Scrounger", "description": "+12% Scrap collected.",
						"effect": {"scrap_mult": 1.12}},
					{"title": "Marching Order", "description": "+6% movement speed.",
						"effect": {"move_speed_mult": 1.06}},
					{"title": "Field Scavenger",
						"description": "+20% experience and +20% Scrap.",
						"effect": {"xp_mult": 1.20, "scrap_mult": 1.20}},
				],
			},
		],
	},
	CLASS_RENEGADE: {
		"title": "RENEGADE",
		"tagline": "Walks into it.",
		"categories": [
			{
				"id": &"armour", "title": "ARMOUR",
				"tagline": "Take the hit and keep going.",
				"nodes": [
					{"title": "Padding", "description": "+20 maximum health.",
						"effect": {"max_health_add": 20.0}},
					{"title": "Plated", "description": "6% less damage taken.",
						"effect": {"damage_reduction": 0.06}},
					{"title": "Heavy Frame", "description": "+25 maximum health.",
						"effect": {"max_health_add": 25.0}},
					{"title": "Riot Shield", "description": "6% less damage taken.",
						"effect": {"damage_reduction": 0.06}},
					{"title": "Second Wind",
						"description": "+2 health regenerated per second.",
						"effect": {"regen_add": 2.0}},
					{"title": "Juggernaut",
						"description": "+50 maximum health and 8% less damage taken.",
						"effect": {"max_health_add": 50.0, "damage_reduction": 0.08}},
				],
			},
			{
				"id": &"aggression", "title": "AGGRESSION",
				"tagline": "Answer faster than it can.",
				"nodes": [
					{"title": "Brawler", "description": "+7% weapon damage.",
						"effect": {"damage_mult": 1.07}},
					{"title": "Bloodlust", "description": "+8% fire rate.",
						"effect": {"fire_rate_mult": 1.08}},
					{"title": "Point Blank", "description": "+10% weapon damage.",
						"effect": {"damage_mult": 1.10}},
					{"title": "Wide Choke", "description": "+14% magazine size.",
						"effect": {"magazine_mult": 1.14}},
					{"title": "Frenzy", "description": "+10% fire rate.",
						"effect": {"fire_rate_mult": 1.10}},
					{"title": "Berserker", "description": "+20% weapon damage.",
						"effect": {"damage_mult": 1.20}},
				],
			},
			{
				"id": &"momentum", "title": "MOMENTUM",
				"tagline": "Close the distance and stay there.",
				"nodes": [
					{"title": "Adrenaline", "description": "+5% movement speed.",
						"effect": {"move_speed_mult": 1.05}},
					{"title": "Quick Load", "description": "-10% reload time.",
						"effect": {"reload_mult": 0.90}},
					{"title": "Charge", "description": "+6% movement speed.",
						"effect": {"move_speed_mult": 1.06}},
					{"title": "Sweep", "description": "+30% pickup range.",
						"effect": {"pickup_radius_mult": 1.30}},
					{"title": "Muscle Memory", "description": "-12% reload time.",
						"effect": {"reload_mult": 0.88}},
					{"title": "Unstoppable",
						"description": "+12% movement speed and +15% ammo reserve.",
						"effect": {"move_speed_mult": 1.12, "ammo_reserve_mult": 1.15}},
				],
			},
		],
	},
	CLASS_MEDIC: {
		"title": "MEDIC",
		"tagline": "Outlasts everything.",
		"categories": [
			{
				"id": &"recovery", "title": "RECOVERY",
				"tagline": "The wound closes while you fight.",
				"nodes": [
					{"title": "Triage",
						"description": "+1 health regenerated per second.",
						"effect": {"regen_add": 1.0}},
					{"title": "Field Kit", "description": "+20 maximum health.",
						"effect": {"max_health_add": 20.0}},
					{"title": "Transfusion",
						"description": "+1.5 health regenerated per second.",
						"effect": {"regen_add": 1.5}},
					{"title": "Reinforced Vest", "description": "6% less damage taken.",
						"effect": {"damage_reduction": 0.06}},
					{"title": "Stimulants", "description": "+25 maximum health.",
						"effect": {"max_health_add": 25.0}},
					{"title": "Regenerator",
						"description": "+3 health regenerated per second.",
						"effect": {"regen_add": 3.0}},
				],
			},
			{
				"id": &"utility", "title": "UTILITY",
				"tagline": "Carry more out than you took in.",
				"nodes": [
					{"title": "Magnetic Kit", "description": "+30% pickup range.",
						"effect": {"pickup_radius_mult": 1.30}},
					{"title": "Fast Learner", "description": "+12% experience gained.",
						"effect": {"xp_mult": 1.12}},
					{"title": "Salvager", "description": "+15% Scrap collected.",
						"effect": {"scrap_mult": 1.15}},
					{"title": "Ammo Runner", "description": "+20% ammo reserve.",
						"effect": {"ammo_reserve_mult": 1.20}},
					{"title": "Field Notes", "description": "+15% experience gained.",
						"effect": {"xp_mult": 1.15}},
					{"title": "Quartermaster",
						"description": "+40% pickup range and +25% Scrap.",
						"effect": {"pickup_radius_mult": 1.40, "scrap_mult": 1.25}},
				],
			},
			{
				"id": &"combat", "title": "COMBAT",
				"tagline": "Not only a survivor.",
				"nodes": [
					{"title": "Steady Hands", "description": "+6% weapon damage.",
						"effect": {"damage_mult": 1.06}},
					{"title": "Rapid Response", "description": "+8% fire rate.",
						"effect": {"fire_rate_mult": 1.08}},
					{"title": "Extended Mags", "description": "+10% magazine size.",
						"effect": {"magazine_mult": 1.10}},
					{"title": "Practised Swap", "description": "-10% reload time.",
						"effect": {"reload_mult": 0.90}},
					{"title": "Suppressive Fire", "description": "+10% weapon damage.",
						"effect": {"damage_mult": 1.10}},
					{"title": "Combat Medic",
						"description": "+18% weapon damage and +10% fire rate.",
						"effect": {"damage_mult": 1.18, "fire_rate_mult": 1.10}},
				],
			},
		],
	},
}


static func get_class_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for class_id: StringName in TREES:
		ids.append(class_id)
	return ids


static func has_tree(class_id: StringName) -> bool:
	return TREES.has(class_id)


static func get_class_tree(class_id: StringName) -> Dictionary:
	return TREES.get(class_id, {})


## The categories of a class, as `[{id, title, tagline}]` in display order.
static func get_categories(class_id: StringName) -> Array[Dictionary]:
	var categories: Array[Dictionary] = []
	var tree := get_class_tree(class_id)
	if tree.is_empty():
		return categories
	for category: Dictionary in tree["categories"]:
		categories.append({
			"id": category["id"],
			"title": category["title"],
			"tagline": category["tagline"],
		})
	return categories


## The six nodes of one category, fully described.
static func get_category_nodes(
	class_id: StringName, category_id: StringName
) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	var tree := get_class_tree(class_id)
	if tree.is_empty():
		return nodes
	for category: Dictionary in tree["categories"]:
		if category["id"] != category_id:
			continue
		for index in CATEGORY_SHAPE.size():
			nodes.append(_describe(class_id, category, index))
	return nodes


static func get_class_nodes(class_id: StringName) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for category in get_categories(class_id):
		nodes.append_array(get_category_nodes(class_id, category["id"]))
	return nodes


static func get_node_definition(node_id: StringName) -> Dictionary:
	for class_id: StringName in TREES:
		for category: Dictionary in TREES[class_id]["categories"]:
			for index in CATEGORY_SHAPE.size():
				if _build_id(class_id, category["id"], index) == node_id:
					return _describe(class_id, category, index)
	return {}


static func get_required_level(node_id: StringName) -> int:
	var node := get_node_definition(node_id)
	if node.is_empty():
		return 0
	return int(REQUIRED_LEVEL_BY_TIER.get(int(node["tier"]), 0))


static func get_required_level_for_tier(tier: int) -> int:
	return int(REQUIRED_LEVEL_BY_TIER.get(tier, 0))


static func get_prerequisites(node_id: StringName) -> Array:
	var node := get_node_definition(node_id)
	return node.get("requires", []) if not node.is_empty() else []


## Any one prerequisite is enough — the fork rejoins, so either side opens what
## comes after it.
static func is_prerequisite_met(node_id: StringName, unlocked_ids: Array) -> bool:
	var required := get_prerequisites(node_id)
	if required.is_empty():
		return true
	for prerequisite in required:
		if prerequisite in unlocked_ids or String(prerequisite) in unlocked_ids:
			return true
	return false


static func get_bonuses(unlocked_ids: Array) -> Dictionary:
	var bonuses := DEFAULT_BONUSES.duplicate()
	for node_id in unlocked_ids:
		var node := get_node_definition(StringName(node_id))
		if node.is_empty():
			continue
		var effect: Dictionary = node["effect"]
		for stat: StringName in effect:
			if stat in ADDITIVE_STATS:
				bonuses[stat] = float(bonuses[stat]) + float(effect[stat])
			else:
				bonuses[stat] = float(bonuses[stat]) * float(effect[stat])
	bonuses["damage_reduction"] = clampf(float(bonuses["damage_reduction"]), 0.0, 0.75)
	return bonuses


static func _build_id(
	class_id: StringName, category_id: StringName, index: int
) -> StringName:
	return StringName("%s_%s_%s" % [
		class_id, category_id, CATEGORY_SHAPE[index]["key"]
	])


static func _describe(
	class_id: StringName, category: Dictionary, index: int
) -> Dictionary:
	var shape: Dictionary = CATEGORY_SHAPE[index]
	var node: Dictionary = category["nodes"][index]
	var requires: Array[StringName] = []
	for key: String in shape["requires"]:
		for shape_index in CATEGORY_SHAPE.size():
			if CATEGORY_SHAPE[shape_index]["key"] == key:
				requires.append(_build_id(class_id, category["id"], shape_index))
	return {
		"id": _build_id(class_id, category["id"], index),
		"class_id": class_id,
		"category_id": category["id"],
		"category_title": category["title"],
		"tier": shape["tier"],
		"column": shape["column"],
		"requires": requires,
		"required_level": get_required_level_for_tier(int(shape["tier"])),
		"title": node["title"],
		"description": node["description"],
		"effect": node["effect"],
	}
