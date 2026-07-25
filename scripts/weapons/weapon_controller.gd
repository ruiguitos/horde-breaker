extends Marker3D

signal active_weapon_changed(active_weapon: Node3D, slot: int)

enum WeaponSlot {
	PRIMARY,
	SECONDARY,
}

const WEAPON_PICKUP_SCENE := preload("res://scenes/pickups/weapon_pickup.tscn")
const PLAYER_GROUP := &"player"

var _primary_weapon_id: StringName = &"assault_rifle"
var _secondary_weapon_id: StringName = &"pistol"
var _reload_duration_multiplier: float = 0.7
var _primary_weapon: Node3D
var _secondary_weapon: Node3D
var _active_weapon: Node3D
var _active_slot: int = WeaponSlot.PRIMARY


func configure(
	character_data: CharacterData,
	primary_weapon_id: StringName = &"",
	secondary_weapon_id: StringName = &""
) -> void:
	if character_data == null:
		return
	_primary_weapon_id = (
		primary_weapon_id
		if primary_weapon_id != &""
		else character_data.primary_weapon_id
	)
	_secondary_weapon_id = (
		secondary_weapon_id
		if secondary_weapon_id != &""
		else character_data.secondary_weapon_id
	)
	_reload_duration_multiplier = character_data.reload_duration_multiplier


func _ready() -> void:
	_primary_weapon = _create_weapon(_primary_weapon_id)
	_secondary_weapon = _create_weapon(_secondary_weapon_id)
	if not equip_slot(WeaponSlot.PRIMARY):
		equip_slot(WeaponSlot.SECONDARY)


func _unhandled_input(event: InputEvent) -> void:
	var switched := false
	if event.is_action_pressed("weapon_primary"):
		switched = equip_slot(WeaponSlot.PRIMARY)
	elif event.is_action_pressed("weapon_secondary"):
		switched = equip_slot(WeaponSlot.SECONDARY)
	if switched:
		get_viewport().set_input_as_handled()


func equip_slot(slot: int) -> bool:
	var next_weapon := (
		_primary_weapon if slot == WeaponSlot.PRIMARY else _secondary_weapon
	)
	if next_weapon == null or next_weapon == _active_weapon:
		return false
	_set_weapon_active(_active_weapon, false)
	_active_weapon = next_weapon
	_active_slot = slot
	_set_weapon_active(_active_weapon, true)
	_apply_weapon_speed_penalty(_active_weapon)
	active_weapon_changed.emit(_active_weapon, _active_slot)
	return true


func _apply_weapon_speed_penalty(weapon: Node3D) -> void:
	# Heavy weapons (Machine Gun, Minigun) trade mobility for firepower; the
	# penalty only applies while they are the active weapon.
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null or not player.has_method(&"set_weapon_speed_multiplier"):
		return
	var multiplier: Variant = weapon.get(&"move_speed_multiplier") if weapon != null else null
	player.call(
		&"set_weapon_speed_multiplier",
		float(multiplier) if multiplier != null else 1.0
	)


func get_active_weapon() -> Node3D:
	return _active_weapon


func get_loadout_weapons() -> Array[Node3D]:
	var weapons: Array[Node3D] = []
	if _primary_weapon != null:
		weapons.append(_primary_weapon)
	if _secondary_weapon != null:
		weapons.append(_secondary_weapon)
	return weapons


func equip_field_weapon(weapon_id: StringName) -> bool:
	# A weapon found while exploring replaces the secondary slot for this run
	# and becomes active immediately.
	if weapon_id == &"":
		return false
	var new_weapon := _create_weapon(weapon_id)
	if new_weapon == null:
		return false
	var old_secondary := _secondary_weapon
	var old_secondary_id := _secondary_weapon_id
	if _active_weapon == old_secondary:
		_active_weapon = null
	if old_secondary != null:
		old_secondary.queue_free()
	# Drop the replaced weapon so it can be picked up again later.
	_drop_weapon(old_secondary_id)
	_secondary_weapon = new_weapon
	_secondary_weapon_id = weapon_id
	return equip_slot(WeaponSlot.SECONDARY)


func _drop_weapon(weapon_id: StringName) -> void:
	if weapon_id == &"":
		return
	var weapon_data := _get_weapon_data(weapon_id)
	if weapon_data == null:
		return
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	if player == null:
		return
	var pickup := WEAPON_PICKUP_SCENE.instantiate() as Area3D
	if pickup == null:
		return
	pickup.set(&"weapon_id", weapon_id)
	pickup.set(&"weapon_display_name", weapon_data.display_name)
	var effect_parent: Node = get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_tree().root
	effect_parent.add_child(pickup)
	# Drop it a short distance away on the ground so it is visible and reachable.
	var drop_angle := randf() * TAU
	pickup.global_position = Vector3(
		player.global_position.x + cos(drop_angle) * 1.6,
		0.35,
		player.global_position.z + sin(drop_angle) * 1.6
	)


func get_active_slot() -> int:
	return _active_slot


func add_ammunition(amount: int) -> int:
	if amount <= 0:
		return 0
	var weapons: Array[Node3D] = []
	if _active_weapon != null:
		weapons.append(_active_weapon)
	var loadout_weapons: Array[Node3D] = [_primary_weapon, _secondary_weapon]
	for weapon in loadout_weapons:
		if weapon != null and weapon != _active_weapon:
			weapons.append(weapon)
	for weapon in weapons:
		if not weapon.has_method(&"add_ammunition"):
			continue
		var added_ammunition := int(weapon.call(&"add_ammunition", amount))
		if added_ammunition > 0:
			return added_ammunition
	return 0


func get_primary_weapon_name() -> String:
	return _get_weapon_name(_primary_weapon_id)


func get_secondary_weapon_name() -> String:
	return _get_weapon_name(_secondary_weapon_id)


func _create_weapon(weapon_id: StringName) -> Node3D:
	if weapon_id == &"":
		return null
	var weapon_data := _get_weapon_data(weapon_id)
	if weapon_data == null or not weapon_data.is_playable or weapon_data.weapon_scene == null:
		push_error("WeaponController could not create weapon: %s" % weapon_id)
		return null
	var weapon := weapon_data.weapon_scene.instantiate() as Node3D
	if weapon == null:
		push_error("Weapon scenes must use Node3D as root: %s" % weapon_id)
		return null
	add_child(weapon)
	if weapon.has_method(&"set_reload_duration_multiplier"):
		weapon.call(
			&"set_reload_duration_multiplier",
			_reload_duration_multiplier
		)
	_set_weapon_active(weapon, false)
	return weapon


func _set_weapon_active(weapon: Node3D, is_active: bool) -> void:
	if weapon == null:
		return
	weapon.visible = is_active
	weapon.process_mode = (
		Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	)
	if is_active:
		weapon.add_to_group(&"player_weapon")
	else:
		if weapon.has_method(&"cancel_reload"):
			weapon.call(&"cancel_reload")
		weapon.remove_from_group(&"player_weapon")


func _get_weapon_name(weapon_id: StringName) -> String:
	if weapon_id == &"":
		return "—"
	var weapon_data := _get_weapon_data(weapon_id)
	return weapon_data.display_name if weapon_data != null else String(weapon_id)


func _get_weapon_data(weapon_id: StringName) -> WeaponData:
	return WeaponCatalog.get_weapon_data(weapon_id)
