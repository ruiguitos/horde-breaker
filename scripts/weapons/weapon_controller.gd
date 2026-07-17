extends Marker3D

signal active_weapon_changed(active_weapon: Node3D, slot: int)

enum WeaponSlot {
	PRIMARY,
	SECONDARY,
}

const ASSAULT_RIFLE_DATA: WeaponData = preload("res://data/weapons/assault_rifle.tres")
const PISTOL_DATA: WeaponData = preload("res://data/weapons/pistol.tres")
const SHOTGUN_DATA: WeaponData = preload("res://data/weapons/shotgun.tres")
const WORN_SWORD_DATA: WeaponData = preload("res://data/weapons/worn_sword.tres")

var _primary_weapon_id: StringName = &"assault_rifle"
var _secondary_weapon_id: StringName = &"pistol"
var _reload_duration_multiplier: float = 0.7
var _primary_weapon: Node3D
var _secondary_weapon: Node3D
var _active_weapon: Node3D
var _active_slot: int = WeaponSlot.PRIMARY


func configure(character_data: CharacterData) -> void:
	if character_data == null:
		return
	_primary_weapon_id = character_data.primary_weapon_id
	_secondary_weapon_id = character_data.secondary_weapon_id
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
	active_weapon_changed.emit(_active_weapon, _active_slot)
	return true


func get_active_weapon() -> Node3D:
	return _active_weapon


func get_active_slot() -> int:
	return _active_slot


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
	if weapon_id == ASSAULT_RIFLE_DATA.weapon_id:
		return ASSAULT_RIFLE_DATA
	if weapon_id == PISTOL_DATA.weapon_id:
		return PISTOL_DATA
	if weapon_id == SHOTGUN_DATA.weapon_id:
		return SHOTGUN_DATA
	if weapon_id == WORN_SWORD_DATA.weapon_id:
		return WORN_SWORD_DATA
	return null
