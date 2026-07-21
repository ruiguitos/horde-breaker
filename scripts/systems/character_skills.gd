extends Node

## Applies the selected character's permanent skill-tree bonuses to the player
## and its weapons once, at the start of the run. Scrap and XP multipliers are
## read directly by CampEconomy and CharacterProgression.

const PLAYER_GROUP := &"player"
const WEAPON_CONTROLLER_GROUP := &"weapon_controller"


func _ready() -> void:
	call_deferred(&"_apply_skills")


func _apply_skills() -> void:
	# One frame so the spawned player and its weapons are fully ready.
	await get_tree().process_frame
	var bonuses := SaveManager.get_skill_bonuses(
		SaveManager.get_selected_character()
	)
	_apply_to_player(bonuses)
	_apply_to_weapons(bonuses)


func _apply_to_player(bonuses: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return
	var health_bonus := float(bonuses.get("max_health_add", 0.0))
	if health_bonus > 0.0:
		player.set(
			&"maximum_health",
			float(player.get(&"maximum_health")) + health_bonus
		)
		if player.has_method(&"heal"):
			player.call(&"heal", health_bonus)
	player.set(
		&"health_regeneration_rate",
		float(player.get(&"health_regeneration_rate"))
		+ float(bonuses.get("regen_add", 0.0))
	)
	player.set(
		&"damage_reduction",
		float(player.get(&"damage_reduction"))
		+ float(bonuses.get("damage_reduction", 0.0))
	)
	var speed_mult := float(bonuses.get("move_speed_mult", 1.0))
	player.set(&"move_speed", float(player.get(&"move_speed")) * speed_mult)
	player.set(&"sprint_speed", float(player.get(&"sprint_speed")) * speed_mult)


func _apply_to_weapons(bonuses: Dictionary) -> void:
	var weapon_controller := get_tree().get_first_node_in_group(
		WEAPON_CONTROLLER_GROUP
	)
	if weapon_controller == null or not weapon_controller.has_method(
		&"get_loadout_weapons"
	):
		return
	for weapon in weapon_controller.call(&"get_loadout_weapons"):
		_apply_to_weapon(weapon, bonuses)


func _apply_to_weapon(weapon: Node, bonuses: Dictionary) -> void:
	var damage: Variant = weapon.get(&"damage")
	if damage != null:
		weapon.set(&"damage", float(damage) * float(bonuses.get("damage_mult", 1.0)))
	var fire_rate: Variant = weapon.get(&"fire_rate")
	if fire_rate != null:
		weapon.set(
			&"fire_rate", float(fire_rate) * float(bonuses.get("fire_rate_mult", 1.0))
		)
	if (
		weapon.has_method(&"set_reload_duration_multiplier")
		and weapon.has_method(&"get_reload_duration_multiplier")
	):
		weapon.call(
			&"set_reload_duration_multiplier",
			float(weapon.call(&"get_reload_duration_multiplier"))
			* float(bonuses.get("reload_mult", 1.0))
		)
	var reserve_mult := float(bonuses.get("ammo_reserve_mult", 1.0))
	if reserve_mult != 1.0:
		var max_reserve: Variant = weapon.get(&"maximum_reserve_ammunition")
		if max_reserve != null:
			weapon.set(
				&"maximum_reserve_ammunition", ceili(int(max_reserve) * reserve_mult)
			)
		var reserve: Variant = weapon.get(&"reserve_ammunition")
		if reserve != null:
			weapon.set(&"reserve_ammunition", ceili(int(reserve) * reserve_mult))
