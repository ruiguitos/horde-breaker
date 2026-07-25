extends Node

## Applies the selected character's permanent skill-tree bonuses to the player
## and its weapons once, at the start of the run. Scrap and XP multipliers are
## read directly by CampEconomy and CharacterProgression. When the class
## variant is active, its base overrides land before the skill bonuses and its
## runtime hooks (lifesteal, heal on kill, tint) are wired afterwards.

const PLAYER_GROUP := &"player"
const WEAPON_CONTROLLER_GROUP := &"weapon_controller"
const WAVE_MANAGER_GROUP := &"wave_manager"
const VARIANT_TINT_ALPHA := 0.14


func _ready() -> void:
	call_deferred(&"_apply_skills")


func _apply_skills() -> void:
	# One frame so the spawned player and its weapons are fully ready.
	await get_tree().process_frame
	var class_id := SaveManager.get_selected_character()
	var variant: Dictionary = {}
	if SaveManager.is_variant_active(class_id):
		variant = CharacterVariants.get_variant(class_id)
	if not variant.is_empty():
		_apply_variant_base(variant, class_id)
	var bonuses := SaveManager.get_skill_bonuses(class_id)
	_apply_to_player(bonuses)
	_apply_to_weapons(bonuses)
	if not variant.is_empty():
		_apply_variant_hooks(variant)


func _apply_variant_base(variant: Dictionary, class_id: StringName) -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return
	if variant.has("max_health_override"):
		var new_maximum := float(variant["max_health_override"])
		player.set(&"maximum_health", new_maximum)
		player.set(
			&"current_health",
			minf(float(player.get(&"current_health")), new_maximum)
		)
		player.emit_signal(
			&"health_changed",
			float(player.get(&"current_health")),
			new_maximum
		)
	if variant.has("regen_rate_override"):
		player.set(
			&"health_regeneration_rate", float(variant["regen_rate_override"])
		)
	if variant.has("regen_delay_override"):
		player.set(
			&"health_regeneration_delay", float(variant["regen_delay_override"])
		)
	if variant.has("reload_multiplier_override"):
		# Replace the class reload trait with the override, preserving any
		# other multipliers already applied to the weapon.
		var class_data := SaveManager.get_character_data(class_id)
		var class_multiplier := (
			class_data.reload_duration_multiplier if class_data != null else 1.0
		)
		for weapon in _get_loadout_weapons():
			if (
				weapon.has_method(&"set_reload_duration_multiplier")
				and weapon.has_method(&"get_reload_duration_multiplier")
			):
				var current := float(
					weapon.call(&"get_reload_duration_multiplier")
				)
				weapon.call(
					&"set_reload_duration_multiplier",
					current / maxf(class_multiplier, 0.05)
					* float(variant["reload_multiplier_override"])
				)


func _apply_variant_hooks(variant: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return
	var fire_rate_mult := float(variant.get("fire_rate_mult", 1.0))
	var lifesteal := float(variant.get("melee_lifesteal", 0.0))
	for weapon in _get_loadout_weapons():
		if fire_rate_mult != 1.0:
			var fire_rate: Variant = weapon.get(&"fire_rate")
			if fire_rate != null:
				weapon.set(&"fire_rate", float(fire_rate) * fire_rate_mult)
		if lifesteal > 0.0 and weapon.has_signal(&"attack_performed"):
			weapon.connect(
				&"attack_performed",
				func(hit_count: int) -> void:
					if hit_count > 0 and is_instance_valid(player):
						player.call(&"heal", lifesteal * hit_count)
			)
	var heal_on_kill := float(variant.get("heal_on_kill", 0.0))
	if heal_on_kill > 0.0:
		var wave_manager := get_tree().get_first_node_in_group(WAVE_MANAGER_GROUP)
		if wave_manager != null and wave_manager.has_signal(&"enemy_defeated"):
			wave_manager.connect(
				&"enemy_defeated",
				func(_xp_reward: int) -> void:
					if is_instance_valid(player):
						player.call(&"heal", heal_on_kill)
			)
	_apply_variant_tint(player, variant)


func _apply_variant_tint(player: Node, variant: Dictionary) -> void:
	if not variant.has("tint"):
		return
	var visual_root := player.get_node_or_null("VisualRoot")
	if visual_root == null:
		return
	# Subtle additive sheen in the variant colour, mirroring the enemy hit
	# flash overlay (with alpha transparency enabled so it stays subtle in the
	# GL Compatibility renderer).
	var tint_material := StandardMaterial3D.new()
	tint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tint_color: Color = variant["tint"]
	tint_color.a = VARIANT_TINT_ALPHA
	tint_material.albedo_color = tint_color
	for mesh_value in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_value as MeshInstance3D
		if mesh_instance.visible:
			mesh_instance.material_overlay = tint_material


func _get_loadout_weapons() -> Array:
	var weapon_controller := get_tree().get_first_node_in_group(
		WEAPON_CONTROLLER_GROUP
	)
	if weapon_controller == null or not weapon_controller.has_method(
		&"get_loadout_weapons"
	):
		return []
	return weapon_controller.call(&"get_loadout_weapons")


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
	# Pickup range lives on the run progression, alongside the MAGNETIC FIELD
	# card that scales the same value during a run.
	var pickup_mult := float(bonuses.get("pickup_radius_mult", 1.0))
	if pickup_mult != 1.0:
		var progression := get_tree().get_first_node_in_group(&"run_progression")
		if progression != null:
			progression.set(
				&"pickup_radius_multiplier",
				float(progression.get(&"pickup_radius_multiplier")) * pickup_mult
			)


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
	var magazine_mult := float(bonuses.get("magazine_mult", 1.0))
	if magazine_mult != 1.0:
		var magazine: Variant = weapon.get(&"magazine_size")
		if magazine != null:
			weapon.set(&"magazine_size", ceili(int(magazine) * magazine_mult))
	# Reserve bonuses share the weapon's additive capacity budget with the run
	# cards instead of multiplying the current values.
	var reserve_mult := float(bonuses.get("ammo_reserve_mult", 1.0))
	if reserve_mult > 1.0 and weapon.has_method(&"add_reserve_capacity"):
		weapon.call(&"add_reserve_capacity", reserve_mult - 1.0)
