extends Node

signal upgrade_applied(upgrade_id: StringName, title: String)

const PLAYER_GROUP := &"player"
const WEAPON_CONTROLLER_GROUP := &"weapon_controller"
const CAMP_ECONOMY_GROUP := &"camp_economy"

## Session-only upgrades chosen between waves; everything resets with the run.
## Each entry unlocks at the selected character's permanent level, so higher
## level characters draw choices from a deeper pool.
const UPGRADE_POOL: Array[Dictionary] = [
	{
		"id": &"maximum_health",
		"title": "BLINDAGEM IMPROVISADA",
		"description": "+25 de vida máxima e cura imediata de 25 pontos.",
		"required_level": 1,
	},
	{
		"id": &"move_speed",
		"title": "PERNAS FRESCAS",
		"description": "+10% de velocidade a andar e a correr.",
		"required_level": 1,
	},
	{
		"id": &"full_heal",
		"title": "KIT DE CAMPANHA",
		"description": "Recupera imediatamente toda a vida.",
		"required_level": 1,
	},
	{
		"id": &"reload_speed",
		"title": "MÃOS RÁPIDAS",
		"description": "Recarga 20% mais rápida em todas as armas.",
		"required_level": 3,
	},
	{
		"id": &"weapon_damage",
		"title": "MUNIÇÕES REFORÇADAS",
		"description": "+20% de dano em todas as armas do loadout.",
		"required_level": 5,
	},
	{
		"id": &"magazine_size",
		"title": "CARREGADORES ALARGADOS",
		"description": "+25% de capacidade do carregador nas armas de fogo.",
		"required_level": 7,
	},
	{
		"id": &"fire_rate",
		"title": "ADRENALINA",
		"description": "+15% de cadência de tiro e golpes corpo a corpo mais rápidos.",
		"required_level": 9,
	},
]


func get_unlocked_upgrades() -> Array[Dictionary]:
	var character_level := SaveManager.get_character_level(
		SaveManager.get_selected_character()
	)
	var unlocked: Array[Dictionary] = []
	for upgrade in UPGRADE_POOL:
		if character_level >= int(upgrade.get("required_level", 1)):
			unlocked.append(upgrade)
	return unlocked


func get_total_upgrade_count() -> int:
	return UPGRADE_POOL.size()


func get_random_choices(count: int = 3) -> Array[Dictionary]:
	var pool := get_unlocked_upgrades()
	pool.shuffle()
	var choices: Array[Dictionary] = []
	for upgrade in pool:
		choices.append(upgrade)
		if choices.size() >= count:
			break
	return choices


func apply_upgrade(upgrade_id: StringName) -> bool:
	var applied := false
	match upgrade_id:
		&"weapon_damage":
			applied = _apply_weapon_damage_multiplier(1.2)
		&"maximum_health":
			applied = _apply_maximum_health_bonus(25.0)
		&"move_speed":
			applied = _apply_move_speed_multiplier(1.1)
		&"reload_speed":
			applied = _apply_reload_multiplier(0.8)
		&"full_heal":
			applied = _apply_full_heal()
		&"magazine_size":
			applied = _apply_magazine_multiplier(1.25)
		&"fire_rate":
			applied = _apply_attack_speed_multiplier(1.15)
		_:
			push_error("RunUpgrades received an unknown upgrade: %s" % upgrade_id)
	if applied:
		var title := _get_upgrade_title(upgrade_id)
		upgrade_applied.emit(upgrade_id, title)
		var camp_economy := get_tree().get_first_node_in_group(CAMP_ECONOMY_GROUP)
		if camp_economy != null and camp_economy.has_method(&"request_feedback"):
			camp_economy.call(&"request_feedback", "MELHORIA ATIVA  •  %s" % title)
	return applied


func _apply_weapon_damage_multiplier(multiplier: float) -> bool:
	var weapons := _get_loadout_weapons()
	if weapons.is_empty():
		return false
	for weapon in weapons:
		weapon.set(&"damage", float(weapon.get(&"damage")) * multiplier)
	return true


func _apply_maximum_health_bonus(bonus: float) -> bool:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return false
	player.set(&"maximum_health", float(player.get(&"maximum_health")) + bonus)
	player.call(&"heal", bonus)
	return true


func _apply_move_speed_multiplier(multiplier: float) -> bool:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return false
	player.set(&"move_speed", float(player.get(&"move_speed")) * multiplier)
	player.set(&"sprint_speed", float(player.get(&"sprint_speed")) * multiplier)
	return true


func _apply_reload_multiplier(multiplier: float) -> bool:
	var weapons := _get_loadout_weapons()
	var applied := false
	for weapon in weapons:
		if not weapon.has_method(&"set_reload_duration_multiplier"):
			continue
		var current_multiplier := float(
			weapon.call(&"get_reload_duration_multiplier")
		)
		weapon.call(
			&"set_reload_duration_multiplier", current_multiplier * multiplier
		)
		applied = true
	return applied


func _apply_full_heal() -> bool:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return false
	player.call(&"heal", float(player.get(&"maximum_health")))
	return true


func _apply_magazine_multiplier(multiplier: float) -> bool:
	var applied := false
	for weapon in _get_loadout_weapons():
		var magazine_size: Variant = weapon.get(&"magazine_size")
		if magazine_size == null:
			continue
		weapon.set(&"magazine_size", ceili(int(magazine_size) * multiplier))
		applied = true
	return applied


func _apply_attack_speed_multiplier(multiplier: float) -> bool:
	var applied := false
	for weapon in _get_loadout_weapons():
		var fire_rate: Variant = weapon.get(&"fire_rate")
		if fire_rate != null:
			weapon.set(&"fire_rate", float(fire_rate) * multiplier)
			applied = true
			continue
		var attack_cooldown: Variant = weapon.get(&"attack_cooldown")
		if attack_cooldown != null:
			weapon.set(&"attack_cooldown", float(attack_cooldown) / multiplier)
			applied = true
	return applied


func _get_loadout_weapons() -> Array[Node3D]:
	var weapon_controller := get_tree().get_first_node_in_group(
		WEAPON_CONTROLLER_GROUP
	)
	if weapon_controller == null or not weapon_controller.has_method(
		&"get_loadout_weapons"
	):
		return []
	return weapon_controller.call(&"get_loadout_weapons")


func _get_upgrade_title(upgrade_id: StringName) -> String:
	for upgrade in UPGRADE_POOL:
		if upgrade["id"] == upgrade_id:
			return String(upgrade["title"])
	return String(upgrade_id)
