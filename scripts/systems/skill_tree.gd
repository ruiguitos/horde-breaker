class_name SkillTree
extends RefCounted

## Permanent skill trees, one per class, in the shape Killing Floor 2 uses:
##
##      tier 1     [ A ]  or  [ B ]     unlocked at character level 2
##      tier 2     [ A ]  or  [ B ]     level 5
##      tier 3     [ A ]  or  [ B ]     level 9
##      tier 4     [ A ]  or  [ B ]     level 14
##      tier 5     [ A ]  or  [ B ]     level 20   <- defines the class
##
## Five choices, ten nodes, per class. It replaced a single shared tree of 36
## nodes that every class walked identically — which meant the tree said nothing
## about who you were playing, and that a third of it was always the obvious pick.
##
## Two rules carry most of the design:
##
## * **One choice per tier.** Taking a side means giving up the other, so a build
##   reads as a set of decisions rather than a total.
## * **Choices are free to change between runs.** There is no currency and no
##   respec cost. A tree you can rearrange is a loadout you experiment with; a
##   tree you cannot is one you look up online and copy once. This is also what
##   makes migrating old saves harmless — see SaveManager.
##
## Tiers unlock by character level alone. Each node contributes to the aggregate
## bonus dictionary applied at run start, and only the keys in DEFAULT_BONUSES
## do anything: character_skills.gd reads that dictionary and nothing else.

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

## Each class: a title, a tagline, and five tiers of exactly two options.
## Node ids are prefixed by class so they stay unique across the whole game.
const TREES: Dictionary[StringName, Dictionary] = {
	CLASS_RECRUIT: {
		"title": "RECRUIT",
		"tagline": "Never stops shooting.",
		"tiers": [
			[
				{
					"id": &"rec_1a", "title": "Sharpshooter",
					"description": "+8% weapon damage.",
					"effect": {"damage_mult": 1.08},
				},
				{
					"id": &"rec_1b", "title": "Rapid Fire",
					"description": "+10% fire rate.",
					"effect": {"fire_rate_mult": 1.10},
				},
			],
			[
				{
					"id": &"rec_2a", "title": "Extended Mags",
					"description": "+20% magazine size.",
					"effect": {"magazine_mult": 1.20},
				},
				{
					"id": &"rec_2b", "title": "Fast Hands",
					"description": "-20% reload time.",
					"effect": {"reload_mult": 0.80},
				},
			],
			[
				{
					"id": &"rec_3a", "title": "Bandolier",
					"description": "+35% ammo reserve.",
					"effect": {"ammo_reserve_mult": 1.35},
				},
				{
					"id": &"rec_3b", "title": "Combat Vitals",
					"description": "+25 maximum health.",
					"effect": {"max_health_add": 25.0},
				},
			],
			[
				{
					"id": &"rec_4a", "title": "Field Scavenger",
					"description": "+25% Scrap collected.",
					"effect": {"scrap_mult": 1.25},
				},
				{
					"id": &"rec_4b", "title": "Quick Study",
					"description": "+20% experience gained.",
					"effect": {"xp_mult": 1.20},
				},
			],
			[
				# The Recruit's defining pick: heavier rounds, or a wall of them.
				{
					"id": &"rec_5a", "title": "Gunsmith",
					"description": "+20% damage and +10% magazine size.",
					"effect": {"damage_mult": 1.20, "magazine_mult": 1.10},
				},
				{
					"id": &"rec_5b", "title": "Trigger Discipline",
					"description": "+30% fire rate, but -12% damage per shot.",
					"effect": {"fire_rate_mult": 1.30, "damage_mult": 0.88},
				},
			],
		],
	},
	CLASS_RENEGADE: {
		"title": "RENEGADE",
		"tagline": "Walks into it.",
		"tiers": [
			[
				{
					"id": &"ren_1a", "title": "Heavy Frame",
					"description": "+30 maximum health.",
					"effect": {"max_health_add": 30.0},
				},
				{
					"id": &"ren_1b", "title": "Brawler",
					"description": "+10% weapon damage.",
					"effect": {"damage_mult": 1.10},
				},
			],
			[
				{
					"id": &"ren_2a", "title": "Plated",
					"description": "12% less damage taken.",
					"effect": {"damage_reduction": 0.12},
				},
				{
					"id": &"ren_2b", "title": "Adrenaline",
					"description": "+10% movement speed.",
					"effect": {"move_speed_mult": 1.10},
				},
			],
			[
				{
					"id": &"ren_3a", "title": "Drum Mags",
					"description": "+25% magazine size.",
					"effect": {"magazine_mult": 1.25},
				},
				{
					"id": &"ren_3b", "title": "Quick Load",
					"description": "-22% reload time.",
					"effect": {"reload_mult": 0.78},
				},
			],
			[
				{
					"id": &"ren_4a", "title": "Second Wind",
					"description": "+2 health regenerated per second.",
					"effect": {"regen_add": 2.0},
				},
				{
					"id": &"ren_4b", "title": "Bloodlust",
					"description": "+15% fire rate.",
					"effect": {"fire_rate_mult": 1.15},
				},
			],
			[
				# Two ways to be the one who closes the distance: outlast the
				# horde, or make the trade so fast it never gets to answer.
				{
					"id": &"ren_5a", "title": "Juggernaut",
					"description": "+60 maximum health and 18% less damage taken.",
					"effect": {"max_health_add": 60.0, "damage_reduction": 0.18},
				},
				{
					"id": &"ren_5b", "title": "Berserker",
					"description": "+28% damage and +12% speed, but -25 maximum health.",
					"effect": {
						"damage_mult": 1.28, "move_speed_mult": 1.12,
						"max_health_add": -25.0,
					},
				},
			],
		],
	},
	CLASS_MEDIC: {
		"title": "MEDIC",
		"tagline": "Outlasts everything.",
		"tiers": [
			[
				{
					"id": &"med_1a", "title": "Triage",
					"description": "+2 health regenerated per second.",
					"effect": {"regen_add": 2.0},
				},
				{
					"id": &"med_1b", "title": "Steady Hands",
					"description": "+8% weapon damage.",
					"effect": {"damage_mult": 1.08},
				},
			],
			[
				{
					"id": &"med_2a", "title": "Field Kit",
					"description": "+25 maximum health.",
					"effect": {"max_health_add": 25.0},
				},
				{
					"id": &"med_2b", "title": "Light Footed",
					"description": "+12% movement speed.",
					"effect": {"move_speed_mult": 1.12},
				},
			],
			[
				{
					"id": &"med_3a", "title": "Magnetic Kit",
					"description": "+50% pickup range.",
					"effect": {"pickup_radius_mult": 1.50},
				},
				{
					"id": &"med_3b", "title": "Fast Learner",
					"description": "+25% experience gained.",
					"effect": {"xp_mult": 1.25},
				},
			],
			[
				{
					"id": &"med_4a", "title": "Reinforced Vest",
					"description": "12% less damage taken.",
					"effect": {"damage_reduction": 0.12},
				},
				{
					"id": &"med_4b", "title": "Stimulants",
					"description": "+18% fire rate.",
					"effect": {"fire_rate_mult": 1.18},
				},
			],
			[
				# Stay standing forever, or stop being only a survivor.
				{
					"id": &"med_5a", "title": "Regenerator",
					"description": "+5 health per second and +25 maximum health.",
					"effect": {"regen_add": 5.0, "max_health_add": 25.0},
				},
				{
					"id": &"med_5b", "title": "Combat Medic",
					"description": "+22% damage and +2 health per second.",
					"effect": {"damage_mult": 1.22, "regen_add": 2.0},
				},
			],
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


## The two options for one tier, 1-based, as an array of node definitions.
static func get_tier_options(class_id: StringName, tier: int) -> Array:
	var tree := get_class_tree(class_id)
	if tree.is_empty() or tier < 1 or tier > TIER_COUNT:
		return []
	return tree["tiers"][tier - 1]


## Every node of a class, in tier order. Used by the screen to lay the tree out.
static func get_class_nodes(class_id: StringName) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for tier in range(1, TIER_COUNT + 1):
		for option: Dictionary in get_tier_options(class_id, tier):
			nodes.append(_describe(option, class_id, tier))
	return nodes


static func get_node_definition(node_id: StringName) -> Dictionary:
	for class_id: StringName in TREES:
		for tier in range(1, TIER_COUNT + 1):
			for option: Dictionary in get_tier_options(class_id, tier):
				if option["id"] == node_id:
					return _describe(option, class_id, tier)
	return {}


static func get_tier_of(node_id: StringName) -> int:
	var node := get_node_definition(node_id)
	return int(node.get("tier", 0))


static func get_class_of(node_id: StringName) -> StringName:
	var node := get_node_definition(node_id)
	return node.get("class_id", &"")


static func get_required_level(node_id: StringName) -> int:
	var node := get_node_definition(node_id)
	if node.is_empty():
		return 0
	return int(REQUIRED_LEVEL_BY_TIER.get(int(node["tier"]), 0))


static func get_required_level_for_tier(tier: int) -> int:
	return int(REQUIRED_LEVEL_BY_TIER.get(tier, 0))


## Which node the player has taken in a tier, or an empty name for none.
static func get_choice_for_tier(
	chosen_ids: Array, class_id: StringName, tier: int
) -> StringName:
	for option: Dictionary in get_tier_options(class_id, tier):
		if String(option["id"]) in chosen_ids or option["id"] in chosen_ids:
			return option["id"]
	return &""


static func get_bonuses(chosen_ids: Array) -> Dictionary:
	var bonuses := DEFAULT_BONUSES.duplicate()
	for node_id in chosen_ids:
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


static func _describe(
	option: Dictionary, class_id: StringName, tier: int
) -> Dictionary:
	var described := option.duplicate()
	described["class_id"] = class_id
	described["tier"] = tier
	described["required_level"] = get_required_level_for_tier(tier)
	return described
