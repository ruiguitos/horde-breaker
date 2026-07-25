class_name SkillTree
extends RefCounted

## Static definition of the permanent, per-character skill tree. Three separate
## trees — Offense, Survival, Expedition — each shaped as a trunk that forks
## into two paths and rejoins at a capstone:
##
##            tier 1          (trunk)
##          /        \
##      tier 2      tier 2    (fork: pick a side, or pay for both)
##        |           |
##      tier 3      tier 3
##        |           |
##       ...         ...      (tiers 4, 5 and 6 continue both paths)
##          \        /
##            tier 7          (capstone: either tier 6 opens it)
##
## 12 nodes per branch, 36 in total. Node ids from the original five-per-branch
## layout are kept on the left path so existing saves keep every point they
## have already spent.
##
## Each node contributes to an aggregate bonus dictionary applied at run start.

const BRANCH_OFFENSE := &"offense"
const BRANCH_SURVIVAL := &"survival"
const BRANCH_EXPEDITION := &"expedition"

const REQUIRED_LEVEL_BY_TIER := {
	1: 2,
	2: 4,
	3: 7,
	4: 10,
	5: 14,
	6: 18,
	7: 24,
}

const BRANCHES: Array[Dictionary] = [
	{
		"id": BRANCH_OFFENSE,
		"title": "OFFENSE",
		"tagline": "Kill faster, reload less.",
	},
	{
		"id": BRANCH_SURVIVAL,
		"title": "SURVIVAL",
		"tagline": "Outlast the horde.",
	},
	{
		"id": BRANCH_EXPEDITION,
		"title": "EXPEDITION",
		"tagline": "Move, loot and learn faster.",
	},
]

# Each node: id, branch, tier (1..5), column (-1 left, 0 trunk, 1 right),
# requires (any one of these unlocks it), title, description, effect.
const NODES: Array[Dictionary] = [
	# --- Offense ---
	{
		"id": &"off_1", "branch": BRANCH_OFFENSE, "tier": 1, "column": 0,
		"requires": [],
		"title": "Sharpshooter", "description": "+6% weapon damage.",
		"effect": {"damage_mult": 1.06},
	},
	{
		"id": &"off_2", "branch": BRANCH_OFFENSE, "tier": 2, "column": -1,
		"requires": [&"off_1"],
		"title": "Rapid Fire", "description": "+8% fire rate.",
		"effect": {"fire_rate_mult": 1.08},
	},
	{
		"id": &"off_2b", "branch": BRANCH_OFFENSE, "tier": 2, "column": 1,
		"requires": [&"off_1"],
		"title": "Extended Mags", "description": "+15% magazine size.",
		"effect": {"magazine_mult": 1.15},
	},
	{
		"id": &"off_3", "branch": BRANCH_OFFENSE, "tier": 3, "column": -1,
		"requires": [&"off_2"],
		"title": "Deadeye", "description": "+8% weapon damage.",
		"effect": {"damage_mult": 1.08},
	},
	{
		"id": &"off_3b", "branch": BRANCH_OFFENSE, "tier": 3, "column": 1,
		"requires": [&"off_2b"],
		"title": "Gun Oil", "description": "10% faster reloads.",
		"effect": {"reload_mult": 0.90},
	},
	{
		"id": &"off_4", "branch": BRANCH_OFFENSE, "tier": 4, "column": -1,
		"requires": [&"off_3"],
		"title": "Quick Hands", "description": "12% faster reloads.",
		"effect": {"reload_mult": 0.88},
	},
	{
		"id": &"off_4b", "branch": BRANCH_OFFENSE, "tier": 4, "column": 1,
		"requires": [&"off_3b"],
		"title": "Overclock", "description": "+10% fire rate.",
		"effect": {"fire_rate_mult": 1.10},
	},
	{
		"id": &"off_5", "branch": BRANCH_OFFENSE, "tier": 5, "column": -1,
		"requires": [&"off_4"],
		"title": "Executioner", "description": "+12% weapon damage.",
		"effect": {"damage_mult": 1.12},
	},
	{
		"id": &"off_5b", "branch": BRANCH_OFFENSE, "tier": 5, "column": 1,
		"requires": [&"off_4b"],
		"title": "Heavy Rounds", "description": "+10% weapon damage.",
		"effect": {"damage_mult": 1.10},
	},
	{
		"id": &"off_6", "branch": BRANCH_OFFENSE, "tier": 6, "column": -1,
		"requires": [&"off_5"],
		"title": "Trigger Discipline", "description": "+12% fire rate.",
		"effect": {"fire_rate_mult": 1.12},
	},
	{
		"id": &"off_6b", "branch": BRANCH_OFFENSE, "tier": 6, "column": 1,
		"requires": [&"off_5b"],
		"title": "Drum Mags", "description": "+20% magazine size.",
		"effect": {"magazine_mult": 1.20},
	},
	{
		"id": &"off_7", "branch": BRANCH_OFFENSE, "tier": 7, "column": 0,
		"requires": [&"off_6", &"off_6b"],
		"title": "Annihilator", "description": "+15% weapon damage.",
		"effect": {"damage_mult": 1.15},
	},
	# --- Survival ---
	{
		"id": &"sur_1", "branch": BRANCH_SURVIVAL, "tier": 1, "column": 0,
		"requires": [],
		"title": "Toughness", "description": "+20 maximum health.",
		"effect": {"max_health_add": 20.0},
	},
	{
		"id": &"sur_2", "branch": BRANCH_SURVIVAL, "tier": 2, "column": -1,
		"requires": [&"sur_1"],
		"title": "Regeneration", "description": "+1.5 health regen per second.",
		"effect": {"regen_add": 1.5},
	},
	{
		"id": &"sur_2b", "branch": BRANCH_SURVIVAL, "tier": 2, "column": 1,
		"requires": [&"sur_1"],
		"title": "Padded Vest", "description": "4% damage reduction.",
		"effect": {"damage_reduction": 0.04},
	},
	{
		"id": &"sur_3", "branch": BRANCH_SURVIVAL, "tier": 3, "column": -1,
		"requires": [&"sur_2"],
		"title": "Vitality", "description": "+30 maximum health.",
		"effect": {"max_health_add": 30.0},
	},
	{
		"id": &"sur_3b", "branch": BRANCH_SURVIVAL, "tier": 3, "column": 1,
		"requires": [&"sur_2b"],
		"title": "Field Dressing", "description": "+2 health regen per second.",
		"effect": {"regen_add": 2.0},
	},
	{
		"id": &"sur_4", "branch": BRANCH_SURVIVAL, "tier": 4, "column": -1,
		"requires": [&"sur_3"],
		"title": "Armor Plating", "description": "8% damage reduction.",
		"effect": {"damage_reduction": 0.08},
	},
	{
		"id": &"sur_4b", "branch": BRANCH_SURVIVAL, "tier": 4, "column": 1,
		"requires": [&"sur_3b"],
		"title": "Second Wind", "description": "+40 maximum health.",
		"effect": {"max_health_add": 40.0},
	},
	{
		"id": &"sur_5", "branch": BRANCH_SURVIVAL, "tier": 5, "column": -1,
		"requires": [&"sur_4"],
		"title": "Juggernaut", "description": "+50 maximum health.",
		"effect": {"max_health_add": 50.0},
	},
	{
		"id": &"sur_5b", "branch": BRANCH_SURVIVAL, "tier": 5, "column": 1,
		"requires": [&"sur_4b"],
		"title": "Combat Stims", "description": "+2.5 health regen per second.",
		"effect": {"regen_add": 2.5},
	},
	{
		"id": &"sur_6", "branch": BRANCH_SURVIVAL, "tier": 6, "column": -1,
		"requires": [&"sur_5"],
		"title": "Hardened", "description": "10% damage reduction.",
		"effect": {"damage_reduction": 0.10},
	},
	{
		"id": &"sur_6b", "branch": BRANCH_SURVIVAL, "tier": 6, "column": 1,
		"requires": [&"sur_5b"],
		"title": "Bulwark", "description": "+60 maximum health.",
		"effect": {"max_health_add": 60.0},
	},
	{
		"id": &"sur_7", "branch": BRANCH_SURVIVAL, "tier": 7, "column": 0,
		"requires": [&"sur_6", &"sur_6b"],
		"title": "Immovable", "description": "+70 maximum health.",
		"effect": {"max_health_add": 70.0},
	},
	# --- Expedition ---
	{
		"id": &"exp_1", "branch": BRANCH_EXPEDITION, "tier": 1, "column": 0,
		"requires": [],
		"title": "Fleet Footed", "description": "+6% movement speed.",
		"effect": {"move_speed_mult": 1.06},
	},
	{
		"id": &"exp_2", "branch": BRANCH_EXPEDITION, "tier": 2, "column": -1,
		"requires": [&"exp_1"],
		"title": "Scavenger", "description": "+25% Scrap collected.",
		"effect": {"scrap_mult": 1.25},
	},
	{
		"id": &"exp_2b", "branch": BRANCH_EXPEDITION, "tier": 2, "column": 1,
		"requires": [&"exp_1"],
		"title": "Magnetic Field", "description": "+50% pickup range.",
		"effect": {"pickup_radius_mult": 1.50},
	},
	{
		"id": &"exp_3", "branch": BRANCH_EXPEDITION, "tier": 3, "column": -1,
		"requires": [&"exp_2"],
		"title": "Fast Learner", "description": "+20% XP gained.",
		"effect": {"xp_mult": 1.20},
	},
	{
		"id": &"exp_3b", "branch": BRANCH_EXPEDITION, "tier": 3, "column": 1,
		"requires": [&"exp_2b"],
		"title": "Salvager", "description": "+30% Scrap collected.",
		"effect": {"scrap_mult": 1.30},
	},
	{
		"id": &"exp_4", "branch": BRANCH_EXPEDITION, "tier": 4, "column": -1,
		"requires": [&"exp_3"],
		"title": "Ammo Belt", "description": "+30% ammo reserve capacity.",
		"effect": {"ammo_reserve_mult": 1.30},
	},
	{
		"id": &"exp_4b", "branch": BRANCH_EXPEDITION, "tier": 4, "column": 1,
		"requires": [&"exp_3b"],
		"title": "Quick Study", "description": "+25% XP gained.",
		"effect": {"xp_mult": 1.25},
	},
	{
		"id": &"exp_5", "branch": BRANCH_EXPEDITION, "tier": 5, "column": -1,
		"requires": [&"exp_4"],
		"title": "Marathoner", "description": "+10% movement speed.",
		"effect": {"move_speed_mult": 1.10},
	},
	{
		"id": &"exp_5b", "branch": BRANCH_EXPEDITION, "tier": 5, "column": 1,
		"requires": [&"exp_4b"],
		"title": "Deep Pockets", "description": "+30% ammo reserve capacity.",
		"effect": {"ammo_reserve_mult": 1.30},
	},
	{
		"id": &"exp_6", "branch": BRANCH_EXPEDITION, "tier": 6, "column": -1,
		"requires": [&"exp_5"],
		"title": "Treasure Hunter", "description": "+35% Scrap collected.",
		"effect": {"scrap_mult": 1.35},
	},
	{
		"id": &"exp_6b", "branch": BRANCH_EXPEDITION, "tier": 6, "column": 1,
		"requires": [&"exp_5b"],
		"title": "Lightfoot", "description": "+8% movement speed.",
		"effect": {"move_speed_mult": 1.08},
	},
	{
		"id": &"exp_7", "branch": BRANCH_EXPEDITION, "tier": 7, "column": 0,
		"requires": [&"exp_6", &"exp_6b"],
		"title": "Pathfinder", "description": "+12% movement speed.",
		"effect": {"move_speed_mult": 1.12},
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
	"pickup_radius_mult": 1.0,
}

const ADDITIVE_STATS: Array[StringName] = [
	&"max_health_add", &"regen_add", &"damage_reduction",
]

const TIER_COUNT := 7


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
		func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["tier"]) != int(b["tier"]):
				return int(a["tier"]) < int(b["tier"])
			return int(a["column"]) < int(b["column"])
	)
	return branch_nodes


static func get_prerequisites(node_id: StringName) -> Array:
	var node := get_node_definition(node_id)
	return [] if node.is_empty() else node["requires"]


static func is_prerequisite_met(node_id: StringName, unlocked_ids: Array) -> bool:
	# Any one prerequisite is enough: the capstone opens from either path.
	var prerequisites := get_prerequisites(node_id)
	if prerequisites.is_empty():
		return true
	for prerequisite in prerequisites:
		if String(prerequisite) in unlocked_ids:
			return true
	return false


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
