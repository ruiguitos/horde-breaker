class_name SkillTree
extends RefCounted

## Static definition of the permanent, per-character skill tree. Three branches
## of five tiers each; a node requires the previous tier in the same branch.
## Each node contributes to an aggregate bonus dictionary applied at run start.

const BRANCH_OFFENSE := &"offense"
const BRANCH_SURVIVAL := &"survival"
const BRANCH_EXPEDITION := &"expedition"

const REQUIRED_LEVEL_BY_TIER := {
	1: 2,
	2: 5,
	3: 9,
	4: 14,
	5: 20,
}

const BRANCHES: Array[Dictionary] = [
	{"id": BRANCH_OFFENSE, "title": "OFFENSE"},
	{"id": BRANCH_SURVIVAL, "title": "SURVIVAL"},
	{"id": BRANCH_EXPEDITION, "title": "EXPEDITION"},
]

# Each node: id, branch, tier (1..5), title, description, and effect (stat->value).
const NODES: Array[Dictionary] = [
	# --- Offense ---
	{
		"id": &"off_1", "branch": BRANCH_OFFENSE, "tier": 1,
		"title": "Sharpshooter", "description": "+6% weapon damage.",
		"effect": {"damage_mult": 1.06},
	},
	{
		"id": &"off_2", "branch": BRANCH_OFFENSE, "tier": 2,
		"title": "Rapid Fire", "description": "+8% fire rate.",
		"effect": {"fire_rate_mult": 1.08},
	},
	{
		"id": &"off_3", "branch": BRANCH_OFFENSE, "tier": 3,
		"title": "Deadeye", "description": "+8% weapon damage.",
		"effect": {"damage_mult": 1.08},
	},
	{
		"id": &"off_4", "branch": BRANCH_OFFENSE, "tier": 4,
		"title": "Quick Hands", "description": "12% faster reloads.",
		"effect": {"reload_mult": 0.88},
	},
	{
		"id": &"off_5", "branch": BRANCH_OFFENSE, "tier": 5,
		"title": "Executioner", "description": "+12% weapon damage.",
		"effect": {"damage_mult": 1.12},
	},
	# --- Survival ---
	{
		"id": &"sur_1", "branch": BRANCH_SURVIVAL, "tier": 1,
		"title": "Toughness", "description": "+20 maximum health.",
		"effect": {"max_health_add": 20.0},
	},
	{
		"id": &"sur_2", "branch": BRANCH_SURVIVAL, "tier": 2,
		"title": "Regeneration", "description": "+1.5 health regen per second.",
		"effect": {"regen_add": 1.5},
	},
	{
		"id": &"sur_3", "branch": BRANCH_SURVIVAL, "tier": 3,
		"title": "Vitality", "description": "+30 maximum health.",
		"effect": {"max_health_add": 30.0},
	},
	{
		"id": &"sur_4", "branch": BRANCH_SURVIVAL, "tier": 4,
		"title": "Armor Plating", "description": "8% damage reduction.",
		"effect": {"damage_reduction": 0.08},
	},
	{
		"id": &"sur_5", "branch": BRANCH_SURVIVAL, "tier": 5,
		"title": "Juggernaut", "description": "+50 maximum health.",
		"effect": {"max_health_add": 50.0},
	},
	# --- Expedition ---
	{
		"id": &"exp_1", "branch": BRANCH_EXPEDITION, "tier": 1,
		"title": "Fleet Footed", "description": "+6% movement speed.",
		"effect": {"move_speed_mult": 1.06},
	},
	{
		"id": &"exp_2", "branch": BRANCH_EXPEDITION, "tier": 2,
		"title": "Scavenger", "description": "+25% Scrap collected.",
		"effect": {"scrap_mult": 1.25},
	},
	{
		"id": &"exp_3", "branch": BRANCH_EXPEDITION, "tier": 3,
		"title": "Fast Learner", "description": "+20% XP gained.",
		"effect": {"xp_mult": 1.20},
	},
	{
		"id": &"exp_4", "branch": BRANCH_EXPEDITION, "tier": 4,
		"title": "Ammo Belt", "description": "+30% ammo reserve capacity.",
		"effect": {"ammo_reserve_mult": 1.30},
	},
	{
		"id": &"exp_5", "branch": BRANCH_EXPEDITION, "tier": 5,
		"title": "Marathoner", "description": "+10% movement speed.",
		"effect": {"move_speed_mult": 1.10},
	},
]

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
}

const ADDITIVE_STATS: Array[StringName] = [
	&"max_health_add", &"regen_add", &"damage_reduction",
]


static func get_node_definition(node_id: StringName) -> Dictionary:
	for node in NODES:
		if node["id"] == node_id:
			return node
	return {}


static func get_branch_nodes(branch_id: StringName) -> Array[Dictionary]:
	var branch_nodes: Array[Dictionary] = []
	for node in NODES:
		if node["branch"] == branch_id:
			branch_nodes.append(node)
	branch_nodes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return int(a["tier"]) < int(b["tier"])
	)
	return branch_nodes


static func get_prerequisite_id(node_id: StringName) -> StringName:
	var node := get_node_definition(node_id)
	if node.is_empty() or int(node["tier"]) <= 1:
		return &""
	for candidate in NODES:
		if (
			candidate["branch"] == node["branch"]
			and int(candidate["tier"]) == int(node["tier"]) - 1
		):
			return candidate["id"]
	return &""


static func get_required_level(node_id: StringName) -> int:
	var node := get_node_definition(node_id)
	if node.is_empty():
		return 0
	return int(REQUIRED_LEVEL_BY_TIER.get(int(node["tier"]), 0))


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
