class_name CharacterMastery
extends RefCounted

## Static mastery objective definitions, mirroring the SkillTree pattern.
## Progress and rewards are stored per character by the SaveManager;
## `track_highest` objectives keep the best value instead of accumulating.

const OBJECTIVES: Dictionary[StringName, Dictionary] = {
	&"kills_100": {
		"name": "EXTERMINATOR",
		"description": "Defeat 100 enemies",
		"goal": 100,
		"reward_credits": 150,
		"track_highest": false,
	},
	&"threat_5": {
		"name": "STORM RIDER",
		"description": "Survive threat level 5 in one run",
		"goal": 5,
		"reward_credits": 200,
		"track_highest": true,
	},
	&"scrap_500": {
		"name": "SCAVENGER",
		"description": "Collect 500 scrap",
		"goal": 500,
		"reward_credits": 150,
		"track_highest": false,
	},
}


static func get_objective(objective_id: StringName) -> Dictionary:
	return OBJECTIVES.get(objective_id, {})
